# RV32 DSP Core

This repository develops the original JYD contest RV32I student core into a
small, verifiable FPGA DSP processor for the PYNQ-Z2 board.

## Intended architecture

- RV32I base ISA with strict instruction legality checks
- Zicsr and basic Machine-mode traps
- Zmmul multiplication using DSP48E1 resources
- A documented custom fixed-point DSP extension
- Five-stage in-order pipeline with explicit valid/stall/flush behavior
- Synchronous Harvard instruction and data BRAM
- PYNQ-Z2 PS software loading and run control

The current protected milestone is smaller and deliberately achievable first:
an RV32I + Zicsr machine running RT-Thread Nano from PL-only synchronous ROM,
RAM, UART, and machine-timer peripherals.  DSP instructions and PS/AXI
integration remain incremental follow-on work and are not required for the
Nano baseline.

This is an educational FPGA soft core. It does not target Linux, an MMU,
caches, superscalar execution, or commercial DSP compatibility.

## Repository layout

```text
rtl/core/       Processor RTL
sim/            Self-checking SystemVerilog testbenches
scripts/        Windows build and test scripts
vivado/         Reproducible Vivado project scripts
sw/             Bare-metal runtime and DSP benchmarks
tests/          Directed and architecture-test integration
docs/           Design notes, audit results, and milestones
```

## Baseline source

The initial RTL under `rtl/core` is an unchanged copy of:

```text
E:\FPGA\vivado_prj\digital_twin.srcs\sources_1\new\CPU
```

The contest SoC wrapper and peripherals are deliberately not copied. The
original project remains the reference for its old memory map and behavior.

## Host tools

- Vivado 2024.2: `E:\Xilinx\Vivado\2024.2`
- Git for Windows
- Python 3.12
- xPack RISC-V bare-metal GCC 15.2.0: `E:\riscv-tools\xpack-riscv-none-elf-gcc-15.2.0-1`
- GitHub CLI

## Run the baseline smoke test

From PowerShell:

```powershell
.\scripts\run_xsim.ps1
```

The smoke test uses hand-encoded RV32I instructions, so it does not require a
RISC-V compiler. It is only a build/integration check, not ISA compliance.

Run the current directed RV32I arithmetic test:

```powershell
.\scripts\run_directed_xsim.ps1
```

This test also uses hand-encoded instructions and checks 24 register results
through store addresses. It is a focused regression, not a substitute for the
official architectural tests.

Run the hazard and RV32I control-flow regressions:

```powershell
.\scripts\run_hazard_xsim.ps1
.\scripts\run_control_flow_xsim.ps1
```

The synchronous Core's architectural trap checks can be exercised directly:

```powershell
.\scripts\run_cpu_sync_control_xsim.ps1
.\scripts\run_cpu_sync_misaligned_xsim.ps1
```

These tests cover valid-gated forwarding, true and false load-use hazards, all
six RV32I branch conditions on taken and not-taken paths, negative branch/JAL
offsets, JAL/JALR link values, JALR bit-zero clearing, and wrong-path flushing.
All simulation scripts require an explicit testbench pass marker because XSim
can return process exit code zero after a SystemVerilog `$fatal`.

Run the complete PL-only strict regression:

```powershell
.\scripts\run_pl_strict.ps1
```

The strict entry point runs every current test, requires its pass marker, and
fails on tool errors, simulator warnings, fatal messages, or X/Z detection in
the PYNQ integration test. It does not require a RISC-V compiler or a board.

Run one upstream `riscv-tests` RV32UI case, or the selected RV32I profile:

```powershell
.\scripts\run_riscv_test_xsim.ps1 -Test add
.\scripts\run_rv32ui_official.ps1
```

The Windows-native flow compiles the upstream assembly with
`-march=rv32i_zicsr_zifencei -mabi=ilp32`, converts the ELF to a sparse
32-bit memory image, runs it on `myCPU_sync`, and requires `tohost=1`.
The selected profile contains 41 passing RV32UI cases.  Upstream `ma_data` is
excluded because it requires hardware-completed misaligned accesses, whereas
this Core intentionally implements the standard load/store-misalignment traps.
See `docs/riscv-tests.md` for the exact scope and provenance.

## RT-Thread Nano PL-only image

RT-Thread Nano does not require Linux.  The Windows-native flow below uses the
xPack bare-metal GCC toolchain, the official Nano kernel sources, and XSim:

```powershell
.\scripts\build_rtthread_nano.ps1 -SimFast
.\scripts\run_rtthread_nano_xsim.ps1
```

`build_rtthread_nano.ps1` emits `build/rtthread_nano/program.mem` from an
RV32I ELF.  The image links code at `0x8000_0000` and RAM at `0x8010_0000`,
sets `mtvec`, copies `.data`, clears `.bss`, and starts the Nano scheduler.
`run_rtthread_nano_xsim.ps1` then verifies the same image on
`rv32_nano_soc`: RT-Thread banner, UART output, machine-timer ticks,
`rt_thread_mdelay()` wakeups, context switching, and LED activity.  `-SimFast`
only shortens the simulated timer interval and increases the simulated UART
baud; the default constants are the 80 MHz / 1 kHz / 115200-baud hardware
values.

The Nano shell's map is:

```text
0x8000_0000  instruction ROM (also readable through the data port for .rodata)
0x8010_0000  byte-write data RAM (32 KiB default)
0x0200_0000  mtime, 0x0200_4000 mtimecmp
0x1000_0000  polling UART TXDATA/STATUS
0x8020_0040  LED register
```

The first Nano application is intentionally static (main thread plus one
worker).  Heap, device framework, filesystems, networking, and PS7 are left
off until the core/ABI baseline is stable.

The synchronous-memory migration is exercised separately with:

```powershell
.\scripts\run_sync_mem_xsim.ps1
.\scripts\run_cpu_sync_xsim.ps1
```

`myCPU_sync` is a parallel migration top; the compatibility `myCPU` and the
current PYNQ demo remain unchanged until the synchronous path has accumulated
the same architectural coverage.

Create a local Vivado project when GUI inspection is useful:

```powershell
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\create_project.tcl
```

Generated projects and simulation files go under `build/` and are not tracked.

## PYNQ-Z2 standalone demo

The direct-clock comparison demo uses the 125 MHz PL clock, BTN0 as reset, and
the four user LEDs.  The timing-safe board image uses a real MMCM to derive an
80 MHz Core/BRAM clock from that 125 MHz reference; this is the recommended
image for hardware deployment.  Both built-in programs write `0x5` to the LED
MMIO register at `0x80200040`.  The synchronous path uses inferred Block RAM
with explicit one-cycle request/response latency.

Run the self-checking integration simulation:

```powershell
.\scripts\run_pynq_demo_xsim.ps1
```

Create the Vivado project and generate a bitstream:

```powershell
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\create_pynq_z2_project.tcl
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\build_pynq_z2_bitstream.tcl
```

For the timing-safe synchronous board image:

```powershell
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\create_pynq_z2_sync_mmcm_project.tcl
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\build_pynq_z2_sync_mmcm_bitstream.tcl
```

The timing evidence for the two clocking choices is recorded in
[`docs/timing-baseline.md`](docs/timing-baseline.md).  The direct 125 MHz
variant is retained for comparison; use the MMCM bitstream for board
sign-off.

The timing-safe bitstream and post-route reports are written under
`build/bitstream_pynq_z2_sync_mmcm/`. After programming the board, LED0 and
LED2 should turn on (`0101`); BTN0 restarts the Core.

This first milestone is intentionally PL-only, so Vivado reports the expected
`ZPS7-1` advisory that no PS7 processing-system block is present. It does not
prevent bitstream generation or PL configuration. The PYNQ-Z2 manual confirms
that the push-buttons are active-high when pressed and the individual LEDs are
active-high.

The board-only procedure is tracked separately in
`docs/hardware-deployment-checklist.md` and can be completed when the PYNQ-Z2
arrives.

The optional `rv32_pl_controlled` shell reserves start, reset, done, cycle, and
retirement-counter signals for a future PS7/AXI-Lite adapter. It is verified as
a standalone PL module today; the recommended board top is
`rv32_pynq_z2_sync_mmcm_demo` (with `rv32_pynq_z2_demo` retained for direct-
clock comparison), so no PS, Linux, or board is required for the regression.
