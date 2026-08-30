#include <stddef.h>
#include <stdint.h>
#include "dsp_intrinsics.h"

/* These kernels are freestanding and can be linked into a future Nano
 * application.  Keeping scalar and accelerated forms side by side makes the
 * evaluation reproducible on the same input vectors. */
int32_t rv32_scalar_dotp16(const int32_t *a, const int32_t *b, size_t n)
{
    int32_t acc = 0;
    for (size_t i = 0; i < n; ++i) {
        int32_t alo = (int16_t)(a[i] & 0xffff);
        int32_t ahi = (int16_t)((uint32_t)a[i] >> 16);
        int32_t blo = (int16_t)(b[i] & 0xffff);
        int32_t bhi = (int16_t)((uint32_t)b[i] >> 16);
        acc += alo * blo + ahi * bhi;
    }
    return acc;
}

int32_t rv32_custom_dotp16(const int32_t *a, const int32_t *b, size_t n)
{
    int32_t acc = 0;
    for (size_t i = 0; i < n; ++i)
        acc += rv32_xdotp16(a[i], b[i]);
    return acc;
}

int32_t rv32_zmmul_dotp16(const int32_t *a, const int32_t *b, size_t n)
{
    int32_t acc = 0;
    for (size_t i = 0; i < n; ++i) {
        int32_t alo = (int16_t)(a[i] & 0xffff);
        int32_t ahi = (int16_t)((uint32_t)a[i] >> 16);
        int32_t blo = (int16_t)(b[i] & 0xffff);
        int32_t bhi = (int16_t)((uint32_t)b[i] >> 16);
        acc += rv32_mul(alo, blo) + rv32_mul(ahi, bhi);
    }
    return acc;
}

