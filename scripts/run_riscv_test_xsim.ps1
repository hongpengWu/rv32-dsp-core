[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_]+$')]
    [string]$Test = 'add',
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin',
    [string]$ToolchainRoot = $env:RISCV_TOOLCHAIN_ROOT,
    [string]$RiscvTestsRoot = 'E:\riscv-tools\src\riscv-tests'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coreDir = Join-Path $repoRoot 'rtl\core'
$socDir = Join-Path $repoRoot 'rtl\soc'
$testbench = Join-Path $repoRoot 'sim\tb_riscv_test.sv'
$buildDir = Join-Path $repoRoot "build\riscv_tests\rv32ui-p-$Test"
$sourceFile = Join-Path $RiscvTestsRoot "isa\rv32ui\$Test.S"
$upstreamEnv = Join-Path $RiscvTestsRoot 'env\p\riscv_test.h'
$macroDir = Join-Path $RiscvTestsRoot 'isa\macros\scalar'
$linkerScript = Join-Path $RiscvTestsRoot 'env\p\link.ld'

if ([string]::IsNullOrWhiteSpace($ToolchainRoot)) {
    $ToolchainRoot = [Environment]::GetEnvironmentVariable('RISCV_TOOLCHAIN_ROOT', 'User')
}
if ([string]::IsNullOrWhiteSpace($ToolchainRoot)) {
    $ToolchainRoot = 'E:\riscv-tools\xpack-riscv-none-elf-gcc-15.2.0-1'
}

$toolBin = Join-Path $ToolchainRoot 'bin'
$gcc = Join-Path $toolBin 'riscv-none-elf-gcc.exe'
$objcopy = Join-Path $toolBin 'riscv-none-elf-objcopy.exe'
$objdump = Join-Path $toolBin 'riscv-none-elf-objdump.exe'
$xvlog = Join-Path $VivadoBin 'xvlog.bat'
$xelab = Join-Path $VivadoBin 'xelab.bat'
$xsim = Join-Path $VivadoBin 'xsim.bat'

foreach ($path in @($gcc, $objcopy, $objdump, $xvlog, $xelab, $xsim,
                     $sourceFile, $upstreamEnv, $linkerScript, $testbench)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$elfFile = Join-Path $buildDir "rv32ui-p-$Test.elf"
$memFile = Join-Path $buildDir "rv32ui-p-$Test.mem"
$simMemFile = Join-Path $buildDir 'program.mem'
$dumpFile = Join-Path $buildDir "rv32ui-p-$Test.dump"
$envDir = Join-Path $buildDir 'env'
New-Item -ItemType Directory -Force -Path $envDir | Out-Null

# The upstream physical environment assumes a broader privileged profile.
# Keep its standard reset/trap/tohost code, while skipping initializers for
# PMP, SATP, RNMI, and interrupt delegation that this RV32I machine profile
# does not claim to implement.
$upstreamInclude = $upstreamEnv.Replace('\', '/')
$envHeader = @"
#include "$upstreamInclude"
#undef RISCV_MULTICORE_DISABLE
#define RISCV_MULTICORE_DISABLE
#undef INIT_RNMI
#define INIT_RNMI
#undef INIT_SATP
#define INIT_SATP
#undef INIT_PMP
#define INIT_PMP
#undef DELEGATE_NO_TRAPS
#define DELEGATE_NO_TRAPS
"@
[System.IO.File]::WriteAllText((Join-Path $envDir 'riscv_test.h'), $envHeader,
                               [System.Text.Encoding]::ASCII)

$gccArgs = @(
    '-march=rv32i_zicsr_zifencei', '-mabi=ilp32', '-static', '-mcmodel=medany',
    '-fvisibility=hidden', '-nostdlib', '-nostartfiles',
    '-I', $envDir, '-I', $macroDir, '-T', $linkerScript,
    $sourceFile, '-o', $elfFile
)
& $gcc @gccArgs
if ($LASTEXITCODE -ne 0) { throw "riscv-none-elf-gcc failed with exit code $LASTEXITCODE" }

& $objdump --disassemble-all --disassemble-zeroes -h $elfFile | Out-File -LiteralPath $dumpFile -Encoding ascii
if ($LASTEXITCODE -ne 0) { throw "riscv-none-elf-objdump failed with exit code $LASTEXITCODE" }

# Emit 32-bit little-endian words with addresses rebased from 0x80000000.
# This preserves sparse ELF sections such as .tohost at array index 0x400.
& $objcopy -O verilog --verilog-data-width 4 --change-addresses -0x80000000 $elfFile $memFile
if ($LASTEXITCODE -ne 0) { throw "riscv-none-elf-objcopy failed with exit code $LASTEXITCODE" }
Copy-Item -LiteralPath $memFile -Destination $simMemFile -Force

$sources = @(
    (Get-ChildItem -LiteralPath $coreDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
    (Get-ChildItem -LiteralPath $socDir -Filter '*.sv' | Sort-Object Name | ForEach-Object FullName)
)

Push-Location $buildDir
try {
    & $xvlog --sv --include $coreDir --include $socDir @sources $testbench
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

    & $xelab tb_riscv_test -s tb_riscv_test_sim -debug typical --timescale 1ns/1ps -mt 8
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

    $simOutput = & $xsim tb_riscv_test_sim -runall 2>&1
    $simExit = $LASTEXITCODE
    $simOutput | Write-Host
    if ($simExit -ne 0) { throw "xsim failed with exit code $simExit" }

    $output = $simOutput | Out-String
    if ($output -notmatch 'RISCV TEST PASS:') {
        throw "Official riscv-test '$Test' did not report a pass result"
    }
}
finally {
    Pop-Location
}

Write-Host "OFFICIAL RV32UI PASS: $Test"
