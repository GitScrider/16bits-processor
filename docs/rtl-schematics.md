# Generating RTL schematics (logic-circuit view)

Two ways to turn each SystemVerilog module into a **logic-circuit diagram** — the gate/mux/register
level view, like the one you see in Quartus. Use whichever is handy; the Quartus one needs no extra
install, the Yosys one is scriptable and produces clean SVGs that drop straight into the portfolio.

---

## Option A — Quartus RTL Viewer (no install; you already have Quartus)

This is literally the view you referenced. Per module:

1. Create/open a Quartus project with the module as the **top-level entity** (or reuse the
   `fpga/de2_115` project and set the top entity to the module you want to inspect).
2. Run **Analysis & Synthesis** (Processing → Start → Start Analysis & Synthesis, or
   `quartus_map <project>` on the command line — the RTL Viewer only needs synthesis, not a full fit).
3. Open **Tools → Netlist Viewers → RTL Viewer**.
4. Browse the schematic; **File → Export** (or a screenshot) to save the image for the portfolio.

The RTL Viewer shows the design *before* technology mapping — muxes, adders, registers, decoders —
which is exactly the "circuit" picture for each block (ALU, register file, control unit, ...).

---

## Option B — Yosys + netlistsvg (scriptable, produces SVG)

Open-source flow that reads the RTL, elaborates it, and renders an SVG schematic. Great for
auto-generating a diagram per module and embedding it in the site.

### One-time install
- **Yosys** — Windows build from the OSS CAD Suite (YosysHQ) — https://github.com/YosysHQ/oss-cad-suite-build
  (unzip, add its `bin` to PATH).
- **netlistsvg** — needs Node.js (already installed): `npm install -g netlistsvg`.

### Generate
From the repo root:
```powershell
powershell -ExecutionPolicy Bypass -File tools\gen_rtl_svg.ps1 alu
powershell -ExecutionPolicy Bypass -File tools\gen_rtl_svg.ps1 regfile
# ...one per module: control  pc  imem  dmem  sequencer
```
Output lands in `docs/schematics/<module>.svg` (and a `.json` netlist alongside).

Under the hood the script runs:
```
yosys -p "read_verilog -sv rtl/<module>.sv; hierarchy -top <module>; proc; opt; write_json <out>.json"
netlistsvg <out>.json -o docs/schematics/<module>.svg
```

> Tip: `proc; opt` keeps the diagram at the RTL level (registers, muxes, arithmetic) rather than
> fully mapping to gates. For a gate-level picture, add `techmap; opt` before `write_json`.

---

## Where these fit

These schematics are **layer L5 (Synthesis)** of the portfolio showcase (see
[roadmap](roadmap.md) → Phase 6). Pair each module's RTL (L2) with its schematic here and its
simulation waveform (L3) to tell the full story from code → circuit → behaviour.
