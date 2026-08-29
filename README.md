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
- RISC-V bare-metal GCC: not installed yet
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

These tests cover valid-gated forwarding, true and false load-use hazards, all
six RV32I branch conditions on taken and not-taken paths, negative branch/JAL
offsets, JAL/JALR link values, JALR bit-zero clearing, and wrong-path flushing.
All simulation scripts require an explicit testbench pass marker because XSim
can return process exit code zero after a SystemVerilog `$fatal`.

Create a local Vivado project when GUI inspection is useful:

```powershell
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\create_project.tcl
```

Generated projects and simulation files go under `build/` and are not tracked.

## PYNQ-Z2 standalone demo

The current board demo uses the 125 MHz PL clock, BTN0 as reset, and the four
user LEDs. Its built-in four-instruction program writes `0x5` to the LED MMIO
register at `0x80200040`. The temporary zero-latency memories are intentionally
small: 256 bytes of instruction ROM and 256 bytes of data RAM. They will be
replaced by synchronous BRAM when the Core memory interface is migrated.

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

The bitstream and post-route reports are written under
`build/bitstream_pynq_z2/`. After programming the board, LED0 and LED2 should
turn on (`0101`); BTN0 restarts the Core.

This first milestone is intentionally PL-only, so Vivado reports the expected
`ZPS7-1` advisory that no PS7 processing-system block is present. It does not
prevent bitstream generation or PL configuration. The PYNQ-Z2 manual confirms
that the push-buttons are active-high when pressed and the individual LEDs are
active-high.
