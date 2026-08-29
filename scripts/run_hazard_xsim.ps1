[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $repoRoot 'build\xsim_hazard'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) {
        throw "Vivado tool not found: $tool"
    }
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$sources = @(
    (Join-Path $repoRoot 'rtl\core\Data_hazard.sv'),
    (Join-Path $repoRoot 'rtl\core\Control.sv'),
    (Join-Path $repoRoot 'sim\tb_data_hazard.sv'),
    (Join-Path $repoRoot 'sim\tb_control_hazard.sv')
)

Push-Location $buildDir
try {
    & $xvlog --sv @sources
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    $cases = @(
        @{ Top = 'tb_data_hazard'; Snapshot = 'tb_data_hazard_sim'; Pass = 'HAZARD PASS' },
        @{ Top = 'tb_control_hazard'; Snapshot = 'tb_control_hazard_sim'; Pass = 'CONTROL HAZARD PASS' }
    )
    foreach ($case in $cases) {
        & $xelab $case.Top -s $case.Snapshot --timescale 1ns/1ps -mt 8
        if ($LASTEXITCODE -ne 0) { throw "xelab failed for $($case.Top) with exit code $LASTEXITCODE" }
        $simOutput = & $xsim $case.Snapshot -runall 2>&1
        $simExit = $LASTEXITCODE
        $simOutput | Write-Host
        if ($simExit -ne 0) { throw "xsim failed for $($case.Top) with exit code $simExit" }
        if (($simOutput | Out-String) -notmatch [regex]::Escape($case.Pass)) {
            throw "$($case.Top) did not report a pass result"
        }
    }
}
finally {
    Pop-Location
}
