[CmdletBinding()]
param([string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coreDir = Join-Path $repoRoot 'rtl\core'
$socDir = Join-Path $repoRoot 'rtl\soc'
$tb = Join-Path $repoRoot 'sim\tb_dsp_custom.sv'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'
foreach ($path in @($xvlog, $xelab, $xsim, $tb)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
}
$buildDir = Join-Path $repoRoot 'build\dsp_custom_xsim'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$sources = @(
    (Get-ChildItem $coreDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
    (Get-ChildItem $socDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
)
Push-Location $buildDir
try {
    & $xvlog '--sv' '--include' $coreDir '--include' $socDir @sources $tb
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
    & $xelab 'tb_dsp_custom' '-s' 'tb_dsp_custom_sim' '-debug' 'typical' '--timescale' '1ns/1ps' '-mt' '8'
    if ($LASTEXITCODE -ne 0) { throw 'xelab failed' }
    $output = & $xsim 'tb_dsp_custom_sim' '-runall' 2>&1
    $exitCode = $LASTEXITCODE
    $output | Write-Host
    if ($exitCode -ne 0) { throw "xsim failed with exit code $exitCode" }
    $text = $output | Out-String
    if ($text -notmatch 'DSP CUSTOM PASS:') { throw 'Custom DSP simulation did not report a pass result' }
    if ($text -match '(?im)^\s*(ERROR|FATAL|CRITICAL WARNING|WARNING:)') {
        throw 'Custom DSP simulation emitted an error or warning'
    }
}
finally { Pop-Location }
Write-Host 'CUSTOM DSP XSIM PASS'
