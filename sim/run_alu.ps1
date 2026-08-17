# run_alu.ps1 -- compile & run the ALU testbench in ModelSim ASE (bundled with Quartus).
# Usage (from anywhere):  powershell -ExecutionPolicy Bypass -File sim\run_alu.ps1
#
# Adjust $MS if your Quartus lives elsewhere. This is the exact flow that was
# verified to print "RESULT: PASS" on Quartus II 13.1 / ModelSim ASE 10.1d.

$MS  = "C:\altera\13.1\modelsim_ase\win32aloem"
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
$RTL = Join-Path $HERE "..\rtl"

Set-Location $HERE
if (Test-Path work) { Remove-Item work -Recurse -Force }
& "$MS\vlib.exe" work | Out-Null
& "$MS\vlog.exe" -sv "$RTL\alu.sv" "$HERE\alu_tb.sv"
& "$MS\vsim.exe" -c -do "run -all; quit -f" alu_tb

# Clean up (the VCD is kept for GTKWave; comment out to keep the work library).
Remove-Item work, transcript, vsim.wlf -Recurse -Force -ErrorAction SilentlyContinue
