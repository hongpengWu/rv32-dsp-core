/* RV32I reset entry.  The Core starts fetching at 0x80000000. */
    .section .text.startup, "ax", @progbits
    .align 2
    .globl _start
    .type _start, @function
_start:
    la      sp, _sp
    /* Copy initialized data from the ROM load image. */
    la      t0, __data_load
    la      t1, __data_start
    la      t2, __data_end
0:
    bgeu    t1, t2, 1f
    lw      t3, 0(t0)
    sw      t3, 0(t1)
    addi    t0, t0, 4
    addi    t1, t1, 4
    j       0b
1:
    /* Clear .bss so the C kernel starts from a deterministic state. */
    la      t0, __bss_start
    la      t1, __bss_end
2:
    bgeu    t0, t1, 3f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       2b
3:
    la      t0, trap_entry
    csrw    mtvec, t0
    call    rtthread_startup

4:
    j       4b
    .size _start, .-_start
