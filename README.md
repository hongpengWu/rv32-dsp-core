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
- GitHub CLI: not installed yet

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

Create a local Vivado project when GUI inspection is useful:

```powershell
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\create_project.tcl
```

Generated projects and simulation files go under `build/` and are not tracked.
