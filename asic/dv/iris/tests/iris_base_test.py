import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from dv.iris.seq import iris_powerup_seq
from dv.common.uvc import ClockMonitor, ResetMonitor

from cocotbext.eth import GmiiFrame, RgmiiPhy
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP


@cocotb.test()
async def iris_base_test(dut):

    # top level monitors
    refclk_mon = ClockMonitor(dut.refclk_i, 20, name="refclk").start()
    rstn_mon   = ResetMonitor(dut.rstn_i, active_low=True, name="rstn").start()

    # create a Virtual PHY for ENET1
    enet1_phy = RgmiiPhy(
        dut.ENET1_TX_DATA, dut.ENET1_TX_EN, dut.ENET1_GTX_CLK,   # from DUT -> Virtual PHY
        dut.ENET1_RX_DATA, dut.ENET1_RX_DV, dut.ENET1_RX_CLK,    # from Virtual PHY -> DUT
        speed=1e9,                                               # Gigabit Ethernet 
    )

    await iris_powerup_seq(dut)

    pkt = (Ether(src="00:11:22:33:44:55", dst="02:00:00:00:00:00")
    / IP(src="192.168.1.100", dst="192.168.1.128")
    / UDP(sport=5000, dport=6000)
    / bytes(range(32)))

    await enet1_phy.rx.send(GmiiFrame.from_payload(bytes(pkt)))

    await Timer(5, 'us')




  