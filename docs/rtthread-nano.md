# RT-Thread Nano milestone

This milestone proves that the RV32I Core can host a small preemptive
RT-Thread Nano application without a processor-system (PS), Linux, or a
physical board.

## Software contract

The build uses the official Nano sources in
`E:\riscv-tools\src\rtthread-nano-master\rt-thread` and the xPack
`riscv-none-elf-gcc` toolchain.  The selected ISA is
`rv32i_zicsr_zifencei`/`ilp32`; the Core has no hardware M extension.  The
port reuses RT-Thread's upstream RISC-V context and e310 trap assembly and
implements the board hooks in `sw/rtthread_nano/nano_port.c`.

The linker places executable code and read-only tables at `0x8000_0000` and
RAM at `0x8010_0000`.  Startup code initializes the stack, copies `.data`
from the ROM load image, clears `.bss`, and installs `trap_entry` in `mtvec`.
The Nano shell therefore exposes a second synchronous ROM read port so C code
can read string literals and initialization tables over the data path in this
Harvard design.

## Hardware-visible devices

| Address | Function |
| --- | --- |
| `0x0200_0000` / `+4` | `mtime` low/high |
| `0x0200_4000` / `+4` | `mtimecmp` low/high |
| `0x1000_0000` | UART TXDATA (polling, 8-N-1) |
| `0x1000_0004` | UART STATUS (`bit0=ready`, `bit1=busy`) |
| `0x8020_0040` | four-bit LED output |

Timer compare values are written high word first and low word second, as
required by the CLINT programming convention.  On each MTIP interrupt the
port advances `mtimecmp`, calls `rt_tick_increase()`, and lets the upstream
trap epilogue perform any pending context switch.

## Verification

```powershell
.\scripts\build_rtthread_nano.ps1 -SimFast
.\scripts\run_rtthread_nano_xsim.ps1
```

The self-checking testbench captures UART bytes, checks that the LED changes
after thread wakeups, rejects X/Z data-bus requests, and requires timer/core
progress.  `-SimFast` uses a 10,000-cycle simulated tick and 1-Mbaud UART so
the regression completes quickly.  A normal build (without `-SimFast`) uses
80,000 cycles per tick (80 MHz / 1 kHz) and 115200 baud for the eventual
PYNQ-Z2 deployment.

## Scope and next steps

The image intentionally uses static threads and no heap, device framework,
filesystem, or networking.  This is enough for a defensible undergraduate
milestone: kernel startup, scheduler dispatch, timer preemption,
`rt_thread_mdelay()` sleep/wakeup, UART logging, and LED observability.  Once
the board is available, the same shell can be connected to the PYNQ-Z2 clock,
LED, and UART pins.  Later DSP work can extend the ISA and add a benchmark
without changing this Nano ABI.
