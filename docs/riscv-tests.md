# Upstream RISC-V test integration

## Provenance

The Windows-native test flow uses:

- `riscv-software-src/riscv-tests` commit `2ebecad` (2026-08-15)
- `riscv-test-env` commit `6de71edb142be36319e380ce782c3d1830c65d68`
- xPack `riscv-none-elf-gcc` 15.2.0-1
- Vivado/XSim 2024.2

The external source and toolchain are installed under `E:\riscv-tools` and
are not copied into this repository.  Each run saves its ELF, disassembly,
and sparse 32-bit memory image under `build/riscv_tests/`.

## Declared profile

Tests are compiled with:

```text
-march=rv32i_zicsr_zifencei -mabi=ilp32
```

The upstream physical environment is retained for reset, trap, and `tohost`
handling.  Initializers for PMP, SATP, RNMI, and interrupt delegation are
disabled because this educational machine-mode Core does not claim those
extensions.  The single-hart `mhartid` CSR is implemented as read-only zero.

The selected RV32UI profile contains 41 tests and is run by:

```powershell
.\scripts\run_rv32ui_official.ps1
```

Success requires each compiled program to write exactly `1` to `tohost`.
The XSim harness also fails on timeout or X/Z values on active memory
transactions.  Its unified synchronous test memory is intentional: the
upstream `fence_i` case uses self-modifying code and requires data-side writes
to become visible to instruction fetch.

## Misaligned-access policy

The upstream `ma_data` test is excluded from this profile.  It requires every
misaligned load/store to complete in hardware.  RV32I permits the execution
environment to handle misaligned accesses instead; this Core takes precise
load/store address-misaligned traps (causes 4 and 6), records the address in
`mtval`, and suppresses the faulting memory transaction.  That behavior is
covered by `sim/tb_cpu_sync_misaligned.sv`.

This exclusion must remain visible in reports.  The result is a 41-case
selected-profile pass, not a claim that the incompatible `ma_data` case
passed.
