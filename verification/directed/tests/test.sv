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

    // Initial signal state before first reset
    rst_n      = 0;
    write_en   = 0;
    read_en    = 0;
    write_data = 0;
    
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
    do_reset();

    repeat (8) push(8'hFF);           // fill to capacity
    @(negedge clk);
    check("TC2-A  full=1 after 8 writes",          full, 1'b1);

    push(8'hEE);                      // overflow attempt — must be ignored
    @(negedge clk);
    check("TC2-B  full=1 after overflow attempt",  full, 1'b1);

    // ==============================================================
    // TC3 — Empty flag and underflow protection
    // Push 3, pop 3; verify empty=1; attempt 4th pop; empty must
    // remain 1 (underflow silently ignored).
    // ==============================================================
    $display("\n--- TC3: Empty flag and underflow protection ---");
    do_reset();

    push(8'h01); push(8'h02); push(8'h03);
    pop(rd); pop(rd); pop(rd);
    @(negedge clk);
    check("TC3-A  empty=1 after 3 reads",           empty, 1'b1);

    // Raw underflow attempt (bypasses pop task to match spec exactly)
    read_en = 1; @(posedge clk); @(negedge clk); read_en = 0;
    check("TC3-B  empty=1 after underflow attempt", empty, 1'b1);

    // ==============================================================
    // TC4 — Almost-full threshold  (ALMOST_FULL_THRESHOLD = 6)
    // Verify almost_full asserts at count=6; full=1 at count=8.
    // ==============================================================
    $display("\n--- TC4: Almost-full threshold ---");
    do_reset();

    repeat (5) push(8'hAA);           // count = 1..5 (below threshold)

    push(8'hAA);                      // count = 6
    @(negedge clk);
    check("TC4-A  almost_full=1 at count=6", almost_full, 1'b1);
    check("TC4-B  full=0        at count=6", full,        1'b0);

    push(8'hAA);                      // count = 7
    @(negedge clk);
    check("TC4-C  almost_full=1 at count=7", almost_full, 1'b1);
    check("TC4-D  full=0        at count=7", full,        1'b0);

    push(8'hAA);                      // count = 8
    @(negedge clk);
    check("TC4-E  full=1        at count=8", full,        1'b1);

    // ==============================================================
    // TC5 — Almost-empty threshold  (ALMOST_EMPTY_THRESHOLD = 2)
    // Start with 3 entries; pop one by one; verify almost_empty and
    // empty at each occupancy level.
    // ==============================================================
    $display("\n--- TC5: Almost-empty threshold ---");
    do_reset();

    repeat (3) push(8'hBB);           // count = 3

    pop(rd);                          // count = 2
    @(negedge clk);
    check("TC5-A  almost_empty=1 at count=2", almost_empty, 1'b1);
    check("TC5-B  empty=0        at count=2", empty,        1'b0);

    pop(rd);                          // count = 1
    @(negedge clk);
    check("TC5-C  almost_empty=1 at count=1", almost_empty, 1'b1);
    check("TC5-D  empty=0        at count=1", empty,        1'b0);

    pop(rd);                          // count = 0
    @(negedge clk);
    check("TC5-E  empty=1        at count=0", empty,        1'b1);

    // ==============================================================
    // TC6 — Simultaneous read and write
    // Load 4 entries; assert read_en=1 and write_en=1 in the same
    // cycle; verify count unchanged, correct read value, and that
    // the new entry appears at the correct position in drain order.
    // ==============================================================
    $display("\n--- TC6: Simultaneous read and write ---");
    do_reset();

    push(8'hC1); push(8'hC2);
    push(8'hC3); push(8'hC4);        // count = 4

    // Assert both enables for exactly one clock cycle
    @(negedge clk);
    write_en   = 1;
    write_data = 8'hEF;
    read_en    = 1;
    @(posedge clk);                   // DUT performs R+W simultaneously
    @(negedge clk);
    write_en = 0;
    read_en  = 0;

    // count must still be 4 → neither full nor empty
    check("TC6-A  full=0  after sim R+W",           full,      1'b0);
    check("TC6-B  empty=0 after sim R+W",           empty,     1'b0);
    // read_data must hold the oldest entry (0xC1)
    check("TC6-C  read_data=0xC1 (oldest popped)",  read_data, 8'hC1);

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
    @(negedge clk);
    write_en   = 1;
    write_data = d;
    @(posedge clk);   // DUT captures write_data on this edge
    @(negedge clk);
    write_en = 0;
  endtask

  // ----------------------------------------------------------------
  // Task: pop — read one entry
  // Drives read_en at negedge; samples read_data at the negedge
  // AFTER the posedge that registered the output (Option A semantics).
  // ----------------------------------------------------------------
  task automatic pop(output logic [WIDTH-1:0] d);
    @(negedge clk);
    read_en = 1;
    @(posedge clk);   // DUT updates read_data on this edge
    @(negedge clk);
    d       = read_data;   // stable registered value
    read_en = 0;
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
