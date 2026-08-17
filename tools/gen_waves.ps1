# gen_waves.ps1 -- (re)generate a waveform PNG for every module.
# Flow: run each self-checking testbench in ModelSim to produce a VCD, then render it to a clean
#       digital timing diagram with tools/vcd_wave.py (matplotlib). Output: docs/waves/<module>.png
#
# The --tmax windows below frame the illustrative (directed) part of each run so the waves stay
# readable instead of showing thousands of random cycles.

$MS   = "C:\altera\13.1\modelsim_ase\win32aloem"
$repo = Split-Path $PSScriptRoot -Parent
$env:Path = "C:\Users\igorl\AppData\Local\Programs\Python\Python312;" + $env:Path
New-Item -ItemType Directory -Force "$repo\docs\waves" | Out-Null

$cfg = @(
    @{m='alu';       sig='a,b,ulaop,result,zero';                        tmax=11000;  t='ALU - one operation per step'},
    @{m='regfile';   sig='clk,rst,we,rd,wdata,rx_data';                  tmax=180000; t='Register file - write then read'},
    @{m='control';   sig='op,ulaop,regwrite,alusrc,branch,memwrite,jump';tmax=16000;  t='Control unit - decode per opcode'},
    @{m='pc';        sig='clk,rst,en,load,target,pc_out';                tmax=220000; t='Program counter'},
    @{m='imem';      sig='addr,instr';                                    tmax=16000;  t='Instruction memory - program contents'},
    @{m='dmem';      sig='clk,we,addr,wdata,rdata';                      tmax=200000; t='Data memory - 1-cycle read latency'},
    @{m='sequencer'; sig='clk,rst,phase';                                tmax=170000; t='5-phase sequencer (one-hot ring)'}
)

foreach ($c in $cfg) {
    Set-Location "$repo\sim"
    if (Test-Path work) { Remove-Item work -Recurse -Force }
    & "$MS\vlib.exe" work | Out-Null
    & "$MS\vlog.exe" -sv "$repo\rtl\$($c.m).sv" "$repo\sim\$($c.m)_tb.sv" 2>&1 | Out-Null
    & "$MS\vsim.exe" -c -do "run -all; quit -f" "$($c.m)_tb" 2>&1 | Out-Null
    Set-Location $repo
    python tools\vcd_wave.py --vcd "sim\$($c.m)_tb.vcd" --out "docs\waves\$($c.m).png" --signals $c.sig --tmax $c.tmax --title $c.t
    Remove-Item "$repo\sim\work" -Recurse -Force -ErrorAction SilentlyContinue
}
