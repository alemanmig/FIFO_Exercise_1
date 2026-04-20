# Synchronous FIFO — Verification Plan

**Course:** Digital Design with SystemVerilog  
**Topic:** Functional Verification  
**Prerequisite:** `sync_fifo_spec.md` — read and implement the RTL before starting this document  
**Estimated time:** 2–3 hours

---

## 1. Scope

This document defines the verification plan for the `sync_fifo` module specified in `sync_fifo_spec.md`. It covers:

- The verification goals and what is **in** and **out** of scope.
- The testbench architecture and timing contract.
- The six test cases (TC1–TC6) with explicit stimulus sequences and pass/fail criteria.
- Deliverable requirements and evaluation criteria.

The RTL interface and functional rules are **not repeated here**. If you need to consult them, refer to `sync_fifo_spec.md`.

---

## 2. Verification Goals

The objective is to demonstrate, through directed simulation, that the DUT (`sync_fifo`) correctly implements every behavioral requirement of the specification. The testbench must be **self-checking**: it prints a labelled `PASS` or `FAIL` line for every assertion and exits with a final summary.

### In scope

- Functional correctness of all six test cases under the nominal parameter set (`DEPTH=8`, `WIDTH=8`, `ALMOST_FULL_THRESHOLD=6`, `ALMOST_EMPTY_THRESHOLD=2`).
- Reset behavior: state clears correctly and flags reflect a valid initial state.
- Write path: data stored in FIFO order; overflow silently ignored.
- Read path: data returned in FIFO order; underflow silently ignored; registered output holds last valid value.
- Flag generation: `full`, `empty`, `almost_full`, `almost_empty` assert and de-assert at the correct occupancy boundaries.
- Simultaneous read + write: occupancy unchanged; both pointers advance; oldest entry read; newest entry stored.

### Out of scope

- Formal property verification (SVA / model checking).
- Random / constrained-random stimulus.
- Coverage collection.
- Back-annotated timing simulation.
- Parameter sweeps (non-default `DEPTH`, `WIDTH`, or threshold values).

---

## 3. Testbench Architecture

### 3.1 Top-level structure

```
┌──────────────────────────────────────────────────────┐
│  module tb                                           │
│                                                      │
│  ┌─────────────┐      ┌──────────────────────────┐  │
│  │  Clock gen  │─clk─►│                          │  │
│  └─────────────┘      │       DUT                │  │
│                        │    sync_fifo             │  │
│  ┌─────────────┐      │                          │  │
│  │  Stimulus   │─────►│  write_en / write_data   │  │
│  │  (initial)  │      │  read_en                 │  │
│  │             │◄─────│  read_data               │  │
│  │  push()     │      │  full / empty            │  │
│  │  pop()      │      │  almost_full/empty       │  │
│  │  check()    │      │                          │  │
│  │  do_reset() │      └──────────────────────────┘  │
│  └─────────────┘                                     │
└──────────────────────────────────────────────────────┘
```

### 3.2 Parameters

Instantiate the DUT with the following parameter values. These must match the RTL port names exactly.

```systemverilog
localparam int unsigned DEPTH                  = 8;
localparam int unsigned WIDTH                  = 8;
localparam int unsigned ALMOST_FULL_THRESHOLD  = 6;
localparam int unsigned ALMOST_EMPTY_THRESHOLD = 2;
```

### 3.3 Clock

- Period: **10 ns** (toggle every 5 ns).
- Starting value: `clk = 0` at time 0.

```systemverilog
initial clk = 0;
always #5 clk = ~clk;
```

### 3.4 Timing contract

All stimulus is driven at the **negedge** of the clock to guarantee setup and hold margin at the DUT's posedge-triggered flip-flops. Outputs are sampled after the DUT has had a full clock cycle to settle.

```
negedge        posedge        negedge        posedge
   │              │              │              │
   ├── drive ─────┤              ├── drive ─────┤
   │              └── DUT FF ───►└── sample ───►│
```

This contract is enforced by the `push` and `pop` tasks described below.

---

## 4. Task Definitions

### 4.1 `push` — write one entry

```
Drives write_en=1 and write_data at negedge.
Waits for the capturing posedge (DUT stores the data).
Deasserts write_en at the following negedge.
```

```systemverilog
task automatic push(input logic [WIDTH-1:0] d);
  @(negedge clk);
  write_en   = 1;
  write_data = d;
  @(posedge clk);   // DUT captures write_data here
  @(negedge clk);
  write_en = 0;
endtask
```

### 4.2 `pop` — read one entry

```
Drives read_en=1 at negedge.
Waits for the capturing posedge (DUT registers read_data).
Samples read_data at the following negedge (output is stable).
Deasserts read_en.
```

```systemverilog
task automatic pop(output logic [WIDTH-1:0] d);
  @(negedge clk);
  read_en = 1;
  @(posedge clk);   // DUT updates read_data here (registered output)
  @(negedge clk);
  d       = read_data;  // sample stable registered value
  read_en = 0;
endtask
```

> **Why sample after posedge?** The DUT uses a registered (Option A) read output: `read_data` is a flip-flop that updates on the posedge when `read_fire` is true. Sampling before that posedge would capture the *previous* value.

### 4.3 `check` — compare and report

```systemverilog
task automatic check(
  input string       label,
  input logic [31:0] got,
  input logic [31:0] exp
);
  if (got === exp) begin          // === catches X and Z
    p++;
    $display("PASS: %s  (got=0x%0h)", label, got);
  end else begin
    f++;
    $display("FAIL: %s  expected=0x%0h  got=0x%0h", label, exp, got);
  end
endtask
```

> Use `===` (case equality) instead of `==` so that unknown (`X`) or high-impedance (`Z`) values on the DUT outputs are caught and reported as failures rather than passing silently.

### 4.4 `do_reset` — apply reset sequence

```systemverilog
task automatic do_reset();
  rst_n    = 0;
  write_en = 0;
  read_en  = 0;
  @(posedge clk);   // hold reset for at least 2 rising edges
  @(posedge clk);
  rst_n = 1;
  @(posedge clk);   // one idle cycle before stimulus
endtask
```

Call `do_reset()` at the start of the simulation and before each test case that needs a clean state.

---

## 5. Test Cases

### TC1 — Basic FIFO order

**Purpose:** Verify that entries are returned in push order (FIFO property, not LIFO or random).

**Setup:** Empty FIFO after reset.

**Stimulus sequence:**

| Step | Action |
|---|---|
| 1 | `push(0xAA)` |
| 2 | `push(0xBB)` |
| 3 | `push(0xCC)` |
| 4 | `pop(rd)` |
| 5 | `pop(rd)` |
| 6 | `pop(rd)` |

**Assertions:**

| ID | Signal checked | Expected value | Description |
|---|---|---|---|
| TC1-A | `rd` after pop 1 | `0xAA` | First-in, first-out |
| TC1-B | `rd` after pop 2 | `0xBB` | Second entry returned second |
| TC1-C | `rd` after pop 3 | `0xCC` | Third entry returned third |

---

### TC2 — Full flag and overflow protection

**Purpose:** Verify that `full` asserts at capacity and that a write attempt while full is ignored without corrupting state.

**Setup:** Empty FIFO after reset. Note: TC1 leaves the FIFO empty (3 pushed, 3 popped), so a reset is not strictly required — but issuing one is good practice for test isolation.

**Stimulus sequence:**

| Step | Action |
|---|---|
| 1–8 | `push(0xFF)` × 8 |
| 9 | Sample `full` at negedge |
| 10 | `push(0xEE)` (overflow attempt) |
| 11 | Sample `full` at negedge |

**Assertions:**

| ID | Signal checked | Expected value | Description |
|---|---|---|---|
| TC2-A | `full` after step 9 | `1` | FIFO is full after 8 writes |
| TC2-B | `full` after step 11 | `1` | `full` stays asserted after overflow attempt |

> TC2 does not verify that `0xEE` was not stored (that is covered implicitly by TC6's drain sequence). If you want to make it explicit, drain the FIFO after TC2 and verify all 8 entries contain `0xFF`.

---

### TC3 — Empty flag and underflow protection

**Purpose:** Verify that `empty` asserts when all entries are consumed and that a read attempt while empty is ignored.

**Setup:** Empty FIFO after `do_reset()`.

**Stimulus sequence:**

| Step | Action |
|---|---|
| 1 | `push(0x01)` |
| 2 | `push(0x02)` |
| 3 | `push(0x03)` |
| 4–6 | `pop(rd)` × 3 |
| 7 | Sample `empty` at negedge |
| 8 | Drive `read_en=1`, wait posedge, drive `read_en=0` (underflow attempt) |
| 9 | Sample `empty` at negedge |

**Assertions:**

| ID | Signal checked | Expected value | Description |
|---|---|---|---|
| TC3-A | `empty` after step 7 | `1` | FIFO is empty after 3 reads |
| TC3-B | `empty` after step 9 | `1` | `empty` stays asserted after underflow attempt |

---

### TC4 — Almost-full threshold

**Purpose:** Verify that `almost_full` asserts at the correct occupancy level and that the relationship between `almost_full` and `full` is correct across the boundary.

**Setup:** Empty FIFO after `do_reset()`.

**Stimulus sequence:** Push entries one at a time, sampling flags after each.

| Step | Action | Count after |
|---|---|:---:|
| 1–5 | `push(0xAA)` × 5 | 5 |
| 6 | `push(0xAA)` | 6 |
| 7 | `push(0xAA)` | 7 |
| 8 | `push(0xAA)` | 8 |

**Assertions:**

| ID | Count | Signal checked | Expected value | Description |
|---|:---:|---|---|---|
| TC4-A | 6 | `almost_full` | `1` | Threshold reached |
| TC4-B | 6 | `full` | `0` | Not yet full |
| TC4-C | 7 | `almost_full` | `1` | Still above threshold |
| TC4-D | 7 | `full` | `0` | Still not full |
| TC4-E | 8 | `full` | `1` | FIFO is now full |

> You may optionally add assertions for counts 1–5 to verify `almost_full=0` before the threshold.

---

### TC5 — Almost-empty threshold

**Purpose:** Verify that `almost_empty` asserts at the correct occupancy level and that the relationship between `almost_empty` and `empty` is correct as the FIFO drains.

**Setup:** Empty FIFO after `do_reset()`.

**Stimulus sequence:**

| Step | Action | Count after |
|---|---|:---:|
| 1–3 | `push(0xBB)` × 3 | 3 |
| 4 | `pop(rd)` | 2 |
| 5 | `pop(rd)` | 1 |
| 6 | `pop(rd)` | 0 |

**Assertions:**

| ID | Count | Signal checked | Expected value | Description |
|---|:---:|---|---|---|
| TC5-A | 2 | `almost_empty` | `1` | At threshold |
| TC5-B | 2 | `empty` | `0` | Not yet empty |
| TC5-C | 1 | `almost_empty` | `1` | Below threshold |
| TC5-D | 1 | `empty` | `0` | Still not empty |
| TC5-E | 0 | `empty` | `1` | FIFO is now empty |

> When `empty=1` and `ALMOST_EMPTY_THRESHOLD ≥ 1`, `almost_empty` will also be asserted (0 ≤ threshold). This is correct and expected — both flags may be high simultaneously.

---

### TC6 — Simultaneous read and write

**Purpose:** Verify that asserting `read_en` and `write_en` in the same clock cycle correctly performs both operations, leaves occupancy unchanged, and preserves FIFO order.

**Setup:** Empty FIFO after `do_reset()`.

**Stimulus sequence:**

| Step | Action | Count after |
|---|---|:---:|
| 1 | `push(0xC1)` | 1 |
| 2 | `push(0xC2)` | 2 |
| 3 | `push(0xC3)` | 3 |
| 4 | `push(0xC4)` | 4 |
| 5 | Drive `write_en=1`, `write_data=0xEF`, `read_en=1` at negedge | — |
| 6 | Wait posedge (simultaneous R+W captured) | 4 |
| 7 | Drive `write_en=0`, `read_en=0` at negedge | — |
| 8–11 | `pop(rd)` × 4 (drain remaining entries) | 0 |

**Assertions:**

| ID | Signal checked | Expected value | Description |
|---|---|---|---|
| TC6-A | `full` after step 7 | `0` | Count still 4, not full |
| TC6-B | `empty` after step 7 | `0` | Count still 4, not empty |
| TC6-C | `read_data` after step 7 | `0xC1` | Oldest entry was read |
| TC6-D | `rd` after pop 1 (step 8) | `0xC2` | FIFO order preserved |
| TC6-E | `rd` after pop 2 (step 9) | `0xC3` | FIFO order preserved |
| TC6-F | `rd` after pop 3 (step 10) | `0xC4` | FIFO order preserved |
| TC6-G | `rd` after pop 4 (step 11) | `0xEF` | New entry written in correct position |

> TC6-G is the most important assertion in this test case: it proves that `0xEF` was stored *after* the existing four entries, confirming that the write pointer advanced correctly during the simultaneous cycle.

---

## 6. Pass / Fail Summary

At the end of simulation the testbench must print a single summary line:

```
=== N passed  M failed ===
```

where `N + M` equals the total number of assertions executed. The simulation then calls `$finish`.

A run is considered **fully passing** when `M = 0`. Any non-zero `M` must be investigated before the design is considered correct.

---

## 7. Testbench Skeleton

The following skeleton provides the required module header, localparam declarations, DUT instantiation, clock generator, and the four required tasks. Complete the `initial begin ... end` block with the stimulus for TC1–TC6.

```systemverilog
module tb;

  localparam int unsigned DEPTH                  = 8;
  localparam int unsigned WIDTH                  = 8;
  localparam int unsigned ALMOST_FULL_THRESHOLD  = 6;
  localparam int unsigned ALMOST_EMPTY_THRESHOLD = 2;

  logic             clk;
  logic             rst_n;
  logic             write_en;
  logic [WIDTH-1:0] write_data;
  logic             read_en;
  logic [WIDTH-1:0] read_data;
  logic             full, empty, almost_full, almost_empty;

  int p = 0, f = 0;   // pass / fail counters

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // DUT
  sync_fifo #(
    .DEPTH                 (DEPTH),
    .WIDTH                 (WIDTH),
    .ALMOST_FULL_THRESHOLD (ALMOST_FULL_THRESHOLD),
    .ALMOST_EMPTY_THRESHOLD(ALMOST_EMPTY_THRESHOLD)
  ) dut (.*);

  // Tasks
  task automatic push(input logic [WIDTH-1:0] d);
    // TODO: implement per Section 4.1
  endtask

  task automatic pop(output logic [WIDTH-1:0] d);
    // TODO: implement per Section 4.2
  endtask

  task automatic check(
    input string       label,
    input logic [31:0] got,
    input logic [31:0] exp
  );
    // TODO: implement per Section 4.3
  endtask

  task automatic do_reset();
    // TODO: implement per Section 4.4
  endtask

  logic [WIDTH-1:0] rd;

  initial begin
    rst_n      = 0;
    write_en   = 0;
    read_en    = 0;
    write_data = 0;
    do_reset();

    // TODO: TC1 — Basic FIFO order
    // TODO: TC2 — Full flag and overflow protection
    // TODO: TC3 — Empty flag and underflow protection
    // TODO: TC4 — Almost-full threshold
    // TODO: TC5 — Almost-empty threshold
    // TODO: TC6 — Simultaneous read and write

    $display("");
    $display("=== %0d passed  %0d failed ===", p, f);
    $finish;
  end

endmodule
```

---

## 8. Common Mistakes to Avoid

| Mistake | Consequence | Correct approach |
|---|---|---|
| Capturing `read_data` before the posedge that registers it | Always reads previous value; TC1 fails | Sample `read_data` at the negedge *after* the capturing posedge |
| Driving `write_en` or `read_en` at posedge | Setup time violation; non-deterministic behavior | Always drive at negedge |
| Using `==` instead of `===` in assertions | `X` values pass silently | Use `===` (case equality) |
| Forgetting `do_reset()` between test cases | Leftover state causes false failures | Reset before TC3–TC6 at minimum |
| Checking flags at posedge (before count settles in next cycle) | Flags are combinational but count is sequential | Check flags at negedge, one full cycle after the last operation |
| Naming parameters `ALMOST_FULL_THRESH` instead of `ALMOST_FULL_THRESHOLD` | Elaboration error (port mismatch) | Match the RTL parameter names exactly |

---

## 9. Deliverable

| File | Requirements |
|---|---|
| `tb.sv` | Self-checking testbench. All tasks implemented. TC1–TC6 fully stimulated and checked. Ends with summary line and `$finish`. No elaboration errors or warnings. |

The testbench must compile and simulate against the reference `sync_fifo.sv` (provided separately after the exercise) using an IEEE 1800-2017 compliant simulator.

---

## 10. Evaluation Criteria

| Criterion | Weight |
|---|---|
| TC1–TC6 all pass against a correct DUT | 40 % |
| Timing discipline: signals driven at negedge, sampled correctly | 20 % |
| Correct use of `===` in all assertions | 10 % |
| Task implementations match the contracts in Section 4 | 15 % |
| Code readability: labels descriptive, structure clear | 15 % |

---

*End of verification plan*