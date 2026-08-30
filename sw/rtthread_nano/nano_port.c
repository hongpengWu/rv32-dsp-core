/* Board support for the PL-only RV32I Nano shell. */
#include <rthw.h>
#include <rtthread.h>

#define UART_BASE       0x10000000u
#define UART_TXDATA     (*(volatile rt_uint32_t *)(UART_BASE + 0x00u))
#define UART_STATUS     (*(volatile rt_uint32_t *)(UART_BASE + 0x04u))
#define MTIME_BASE      0x02000000u
#define MTIME_LO        (*(volatile rt_uint32_t *)(MTIME_BASE + 0x0000u))
#define MTIME_HI        (*(volatile rt_uint32_t *)(MTIME_BASE + 0x0004u))
#define MTIMECMP_LO     (*(volatile rt_uint32_t *)(MTIME_BASE + 0x4000u))
#define MTIMECMP_HI     (*(volatile rt_uint32_t *)(MTIME_BASE + 0x4004u))
#define LED_REG         (*(volatile rt_uint32_t *)(0x80200040u))

#ifndef NANO_TICK_CYCLES
#define NANO_TICK_CYCLES 50000u /* 50 MHz / 1 kHz on the Zmmul PL image. */
#endif

static rt_uint32_t nano_next_tick;
static volatile rt_uint32_t nano_tick_count;

static rt_uint64_t nano_read_mtime(void)
{
    rt_uint32_t hi1, lo, hi2;
    do {
        hi1 = MTIME_HI;
        lo  = MTIME_LO;
        hi2 = MTIME_HI;
    } while (hi1 != hi2);
    return ((rt_uint64_t)hi1 << 32) | lo;
}

static void nano_program_timer(void)
{
    rt_uint64_t now = nano_read_mtime();
    rt_uint64_t next = now + (rt_uint64_t)NANO_TICK_CYCLES;

    /* The timer block follows the CLINT high-then-low programming rule. */
    MTIMECMP_HI = 0xffffffffu;
    MTIMECMP_LO = (rt_uint32_t)next;
    MTIMECMP_HI = (rt_uint32_t)(next >> 32);
    nano_next_tick = (rt_uint32_t)next;
}

void rt_hw_board_init(void)
{
    nano_program_timer();
    /* Enable the machine-timer source; global MIE is restored by mret from
     * the initial RT-Thread context frame after the scheduler starts. */
    __asm__ volatile ("li t0, 0x80\n\tcsrs mie, t0" ::: "t0", "memory");
    rt_hw_interrupt_init();
#ifdef RT_USING_COMPONENTS_INIT
    rt_components_board_init();
#endif
}

void rt_hw_console_output(const char *str)
{
    while (str && *str) {
        while ((UART_STATUS & 1u) == 0u) {
            /* polling is intentional: this image has no UART IRQ line */
        }
        UART_TXDATA = (rt_uint8_t)*str++;
    }
}

/* Machine timer interrupt entry point called by e310/interrupt_gcc.S. */
rt_ubase_t handle_trap(rt_ubase_t mcause, rt_ubase_t epc, rt_ubase_t *sp)
{
    (void)sp;
    if ((mcause & 0x80000000u) && ((mcause & 0x7fffffffu) == 7u)) {
        ++nano_tick_count;
        nano_program_timer();
        rt_tick_increase();
        return epc;
    }

    /* Keep unexpected exceptions visible and restart after the faulting
     * instruction.  The Nano milestone only intentionally generates MTIP. */
    rt_kprintf("\ntrap mcause=%x epc=%x\n", (unsigned)mcause, (unsigned)epc);
    return epc + 4u;
}

void rt_hw_interrupt_init(void) { }
void rt_hw_interrupt_mask(int vector) { (void)vector; }
void rt_hw_interrupt_umask(int vector) { (void)vector; }
rt_isr_handler_t rt_hw_interrupt_install(int vector, rt_isr_handler_t handler,
                                          void *param, const char *name)
{
    (void)vector; (void)param; (void)name;
    return handler;
}

void rt_hw_cpu_icache_enable(void) { }
void rt_hw_cpu_icache_disable(void) { }
rt_base_t rt_hw_cpu_icache_status(void) { return 0; }
void rt_hw_cpu_icache_ops(int ops, void *addr, int size)
{ (void)ops; (void)addr; (void)size; }
void rt_hw_cpu_dcache_enable(void) { }
void rt_hw_cpu_dcache_disable(void) { }
rt_base_t rt_hw_cpu_dcache_status(void) { return 0; }
void rt_hw_cpu_dcache_ops(int ops, void *addr, int size)
{ (void)ops; (void)addr; (void)size; }

void rt_hw_cpu_reset(void)
{
    while (1) { }
}

void rt_hw_exception_install(rt_err_t (*exception_handle)(void *context))
{ (void)exception_handle; }

void rt_hw_backtrace(rt_uint32_t *fp, rt_ubase_t thread_entry)
{ (void)fp; (void)thread_entry; }
void rt_hw_show_memory(rt_uint32_t addr, rt_size_t size)
{ (void)addr; (void)size; }

/* Keep LED activity observable in simulation and on the eventual board. */
void nano_led_set(rt_uint32_t value) { LED_REG = value; }
rt_uint32_t nano_get_tick_count(void) { return nano_tick_count; }
