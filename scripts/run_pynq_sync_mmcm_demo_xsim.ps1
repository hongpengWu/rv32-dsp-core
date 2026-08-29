[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coreDir = Join-Path $repoRoot 'rtl\core'
$socDir = Join-Path $repoRoot 'rtl\soc'
$testbench = Join-Path $repoRoot 'sim\tb_pynq_sync_mmcm_demo.sv'
$buildDir = Join-Path $repoRoot 'build\xsim_pynq_sync_mmcm_demo'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'
$glbl = [System.IO.Path]::GetFullPath((Join-Path $VivadoBin '..\data\verilog\src\glbl.v'))

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Vivado tool not found: $tool" }
}
if (-not (Test-Path -LiteralPath $glbl)) { throw "Vivado glbl source not found: $glbl" }

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$sources = @(
    (Get-ChildItem -LiteralPath $coreDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
    (Get-ChildItem -LiteralPath $socDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
)

Push-Location $buildDir
try {
    & $xvlog --sv --include $coreDir --include $socDir @sources $testbench $glbl
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }
    & $xelab tb_pynq_sync_mmcm_demo glbl -s tb_pynq_sync_mmcm_demo_sim -debug typical --timescale 1ns/1ps -L unisims_ver
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }
    $simOutput = & $xsim tb_pynq_sync_mmcm_demo_sim -runall 2>&1
    $simExit = $LASTEXITCODE
    $simOutput | Write-Host
    if ($simExit -ne 0) { throw "xsim failed with exit code $simExit" }
    if (($simOutput | Out-String) -notmatch 'MMCM PYNQ PASS:') {
        throw 'MMCM PYNQ simulation did not report a pass result'
    }
}
finally {
    Pop-Location
}
