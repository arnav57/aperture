import cocotb

from dv.acf.seq import acf_stf_init_seq


@cocotb.test()
async def stf_base_test(dut):
    await acf_stf_init_seq(dut)
    
