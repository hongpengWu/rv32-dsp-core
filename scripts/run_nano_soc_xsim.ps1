[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coreDir = Join-Path $repoRoot 'rtl\core'
$socDir = Join-Path $repoRoot 'rtl\soc'
$testbench = Join-Path $repoRoot 'sim\tb_nano_soc.sv'
$buildDir = Join-Path $repoRoot 'build\xsim_nano_soc'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Vivado tool not found: $tool"
    }
}
foreach ($path in @($testbench)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
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
    & $xvlog --sv --include $coreDir --include $socDir @sources $testbench
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & $xelab tb_nano_soc -s tb_nano_soc_sim -debug typical `
        --timescale 1ns/1ps -mt 8
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    $simOutput = & $xsim tb_nano_soc_sim -runall 2>&1
    $simExit = $LASTEXITCODE
    $simOutput | Write-Host
    if ($simExit -ne 0) { throw "xsim failed with exit code $simExit" }
    $output = $simOutput | Out-String
    if ($output -notmatch 'NANO PASS:') {
        throw 'Nano platform simulation did not report a pass result'
    }
    if ($output -match '(?im)^\s*(ERROR|FATAL|CRITICAL WARNING|WARNING:)') {
        throw 'Nano platform simulation emitted an error or warning'
    }
}
finally {
    Pop-Location
}

Write-Host 'NANO SOC XSIM PASS'
