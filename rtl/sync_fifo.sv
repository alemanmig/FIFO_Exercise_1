// ============================================================
//  Synchronous FIFO with Full, Empty, Almost-Full/Empty Flags
//  Single clock domain, parameterizable DEPTH (power-of-2) and WIDTH
// ============================================================
module sync_fifo #(
  parameter int DEPTH               = 8,   // Must be a power of 2
  parameter int WIDTH               = 8,
  parameter int ALMOST_FULL_THRESH  = 6,   // assert almost_full  when count >= threshold
  parameter int ALMOST_EMPTY_THRESH = 2    // assert almost_empty when count <= threshold
)(
  input  logic             clk,
  input  logic             rst_n,

  // Write port
  input  logic             write_en,
  input  logic [WIDTH-1:0] write_data,

  // Read port
  input  logic             read_en,
  output logic [WIDTH-1:0] read_data,

  // Status flags
  output logic             full,
  output logic             empty,
  output logic             almost_full,
  output logic             almost_empty
);

  // ----------------------------------------------------------------
  //  Local parameters
  // ----------------------------------------------------------------
  localparam int ADDR_W = $clog2(DEPTH);   // address width

  // ----------------------------------------------------------------
  //  Storage array
  // ----------------------------------------------------------------
  logic [WIDTH-1:0] mem [0:DEPTH-1];

  // ----------------------------------------------------------------
  //  Pointers and count
  //  Both pointers are one bit wider than the address so that
  //  full/empty can be distinguished when write_ptr == read_ptr.
  // ----------------------------------------------------------------
  logic [ADDR_W:0] write_ptr, read_ptr;
  logic [ADDR_W:0] count;          // number of valid entries

  // Combinational: effective write / read enable (guard ops)
  logic wr_en_eff, rd_en_eff;
  assign wr_en_eff = write_en & ~full;
  assign rd_en_eff = read_en  & ~empty;

  // ----------------------------------------------------------------
  //  Pointer update
  // ----------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_ptr <= '0;
      read_ptr  <= '0;
    end else begin
      if (wr_en_eff) write_ptr <= write_ptr + 1'b1;
      if (rd_en_eff) read_ptr  <= read_ptr  + 1'b1;
    end
  end

  // ----------------------------------------------------------------
  //  Occupancy counter
  // ----------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      count <= '0;
    else
      unique case ({wr_en_eff, rd_en_eff})
        2'b10:   count <= count + 1'b1;   // write only
        2'b01:   count <= count - 1'b1;   // read only
        default: count <= count;           // 00 or 11 (simultaneous)
      endcase
  end

  // ----------------------------------------------------------------
  //  Memory write
  // ----------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (wr_en_eff)
      mem[write_ptr[ADDR_W-1:0]] <= write_data;
  end

  // ----------------------------------------------------------------
  //  Read data — registered output
  //  read_data is latched at the same cycle the pop is accepted so
  //  the testbench task can capture it before the address advances.
  //  When the FIFO is empty the last valid data is held.
  // ----------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      read_data <= '0;
    else if (rd_en_eff)
      read_data <= mem[read_ptr[ADDR_W-1:0]];
  end

  // ----------------------------------------------------------------
  //  Status flags (combinational, derived from count)
  // ----------------------------------------------------------------
  assign full         = (count == DEPTH[ADDR_W:0]);
  assign empty        = (count == '0);
  assign almost_full  = (count >= ALMOST_FULL_THRESH[ADDR_W:0])  & ~full;
  assign almost_empty = (count <= ALMOST_EMPTY_THRESH[ADDR_W:0]) & ~empty;

endmodule
