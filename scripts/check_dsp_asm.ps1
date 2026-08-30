[CmdletBinding()]
param([string]$ToolchainRoot = 'E:\riscv-tools\xpack-riscv-none-elf-gcc-15.2.0-1')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$gcc = Join-Path $ToolchainRoot 'bin\riscv-none-elf-gcc.exe'
$objdump = Join-Path $ToolchainRoot 'bin\riscv-none-elf-objdump.exe'
$source = Join-Path $repoRoot 'sw\dsp\dsp_benchmark.c'
$outDir = Join-Path $repoRoot 'build\dsp_asm'
$object = Join-Path $outDir 'dsp_benchmark.o'
$dump = Join-Path $outDir 'dsp_benchmark.dump'
foreach ($path in @($gcc, $objdump, $source)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$includes = @('-I', (Join-Path $repoRoot 'sw\dsp'))
& $gcc '-march=rv32i_zicsr_zifencei' '-mabi=ilp32' '-O2' '-ffreestanding' '-fno-builtin' @includes '-c' $source '-o' $object
if ($LASTEXITCODE -ne 0) { throw 'DSP benchmark assembly check failed' }
& $objdump '-dr' $object | Out-File -LiteralPath $dump -Encoding ascii
if (-not (Test-Path -LiteralPath $dump)) { throw 'DSP benchmark disassembly was not generated' }
Write-Host "DSP ASM PASS: $dump"
