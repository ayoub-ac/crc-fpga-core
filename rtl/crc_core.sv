// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
//
// Parametric CRC update core. Computes the next CRC register value from
// a current CRC register and an input byte by unrolling the bit-serial
// polynomial division into a single combinational step. The transform
// is the well-known "byte-parallel CRC" (Sarwate / table-free form):
//
//   for k in 0..7:
//     msb = crc_msb XOR data_msb_k
//     crc <<= 1
//     if msb: crc ^= POLY
//
// All eight bit-iterations are unrolled and reduced to a single
// combinational expression. Yosys / Vivado / Quartus / Diamond all map
// this into a flat XOR network: ~WIDTH+8 XORs in the critical path,
// dominated by the longest XOR chain.
//
// The module is purely combinational (no flops). The next-state value
// it returns is the function of (crc_in, data_in) that the top-level
// register samples on each accepted byte.
//
// REFIN handling: when REFIN = 1 the input byte is bit-reversed before
// being XORed into the high byte of the running CRC. This matches the
// "reflected" form used by CRC-32, CRC-32C, CRC-16-CCITT (X.25) and
// CRC-16-IBM (Modbus). The reflection is a no-cost permutation in
// hardware (just a wire swap, zero LUTs).
//
// REFOUT and XOROUT live in the top wrapper (`crc_top.sv`); this
// module is the per-byte update kernel only.

module crc_core #(
  parameter int          WIDTH = 32,
  parameter logic [31:0] POLY  = 32'h04C11DB7,  // CRC-32 (Ethernet)
  parameter bit          REFIN = 1'b1
) (
  input  logic [WIDTH-1:0] crc_in,
  input  logic [7:0]       data_in,
  output logic [WIDTH-1:0] crc_out
);

  // Reflect the data byte if REFIN=1 (reverse bit order). Compile-time
  // constant: synthesised away to a wire permutation.
  logic [7:0] data_post_refl;
  always_comb begin
    if (REFIN) begin
      for (int i = 0; i < 8; i++) data_post_refl[i] = data_in[7-i];
    end else begin
      data_post_refl = data_in;
    end
  end

  // Bit-serial unroll. Eight chained steps, each conditionally XORing
  // POLY when the (CRC msb XOR data bit) is 1. The most-significant bit
  // of data_post_refl is consumed first - this is the canonical form
  // when REFIN=0; when REFIN=1 the data byte has already been
  // bit-reversed so the original LSB is now the MSB and is therefore
  // consumed first, matching the reflected CRC convention.
  //
  // Eight separately-named wires (rather than an unpacked array) so
  // the synthesiser - and Verilator's UNOPTFLAT analysis - sees a
  // strictly forward-only DAG.
  logic [WIDTH-1:0] crc_s0, crc_s1, crc_s2, crc_s3,
                    crc_s4, crc_s5, crc_s6, crc_s7, crc_s8;

  function automatic logic [WIDTH-1:0] step(input logic [WIDTH-1:0] crc,
                                            input logic              bit_in);
    logic              msb;
    logic [WIDTH-1:0]  shifted;
    msb     = crc[WIDTH-1] ^ bit_in;
    shifted = {crc[WIDTH-2:0], 1'b0};
    step    = msb ? (shifted ^ POLY[WIDTH-1:0]) : shifted;
  endfunction

  assign crc_s0 = crc_in;
  assign crc_s1 = step(crc_s0, data_post_refl[7]);
  assign crc_s2 = step(crc_s1, data_post_refl[6]);
  assign crc_s3 = step(crc_s2, data_post_refl[5]);
  assign crc_s4 = step(crc_s3, data_post_refl[4]);
  assign crc_s5 = step(crc_s4, data_post_refl[3]);
  assign crc_s6 = step(crc_s5, data_post_refl[2]);
  assign crc_s7 = step(crc_s6, data_post_refl[1]);
  assign crc_s8 = step(crc_s7, data_post_refl[0]);

  assign crc_out = crc_s8;

endmodule
