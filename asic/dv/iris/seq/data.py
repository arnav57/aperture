import cocotb, os
import numpy as np
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from dv.common.uvc import ClockMonitor, ResetMonitor

from cocotbext.eth import GmiiFrame, RgmiiPhy
from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP

from .startup import iris_powerup_seq


async def iris_send_packet(vphy, data):

    pkt = (Ether(src="00:11:22:33:44:55", dst="02:00:00:00:00:00")
    / IP(src="192.168.1.100", dst="192.168.1.128")
    / UDP(sport=5000, dport=6000)
    / bytes(data))

    await vphy.rx.send(GmiiFrame.from_payload(bytes(pkt)))