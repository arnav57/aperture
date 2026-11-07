"""CORDIC testbench: rotation mode (sin/cos) and vectoring mode (atan2 / magnitude).

Scoreboard model
  rotation : (x_o, y_o) = K * R(z) * (x_i, y_i),  z_o ~ 0 (residual angle)
  vectoring: z_o = atan2(y_i, x_i), x_o = K * |(x_i, y_i)|, y_o ~ 0 (residual)
Formats: x/y are Q3.15 (1.0 = 32768), angles are BAR-16 (65536 = 360 deg, 32768 = 180 deg).

Timing: inputs are driven and outputs sampled on falling edges, so everything is race free.
The DUT latency is exactly NUM_STAGES clocks from en_i to valid_o, and that is checked.

vmode_i is treated as static by the DUT (it is not pipelined with the data), so the tests
only flip it when the pipe is empty. Env vars: CORDIC_SEED (default 1).

READERS NOTE: Commented Testcases take literal hours to run. Commented out for iteration speed.

"""
import math
import os
import random
from collections import deque
from dataclasses import dataclass

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from dv.common.uvc import ClockMonitor, ResetMonitor

# ---------------------------------------------------------------------------------------
# DUT configuration (keep in sync with the cordic parameters)
# ---------------------------------------------------------------------------------------
NUM_STAGES   = 14
VECTOR_WIDTH = 18
ANGLE_WIDTH  = 16

ROTATION  = 0
VECTORING = 1

ONE    = 1 << 15                  # 1.0 in Q3.15
HALF   = 1 << (ANGLE_WIDTH - 1)   # 180 deg in BAR
K      = math.prod(math.sqrt(1.0 + 2.0 ** (-2 * i)) for i in range(NUM_STAGES))  # CORDIC gain
UNIT_X = round(ONE / K)           # x input that gives cos/sin directly (y = 0)

# Tolerances (LSBs / BAR units). err = ABS + REL * scale
# The absolute terms are dominated by the >>> in each stage: an arithmetic right shift floors
# (rounds toward -inf), which gives x_o a small positive bias of up to ~10 LSB regardless of
# vector size. That is why small vectors have a large *relative* magnitude error.
ROT_XY_ABS,  ROT_XY_REL  = 12.0, 6e-4    # vs K*|v|
ROT_Z_TOL                = 4             # residual angle, BAR LSBs
VEC_ANG_ABS, VEC_ANG_REL = 6.0, 62000.0  # BAR LSBs: ABS + REL / |v|   (small vectors lose precision)
VEC_MAG_ABS, VEC_MAG_REL = 14.0, 4e-4    # vs K*|v|
VEC_Y_ABS,   VEC_Y_REL   = 10.0, 2.5e-4  # residual y, vs K*|v|
VEC_MIN_MAG              = 1000          # below this the angle is not checked (see docstring)


# ---------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------
def to_unsigned(v, bits):
    return v & ((1 << bits) - 1)


def to_signed(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def read_signed(sig, bits):
    return to_signed(int(sig.value), bits)


def clamp16(v):
    return max(-32768, min(32767, int(v)))


def bar_to_deg(z):
    return z * 180.0 / HALF


@dataclass
class Txn:
    mode: int
    x: int
    y: int
    z: int = 0
    tag: str = ""


def rot_txn(z, x=UNIT_X, y=0, tag=""):
    return Txn(ROTATION, x, y, z, tag)


def vec_txn(x, y, tag=""):
    return Txn(VECTORING, x, y, 0, tag)


# ---------------------------------------------------------------------------------------
# driver + scoreboard
# ---------------------------------------------------------------------------------------
class Harness:
    def __init__(self, dut, seed):
        self.dut = dut
        self.rng = random.Random(seed)
        self.errors = []
        self.checked = {ROTATION: 0, VECTORING: 0}
        # worst (error / tolerance) seen, 1.0 means right at the limit
        self.worst = {"rot_xy": 0.0, "rot_z": 0.0, "vec_ang": 0.0, "vec_mag": 0.0, "vec_y": 0.0}

    def _err(self, msg):
        self.errors.append(msg)

    async def run(self, txns, mode, idle_prob=0.0):
        """Issue txns (one per clock, optional random bubbles), check every output, drain."""
        dut = self.dut
        assert all(t.mode == mode for t in txns), "one mode per run (vmode_i is static)"
        await FallingEdge(dut.clk_i)
        dut.en_i.value = 0
        dut.vmode_i.value = mode  # pipe is empty here, so flipping the mode is safe

        pending, inflight = deque(txns), deque()
        limit = int(len(txns) / max(1e-9, 1.0 - idle_prob)) * 2 + 4 * NUM_STAGES + 100
        c = 0
        while True:
            if int(dut.valid_o.value):
                self._check_output(c, inflight)
            if not pending and not inflight:
                break
            if pending and self.rng.random() >= idle_prob:
                t = pending.popleft()
                dut.x_i.value = to_unsigned(t.x, VECTOR_WIDTH)
                dut.y_i.value = to_unsigned(t.y, VECTOR_WIDTH)
                dut.z_i.value = to_unsigned(t.z, ANGLE_WIDTH)
                dut.en_i.value = 1
                inflight.append((c, t))
            else:
                dut.en_i.value = 0
            c += 1
            assert c < limit, f"timeout: {len(inflight)} outputs never arrived"
            await FallingEdge(dut.clk_i)
        dut.en_i.value = 0

    def _check_output(self, c, inflight):
        dut = self.dut
        if not inflight:
            self._err(f"cycle {c}: valid_o asserted with nothing in flight")
            return
        c_in, t = inflight.popleft()
        if c - c_in != NUM_STAGES:
            self._err(f"{t}: latency {c - c_in}, expected {NUM_STAGES}")
        xo = read_signed(dut.x_o, VECTOR_WIDTH)
        yo = read_signed(dut.y_o, VECTOR_WIDTH)
        zo = read_signed(dut.z_o, ANGLE_WIDTH)
        self.checked[t.mode] += 1
        if t.mode == ROTATION:
            self._check_rot(t, xo, yo, zo)
        else:
            self._check_vec(t, xo, yo, zo)

    def _note(self, key, ratio):
        self.worst[key] = max(self.worst[key], ratio)

    def _check_rot(self, t, xo, yo, zo):
        th = t.z * math.pi / HALF
        ex = K * (t.x * math.cos(th) - t.y * math.sin(th))
        ey = K * (t.x * math.sin(th) + t.y * math.cos(th))
        tol = ROT_XY_ABS + ROT_XY_REL * K * math.hypot(t.x, t.y)
        r = max(abs(xo - ex), abs(yo - ey)) / tol
        self._note("rot_xy", r)
        self._note("rot_z", abs(zo) / ROT_Z_TOL)
        if r > 1.0:
            self._err(f"ROT {t}: got ({xo},{yo}) expected ({ex:.1f},{ey:.1f}) tol {tol:.1f}")
        if abs(zo) > ROT_Z_TOL:
            self._err(f"ROT {t}: residual z_o = {zo} BAR (|z| must be <= {ROT_Z_TOL})")

    def _check_vec(self, t, xo, yo, zo):
        mag = math.hypot(t.x, t.y)
        gm = K * mag
        # magnitude and residual y are always checked
        r_m = abs(xo - gm) / (VEC_MAG_ABS + VEC_MAG_REL * gm)
        r_y = abs(yo) / (VEC_Y_ABS + VEC_Y_REL * gm)
        self._note("vec_mag", r_m)
        self._note("vec_y", r_y)
        if r_m > 1.0:
            self._err(f"VEC {t}: x_o = {xo}, expected K*|v| = {gm:.1f}")
        if r_y > 1.0:
            self._err(f"VEC {t}: residual y_o = {yo}")
        if mag < VEC_MIN_MAG:
            return
        ang = math.atan2(t.y, t.x) * HALF / math.pi
        d = (zo - ang + HALF) % (2 * HALF) - HALF  # wrapped, so +180 and -180 compare equal
        tol = VEC_ANG_ABS + VEC_ANG_REL / mag
        self._note("vec_ang", abs(d) / tol)
        if abs(d) > tol:
            self._err(f"VEC {t}: z_o = {bar_to_deg(zo):.4f} deg, expected {bar_to_deg(ang):.4f} deg "
                      f"(err {bar_to_deg(d):.4f} deg, tol {bar_to_deg(tol):.4f})")

    def finish(self, name):
        self.dut._log.info(f"{name}: checked rot={self.checked[ROTATION]} vec={self.checked[VECTORING]}; "
                           f"worst error/tolerance: " +
                           ", ".join(f"{k}={v:.2f}" for k, v in self.worst.items()))
        for e in self.errors[:10]:
            self.dut._log.error(e)
        assert not self.errors, f"{name}: {len(self.errors)} mismatches, first: {self.errors[0]}"


# ---------------------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------------------
async def setup(dut):
    dut.vmode_i.value = ROTATION
    dut.en_i.value = 0
    dut.x_i.value = 0
    dut.y_i.value = 0
    dut.z_i.value = 0

    ResetMonitor(dut.rstn_i, active_low=True, name="cordic_rst").start()
    ClockMonitor(dut.clk_i, 10, name="cordic_clk").start()
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())

    dut.rstn_i.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.rstn_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.rstn_i.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk_i)

    seed = int(os.getenv("CORDIC_SEED", "1"))
    dut._log.info(f"seed={seed}  K={K:.6f}  UNIT_X={UNIT_X}")
    return Harness(dut, seed)


# ---------------------------------------------------------------------------------------
# tests
# ---------------------------------------------------------------------------------------
@cocotb.test()
async def cordic_base_test(dut):
    """Reset / clock bring-up, and nothing valid comes out of an idle pipe."""
    await setup(dut)
    for _ in range(100):
        await RisingEdge(dut.clk_i)
        assert int(dut.valid_o.value) == 0, "valid_o asserted with en_i low"


@cocotb.test()
async def rotation_directed(dut):
    """Fold boundaries and corner angles, unit vector and a few general vectors."""
    h = await setup(dut)
    angles = [0, 1, -1, 8192, -8192, 16383, 16384, 16385, -16383, -16384, -16385,
              24576, -24576, 32767, -32768, 32766, -32767, 18181, -18181]
    txns = [rot_txn(z, tag="unit") for z in angles]
    txns += [rot_txn(z, x=20000, y=-15000, tag="general") for z in angles]
    txns += [rot_txn(z, x=-32768, y=32767, tag="corner") for z in angles]
    await h.run(txns, ROTATION)
    h.finish("rotation_directed")


# @cocotb.test()
# async def rotation_sweep(dut):
#     """Every one of the 65536 BAR angles, unit vector (this is sin/cos of the full circle)."""
#     h = await setup(dut)
#     txns = [rot_txn(to_signed(z, ANGLE_WIDTH)) for z in range(1 << ANGLE_WIDTH)]
#     await h.run(txns, ROTATION)
#     h.finish("rotation_sweep")


@cocotb.test()
async def rotation_random(dut):
    """Random general vectors and angles, with random idle bubbles on en_i."""
    h = await setup(dut)
    r = h.rng
    txns = []
    for _ in range(200):
        mag = r.uniform(0, 32767)
        a = r.uniform(-math.pi, math.pi)
        txns.append(rot_txn(r.randrange(-HALF, HALF),
                            x=clamp16(mag * math.cos(a)), y=clamp16(mag * math.sin(a)), tag="rand"))
    await h.run(txns, ROTATION, idle_prob=0.3)
    h.finish("rotation_random")


@cocotb.test()
async def vectoring_directed(dut):
    """Axes, diagonals, +/-180 boundary, extreme corners."""
    h = await setup(dut)
    m = 16384
    pts = [(m, m), (m, -m), (-m, m), (-m, -m),
           (20000, 0), (-20000, 0), (0, 20000), (0, -20000),
           (VEC_MIN_MAG, 0), (-VEC_MIN_MAG, 0), (0, VEC_MIN_MAG), (0, -VEC_MIN_MAG),
           (30000, 1), (30000, -1), (-30000, 1), (-30000, -1), (-30000, 0),
           (32767, 0), (-32768, 0), (0, 32767), (0, -32768),
           (32767, 32767), (-32768, -32768), (-32768, 32767), (32767, -32768),
           (1, 30000), (-1, 30000), (1, -30000), (-1, -30000)]
    await h.run([vec_txn(x, y, tag="dir") for x, y in pts], VECTORING)
    h.finish("vectoring_directed")


# @cocotb.test()
# async def vectoring_sweep_angle(dut):
#     """Full circle at two radii (one at the 16-bit corner magnitude) in 1/4 degree steps."""
#     h = await setup(dut)
#     txns = []
#     for mag in (5000, 32000):
#         for i in range(1440):
#             a = -math.pi + i * (2 * math.pi / 1440)
#             txns.append(vec_txn(clamp16(mag * math.cos(a)), clamp16(mag * math.sin(a)), tag=f"r{mag}"))
#     await h.run(txns, VECTORING)
#     h.finish("vectoring_sweep_angle")


@cocotb.test()
async def vectoring_random(dut):
    """Random angle and log-uniform magnitude, with random idle bubbles on en_i."""
    h = await setup(dut)
    r = h.rng
    lo, hi = math.log(VEC_MIN_MAG), math.log(46000)
    txns = []
    for _ in range(200):
        mag = math.exp(r.uniform(lo, hi))
        a = r.uniform(-math.pi, math.pi)
        txns.append(vec_txn(clamp16(mag * math.cos(a)), clamp16(mag * math.sin(a)), tag="rand"))
    await h.run(txns, VECTORING, idle_prob=0.3)
    h.finish("vectoring_random")


@cocotb.test()
async def vectoring_small_magnitude(dut):
    """Characterization (informational, no angle check): x_o / y_o stay sane for tiny vectors."""
    h = await setup(dut)
    r = h.rng
    txns = [vec_txn(r.randint(-VEC_MIN_MAG, VEC_MIN_MAG), r.randint(-VEC_MIN_MAG, VEC_MIN_MAG), tag="small")
            for _ in range(200)]
    # only magnitude/residual checks apply below VEC_MIN_MAG; they use the same tolerances
    await h.run(txns, VECTORING)
    h.finish("vectoring_small_magnitude")


@cocotb.test()
async def mode_switch(dut):
    """Alternate modes with the pipe drained in between (vmode_i is static in the DUT)."""
    h = await setup(dut)
    r = h.rng
    for seg in range(8):
        if seg % 2 == 0:
            txns = [rot_txn(r.randrange(-HALF, HALF), tag="seg") for _ in range(200)]
            await h.run(txns, ROTATION)
        else:
            txns = []
            for _ in range(200):
                mag = r.uniform(2000, 32000)
                a = r.uniform(-math.pi, math.pi)
                txns.append(vec_txn(clamp16(mag * math.cos(a)), clamp16(mag * math.sin(a)), tag="seg"))
            await h.run(txns, VECTORING)
    h.finish("mode_switch")
