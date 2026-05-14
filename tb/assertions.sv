// SPDX-License-Identifier: GPL-3.0-or-later OR Commercial
//
// SVA properties for crc_top. The protocol invariants enforced on every
// cycle of every regression are:
//
//   p_byte_after_init     : byte_ready_o never rises before init_i seen.
//   p_crc_stable_when_v   : crc_o is stable while crc_valid_o is high.
//   p_byte_count_monoton  : byte_count_o never decreases except across
//                           init_i.
//   p_finalize_yields_v   : a finalize_i pulse in BYTE state produces
//                           crc_valid_o within LAT_MAX cycles.
//   p_no_byte_during_init : byte_ready_o is low in the cycle init_i is
//                           asserted (the FSM moves to BYTE state on the
//                           next edge).
//
// LAT_MAX is generous (16) to cover the worst-case 1-cycle FINAL +
// transition into DONE plus a back-pressure beat. Properties are
// stripped on synthesis flows via `ifndef SYNTHESIS so the synthesised
// netlist contains zero assertion infrastructure.

module crc_assertions #(
  parameter int LAT_MAX = 16
) (
  input logic        clk_i,
  input logic        rst_ni,
  input logic        init_i,
  input logic        init_ready_o,
  input logic        byte_valid_i,
  input logic        byte_ready_o,
  input logic        byte_last_i,
  input logic        finalize_i,
  input logic        crc_valid_o,
  input logic [31:0] crc_o,
  input logic [31:0] byte_count_o
);
`ifndef SYNTHESIS

  logic        init_seen_q;
  logic [31:0] last_count_q;
  logic        finalize_pending_q;
  int          finalize_age_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      init_seen_q        <= 1'b0;
      last_count_q       <= 32'd0;
      finalize_pending_q <= 1'b0;
      finalize_age_q     <= 0;
    end else begin
      if (init_i) begin
        init_seen_q        <= 1'b1;
        last_count_q       <= 32'd0;
        finalize_pending_q <= 1'b0;
        finalize_age_q     <= 0;
      end else begin
        last_count_q <= byte_count_o;
        // A finalize is implicit on byte_last + handshake or explicit
        // finalize_i. Track whichever fires.
        if (((byte_valid_i && byte_ready_o && byte_last_i) || finalize_i)
            && !finalize_pending_q) begin
          finalize_pending_q <= 1'b1;
          finalize_age_q     <= 0;
        end else if (finalize_pending_q) begin
          if (crc_valid_o) begin
            finalize_pending_q <= 1'b0;
            finalize_age_q     <= 0;
          end else begin
            finalize_age_q <= finalize_age_q + 1;
          end
        end
      end
    end
  end

  // 1. byte_ready_o never high before any init has been observed.
  property p_byte_after_init;
    @(posedge clk_i) disable iff (!rst_ni)
      byte_ready_o |-> init_seen_q;
  endproperty
  a_byte_after_init: assert property (p_byte_after_init)
    else $error("crc: byte_ready_o asserted before init_i ever seen");

  // 2. crc_o stable while crc_valid_o asserted.
  property p_crc_stable;
    @(posedge clk_i) disable iff (!rst_ni)
      crc_valid_o |=> (!crc_valid_o || $stable(crc_o));
  endproperty
  a_crc_stable: assert property (p_crc_stable)
    else $error("crc: crc_o changed while crc_valid_o asserted");

  // 3. byte_count_o is monotonic outside init_i.
  property p_byte_count_monotonic;
    @(posedge clk_i) disable iff (!rst_ni || init_i)
      byte_count_o >= last_count_q;
  endproperty
  a_byte_count_monotonic: assert property (p_byte_count_monotonic)
    else $error("crc: byte_count_o decreased without init_i");

  // 4. A finalize must land within LAT_MAX cycles.
  property p_finalize_eventually;
    @(posedge clk_i) disable iff (!rst_ni)
      finalize_pending_q |-> (finalize_age_q < LAT_MAX);
  endproperty
  a_finalize_eventually: assert property (p_finalize_eventually)
    else $error("crc: finalize_i pulse did not yield crc_valid_o within %0d cycles",
                LAT_MAX);

  // 5. byte_ready_o cannot be high during the init_i pulse (FSM is
  //    transitioning out of IDLE / DONE; BYTE state begins next cycle).
  property p_no_byte_during_init;
    @(posedge clk_i) disable iff (!rst_ni)
      init_i |-> !byte_ready_o;
  endproperty
  a_no_byte_during_init: assert property (p_no_byte_during_init)
    else $error("crc: byte_ready_o high during init_i");

`endif
endmodule
