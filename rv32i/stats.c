/* 
 * Usage:
 *   stats              BFS level counts + distance-table distributions
 *   stats STATE        also run IDA* on STATE (14 chars, e.g. 21345671111111)
 *
 * Move tables, rank and unrank are copied from upstream solver.c.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CUBIES 7
#define NP 5040
#define NO 729
#define NSTATES (NP * NO)
#define MOVES 9

typedef struct {
    uint8_t p[CUBIES], o[CUBIES];
} state_t;

static const char *move_names[MOVES] = {"R",  "R2", "R'", "B", "B2",
                                        "B'", "D",  "D2", "D'"};
static const uint8_t source[3][CUBIES] = {
    {1, 4, 2, 0, 3, 5, 6},
    {0, 1, 2, 4, 5, 6, 3},
    {0, 2, 5, 3, 1, 4, 6},
};
static const uint8_t twist[3][CUBIES] = {
    {1, 2, 0, 2, 1, 0, 0},
    {0, 0, 0, 1, 2, 1, 2},
    {0, 0, 0, 0, 0, 0, 0},
};

static state_t quarter_turn(state_t s, int face)
{
    state_t r;
    for (int i = 0; i < CUBIES; i++) {
        int from = source[face][i];
        r.p[i] = s.p[from];
        r.o[i] = (uint8_t) ((s.o[from] + twist[face][i]) % 3);
    }
    return r;
}

static int rank_p(const state_t *s)
{
    int p = 0;
    for (int i = 0; i < CUBIES; i++) {
        int smaller = 0;
        for (int j = i + 1; j < CUBIES; j++)
            if (s->p[j] < s->p[i])
                smaller++;
        p = p * (CUBIES - i) + smaller;
    }
    return p;
}

static int rank_o(const state_t *s)
{
    int o = 0;
    for (int i = 0; i < 6; i++)
        o = o * 3 + s->o[i];
    return o;
}

static void unrank(int p, int o, state_t *s)
{
    uint8_t avail[CUBIES] = {0, 1, 2, 3, 4, 5, 6};
    int f = 720, sum = 0;
    for (int i = 0; i < CUBIES; i++) {
        int q = p / f;
        p %= f;
        s->p[i] = avail[q];
        for (int j = q; j + 1 < CUBIES - i; j++)
            avail[j] = avail[j + 1];
        if (i < 5)
            f /= 6 - i;
    }
    for (int i = 5; i >= 0; i--) {
        s->o[i] = (uint8_t) (o % 3);
        sum += s->o[i];
        o /= 3;
    }
    s->o[6] = (uint8_t) ((3 - sum % 3) % 3);
}

/* 9 transition tables per component: move m = face*3 + (turns-1) */
static uint16_t ptab[MOVES][NP], otab[MOVES][NO];
static uint8_t pdist[NP], odist[NO];

static void build_transitions(void)
{
    state_t s, t;
    for (int p = 0; p < NP; p++) {
        unrank(p, 0, &s);
        for (int face = 0; face < 3; face++) {
            t = s;
            for (int k = 0; k < 3; k++) {
                t = quarter_turn(t, face);
                ptab[face * 3 + k][p] = (uint16_t) rank_p(&t);
            }
        }
    }
    for (int o = 0; o < NO; o++) {
        unrank(0, o, &s);
        for (int face = 0; face < 3; face++) {
            t = s;
            for (int k = 0; k < 3; k++) {
                t = quarter_turn(t, face);
                otab[face * 3 + k][o] = (uint16_t) rank_o(&t);
            }
        }
    }
}

/* BFS over one projection (n = 5040 or 729), print the distribution */
static void build_dist(const char *name, int n, uint16_t tab[][NP],
                       uint16_t otab_[][NO], uint8_t *dist)
{
    int *queue = malloc(n * sizeof *queue);
    int head = 0, tail = 1, count[16] = {0}, maxd = 0;
    memset(dist, 0xFF, n);
    dist[0] = 0;
    queue[0] = 0;
    while (head < tail) {
        int x = queue[head++];
        for (int m = 0; m < MOVES; m++) {
            int y = tab ? tab[m][x] : otab_[m][x];
            if (dist[y] == 0xFF) {
                dist[y] = (uint8_t) (dist[x] + 1);
                queue[tail++] = y;
            }
        }
    }
    for (int i = 0; i < n; i++) {
        if (dist[i] == 0xFF) {
            printf("%s: entry %d NOT filled\n", name, i);
            exit(1);
        }
        count[dist[i]]++;
        if (dist[i] > maxd)
            maxd = dist[i];
    }
    printf("%s distribution (distance: entries)\n", name);
    for (int d = 0; d <= maxd; d++)
        printf("  %2d: %d\n", d, count[d]);
    printf("  filled %d / %d, solved entry = %d, max = %d\n\n", tail, n,
           dist[0], maxd);
    free(queue);
}

/* Full BFS over all 3,674,160 states, only to count states per level */
static void full_bfs_levels(void)
{
    uint8_t *dist = malloc(NSTATES);
    uint32_t *queue = malloc((size_t) NSTATES * sizeof *queue);
    uint32_t head = 0, tail = 1;
    long count[16] = {0};
    int maxd = 0;
    memset(dist, 0xFF, NSTATES);
    dist[0] = 0;
    queue[0] = 0;
    while (head < tail) {
        uint32_t x = queue[head++];
        int p = x / NO, o = x % NO;
        for (int m = 0; m < MOVES; m++) {
            uint32_t y = (uint32_t) ptab[m][p] * NO + otab[m][o];
            if (dist[y] == 0xFF) {
                dist[y] = (uint8_t) (dist[x] + 1);
                queue[tail++] = y;
            }
        }
    }
    for (uint32_t i = 0; i < NSTATES; i++) {
        count[dist[i]]++;
        if (dist[i] > maxd)
            maxd = dist[i];
    }
    printf("Full BFS from solved (level: states)\n");
    for (int d = 0; d <= maxd; d++)
        printf("  %2d: %ld\n", d, count[d]);
    printf("  visited %u / %d, deepest level = %d\n\n", tail, NSTATES, maxd);
    free(dist);
    free(queue);
}

/* ---------- IDA* ---------- */
static long nodes;
static int path[12];
static int skip_same_face;

static int h(int p, int o)
{
    return pdist[p] > odist[o] ? pdist[p] : odist[o];
}

static int dfs(int p, int o, int g, int bound, int last_face)
{
    nodes++;
    int hh = h(p, o);
    if (g + hh > bound)
        return 0;
    if (hh == 0)
        return 1; /* p and o both solved */
    for (int m = 0; m < MOVES; m++) {
        if (skip_same_face && m / 3 == last_face)
            continue;
        path[g] = m;
        if (dfs(ptab[m][p], otab[m][o], g + 1, bound, m / 3))
            return 1;
    }
    return 0;
}

static int ida(int p, int o)
{
    for (int bound = h(p, o); bound <= 11; bound++)
        if (dfs(p, o, 0, bound, -1))
            return bound;
    return -1;
}

static int parse(const char *in, state_t *s)
{
    int sum = 0, seen = 0;
    if (strlen(in) != 14)
        return 0;
    for (int i = 0; i < 7; i++) {
        if (in[i] < '1' || in[i] > '7' || (seen & (1 << (in[i] - '1'))))
            return 0;
        seen |= 1 << (in[i] - '1');
        s->p[i] = (uint8_t) (in[i] - '1');
    }
    for (int i = 0; i < 7; i++) {
        if (in[7 + i] < '1' || in[7 + i] > '3')
            return 0;
        s->o[i] = (uint8_t) (in[7 + i] - '1');
        sum += s->o[i];
    }
    return sum % 3 == 0;
}

int main(int argc, char **argv)
{
    build_transitions();
    build_dist("p_distance", NP, ptab, NULL, pdist);
    build_dist("o_distance", NO, NULL, otab, odist);

    if (argc < 2) {
        full_bfs_levels();
        return 0;
    }

    state_t s;
    if (!parse(argv[1], &s)) {
        printf("bad state: %s\n", argv[1]);
        return 2;
    }
    int p = rank_p(&s), o = rank_o(&s);
    printf("State %s: p = %d, o = %d\n", argv[1], p, o);
    printf("  p_distance = %d, o_distance = %d, h = %d\n\n", pdist[p],
           odist[o], h(p, o));

    for (skip_same_face = 0; skip_same_face <= 1; skip_same_face++) {
        nodes = 0;
        int len = ida(p, o);
        printf("IDA* %s same-face skipping:\n",
               skip_same_face ? "WITH" : "WITHOUT");
        printf("  solution length = %d, nodes entered = %ld\n  moves:", len,
               nodes);
        for (int i = 0; i < len; i++)
            printf(" %s", move_names[path[i]]);
        printf("\n\n");
    }
    return 0;
}
