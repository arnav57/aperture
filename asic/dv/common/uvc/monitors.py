"""Generic cocotb monitors (targets cocotb 2.x).

    _Monitor
    |-- BitMonitor          single-bit signal: edges, counts, timestamps, callbacks
    |   |-- ResetMonitor    polarity-aware assert/deassert tracking
    |   `-- ClockMonitor    period / frequency / duty-cycle / jitter measurement
    `-- BusMonitor          multi-bit signal: raw/signed/unsigned/bit-field reads,
                            fixed-point (Qm.n) decoding to ints, optional clocked sampling

Usage sketch:

    rst = ResetMonitor(dut.rst_n, active_low=True).start()
    clk = ClockMonitor(dut.clk, expected_period_ns=10).start()
    out = BusMonitor(dut.angle, clock=dut.clk).start()

    @out.on("change")
    def _(old, new, t):
        dut._log.info(f"{t} ns: {out.as_q('Q1.15', raw=new)}")

    await rst.wait_deassert()
    await out.wait_change()
    x = out.as_float("Q1.15")

Callback signature for every event is fn(old, new, t_ns). Sync callbacks run
inline in the monitor task (an exception fails the test). Coroutine callbacks are
started with cocotb.start_soon so a slow callback never makes the monitor miss an edge.
"""
from __future__ import annotations

import inspect
import logging
import math
import re
from collections import deque
from dataclasses import dataclass
from typing import Callable, Deque, Dict, List, Optional, Tuple, Union

import cocotb
from cocotb.triggers import Edge, FallingEdge, ReadOnly, RisingEdge
from cocotb.utils import get_sim_time


# --------------------------------------------------------------------------- #
# Fixed-point format
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class QFormat:
    """Fixed-point format descriptor.

    int_bits, frac_bits : the m and n of Qm.n
    signed              : two's complement if True
    sign_in_int         : if True, int_bits already counts the sign bit
                          (total = m + n, so Q1.15 is 16 bits, the ARM/"Q15" style).
                          If False (default, TI style) the sign bit is extra
                          (total = 1 + m + n, so Q3.15 is 19 bits).
                          Unsigned formats never have a sign bit.
    """

    int_bits: int
    frac_bits: int
    signed: bool = True
    sign_in_int: bool = False

    def __post_init__(self):
        if self.int_bits < 0 or self.frac_bits < 0:
            raise ValueError("int_bits and frac_bits must be >= 0")
        if self.signed and self.sign_in_int and self.int_bits < 1:
            raise ValueError("sign_in_int=True needs int_bits >= 1 (it counts the sign bit)")
        if self.total_bits <= 0:
            raise ValueError("format has zero bits")

    # ---- construction -------------------------------------------------- #
    @classmethod
    def parse(cls, spec: str, sign_in_int: bool = False) -> "QFormat":
        """'Q3.15' / 'SQ3.15' -> signed, 'UQ3.15' -> unsigned."""
        m = re.fullmatch(r"\s*([US])?Q(\d+)\.(\d+)\s*", spec, re.IGNORECASE)
        if not m:
            raise ValueError(f"cannot parse fixed-point spec {spec!r} (expected e.g. 'Q3.15' or 'UQ0.16')")
        prefix, i, f = m.groups()
        signed = not (prefix and prefix.upper() == "U")
        return cls(int(i), int(f), signed=signed, sign_in_int=sign_in_int)

    # ---- geometry ------------------------------------------------------ #
    @property
    def total_bits(self) -> int:
        n = self.int_bits + self.frac_bits
        if self.signed and not self.sign_in_int:
            n += 1
        return n

    @property
    def scale(self) -> int:
        """2**frac_bits: scaled_int / scale == real value."""
        return 1 << self.frac_bits

    @property
    def lsb(self) -> float:
        return 2.0 ** -self.frac_bits

    @property
    def min_int(self) -> int:
        return -(1 << (self.total_bits - 1)) if self.signed else 0

    @property
    def max_int(self) -> int:
        return (1 << (self.total_bits - 1)) - 1 if self.signed else (1 << self.total_bits) - 1

    @property
    def min_val(self) -> float:
        return self.min_int / self.scale

    @property
    def max_val(self) -> float:
        return self.max_int / self.scale

    def __str__(self) -> str:
        return f"{'' if self.signed else 'U'}Q{self.int_bits}.{self.frac_bits}" \
               f"{' (sign in int)' if self.signed and self.sign_in_int else ''}"

    # ---- conversions --------------------------------------------------- #
    def from_bits(self, bits: int) -> int:
        """Raw bit pattern (unsigned int) -> scaled int (two's complement if signed)."""
        n = self.total_bits
        bits &= (1 << n) - 1
        if self.signed and (bits >> (n - 1)):
            bits -= 1 << n
        return bits

    def to_bits(self, scaled: int) -> int:
        """Scaled int -> raw bit pattern you can assign to a DUT signal."""
        if not (self.min_int <= scaled <= self.max_int):
            raise OverflowError(f"{scaled} does not fit in {self} [{self.min_int}, {self.max_int}]")
        return scaled & ((1 << self.total_bits) - 1)

    def to_float(self, scaled: int) -> float:
        return scaled / self.scale

    def from_float(self, x: float, rounding: str = "nearest", saturate: bool = True) -> int:
        """Real value -> scaled int.

        rounding: 'nearest' (half away from zero), 'even' (banker's), 'floor', 'trunc'
        saturate: clamp to [min_int, max_int]; otherwise raise OverflowError.
        """
        y = x * self.scale
        if rounding == "nearest":
            s = int(math.floor(abs(y) + 0.5)) * (1 if y >= 0 else -1)
        elif rounding == "even":
            s = round(y)
        elif rounding == "floor":
            s = math.floor(y)
        elif rounding == "trunc":
            s = math.trunc(y)
        else:
            raise ValueError(f"unknown rounding mode {rounding!r}")
        if s < self.min_int or s > self.max_int:
            if not saturate:
                raise OverflowError(f"{x} does not fit in {self}")
            s = max(self.min_int, min(self.max_int, s))
        return s

    def split(self, scaled: int) -> Tuple[int, int]:
        """Scaled int -> (integer_part, fraction_bits). value = ip + fp / scale.

        integer_part is floor(value) (negative for negative numbers) and
        fraction_bits is always non-negative, matching two's complement layout.
        """
        return scaled >> self.frac_bits, scaled & (self.scale - 1)


QSpec = Union[QFormat, str]


def _as_qformat(fmt: QSpec) -> QFormat:
    return fmt if isinstance(fmt, QFormat) else QFormat.parse(fmt)


# --------------------------------------------------------------------------- #
# Base
# --------------------------------------------------------------------------- #
class _Monitor:
    def __init__(self, name: str):
        self.name = name
        self.log = logging.getLogger(f"cocotb.{name}")
        self.log.setLevel(logging.DEBUG)
        self._task = None
        self._callbacks: Dict[str, List[Callable]] = {}

    # ---- lifecycle ----------------------------------------------------- #
    @property
    def running(self) -> bool:
        return self._task is not None and not self._task.done()

    def start(self):
        """Spawn the monitor task. Call from inside a running test. Returns self."""
        if not self.running:
            self._task = cocotb.start_soon(self._run())
        return self

    def stop(self):
        if self._task is not None and not self._task.done():
            self._task.cancel()
        self._task = None

    # ---- callbacks ----------------------------------------------------- #
    def on(self, event: str, fn: Optional[Callable] = None):
        """Register fn for an event. Usable as mon.on('rise', fn) or as a decorator."""
        if fn is None:
            return lambda f: self.on(event, f)
        self._callbacks.setdefault(event, []).append(fn)
        return fn

    def _fire(self, event: str, old, new, t: float):
        for fn in list(self._callbacks.get(event, ())):
            result = fn(old, new, t)
            if inspect.iscoroutine(result):
                cocotb.start_soon(result)

    # ---- helpers ------------------------------------------------------- #
    @staticmethod
    def _now() -> float:
        return get_sim_time("ns")

    async def _run(self):
        raise NotImplementedError


# --------------------------------------------------------------------------- #
# BitMonitor
# --------------------------------------------------------------------------- #
class BitMonitor(_Monitor):
    """Tracks a single-bit signal.

    Events: 'rise' (0->1), 'fall' (1->0), 'change' (any value change, incl. to/from X/Z).
    Values are ints 0/1, or None when the signal is X/Z/U.

    Subclass hooks (called after bookkeeping, before user callbacks):
        _on_start(value, t)  _on_rise(t)  _on_fall(t)  _on_change(old, new, t)
    """

    def __init__(self, signal, name: Optional[str] = None,
                 keep_history: bool = False, history_len: Optional[int] = None):
        super().__init__(name or getattr(signal, "_name", "bit"))
        self.signal = signal

        self._cur: Optional[int] = None
        self.prev_value: Optional[int] = None

        self.rise_count = 0
        self.fall_count = 0
        self.change_count = 0
        self.last_rise_time: Optional[float] = None
        self.prev_rise_time: Optional[float] = None
        self.last_fall_time: Optional[float] = None
        self.prev_fall_time: Optional[float] = None
        self.last_change_time: Optional[float] = None

        self.history: Optional[Deque[Tuple[float, Optional[int]]]] = \
            deque(maxlen=history_len) if keep_history else None

    # ---- reads --------------------------------------------------------- #
    def read(self) -> Optional[int]:
        v = self.signal.value
        return int(v) if v.is_resolvable else None

    @property
    def value(self) -> Optional[int]:
        """Live value (None if X/Z)."""
        return self.read()

    # ---- waits (independent of the monitor task) ----------------------- #
    async def wait_rise(self):
        await RisingEdge(self.signal)

    async def wait_fall(self):
        await FallingEdge(self.signal)

    async def wait_change(self):
        await self.signal.value_change

    # ---- hooks --------------------------------------------------------- #
    def _on_start(self, value, t): ...
    def _on_rise(self, t): ...
    def _on_fall(self, t): ...
    def _on_change(self, old, new, t): ...

    # ---- main loop ----------------------------------------------------- #
    async def _run(self):
        t = self._now()
        self._cur = self.read()
        self.last_change_time = t
        if self.history is not None:
            self.history.append((t, self._cur))
        self._on_start(self._cur, t)

        while True:
            await self.signal.value_change
            t = self._now()
            old, new = self._cur, self.read()
            self.prev_value, self._cur = old, new
            self.change_count += 1
            self.last_change_time = t
            if self.history is not None:
                self.history.append((t, new))

            kind = None
            if old == 0 and new == 1:
                kind = "rise"
                self.rise_count += 1
                self.prev_rise_time, self.last_rise_time = self.last_rise_time, t
                self._on_rise(t)
            elif old == 1 and new == 0:
                kind = "fall"
                self.fall_count += 1
                self.prev_fall_time, self.last_fall_time = self.last_fall_time, t
                self._on_fall(t)
            else:
                self.log.debug("%s: %s -> %s at %.3f ns (not a clean edge)", self.name, old, new, t)
            self._on_change(old, new, t)

            if kind:
                self._fire(kind, old, new, t)
            self._fire("change", old, new, t)


# --------------------------------------------------------------------------- #
# ResetMonitor
# --------------------------------------------------------------------------- #
class ResetMonitor(BitMonitor):
    """BitMonitor with assert/deassert semantics.

    Extra events: 'assert', 'deassert'. A transition from X/Z into the active
    level counts as an assertion. If the reset is already asserted when start()
    runs it is counted as an assertion at the start time.
    """

    def __init__(self, signal, active_low: bool = True, name: Optional[str] = None, **kw):
        super().__init__(signal, name, **kw)
        self.active_low = active_low
        self.assert_count = 0
        self.assert_times: List[float] = []
        self.durations: List[float] = []   # ns, one per completed assertion
        self.last_assert_time: Optional[float] = None
        self.last_deassert_time: Optional[float] = None

    # ---- state --------------------------------------------------------- #
    @property
    def active_level(self) -> int:
        return 0 if self.active_low else 1

    @property
    def is_asserted(self) -> Optional[bool]:
        """True/False, or None when the signal is X/Z."""
        v = self.read()
        return None if v is None else v == self.active_level

    @property
    def last_duration(self) -> Optional[float]:
        return self.durations[-1] if self.durations else None

    # ---- waits --------------------------------------------------------- #
    async def wait_assert(self):
        """Wait for the next assertion (X/Z -> active counts)."""
        while True:
            await self.signal.value_change
            if self.is_asserted:
                return

    async def wait_deassert(self):
        """Wait for the next deassertion (active -> inactive)."""
        while True:
            await self.signal.value_change
            if self.is_asserted is False:
                return

    async def wait_asserted(self):
        """Return immediately if currently asserted, else wait for assertion."""
        while not self.is_asserted:
            await self.signal.value_change

    async def wait_deasserted(self):
        """Return immediately if currently deasserted, else wait for deassertion."""
        while self.is_asserted is not False:
            await self.signal.value_change

    # ---- hooks --------------------------------------------------------- #
    def _classify(self, v: Optional[int]) -> Optional[bool]:
        return None if v is None else v == self.active_level

    def _do_assert(self, old, new, t):
        self.assert_count += 1
        self.assert_times.append(t)
        self.last_assert_time = t
        self.log.debug("%s asserted at %.3f ns", self.name, t)
        self._fire("assert", old, new, t)

    def _do_deassert(self, old, new, t):
        self.last_deassert_time = t
        if self.last_assert_time is not None:
            self.durations.append(t - self.last_assert_time)
        self.log.debug("%s deasserted at %.3f ns", self.name, t)
        self._fire("deassert", old, new, t)

    def _on_start(self, value, t):
        if self._classify(value) is True:
            self._do_assert(None, value, t)

    def _on_change(self, old, new, t):
        was, now = self._classify(old), self._classify(new)
        if now is True and was is not True:
            self._do_assert(old, new, t)
        elif now is False and was is True:
            self._do_deassert(old, new, t)


# --------------------------------------------------------------------------- #
# ClockMonitor
# --------------------------------------------------------------------------- #
class ClockMonitor(BitMonitor):
    """BitMonitor that measures a clock. Times are in ns.

    expected_period_ns : if given, each rise-to-rise period is checked against it
    tolerance          : allowed fractional deviation (0.01 = 1%)
    window             : how many recent periods/high/low times to keep
    strict             : raise AssertionError (fails the test) on the first violation;
                         otherwise log a warning and record it in .violations
    """

    _MAX_STORED_VIOLATIONS = 100
    _MAX_LOGGED_VIOLATIONS = 10

    def __init__(self, signal, expected_period_ns: Optional[float] = None,
                 tolerance: float = 0.01, window: int = 1024, strict: bool = False,
                 name: Optional[str] = None, **kw):
        super().__init__(signal, name, **kw)
        self.expected_period_ns = expected_period_ns
        self.tolerance = tolerance
        self.strict = strict
        self.periods: Deque[float] = deque(maxlen=window)
        self.high_times: Deque[float] = deque(maxlen=window)
        self.low_times: Deque[float] = deque(maxlen=window)
        self.violations: List[Tuple[float, float]] = []   # (time, measured period)
        self.violation_count = 0

    # ---- measurements -------------------------------------------------- #
    @property
    def cycle_count(self) -> int:
        return self.rise_count

    @property
    def period_ns(self) -> Optional[float]:
        """Most recent period."""
        return self.periods[-1] if self.periods else None

    @property
    def avg_period_ns(self) -> Optional[float]:
        return sum(self.periods) / len(self.periods) if self.periods else None

    @property
    def freq_mhz(self) -> Optional[float]:
        p = self.avg_period_ns
        return 1000.0 / p if p else None

    @property
    def jitter_pp_ns(self) -> Optional[float]:
        """Peak-to-peak period variation over the window."""
        return (max(self.periods) - min(self.periods)) if self.periods else None

    @property
    def duty_cycle(self) -> Optional[float]:
        """Average high time / average period (0..1)."""
        if not self.high_times or not self.low_times:
            return None
        hi = sum(self.high_times) / len(self.high_times)
        lo = sum(self.low_times) / len(self.low_times)
        return hi / (hi + lo)

    def check(self):
        """Raise AssertionError if any period violation was recorded."""
        assert self.violation_count == 0, (
            f"{self.name}: {self.violation_count} period violation(s) vs expected "
            f"{self.expected_period_ns} ns +/-{self.tolerance:.1%}; first: {self.violations[:3]}")

    # ---- hooks --------------------------------------------------------- #
    def _on_rise(self, t):
        if self.prev_rise_time is not None:
            p = t - self.prev_rise_time
            self.periods.append(p)
            self._check_period(p, t)
        if self.last_fall_time is not None:
            self.low_times.append(t - self.last_fall_time)

    def _on_fall(self, t):
        if self.last_rise_time is not None:
            self.high_times.append(t - self.last_rise_time)

    def _check_period(self, p: float, t: float):
        exp = self.expected_period_ns
        if exp is None or abs(p - exp) <= self.tolerance * exp:
            return
        self.violation_count += 1
        if len(self.violations) < self._MAX_STORED_VIOLATIONS:
            self.violations.append((t, p))
        msg = f"{self.name}: period {p:.4f} ns at {t:.3f} ns, expected {exp} ns +/-{self.tolerance:.1%}"
        if self.strict:
            raise AssertionError(msg)
        if self.violation_count <= self._MAX_LOGGED_VIOLATIONS:
            self.log.warning(msg)


# --------------------------------------------------------------------------- #
# BusMonitor
# --------------------------------------------------------------------------- #
class BusMonitor(_Monitor):
    """Multi-bit signal monitor with fixed-point decoding.

    Sampling:
      clock=None : fires whenever the signal changes (Edge trigger).
      clock=clk  : samples on each `edge` ('rising' | 'falling' | 'both') of clk.
        sample='pre'  : value immediately after the clock edge, before the flops
                        update, i.e. what the DUT's registers capture (default).
        sample='post' : value after ReadOnly, i.e. the settled post-edge value.
                        Callbacks then run in the ReadOnly phase and cannot write signals.

    Events (fn(old, new, t_ns), old/new are raw unsigned ints or None for X/Z):
      'change' : sampled value differs from the previous sample
      'sample' : every clock sample (clocked mode only)
    """

    _EDGES = {"rising": RisingEdge, "falling": FallingEdge, "both": Edge}

    def __init__(self, signal, name: Optional[str] = None, clock=None,
                 edge: str = "rising", sample: str = "pre",
                 keep_history: bool = False, history_len: Optional[int] = None):
        super().__init__(name or getattr(signal, "_name", "bus"))
        if edge not in self._EDGES:
            raise ValueError(f"edge must be one of {list(self._EDGES)}")
        if sample not in ("pre", "post"):
            raise ValueError("sample must be 'pre' or 'post'")
        self.signal = signal
        self.width = len(signal)
        self.clock = clock
        self.edge = edge
        self.sample = sample

        self._cur: Optional[int] = None
        self.prev_value: Optional[int] = None
        self.change_count = 0
        self.sample_count = 0
        self.last_change_time: Optional[float] = None
        self.history: Optional[Deque[Tuple[float, Optional[int]]]] = \
            deque(maxlen=history_len) if keep_history else None

    # ---- raw reads ----------------------------------------------------- #
    def read(self) -> Optional[int]:
        """Live raw value as an unsigned int, or None if any bit is X/Z."""
        v = self.signal.value
        return int(v) if v.is_resolvable else None

    @property
    def is_resolvable(self) -> bool:
        return self.signal.value.is_resolvable

    @property
    def unsigned(self) -> Optional[int]:
        return self.read()

    @property
    def signed(self) -> Optional[int]:
        """Two's complement interpretation over the full bus width."""
        return self.to_signed(self.read(), self.width)

    @staticmethod
    def to_signed(raw: Optional[int], width: int) -> Optional[int]:
        if raw is None:
            return None
        raw &= (1 << width) - 1
        return raw - (1 << width) if raw >> (width - 1) else raw

    def bit(self, i: int, raw: Optional[int] = None) -> Optional[int]:
        raw = self.read() if raw is None else raw
        return None if raw is None else (raw >> i) & 1

    def bits(self, msb: int, lsb: int = 0, raw: Optional[int] = None) -> Optional[int]:
        """Unsigned bit-field [msb:lsb] (inclusive), like Verilog sig[msb:lsb]."""
        if not (0 <= lsb <= msb < self.width):
            raise ValueError(f"bad field [{msb}:{lsb}] for {self.width}-bit bus")
        raw = self.read() if raw is None else raw
        return None if raw is None else (raw >> lsb) & ((1 << (msb - lsb + 1)) - 1)

    # ---- fixed point --------------------------------------------------- #
    def _q_bits(self, fmt: QSpec, lsb: int, strict: bool, raw: Optional[int]):
        fmt = _as_qformat(fmt)
        n = fmt.total_bits
        if strict and lsb == 0 and n != self.width:
            raise ValueError(
                f"{fmt} is {n} bits but {self.name} is {self.width} wide. Check the sign "
                f"convention (QFormat.sign_in_int), or pass strict=False / lsb=... "
                f"to decode a sub-field.")
        if lsb < 0 or lsb + n > self.width:
            raise ValueError(f"{fmt} ({n} bits) at lsb={lsb} does not fit in {self.width}-bit bus")
        raw = self.read() if raw is None else raw
        return fmt, (None if raw is None else (raw >> lsb) & ((1 << n) - 1))

    def as_q(self, fmt: QSpec, lsb: int = 0, strict: bool = True,
             raw: Optional[int] = None) -> Optional[int]:
        """Decode as fixed point, returned as a scaled int (real value = result / 2**frac_bits).

        fmt    : QFormat or a string such as 'Q3.15' / 'UQ0.16'
        lsb    : LSB position of the field within the bus (default 0)
        strict : require fmt.total_bits == bus width when lsb == 0
        raw    : decode this captured raw value instead of reading the signal now
        Returns None if any bit is X/Z.
        """
        fmt, bits = self._q_bits(fmt, lsb, strict, raw)
        return None if bits is None else fmt.from_bits(bits)

    def as_float(self, fmt: QSpec, lsb: int = 0, strict: bool = True,
                 raw: Optional[int] = None) -> Optional[float]:
        fmt = _as_qformat(fmt)
        s = self.as_q(fmt, lsb, strict, raw)
        return None if s is None else fmt.to_float(s)

    def q_parts(self, fmt: QSpec, lsb: int = 0, strict: bool = True,
                raw: Optional[int] = None) -> Optional[Tuple[int, int]]:
        """(integer_part, fraction_bits) with value = ip + fp / 2**frac_bits."""
        fmt = _as_qformat(fmt)
        s = self.as_q(fmt, lsb, strict, raw)
        return None if s is None else fmt.split(s)

    # ---- waits --------------------------------------------------------- #
    async def wait_change(self):
        """Wait for the signal to change (unclocked), or for the next changed sample (clocked)."""
        if self.clock is None:
            await self.signal.value_change
            return
        last = self.read()
        while True:
            await self._wait_clock()
            if self.read() != last:
                return

    async def wait_value(self, raw: int):
        """Return once the bus equals raw (immediately if it already does)."""
        while self.read() != raw:
            if self.clock is None:
                await self.signal.value_change
            else:
                await self._wait_clock()

    async def _wait_clock(self):
        await self._EDGES[self.edge](self.clock)
        if self.sample == "post":
            await ReadOnly()

    # ---- main loop ----------------------------------------------------- #
    def _record(self, t, v):
        if self.history is not None:
            self.history.append((t, v))

    async def _run(self):
        t = self._now()
        self._cur = self.read()
        self.last_change_time = t
        self._record(t, self._cur)

        while True:
            if self.clock is None:
                await self.signal.value_change
            else:
                await self._wait_clock()
            t = self._now()
            old, new = self._cur, self.read()

            if new != old:
                self.prev_value, self._cur = old, new
                self.change_count += 1
                self.last_change_time = t
                self._record(t, new)
            if self.clock is not None:
                self.sample_count += 1
                self._fire("sample", old, new, t)
            if new != old:
                self._fire("change", old, new, t)