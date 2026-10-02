import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from dv.common.uvc import ClockMonitor, ResetMonitor

async def acf_stf_init_seq(dut):
    rst_mon = ResetMonitor(dut.rstn_i, active_low=True, name="acf_rst").start()
    clk_mon = ClockMonitor(dut.clk_i, 10, name="acf_clk").start()
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())

    dut.I_i.value = 0
    dut.Q_i.value = 0

    dut.rstn_i.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.rstn_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.rstn_i.value = 1

    for _ in range(5):
        await RisingEdge(dut.clk_i)