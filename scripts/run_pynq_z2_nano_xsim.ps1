[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coreDir = Join-Path $repoRoot 'rtl\core'
$socDir = Join-Path $repoRoot 'rtl\soc'
$testbench = Join-Path $repoRoot 'sim\tb_pynq_z2_nano.sv'
$buildDir = Join-Path $repoRoot 'build\xsim_pynq_z2_nano'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'
$glbl = [System.IO.Path]::GetFullPath((Join-Path $VivadoBin '..\data\verilog\src\glbl.v'))

foreach ($tool in @($xvlog, $xelab, $xsim, $testbench, $glbl)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Required file not found: $tool"
    }
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$sources = @(
    (Get-ChildItem -LiteralPath $coreDir -Filter '*.sv' |
        Sort-Object Name | ForEach-Object FullName)
    (Get-ChildItem -LiteralPath $socDir -Filter '*.sv' |
        Sort-Object Name | ForEach-Object FullName)
)

Push-Location $buildDir
try {
    & $xvlog --sv --include $coreDir --include $socDir @sources $testbench $glbl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & $xelab tb_pynq_z2_nano glbl -s tb_pynq_z2_nano_sim -debug typical `
        --timescale 1ns/1ps -L unisims_ver -mt 8
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    $simOutput = & $xsim tb_pynq_z2_nano_sim -runall 2>&1
    $simExit = $LASTEXITCODE
    $simOutput | Write-Host
    if ($simExit -ne 0) { throw "xsim failed with exit code $simExit" }
    $output = $simOutput | Out-String
    if ($output -notmatch 'PYNQ NANO PASS:') {
        throw 'PYNQ-Z2 Nano top simulation did not report a pass result'
    }
    if ($output -match '(?im)^\s*(ERROR|FATAL|CRITICAL WARNING|WARNING:)') {
        throw 'PYNQ-Z2 Nano top simulation emitted an error or warning'
    }
}
finally {
    Pop-Location
}

Write-Host 'PYNQ-Z2 NANO XSIM PASS'
