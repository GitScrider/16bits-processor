# gen_rtl.ps1 -- (re)generate the RTL logic-circuit SVG for every module.
# Flow: yowasp-yosys (Yosys via WebAssembly) reads the SystemVerilog and emits a JSON netlist,
#       then netlistsvg renders it to an SVG. Output: docs/schematics/<module>.svg
#
# One-time setup used here:
#   python -m pip install yowasp-yosys
#   npm install -g netlistsvg
#
# yowasp-yosys runs in a WASM sandbox that only sees the current directory, so we cd to the repo
# root and use RELATIVE paths.

$env:Path = "C:\Users\igorl\AppData\Roaming\npm;C:\Users\igorl\AppData\Local\Programs\Python\Python312\Scripts;C:\Program Files\nodejs;" + $env:Path
$repo = Split-Path $PSScriptRoot -Parent
Set-Location $repo
New-Item -ItemType Directory -Force "docs/schematics" | Out-Null

foreach ($m in @('alu','regfile','control','pc','imem','dmem','sequencer')) {
    yowasp-yosys -q -p "read_verilog -sv rtl/$m.sv; hierarchy -top $m; proc; opt; write_json docs/schematics/$m.json" 2>&1 | Out-Null
    if (Test-Path "docs/schematics/$m.json") {
        netlistsvg "docs/schematics/$m.json" -o "docs/schematics/$m.svg" 2>&1 | Out-Null
        # netlistsvg draws black-on-transparent; inject a white background so it is readable
        # on a dark page (idempotent).
        $svg = Get-Content "docs/schematics/$m.svg" -Raw
        if ($svg -notmatch 'width="100%".*fill:#ffffff') {
            $rect = '<rect x="0" y="0" width="100%" height="100%" style="fill:#ffffff"/>'
            $svg = [regex]::Replace($svg, '(<svg[^>]*>)', "`$1`n$rect", 1)
            Set-Content "docs/schematics/$m.svg" $svg -Encoding utf8 -NoNewline
        }
    }
    Write-Output ("{0,-11} -> {1}" -f $m, $(if (Test-Path "docs/schematics/$m.svg") { 'SVG OK' } else { 'FAILED' }))
}
