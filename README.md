# 16-bit RISC Processor

A 16-bit, MIPS-like **RISC processor** designed and simulated in **Logisim**, now being
re-implemented as hand-written **SystemVerilog** and brought up **module-by-module** on an
**Altera/Intel DE2-115** FPGA.

> Multicycle core · 5-phase clock sequencer · 16-bit words · 16 registers · 14 instructions

![Top-level datapath](docs/images/01-datapath-toplevel.jpg)

---

## What it is

This processor executes a fixed **16-bit instruction** made of four 4-bit fields
(`OP | RD | RX | RY/I`), over **16 general-purpose registers**, in a **multicycle** style driven by
a **5-phase clock sequencer** (PC → Fetch/Decode → Execute → Memory → Write-back). It supports
integer arithmetic (add/sub/mul/div, register and immediate forms), set-less-than, a
compare-and-branch (`beqz`), load/store, and jump — enough to run real control flow such as the
nested-loop demo in [`logisim/programs/loop.mem`](logisim/programs/loop.mem).

| Property | Value |
|---|---|
| Data word | 16 bits |
| Instruction width | 16 bits (single fixed format) |
| Registers | 16 × 16-bit (`r0`..`r15`) |
| Execution model | Multicycle, 5 fixed phases per instruction |
| Opcodes | 4-bit → 16 possible; **14 defined**, 2 reserved |
| Instruction memory (L1-I) | 16 words × 16 bits |
| Data memory (L1-D) | 65536 words × 16 bits |
| Design tool | Logisim 2.7.1 |
| FPGA target | DE2-115 · Cyclone IV E · `EP4CE115F29C7` · Quartus Prime Lite |

The instruction format:

```
bit15 ........................................ bit0
[  OP (4)  ][  RD (4)  ][  RX (4)  ][  RY / I (4) ]
```

---

## Documentation

Start here and follow the links:

| Doc | What's inside |
|---|---|
| [Architecture](docs/architecture.md) | Block diagram and a tour of every module (PC, memories, register file, control unit, ALU, sequencer). |
| [ISA reference](docs/isa.md) | Instruction format, full opcode + control-signal tables, per-instruction semantics. |
| [Microarchitecture](docs/microarchitecture.md) | The 5-phase multicycle timing and next-PC logic. |
| [Programming](docs/programming.md) | Assembly syntax, program limits, and how to load a program into Logisim. |
| [FPGA bring-up](docs/fpga-bringup.md) | The module-by-module methodology for the DE2-115. |
| [Verification](docs/verification.md) | Simulation, a formal-verification primer, and on-hardware capture. |
| [Tooling](docs/tooling.md) | Installing and running Logisim, Quartus, and the open-source sim/formal stack. |
| [Roadmap](docs/roadmap.md) | Phased plan and the open questions to resolve during bring-up. |
| [Glossary](docs/glossary.md) | Every term, defined for a learner. |

---

## Repository layout

```
16bits-processor/
├─ README.md              # you are here
├─ LICENSE                # MIT
├─ docs/                  # the documentation set (+ images/ : the 5 module photos)
├─ logisim/               # original Logisim design
│  ├─ Processador.circ    #   main build
│  ├─ Desenvolvendo.circ  #   development variant
│  ├─ Registrador.circ    #   standalone register experiment
│  └─ programs/loop.mem   #   nested-loop demo program
├─ rtl/                   # hand-written SystemVerilog (module-by-module)
│  └─ alu.sv              #   Module 1: the ALU
├─ sim/                   # self-checking testbenches
│  └─ alu_tb.sv
├─ fpga/de2_115/          # DE2-115 board demos + 7-seg decoder
│  ├─ alu_calc_top.sv     #   App #1: interactive ALU calculator
│  └─ hex7seg.sv
├─ formal/                # formal verification (SymbiYosys/SVA) — planned
└─ asm/                   # assembler / example programs — planned
```

---

## Getting started

### 1. Explore the design in Logisim
Open [`logisim/Processador.circ`](logisim/Processador.circ) in **Logisim Evolution**, enable the
clock, and (optionally) *Load Image* [`logisim/programs/loop.mem`](logisim/programs/loop.mem) into
the instruction RAM to watch a program run. See [Tooling](docs/tooling.md).

### 2. Simulate the first RTL module
Quartus ships **ModelSim ASE**, so no extra install is needed. From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File sim\run_alu.ps1
```

This prints `RESULT: PASS` (2010 checks, 0 errors). Icarus Verilog works too — see
[`sim/README.md`](sim/README.md) for both flows and how to open the waveform in GTKWave.

### 3. Run App #1 on the DE2-115
Create a Quartus project with [`fpga/de2_115/alu_calc_top.sv`](fpga/de2_115/alu_calc_top.sv) as the
top level, set the device to `EP4CE115F29C7`, import the board's official pin-assignment file, then
compile and program the board. Flip the switches to compute live:
`SW[7:0]`=A, `SW[14:8]`=B, `SW[17:15]`=operation, result on the `HEX` displays. Full steps in
[FPGA bring-up](docs/fpga-bringup.md).

---

## Status

- ✅ **Phase 0 — Publish & document:** repo structure, full docs, license.
- 🚧 **Phase 1 — RTL module-by-module:** ALU done (RTL + testbench + board demo); register file,
  control unit, PC + memories, and the 5-phase sequencer next.
- ⬜ Phases 2–6: full integration, demo apps, verification, assembler, stretch goals.

See the [Roadmap](docs/roadmap.md) for the full plan and the list of open questions still being
confirmed against the running simulator.

---

## License

[MIT](LICENSE) © Igor Lacerda Tomich (GitScrider)
