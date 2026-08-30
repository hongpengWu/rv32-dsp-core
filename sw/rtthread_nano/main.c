#include <rtthread.h>

void nano_led_set(rt_uint32_t value);
rt_uint32_t nano_get_tick_count(void);

static struct rt_thread worker_thread;
static rt_uint8_t worker_stack[512] ALIGN(8);
static volatile rt_uint32_t worker_runs;

static void worker_entry(void *parameter)
{
    (void)parameter;
    while (1) {
        ++worker_runs;
        nano_led_set(worker_runs & 0xfu);
        rt_kprintf("W");
        rt_thread_mdelay(5);
    }
}

int main(void)
{
    rt_kprintf("\nRV32 Nano start\n");

    rt_thread_init(&worker_thread, "work", worker_entry, RT_NULL,
                   worker_stack, sizeof(worker_stack), 1, 5);
    rt_thread_startup(&worker_thread);

    while (1) {
        rt_kprintf("M");
        rt_thread_mdelay(10);
    }
}
