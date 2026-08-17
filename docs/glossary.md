# Glossary

> Plain-language definitions of the terms used across this project's docs — grounded in how each term actually appears in our 16-bit, MIPS-like, multicycle RISC processor.

This page is a quick reference for a student re-learning their own design and for open-source readers meeting the project for the first time. Each entry gives a general definition, then (where it helps) a sentence on how the term is used in *this* CPU. A few low-level details are still marked **[TO-VERIFY]** — those will be confirmed during RTL bring-up and should not be treated as settled yet.

**Related pages:** [README](../README.md) · the module photos in [`images/`](images/) · planned sibling docs are referenced inline (e.g. [ISA reference](isa.md)) and will be filled in as the documentation set grows.

---

## Architecture & ISA concepts

### RISC (Reduced Instruction Set Computer)
An architecture style built around a small set of simple, fixed-length instructions that each do one thing, which keeps the hardware simpler and easier to reason about. This project is a 16-bit RISC design with a single fixed 16-bit instruction width and 14 defined operations (plus 2 reserved).

### MIPS
A classic RISC instruction set architecture, popular in teaching, known for its clean register-based, load/store design. This CPU is described as *MIPS-like*: it borrows the same spirit — fixed-width instructions, general-purpose registers, and memory reached only through explicit `lw`/`sw` — at a smaller 16-bit scale.

### ISA (Instruction Set Architecture)
The contract between hardware and software: the instructions, registers, and behaviors a programmer can rely on, independent of how the chip is physically built. Here the ISA has 16 general-purpose registers, a 16-bit word, and instructions such as `add`, `addi`, `lw`, `sw`, `slt`, `beqz`, and `j` (see the full [ISA reference](isa.md)).

### Opcode
The field of an instruction that says *which* operation to perform. In this design the opcode is the 4-bit `OP` field, giving 16 possible codes (14 defined, 2 reserved). Its exact bit position — most-significant nibble vs least-significant nibble — is **[TO-VERIFY]**; the docs present `OP` as the most-significant nibble, with the field endianness to be confirmed during RTL bring-up.

### Immediate
A constant value encoded directly inside the instruction, rather than read from a register. Here the immediate shares the 4-bit `RY/I` field with the second source register, so immediate values (and jump/branch targets) are limited to the range 0..15.

### Sign extension / zero extension
Two ways to widen a short value to the full word width: **sign extension** copies the value's top bit into the new high bits to preserve a signed number, while **zero extension** pads with zeros for an unsigned number. A sign/zero "extend" block appears on the schematic to widen the 4-bit immediate to 16 bits; whether it sign- or zero-extends is **[TO-VERIFY]** and to be confirmed during RTL bring-up (documented as configurable for now).

---

## Microarchitecture & datapath

### Datapath
The network of functional units (ALU, register file, memories, multiplexers, PC) plus the buses that carry data between them — the "roads" the data travels while the control unit works the "traffic lights." The top-level datapath is captured in [`images/01-datapath-toplevel.jpg`](images/01-datapath-toplevel.jpg).

### Control unit
The block that decodes the opcode and produces the control signals that steer the datapath for each instruction. Called **"UNIDADE DE CONTROLE"** in the schematic ([`images/03-unidade-controle.jpg`](images/03-unidade-controle.jpg)); it decodes the 4-bit opcode and emits signals such as `Jump`, `ALUscr`, `RW`, `MemWrite`, `Branch`, and the 3-bit `ULAOP`.

### ALU (Arithmetic Logic Unit)
The calculator of the CPU: it takes two operands and produces a result plus status flags. Called **"ULA"** here ([`images/04-ula.jpg`](images/04-ula.jpg)); it performs add, subtract, multiply, divide, and set-less-than, chosen by the 3-bit `ULAOP` select, and produces a `ZERO` flag that the branch logic uses for `beqz`.

### Register file
The bank of fast, addressable general-purpose registers the CPU reads operands from and writes results to. Here it holds 16 registers of 16 bits each — a 4×4 grid of D-flip-flop registers ([`images/02-banco-registradores.jpg`](images/02-banco-registradores.jpg)) — with a write DEMUX routing the result to the register chosen by `RD` and two read MUXes selecting `RX` and `RY`.

### Program counter (PC)
The register holding the address of the instruction to execute. It addresses the 16-word instruction memory (only ~4 address bits are needed); by default `PC ← PC + 1`, and on a `j` or a taken `beqz` it instead loads the 4-bit target.

### Single-cycle vs multicycle vs pipelined
Three ways to time instruction execution:

| Style | How instructions are timed | This project |
|-------|----------------------------|--------------|
| **Single-cycle** | Every instruction finishes in one (long) clock; the clock must be slow enough for the slowest instruction. | Not used. |
| **Multicycle** | Each instruction is split into several shorter steps of one clock each, reusing hardware across steps; complex instructions simply take more steps. | **This CPU** — a fixed 5-phase sequence per instruction. |
| **Pipelined** | Several instructions are in flight at once, each in a different stage, like an assembly line, for higher throughput. | Not used; listed only as a comparison. |

### Machine phase / machine cycle
In a multicycle CPU, a **machine phase** is one of the discrete time steps an instruction passes through, and a **machine cycle** is the full sequence of them for one instruction. Here every instruction walks through all five phases — even if it doesn't need a given stage — driven by the clock sequencer:

```mermaid
flowchart LR
  P1["Phase 1: PC"] --> P2["Phase 2: Fetch / Decode"] --> P3["Phase 3: Execute"] --> P4["Phase 4: Memory"] --> P5["Phase 5: Write-back"] --> P1
```

Distinct clock strobes derive from these phases, e.g. `ClockBR` (register read, ~phase 2), the ALU output-register clock (~phase 3), and `ClockWB` (write-back, ~phase 5). The exact phase at which `j`/`beqz` commit the new PC is **[TO-VERIFY]** and to be confirmed during RTL bring-up.

### One-hot encoding
A representation in which exactly one bit of a group is `1` at any time. The 5-phase clock sequencer is a **one-hot ring** of 5 D-flip-flops ([`images/05-sequenciador-clock.jpg`](images/05-sequenciador-clock.jpg)), so exactly one machine phase is active per clock; "the sequencer is always one-hot" is one of the properties earmarked for formal verification.

---

## HDL & RTL design

### RTL (Register-Transfer Level)
A way of describing hardware in terms of the registers that hold state and the logic that moves and transforms data between them on each clock edge. The FPGA effort re-expresses the Logisim design as hand-written, synthesizable RTL, brought up one module at a time.

### HDL (Hardware Description Language)
A programming-like language for describing digital hardware — both its structure and its behavior — that tools can simulate and synthesize. This project's HDL is SystemVerilog.

### SystemVerilog
A modern HDL (a superset of Verilog) used for both design and verification, adding richer data types and an assertion feature set. The project's RTL and testbenches are written in SystemVerilog, and its assertion subset (SVA) is used for the formal checks.

---

## Synthesis & FPGA

### Synthesis
Translating HDL/RTL into a netlist of real hardware primitives — gates, LUTs, DSP blocks, and registers — that can be placed onto an FPGA. Quartus performs synthesis targeting the Cyclone IV E device.

### FPGA (Field-Programmable Gate Array)
A reconfigurable chip whose logic blocks and interconnect can be programmed to implement arbitrary digital circuits. The target FPGA here is the Cyclone IV E on the DE2-115 board.

### LUT (Look-Up Table)
The basic combinational building block of an FPGA: a tiny memory that can implement any logic function of its handful of inputs. Synthesizing the CPU's combinational logic — the opcode decoder, the muxes, the adders — maps it onto the Cyclone IV E's LUTs.

### DSP block
A dedicated hardware multiply/arithmetic unit built into the FPGA fabric, faster and more area-efficient than building a multiplier out of LUTs. The design's multiply can map to DSP blocks on the FPGA; **divide, however, cannot complete in a single clock in real hardware** and must become an iterative, multi-cycle unit during RTL bring-up (a known limitation carried over from the Logisim build).

### DE2-115
The Altera/Intel development board targeted for hardware bring-up. It carries the Cyclone IV E FPGA together with the switches (`SW`), push-buttons (`KEY`), LEDs (`LEDR`), and 7-segment displays (`HEX`) that the demo applications use for input and output (see the [FPGA bring-up guide](fpga-bringup.md)).

### Cyclone IV E
The specific Intel/Altera FPGA family on the DE2-115; the exact device is **EP4CE115F29C7**. All synthesis and pin assignments target this part.

### Quartus
Intel's FPGA design software — here **Quartus Prime Lite** — used to synthesize, place-and-route, assign pins, program the board, and run tools such as the RTL Viewer and SignalTap.

### SignalTap
Quartus's on-chip logic analyzer (**SignalTap II**) that captures real signal traces from the running FPGA and streams them back to the host, so you can debug on actual hardware rather than only in simulation. It is the planned way to observe the CPU's internal signals on the DE2-115.

### USB-Blaster
The standard Intel/Altera JTAG download cable/interface used to program an FPGA and to carry logic-analyzer captures between the host PC and the board. In this project it is the link that Quartus (programming) and SignalTap (capture) would use to reach the DE2-115 during hardware bring-up.

---

## Verification & simulation

### Testbench
A simulation-only module that drives a design with stimulus and checks its outputs — ideally *self-checking*, reporting pass/fail rather than requiring you to eyeball the result. The plan calls for a self-checking testbench for each module (using Icarus Verilog, Verilator, or ModelSim-Intel).

### Simulation
Running the HDL model in software to observe its behavior over time, before — or instead of — putting it on hardware. It is used here both to validate each module in isolation and to co-simulate the SystemVerilog against the original Logisim run.

### Waveform
A time-vs-signal plot produced by simulation, showing how each signal changes cycle by cycle; it is the primary tool for debugging a design's timing. Waveforms here are viewed in GTKWave or ModelSim.

### Formal verification
Instead of trying inputs one at a time, a solver *mathematically proves* that a stated property holds for **all** possible inputs. The plan uses it to prove properties such as "the sequencer is always one-hot," "`slt` sets exactly 0 or 1," and "the PC only ever changes by +1 or to a valid target" (see the [verification plan](verification.md)).

### Bounded model checking
A formal technique that exhaustively checks whether a property can be violated within a *bounded* number of clock cycles starting from reset. It is the engine behind the formal checks here, run via SymbiYosys (SBY) on top of yosys.

### SVA (SystemVerilog Assertions)
The SystemVerilog sublanguage for stating properties a design must always satisfy — for example, an assertion that exactly one phase bit is high at all times. These assertions are exactly what the formal tool is asked to prove.

---

## Tooling & file formats

### `.mem` image
A memory-initialization file that preloads a RAM's or ROM's contents. Here it is Logisim's **"v2.0 raw"** hex format; the sample program [`loop.mem`](../logisim/programs/loop.mem) is a 7-word image loaded into the 16-word instruction memory. It demonstrates a nested-loop shape built from `j`, `slt`, and `beqz` — the exact instruction-by-instruction decode depends on the field endianness above and is **[TO-VERIFY]** pending co-simulation, so no confident byte-by-byte decode is published yet.

### Splitter
In Logisim, a component that fans a multi-bit wire out into smaller sub-groups of bits (or merges them back together). This design uses a **16→4 splitter** to break each 16-bit instruction into its four 4-bit fields — `OP`, `RD`, `RX`, and `RY/I` — which is how the instruction format was confirmed.

---

*Terms are grounded in the project design brief. Where a definition depends on a detail still marked **[TO-VERIFY]**, that caveat is preserved here and will be resolved during RTL bring-up.*
