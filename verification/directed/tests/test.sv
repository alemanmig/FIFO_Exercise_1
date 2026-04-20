module test (
    vif_if vif
);
  // =================== DPI FUNCTIONS ==================== //
  import "DPI-C" function real ref_model(real initial_value);

  // ================== GLOBAL VARIABLES ================== //

  import config_pkg::*;

  // =================== MAIN SEQUENCE ==================== //

  initial begin
    // Initial values
    $display("Begin Of Simulation.");
    get_config_args();
    
    // Apply reset
    reset();

    // Stimulus
    fork
      begin
        normal(debounce_time);
        bounce(debounce_time, iterations);
      end

      begin
        check_db_tick();
      end
    join

    // Drain time
    #(100ns);
    $display("End Of Simulation.");
    $finish;
  end


  // ======================= TASKS ======================== //

  task automatic reset();
    vif.rst_i = 1'b1;
    vif.sw_i  = 1'b0;
    repeat (2) @(vif.cb);
    vif.cb.rst_i <= 1'b0;
    repeat (20) @(vif.cb);
  endtask : reset


  task automatic normal(int unsigned debounce_time);
    vif.cb.sw_i <= 1'b1;
    repeat (debounce_time) @(vif.cb);
    vif.cb.sw_i <= 1'b0;
    repeat (debounce_time) @(vif.cb);
  endtask : normal


  task automatic bounce(int unsigned debounce_time, int unsigned iterations = 1000);
    int delay1, delay2;
    realtime time1, time2;
    for (int i = 0; i < iterations; i++) begin
      delay1 = $urandom_range(debounce_time / 10, debounce_time);
      delay2 = $urandom_range(debounce_time / 10, debounce_time);
      $display("[INFO] %10t: iter = %3d, delay1 = %10d, delay2 = %10d", $realtime, i, delay1,
               delay2);
      vif.cb.sw_i <= 1'b1;
      time1 = $realtime;
      repeat (delay1) @(vif.cb);
      vif.cb.sw_i <= 1'b0;
      time2 = $realtime;
      repeat (delay2) @(vif.cb);
      $display("[INFO] %10t: iter = %3d, time1  = %t, time2  = %t", $realtime, i, time1, time2);
      $display("[INFO] %10t: iter = %3d, total_cycles = %10d", $realtime, i, delay1 + delay2);
    end
  endtask : bounce

  
  task automatic check_db_tick();
    int tick_counter = 0;
    int tick_error_counter = 0;

    forever begin

      fork
        begin : wd_timer_fork
          fork : db_tick_wd_timer
            begin
              // Edge detection for db_tick_o
              wait (vif.cb.db_tick_o != 1);
              @(vif.cb iff (vif.cb.db_tick_o == 1));
              tick_counter++;
              $display("[INFO] %10t: posedge db_tick_o, num_pulses: %4d", $realtime, tick_counter);
            end
            begin
              // Watchdog timer to avoid infinite wait
              repeat (10_000) @(vif.cb);
              $display("[INFO] %10t: Timed out!", $realtime);
              $display("[INFO] %10t: REPORT:", $realtime);
              $display("[INFO] %10t: tick_counter: %4d, tick_error_counter: %4d", $realtime,
                       tick_counter, tick_error_counter);
              $finish;
            end
          join_any : db_tick_wd_timer
          disable fork;
        end : wd_timer_fork
      join

      @(vif.cb);
      if (vif.cb.db_tick_o == 1) begin
        tick_error_counter++;
        $display("[ERROR]%10t: db_tick_o ", $realtime);
        //$finish;
      end

    end

  endtask : check_db_tick


endmodule : test
