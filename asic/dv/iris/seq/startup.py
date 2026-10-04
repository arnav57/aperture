import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from dv.common.uvc import ClockMonitor, ResetMonitor

async def iris_powerup_seq(dut):

    # create internal clock and reset monitors
    eth_clk_main_mon   = ClockMonitor(dut.eth_clk_main, 8, name="eth_clk_main").start()
    eth_clk_shift_mon  = ClockMonitor(dut.eth_clk_shift, 8, name="eth_clk_shift").start()
    dp_clk_mon         = ClockMonitor(dut.dp_clk, 6.67, name="dp_clk").start()
    rstn_eth_clk_mon   = ResetMonitor(dut.rstn_eth_clk, active_low=True, name="rstn_eth_clk").start()
    rstn_dp_clk_mon    = ResetMonitor(dut.rstn_dp_clk, active_low=True, name="rstn_dp_clk").start()

    # start the refclk
    cocotb.start_soon( Clock(dut.refclk_i, 20, unit="ns").start() )
    
    # reset sequence
    dut.rstn_i.value = 0
    await Timer(200, 'ns')
    dut.rstn_i.value = 1

    # wait for PLL to lock + a bit of extra time
    await RisingEdge(dut.pll_lock_o)
    await Timer(100, 'ns')