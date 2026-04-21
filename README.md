# FIFO_Exercise_1

# Synchronous FIFO Design & Verification Exercise

**Course:** Digital Design with SystemVerilog  
**Topic:** RTL Design and Functional Verification  
**Estimated time:** 3–4 hours

---

## 1. Overview

In this exercise you will design and verify a **synchronous FIFO** (First-In, First-Out) buffer in SystemVerilog. A FIFO is a fundamental building block in digital systems: it decouples producers and consumers that operate at different rates while preserving data order. You will work through two stages:

1. **RTL Design** — implement the FIFO module from the specification below.
2. **Functional Verification** — write a self-checking testbench that exercises the design against all required test cases.

Read this document carefully before writing any code. The specification defines every decision you must make; if something is ambiguous, document your assumption as a comment in the source.

---

## 2. Interface

```systemverilog
module sync_fifo #(
  parameter int unsigned DEPTH                  = 8,
  parameter int unsigned WIDTH                  = 8,
  parameter int unsigned ALMOST_FULL_THRESHOLD  = DEPTH - 1,
  parameter int unsigned ALMOST_EMPTY_THRESHOLD = 1
)(
  input  logic               clk,
  input  logic               rst_n,

  input  logic               write_en,
  input  logic [WIDTH-1:0]   write_data,

  input  logic               read_en,
  output logic [WIDTH-1:0]   read_data,

  output logic               full,
  output logic               empty,
  output logic               almost_full,
  output logic               almost_empty
);
```

### Port descriptions

| Port | Direction | Description |
|---|---|---|
| `clk` | input | System clock. All state updates occur on the rising edge. |
| `rst_n` | input | Active-low reset. See Section 4 for reset behavior. |
| `write_en` | input | Write request. Data is stored when `write_en=1` and `full=0`. |
| `write_data` | input | Data word to push into the FIFO. |
| `read_en` | input | Read request. Data is consumed when `read_en=1` and `empty=0`. |
| `read_data` | output | Data word popped from the FIFO. |
| `full` | output | Asserted when the FIFO holds `DEPTH` valid entries. |
| `empty` | output | Asserted when the FIFO holds 0 valid entries. |
| `almost_full` | output | Asserted when occupancy ≥ `ALMOST_FULL_THRESHOLD`. |
| `almost_empty` | output | Asserted when occupancy ≤ `ALMOST_EMPTY_THRESHOLD`. |

---

## 3. Parameters

| Parameter | Default | Valid range | Description |
|---|---|---|---|
| `DEPTH` | 8 | ≥ 2, power of 2 recommended | Number of storage entries. |
| `WIDTH` | 8 | ≥ 1 | Bit width of each entry. |
| `ALMOST_FULL_THRESHOLD` | `DEPTH-1` | `(ALMOST_EMPTY_THRESHOLD, DEPTH]` | Occupancy level at which `almost_full` is asserted. |
| `ALMOST_EMPTY_THRESHOLD` | 1 | `[1, ALMOST_FULL_THRESHOLD)` | Occupancy level at or below which `almost_empty` is asserted. |

**Parameter constraints** that must hold at elaboration time:

```
0  <  ALMOST_EMPTY_THRESHOLD
      ALMOST_EMPTY_THRESHOLD  <  ALMOST_FULL_THRESHOLD
                                 ALMOST_FULL_THRESHOLD  <=  DEPTH
DEPTH  >=  2
```

Your implementation should use `initial` assertions or `generate` checks to catch illegal parameter combinations and call `$fatal` if any constraint is violated.

---

## 4. Functional Specification

### 4.1 Reset behavior

- Reset type: **asynchronous, active-low** (`negedge rst_n`).
- On reset, the following state is established:
  - Read pointer → 0, Write pointer → 0
  - Occupancy counter → 0
  - `empty = 1`, `full = 0`
  - `almost_full` and `almost_empty` reflect the thresholds applied to a counter value of 0
  - `read_data` → `'0` (defined, no unknowns on the output bus)

### 4.2 Write operation

- A **write is accepted** (`write_fire`) when `write_en = 1` AND `full = 0`.
- On a successful write: `write_data` is stored at the current write pointer address; the write pointer advances (wraps to 0 after reaching `DEPTH-1`).
- If `write_en = 1` but `full = 1` (**overflow**): the operation is **silently ignored**. No data is stored, no pointer advances, no corruption occurs.

### 4.3 Read operation

- A **read is accepted** (`read_fire`) when `read_en = 1` AND `empty = 0`.
- On a successful read: `read_data` is updated with the entry at the current read pointer address; the read pointer advances (wraps to 0 after reaching `DEPTH-1`).
- `read_data` semantics: **registered output** (Option A). `read_data` changes only on a successful read. Between reads, the last valid value is held.
- If `read_en = 1` but `empty = 1` (**underflow**): the operation is **silently ignored**. `read_data` holds its previous value.

### 4.4 Simultaneous read and write

When both `write_fire` and `read_fire` are true in the same clock cycle:

- Both the write and read operations execute.
- Both pointers advance independently.
- The occupancy counter is **unchanged** (one entry in, one entry out).
- This is always legal when the FIFO is neither full nor empty.

### 4.5 Flag generation

All flags are **combinational**, derived directly from the occupancy counter:

| Flag | Condition |
|---|---|
| `full` | `count == DEPTH` |
| `empty` | `count == 0` |
| `almost_full` | `count >= ALMOST_FULL_THRESHOLD` |
| `almost_empty` | `count <= ALMOST_EMPTY_THRESHOLD` |

Because the flags are combinational, they are valid in the same cycle that `count` changes — there is no one-cycle lag.

### 4.6 Occupancy counter

- The counter has `$clog2(DEPTH) + 1` bits so it can represent the value `DEPTH` exactly.
- Update rules (applied every rising clock edge):

| `write_fire` | `read_fire` | Counter update |
|:---:|:---:|---|
| 1 | 0 | `count + 1` |
| 0 | 1 | `count - 1` |
| 1 | 1 | unchanged (simultaneous) |
| 0 | 0 | unchanged (idle) |

---

## 5. Internal Architecture

You are free to choose any implementation that satisfies the specification. A typical approach uses:

- A **memory array** `mem[0:DEPTH-1]` of `WIDTH`-bit words.
- A **write pointer** `wr_ptr` of width `$clog2(DEPTH)` bits.
- A **read pointer** `rd_ptr` of width `$clog2(DEPTH)` bits.
- An **occupancy counter** `count` of width `$clog2(DEPTH)+1` bits.

Both pointers use **explicit wrap-around**: when a pointer reaches `DEPTH-1` it resets to 0 on the next increment. This works correctly for any value of `DEPTH`, not only powers of two.

```
  write_en ─────► [Guard: !full]  ──write_fire──► mem[wr_ptr] ◄─ write_data
                                                       │
  read_en  ─────► [Guard: !empty] ──read_fire──►  read_data ◄─── mem[rd_ptr]
                                        │
                              ┌─────────┴──────────┐
                              │    count register   │
                              └─────────┬──────────┘
                                        │
                          ┌─────────────┼─────────────┐
                        full          empty      almost_*
```

---

## 6. Test Cases

Your testbench must implement and pass all six test cases below. Each test case is self-checking: it must print `PASS` or `FAIL` with a descriptive label for every assertion, and report a final summary of the form `=== N passed  M failed ===`.

Use `DEPTH=8`, `WIDTH=8`, `ALMOST_FULL_THRESHOLD=6`, `ALMOST_EMPTY_THRESHOLD=2` for all tests unless stated otherwise.

---

### TC1 — Basic FIFO order

**Objective:** Verify that entries are returned in push order (FIFO property).

**Stimulus:**
1. Push `0xAA`, `0xBB`, `0xCC` in sequence.
2. Pop three times.

**Expected results:**

| Pop # | Expected `read_data` |
|:---:|:---:|
| 1 | `0xAA` |
| 2 | `0xBB` |
| 3 | `0xCC` |

---

### TC2 — Full flag and overflow protection

**Objective:** Verify `full` asserts at capacity and that overflow is ignored.

**Stimulus:**
1. Push 8 entries (fills the FIFO).
2. Check `full`.
3. Attempt a 9th push (`write_en=1` while `full=1`).
4. Check `full` again.

**Expected results:**

| Checkpoint | Expected |
|---|---|
| After 8th push | `full = 1` |
| After overflow attempt | `full = 1` (unchanged), count still 8 |

---

### TC3 — Empty flag and underflow protection

**Objective:** Verify `empty` asserts when all entries are consumed and that underflow is ignored.

**Stimulus:**
1. Push 3 entries, then pop 3 entries.
2. Check `empty`.
3. Attempt a 4th pop (`read_en=1` while `empty=1`).
4. Check `empty` again.

**Expected results:**

| Checkpoint | Expected |
|---|---|
| After 3rd pop | `empty = 1` |
| After underflow attempt | `empty = 1` (unchanged), count still 0 |

---

### TC4 — Almost-full threshold

**Objective:** Verify `almost_full` asserts and de-asserts at the correct occupancy levels.

**Stimulus:** Starting from an empty FIFO, push entries one by one.

**Expected results:**

| Count after push | `almost_full` | `full` |
|:---:|:---:|:---:|
| 1 – 5 | 0 | 0 |
| 6 | 1 | 0 |
| 7 | 1 | 0 |
| 8 | 1 | 1 |

---

### TC5 — Almost-empty threshold

**Objective:** Verify `almost_empty` asserts and de-asserts at the correct occupancy levels.

**Stimulus:** Push 3 entries, then pop one by one.

**Expected results:**

| Count after pop | `almost_empty` | `empty` |
|:---:|:---:|:---:|
| 2 | 1 | 0 |
| 1 | 1 | 0 |
| 0 | 1 | 1 |

> Note: when `empty=1` and `ALMOST_EMPTY_THRESHOLD ≥ 1`, the almost_empty flag will also be asserted (0 ≤ threshold). This is correct behavior.

---

### TC6 — Simultaneous read and write

**Objective:** Verify that a concurrent read and write in the same cycle preserves occupancy and correctly updates both pointers.

**Stimulus:**
1. Push 4 entries: `0xC1`, `0xC2`, `0xC3`, `0xC4` (count = 4).
2. In a single clock cycle, assert `write_en=1` (`write_data=0xEF`) and `read_en=1`.
3. After the cycle, drain the remaining entries.

**Expected results:**

| Checkpoint | Expected |
|---|---|
| After simultaneous cycle | `full=0`, `empty=0`, count still 4 |
| `read_data` after simultaneous cycle | `0xC1` (oldest entry) |
| Drain order | `0xC2`, `0xC3`, `0xC4`, `0xEF` |

---

## 7. Testbench Requirements

Your testbench (`tb.sv`) must satisfy the following constraints:

**Clock:** 10 ns period (toggle every 5 ns).

**Reset sequence:** Drive `rst_n=0` for at least two rising clock edges, then release.

**Task `push`:** Drives `write_en` and `write_data`; deasserts `write_en` after one clock cycle. Signals must be driven at the negedge to provide setup margin to the following posedge.

**Task `pop`:** Drives `read_en` for one clock cycle; captures `read_data` after the posedge that registered the output (i.e., on the following negedge or later), ensuring the registered value is stable.

**Checking:** Every assertion prints a one-line result. The testbench ends with a summary line and calls `$finish`.

**Reset between test cases:** Issue a fresh reset before TC3 through TC6 to restore a known state.

---

## 8. Deliverables

| File | Contents |
|---|---|
| `sync_fifo.sv` | RTL implementation of the FIFO module. |
| `tb.sv` | Self-checking testbench covering TC1 – TC6. |

Both files must elaborate and simulate without errors using an IEEE 1800-2017 compliant simulator (e.g., ModelSim, Xcelium, VCS, Verilator ≥ 5.0).

---

## 9. Evaluation Criteria

| Criterion | Weight |
|---|---|
| All 6 test cases pass (TC1 – TC6) | 40 % |
| RTL quality: clean structure, correct use of `always_ff` / `assign`, no latches | 20 % |
| Parameterization: design works for any valid `DEPTH`, `WIDTH`, and threshold values | 15 % |
| Parameter checks: illegal combinations caught at elaboration time | 10 % |
| Testbench quality: self-checking, readable, correct timing discipline | 15 % |

---

## 10. Hints and Guidance

- Start with the **occupancy counter** and the **flags**. Once those are correct, the rest of the logic follows naturally.
- The `$clog2` function returns the ceiling log₂. For `DEPTH=8`, `$clog2(8) = 3`, so the address width is 3 bits (indices 0–7) and the counter width is 4 bits (values 0–8).
- Use `unique case` for the counter update to get exhaustive checking from the simulator.
- The registered read output (Option A) means `read_data` **does not change** unless a valid read fires. This simplifies timing analysis and is the expected behavior in this exercise.
- For the pointer wrap: `(ptr == DEPTH-1) ? '0 : ptr + 1'b1` is more portable than relying on natural binary overflow, and handles non-power-of-2 depths correctly.
- Write your testbench tasks to drive signals at the **negedge** and observe outputs after the following **posedge**. This gives a clean, simulator-independent timing contract.
- Use `===` (case equality) instead of `==` in testbench comparisons to catch `X` and `Z` values.

---

*End of specification*
