// SPDX-License-Identifier: GPL-3.0-or-later OR Commercial
//
// Parametric CRC engine top: byte-streaming + optional 32-bit-parallel
// fast path, REFOUT, XOROUT, and a finalize / coherent-output handshake.
// Supports CRC-8, CRC-16, CRC-32 with arbitrary polynomial, init, and
// reflect / xorout settings. The five named standards directly covered
// by this parameter set are CRC-32 (Ethernet, ZIP), CRC-32C (iSCSI),
// CRC-16-CCITT (X.25, PPP), CRC-16-IBM (Modbus), and CRC-8 (CAN, NRSC-5).
//
// Reference (RevEng catalogue parameter form):
//
//   width=W  poly=POLY  init=INIT  refin=REFIN  refout=REFOUT  xorout=XOROUT
//
//   Example: CRC-32 (Ethernet)
//     width=32 poly=0x04C11DB7 init=0xFFFFFFFF refin=1 refout=1 xorout=0xFFFFFFFF
//   Example: CRC-32C (iSCSI)
//     width=32 poly=0x1EDC6F41 init=0xFFFFFFFF refin=1 refout=1 xorout=0xFFFFFFFF
//   Example: CRC-16-CCITT (X.25)
//     width=16 poly=0x1021 init=0xFFFF refin=1 refout=1 xorout=0xFFFF
//   Example: CRC-16-IBM (Modbus)
//     width=16 poly=0x8005 init=0xFFFF refin=1 refout=1 xorout=0x0000
//   Example: CRC-8 (CAN / SAE J1850 zero)
//     width=8  poly=0x07 init=0x00 refin=0 refout=0 xorout=0x00
//
// Streaming protocol (one byte per accepted handshake):
//   1. Pulse `init_i` for one cycle to load INIT into the running CRC
//      register and clear the byte counter.
//   2. Stream input bytes via `byte_valid_i / byte_i / byte_last_i`.
//      Handshake: a byte is consumed when `byte_valid_i & byte_ready_o`
//      are both high on the same rising edge. `byte_ready_o` is high
//      whenever the engine is in BYTE state (not init, not finalising).
//   3. When the producer asserts `byte_last_i` together with the final
//      byte, OR pulses `finalize_i` after the last byte, the engine
//      applies REFOUT (bit-reverse the running CRC register) and XOROUT
//      and emits the result on `crc_o`.
//
// Parallel 32-bit fast path:
//   Setting WORD_PARALLEL = 1 instantiates a 4-byte-wide ingest register
//   that consumes a 32-bit word per cycle, processed as four byte updates
//   chained combinationally. `word_valid_i / word_i / word_last_i /
//   word_byte_count_i` provide the wide-bus handshake. Useful for
//   high-throughput packet pipelines (Ethernet, NVMe-TCP). Disabled by
//   default to keep the core small.
//
// Endianness:
//   - When REFIN = 1, byte 0 (the first byte of the message) is the
//     LEAST-significant byte of `word_i` (i.e. word_i[7:0]). This matches
//     packet-byte-stream conventions and Python `crcmod` / `zlib.crc32`.
//   - When REFIN = 0, byte 0 is the MOST-significant byte of `word_i`
//     (i.e. word_i[31:24]).
//   `word_byte_count_i` ranges 1..4; only the lower `count` bytes of the
//   32-bit word are consumed (the others are don't-care).

module crc_top #(
  parameter int          WIDTH         = 32,
  parameter logic [31:0] POLY          = 32'h04C11DB7,
  parameter logic [31:0] INIT          = 32'hFFFFFFFF,
  parameter bit          REFIN         = 1'b1,
  parameter bit          REFOUT        = 1'b1,
  parameter logic [31:0] XOROUT        = 32'hFFFFFFFF,
  parameter bit          WORD_PARALLEL = 1'b0
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  // Session
  input  logic                  init_i,
  output logic                  init_ready_o,

  // Byte-streaming ingress
  input  logic                  byte_valid_i,
  input  logic [7:0]            byte_i,
  input  logic                  byte_last_i,
  output logic                  byte_ready_o,

  // Optional 32-bit-parallel ingress (only active when WORD_PARALLEL=1)
  input  logic                  word_valid_i,
  input  logic [31:0]           word_i,
  input  logic [2:0]            word_byte_count_i,   // 1..4
  input  logic                  word_last_i,
  output logic                  word_ready_o,

  // Explicit finalize (alternative to byte_last_i / word_last_i)
  input  logic                  finalize_i,

  // Output
  output logic                  crc_valid_o,
  output logic [WIDTH-1:0]      crc_o,
  output logic [31:0]           byte_count_o
);

  // -------------------------------------------------------------------
  // FSM
  // -------------------------------------------------------------------
  typedef enum logic [1:0] {S_IDLE, S_BYTE, S_FINAL, S_DONE} state_t;
  state_t state_q, state_d;

  // -------------------------------------------------------------------
  // Running CRC register and byte counter
  // -------------------------------------------------------------------
  logic [WIDTH-1:0] crc_q, crc_d;
  logic [31:0]      bcount_q, bcount_d;
  logic             crc_valid_q;
  logic [WIDTH-1:0] crc_out_q;

  // -------------------------------------------------------------------
  // Single byte-update kernel (per-byte combinational network).
  // -------------------------------------------------------------------
  logic [WIDTH-1:0] crc_after_byte;

  crc_core #(.WIDTH(WIDTH), .POLY(POLY), .REFIN(REFIN)) u_byte (
    .crc_in (crc_q),
    .data_in(byte_i),
    .crc_out(crc_after_byte)
  );

  // -------------------------------------------------------------------
  // Optional 32-bit parallel chain. Four crc_core instances chained
  // combinationally; the chain is only wired into crc_d when
  // WORD_PARALLEL=1 (synthesised away otherwise).
  // -------------------------------------------------------------------
  logic [WIDTH-1:0] crc_word_chain [0:4];
  logic [7:0]       word_byte [0:3];

  // Byte order at the input of the parallel chain depends on REFIN: if
  // REFIN=1 the message-byte 0 is the LSB of word_i, else it is the MSB.
  // The chain processes message-byte 0 first, then 1, 2, 3.
  always_comb begin
    if (REFIN) begin
      word_byte[0] = word_i[7:0];
      word_byte[1] = word_i[15:8];
      word_byte[2] = word_i[23:16];
      word_byte[3] = word_i[31:24];
    end else begin
      word_byte[0] = word_i[31:24];
      word_byte[1] = word_i[23:16];
      word_byte[2] = word_i[15:8];
      word_byte[3] = word_i[7:0];
    end
  end

  generate if (WORD_PARALLEL) begin : g_word_chain
    assign crc_word_chain[0] = crc_q;
    for (genvar w = 0; w < 4; w++) begin : g_byte_in_word
      crc_core #(.WIDTH(WIDTH), .POLY(POLY), .REFIN(REFIN)) u_w (
        .crc_in (crc_word_chain[w]),
        .data_in(word_byte[w]),
        .crc_out(crc_word_chain[w+1])
      );
    end
  end else begin : g_word_unused
    // Tie chain off when not used so the synthesiser can prune it.
    assign crc_word_chain[0] = '0;
    assign crc_word_chain[1] = '0;
    assign crc_word_chain[2] = '0;
    assign crc_word_chain[3] = '0;
    assign crc_word_chain[4] = '0;
  end endgenerate

  // -------------------------------------------------------------------
  // REFOUT + XOROUT post-processing.
  // -------------------------------------------------------------------
  function automatic logic [WIDTH-1:0] refl(input logic [WIDTH-1:0] x);
    for (int i = 0; i < WIDTH; i++) refl[i] = x[WIDTH-1-i];
  endfunction

  // Finalisation acts on `crc_d` (the value being committed THIS cycle, which
  // includes the just-accepted last byte/word) rather than `crc_q` (the
  // pre-update value). This matters on the cycle a byte_last / word_last /
  // finalize_i handshake triggers the transition into S_FINAL: the latched
  // output must reflect the data we just consumed.
  logic [WIDTH-1:0] crc_finalised;
  logic [WIDTH-1:0] crc_d_reflected;
  assign crc_d_reflected = REFOUT ? refl(crc_d) : crc_d;
  assign crc_finalised   = crc_d_reflected ^ XOROUT[WIDTH-1:0];

  // -------------------------------------------------------------------
  // Word-mode: select how many bytes of the chain to commit.
  // word_byte_count_i = 1..4. We mux on the count using a small
  // combinational selector. Each chain stage represents the CRC state
  // *after* consuming that many bytes.
  // -------------------------------------------------------------------
  logic [WIDTH-1:0] crc_after_word;
  always_comb begin
    unique case (word_byte_count_i)
      3'd1:    crc_after_word = crc_word_chain[1];
      3'd2:    crc_after_word = crc_word_chain[2];
      3'd3:    crc_after_word = crc_word_chain[3];
      3'd4:    crc_after_word = crc_word_chain[4];
      default: crc_after_word = crc_word_chain[4];
    endcase
  end

  // -------------------------------------------------------------------
  // FSM transitions
  // -------------------------------------------------------------------
  logic byte_take;
  logic word_take;
  logic finalize_now;

  assign byte_take    = byte_valid_i && byte_ready_o;
  assign word_take    = WORD_PARALLEL && word_valid_i && word_ready_o;
  assign finalize_now = (byte_take && byte_last_i)
                      || (word_take && word_last_i)
                      || (finalize_i && (state_q == S_BYTE));

  always_comb begin
    state_d  = state_q;
    crc_d    = crc_q;
    bcount_d = bcount_q;

    case (state_q)
      S_IDLE: begin
        if (init_i) begin
          state_d  = S_BYTE;
          crc_d    = INIT[WIDTH-1:0];
          bcount_d = '0;
        end
      end

      S_BYTE: begin
        // Byte-stream update
        if (byte_take) begin
          crc_d    = crc_after_byte;
          bcount_d = bcount_q + 32'd1;
        end else if (word_take) begin
          crc_d    = crc_after_word;
          bcount_d = bcount_q + {29'd0, word_byte_count_i};
        end

        if (finalize_now) begin
          state_d = S_FINAL;
        end else if (init_i) begin
          // Mid-session re-init: reload INIT and stay in BYTE.
          crc_d    = INIT[WIDTH-1:0];
          bcount_d = '0;
        end
      end

      S_FINAL: begin
        // 1-cycle hold to register the finalised output before DONE.
        state_d = S_DONE;
      end

      S_DONE: begin
        if (init_i) begin
          state_d  = S_BYTE;
          crc_d    = INIT[WIDTH-1:0];
          bcount_d = '0;
        end
      end

      default: state_d = S_IDLE;
    endcase
  end

  // -------------------------------------------------------------------
  // Sequential
  // -------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q     <= S_IDLE;
      crc_q       <= INIT[WIDTH-1:0];
      bcount_q    <= '0;
      crc_valid_q <= 1'b0;
      crc_out_q   <= '0;
    end else begin
      state_q  <= state_d;
      crc_q    <= crc_d;
      bcount_q <= bcount_d;

      // Latch the finalised CRC the cycle we transition into S_FINAL,
      // so it is stable for the consumer in S_DONE.
      if (state_q == S_BYTE && state_d == S_FINAL) begin
        crc_out_q   <= crc_finalised;
        crc_valid_q <= 1'b1;
      end else if (state_d == S_BYTE || state_d == S_IDLE) begin
        crc_valid_q <= 1'b0;
      end
    end
  end

  // -------------------------------------------------------------------
  // Outputs
  // -------------------------------------------------------------------
  assign init_ready_o = (state_q == S_IDLE) || (state_q == S_DONE);
  assign byte_ready_o = (state_q == S_BYTE);
  assign word_ready_o = WORD_PARALLEL && (state_q == S_BYTE);
  assign crc_valid_o  = crc_valid_q;
  assign crc_o        = crc_out_q;
  assign byte_count_o = bcount_q;

endmodule
