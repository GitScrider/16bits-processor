# gen_synth.ps1 -- synthesize each module standalone in Quartus and collect its FPGA resource
# usage (logic elements, registers, memory bits, DSP multipliers) for the portfolio's "synthesis"
# layer. Writes a consolidated summary the page/docs can quote.
#
# Runs sequentially (a full Quartus compile per module) into a scratch build area, then extracts
# each module's <mod>.fit.summary. Target device: EP4CE115F29C7 (DE2-115, Cyclone IV E).

$Q    = "C:\altera\13.1\quartus\bin64"
$RTL  = "C:/Development/16bits-processor/rtl"   # forward slashes: Quartus .qsf eats backslashes
$BASE = Join-Path $env:TEMP "proc_synth"
$OUT  = "C:\Development\16bits-processor\docs\synth-results.txt"
New-Item -ItemType Directory -Force $BASE | Out-Null
"Resource usage per module (Quartus, EP4CE115F29C7)" | Set-Content $OUT

foreach ($m in @('alu','regfile','control','pc','imem','dmem','sequencer')) {
    $d = Join-Path $BASE $m
    New-Item -ItemType Directory -Force $d | Out-Null
    Set-Location $d
    @"
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE115F29C7
set_global_assignment -name TOP_LEVEL_ENTITY $m
set_global_assignment -name SYSTEMVERILOG_FILE $RTL/$m.sv
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
"@ | Set-Content "$m.qsf" -Encoding ascii
    "QUARTUS_VERSION = `"13.1`"`nPROJECT_REVISION = `"$m`"" | Set-Content "$m.qpf" -Encoding ascii

    & "$Q\quartus_sh.exe" --flow compile $m 2>&1 | Out-Null

    Add-Content $OUT "`n===== $m ====="
    if (Test-Path "$d\$m.fit.summary") {
        Get-Content "$d\$m.fit.summary" |
            Select-String -Pattern 'logic elements|registers|memory bits|Multiplier|Total pins' |
            ForEach-Object { Add-Content $OUT ("  " + $_.ToString().Trim()) }
    } else {
        Add-Content $OUT "  (compile failed - no fit.summary)"
    }
}
Write-Output "Done. Summary -> $OUT"
Get-Content $OUT
