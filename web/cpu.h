// cpu.h - state and helpers for the C translation of the game's x86-64 code
#pragma once
#include <stdint.h>
#include <string.h>
#include <math.h>

typedef union {
    float f[4];
    uint32_t u32[4];
    uint64_t u64[2];
} xmm_t;

typedef struct {
    uint64_t r[16];     // rax rcx rdx rbx rsp rbp rsi rdi r8..r15
    xmm_t x[16];
    uint32_t fop, fsz;  // lazy flags: last flag-setting operation
    uint64_t fa, fb, fr;
} cpu_t;

extern cpu_t R;
void cpu_trap(const char *why);

// memory: the translated program uses real (host / wasm) addresses
static inline uint8_t  LD8 (uint64_t a) { return *(const uint8_t *)(uintptr_t)a; }
static inline uint16_t LD16(uint64_t a) { uint16_t v; memcpy(&v, (const void *)(uintptr_t)a, 2); return v; }
static inline uint32_t LD32(uint64_t a) { uint32_t v; memcpy(&v, (const void *)(uintptr_t)a, 4); return v; }
static inline uint64_t LD64(uint64_t a) { uint64_t v; memcpy(&v, (const void *)(uintptr_t)a, 8); return v; }
static inline void ST8 (uint64_t a, uint64_t v) { *(uint8_t *)(uintptr_t)a = (uint8_t)v; }
static inline void ST16(uint64_t a, uint64_t v) { uint16_t w = (uint16_t)v; memcpy((void *)(uintptr_t)a, &w, 2); }
static inline void ST32(uint64_t a, uint64_t v) { uint32_t w = (uint32_t)v; memcpy((void *)(uintptr_t)a, &w, 4); }
static inline void ST64(uint64_t a, uint64_t v) { memcpy((void *)(uintptr_t)a, &v, 8); }
static inline float f32(uint32_t u) { float f; memcpy(&f, &u, 4); return f; }

// lazy flags
enum { F_LOGIC = 0, F_ADD, F_SUB, F_INC, F_DEC, F_NEG, F_SHIFT, F_BT, F_COMI };

static inline uint64_t fmask(uint32_t sz) { return sz >= 64 ? ~0ull : ((1ull << sz) - 1); }
static inline uint64_t fsign(uint32_t sz) { return 1ull << (sz - 1); }

static inline int zf_(uint32_t op, uint32_t sz, uint64_t a, uint64_t b, uint64_t r) {
    (void)b;
    if (op == F_COMI) return a == 3 || a == 2;
    return (r & fmask(sz)) == 0;
}
static inline int cf_(uint32_t op, uint32_t sz, uint64_t a, uint64_t b, uint64_t r) {
    uint64_t m = fmask(sz);
    switch (op) {
    case F_ADD: return (r & m) < (a & m);
    case F_SUB: return (a & m) < (b & m);
    case F_NEG: return (a & m) != 0;
    case F_SHIFT: case F_BT: return (int)(a & 1);
    case F_COMI: return a == 1 || a == 2;
    default: return 0;
    }
}
static inline int sf_(uint32_t op, uint32_t sz, uint64_t a, uint64_t b, uint64_t r) {
    (void)a; (void)b;
    if (op == F_COMI || op == F_BT) return 0;
    return (r & fsign(sz)) != 0;
}
static inline int of_(uint32_t op, uint32_t sz, uint64_t a, uint64_t b, uint64_t r) {
    uint64_t s = fsign(sz), m = fmask(sz);
    switch (op) {
    case F_ADD: return ((~(a ^ b)) & (a ^ r) & s) != 0;
    case F_SUB: return ((a ^ b) & (a ^ r) & s) != 0;
    case F_INC: return (r & m) == s;
    case F_DEC: return (r & m) == s - 1;
    case F_NEG: return (a & m) == s;
    default: return 0;
    }
}
static inline int pf_(uint32_t op, uint64_t a, uint64_t r) {
    if (op == F_COMI) return a == 2;
    return !__builtin_parity((unsigned)(r & 0xff));
}

#define ZF zf_(fop, fsz, fa, fb, fr)
#define CF cf_(fop, fsz, fa, fb, fr)
#define SF sf_(fop, fsz, fa, fb, fr)
#define OF of_(fop, fsz, fa, fb, fr)
#define PF pf_(fop, fa, fr)
