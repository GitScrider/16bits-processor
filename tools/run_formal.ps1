# run_formal.ps1 -- run the formal proofs and report SUCCESS / FAIL per property set.
#
# Uses Yosys's built-in SAT engine (via yowasp-yosys) — no external SMT solver needed.
# Combinational modules are proved EXHAUSTIVELY (every input) in one shot.
#
#   python -m pip install yowasp-yosys   # one-time
#   powershell -ExecutionPolicy Bypass -File tools\run_formal.ps1

$env:Path = "C:\Users\igorl\AppData\Local\Programs\Python\Python312\Scripts;" + $env:Path
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

# combinational property sets: <module rtl>, <props top>
$COMB = @(
    @{ rtl = 'rtl/alu.sv';     props = 'formal/alu_props.sv';     top = 'alu_props' },
    @{ rtl = 'rtl/control.sv'; props = 'formal/control_props.sv'; top = 'control_props' }
)

foreach ($c in $COMB) {
    $log = Join-Path $env:TEMP ("formal_" + $c.top + ".log")
    yowasp-yosys -p "read_verilog -sv $($c.rtl) $($c.props); prep -top $($c.top) -flatten; memory_map; opt -full; chformal -lower; sat -prove-asserts -verify" *> $log
    $ok = Select-String -Path $log -Pattern 'proof finished - no model found: SUCCESS'
    Write-Output ("{0,-16} -> {1}" -f $c.top, $(if ($ok) { 'PROVED (all inputs)' } else { 'FAIL / see ' + $log }))
}

Write-Output ""
Write-Output "Sequential modules (pc, regfile, dmem, sequencer) carry temporal properties that need a"
Write-Output "reset-sequenced harness (SymbiYosys) - see formal/sequencer_props.sv and docs/verification.md."
