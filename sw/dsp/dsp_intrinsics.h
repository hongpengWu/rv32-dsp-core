#ifndef RV32_DSP_INTRINSICS_H
#define RV32_DSP_INTRINSICS_H

#include <stdint.h>

/* custom-0 encodings are emitted with .insn so the benchmark can be built
 * using the ordinary RV32I toolchain without requiring a custom GCC fork. */
static inline int32_t rv32_xdotp16(int32_t packed_a, int32_t packed_b)
{
    int32_t result;
    __asm__ volatile (".insn r 0x0b, 0, 0, %0, %1, %2"
                      : "=r" (result)
                      : "r" (packed_a), "r" (packed_b));
    return result;
}

static inline int32_t rv32_xq15mul(int32_t a, int32_t b)
{
    int32_t result;
    __asm__ volatile (".insn r 0x0b, 1, 1, %0, %1, %2"
                      : "=r" (result)
                      : "r" (a), "r" (b));
    return result;
}

static inline int32_t rv32_mul(int32_t a, int32_t b)
{
    int32_t result;
    __asm__ volatile (".insn r 0x33, 0, 1, %0, %1, %2"
                      : "=r" (result)
                      : "r" (a), "r" (b));
    return result;
}

#endif
