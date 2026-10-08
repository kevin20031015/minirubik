#include "rv_io.h"

static const uint32_t fact[7] = {720, 120, 24, 6, 2, 1, 1};
static const char input[] = "21345671111111";
static uint8_t state[14];
static uint8_t seen[7]; 
typedef struct { uint32_t p, o, next, last; } frame_t;
static frame_t frames[12]; // 起點加上最多 11 步
static const char move_names[9][4] = {" R", " R2", " R'", " B", " B2", " B'", " D", " D2", " D'"};

int main(void)
{
    uint32_t i, j, p, o;
    uint32_t bound, depth, m, np, no, rem;
    uint32_t sum; 
    int k;
    uint32_t cp, co;
    // 輸入字元減 '1'，轉成內部編碼
    for (i = 0; i < 14; i++) {
       state[i]=input[i]-'1';
    }
    // 前 7 個值必須是 0～6，不能重複
    for (i = 0; i < 7; i++) {
        if (state[i]>=7) goto invalid;          
        if (seen[state[i]] == 1) goto invalid;  
        seen[state[i]] = 1;                     
    }
    // 方向值只能是 0～2，總和必須是 3 的倍數
    sum = 0;
    for (i = 7; i < 14; i++) {
        if (state[i]>=3) goto invalid;         
        sum = sum + state[i];                   
    }
    while (sum >= 3) sum = sum - 3;             
    if (sum != 0) goto invalid;                 
    // 用後方較小元素的個數計算排列編號 p（0～5039）
    p = 0;
    for (i = 0; i < 7; i++) {
        for (j = i+1; j < 7; j++) {
            if (state[j] < state[i]) p = p + fact[i];
        }
    }
    // 前 6 個方向編成三進位數，第 7 個由方向總和決定
    o = 0;
    for (i = 7; i < 13; i++) {
        o=3*o+state[i];    
    }
    // 取兩張距離表的較大值，作為搜尋深度的起點
    bound = p_distance[p];
    if (p_distance[p]<o_distance[o]) bound = o_distance[o];

    // 每輪從起點重搜；last = 9 表示沒有上一步

    new_bound:
    depth=0;
    frames[depth].p = p;
    frames[depth].o = o;
    frames[depth].next = 0; 
    frames[depth].last = 9;
    if (p != 0) goto try_move;
    if (o != 0) goto try_move;
    goto found;


// 同一面的連續轉動可以合併，不必搜尋。
// 轉完後若估計距離超過剩餘步數，就跳過。
// 先查位置距離，通過後再查方向距離。
try_move:                    
    if(depth==bound) goto back;
    m = frames[depth].next;
    if(m==9) goto back;
    frames[depth].next = m + 1;
    if(move_face[m] == move_face[frames[depth].last]) goto try_move;

    np = p_move_rows[m][frames[depth].p];
    rem = bound - depth - 1;
    if(p_distance[np]>rem) goto try_move;

    no = o_move_rows[m][frames[depth].o];
    if(o_distance[no]>rem) goto try_move;
    depth = depth + 1;
    frames[depth].p = np;
    frames[depth].o = no;
    frames[depth].next = 0;
    frames[depth].last = m;
    if (np != 0) goto try_move;
    if (no != 0) goto try_move;
    goto found;
// 根節點也試完就增加 bound，否則退回上一層
back:
    if(depth != 0) goto pop;
    bound = bound + 1;
    if(bound > 11) goto fail;
    goto new_bound;

pop:
    depth = depth - 1;
    goto try_move;

fail:
    depth = - 1;


// 從第 1 層開始讀 last，印出解答並從起點重播，最後檢查 p、o 是否都回到 0
found:
    print_int((int)depth);
    i = 1;                   
    k = (int)depth;          
    cp = p;                  
    co = o;                  
check_loop:
    if (k <= 0) goto check_done;          
    m = frames[i].last;                           
    print_str(move_names[m]);
    cp = p_move_rows[m][cp];
    co = o_move_rows[m][co];
    i = i + 1;
    k = k - 1;
    goto check_loop;
check_done:
    if(cp != 0) goto bad;
    if(co != 0) goto bad;                            
    print_str(" PASS");
    return 0;
bad:
    print_str(" FAIL");
    return 1;

invalid:
    print_str(" INVALID");
    return 1;
}
