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
  parameter int ClkFreq    = 100_000_000,
  parameter int StableTime = 10,
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

  // ----------------------------------------------------------------
  //  Local parameters
  // ----------------------------------------------------------------
  localparam int CounterMax = ClkFreq * StableTime / 1_000_000;
 

  // Shorthand: default clocking and reset for all properties
  default clocking @(posedge clk); endclocking
  default disable iff (!rst_n);

  // ============================================================
  // G1 — Reset behavior
  // ============================================================

  // After rst_n is released, pointers and count must be zero
  // and empty must be asserted on the very next posedge.

  property pr1;
    @(posedge clk)
    $rose(rst_n) |=> (count === '0);
  endproperty

  a_rst_count_zero : assert property (pr1) 
  else $error("G1: count not zero after reset");

  a_rst_wr_ptr_zero : assert property (
    @(posedge clk) $rose(rst_n) |=> (wr_ptr === '0)
  ) else $error("G1: wr_ptr not zero after reset");

  a_rst_rd_ptr_zero : assert property (
    @(posedge clk) $rose(rst_n) |=> (rd_ptr === '0)
  ) else $error("G1: rd_ptr not zero after reset");

  a_rst_empty : assert property (
    @(posedge clk) $rose(rst_n) |=> empty
  ) else $error("G1: empty not asserted after reset");

  a_rst_not_full : assert property (
    $rose(rst_n) |=> !full
  ) else $error("G1: full incorrectly asserted after reset");

  a_rst_read_data_zero : assert property (
    $rose(rst_n) |=> (read_data === '0)
  ) else $error("G1: read_data not cleared after reset");

  // ============================================================
  // G2 — Flag correctness
  // ============================================================

  // full ↔ count == DEPTH
  a_full_iff_count_depth : assert property (
    full === (count == $clog2(DEPTH)'(DEPTH))
  ) else $error("G2: full flag mismatch with count");

  // empty ↔ count == 0
  a_empty_iff_count_zero : assert property (
    empty === (count == '0)
  ) else $error("G2: empty flag mismatch with count");

  // almost_full ↔ count >= ALMOST_FULL_THRESHOLD
  a_almost_full_iff_threshold : assert property (
    almost_full === (count >= $clog2(DEPTH)'(ALMOST_FULL_THRESH))
  ) else $error("G2: almost_full flag mismatch with count");

  // almost_empty ↔ count <= ALMOST_EMPTY_THRESHOLD
  a_almost_empty_iff_threshold : assert property (
    almost_empty === (count <= $clog2(DEPTH)'(ALMOST_EMPTY_THRESH))
  ) else $error("G2: almost_empty flag mismatch with count");

  // full and empty are mutually exclusive (DEPTH >= 2 guaranteed)
  a_full_empty_mutex : assert property (
    !(full && empty)
  ) else $error("G2: full and empty asserted simultaneously");

  // almost_full must be asserted whenever full is asserted
  // (full → count==DEPTH >= ALMOST_FULL_THRESHOLD)
  a_full_implies_almost_full : assert property (
    full |-> almost_full
  ) else $error("G2: full asserted but almost_full not asserted");

  // almost_empty must be asserted whenever empty is asserted
  // (empty → count==0 <= ALMOST_EMPTY_THRESHOLD, since threshold >= 1)
  a_empty_implies_almost_empty : assert property (
    empty |-> almost_empty
  ) else $error("G2: empty asserted but almost_empty not asserted");

  // Flags are combinational: they must never be X after reset
  a_full_not_x : assert property (
    !$isunknown(full)
  ) else $error("G2: full is X");

  a_empty_not_x : assert property (
    !$isunknown(empty)
  ) else $error("G2: empty is X");

  a_almost_full_not_x : assert property (
    !$isunknown(almost_full)
  ) else $error("G2: almost_full is X");

  a_almost_empty_not_x : assert property (
    !$isunknown(almost_empty)
  ) else $error("G2: almost_empty is X");

  // ============================================================
  // G3 — Write path
  // ============================================================

  // write_fire is qualified: never fires when full
  a_no_write_when_full : assert property (
    full |-> !write_fire
  ) else $error("G3: write_fire asserted while full");

  // write_fire definition: fires iff write_en and not full
  a_write_fire_def : assert property (
    write_fire === (write_en && !full)
  ) else $error("G3: write_fire definition violated");

  // wr_ptr advances by 1 on write_fire (with wrap)
  a_wr_ptr_advance : assert property (
    write_fire |=>
      (wr_ptr === ($clog2(DEPTH)'($past(wr_ptr) == DEPTH-1)
                   ? '0
                   : $past(wr_ptr) + 1'b1))
  ) else $error("G3: wr_ptr did not advance correctly on write");

  // wr_ptr is stable when write_fire is not asserted
  a_wr_ptr_stable : assert property (
    !write_fire |=> (wr_ptr === $past(wr_ptr))
  ) else $error("G3: wr_ptr changed without write_fire");

  // wr_ptr stays within valid address range at all times
  a_wr_ptr_range : assert property (
    wr_ptr < $clog2(DEPTH)'(DEPTH)
  ) else $error("G3: wr_ptr out of range");

  // ============================================================
  // G4 — Read path
  // ============================================================

  // read_fire is qualified: never fires when empty
  a_no_read_when_empty : assert property (
    empty |-> !read_fire
  ) else $error("G4: read_fire asserted while empty");

  // read_fire definition: fires iff read_en and not empty
  a_read_fire_def : assert property (
    read_fire === (read_en && !empty)
  ) else $error("G4: read_fire definition violated");

  // rd_ptr advances by 1 on read_fire (with wrap)
  a_rd_ptr_advance : assert property (
    read_fire |=>
      (rd_ptr === ($clog2(DEPTH)'($past(rd_ptr) == DEPTH-1)
                   ? '0
                   : $past(rd_ptr) + 1'b1))
  ) else $error("G4: rd_ptr did not advance correctly on read");

  // rd_ptr is stable when read_fire is not asserted
  a_rd_ptr_stable : assert property (
    !read_fire |=> (rd_ptr === $past(rd_ptr))
  ) else $error("G4: rd_ptr changed without read_fire");

  // rd_ptr stays within valid address range at all times
  a_rd_ptr_range : assert property (
    rd_ptr < $clog2(DEPTH)'(DEPTH)
  ) else $error("G4: rd_ptr out of range");

  // read_data is registered: it must only change on a successful read
  a_read_data_stable : assert property (
    !read_fire |=> (read_data === $past(read_data))
  ) else $error("G4: read_data changed without read_fire (registered output violated)");

  // read_data must not be X after a successful read
  a_read_data_not_x : assert property (
    read_fire |=> !$isunknown(read_data)
  ) else $error("G4: read_data is X after successful read");

  // ============================================================
  // G5 — Occupancy counter integrity
  // ============================================================

  // count stays within legal range [0, DEPTH] at all times
  a_count_range : assert property (
    count <= ($clog2(DEPTH)+1)'(DEPTH)
  ) else $error("G5: count out of range [0, DEPTH]");

  // write-only: count increments by exactly 1
  a_count_inc_on_write : assert property (
    (write_fire && !read_fire) |=> (count === $past(count) + 1'b1)
  ) else $error("G5: count did not increment on write-only");

  // read-only: count decrements by exactly 1
  a_count_dec_on_read : assert property (
    (!write_fire && read_fire) |=> (count === $past(count) - 1'b1)
  ) else $error("G5: count did not decrement on read-only");

  // simultaneous read+write: count is unchanged
  a_count_stable_on_sim_rw : assert property (
    (write_fire && read_fire) |=> (count === $past(count))
  ) else $error("G5: count changed during simultaneous read+write");

  // idle (no fire): count is unchanged
  a_count_stable_on_idle : assert property (
    (!write_fire && !read_fire) |=> (count === $past(count))
  ) else $error("G5: count changed while idle");

  // count must not be X after reset
  a_count_not_x : assert property (
    !$isunknown(count)
  ) else $error("G5: count is X");

  // ============================================================
  // G6 — Simultaneous read + write
  // ============================================================

  // Simultaneous operation is only possible when neither full nor empty
  a_sim_rw_requires_not_full_empty : assert property (
    (write_fire && read_fire) |-> (!full && !empty)
  ) else $error("G6: simultaneous R+W fired while full or empty");

  // Both pointers must advance in the same cycle during sim R+W
  a_sim_rw_wr_ptr_advances : assert property (
    (write_fire && read_fire) |=>
      (wr_ptr === ($clog2(DEPTH)'($past(wr_ptr) == DEPTH-1)
                   ? '0 : $past(wr_ptr) + 1'b1))
  ) else $error("G6: wr_ptr did not advance during simultaneous R+W");

  a_sim_rw_rd_ptr_advances : assert property (
    (write_fire && read_fire) |=>
      (rd_ptr === ($clog2(DEPTH)'($past(rd_ptr) == DEPTH-1)
                   ? '0 : $past(rd_ptr) + 1'b1))
  ) else $error("G6: rd_ptr did not advance during simultaneous R+W");

  // ============================================================
  // G7 — Functional covers (reachability)
  // These verify the testbench can actually exercise each state.
  // A failing cover means the scenario was never reached.
  // ============================================================

  // FIFO reaches full capacity
  c_fifo_full : cover property (full);

  // FIFO reaches empty after being non-empty
  c_fifo_empty_after_data : cover property (!empty ##1 empty);

  // almost_full asserted without full (threshold zone)
  c_almost_full_not_full : cover property (almost_full && !full);

  // almost_empty asserted without empty (threshold zone)
  c_almost_empty_not_empty : cover property (almost_empty && !empty);

  // Successful write (write_fire)
  c_write_fire : cover property (write_fire);

  // Successful read (read_fire)
  c_read_fire : cover property (read_fire);

  // Simultaneous read and write
  c_sim_rw : cover property (write_fire && read_fire);

  // Overflow attempt: write_en asserted while full (should be ignored)
  c_overflow_attempt : cover property (write_en && full);

  // Underflow attempt: read_en asserted while empty (should be ignored)
  c_underflow_attempt : cover property (read_en && empty);

  // wr_ptr wraps around from DEPTH-1 back to 0
  c_wr_ptr_wrap : cover property (
    (wr_ptr == $clog2(DEPTH)'(DEPTH-1)) ##1 (wr_ptr == '0)
  );

  // rd_ptr wraps around from DEPTH-1 back to 0
  c_rd_ptr_wrap : cover property (
    (rd_ptr == $clog2(DEPTH)'(DEPTH-1)) ##1 (rd_ptr == '0)
  );

  // FIFO goes full then drains back to empty
  c_full_to_empty : cover property (full ##[1:$] empty);

  // Back-to-back writes (two consecutive write_fire cycles)
  c_back_to_back_writes : cover property (write_fire ##1 write_fire);

  // Back-to-back reads (two consecutive read_fire cycles)
  c_back_to_back_reads : cover property (read_fire ##1 read_fire);

  // Alternating write then read in consecutive cycles
  c_write_then_read : cover property (write_fire ##1 read_fire);

  // Alternating read then write in consecutive cycles
  c_read_then_write : cover property (read_fire ##1 write_fire);

endmodule
