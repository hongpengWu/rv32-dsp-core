# PYNQ-Z2 PL Deployment Checklist

This checklist is deliberately limited to the programmable-logic design. The
current milestone does not require the Zynq processing system, Linux, AXI, or a
PS software application.

## Before the board arrives

- [x] Confirm the target part is `xc7z020clg400-1`.
- [x] Confirm the PYNQ-Z2 pin constraints in `vivado/constraints/pynq_z2_nano.xdc`.
- [x] Run `scripts/run_pl_strict.ps1` on Windows.
- [x] Run the Vivado implementation script and confirm no DRC errors.
- [x] Build the Nano image with
      `vivado/create_pynq_z2_nano_project.tcl` and
      `vivado/build_pynq_z2_nano_bitstream.tcl`.
- [x] Confirm the Nano/Zmmul/custom-DSP MMCM image builds a routed checkpoint
      and bitstream with 125 MHz input, 50 MHz generated Core/BRAM clock,
      seven DSP48E1 blocks, post-route WNS +1.015 ns/WHS +0.155 ns, zero
      failing endpoints, and zero DRC errors.
- [x] Simulate the Nano top's cold start and runtime BTN0 reset, including
      MMCM unlock, CPU-domain reset, LED clear, CPU restart, and UART TX.

## First power-up

- [ ] Install the Digilent/Xilinx USB-JTAG driver and connect the board by
  micro-USB.
- [ ] Set the board power jumper correctly and verify the board power LED.
- [ ] Open Vivado Hardware Manager and connect to the local hardware target.
- [ ] Program `build/bitstream_pynq_z2_nano/rv32_pynq_z2_nano.bit`.
- [ ] Confirm the DONE indicator is asserted after programming.
- [ ] Confirm the RT-Thread Nano image eventually drives the LEDs. The
      individual LEDs and push buttons on PYNQ-Z2 are active-high.
- [ ] If UART output is required, connect a 3.3 V USB-TTL adapter RX to
      Raspberry-Pi header pin 37 (W9) and adapter GND to header pin 39 (or
      another board ground). The on-board FT2232 bridge is PS-MIO-only.

## Functional checks

- [ ] Press and release BTN0; after the generated clock resumes, confirm the
      CPU reset clears peripheral state and the Nano image restarts.
- [ ] Repeat programming and reset at least three times to rule out a timing-
  sensitive startup issue.
- [ ] Replace the ROM image with a second known program and repeat the reset,
      store, and LED checks.  Rebuild the bitstream after changing the image.

## Troubleshooting order

1. Check the selected part, XDC pin names, and generated bitstream timestamp.
2. Check JTAG cable, power, and the DONE indicator.
3. Probe `sys_clk`, BTN0, and the LED pins with an ILA or oscilloscope if
   available.
4. Reduce the design to a clock-counter LED test to isolate board wiring.
5. Re-run the strict PL simulation before changing RTL.

The current post-route DRC has zero errors. Its DSP input/output-pipelining
warnings describe the deliberately single-cycle arithmetic paths, and the
expected PL-only `ZPS7-1` advisory can remain until a later milestone that
intentionally adds a PS7 processing-system block. See
[`docs/pynq-z2.md`](pynq-z2.md) for the clock/PHYRSTB risk and the complete
standalone-top wiring notes.
