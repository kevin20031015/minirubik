#include <stdint.h>

#ifdef __riscv
static void print_int(int x)
{
    register int a0 asm("a0") = x;
    register int a7 asm("a7") = 1;          /* Ripes ecall 1: print integer */
    asm volatile("ecall" : : "r"(a0), "r"(a7));
}
static void print_str(const char *s)
{
    register const char *a0 asm("a0") = s;
    register int a7 asm("a7") = 4;          /* Ripes ecall 4: print string */
    asm volatile("ecall" : : "r"(a0), "r"(a7) : "memory");
}
extern const uint16_t *const p_move_rows[9];
extern const uint16_t *const o_move_rows[9];
extern const uint8_t p_distance[5040], o_distance[729], move_face[10];
#else
#include <stdio.h>
#include "tables.h"
#define print_int(x) printf("%d", (x))
#define print_str(s) printf("%s", (s))
#endif
