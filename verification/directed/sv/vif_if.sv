`ifndef VIF_IF_SV
`define VIF_IF_SV

interface vif_if(
    input logic clk_i
); 

  timeunit      1ns;
  timeprecision 100ps;
  
  import config_pkg::*;
  
  logic rst_i;
  logic sw_i;
  logic db_level_o;
  logic db_tick_o;

  clocking cb @(posedge clk_i);
    default input #1ns output #1ns;
    output rst_i;
    output sw_i;
    input db_level_o;
    input db_tick_o;
  endclocking

endinterface : vif_if

`endif // VIF_IF_SV
