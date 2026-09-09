# RV32 DSP Core

This repository contains one final hardware path: a small RV32I/Zicsr FPGA
processor with `Zmmul`, custom fixed-point DSP operations, synchronous memory,
and an RT-Thread Nano SoC for PYNQ-Z2.

It is an educational in-order soft core. It does not target Linux, an MMU,
caches, superscalar execution, or commercial DSP compatibility. The complete
design is PL-only; PS7, AXI, DDR, and Linux are not build or simulation
dependencies.

## Final hardware structure

```text
rv32_pynq_z2_nano             PYNQ-Z2 clock, reset, LEDs, and UART pin
`-- rv32_nano_soc             ROM, RAM, timer, UART, and LED MMIO
    |-- myCPU_sync            processor top
    |-- rv32_sync_rom
    |-- rv32_sync_byte_ram
    |-- rv32_machine_timer
    `-- rv32_uart
```

The processor implements:

- RV32I with explicit instruction legality checks;
- Zicsr and Machine-mode traps/interrupts used by Nano;
- precise illegal-instruction and load/store-misalignment traps;
- the four `Zmmul` operations;
- `XDOTP16` packed signed dot product;
- `XQ15MUL` rounded and saturated Q1.15 multiply;
- five-stage in-order execution with valid/stall/flush control;
- one-cycle synchronous instruction and data-memory interfaces.

## Repository layout

```text
rtl/core/       Final processor RTL
rtl/soc/        Final Nano SoC and PYNQ-Z2 RTL
sim/            Self-checking SystemVerilog testbenches
scripts/        Windows build and verification entry points
vivado/         Final PYNQ-Z2 project, bitstream, and constraints scripts
sw/             RT-Thread Nano port and DSP software
tests/          Upstream RISC-V test integration
docs/           Current design and deployment notes
```

Generated files are written under `build/` and are not tracked.

## Required host tools

- Vivado/XSim 2024.2: `E:\Xilinx\Vivado\2024.2`
- xPack RISC-V bare-metal GCC 15.2.0:
  `E:\riscv-tools\xpack-riscv-none-elf-gcc-15.2.0-1`
- upstream `riscv-tests`: `E:\riscv-tools\src\riscv-tests`
- Git for Windows and Python 3.12

No Linux or WSL environment is required for the checked-in flows.

## Verification

Run the complete board-independent PL regression:

```powershell
.\scripts\run_pl_strict.ps1
```

It covers pipeline hazards, synchronous memory and Core execution, control
flow and traps, misalignment, timer interrupts, `Zmmul`, custom DSP operations,
the Nano SoC, and the final PYNQ-Z2 top. Every test requires an explicit pass
marker and fails on simulator warnings or active-interface X/Z values.

Run the selected 41-case upstream RV32UI profile:

```powershell
.\scripts\run_rv32ui_official.ps1
```

The profile uses `-march=rv32i_zicsr_zifencei -mabi=ilp32` and requires
`tohost=1`. Upstream `ma_data` is intentionally excluded because this Core
traps misaligned loads/stores instead of completing them in hardware. See
[`docs/riscv-tests.md`](docs/riscv-tests.md) for the exact scope.

Build and simulate RT-Thread Nano:

```powershell
.\scripts\build_rtthread_nano.ps1 -SimFast
.\scripts\run_rtthread_nano_xsim.ps1
```

This verifies kernel startup, UART output, machine-timer ticks, delayed-thread
wakeups, context switching, and LED activity. `-SimFast` changes only
simulation timer/UART constants; a normal build uses the 50 MHz, 1 kHz, and
115200-baud hardware values.

Focused extension checks remain available:

```powershell
.\scripts\run_mul_xsim.ps1
.\scripts\run_dsp_custom_xsim.ps1
.\scripts\check_dsp_asm.ps1
```

## PYNQ-Z2 bitstream

Build the normal Nano image, create the final Vivado project, and implement it:

```powershell
.\scripts\build_rtthread_nano.ps1
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\create_pynq_z2_nano_project.tcl
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\build_pynq_z2_nano_bitstream.tcl
```

The result is
`build/bitstream_pynq_z2_nano/rv32_pynq_z2_nano.bit`. The board top derives a
50 MHz Core clock from the 125 MHz PL reference and uses BTN0 for reset, four
user LEDs, and a TX-only 3.3 V UART on Raspberry-Pi header pin 37 (W9).

The post-route reference result is WNS +1.015 ns, WHS +0.155 ns, no failing
timing endpoints, no DRC errors, and 7 DSP48E1 blocks. See
[`docs/timing-baseline.md`](docs/timing-baseline.md) and
[`docs/hardware-deployment-checklist.md`](docs/hardware-deployment-checklist.md).

## Nano memory map

```text
0x8000_0000  instruction ROM and data-side read-only constants
0x8010_0000  byte-write data RAM (32 KiB default)
0x0200_0000  mtime
0x0200_4000  mtimecmp
0x1000_0000  UART TXDATA/STATUS
0x8020_0040  four-bit LED register
```

The initial Nano application uses static threads. Heap, device framework,
filesystems, networking, and PS-controlled program loading are outside the
current hardware baseline.
