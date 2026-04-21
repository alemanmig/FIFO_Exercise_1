module tb;

  timeunit      1ns;
  timeprecision 100ps;

  import config_pkg::*;

  // Clock signal
  logic clk = 0;
  int unsigned MainClkPeriod = 10;  // 100 MHz -> 10 ns period
  always #(MainClkPeriod / 2) clk = ~clk;

  // Interface
  vif_if vif (clk);

  // Test
  test top_test (vif);

  // Instantiation
  sync_fifo #(
    .DEPTH(DEPTH),
    .WIDTH(WIDTH),
    .ALMOST_FULL_THRESH(ALMOST_FULL_THRESH),
    .ALMOST_EMPTY_THRESH(ALMOST_EMPTY_THRESH)
  ) dut (
      .clk(vif.clk),
      .rst_n(vif.rst_n),
      .write_en(vif.write_en),
      .write_data(vif.write_data),
      .read_en(vif.read_en),
      .read_data(vif.read_data),
      .full(vif.full),
      .empty(vif.empty),
      .almost_full(vif.almost_full),
      .almost_empty(vif.almost_empty)
  );
  
  // SVA
  bind sync_fifo sva #(
      .DEPTH                  (DEPTH),
      .WIDTH                  (WIDTH),
      .ALMOST_FULL_THRESH  (ALMOST_FULL_THRESH),
      .ALMOST_EMPTY_THRESH (ALMOST_EMPTY_THRESH)
  ) dut_sva (
      .clk(clk),
      .rst_n(rst_n),
      .write_en(write_en),
      .write_data(write_data),
      .read_en(read_en),
      .read_data(read_data),
      .full(full),
      .empty(empty),
      .almost_full(almost_full),
      .almost_empty(almost_empty),
      .wr_ptr(write_ptr),
      .rd_ptr(read_ptr),
      .count(count)
  );

  initial begin
    $timeformat(-9, 1, "ns", 10);
  end

endmodule : tb
