[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin',
    [string]$ToolchainRoot = 'E:\riscv-tools\xpack-riscv-none-elf-gcc-15.2.0-1',
    [string]$RtThreadRoot = 'E:\riscv-tools\src\rtthread-nano-master\rt-thread'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $PSScriptRoot 'build_rtthread_nano.ps1'
$buildDir = Join-Path $repoRoot 'build\rtthread_nano'
$coreDir = Join-Path $repoRoot 'rtl\core'
$socDir = Join-Path $repoRoot 'rtl\soc'
$tb = Join-Path $repoRoot 'sim\tb_rtthread_nano.sv'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'
foreach ($path in @($xvlog, $xelab, $xsim, $tb)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
}

& $buildScript -ToolchainRoot $ToolchainRoot -RtThreadRoot $RtThreadRoot -SimFast
if ($LASTEXITCODE -ne 0) { throw 'RT-Thread Nano build failed' }
$mem = Join-Path $buildDir 'program.mem'
if (-not (Test-Path -LiteralPath $mem)) { throw "Image not found: $mem" }

$sources = @(
    (Get-ChildItem $coreDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
    (Get-ChildItem $socDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
)
Push-Location $buildDir
try {
    & $xvlog '--sv' '--include' $coreDir '--include' $socDir @sources $tb
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
    & $xelab 'tb_rtthread_nano' '-s' 'tb_rtthread_nano_sim' '-debug' 'typical' '--timescale' '1ns/1ps' '-mt' '8'
    if ($LASTEXITCODE -ne 0) { throw 'xelab failed' }
    $output = & $xsim 'tb_rtthread_nano_sim' '-runall' 2>&1
    $exitCode = $LASTEXITCODE
    $output | Write-Host
    if ($exitCode -ne 0) { throw "xsim failed with exit code $exitCode" }
    $text = $output | Out-String
    if ($text -notmatch 'NANO RTT PASS:') { throw 'RT-Thread Nano simulation did not report a pass result' }
    if ($text -match '(?im)^\s*(ERROR|FATAL|CRITICAL WARNING|WARNING:)') {
        throw 'RT-Thread Nano simulation emitted an error or warning'
    }
}
finally { Pop-Location }
Write-Host 'RT-THREAD NANO XSIM PASS'
