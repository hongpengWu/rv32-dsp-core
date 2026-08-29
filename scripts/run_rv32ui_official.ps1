[CmdletBinding()]
param(
    [string]$VivadoBin = 'E:\Xilinx\Vivado\2024.2\bin',
    [string]$ToolchainRoot = $env:RISCV_TOOLCHAIN_ROOT,
    [string]$RiscvTestsRoot = 'E:\riscv-tools\src\riscv-tests'
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_riscv_test_xsim.ps1'
$tests = @(
    'simple',
    'add', 'addi', 'and', 'andi', 'auipc',
    'beq', 'bge', 'bgeu', 'blt', 'bltu', 'bne',
    'fence_i', 'jal', 'jalr',
    'lb', 'lbu', 'lh', 'lhu', 'lw', 'ld_st', 'lui',
    'or', 'ori', 'sb', 'sh', 'sw', 'st_ld',
    'sll', 'slli', 'slt', 'slti', 'sltiu', 'sltu',
    'sra', 'srai', 'srl', 'srli', 'sub', 'xor', 'xori'
)

$passed = 0
foreach ($test in $tests) {
    Write-Host "=== OFFICIAL RV32UI TEST: $test ==="
    $lines = @()
    try {
        $lines = @(& $runner -Test $test -VivadoBin $VivadoBin `
            -ToolchainRoot $ToolchainRoot -RiscvTestsRoot $RiscvTestsRoot *>&1 |
            ForEach-Object { $_.ToString() })
    }
    catch {
        if ($lines) { $lines | Write-Host }
        throw "Official RV32UI test '$test' failed: $($_.Exception.Message)"
    }

    $output = $lines -join "`n"
    if ($output -notmatch "OFFICIAL RV32UI PASS: $test") {
        $lines | Write-Host
        throw "Official RV32UI test '$test' did not produce its pass marker"
    }

    ($lines | Where-Object { $_ -match 'RISCV TEST PASS:|OFFICIAL RV32UI PASS:' }) |
        Write-Host
    $passed++
}

Write-Host "OFFICIAL RV32UI PROFILE PASS: $passed/$($tests.Count) selected tests"
Write-Host 'EXCLUDED BY PROFILE: ma_data requires hardware-completed misaligned accesses; this Core traps them with causes 4/6'
