# PYNQ-Z2 timing baseline

`rv32_pynq_z2_nano` is the only board implementation. It uses the PYNQ-Z2
125 MHz PL oscillator as the `MMCME2_BASE` reference and generates a 50 MHz
clock for the Core, synchronous ROM/RAM, timer, UART, and LED peripheral.

The 50 MHz target leaves positive timing margin for the deliberately
single-cycle `Zmmul` and custom DSP arithmetic. The implementation was run in
Vivado 2024.2 for `xc7z020clg400-1` with eight threads.

| Metric | Post-route result |
| --- | ---: |
| Input clock | 125 MHz |
| Generated Core clock | 50 MHz |
| WNS | +1.015 ns |
| TNS | 0 ns |
| Failing setup endpoints | 0 |
| WHS | +0.155 ns |
| Failing hold endpoints | 0 |
| LUT | 2359 (4.43%) |
| Flip-flops | 1821 (1.71%) |
| Block RAM tiles | 24 (17.14%) |
| DSP48E1 | 7 (3.18%) |
| DRC errors | 0 |

The reproducible implementation entry point is:

```powershell
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\build_pynq_z2_nano_bitstream.tcl
```

Reports, the routed checkpoint, and the bitstream are generated under
`build/bitstream_pynq_z2_nano/`. Vivado emits non-fatal DSP pipelining,
RAM-inference, and missing I/O-delay advisories, plus the expected `ZPS7-1`
advisory because this standalone image intentionally has no PS7 block. None
creates a failing timing endpoint or DRC error.

`scripts/run_pynq_z2_nano_xsim.ps1` checks generated-clock reset, UART TX, LED
MMIO, restart behavior, and active-interface X/Z values. Simulation validates
RTL and clock/reset behavior, while the first board session must still confirm
the physical 125 MHz clock, pins, JTAG configuration, and USB-TTL connection.
