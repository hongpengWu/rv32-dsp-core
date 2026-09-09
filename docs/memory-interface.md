# Synchronous memory interface

`myCPU_sync` is the sole processor top. Both memory ports use a one-cycle
request/response contract designed for inferred Xilinx Block RAM.

## Instruction port

| Signal | Meaning |
| --- | --- |
| `imem_req_valid` | A read request is sampled on the rising edge. |
| `imem_req_addr` | Byte address; instructions are 32-bit aligned. |
| `imem_rsp_valid` | The requested word is valid one cycle later. |
| `imem_rsp_data` | Instruction corresponding to the accepted request. |

`IFU_sync` permits one outstanding request and has a one-entry response
buffer. Redirects invalidate an in-flight or buffered wrong-path instruction.
`rv32_sync_rom` returns no valid response for an out-of-range or misaligned
request.

## Data port

| Signal | Meaning |
| --- | --- |
| `dmem_req_valid` | A load or store request is sampled on the rising edge. |
| `dmem_req_write` | `1` for store, `0` for load. |
| `dmem_req_addr` | Aligned 32-bit word address. |
| `dmem_req_wstrb[3:0]` | Per-byte store enables in little-endian lane order. |
| `dmem_req_wdata` | Lane-aligned store data. |
| `dmem_rsp_valid` | A load response is valid one cycle after its request. |
| `dmem_rsp_rdata` | The complete aligned 32-bit memory word. |

`LSU_sync` aligns byte and halfword data and performs sign or zero extension.
The Core detects misaligned halfword/word accesses before the LSU transaction,
takes causes 4 or 6, records the fault address in `mtval`, and suppresses the
memory request.

`rv32_nano_soc` decodes this port across data RAM, data-side ROM reads, timer,
UART, and LED MMIO. Unmapped reads still return a deterministic registered
response so the pipeline cannot hang.

## Verification

```powershell
.\scripts\run_sync_mem_xsim.ps1
.\scripts\run_cpu_sync_xsim.ps1
.\scripts\run_cpu_sync_misaligned_xsim.ps1
```

These tests check latency, bounds, byte strobes, load formatting, normal Core
execution, and the no-request property of misaligned traps. They are also part
of `scripts/run_pl_strict.ps1`.
