import cocotb, os
import numpy as np
from pathlib import Path

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from dv.iris.seq import iris_powerup_seq, iris_send_packet
from dv.common.uvc import ClockMonitor, ResetMonitor

from cocotbext.eth import GmiiFrame, RgmiiPhy
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP


def get_wifi_data():
    asic_scripts = os.getenv("ASIC_SCRIPTS", None)
    if asic_scripts is None:
        raise RuntimeError(f"ASIC_SCRIPTS is None!")
    
    asic_scripts = Path(asic_scripts)
    wifi_data_file = asic_scripts / 'wifi' / 'wifi_iq.bin'
    wifi_data = np.fromfile(wifi_data_file, dtype='>i2')

    return wifi_data

class IQMonitor():
    def __init__(self, dut):
        self.dut = dut
        self.samples = []

    def start(self):
        self._task = cocotb.start_soon(self._run())
        return self
    
    async def _run(self):
        core = self.dut.I_core
        while True:
            await RisingEdge(self.dut.dp_clk)
            if str(core.iq_valid.value) != "1":
                continue
            self.samples.append( (
                core.i.value.to_signed(), core.q.value.to_signed()
            ) )


async def wait_for_samples(mon, n, timeout_us=5000):
    waited = 0
    while len(mon.samples) < n and waited < timeout_us:
        await Timer(1, 'us')
        waited += 1

@cocotb.test()
async def iris_base_test(dut):

    # top level monitors
    refclk_mon = ClockMonitor(dut.refclk_i, 20, name="refclk").start()
    rstn_mon   = ResetMonitor(dut.rstn_i, active_low=True, name="rstn").start()
    iq_mon     = IQMonitor(dut).start()

    wifi_iq = get_wifi_data()
    raw_iq  = wifi_iq.tobytes()
    raw_iq  = raw_iq[: len(raw_iq) - (len(raw_iq) % 4)]

    # create a Virtual PHY for ENET1
    enet1_phy = RgmiiPhy(
        dut.ENET1_TX_DATA, dut.ENET1_TX_EN, dut.ENET1_GTX_CLK,   # from DUT -> Virtual PHY
        dut.ENET1_RX_DATA, dut.ENET1_RX_DV, dut.ENET1_RX_CLK,    # from Virtual PHY -> DUT
        speed=1e9,                                               # Gigabit Ethernet 
    )

    await iris_powerup_seq(dut)
    
    bytes_per_packet = 512
    for i in range(0, len(raw_iq), bytes_per_packet):
        await iris_send_packet(enet1_phy, raw_iq[i : i + bytes_per_packet])


    await enet1_phy.rx.wait()
    await wait_for_samples(iq_mon, len(raw_iq) // 4)

    expected = np.frombuffer(raw_iq, dtype='>i2').reshape(-1, 2).astype(np.int16)
    got      = np.array(iq_mon.samples, dtype=np.int16).reshape(-1, 2)

    n   = min( len(got), len(expected) )
    bad = np.flatnonzero( (got[:n] != expected[:n]).any(axis=1) )

    assert bad.size == 0, (
        f"{bad.size} mismatches, first at sample {bad[0]}: "
        f"got {got[bad[0]]}, expected {expected[bad[0]]}"
    )

    assert len(got) == len(expected), (
        f"got {len(got)} samples, expected {len(expected)}"
    )





  