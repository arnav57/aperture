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

    await iris_powerup_seq(dut)

    await Timer(5, 'us')




  