# Simulation

Self-checking testbenches for the RTL modules. Each one drives directed + pseudo-random vectors,
compares the DUT against an in-testbench reference model, prints a `RESULT: PASS` / `RESULT: FAIL`
summary, and exits non-zero on failure (CI-friendly).

| Testbench | Device under test | Status |
|---|---|---|
| `alu_tb.sv` | [`../rtl/alu.sv`](../rtl/alu.sv) | ✅ PASS — 2010 checks |
| `regfile_tb.sv` | [`../rtl/regfile.sv`](../rtl/regfile.sv) | ✅ PASS — 519 checks |
| `control_tb.sv` | [`../rtl/control.sv`](../rtl/control.sv) | ✅ PASS — 16 checks (exhaustive over all opcodes) |
| `pc_tb.sv` | [`../rtl/pc.sv`](../rtl/pc.sv) | ✅ PASS — 1015 checks |
| `imem_tb.sv` | [`../rtl/imem.sv`](../rtl/imem.sv) | ✅ PASS — 16 checks |
| `dmem_tb.sv` | [`../rtl/dmem.sv`](../rtl/dmem.sv) | ✅ PASS — 506 checks |
| `sequencer_tb.sv` | [`../rtl/sequencer.sv`](../rtl/sequencer.sv) | ✅ PASS — 16 checks |

All verified with **ModelSim ASE 10.1d** (bundled with Quartus II 13.1).

## Run a module

The generic runner ([`run.ps1`](run.ps1)) compiles `../rtl/<module>.sv` with `./<module>_tb.sv`
and runs it. From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File sim\run.ps1 sequencer          # headless -> prints PASS/FAIL
powershell -ExecutionPolicy Bypass -File sim\run.ps1 sequencer -Wave     # open the ModelSim wave GUI
powershell -ExecutionPolicy Bypass -File sim\run.ps1 sequencer -Keep     # also keep the work/ library
```

`<module>` is any of: `alu` `regfile` `control` `pc` `imem` `dmem` `sequencer`.

Expected tail (headless):
```
== <N> checks, 0 errors ==
RESULT: PASS
```

## Waveform analysis (layer L3)

Every run leaves a VCD (`<module>_tb.vcd`) behind. Two ways to inspect signals over time:

- **ModelSim GUI** — `run.ps1 <module> -Wave` opens ModelSim, adds all signals to the Wave window,
  and runs to completion. This is the quickest path (ModelSim ships with Quartus).
- **GTKWave** (open-source) — `gtkwave sim/<module>_tb.vcd`. Install GTKWave separately.

Capture wave screenshots here for the portfolio's L3 layer (see [roadmap](../docs/roadmap.md) Phase 6).

## Compatibility note

The RTL and testbenches avoid modern SystemVerilog shorthands that the 2012-era ModelSim ASE 10.1d
parser rejects (unsized `'0` / `'1` literals and `type'(...)` casts). Sized literals like
`{WIDTH{1'b0}}` are used instead, so the same sources also compile on Icarus, Verilator and Questa.

> `run_alu.ps1` is the original single-module script, kept as a simple example; `run.ps1` supersedes it.
