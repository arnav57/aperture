import cocotb

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def ethernet_init_seq(dut):
    cocotb.start_soon(Clock(dut.clk_125_i, 8, unit="ns").start())

    async def clk90():
        await Timer(2, "ns")
        await Clock(dut.clk_125_90_i, 8, unit="ns").start()
    cocotb.start_soon(clk90())

    cocotb.start_soon(Clock(dut.compute_clk_i, 10, unit="ns").start())
    # no clock on ENET1_RX_CLK: RgmiiPhy drives it

    # tie off the stream inputs
    dut.udp_rx_tready.value = 1
    dut.udp_tx_tdata.value  = 0
    dut.udp_tx_tvalid.value = 0
    dut.udp_tx_tlast.value  = 0
    dut.udp_tx_tuser.value  = 0

    dut.rstn_clk_125_i.value     = 0
    dut.rstn_compute_clk_i.value = 0
    await Timer(200, "ns")
    dut.rstn_clk_125_i.value     = 1
    dut.rstn_compute_clk_i.value = 1
    await Timer(500, "ns")   # let the MAC see some idle cycles


  