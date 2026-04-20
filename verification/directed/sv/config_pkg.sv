`ifndef CONFIG_PKG_SV
`define CONFIG_PKG_SV

package config_pkg;
  
  // ====== TESTBENCH PARAMETERS ====== //

  localparam int unsigned ClkFreq       = 100_000_000; // 100 MHz
  localparam int unsigned StableTime    = 1;           // 1 ms

  int unsigned debounce_time = 120;         // Clock cycles
  int unsigned iterations    = 50;        // Number of bounces
  

  function void get_config_args();
    int unsigned cli_value;

    if ($value$plusargs("iterations=%d", cli_value)) begin
      iterations = cli_value;
      $display("[INFO] %10t: iterations = %5d", $realtime, iterations);
    end else begin
      $display("[INFO] %10t: iterations = %5d (DEFAULT)", $realtime, iterations);
    end

    if ($value$plusargs("debounce_time=%d", cli_value)) begin
      debounce_time = cli_value;
      $display("[INFO] %10t: debounce_time = %5d", $realtime, debounce_time);
    end else begin
      $display("[INFO] %10t: debounce_time = %5d (DEFAULT)", $realtime, debounce_time);
    end

  endfunction

endpackage : config_pkg

`endif // CONFIG_PKG_SV