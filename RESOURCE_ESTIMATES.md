# Resource estimates

Numbers below are from Yosys 0.x generic synthesis (`make synth_report`).
They are pre-place-and-route. See `SYNTH_REPORT.md` for the most recent
run; this document explains what dominates the area and how to shrink
or extend it.

## Summary (post-Yosys, pre-PnR)

| Target                         | Comment |
|--------------------------------|---------|
| Lattice iCE40 UP5K             | LUT4-light: per-byte XOR network plus a WIDTH-bit register and 32-bit byte counter. Fits comfortably on the UP5K (5280 logic tiles). |
| Lattice ECP5 LFE5UM-25         | LUT4 dominates the byte-update kernel. nextpnr-ecp5 packs tighter than the Yosys-generic estimate; vendor (Diamond) tighter still. |
| Xilinx Artix-7 XC7A35T         | Yosys-generic synthesis here counts LUT6 + CARRY4. Vivado synth_design typically maps the per-byte XOR to a single LUT6 layer. |
| Cyclone V 5CSEMA5F31C6         | Quartus packs the byte-update XOR network into ALMs efficiently; ALM count is typically lower than the Yosys soft estimate. |
| Gowin GW1NR-9 (Tang Nano 9K)   | Not characterised here. Gowin's vendor flow handles the design without issue. |

For exact LUT/FF/BRAM numbers run `make synth_report` and read
`SYNTH_REPORT.md`. The synthesis-comparison report is regenerated on
every CI build.

## What dominates the area

- **Per-byte XOR network (`crc_core`)**: eight chained
  bit-serial-step expressions, each conditionally XORing the
  WIDTH-bit polynomial. For WIDTH=32 the depth is 8 levels of XOR2
  and a final 32-bit XOR; Yosys / Vivado / Quartus map this into a
  flat LUT4 / LUT6 layer of roughly 32-64 LUTs depending on the
  target.
- **Running CRC register**: WIDTH FFs (8/16/32 depending on
  parameter set).
- **Output register**: WIDTH FFs (registered finalised output, so
  the consumer reads a stable value).
- **Byte counter**: 32 FFs.
- **FSM and session state**: 2 FFs for the 4-state FSM, 1 FF for
  the `crc_valid_q` flag.

For the WIDTH=32 default, total sequential cost is roughly
32 + 32 + 32 + 3 ≈ 100 FFs. The combinational cost is dominated by
the byte-update kernel.

## What you can do to shrink it

- **Use WIDTH=8 or WIDTH=16** when the application allows. CRC-8 and
  CRC-16 cores cut the per-byte XOR network and the running register
  by 4x and 2x respectively.
- **Drop `WORD_PARALLEL`** if you only need byte-rate throughput.
  This removes four `crc_core` instances (~3x LUT reduction).
- **Tie `byte_count_o` off** if the consumer doesn't need it. The
  32-bit counter accounts for ~30% of the FFs.
- **Single-bit-serial mode** (Premium): replace the unrolled 8-step
  byte kernel with a 1-step bit kernel and feed bits one at a time.
  Cuts area by ~8x at the cost of 8x latency per byte. Useful for
  ultra-tiny iCE40 LP1K projects.

## What you can do to push throughput

- **`WORD_PARALLEL = 1`**: ingest 32 bits per cycle. ~3x the LUT
  cost but 4x throughput. Already in the default tier.
- **64-bit / 128-bit parallel** (Premium): chain 8 or 16 byte
  kernels combinationally. Useful for 10G / 25G / 100G Ethernet FCS.
  Linearly scales LUT cost.
- **Pipelined kernel** (Premium): split the 8-step bit-serial
  unroll into a pipelined version where each pipeline stage holds
  one bit-step. Allows higher Fmax on deep targets at no
  steady-state throughput cost. Useful when the design's critical
  path is the CRC kernel.

## Frequency

- iCE40 UP5K, default toolchain (Yosys + nextpnr), no constraints:
  ~80-100 MHz typical for the WIDTH=32 byte-mode core.
- ECP5: ~150-180 MHz.
- Artix-7 -1 speed grade: ~250 MHz typical with Vivado, easily
  300+ MHz with WIDTH=8 or WIDTH=16.
- Cyclone V: similar to Artix-7.

The critical path for the WIDTH=32 byte-mode core is the 8-deep
XOR chain in `crc_core` plus the final XOR with POLY. For
`WORD_PARALLEL = 1` the chain is 32-deep (4 byte kernels chained)
and the maximum frequency drops by roughly 1.5-2x; rebalance with
a pipeline register between adjacent kernels if the application
demands both throughput and high Fmax.

## Power

Ballpark: 2-5 mW dynamic on iCE40 UP5K at 50 MHz, depending on
data activity. The CRC register toggles ~32 FFs per byte; the
byte counter toggles a few FFs per byte; the rest is the FSM. The
core is significantly cheaper than a full AES round in both area
and power.

## How to reproduce

```bash
make synth_report
```

This runs Yosys with `synth_ice40`, `synth_ecp5` (with `-abc9`),
and `synth_xilinx`, then `stat`, and writes the result to
`SYNTH_REPORT.md`. Vendor flows (Vivado, Quartus) are detected
automatically when on PATH.

For end-to-end place-and-route numbers (post-PnR LUT counts and
timing), run the vendor flow:

- iCE40 / ECP5: `nextpnr-ice40` / `nextpnr-ecp5` with Yosys output.
- Xilinx: Vivado with a project pointing at the `rtl/` files.
- Lattice Diamond / Radiant: project with `rtl/` added.
- Quartus: project with `rtl/` added.
