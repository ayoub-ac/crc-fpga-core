// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
//
// Top-level testbench wrapper for crc_top. Five DUT instances cover the
// five named standards (CRC-32 Ethernet, CRC-32C iSCSI, CRC-16-CCITT
// X.25, CRC-16-IBM Modbus, CRC-8 CAN). The C++ harness drives each
// instance through its own port set and compares against Python crcmod
// reference vectors.
//
// All five instances share clk_i and rst_ni; each has its own
// init_i / byte_* / word_* / finalize_i ports.

module crc_tb (
  input  logic        clk_i,
  input  logic        rst_ni,

  // ---- DUT 0: CRC-32 Ethernet (WIDTH=32, with WORD_PARALLEL=1) ----
  input  logic        d0_init_i,
  output logic        d0_init_ready_o,
  input  logic        d0_byte_valid_i,
  input  logic [7:0]  d0_byte_i,
  input  logic        d0_byte_last_i,
  output logic        d0_byte_ready_o,
  input  logic        d0_word_valid_i,
  input  logic [31:0] d0_word_i,
  input  logic [2:0]  d0_word_byte_count_i,
  input  logic        d0_word_last_i,
  output logic        d0_word_ready_o,
  input  logic        d0_finalize_i,
  output logic        d0_crc_valid_o,
  output logic [31:0] d0_crc_o,
  output logic [31:0] d0_byte_count_o,

  // ---- DUT 1: CRC-32C iSCSI (WIDTH=32) ----
  input  logic        d1_init_i,
  output logic        d1_init_ready_o,
  input  logic        d1_byte_valid_i,
  input  logic [7:0]  d1_byte_i,
  input  logic        d1_byte_last_i,
  output logic        d1_byte_ready_o,
  input  logic        d1_finalize_i,
  output logic        d1_crc_valid_o,
  output logic [31:0] d1_crc_o,
  output logic [31:0] d1_byte_count_o,

  // ---- DUT 2: CRC-16-CCITT X.25 (WIDTH=16) ----
  input  logic        d2_init_i,
  output logic        d2_init_ready_o,
  input  logic        d2_byte_valid_i,
  input  logic [7:0]  d2_byte_i,
  input  logic        d2_byte_last_i,
  output logic        d2_byte_ready_o,
  input  logic        d2_finalize_i,
  output logic        d2_crc_valid_o,
  output logic [15:0] d2_crc_o,
  output logic [31:0] d2_byte_count_o,

  // ---- DUT 3: CRC-16-IBM Modbus (WIDTH=16) ----
  input  logic        d3_init_i,
  output logic        d3_init_ready_o,
  input  logic        d3_byte_valid_i,
  input  logic [7:0]  d3_byte_i,
  input  logic        d3_byte_last_i,
  output logic        d3_byte_ready_o,
  input  logic        d3_finalize_i,
  output logic        d3_crc_valid_o,
  output logic [15:0] d3_crc_o,
  output logic [31:0] d3_byte_count_o,

  // ---- DUT 4: CRC-8 CAN (WIDTH=8) ----
  input  logic        d4_init_i,
  output logic        d4_init_ready_o,
  input  logic        d4_byte_valid_i,
  input  logic [7:0]  d4_byte_i,
  input  logic        d4_byte_last_i,
  output logic        d4_byte_ready_o,
  input  logic        d4_finalize_i,
  output logic        d4_crc_valid_o,
  output logic [7:0]  d4_crc_o,
  output logic [31:0] d4_byte_count_o
);

  // ===================================================================
  // DUT 0 - CRC-32 Ethernet, with optional 32-bit-parallel ingress.
  // ===================================================================
  crc_top #(
    .WIDTH(32),
    .POLY (32'h04C11DB7),
    .INIT (32'hFFFFFFFF),
    .REFIN (1'b1),
    .REFOUT(1'b1),
    .XOROUT(32'hFFFFFFFF),
    .WORD_PARALLEL(1'b1)
  ) u_dut0 (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .init_i           (d0_init_i),
    .init_ready_o     (d0_init_ready_o),
    .byte_valid_i     (d0_byte_valid_i),
    .byte_i           (d0_byte_i),
    .byte_last_i      (d0_byte_last_i),
    .byte_ready_o     (d0_byte_ready_o),
    .word_valid_i     (d0_word_valid_i),
    .word_i           (d0_word_i),
    .word_byte_count_i(d0_word_byte_count_i),
    .word_last_i      (d0_word_last_i),
    .word_ready_o     (d0_word_ready_o),
    .finalize_i       (d0_finalize_i),
    .crc_valid_o      (d0_crc_valid_o),
    .crc_o            (d0_crc_o),
    .byte_count_o     (d0_byte_count_o)
  );

  // ===================================================================
  // DUT 1 - CRC-32C iSCSI.
  // ===================================================================
  logic d1_unused_word_ready;
  crc_top #(
    .WIDTH(32),
    .POLY (32'h1EDC6F41),
    .INIT (32'hFFFFFFFF),
    .REFIN (1'b1),
    .REFOUT(1'b1),
    .XOROUT(32'hFFFFFFFF),
    .WORD_PARALLEL(1'b0)
  ) u_dut1 (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .init_i           (d1_init_i),
    .init_ready_o     (d1_init_ready_o),
    .byte_valid_i     (d1_byte_valid_i),
    .byte_i           (d1_byte_i),
    .byte_last_i      (d1_byte_last_i),
    .byte_ready_o     (d1_byte_ready_o),
    .word_valid_i     (1'b0),
    .word_i           (32'd0),
    .word_byte_count_i(3'd0),
    .word_last_i      (1'b0),
    .word_ready_o     (d1_unused_word_ready),
    .finalize_i       (d1_finalize_i),
    .crc_valid_o      (d1_crc_valid_o),
    .crc_o            (d1_crc_o),
    .byte_count_o     (d1_byte_count_o)
  );

  // ===================================================================
  // DUT 2 - CRC-16-CCITT X.25.
  // ===================================================================
  logic d2_unused_word_ready;
  logic [15:0] d2_crc_w;
  crc_top #(
    .WIDTH(16),
    .POLY (32'h00001021),
    .INIT (32'h0000FFFF),
    .REFIN (1'b1),
    .REFOUT(1'b1),
    .XOROUT(32'h0000FFFF),
    .WORD_PARALLEL(1'b0)
  ) u_dut2 (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .init_i           (d2_init_i),
    .init_ready_o     (d2_init_ready_o),
    .byte_valid_i     (d2_byte_valid_i),
    .byte_i           (d2_byte_i),
    .byte_last_i      (d2_byte_last_i),
    .byte_ready_o     (d2_byte_ready_o),
    .word_valid_i     (1'b0),
    .word_i           (32'd0),
    .word_byte_count_i(3'd0),
    .word_last_i      (1'b0),
    .word_ready_o     (d2_unused_word_ready),
    .finalize_i       (d2_finalize_i),
    .crc_valid_o      (d2_crc_valid_o),
    .crc_o            (d2_crc_w),
    .byte_count_o     (d2_byte_count_o)
  );
  assign d2_crc_o = d2_crc_w;

  // ===================================================================
  // DUT 3 - CRC-16-IBM Modbus.
  // ===================================================================
  logic d3_unused_word_ready;
  logic [15:0] d3_crc_w;
  crc_top #(
    .WIDTH(16),
    .POLY (32'h00008005),
    .INIT (32'h0000FFFF),
    .REFIN (1'b1),
    .REFOUT(1'b1),
    .XOROUT(32'h00000000),
    .WORD_PARALLEL(1'b0)
  ) u_dut3 (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .init_i           (d3_init_i),
    .init_ready_o     (d3_init_ready_o),
    .byte_valid_i     (d3_byte_valid_i),
    .byte_i           (d3_byte_i),
    .byte_last_i      (d3_byte_last_i),
    .byte_ready_o     (d3_byte_ready_o),
    .word_valid_i     (1'b0),
    .word_i           (32'd0),
    .word_byte_count_i(3'd0),
    .word_last_i      (1'b0),
    .word_ready_o     (d3_unused_word_ready),
    .finalize_i       (d3_finalize_i),
    .crc_valid_o      (d3_crc_valid_o),
    .crc_o            (d3_crc_w),
    .byte_count_o     (d3_byte_count_o)
  );
  assign d3_crc_o = d3_crc_w;

  // ===================================================================
  // DUT 4 - CRC-8 CAN / SAE J1850 zero.
  // ===================================================================
  logic d4_unused_word_ready;
  logic [7:0] d4_crc_w;
  crc_top #(
    .WIDTH(8),
    .POLY (32'h00000007),
    .INIT (32'h00000000),
    .REFIN (1'b0),
    .REFOUT(1'b0),
    .XOROUT(32'h00000000),
    .WORD_PARALLEL(1'b0)
  ) u_dut4 (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .init_i           (d4_init_i),
    .init_ready_o     (d4_init_ready_o),
    .byte_valid_i     (d4_byte_valid_i),
    .byte_i           (d4_byte_i),
    .byte_last_i      (d4_byte_last_i),
    .byte_ready_o     (d4_byte_ready_o),
    .word_valid_i     (1'b0),
    .word_i           (32'd0),
    .word_byte_count_i(3'd0),
    .word_last_i      (1'b0),
    .word_ready_o     (d4_unused_word_ready),
    .finalize_i       (d4_finalize_i),
    .crc_valid_o      (d4_crc_valid_o),
    .crc_o            (d4_crc_w),
    .byte_count_o     (d4_byte_count_o)
  );
  assign d4_crc_o = d4_crc_w;

  // ===================================================================
  // Bind assertions and coverage to DUT 0 (the most-exercised instance).
  // ===================================================================
  crc_assertions u_assert (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .init_i       (d0_init_i),
    .init_ready_o (d0_init_ready_o),
    .byte_valid_i (d0_byte_valid_i),
    .byte_ready_o (d0_byte_ready_o),
    .byte_last_i  (d0_byte_last_i),
    .finalize_i   (d0_finalize_i),
    .crc_valid_o  (d0_crc_valid_o),
    .crc_o        (d0_crc_o),
    .byte_count_o (d0_byte_count_o)
  );

  crc_cov u_cov (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .d0_init_i           (d0_init_i),
    .d0_byte_valid_i     (d0_byte_valid_i),
    .d0_byte_ready_o     (d0_byte_ready_o),
    .d0_byte_last_i      (d0_byte_last_i),
    .d0_word_valid_i     (d0_word_valid_i),
    .d0_word_ready_o     (d0_word_ready_o),
    .d0_word_byte_count_i(d0_word_byte_count_i),
    .d0_word_last_i      (d0_word_last_i),
    .d0_crc_valid_o      (d0_crc_valid_o),
    .d1_init_i           (d1_init_i),
    .d1_crc_valid_o      (d1_crc_valid_o),
    .d2_init_i           (d2_init_i),
    .d2_crc_valid_o      (d2_crc_valid_o),
    .d3_init_i           (d3_init_i),
    .d3_crc_valid_o      (d3_crc_valid_o),
    .d4_init_i           (d4_init_i),
    .d4_crc_valid_o      (d4_crc_valid_o)
  );

endmodule
