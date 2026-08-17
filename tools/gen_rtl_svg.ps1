# gen_rtl_svg.ps1 -- generate a logic-circuit SVG for one RTL module (Yosys + netlistsvg).
#
# Prereqs (one-time):
#   * Yosys on PATH        (OSS CAD Suite: https://github.com/YosysHQ/oss-cad-suite-build)
#   * netlistsvg on PATH   (npm install -g netlistsvg)
#
# Usage (from anywhere):
#   powershell -ExecutionPolicy Bypass -File tools\gen_rtl_svg.ps1 <module>
#   e.g.  ... gen_rtl_svg.ps1 alu     ->  docs/schematics/alu.svg
#
# See docs/rtl-schematics.md for the Quartus RTL Viewer alternative (no install needed).

param([Parameter(Mandatory = $true)][string]$Module)

$repo = Split-Path $PSScriptRoot -Parent
$rtl  = Join-Path $repo "rtl\$Module.sv"
$outDir = Join-Path $repo "docs\schematics"

if (-not (Test-Path $rtl)) { Write-Error "RTL not found: $rtl"; exit 1 }
if (-not (Get-Command yosys -ErrorAction SilentlyContinue))      { Write-Error "yosys not on PATH (see docs/rtl-schematics.md)"; exit 1 }
if (-not (Get-Command netlistsvg -ErrorAction SilentlyContinue)) { Write-Error "netlistsvg not on PATH (npm install -g netlistsvg)"; exit 1 }

New-Item -ItemType Directory -Force $outDir | Out-Null
$json = Join-Path $outDir "$Module.json"
$svg  = Join-Path $outDir "$Module.svg"

# proc; opt keeps it at RTL level (registers/muxes/arithmetic). Add "techmap; opt" for gate-level.
yosys -p "read_verilog -sv `"$rtl`"; hierarchy -top $Module; proc; opt; write_json `"$json`""
if ($LASTEXITCODE -ne 0) { Write-Error "yosys failed"; exit 1 }

netlistsvg $json -o $svg
if ($LASTEXITCODE -ne 0) { Write-Error "netlistsvg failed"; exit 1 }

Write-Output "Wrote $svg"
