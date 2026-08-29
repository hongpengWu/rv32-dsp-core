# Implementation Roadmap

Each phase must end with passing automated tests and a separate Git commit.
DSP instructions are intentionally delayed until the RV32I baseline is stable.

## Phase 0: Preserve and reproduce the legacy core

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

## Phase 4: Synchronous memory and PYNQ-Z2

- Replace the zero-latency ports with request/response interfaces.
- Use four byte write strobes for data memory.
- Replace distributed ROM/RAM with true dual-port Block Memory Generator IP.
- Give the PS one BRAM port and the core the other port.
- Add AXI-Lite reset, start, done, cycle, and instruction-retired registers.

Exit criterion: Python loads a program and data, starts the PL core, waits for
completion, and reads the correct result.

## Phase 5: Standard multiply and custom DSP extension

- Implement all four Zmmul operations.
- Infer DSP48E1 resources for multiplication.
- Add a custom-0 fixed-point MAC/accumulator unit.
- Add rounding and saturation operations.
- Provide C inline-assembly wrappers using `.insn`.

Exit criterion: FIR, dot-product, and matrix-multiply results match the scalar
reference implementation.

## Phase 6: Evaluation

Compare RV32I, RV32I+Zmmul, and RV32I+Zmmul+Xdsp using:

- cycles and retired instructions
- LUT, FF, BRAM, and DSP48E1 use
- maximum clock frequency
- numerical correctness and saturation behavior

