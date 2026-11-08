#!/usr/bin/env python3
"""
Send I/Q samples to the Aperture (iris) FPGA over UDP.

Wire format (matches iris_byte_align.sv and the cocotb tests):
    interleaved I0, Q0, I1, Q1, ...  as signed 16-bit BIG-endian integers
    (4 bytes per complex sample: I_hi I_lo Q_hi Q_lo)

Each UDP payload must be a multiple of 4 bytes. The aligner resets its
byte counter on every tlast (end of packet), so a payload that is not a
multiple of 4 would swap I and Q for the next packet.

Put this file in asic/scripts/ so the default data path resolves to
asic/scripts/wifi/wifi_iq.bin, or pass --file.

Examples:
    python send_iq.py
    python send_iq.py --loop 10 --gap-us 20
    python send_iq.py --tone 1.0e6 --samples 20000
    python send_iq.py --file my_iq.bin --src-ip 192.168.1.100
"""

import argparse
import socket
import sys
import time
from pathlib import Path

import numpy as np

DEFAULT_FILE = Path(__file__).resolve().parent / "wifi" / "wifi_iq.bin"
FS_HZ = 20e6  # sample rate used by gen.m (20 MSPS)


def load_iq_bytes(path: Path) -> bytes:
    """Load an int16 big-endian interleaved IQ file as raw bytes (already on-wire format)."""
    data = np.fromfile(path, dtype=">i2")
    if data.size < 2:
        sys.exit(f"{path}: no samples found")
    data = data[: data.size - (data.size % 2)]  # whole I/Q pairs only
    return data.tobytes()


def make_tone(freq_hz: float, n_samples: int, amplitude: float = 0.5) -> bytes:
    """Complex tone at freq_hz (sampled at FS_HZ) as on-wire bytes."""
    n = np.arange(n_samples)
    x = amplitude * np.exp(2j * np.pi * freq_hz / FS_HZ * n)
    scale = 2**15 - 1
    iq = np.empty(2 * n_samples, dtype=">i2")
    iq[0::2] = np.round(x.real * scale)
    iq[1::2] = np.round(x.imag * scale)
    return iq.tobytes()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", type=Path, default=DEFAULT_FILE, help="int16 big-endian interleaved IQ file")
    ap.add_argument("--ip", default="192.168.1.128", help="FPGA IP (default: %(default)s)")
    ap.add_argument("--port", type=int, default=6000, help="UDP destination port (default: %(default)s)")
    ap.add_argument("--src-ip", default="192.168.1.100", help="PC IP to bind to; '' = let the OS choose")
    ap.add_argument("--src-port", type=int, default=5000, help="UDP source port (default: %(default)s)")
    ap.add_argument("--pkt-bytes", type=int, default=512, help="payload bytes per packet, multiple of 4 (default: %(default)s)")
    ap.add_argument("--gap-us", type=float, default=0.0, help="busy-wait between packets in microseconds (default: 0)")
    ap.add_argument("--loop", type=int, default=1, help="send the whole stream this many times (default: 1)")
    ap.add_argument("--tone", type=float, default=None, metavar="HZ", help="send a complex test tone instead of --file")
    ap.add_argument("--samples", type=int, default=20000, help="samples for --tone (default: %(default)s)")
    args = ap.parse_args()

    if args.pkt_bytes % 4 or args.pkt_bytes <= 0:
        sys.exit("--pkt-bytes must be a positive multiple of 4")
    if args.pkt_bytes > 1472:
        sys.exit("--pkt-bytes must be <= 1472 (single Ethernet frame, no IP fragmentation)")

    raw = make_tone(args.tone, args.samples) if args.tone is not None else load_iq_bytes(args.file)
    raw = raw[: len(raw) - (len(raw) % 4)]
    n_samples = len(raw) // 4
    n_packets = -(-len(raw) // args.pkt_bytes)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    if args.src_ip:
        sock.bind((args.src_ip, args.src_port))
    dest = (args.ip, args.port)

    print(f"Sending {n_samples} samples ({len(raw)} bytes) as {n_packets} packets of up to "
          f"{args.pkt_bytes} B to {args.ip}:{args.port}, x{args.loop}")

    t0 = time.perf_counter()
    sent_pkts = 0
    for _ in range(args.loop):
        for off in range(0, len(raw), args.pkt_bytes):
            sock.sendto(raw[off:off + args.pkt_bytes], dest)
            sent_pkts += 1
            if args.gap_us > 0:
                end = time.perf_counter() + args.gap_us * 1e-6
                while time.perf_counter() < end:
                    pass
    dt = time.perf_counter() - t0

    total = len(raw) * args.loop
    print(f"Done: {sent_pkts} packets, {total} bytes in {dt:.3f} s ({total * 8 / dt / 1e6:.1f} Mbit/s)")
    print("Note: UDP is fire-and-forget; the FPGA never replies, so confirm reception in Signal Tap / Wireshark.")


if __name__ == "__main__":
    main()
