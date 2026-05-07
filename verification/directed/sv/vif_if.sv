`ifndef VIF_IF_SV
`define VIF_IF_SV

interface vif_if(
    input logic clk
); 

  timeunit      1ns;
  timeprecision 100ps;
  
  import config_pkg::*;
  
  logic rst_n;
  logic write_en;
  logic [WIDTH-1:0] write_data;
  logic read_en;
  logic [WIDTH-1:0] read_data;
  logic full;
  logic empty;
  logic almost_full;
  logic almost_empty;

endinterface : vif_if

`endif // VIF_IF_SV
