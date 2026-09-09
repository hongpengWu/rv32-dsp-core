# Implementation Roadmap

Each phase must end with passing automated tests and a separate Git commit.
DSP instructions are intentionally delayed until the RV32I baseline is stable.

## Phase 0: Reproduce the original core (complete)

- Copy the CPU RTL without changing behavior.
- Compile it independently from the contest SoC.
- Run a hand-encoded smoke program in XSim.
- Record the known warnings and architectural gaps.

Exit criterion: the standalone smoke test writes decimal 12 to address
`0x8010_0000`.

## Phase 1: RV32I correctness foundation

- Make x0 read as zero and reject writes to x0.
- Replace permissive decoding with explicit legal instruction decoding.
- Carry `uses_rs1`, `uses_rs2`, and `illegal_inst` control signals.
- Clear bit zero of JALR targets.
- Add directed tests for all 37 arithmetic, branch, jump, and memory operations.
- Add dependency, branch flush, and load-use tests.

Exit criterion: all directed RV32I tests pass without relying on register
initialization or no-op warmup instructions.

## Phase 2: Pipeline and retirement contract

- Add explicit IF/ID and MEM/WB state.
- Define one valid/ready rule for every pipeline stage.
- Gate forwarding, stalls, redirects, and writes with stage validity.
- Carry PC and instruction bits to retirement.
- Export a commit trace containing PC, instruction, register write, memory
  write, and trap information.

Exit criterion: randomized wait states and pipeline bubbles do not change the
architectural result.

## Phase 3: System instructions and architecture tests

- Decode FENCE, ECALL, EBREAK, and MRET correctly.
- Implement the six Zicsr operations.
- Implement `mstatus`, `mtvec`, `mepc`, `mcause`, and `mtval`.
- Add precise illegal-instruction and misaligned-access traps.
- Integrate `riscv-tests`, then the RISC-V architectural test framework.

Exit criterion: the declared RV32I/Zicsr test profiles pass and produce saved
signatures.

Current status: the RTL now implements the listed Zicsr/system instructions,
illegal-instruction traps, and precise load/store misalignment traps.  The
Windows-native GCC/ELF/XSim flow passes the selected 41-case upstream RV32UI
profile.  The remaining Phase 3 work is broader privileged/CSR coverage and
integration with the current RISC-V architectural test framework.

## Phase 4: Synchronous memory and PYNQ-Z2 (complete)

- Use one-cycle request/response interfaces for instruction and data memory.
- Use four byte write strobes for data memory.
- Infer Xilinx Block RAM for the final ROM and RAM.
- Provide a standalone PYNQ-Z2 top with MMCM, reset, LED, and UART wiring.
- Keep PS/AXI integration optional and outside the final PL baseline.

Exit criterion: the Nano image boots from PL ROM, uses synchronous RAM and
MMIO, passes board-top simulation, and closes post-route timing.

Current status: `rv32_pynq_z2_nano` is the sole board top. The complete
Nano/Zmmul/custom-DSP image is covered by the strict Windows/XSim regression
and closes post-route timing at 50 MHz. PS/AXI control is not a dependency.

## Phase 5: Standard multiply and custom DSP extension

- Implement all four Zmmul operations.
- Infer DSP48E1 resources for multiplication.
- Add a custom-0 packed fixed-point dot-product unit.
- Add a rounded and saturated Q1.15 operation.
- Provide C inline-assembly wrappers using `.insn`.

Current status: all four standard `Zmmul` instructions are implemented in the
existing EXU/ALU path and covered by CPU-level signedness/high-half and random
ALU-vector checks. The strict PL regression and the selected 41-case upstream
RV32UI profile remain passing. Vivado 2024.2 maps the shared Zmmul multiplier
and custom packed operations to seven DSP48E1 blocks; the PYNQ-Z2 Nano image
is signed off at 50 MHz with post-route WNS +1.015 ns, WHS +0.155 ns, zero
failing endpoints, and zero DRC errors. The first custom-0 packed dot-product and rounded/
saturated Q1.15 operations are implemented, tested, and exposed through
ordinary-GCC `.insn` wrappers. A true persistent accumulator form, a
pipelined/multi-cycle multiplier, and end-to-end FIR/benchmark comparisons
are the remaining Phase 5 work.

Exit criterion: FIR, dot-product, and matrix-multiply results match the scalar
reference implementation.

## Phase 6: Evaluation

Compare RV32I, RV32I+Zmmul, and RV32I+Zmmul+Xdsp using:

- cycles and retired instructions
- LUT, FF, BRAM, and DSP48E1 use
- maximum clock frequency
- numerical correctness and saturation behavior
