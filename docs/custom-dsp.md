# Custom packed fixed-point DSP extension

The `custom-0` major opcode (`0001011`) is reserved for the project's first
DSP-specific instructions. They are deliberately small and independently
testable, while the RT-Thread Nano image remains valid RV32I/Zicsr software.

## Encodings

Both instructions use the R-type layout (`rd`, `rs1`, `rs2`):

| Instruction | `funct7` | `funct3` | Semantics |
| --- | --- | --- | --- |
| `XDOTP16 rd, rs1, rs2` | `0000000` | `000` | signed low16×low16 + signed high16×high16; return low 32 bits |
| `XQ15MUL rd, rs1, rs2` | `0000001` | `001` | signed low16 Q1.15 multiply, add `0x4000`, arithmetic shift 15, saturate to `[-32768,32767]`, sign-extend |

Unknown `funct7`/`funct3` combinations under `custom-0` remain illegal and
take the existing machine illegal-instruction trap path. Both instructions
are marked as using `rs1`/`rs2`, so the existing forwarding and load-use hazard
logic applies to dependent sequences.

## Hardware mapping

The operations share the existing ALU/EXU writeback path and do not alter the
pipeline interface. `XDOTP16` uses two signed 16×16 products and a widened
33-bit sum. `XQ15MUL` uses one signed 16×16 product, deterministic round-to-
nearest with a positive `0x4000` bias, and explicit signed saturation. The
standard `Zmmul` product remains a separate shared 33×33 datapath. Vivado can
therefore map the complete DSP image to the XC7Z020 DSP48E1 resources; timing
is measured from the routed design rather than inferred from simulation.

## Verification

Run the focused CPU-level regression:

```powershell
.\scripts\run_dsp_custom_xsim.ps1
```

It checks a negative two-lane dot product (`-5000`), a Q1.15 `0.5×0.75`
result (`0x3000`), the `-1×-1` positive saturation boundary (`0x7fff`),
directed signed-lane and rounding boundaries, and 64 pseudo-random ALU input
pairs against independent reference models. It also checks dependent custom
instructions through the forwarding path and rejects unknown values on both
memory interfaces. The test is part of `.\scripts\run_pl_strict.ps1`.

The `.insn` C wrappers and scalar/Zmmul/custom dot-product kernels are under
`sw/dsp/`. The next software step is an end-to-end benchmark harness that
records retired cycles and numerical results for all three implementations.
