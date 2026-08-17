# run.ps1 -- generic ModelSim runner for any module's self-checking testbench.
#
# Usage (from the repo root or the sim/ folder):
#   powershell -ExecutionPolicy Bypass -File sim\run.ps1 <module>            # headless, prints PASS/FAIL
#   powershell -ExecutionPolicy Bypass -File sim\run.ps1 <module> -Wave      # opens the ModelSim wave GUI
#   powershell -ExecutionPolicy Bypass -File sim\run.ps1 <module> -Keep      # keep the work library too
#
#   <module> is the base name, e.g.:  alu  regfile  control  pc  imem  dmem  sequencer
#   It compiles ../rtl/<module>.sv together with ./<module>_tb.sv and runs <module>_tb.
#
# A VCD (./<module>_tb.vcd) is always left behind so you can also open it in GTKWave:
#   gtkwave sim/<module>_tb.vcd
#
# Verified against Quartus II 13.1 / ModelSim ASE 10.1d.

param(
    [Parameter(Mandatory = $true)][string]$Module,
    [switch]$Wave,
    [switch]$Keep
)

$MS   = "C:\altera\13.1\modelsim_ase\win32aloem"
$HERE = $PSScriptRoot
$rtlFile = Join-Path $HERE "..\rtl\$Module.sv"
$tbFile  = Join-Path $HERE "${Module}_tb.sv"

if (-not (Test-Path $rtlFile)) { Write-Error "RTL not found: $rtlFile"; exit 1 }
if (-not (Test-Path $tbFile))  { Write-Error "Testbench not found: $tbFile"; exit 1 }

Set-Location $HERE
if (Test-Path work) { Remove-Item work -Recurse -Force }
& "$MS\vlib.exe" work | Out-Null
& "$MS\vlog.exe" -sv $rtlFile $tbFile

$tb = "${Module}_tb"
if ($Wave) {
    # Interactive: open the GUI, add every signal to the Wave window, run to completion.
    & "$MS\vsim.exe" $tb -do "add wave -r /*; run -all"
} else {
    & "$MS\vsim.exe" -c -do "run -all; quit -f" $tb
    # tidy up, but keep the VCD (gitignored) for GTKWave
    if (-not $Keep) {
        Remove-Item work, transcript, vsim.wlf -Recurse -Force -ErrorAction SilentlyContinue
    }
}
