/*
 * Minimal RT-Thread Nano configuration for the RV32I PL shell.
 *
 * The first milestone deliberately keeps the kernel small: no heap, device
 * framework, networking, or filesystem.  A statically allocated main thread
 * and one application thread are enough to prove context switching, timer
 * ticks, and delay/wakeup semantics on the Core.
 */
#ifndef __RTTHREAD_CFG_H__
#define __RTTHREAD_CFG_H__

#define RT_THREAD_PRIORITY_MAX      8
#define RT_TICK_PER_SECOND          1000
#define RT_ALIGN_SIZE               4
#define RT_NAME_MAX                 8

#define RT_USING_USER_MAIN
#define RT_MAIN_THREAD_STACK_SIZE   512

#define RT_USING_COMPONENTS_INIT
#define RT_USING_CONSOLE
#define RT_CONSOLEBUF_SIZE          128

/* Keep the first image deterministic and fully static. */
/* RT_USING_HEAP intentionally disabled. */
/* RT_USING_DEVICE intentionally disabled. */
/* RT_USING_TIMER_SOFT intentionally disabled. */

#define RT_DEBUG_INIT               0

#endif
