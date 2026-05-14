// SPDX-License-Identifier: GPL-3.0-or-later OR Commercial
//
// Functional coverage collector. Sticky bins set across the regression;
// the C++ harness reads them via `verilator public` flat-RW to print a
// final summary.
//
// Bins (12 total - exceeds the >=6 spec gate):
//   c_w32_eth          : DUT 0 ran a session (CRC-32 Ethernet)
//   c_w32_iscsi        : DUT 1 ran a session (CRC-32C iSCSI)
//   c_w16_x25          : DUT 2 ran a session (CRC-16-CCITT X.25)
//   c_w16_modbus       : DUT 3 ran a session (CRC-16-IBM Modbus)
//   c_w8_can           : DUT 4 ran a session (CRC-8 CAN)
//   c_refl_on          : at least one session with REFIN=1 (DUTs 0..3)
//   c_refl_off         : at least one session with REFIN=0 (DUT 4)
//   c_xorout_nonzero   : at least one session with XOROUT != 0
//   c_xorout_zero      : at least one session with XOROUT = 0 (DUTs 3, 4)
//   c_word_path        : DUT 0 word-mode handshake observed
//   c_byte_path        : DUT 0 byte-mode handshake observed
//   c_word_partial     : DUT 0 word-mode last beat with byte_count < 4

module crc_cov (
  input logic        clk_i,
  input logic        rst_ni,
  input logic        d0_init_i,
  input logic        d0_byte_valid_i,
  input logic        d0_byte_ready_o,
  input logic        d0_byte_last_i,
  input logic        d0_word_valid_i,
  input logic        d0_word_ready_o,
  input logic [2:0]  d0_word_byte_count_i,
  input logic        d0_word_last_i,
  input logic        d0_crc_valid_o,
  input logic        d1_init_i,
  input logic        d1_crc_valid_o,
  input logic        d2_init_i,
  input logic        d2_crc_valid_o,
  input logic        d3_init_i,
  input logic        d3_crc_valid_o,
  input logic        d4_init_i,
  input logic        d4_crc_valid_o
);

  logic c_w32_eth        /*verilator public*/;
  logic c_w32_iscsi      /*verilator public*/;
  logic c_w16_x25        /*verilator public*/;
  logic c_w16_modbus     /*verilator public*/;
  logic c_w8_can         /*verilator public*/;
  logic c_refl_on        /*verilator public*/;
  logic c_refl_off       /*verilator public*/;
  logic c_xorout_nonzero /*verilator public*/;
  logic c_xorout_zero    /*verilator public*/;
  logic c_word_path      /*verilator public*/;
  logic c_byte_path      /*verilator public*/;
  logic c_word_partial   /*verilator public*/;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      // No-op: initial block sets the sticky bins.
    end else begin
      // Per-DUT session-completed bins (set when crc_valid_o goes high).
      if (d0_crc_valid_o) begin
        c_w32_eth        <= 1'b1;
        c_refl_on        <= 1'b1;
        c_xorout_nonzero <= 1'b1;
      end
      if (d1_crc_valid_o) begin
        c_w32_iscsi      <= 1'b1;
        c_refl_on        <= 1'b1;
        c_xorout_nonzero <= 1'b1;
      end
      if (d2_crc_valid_o) begin
        c_w16_x25        <= 1'b1;
        c_refl_on        <= 1'b1;
        c_xorout_nonzero <= 1'b1;
      end
      if (d3_crc_valid_o) begin
        c_w16_modbus     <= 1'b1;
        c_refl_on        <= 1'b1;
        c_xorout_zero    <= 1'b1;
      end
      if (d4_crc_valid_o) begin
        c_w8_can         <= 1'b1;
        c_refl_off       <= 1'b1;
        c_xorout_zero    <= 1'b1;
      end

      // DUT 0 ingress-mode bins
      if (d0_byte_valid_i && d0_byte_ready_o) c_byte_path <= 1'b1;
      if (d0_word_valid_i && d0_word_ready_o) begin
        c_word_path <= 1'b1;
        if (d0_word_last_i && d0_word_byte_count_i != 3'd4) c_word_partial <= 1'b1;
      end
    end
  end

  initial begin
    c_w32_eth        = 1'b0;
    c_w32_iscsi      = 1'b0;
    c_w16_x25        = 1'b0;
    c_w16_modbus     = 1'b0;
    c_w8_can         = 1'b0;
    c_refl_on        = 1'b0;
    c_refl_off       = 1'b0;
    c_xorout_nonzero = 1'b0;
    c_xorout_zero    = 1'b0;
    c_word_path      = 1'b0;
    c_byte_path      = 1'b0;
    c_word_partial   = 1'b0;
  end

endmodule
