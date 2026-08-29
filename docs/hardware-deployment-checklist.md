# PYNQ-Z2 PL Deployment Checklist

This checklist is deliberately limited to the programmable-logic design. The
current milestone does not require the Zynq processing system, Linux, AXI, or a
PS software application.

## Before the board arrives

- [x] Confirm the target part is `xc7z020clg400-1`.
- [x] Confirm the PYNQ-Z2 pin constraints in `vivado/constraints/pynq_z2_demo.xdc`.
- [x] Run `scripts/run_pl_strict.ps1` on Windows.
- [x] Run the Vivado implementation script and confirm no DRC errors.
- [x] Build the timing-safe MMCM variant with
      `vivado/create_pynq_z2_sync_mmcm_project.tcl` and
      `vivado/build_pynq_z2_sync_mmcm_bitstream.tcl`.
- [x] Confirm the MMCM variant meets timing: 125 MHz input, 80 MHz generated
      Core/BRAM clock, post-route WNS +0.268 ns and WHS +0.059 ns, with zero
      setup or hold failing endpoints.
- [x] Simulate both cold start and runtime BTN0 reset, including MMCM unlock,
      CPU-domain reset, LED clear, and CPU restart.
- [ ] Close timing at 125 MHz for the direct-clock comparison top.  It is
      retained as a diagnostic baseline and is not the board sign-off image.

## First power-up

- [ ] Install the Digilent/Xilinx USB-JTAG driver and connect the board by
  micro-USB.
- [ ] Set the board power jumper correctly and verify the board power LED.
- [ ] Open Vivado Hardware Manager and connect to the local hardware target.
- [ ] Program `build/bitstream_pynq_z2_sync_mmcm/rv32_pynq_z2_sync_mmcm_demo.bit`.
- [ ] Confirm the DONE indicator is asserted after programming.
- [ ] Confirm LED0 and LED2 are on (`0101`). The individual LEDs and push
  buttons on PYNQ-Z2 are active-high.

## Functional checks

- [ ] Press and release BTN0; after the generated clock resumes, confirm the
      CPU reset clears the LEDs and the demo restarts to `0101`.
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

The post-route DRC has zero errors.  Two `PDRC-138` LUT-packing warnings are
tool placement advisories, and the expected PL-only `ZPS7-1` advisory can
remain until a later milestone that intentionally adds a PS7 processing-
system block.
