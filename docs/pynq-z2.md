# PYNQ-Z2 hardware and standalone Nano top

This note records the board facts used by the PL-only RT-Thread Nano image.
The pin numbers and electrical descriptions are taken from the TUL PYNQ-Z2
Reference Manual v1.0. The target FPGA in Vivado is `xc7z020clg400-1`
(`XC7Z020-1CLG400C`).

## Board resources used by this milestone

| Resource | Board connection | RTL port |
| --- | --- | --- |
| PL reference clock | 125 MHz Ethernet-PHY oscillator, package pin H16 | `sys_clk` |
| BTN0 | D19, active-high push button | `btn[0]` / reset |
| BTN1 | D20, active-high push button | `btn[1]` (reserved) |
| BTN2 | L20, active-high push button | `btn[2]` (reserved) |
| BTN3 | L19, active-high push button | `btn[3]` (reserved) |
| LED0 | R14, active-high user LED | `led[0]` |
| LED1 | P14, active-high user LED | `led[1]` |
| LED2 | N16, active-high user LED | `led[2]` |
| LED3 | M14, active-high user LED | `led[3]` |
| PL UART TX | Raspberry-Pi header pin 37, package pin W9 | `uart_tx` |

The constraints are in
[`vivado/constraints/pynq_z2_nano.xdc`](../vivado/constraints/pynq_z2_nano.xdc).
The standalone top is
[`rtl/soc/rv32_pynq_z2_nano.sv`](../rtl/soc/rv32_pynq_z2_nano.sv).

## Clock and reset

`sys_clk` is constrained to 125 MHz (8.000 ns). The top instantiates a
7-series `MMCME2_BASE` with `CLKFBOUT_MULT_F=8.0` and
`CLKOUT0_DIVIDE_F=20.0`, producing a 50 MHz Core/BRAM/UART clock. BTN0 is
asserted into the board-clock reset supervisor, which holds the MMCM in reset
and then synchronizes reset into the generated-clock domain after lock.

The reference manual states that the 125 MHz PHY clock is disabled while the
PHY reset signal (`PHYRSTB`) is low. `PHYRSTB` is controlled through the
Zynq/PS-side circuitry on the board. Therefore the current PS-free design
assumes that H16 is running after power-up; this must be checked when the
board arrives. If H16 is stopped, the design needs either a board-level PHY
reset configuration or a different PL-available clock source.

## UART connection

The on-board FT2232 USB-UART bridge is wired to Zynq PS MIO14/MIO15, not to a
PL pin. A PS-free top cannot use that bridge. For the Nano image, connect a
3.3 V USB-TTL adapter as follows:

1. Adapter RX -> PYNQ-Z2 Raspberry-Pi header pin 37 (W9, `uart_tx`).
2. Adapter GND -> any PYNQ-Z2 ground pin (header pin 39 is convenient).
3. Do not connect the adapter's TX to the FPGA for this TX-only milestone.

The UART format is 115200 baud, 8 data bits, no parity, one stop bit for the
normal hardware image. The Nano shell uses polling TX registers at
`0x1000_0000` and `0x1000_0004`.

## Build and simulation

Build the RT-Thread Nano image first, then create and implement the standalone
Vivado project:

```powershell
.\scripts\build_rtthread_nano.ps1
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\create_pynq_z2_nano_project.tcl
& 'E:\Xilinx\Vivado\2024.2\bin\vivado.bat' -mode batch `
  -source .\vivado\build_pynq_z2_nano_bitstream.tcl
```

The resulting bitstream is
`build/bitstream_pynq_z2_nano/rv32_pynq_z2_nano.bit`. Before hardware is
available, the integration simulation and complete PL regression are:

```powershell
.\scripts\run_pynq_z2_nano_xsim.ps1
.\scripts\run_pl_strict.ps1
```

The top-level simulation checks MMCM lock, cold-start reset, runtime BTN0
reset while the generated clock is stopped, CPU restart, UART activity, LED
MMIO, and active-interface X/Z values. It does not claim to verify the
electrical behavior of the physical oscillator or USB-TTL adapter.

## First board session

Use the separate
[`docs/hardware-deployment-checklist.md`](hardware-deployment-checklist.md)
for the ordered power, JTAG, clock, LED, reset, and UART checks. PS7, AXI,
DDR, and Linux are intentionally not prerequisites for this milestone; a
future PS-controlled shell can be added without changing the Nano ABI.
