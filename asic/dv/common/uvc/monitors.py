import cocotb
from cocotb.triggers import Edge, RisingEdge, FallingEdge, Event
from cocotb.utils import get_sim_time

class BitMonitor:
	"""Tracks a single-bit signal: current value, edge history, callbacks."""

	def __init__(self, signal, name=None):
		self.signal = signal
		self.name = name or signal._name
		self.log = cocotb.log.getChild(self.name)
		self._task = None
		self._callbacks = {"rise": [], "fall": [], "any": []}
		self.rise_count = 0
		self.fall_count = 0
		self.last_change_time = None    # TODO: units (ns? ps?)

	# --- public API
	@property
	def value(self) -> int:
		# TODO: handle X/Z (raise? return None?)
		return int(self.signal.value)

	def on(self, event: str, fn):
		"""event: 'rise' | 'fall' | 'any'"""
		self._callbacks[event].append(fn)

	def start(self):
		self._task = cocotb.start_soon(self._run())

	def stop(self):
		if self._task is not None:
			self._task.cancel()
			self._task = None

	# --- internals
	async def _run(self):
		prev = self.value
		while True:
			await Edge(self.signal)
			new = self.value
			now = get_sim_time("ns")
			# TODO: update counters, classify rise/fall, call self._on_rise() /
			#       self._on_fall() hooks, then fire registered callbacks
			self.last_change_time = now
			prev = new

	# hooks for subclasses
	def _on_rise(self, t): ...
	def _on_fall(self, t): ...