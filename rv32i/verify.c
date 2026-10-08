#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "tables.h"

#define NP 5040
#define NO 729
#define NS (NP * NO)            /* 3,674,160 */

static uint8_t dist[NS];        /* exact distance of every state */
static uint32_t queue[NS];

/* ---- same search as final.c (IDA*, max of two pattern databases) ---- */
typedef struct { uint32_t p, o, next, last; } frame_t;
static frame_t frames[12];

static int solve(uint32_t p, uint32_t o)   /* returns depth, or -1 */
{
    uint32_t bound, depth, m, np, no, rem;
    bound = p_distance[p];
    if (p_distance[p] < o_distance[o]) bound = o_distance[o];
new_bound:
    depth = 0;
    frames[0].p = p; frames[0].o = o; frames[0].next = 0; frames[0].last = 9;
    if (p == 0 && o == 0) return 0;
try_move:
    if (depth == bound) goto back;
    m = frames[depth].next;
    if (m == 9) goto back;
    frames[depth].next = m + 1;
    if (move_face[m] == move_face[frames[depth].last]) goto try_move;
    np = p_move_rows[m][frames[depth].p];
    rem = bound - depth - 1;
    if (p_distance[np] > rem) goto try_move;
    no = o_move_rows[m][frames[depth].o];
    if (o_distance[no] > rem) goto try_move;
    depth++;
    frames[depth].p = np; frames[depth].o = no;
    frames[depth].next = 0; frames[depth].last = m;
    if (np != 0 || no != 0) goto try_move;
    return (int)depth;
back:
    if (depth != 0) { depth--; goto try_move; }
    bound++;
    if (bound > 11) return -1;
    goto new_bound;
}

static int check_table_u16(const char *name, const uint16_t *t, int n)
{
    /* each move table row must be a permutation of 0..n-1 */
    static uint8_t hit[NP];
    memset(hit, 0, sizeof hit);
    for (int i = 0; i < n; i++) {
        if (t[i] >= n || hit[t[i]]) { printf("  FAIL %s: not a permutation at %d\n", name, i); return 1; }
        hit[t[i]] = 1;
    }
    return 0;
}

int main(void)
{
    int bad = 0;
    char name[32];

    /* ===== H2: tables ===== */
    printf("H2: tables\n");
    for (int m = 0; m < 9; m++) {
        sprintf(name, "p_move_%d", m); bad += check_table_u16(name, p_move_rows[m], NP);
        sprintf(name, "o_move_%d", m); bad += check_table_u16(name, o_move_rows[m], NO);
    }
    {
        int pmax = 0, omax = 0, pz = 0, oz = 0, punset = 0, ounset = 0;
        for (int i = 0; i < NP; i++) {
            if (p_distance[i] == 0xFF) punset++;
            if (p_distance[i] > pmax) pmax = p_distance[i];
            if (p_distance[i] == 0) pz++;
        }
        for (int i = 0; i < NO; i++) {
            if (o_distance[i] == 0xFF) ounset++;
            if (o_distance[i] > omax) omax = o_distance[i];
            if (o_distance[i] == 0) oz++;
        }
        printf("  p_distance: %d entries, unfilled %d, max %d, solved entry p_distance[0] = %d, zeros %d\n",
               NP, punset, pmax, p_distance[0], pz);
        printf("  o_distance: %d entries, unfilled %d, max %d, solved entry o_distance[0] = %d, zeros %d\n",
               NO, ounset, omax, o_distance[0], oz);
        if (punset || ounset || p_distance[0] || o_distance[0] || pz != 1 || oz != 1) bad++;
        printf("  move_face: ");
        for (int i = 0; i < 10; i++) printf("%d ", move_face[i]);
        printf("\n");
    }
    printf("  9 p_move rows and 9 o_move rows are permutations: %s\n", bad ? "NO" : "yes");

    /* 每個面：R2 = R 轉兩次、R' = R 轉三次、轉 4 次回到原狀 */
    {
        int rel_bad = 0;
        for (int f = 0; f < 3; f++) {
            int m = f * 3;                      // m = R、m+1 = R2、m+2 = R'（B、D 同理）
            for (int p = 0; p < NP; p++) {
                int a = p_move_rows[m][p];      // 轉 1 次
                int b = p_move_rows[m][a];      // 轉 2 次
                int c = p_move_rows[m][b];    // 轉 3 次
                int d = p_move_rows[m][c];    // 轉 4 次
                if (p_move_rows[m+1][p] != b) rel_bad++;   // R2 要等於轉 2 次
                if (p_move_rows[m+2][p] != c) rel_bad++;   // R' 要等於轉 3 次
                if (d != p) rel_bad++;                     // 轉 4 次要回到原本
            }
        
            for (int o = 0; o < NO; o++) {
                int a = o_move_rows[m][o];
                int b = o_move_rows[m][a];
                int c = o_move_rows[m][b];
                int d = o_move_rows[m][c];
                if (o_move_rows[m+1][o] != b) rel_bad++;
                if (o_move_rows[m+2][o] != c) rel_bad++;
                if (d != o) rel_bad++;
            }
            
        }
        printf("  face relations (R2 = RR, R' = RRR, R^4 = id): %d failures\n", rel_bad);
        bad += (rel_bad != 0);
    }

    /* ===== exact distance of every state: BFS from solved ===== */
    memset(dist, 0xFF, sizeof dist);
    uint32_t head = 0, tail = 0;
    dist[0] = 0; queue[tail++] = 0;
    while (head < tail) {
        uint32_t s = queue[head++], p = s / NO, o = s % NO;
        for (int m = 0; m < 9; m++) {
            uint32_t t = (uint32_t)p_move_rows[m][p] * NO + o_move_rows[m][o];
            if (dist[t] == 0xFF) { dist[t] = dist[s] + 1; queue[tail++] = t; }
        }
    }
    {
        long count[16] = {0}; int maxd = 0;
        for (uint32_t s = 0; s < NS; s++) { count[dist[s]]++; if (dist[s] > maxd) maxd = dist[s]; }
        printf("BFS: reached %u of %d states, max distance %d\n", tail, NS, maxd);
        for (int d = 0; d <= maxd; d++) printf("  d=%2d: %ld\n", d, count[d]);
        if (tail != NS) bad++;
    }

    /* ===== H1, H3, T5 over every state ===== */
    long h1_bad = 0, h3_bad = 0, t5_bad = 0;
    for (uint32_t s = 0; s < NS; s++) {
        uint32_t p = s / NO, o = s % NO;
        int h = p_distance[p] > o_distance[o] ? p_distance[p] : o_distance[o];
        if (h > dist[s]) { if (h1_bad < 5) printf("  H1 FAIL p=%u o=%u h=%d d=%d\n", p, o, h, dist[s]); h1_bad++; }
        int len = solve(p, o);
        if (len != dist[s]) { if (h3_bad < 5) printf("  H3 FAIL p=%u o=%u len=%d d=%d\n", p, o, len, dist[s]); h3_bad++; }
        uint32_t cp = p, co = o;
        for (int i = 1; i <= len; i++) {
            uint32_t m = frames[i].last;
            cp = p_move_rows[m][cp]; co = o_move_rows[m][co];
        }
        if (len < 0 || cp != 0 || co != 0) t5_bad++;
        if ((s + 1) % 367416 == 0) { printf("  checked %u / %d\n", s + 1, NS); fflush(stdout); }
    }
    printf("H1 (h <= d, admissible):        %ld failures\n", h1_bad);
    printf("H3 (length == exact distance):   %ld failures\n", h3_bad);
    printf("T5 (path reaches solved state):  %ld failures\n", t5_bad);
    bad += (h1_bad != 0) + (h3_bad != 0) + (t5_bad != 0);
    printf(bad ? "SOME CHECKS FAILED\n" : "ALL CHECKS PASSED\n");
    return bad ? 1 : 0;
}
