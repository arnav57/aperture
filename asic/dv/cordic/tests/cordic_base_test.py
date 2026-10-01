import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def cordic_base_test(dut):
    cocotb.start_soon(Clock(dut.clk_i, 10, unit="ns").start())
    dut.rstn_i.value = 1
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.rstn_i.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk_i)
    dut.rstn_i.value = 1

    for _ in range(100):
        await RisingEdge(dut.clk_i)



    
