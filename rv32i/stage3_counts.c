/* 
 * Usage:
 *   stage3_counts              run on 21345671111111
 *   stage3_counts STATE        run on STATE (14 chars)
 *
 * Five versions of the same IDA* search. Each one adds ONE change:
 *   V0  stats.c dfs (recursive, m / 3, both tables checked on entry)
 *   V1  + change 1: move_face[m] table instead of m / 3
 *   V2  + change 2: check p_distance first, read o_distance only if p passes
 *   V3  + change 3: check the child in the parent, do not enter bad children
 *   V4  + change 4: no recursion, explicit stack (same as optimized.c solve)
 * All five must print the same solution.
 *
 * Table building is copied from stats.c.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CUBIES 7
#define NP 5040
#define NO 729
#define MOVES 9
#define MAX_DEPTH 11

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
/* move 0..8 -> face 0..2; entry 9 = "no previous move" at the root */
static const uint8_t move_face[MOVES + 1] = {0, 0, 0, 1, 1, 1, 2, 2, 2, 3};

/* ---------- tables (same as stats.c) ---------- */
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

static uint16_t ptab[MOVES][NP], otab[MOVES][NO];
static uint8_t pdist[NP], odist[NO];

static void build_tables(void)
{
    state_t s, t;
    static int queue[NP];
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
    for (int pass = 0; pass < 2; pass++) {
        int n = pass ? NO : NP, head = 0, tail = 1;
        uint8_t *dist = pass ? odist : pdist;
        memset(dist, 0xFF, n);
        dist[0] = 0;
        queue[0] = 0;
        while (head < tail) {
            int x = queue[head++];
            for (int m = 0; m < MOVES; m++) {
                int y = pass ? otab[m][x] : ptab[m][x];
                if (dist[y] == 0xFF) {
                    dist[y] = (uint8_t) (dist[x] + 1);
                    queue[tail++] = y;
                }
            }
        }
    }
}

/* ---------- counters ---------- */
typedef struct {
    long nodes;  /* nodes entered (dfs calls, or frames pushed in V4) */
    long divs;   /* m / 3 executed */
    long ptab_r; /* reads of ptab (2-byte table) */
    long otab_r; /* reads of otab (2-byte table) */
    long pd_r;   /* reads of pdist */
    long od_r;   /* reads of odist */
    long face_r; /* reads of move_face (replaces m / 3) */
    long calls;  /* function calls to dfs */
} count_t;

static count_t c;
static int path[12];
static int bound_;

/* V0: exactly the stats.c dfs (skip_same_face = 1) */
static int dfs0(int p, int o, int g, int last_face)
{
    c.calls++;
    c.nodes++;
    c.pd_r++;
    c.od_r++;
    int hh = pdist[p] > odist[o] ? pdist[p] : odist[o];
    if (g + hh > bound_)
        return 0;
    if (hh == 0)
        return 1;
    for (int m = 0; m < MOVES; m++) {
        c.divs++;
        if (m / 3 == last_face)
            continue;
        path[g] = m;
        c.ptab_r++;
        c.otab_r++;
        c.divs++;
        if (dfs0(ptab[m][p], otab[m][o], g + 1, m / 3))
            return 1;
    }
    return 0;
}

/* V1: change 1 - move_face[] instead of m / 3 */
static int dfs1(int p, int o, int g, int last_move)
{
    c.calls++;
    c.nodes++;
    c.pd_r++;
    c.od_r++;
    int hh = pdist[p] > odist[o] ? pdist[p] : odist[o];
    if (g + hh > bound_)
        return 0;
    if (hh == 0)
        return 1;
    for (int m = 0; m < MOVES; m++) {
        c.face_r += 2;
        if (move_face[m] == move_face[last_move])
            continue;
        path[g] = m;
        c.ptab_r++;
        c.otab_r++;
        if (dfs1(ptab[m][p], otab[m][o], g + 1, m))
            return 1;
    }
    return 0;
}

/* V2: change 2 - check pdist first; read odist only if p passes */
static int dfs2(int p, int o, int g, int last_move)
{
    c.calls++;
    c.nodes++;
    c.pd_r++;
    if (g + pdist[p] > bound_)
        return 0;
    c.od_r++;
    if (g + odist[o] > bound_)
        return 0;
    if (p == 0 && o == 0)
        return 1;
    for (int m = 0; m < MOVES; m++) {
        c.face_r += 2;
        if (move_face[m] == move_face[last_move])
            continue;
        path[g] = m;
        c.ptab_r++;
        c.otab_r++;
        if (dfs2(ptab[m][p], otab[m][o], g + 1, m))
            return 1;
    }
    return 0;
}

/* V3: change 3 - the parent checks each child; bad children are never
 * entered, and otab is read only after the child's p passes. */
static int dfs3(int p, int o, int g, int last_move)
{
    c.calls++;
    c.nodes++;
    if (p == 0 && o == 0)
        return 1;
    if (g == bound_)
        return 0;
    int remaining = bound_ - g - 1;
    for (int m = 0; m < MOVES; m++) {
        c.face_r += 2;
        if (move_face[m] == move_face[last_move])
            continue;
        c.ptab_r++;
        int np = ptab[m][p];
        c.pd_r++;
        if (pdist[np] > remaining)
            continue;
        c.otab_r++;
        int no = otab[m][o];
        c.od_r++;
        if (odist[no] > remaining)
            continue;
        path[g] = m;
        if (dfs3(np, no, g + 1, m))
            return 1;
    }
    return 0;
}

/* V4: change 4 - same checks as V3, but a loop over an explicit stack
 * (this is optimized.c solve, lines 169-204) */
typedef struct {
    int p, o, next_move, last_move;
} frame_t;
static frame_t stack[MAX_DEPTH + 1];

static int solve4(int p0, int o0)
{
    int depth = 0;
    frame_t *cur = stack;
    int p, o;
    cur->p = p0;
    cur->o = o0;
    cur->next_move = 0;
    cur->last_move = MOVES;
    c.nodes++;
enter_node:
    p = cur->p;
    o = cur->o;
    if (p == 0 && o == 0)
        return 1;
    if (depth == bound_)
        goto backtrack;
scan_moves:
    while (cur->next_move < MOVES) {
        int move = cur->next_move++;
        c.face_r += 2;
        if (move_face[move] == move_face[cur->last_move])
            continue;
        c.ptab_r++;
        int next_p = ptab[move][p];
        int remaining = bound_ - depth - 1;
        c.pd_r++;
        if (pdist[next_p] > remaining)
            continue;
        c.otab_r++;
        int next_o = otab[move][o];
        c.od_r++;
        if (odist[next_o] > remaining)
            continue;
        ++cur;
        ++depth;
        cur->p = next_p;
        cur->o = next_o;
        cur->next_move = 0;
        cur->last_move = move;
        c.nodes++;
        goto enter_node;
    }
backtrack:
    if (depth == 0)
        return 0;
    --cur;
    --depth;
    p = cur->p;
    o = cur->o;
    goto scan_moves;
}

/* Run one version over all bounds; returns solution length. */
static int run(int version, int p, int o, count_t *out, int moves[12])
{
    int h = pdist[p] > odist[o] ? pdist[p] : odist[o];
    int len = -1;
    memset(&c, 0, sizeof c);
    for (bound_ = h; bound_ <= MAX_DEPTH; bound_++) {
        int found = 0;
        switch (version) {
        case 0: found = dfs0(p, o, 0, -1); break;
        case 1: found = dfs1(p, o, 0, MOVES); break;
        case 2: found = dfs2(p, o, 0, MOVES); break;
        case 3: found = dfs3(p, o, 0, MOVES); break;
        case 4: c.calls++; found = solve4(p, o); break;
        }
        if (found) {
            len = bound_;
            break;
        }
    }
    for (int i = 0; i < len; i++)
        moves[i] = (version == 4) ? stack[i + 1].last_move : path[i];
    *out = c;
    return len;
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
    const char *input = argc > 1 ? argv[1] : "21345671111111";
    state_t s;
    if (!parse(input, &s)) {
        printf("bad state: %s\n", input);
        return 2;
    }
    build_tables();
    int p = rank_p(&s), o = rank_o(&s);
    printf("State %s: p = %d, o = %d\n\n", input, p, o);

    count_t r[5];
    int len[5], moves[5][12];
    for (int v = 0; v < 5; v++)
        len[v] = run(v, p, o, &r[v], moves[v]);

    printf("%-22s %10s %10s %10s %10s %10s\n", "", "V0", "V1", "V2", "V3",
           "V4");
#define ROW(name, field)                                                    \
    printf("%-22s %10ld %10ld %10ld %10ld %10ld\n", name, r[0].field,       \
           r[1].field, r[2].field, r[3].field, r[4].field)
    ROW("nodes entered", nodes);
    ROW("m / 3 (divisions)", divs);
    ROW("move_face reads", face_r);
    ROW("ptab reads", ptab_r);
    ROW("otab reads", otab_r);
    ROW("pdist reads", pd_r);
    ROW("odist reads", od_r);
    ROW("function calls", calls);
    printf("%-22s %10ld %10ld %10ld %10ld %10ld\n", "table reads (total)",
           r[0].ptab_r + r[0].otab_r + r[0].pd_r + r[0].od_r,
           r[1].ptab_r + r[1].otab_r + r[1].pd_r + r[1].od_r,
           r[2].ptab_r + r[2].otab_r + r[2].pd_r + r[2].od_r,
           r[3].ptab_r + r[3].otab_r + r[3].pd_r + r[3].od_r,
           r[4].ptab_r + r[4].otab_r + r[4].pd_r + r[4].od_r);

    printf("\nSolutions (all five must match):\n");
    for (int v = 0; v < 5; v++) {
        printf("  V%d (%2d moves):", v, len[v]);
        for (int i = 0; i < len[v]; i++)
            printf(" %s", move_names[moves[v][i]]);
        printf("\n");
    }
    return 0;
}
