[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $repoRoot 'build\xsim_machine_timer'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'
$timer = Join-Path $repoRoot 'rtl\soc\rv32_machine_timer.sv'
$testbench = Join-Path $repoRoot 'sim\tb_machine_timer.sv'

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Vivado tool not found: $tool" }
}
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
Push-Location $buildDir
try {
    & $xvlog --sv $timer $testbench
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }
    & $xelab tb_machine_timer -s tb_machine_timer_sim --timescale 1ns/1ps -mt 8
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }
    $simOutput = & $xsim tb_machine_timer_sim -runall 2>&1
    $simExit = $LASTEXITCODE
    $simOutput | Write-Host
    if ($simExit -ne 0) { throw "xsim failed with exit code $simExit" }
    if (($simOutput | Out-String) -notmatch 'TIMER PASS:') {
        throw 'Machine timer simulation did not report a pass result'
    }
}
finally {
    Pop-Location
}
