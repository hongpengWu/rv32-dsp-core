# Synchronous memory interface

The current legacy `myCPU` ports are zero-latency reads. They are retained for
the first RV32I regressions and the small PL demo, but they cannot map cleanly
to a Xilinx Block Memory Generator. The next Core revision will use the
following fixed-latency contract.

## Instruction port

| Signal | Meaning |
|---|---|
| `req_valid` | A read request is sampled on the rising clock edge. |
| `req_addr` | Byte address; instructions must be 32-bit aligned. |
| `rsp_valid` | Asserted during the cycle after an accepted request. |
| `rsp_data` | Instruction corresponding to the accepted request. |

`rv32_sync_rom` implements this contract today and has a block-RAM inference
hint. Out-of-range or misaligned requests return `rsp_valid=0` and a NOP data
value.

## Data port

`rv32_sync_byte_ram` uses a single request port with a registered read response:

| Signal | Meaning |
|---|---|
| `req_valid` | Request is sampled on the rising edge. |
| `req_write` | `1` for a write, `0` for a read. |
| `req_addr` | Aligned 32-bit word address. |
| `req_wstrb[3:0]` | Per-byte write enables, little-endian lanes. |
| `req_wdata` | Write data. |
| `rsp_valid`/`rsp_rdata` | One-cycle-latency read response; writes have no response. |

The Core adapter will translate its current load/store size encoding to the
four byte strobes and will hold the LSU transaction until `rsp_valid` arrives.
Misaligned accesses will be trapped by the Core rather than silently crossing
word boundaries.

## Verification boundary

Run `scripts/run_sync_mem_xsim.ps1` to verify latency, alignment rejection,
byte strobes, and address bounds. The strict PL regression includes this test.
The modules are deliberately introduced before changing `myCPU`, so a failing
Core migration can be isolated from the BRAM model itself.
