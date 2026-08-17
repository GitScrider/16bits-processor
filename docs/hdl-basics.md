# HDL basics — learning SystemVerilog through this processor

A hands-on reference. Part 1 is the small set of ideas you need; Part 2 teaches each idea again
through the actual modules of this CPU, so every concept has a real file you can open and run.

> Coming from classic Verilog (`reg`, `wire`, `always`)? SystemVerilog is a **superset** — your old
> code still works. Everything below is an *addition* that makes intent clearer and catches mistakes.

---

## Part 1 — The essentials

### 1. `logic` replaces `reg` and `wire`
Classic Verilog made you choose between `wire` (driven by `assign` / module outputs) and `reg`
(assigned inside `always`/`initial`) — and confusingly, `reg` never meant "register". SystemVerilog
gives you **one type, `logic`**, usable in `assign`, inside `always`, and on ports. It is still
4-state (0, 1, X, Z).

The only catch: `logic` allows a **single driver**. For a genuine multi-driver net (e.g. a tri-state
bus) you still use `wire`. That is rare, so in practice you use `logic` for almost everything.

### 2. Labelled `always` blocks: `always_ff` / `always_comb` / `always_latch`
Classic Verilog used one keyword, `always`, for both flip-flops and combinational logic — and nothing
checked which you meant. SystemVerilog adds intent-specific blocks that the tool verifies for you:

| You want… | Write | The tool guarantees |
|---|---|---|
| Flip-flop (sequential) | `always_ff @(posedge clk)` | it really is edge-triggered |
| Combinational | `always_comb` | builds the sensitivity list for you, **warns on accidental latches** |
| Latch (rare) | `always_latch` | you meant it |

You *can* still use plain `always` — it compiles the same. The labelled versions are free insurance
and, while learning, the block name tells you at a glance whether the logic is sequential or
combinational.

### 3. The one question: "does it need to REMEMBER between clock edges?"
This decides everything:

- **No → combinational.** Output is a pure function of the current inputs. Use `always_comb` (or an
  `assign`). Example: the ALU, the control unit, a register-file read.
- **Yes → sequential.** It stores state that persists across cycles. Use `always_ff @(posedge clk)`.
  Example: the program counter, the register-file write, the sequencer.

### 4. Blocking `=` vs non-blocking `<=`
- In **`always_comb`** use blocking `=` (evaluate in order, like normal code).
- In **`always_ff`** use non-blocking `<=` (all right-hand sides are sampled, then every register
  updates together on the edge). This models real flip-flops correctly.
- **Rule of thumb:** `always_comb` → `=`; `always_ff` → `<=`. Don't mix, and don't drive the same
  signal from two blocks.

### 5. Synchronous vs asynchronous reset
- **Synchronous** (our default): `rst` is tested *inside* the clocked block, so it acts only on a
  clock edge.
  ```systemverilog
  always_ff @(posedge clk)
      if (rst) q <= '0;        // waits for the clock
      else     q <= d;
  ```
- **Asynchronous**: `rst` is in the sensitivity list, so it acts immediately.
  ```systemverilog
  always_ff @(posedge clk or posedge rst)   // acts at once
  ```
  Mostly used for a power-on reset. Synchronous is the safe default on FPGAs.

### 6. Avoiding accidental latches
Inside an `always_comb`, if some path leaves an output unassigned, the tool must "keep the old value"
— i.e. it infers a **latch**, which is almost never what you want. The fix: **assign every output a
default at the top of the block**, then override per case. (See the control unit below.)

---

## Part 2 — Learn it through our modules

Each module is a small, verified example of one idea. Open the file, read the header comments, run
its testbench (`powershell -ExecutionPolicy Bypass -File sim\run.ps1 <module>`), and — for the
sequential ones — watch the waveform (`... run.ps1 <module> -Wave`).

### ALU — [`rtl/alu.sv`](../rtl/alu.sv) · combinational
The purest combinational block: `result` is a function of `a`, `b` and the operation select, with no
clock. Written as an `always_comb` + `case`. This is the "wire that computes" side of the coin.

### Register file — [`rtl/regfile.sv`](../rtl/regfile.sv) · both at once
The best single example, because it holds both worlds side by side: **writing is sequential**
(`always_ff` + `<=`, gated by a write-enable) while **reading is combinational** (two `assign`
statements — the output follows the selector immediately). It also shows a synchronous reset and the
read-during-write subtlety (a combinational read sees the *old* value until the clock edge).

### Control unit — [`rtl/control.sv`](../rtl/control.sv) · combinational (a truth table in code)
A decoder is a truth table cast into gates: no state, no clock, outputs are a direct function of the
4-bit opcode. It is a single `always_comb` wrapping a `case (op)`, where each arm is one row of the
ISA's control table. **Every output is defaulted to 0 before the `case`** — the key habit that makes
the block latch-free (see essential #6). Because there are only 16 opcodes, the testbench is
**exhaustive**: it checks all 16, which is the strongest possible proof.

### Program counter — [`rtl/pc.sv`](../rtl/pc.sv) · sequential (a register that remembers)
The simplest interesting sequential block: a register updated in `always_ff` with `<=`. Its logic is
**priority**, an `if / else-if` chain — `rst` beats `load` (jump/branch) beats `en` (advance) — and
the last, empty case is **hold** (assign nothing and the flip-flops keep their value, which is how the
PC waits during a multi-cycle instruction). Fixed-width `+ 1` wraps at `2**W` for free.

### Instruction memory — [`rtl/imem.sv`](../rtl/imem.sv) · memory as an array (ROM)
"Memory" is just an array: `logic [15:0] mem [0:15]` — the `[15:0]` before the name is the word width
(packed), the `[0:15]` after is the number of words (unpacked). It is a **ROM** because it has *no
write path* (the program is fixed), and its read is **combinational** (`assign instr = mem[addr]`).
Contents are loaded in an `initial` block (or via `$readmemh` from an assembler's output).

### Data memory — [`rtl/dmem.sv`](../rtl/dmem.sv) · RAM + block-RAM timing
A **RAM**: written (sequentially, gated by `we`) and read while the processor runs. The twist is a
**registered read** (`rdata <= mem[addr]`), which adds a deliberate **one-cycle read latency**. Why
pay it? Because that timing is what lets the huge array map onto the FPGA's dedicated **block RAM**
(M9K on the Cyclone IV E); a combinational read would force tiny distributed RAM that could never fit
2¹⁶ words. Contrast with the register file: tiny + same-cycle read → logic; large + 1-cycle read →
block RAM.

### Sequencer — [`rtl/sequencer.sv`](../rtl/sequencer.sv) · a one-hot state machine
State lives in the 5-bit `phase` register, updated in one `always_ff`. The encoding is **one-hot**
(exactly one bit set), so each bit *is* a phase-enable signal — no decoder needed. The next-state rule
is a **ring counter**: rotate the bits by one each clock (`{phase[3:0], phase[4]}`), so the single 1
circles endlessly (00001 → 00010 → … → 10000 → 00001). Reset defines the start state (phase PC), and a
small all-zero guard makes it self-healing.

---

## Verifying everything
Every module has a self-checking testbench that compares it against a reference model and prints
`RESULT: PASS`/`FAIL`. Run one with `sim\run.ps1 <module>`; add `-Wave` to inspect signals over time
in ModelSim. See [`sim/README.md`](../sim/README.md) for the full list and the waveform flow, and
[`verification.md`](verification.md) for the broader strategy (including formal).
