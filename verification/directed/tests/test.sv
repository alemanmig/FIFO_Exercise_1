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

  logic [WIDTH-1:0] rd;

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
    // TC1 — Basic FIFO order
    // Push 0xAA, 0xBB, 0xCC; pop must return them in the same order.
    // ==============================================================
    $display("\n--- TC1: Basic FIFO order ---");
    push(8'hAA);
    push(8'hBB);
    push(8'hCC);

    pop(rd); check("TC1-A  pop[0] = 0xAA", rd, 8'hAA);
    pop(rd); check("TC1-B  pop[1] = 0xBB", rd, 8'hBB);
    pop(rd); check("TC1-C  pop[2] = 0xCC", rd, 8'hCC);

    // ==============================================================
    // TC2 — Full flag and overflow protection
    // Fill all 8 slots; verify full=1; attempt 9th write; full must
    // remain 1 (overflow silently ignored).
    // ==============================================================
    $display("\n--- TC2: Full flag and overflow protection ---");
    reset();

    repeat (8) push(8'hFF);           // fill to capacity
    @(negedge vif.clk);
    check("TC2-A  full=1 after 8 writes",          vif.full, 1'b1);

    push(8'hEE);                      // overflow attempt — must be ignored
    @(negedge vif.clk);
    check("TC2-B  full=1 after overflow attempt",  vif.full, 1'b1);

    // ==============================================================
    // TC3 — Empty flag and underflow protection
    // Push 3, pop 3; verify empty=1; attempt 4th pop; empty must
    // remain 1 (underflow silently ignored).
    // ==============================================================
    $display("\n--- TC3: Empty flag and underflow protection ---");
    reset();

    push(8'h01); push(8'h02); push(8'h03);
    pop(rd); pop(rd); pop(rd);
    @(negedge vif.clk);
    check("TC3-A  empty=1 after 3 reads", vif.empty, 1'b1);

    // Raw underflow attempt (bypasses pop task to match spec exactly)
    vif.read_en = 1; @(posedge vif.clk); @(negedge vif.clk); vif.read_en = 0;
    check("TC3-B  empty=1 after underflow attempt", vif.empty, 1'b1);

    // ==============================================================
    // TC4 — Almost-full threshold  (ALMOST_FULL_THRESHOLD = 6)
    // Verify almost_full asserts at count=6; full=1 at count=8.
    // ==============================================================
    $display("\n--- TC4: Almost-full threshold ---");
    reset();

    repeat (5) push(8'hAA);           // count = 1..5 (below threshold)

    push(8'hAA);                      // count = 6
    @(negedge vif.clk);
    check("TC4-A  almost_full=1 at count=6", vif.almost_full, 1'b1);
    check("TC4-B  full=0        at count=6", vif.full,        1'b0);

    push(8'hAA);                      // count = 7
    @(negedge vif.clk);
    check("TC4-C  almost_full=1 at count=7", vif.almost_full, 1'b1);
    check("TC4-D  full=0        at count=7", vif.full,        1'b0);

    push(8'hAA);                      // count = 8
    @(negedge vif.clk);
    check("TC4-E  full=1        at count=8", vif.full,        1'b1);

    // ==============================================================
    // TC5 — Almost-empty threshold  (ALMOST_EMPTY_THRESHOLD = 2)
    // Start with 3 entries; pop one by one; verify almost_empty and
    // empty at each occupancy level.
    // ==============================================================
    $display("\n--- TC5: Almost-empty threshold ---");
    reset();

    repeat (3) push(8'hBB);           // count = 3

    pop(rd);                          // count = 2
    @(negedge vif.clk);
    check("TC5-A  almost_empty=1 at count=2", vif.almost_empty, 1'b1);
    check("TC5-B  empty=0        at count=2", vif.empty,        1'b0);

    pop(rd);                          // count = 1
    @(negedge vif.clk);
    check("TC5-C  almost_empty=1 at count=1", vif.almost_empty, 1'b1);
    check("TC5-D  empty=0        at count=1", vif.empty,        1'b0);

    pop(rd);                          // count = 0
    @(negedge vif.clk);
    check("TC5-E  empty=1        at count=0", vif.empty,        1'b1);

    // ==============================================================
    // TC6 — Simultaneous read and write
    // Load 4 entries; assert read_en=1 and write_en=1 in the same
    // cycle; verify count unchanged, correct read value, and that
    // the new entry appears at the correct position in drain order.
    // ==============================================================
    $display("\n--- TC6: Simultaneous read and write ---");
    reset();

    push(8'hC1); push(8'hC2);
    push(8'hC3); push(8'hC4);        // count = 4

    // Assert both enables for exactly one clock cycle
    @(negedge vif.clk);
    vif.write_en   = 1;
    vif.write_data = 8'hEF;
    vif.read_en    = 1;
    @(posedge vif.clk);                   // DUT performs R+W simultaneously
    @(negedge vif.clk);
    vif.write_en = 0;
    vif.read_en  = 0;

    // count must still be 4 → neither full nor empty
    check("TC6-A  full=0  after sim R+W",           vif.full,      1'b0);
    check("TC6-B  empty=0 after sim R+W",           vif.empty,     1'b0);
    // read_data must hold the oldest entry (0xC1)
    check("TC6-C  read_data=0xC1 (oldest popped)",  vif.read_data, 8'hC1);

    // Drain remaining 4 entries; verify FIFO order and 0xEF position
    pop(rd); check("TC6-D  drain[0] = 0xC2", rd, 8'hC2);
    pop(rd); check("TC6-E  drain[1] = 0xC3", rd, 8'hC3);
    pop(rd); check("TC6-F  drain[2] = 0xC4", rd, 8'hC4);
    pop(rd); check("TC6-G  drain[3] = 0xEF", rd, 8'hEF);

    // ==============================================================
    // Summary
    // ==============================================================
    $display("");
    $display("=== %0d passed  %0d failed ===", p, f);

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
    @(posedge vif.clk);   // hold for at least 2 rising edges
    @(posedge vif.clk);
    vif.rst_n = 1;
    @(posedge vif.clk);   // one idle cycle before stimulus
  endtask : reset


  // ----------------------------------------------------------------
  // Task: push — write one entry
  // Drives write_en + write_data at negedge; deasserts after posedge.
  // ----------------------------------------------------------------
  task automatic push(input logic [WIDTH-1:0] d);
    @(negedge vif.clk);
    vif.write_en   = 1;
    vif.write_data = d;
    @(posedge vif.clk);   // DUT captures write_data on this edge
    @(negedge vif.clk);
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
    @(posedge vif.clk);   // DUT updates read_data on this edge
    @(negedge vif.clk);
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
