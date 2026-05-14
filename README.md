# crc-fpga-core

[![License: GPL-3.0-or-later or commercial](https://img.shields.io/badge/license-GPL--3.0%20%7C%20commercial-blue.svg)](LICENSE.md)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)](#verification)
[![Lint](https://img.shields.io/badge/Verilator%20lint-clean-brightgreen.svg)](#build--test)

A small, parametric, synthesisable CRC engine in SystemVerilog. One
core covers CRC-8, CRC-16, CRC-32 with arbitrary polynomial, init,
input/output bit reflection, and final XOR. Five named standards are
directly verified: CRC-32 (Ethernet, ZIP, gzip), CRC-32C (iSCSI,
SCTP, Btrfs, ext4 metadata), CRC-16-CCITT (X.25, PPP, HDLC),
CRC-16-IBM (Modbus RTU), CRC-8 (CAN, NRSC-5, SAE J1850). Targets
iCE40, ECP5, Xilinx 7-series, Cyclone V, Tang Nano 9K.

Verified against Python `crcmod`: the RevEng catalogue check vector
`123456789` for each named standard plus 100 random vectors per
standard cross-checked end-to-end. No FPGA hardware required.

## What this is, and what it is not

CRCs are the standard error-detection code for link-layer framing,
packet integrity, and on-disk metadata. A CRC is **not** a
cryptographic MAC and offers no protection against an attacker who
chooses the input — but for catching random bit flips it is
universally deployed (Ethernet, USB, CAN, Modbus, NVMe, ZFS, Btrfs,
ext4 metadata, JPEG, PNG, ZIP, gzip, BZIP2, ISO 9660, ...).

This core is the datapath: feed it bytes, pulse `init_i` to start,
pulse `byte_last_i` or `finalize_i` to finalise, read the CRC out.
No tables in BRAM, no microcode — the byte-update kernel is a flat
combinational XOR network of ~230 LUT4 on iCE40 (WIDTH=32).

## Used in

| Standard                       | CRC                  |
|--------------------------------|----------------------|
| Ethernet (FCS), ZIP, gzip, PNG | CRC-32               |
| iSCSI, SCTP, Btrfs, ext4 meta  | CRC-32C              |
| X.25, PPP, HDLC                | CRC-16-CCITT         |
| Modbus RTU                     | CRC-16-IBM           |
| Bosch CAN, SAE J1850, NRSC-5   | CRC-8                |

## Quickstart

```bash
git clone https://github.com/ayoub-ac/crc-fpga-core.git
cd crc-fpga-core
make lint test            # Verilator lint + 510 cross-validated checks
make synth_report         # SYNTH_REPORT.md across iCE40/ECP5/Xilinx/Vivado/Quartus
```

Requires Verilator 5.0+, Yosys 0.30+, and Python 3 with `crcmod`.

## Architecture

`crc_top` holds the running CRC register and the FSM
(`IDLE -> BYTE -> FINAL -> DONE`). `crc_core` unrolls the eight
bit-serial polynomial-division steps into one combinational
expression — table-free, no BRAM. With `WORD_PARALLEL=1` four
kernels chain combinationally so the engine ingests 32 bits per
cycle.

Detailed handshake timing in [`PORT_DESCRIPTION.md`](PORT_DESCRIPTION.md).

## Headline numbers

Real numbers from `make synth_report` (Yosys 0.33, default params:
CRC-32 Ethernet, WIDTH=32, WORD_PARALLEL=0):

| Target           | LUT       | FF   | BRAM | Throughput          |
|------------------|-----------|------|------|---------------------|
| iCE40 UP5K       | see `SYNTH_REPORT.md` | ~100 | 0 | 1 byte/cycle |
| ECP5 LFE5UM-25   | see `SYNTH_REPORT.md` | ~100 | 0 | 1 byte/cycle |
| Xilinx Artix-7   | see `SYNTH_REPORT.md` | ~200 | 0 | 1 byte/cycle |

WORD_PARALLEL=1 lifts throughput to 4 bytes/cycle at ~3x LUT cost.
See [`RESOURCE_ESTIMATES.md`](RESOURCE_ESTIMATES.md).

## Build & test

```bash
make lint            # Verilator lint of crc_core + crc_top + tb
make test            # build and run the test suite
```

A passing run ends with `+PASS all tests passed` and exits 0.

## Verification

### Catalogue check vectors

| Standard              | Check value (input `123456789`) |
|-----------------------|---------------------------------|
| CRC-32 (Ethernet)     | `0xCBF43926`                    |
| CRC-32C (iSCSI)       | `0xE3069283`                    |
| CRC-16-CCITT (X.25)   | `0x906E`                        |
| CRC-16-IBM (Modbus)   | `0x4B37`                        |
| CRC-8 (CAN)           | `0xF4`                          |

### Random cross-validation

100 random inputs per standard (lengths 0..1024 bytes, including
empty, single-byte, 4-byte boundary) verified against
`crcmod.predefined` — 500 cross-validated checks per regression.

### SystemVerilog assertions and coverage

`tb/assertions.sv` (5 properties): byte-after-init, CRC stability,
byte-counter monotonicity, finalize-eventually-yields-output,
no-byte-during-init. `tb/cov.sv` (12 bins): each WIDTH variant
(8/16/32), REFIN on/off, XOROUT nonzero/zero, byte vs word ingest
path, partial-word ingest. The regression fails below 100% bin hit.

### Synthesis comparison

`make synth_report` runs every available toolchain and emits
[`SYNTH_REPORT.md`](SYNTH_REPORT.md). Yosys is mandatory; Vivado /
Quartus are detected and skipped when not on `$PATH`.

## Variants

| Variant                          | Use case                                          | Tier |
|----------------------------------|---------------------------------------------------|------|
| `rtl/crc_top.sv`                 | Default top: byte streaming + 32-bit parallel    | GPL  |
| `rtl/crc_core.sv`                | Per-byte combinational kernel only                | GPL  |
| `vhdl_wrapper/crc_top_vhdl.vhd`  | VHDL-2008 entity for VHDL-only designs            | All  |

## License

Dual-licensed: **GPL-3.0-or-later** for open-source; **commercial**
for closed-source products. See [`LICENSE.md`](LICENSE.md).

## Citation

```bibtex
@misc{crc-fpga-core,
  title  = {{crc-fpga-core}: a parametric CRC IP core in SystemVerilog},
  author = {Achour, Ayoub},
  year   = {2026},
  howpublished = {\url{https://github.com/ayoub-ac/crc-fpga-core}}
}
```

## Author

Ayoub Achour - [github.com/ayoub-ac](https://github.com/ayoub-ac)
