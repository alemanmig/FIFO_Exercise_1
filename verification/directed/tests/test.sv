module test (
    vif_if vif
);

  // Pass / fail counters
  int p = 0, f = 0;

  //logic [WIDTH-1:0] rd;
  
  // =================== DPI FUNCTIONS ==================== //
  import "DPI-C" function real ref_model(real initial_value);

  // ================== GLOBAL VARIABLES ================== //

  import config_pkg::*;

  logic [WIDTH-1:0] Rand_dato [ATTEMPT:0];
  logic [WIDTH-1:0] pop_data;
  string  pop_data_str;

  // =================== MAIN SEQUENCE ==================== //

  initial begin
    // Initial values
    $display("Begin Of Simulation.");
    get_config_args();

    // Initial signal state before first reset
    vif.rst_n      = 0;
    vif.write_en   = 0;
    vif.read_en    = 0;
    vif.write_data = 0;
    
    // Apply reset
    reset();

    // Stimulus
    // ==============================================================
    // BFO — Basic FIFO order (input/output)
    // Push 0xAA, 0xBB, 0xCC; pop must return them in the same order.
    // ==============================================================
    $display("\n--- TC1: Basic FIFO order (input/output)---");
    foreach (Rand_dato[i])  begin
      Rand_dato[i]  = $urandom;
      push(Rand_dato[i]);
      $display("DataPush=0x%h",Rand_dato[i]);
    end
    foreach (Rand_dato[i])  begin
      pop(pop_data);
      pop_data_str  = {"BFO-0",$sformatf("%0d",i),"  pop= 0x",$sformatf("%h",pop_data)};
      check(pop_data_str, pop_data, Rand_dato[i]);
    end
    // Drain time
    #(100ns);
    $display("End Of Simulation.");
    $finish;
  end


  // ======================= TASKS ======================== //

  // ----------------------------------------------------------------
  // Task: reset — apply two-cycle asynchronous reset
  // ----------------------------------------------------------------
  task automatic reset();
    vif.rst_n    = 0;
    vif.write_en = 0;
    vif.read_en  = 0;
    repeat (2) @(posedge vif.clk);
    vif.rst_n = 1;
    repeat (1) @(posedge vif.clk);
  endtask : reset


  // ----------------------------------------------------------------
  // Task: push — write one entry
  // Drives write_en + write_data at negedge; deasserts after posedge.
  // ----------------------------------------------------------------
  task automatic push(input logic [WIDTH-1:0] d);
    @(negedge vif.clk);
    vif.write_en   = 1;
    vif.write_data = d;
    repeat (2) @(posedge vif.clk);
    vif.write_en = 0;
  endtask

  // ----------------------------------------------------------------
  // Task: pop — read one entry
  // Drives read_en at negedge; samples read_data at the negedge
  // AFTER the posedge that registered the output (Option A semantics).
  // ----------------------------------------------------------------
  task automatic pop(output logic [WIDTH-1:0] d);
    @(negedge vif.clk);
    vif.read_en = 1;
    repeat (2) @(posedge vif.clk);
    d = vif.read_data;   // stable registered value
    vif.read_en = 0;
  endtask

  // ----------------------------------------------------------------
  // Task: check — compare and report
  // Uses === (case equality) to catch X and Z on DUT outputs.
  // ----------------------------------------------------------------
  task automatic check(
    input string       label,
    input logic [31:0] got,
    input logic [31:0] exp
  );
    if (got === exp) begin
      p++;
      $display("PASS: %s  (got=0x%0h)", label, got);
    end else begin
      f++;
      $display("FAIL: %s  expected=0x%0h  got=0x%0h", label, exp, got);
    end
  endtask


endmodule : test
