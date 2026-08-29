[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coreDir = Join-Path $repoRoot 'rtl\core'
$testbench = Join-Path $repoRoot 'sim\tb_load_store.sv'
$buildDir = Join-Path $repoRoot 'build\xsim_load_store'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Vivado tool not found: $tool" }
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$sources = Get-ChildItem -LiteralPath $coreDir -Filter '*.sv' |
    Sort-Object Name | ForEach-Object FullName

Push-Location $buildDir
try {
    & $xvlog --sv --include $coreDir @sources $testbench
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }
    & $xelab tb_load_store -s tb_load_store_sim -debug typical --timescale 1ns/1ps
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }
    $simOutput = & $xsim tb_load_store_sim -runall 2>&1
    $simExit = $LASTEXITCODE
    $simOutput | Write-Host
    if ($simExit -ne 0) { throw "xsim failed with exit code $simExit" }
    if (($simOutput | Out-String) -notmatch 'LOAD/STORE PASS:') {
        throw 'Load/store simulation did not report a pass result'
    }
}
finally {
    Pop-Location
}
