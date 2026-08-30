# RV32M/Zmmul multiply extension

The first DSP-oriented extension is the standard RISC-V `Zmmul` subset. It
adds the four register-register multiply instructions without adding a new
pipeline stage or changing the RT-Thread Nano ABI.

## Encodings and semantics

All four instructions use the R-type encoding with opcode `0110011` and
`funct7=0000001`:

| Instruction | `funct3` | Result |
| --- | --- | --- |
| `MUL rd, rs1, rs2` | `000` | low 32 bits of signed x signed product |
| `MULH rd, rs1, rs2` | `001` | high 32 bits of signed x signed product |
| `MULHSU rd, rs1, rs2` | `010` | high 32 bits of signed x unsigned product |
| `MULHU rd, rs1, rs2` | `011` | high 32 bits of unsigned x unsigned product |

The decoder treats any other `funct7`/`funct3` combination as illegal, so the
existing illegal-instruction trap behavior is preserved.

## RTL implementation

The multiply operations use a widened five-bit ALU selector. `ALU.sv` forms one
explicit signed 66-bit
product from sign/zero-extended 33-bit operands and returns either the low or
high 32-bit half. The result then follows the existing EXU,
LSU, and WBU path, including forwarding and register-writeback gating. As a
result, dependent multiply instructions use the same forwarding contract as
other single-cycle ALU operations.

This is deliberately a functional first implementation. The operands feed
one shared combinational 33x33 product datapath; Vivado 2024.2 maps it to
four DSP48E1 blocks on XC7Z020. It is intentionally not pipelined, so the
Zmmul-enabled board image uses a conservative 50 MHz clock. A future
multi-cycle/pipelined multiplier can raise Fmax without changing the ISA.

## Verification

Run the focused CPU-level test:

```powershell
.\scripts\run_mul_xsim.ps1
```

The test executes all four instructions with `0x80000000 * 2`, four boundary
operand pairs, and 32 pseudo-random operand pairs. It checks:

```text
MUL   = 0x00000000
MULH  = 0xffffffff
MULHSU= 0xffffffff
MULHU = 0x00000001
```

The test also rejects unknown values on the synchronous memory interface. The
same test is part of `scripts/run_pl_strict.ps1`. After the extension was
added, the complete PL regression and all 41 selected upstream RV32UI tests
continued to pass.

## Next DSP step

Use the four instructions as the scalar reference path for FIR and dot-product
benchmarks. The current `custom-0` extension adds packed `XDOTP16` and rounded,
saturated `XQ15MUL`; the next software step is to run identical scalar,
Zmmul, and custom kernels and record cycle and numerical-result comparisons.
Keep the Nano image compiled for RV32I/Zicsr so the baseline remains
independently bootable.
