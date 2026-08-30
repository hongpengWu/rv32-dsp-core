[CmdletBinding()]
param(
    [string]$ToolchainRoot = 'E:\riscv-tools\xpack-riscv-none-elf-gcc-15.2.0-1',
    [string]$RtThreadRoot = 'E:\riscv-tools\src\rtthread-nano-master\rt-thread',
    [switch]$SimFast
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$portDir = Join-Path $repoRoot 'sw\rtthread_nano'
$buildDir = Join-Path $repoRoot 'build\rtthread_nano'
$objDir = Join-Path $buildDir 'obj'
$gcc = Join-Path $ToolchainRoot 'bin\riscv-none-elf-gcc.exe'
$objcopy = Join-Path $ToolchainRoot 'bin\riscv-none-elf-objcopy.exe'
$objdump = Join-Path $ToolchainRoot 'bin\riscv-none-elf-objdump.exe'

foreach ($path in @($gcc, $objcopy, $objdump,
                    (Join-Path $RtThreadRoot 'include\rtthread.h'),
                    (Join-Path $portDir 'rtconfig.h'),
                    (Join-Path $portDir 'link.ld'))) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Required file not found: $path" }
}

New-Item -ItemType Directory -Force -Path $objDir | Out-Null
$inc = @('-I', (Join-Path $RtThreadRoot 'include'),
    '-I', (Join-Path $RtThreadRoot 'libcpu\risc-v\common'), '-I', $portDir)
$cflags = @('-march=rv32i_zicsr_zifencei', '-mabi=ilp32', '-O2',
    '-ffreestanding', '-fno-builtin', '-msmall-data-limit=0',
    '-ffunction-sections', '-fdata-sections', '-fno-stack-protector') + $inc
if ($SimFast) { $cflags += '-DNANO_TICK_CYCLES=10000' }

$sources = @(
    (Get-ChildItem (Join-Path $RtThreadRoot 'src') -Filter '*.c' | Sort-Object Name | ForEach-Object FullName)
    (Join-Path $RtThreadRoot 'libcpu\risc-v\common\cpuport.c')
    (Join-Path $RtThreadRoot 'libcpu\risc-v\common\context_gcc.S')
    (Join-Path $RtThreadRoot 'libcpu\risc-v\e310\interrupt_gcc.S')
    (Join-Path $portDir 'nano_port.c')
    (Join-Path $portDir 'main.c')
    (Join-Path $portDir 'startup.S')
)

$objects = @()
foreach ($source in $sources) {
    if (-not (Test-Path -LiteralPath $source)) { throw "Source not found: $source" }
    $object = Join-Path $objDir (([IO.Path]::GetFileNameWithoutExtension($source)) + '.o')
    $objects += $object
    Write-Host "CC $([IO.Path]::GetFileName($source))"
    & $gcc @cflags '-c' $source '-o' $object
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $source" }
}

$elf = Join-Path $buildDir 'rtthread_nano.elf'
Write-Host 'LD rtthread_nano.elf'
$ldflags = @('-nostdlib', '-Wl,--gc-sections',
            '-T', (Join-Path $portDir 'link.ld'))
& $gcc @cflags @ldflags $objects '-lgcc' '-o' $elf
if ($LASTEXITCODE -ne 0) { throw "Link failed" }

$mem = Join-Path $buildDir 'program.mem'
$dump = Join-Path $buildDir 'rtthread_nano.dump'
& $objcopy '-O' 'verilog' '--verilog-data-width' '4' '--change-addresses' '-0x80000000' $elf $mem
if ($LASTEXITCODE -ne 0) { throw "objcopy failed" }
& $objdump '--disassemble-all' '--disassemble-zeroes' '-h' $elf | Out-File -LiteralPath $dump -Encoding ascii
Write-Host "RT-THREAD NANO BUILD PASS: $elf"
Write-Host "Image: $mem"
