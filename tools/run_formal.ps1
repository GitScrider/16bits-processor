# run_formal.ps1 -- run every formal proof and report SUCCESS / FAIL per module.
#
# Uses Yosys's built-in SAT engine (via yowasp-yosys) -- no external SMT solver needed.
#   * Combinational modules (ALU, control) are proved EXHAUSTIVELY (every input) in one shot.
#   * Sequential modules (PC, register file, data memory, sequencer) are proved UNBOUNDED by
#     k-induction: prep -> memory_map (flatten inferred arrays) -> async2sync (lower the clocked
#     asserts) -> chformal -lower -> sat -tempinduct -set-init-zero.
#
#   python -m pip install yowasp-yosys       # one-time
#   powershell -ExecutionPolicy Bypass -File tools\run_formal.ps1

$env:Path = "C:\Users\igorl\AppData\Local\Programs\Python\Python312\Scripts;" + $env:Path
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo

# --- combinational property sets: proved exhaustively over all inputs --------
$COMB = @(
    @{ rtl = 'rtl/alu.sv';     props = 'formal/alu_props.sv';     top = 'alu_props' },
    @{ rtl = 'rtl/control.sv'; props = 'formal/control_props.sv'; top = 'control_props' },
    @{ rtl = 'rtl/imem.sv';    props = 'formal/imem_props.sv';    top = 'imem_props' }
)
foreach ($c in $COMB) {
    $log = Join-Path $env:TEMP ("formal_" + $c.top + ".log")
    yowasp-yosys -p "read_verilog -sv -formal $($c.rtl) $($c.props); prep -top $($c.top) -flatten; memory_map; opt -full; chformal -lower; sat -prove-asserts -verify" *> $log
    $ok = Select-String -Path $log -Pattern 'proof finished - no model found: SUCCESS'
    Write-Output ("{0,-16} -> {1}" -f $c.top, $(if ($ok) { 'PROVED (exhaustive, all inputs)' } else { 'FAIL / see ' + $log }))
}

# --- sequential property sets: proved unbounded by k-induction ---------------
$SEQ = @(
    @{ rtl = 'rtl/pc.sv';        props = 'formal/pc_props.sv';        top = 'pc_props' },
    @{ rtl = 'rtl/regfile.sv';   props = 'formal/regfile_props.sv';   top = 'regfile_props' },
    @{ rtl = 'rtl/dmem.sv';      props = 'formal/dmem_props.sv';      top = 'dmem_props' },
    @{ rtl = 'rtl/sequencer.sv'; props = 'formal/sequencer_props.sv'; top = 'sequencer_props' },
    @{ rtl = 'rtl/vga_sync.sv';  props = 'formal/vga_sync_props.sv';  top = 'vga_sync_props' }
)
foreach ($c in $SEQ) {
    $log = Join-Path $env:TEMP ("formal_" + $c.top + ".log")
    yowasp-yosys -p "read_verilog -sv -formal $($c.rtl) $($c.props); prep -top $($c.top) -flatten; memory_map; opt -full; async2sync; chformal -lower; sat -tempinduct -set-init-zero -prove-asserts -seq 20 -verify" *> $log
    $ok = Select-String -Path $log -Pattern 'Induction step proven: SUCCESS'
    Write-Output ("{0,-16} -> {1}" -f $c.top, $(if ($ok) { 'PROVED (unbounded, k-induction)' } else { 'FAIL / see ' + $log }))
}
