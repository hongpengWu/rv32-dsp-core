# Legacy Baseline Audit

Audit date: 2026-08-29

## Source provenance

The 16 files under `rtl/core` were copied without RTL changes from:

```text
E:\FPGA\vivado_prj\digital_twin.srcs\sources_1\new\CPU
```

The original contest wrapper, UART, display logic, virtual peripherals, PLL,
and distributed memory IP are out of scope for the clean core baseline.

## Reproduction result

Vivado/XSim 2024.2 successfully compiled and elaborated the standalone core for
the PYNQ-Z2 device family. The hand-encoded smoke test completed with:

```text
SMOKE PASS: cycle=11 addr=80100000 data=0000000c
```

The baseline commit contains several writes to x0 before useful work because
the legacy register file does not force x0 to zero at read time. The first
architectural fix removes this workaround and tests that writes to x0 are
discarded.

## Confirmed RTL issues

1. Instruction and data interfaces assume zero-latency asynchronous reads.
2. The ready/valid signals do not implement a complete backpressure contract.
3. IDU is combinational; WBU has no independent pipeline register.
4. Unknown and malformed instructions can enable register writeback.
5. JALR does not clear target address bit zero.
6. Register x0 can read as unknown until it is first written.
7. Hazard forwarding ignores the supplied pipeline-valid inputs.
8. FENCE.I, ECALL, and MRET redirects are not precise pipeline events.
9. CSR support is a partial implementation rather than complete Zicsr.
10. The memory write mask encodes access size in two bits instead of four byte
    strobes.
11. The commit trace omits the retired instruction and memory effects.
12. The legacy testbench has no architectural assertions.

## Tool warnings retained in the baseline

XSim reports that the `clock` input on the ALU instance in `EXU.sv` is not
connected. The ALU is combinational, so Phase 1 will remove that unused port
rather than connecting a meaningless clock.

Some legacy modules do not declare a timescale. The XSim runner supplies a
global `1ns/1ps` default so that the preserved baseline elaborates under Vivado
2024.2.

## Resource observation from the original project

The original placed design used 44,621 LUTs, including 32,768 LUTs as memory,
and used no BRAM or DSP48 resources. The clean PYNQ design must regenerate both
memories as synchronous block RAM before adding DSP hardware.
