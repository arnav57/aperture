import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from dv.ethernet.seq import ethernet_init_seq
from dv.common.uvc import ClockMonitor, ResetMonitor

from cocotbext.eth import GmiiFrame, RgmiiPhy
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP


@cocotb.test()
async def ethernet_base_test(dut):

    # define monitors
    clk_125_mon     = ClockMonitor(dut.clk_125_i, 8, name="clk_125").start()
    clk_125_90_mon  = ClockMonitor(dut.clk_125_90_i, 8, name="clk_125_90").start()
    compute_clk_mon = ClockMonitor(dut.compute_clk_i, 10, name="compute_clk").start()
    rst_125_mon     = ResetMonitor(dut.rstn_clk_125_i, active_low=True, name="rstn_clk_125").start()
    rst_compute_mon = ResetMonitor(dut.rstn_compute_clk_i, active_low=True, name="rstn_compute_clk").start()

    # create the Virtual PHY
    phy = RgmiiPhy(
        dut.ENET1_TX_DATA, dut.ENET1_TX_EN, dut.ENET1_GTX_CLK,   # from DUT -> Virtual PHY
        dut.ENET1_RX_DATA, dut.ENET1_RX_DV, dut.ENET1_RX_CLK,    # from Virtual PHY -> DUT
        speed=1000e6,
    )

    # init sequence
    await ethernet_init_seq(dut)

    pkt = (Ether(src="00:11:22:33:44:55", dst="02:00:00:00:00:00")
       / IP(src="192.168.1.100", dst="192.168.1.128")
       / UDP(sport=5000, dport=6000)
       / bytes(range(32)))
    
    await phy.rx.send(GmiiFrame.from_payload(bytes(pkt)))

    await Timer(5, 'us')


  