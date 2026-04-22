module fcov_fifo #(
  parameter int unsigned DEPTH               = 8,
  parameter int unsigned WIDTH               = 8,
  parameter int unsigned ALMOST_FULL_THRESH  = DEPTH - 1,
  parameter int unsigned ALMOST_EMPTY_THRESH = 1,
  parameter int ADDR_W = $clog2(DEPTH)
) (
  input logic             clk,
  input logic             rst_n,
  input logic             write_en,
  input logic [WIDTH-1:0] write_data,
  input logic             read_en,
  input logic [WIDTH-1:0] read_data,
  input logic             full,
  input logic             empty,
  input logic             almost_full,
  input logic             almost_empty,
  input logic [ADDR_W:0]  wr_ptr,
  input logic [ADDR_W:0]  rd_ptr,
  input logic [ADDR_W:0]  count,
  input logic             write_fire,
  input logic             read_fire
);

  logic signed [ADDR_W+1:0] count_delta;
  logic [ADDR_W:0]          prev_count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      prev_count  <= '0;
      count_delta <= '0;
    end else begin
      count_delta <= $signed({1'b0, count}) - $signed({1'b0, prev_count});
      prev_count  <= count;
    end
  end

  covergroup cg_fifo_core @(posedge clk iff rst_n);
    option.per_instance = 1;
    option.name         = "cg_fifo_core";

    cp_count : coverpoint count {
      bins empty_bin        = {0};
      bins one_bin          = {1};
      bins almost_empty_bin[] = {[1:ALMOST_EMPTY_THRESH]};
      bins middle_bin[]       = {[ALMOST_EMPTY_THRESH+1:ALMOST_FULL_THRESH-1]};
      bins almost_full_bin[]  = {[ALMOST_FULL_THRESH:DEPTH-1]};
      bins full_bin         = {DEPTH};
    }

    cp_flags : coverpoint {full, empty, almost_full, almost_empty} {
      bins empty_state       = {4'b0100};
      bins almost_empty_state = {4'b0001};
      bins mid_state         = {4'b0000};
      bins almost_full_state = {4'b0010};
      bins full_state        = {4'b1000};
    }

    cp_req_kind : coverpoint {write_en, read_en} {
      bins idle_req     = {2'b00};
      bins write_req    = {2'b10};
      bins read_req     = {2'b01};
      bins sim_rw_req   = {2'b11};
    }

    cp_fire_kind : coverpoint {write_fire, read_fire} {
      bins idle_fire    = {2'b00};
      bins write_fire_b = {2'b10};
      bins read_fire_b  = {2'b01};
      bins sim_rw_fire  = {2'b11};
    }

    cp_count_delta : coverpoint count_delta {
      bins dec_bin  = {-1};
      bins same_bin = {0};
      bins inc_bin  = {1};
    }

    cp_overflow_attempt : coverpoint (write_en && full) {
      bins seen = {1'b1};
    }

    cp_underflow_attempt : coverpoint (read_en && empty) {
      bins seen = {1'b1};
    }

    cp_wr_ptr_wrap : coverpoint wr_ptr[ADDR_W-1:0] iff (write_fire) {
      bins wrap_bin = (DEPTH-1 => 0);
    }

    cp_rd_ptr_wrap : coverpoint rd_ptr[ADDR_W-1:0] iff (read_fire) {
      bins wrap_bin = (DEPTH-1 => 0);
    }

    cp_write_data : coverpoint write_data iff (write_fire) {
      bins zero_bin    = {0};
      bins ones_bin    = {'1};
      bins low_bin[]   = {[1:63]};
      bins mid_bin[]   = {[64:191]};
      bins high_bin[]  = {[192:254]};
    }

    cp_read_data : coverpoint read_data iff (read_fire) {
      bins zero_bin    = {0};
      bins ones_bin    = {'1};
      bins low_bin[]   = {[1:63]};
      bins mid_bin[]   = {[64:191]};
      bins high_bin[]  = {[192:254]};
    }

    cx_count_x_fire : cross cp_count, cp_fire_kind;
    cx_flags_x_fire : cross cp_flags, cp_fire_kind;
    cx_req_x_fire   : cross cp_req_kind, cp_fire_kind;
  endgroup

  cg_fifo_core fifo_core_cg = new();

endmodule
