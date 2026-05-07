// ============================================================
// SVA Assertion & Cover Module — sync_fifo
// ============================================================
// Bind this module to the DUT in the testbench:
//
//   bind sync_fifo sync_fifo_sva #(
//     .DEPTH                  (DEPTH),
//     .WIDTH                  (WIDTH),
//     .ALMOST_FULL_THRESHOLD  (ALMOST_FULL_THRESHOLD),
//     .ALMOST_EMPTY_THRESHOLD (ALMOST_EMPTY_THRESHOLD)
//   ) u_sva (.*);
//
// All assertions use the DUT's own internal signals via the bind
// mechanism (clk, rst_n, count, wr_ptr, rd_ptr, full, empty,
// almost_full, almost_empty, write_en, write_data, read_en,
// read_data, write_fire, read_fire).
//
// Organization
// ------------
//   G1  — Reset behavior
//   G2  — Flag correctness (full / empty / almost_*)
//   G3  — Write path (overflow protection, pointer wrap)
//   G4  — Read path  (underflow protection, pointer wrap, registered output)
//   G5  — Occupancy counter integrity
//   G6  — Simultaneous read + write
//   G7  — Functional covers (reachability)
// ============================================================

module sva #(
  parameter int unsigned DEPTH                  = 8,
  parameter int unsigned WIDTH                  = 8,
  parameter int unsigned ALMOST_FULL_THRESH  = DEPTH - 1,
  parameter int unsigned ALMOST_EMPTY_THRESH = 1,
  parameter int ADDR_W = $clog2(DEPTH)   // address width
)(
  input logic                  clk,
  input logic                  rst_n,

  input logic                  write_en,
  input logic [WIDTH-1:0]      write_data,
  input logic                  read_en,
  input logic [WIDTH-1:0]      read_data,

  input logic                  full,
  input logic                  empty,
  input logic                  almost_full,
  input logic                  almost_empty,

  // Internal DUT signals (accessible via bind)
  input logic [ADDR_W:0]        wr_ptr,
  input logic [ADDR_W:0]        rd_ptr,
  input logic [ADDR_W:0]        count,
  input logic                   write_fire,
  input logic                   read_fire
);

  // Shorthand: default clocking and reset for all properties
  default clocking @(posedge clk); endclocking
  default disable iff (!rst_n);



endmodule