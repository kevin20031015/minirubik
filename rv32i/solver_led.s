
# ===== 暫存器表 =====
# s0  = p（位置編號，0～5039）
# s1  = state 的地址
# s2  = 第 2 塊：指向 fact 的指標；第 4 塊之後：常數 9
# s3  = o（方向編號，0～728）
# s4  = 目前這一層 frame 的地址
# s5  = bound（這一輪的深度上限，從 h 開始，每輪 +1）
# s6  = depth（目前在第幾層）
# s7  = move_face 的地址
# s8  = p_move_rows 的地址
# s9  = p_distance 的地址
# s10 = o_move_rows 的地址
# s11 = o_distance 的地址
#
# 搜尋中（try_move）的 t 暫存器：
# t1 = m（這次試的轉法 0～8）   t4 = np（轉完的新 p）
# t5 = 還剩幾步（bound-depth-1） t6 = no（轉完的新 o）
#
# frames 每層 16 bytes：0(p)  4(o)  8(next)  12(last)

.data
fact:   .word 720, 120, 24, 6, 2, 1, 1
input:  .string "21345671111111"    
state:  .zero 14
seen:   .zero 7
.align 4
frames: .zero 192
msg_invalid: .string " INVALID"
msg_pass: .string " PASS"
msg_fail: .string " FAIL"
move_names:
    .string " R"
    .zero 1
    .string " R2"
    .string " R'"
    .string " B"
    .zero 1
    .string " B2"
    .string " B'"
    .string " D"
    .zero 1
    .string " D2"
    .string " D'"

.text
main:
    # ===== 第 1 塊：讀輸入，每個字減 '1' 存進 state =====
    la t0, input
    la t1, state
    addi t3, zero, 0  # t3 = 0（第幾個字
    addi t4, zero, 14  # t4 = 14（總共 14 個字）
loop:
    lbu t2, 0(t0)  # 讀 1 個字
    addi t2, t2, -49
    sb   t2, 0(t1)  # 存進 state
    addi t0, t0, 1  # 輸入往後 1 格
    addi t1, t1, 1  # state 往後 1 格
    addi t3, t3, 1  # 計數 +1
    blt t3, t4, loop     # 還沒到 14 → 繼續
# ===== 第 1.5 塊：檢查輸入 =====
    la t0, state
    addi t3, zero, 0    # i = 0
    addi t4, zero, 7    # 範圍上限：要 < 7
    addi t5, zero, 7  # 迴圈跑 7 次
    la t6, seen   # seen：7 格，一開始全是 0
chk_p:
    lbu t2, 0(t0)
    bge t2, t4, invalid   # ≥ 7 → 不合法       
    add t1, t6, t2        # t1 = seen 的地址 + state[i]     
    lbu t2, 0(t1)         # t2 = seen[state[i]]       
    bne t2, zero, invalid   # 已經劃過 → 重複     
    addi t2, zero, 1
    sb t2, 0(t1)                # 劃掉
    addi t0, t0, 1               
    addi t3, t3, 1
    blt t3, t5, chk_p
    addi t4, zero, 3  # 範圍上限改成 3
    addi t5, zero, 14  # 迴圈跑到第 14 個
    addi t1, zero, 0       # sum = 0
chk_o:
    lbu t2, 0(t0)  #t0 t3沒有重設
    bge t2, t4, invalid  # ≥ 3 → 不合法
    add t1, t1, t2    # sum += state[i]
    addi t0, t0, 1
    addi t3, t3, 1
    blt t3, t5, chk_o
mod3:
    blt t1, t4, mod3_done        # sum < 3 → 減完了
    addi t1, t1, -3             # sum -= 3
    j mod3
mod3_done:
    bne t1, zero, invalid        # 餘數不是 0 → 不合法


    # ===== 第 2 塊：位置編號 p（放在 s0）=====
    la s1, state
    la s2, fact   # s2 指著 fact[0] = 720
    addi s0, zero, 0  # p = 0
    addi t0, zero, 0  # i = 0
    addi t4, zero, 7
outer:
    add t6, s1, t0
    lbu t2, 0(t6)  # t2 = state[i]
    lw t5, 0(s2)  # t5 = fact[i]
    addi t1, t0, 1  # j = i + 1
inner:
    bge t1, t4, inner_done  # j 到 7 → 這個 i 數完了
    add t6, s1, t1  # t6 = state[j] 的地址 
    lbu t3, 0(t6)  # t3 = state[j]
    bge t3, t2, skip  # state[j] 沒比較小 → 跳過
    add s0, s0, t5  # 比較小 → p += fact[i]
skip: 
    addi t1, t1, 1
    j inner
inner_done:
    addi s2, s2, 4  # fact 是 .word，下一格 +4
    addi t0, t0, 1
    blt t0, t4, outer

    # ===== 第 3 塊：方向編號 o（放在 s3）=====
    addi s3, zero, 0  # o = 0
    addi t0, zero, 7  # 從 state[7] 開始
    addi t4, zero, 13  # 到 state[12] 為止（不含 13）
ori_loop:
    add t6, s1, t0  # state[t0] 的地址
    lbu t2, 0(t6)  # t2 = state[t0]
    add t5, s3, s3  # t5 = 2o
    add s3, s3, t5  # o = 3o
    add s3, s3, t2  # o = 3o + state[t0]
    addi t0, t0, 1
    blt t0, t4, ori_loop
# ===== 第 4a 塊：h = max(p_distance[p], o_distance[o])，放在 s5 =====
    la s7, move_face
    la s8, p_move_rows
    la s9, p_distance
    la s10, o_move_rows
    la s11, o_distance  # 5 個表的地址，只載一次（優化 1）
    addi s2, zero, 9  # s2 改放常數 9（優化 3）
    add t0, s9, s0  # p_distance[p] 的地址
    lbu t1, 0(t0)  # t1 = p_distance[p]
    add t0, s11, s3  
    lbu t2, 0(t0)  # t2 = o_distance[o]
    addi s5, t1, 0  # 先假設 h = p_distance
    bge t1, t2, have_h  # p_distance 比較大 → 就是它
    addi s5, t2, 0  # 不然 (bound)  h = o_distance
have_h:
# ===== 第 4b 塊：IDA* 搜尋 =====
new_bound:
    la s4, frames
    addi s6, zero, 0  # depth = 0
    sw s0, 0(s4)  # frame.p = 起點的 p
    sw s3, 4(s4)  # frame.o = 起點的 o
    addi t0, zero, 0
    sw t0, 8(s4)  # frame.next = 0（下一個要試 R）
    sw s2, 12(s4)  # frame.last = 9（s2 = 9）
    bne s0, zero, try_move  # p ≠ 0 → 還沒解好，開始搜
    bne s3, zero, try_move  # o ≠ 0 → 還沒解好，開始搜
    j found  # p、o 都是 0 → 本來就解好了
try_move:
    beq s6, s5, back  # depth == bound → 不能再往下，退回
    lw t1, 8(s4)  # m = 這層的 next
    beq t1, s2, back  # m == 9 → 9 種都試完了，退回
    addi t0, t1, 1  # next = m + 1（先記好下次從哪個開始）
    sw t0, 8(s4)
    add t2, s7, t1
    lbu t2, 0(t2)  # t2 = move_face[m]
    lw t3, 12(s4)
    add t3, s7, t3
    lbu t3, 0(t3)  # t3 = move_face[last]
    beq t2, t3, try_move  # 同一面 → 跳過，換下一個 m
     
    slli t2, t1, 2  # t2 = 4m
    add t0, s8, t2  # p_move_rows[m] 的地址
    lw t0, 0(t0)  # t0 = 第 m 張 p 表的開頭地址
    lw t2, 0(s4)  # t2 = 這層的 p
    slli t2, t2, 1  # t2 = 2p
    add t0, t0, t2  
    lhu t4, 0(t0)  # t4 = np（轉完的新 p）
    sub t5, s5, s6  # bound − depth
    addi t5, t5, -1  # t5 = 轉完這步後還剩幾步
    add t0, s9, t4
    lbu t2, 0(t0)  # t2 = p_distance[np]
    bgt t2, t5, try_move  # 至少要的步數 > 剩的步數 → 砍掉，試下一個 m
    
    slli t2, t1, 2  # t2 = 4m
    add t0, s10, t2
    lw t0, 0(t0)  # 第 m 張 o 表的開頭地址
    lw t2, 4(s4)  # 這層的 o
    slli t2, t2, 1  # 2o
    add t0, t0, t2
    lhu t6, 0(t0)  # t6 = no（轉完的新 o）
    add t0, s11, t6
    
    lbu t2, 0(t0)  # t2 = o_distance[no]
    bgt t2, t5, try_move  # 一樣跟剩的步數 t5 比，超過就砍
    addi s4, s4, 16  # s4 往下一層
    addi s6, s6, 1  # depth + 1
    sw t4, 0(s4)  # 新的一層：p = np
    sw t6, 4(s4)  #  o = no
    sw zero, 8(s4)  # next = 0（從 R 開始試）
    sw t1, 12(s4)  # last = m（剛剛轉的那個）
    bne t4, zero, try_move  # 還沒解好 → 在新的一層繼續試
    bne t6, zero, try_move
    j found  # np、no 都是 0 → 找到了

back:
    bne s6, zero, pop  # 不是第 0 層 → 退一層
    addi s5, s5, 1  # 第 0 層也試完了 → bound + 1
    addi t0, zero, 11
    bgt s5, t0, fail  # bound 超過 11 → 放棄
    j new_bound  # 用新的 bound 從頭再搜一次

pop:
    addi s4, s4, -16  # s4 退回上一層
    addi s6, s6, -1  # depth − 1
    j try_move  # 回上一層，照它的next接著試

fail:
    addi s6, zero, -1  # depth = −1，代表找不到


found:
    mv a0, s6
    li a7, 1
    ecall    # 印出步數（depth）
    jal  ra, init  # LED：抄入輸入的狀態
    jal  ra, render  # LED：畫打亂的樣子
    la t3, frames
    addi t3, t3, 16  # t3 指著第 1 層（第 0 層是起點，沒有步驟）
    addi t4, s6, 0  # t4 = 還剩幾步要轉
    addi t5, s0, 0  # t5 = 起點的 p（搜尋中 s0 沒被改過）
    addi t6, s3, 0  # t6 = 起點的 o
check_loop:
     bge zero, t4, check_done  # 剩 0 步 → 全部轉完，去檢查
     lw t1, 12(t3)  # t1 = 這層的 last，也就是這一步的 m
     la a0, move_names
     slli t2, t1, 2
     add a0, a0, t2  # 第 m 個名字 = move_names + 4m（每個名字 4 bytes
     addi a7, zero, 4
     ecall  # 印出這一步，例如 " R"
     mv   a0, t1   # LED：a0 = 這一步的 m
     jal  ra, turn  # LED：轉一次
     jal  ra, render # LED：重畫
     
     slli t2, t1, 2
     add t0, s8, t2
     lw t0, 0(t0)  # 第 m 張 p 表
     slli t2, t5, 1
     add t0, t0, t2
     lhu t5, 0(t0)
     
     slli t2, t1, 2
     add t0, s10, t2
     lw t0, 0(t0)  # 第 m 張 o 表
     slli t2, t6, 1
     add t0, t0, t2
     lhu t6, 0(t0)  # t6 = 照這一步轉完的 o

     addi t3, t3, 16  # 換到下一層
     addi t4, t4, -1  # 剩的步數 −1
     j check_loop
check_done:
    bne t5, zero, bad
    bne t6, zero, bad   # 轉完 p 或 o 不是 0 → 答案錯，印 FAIL
    la a0, msg_pass
    li a7, 4
    ecall  # 都是 0 → 印 PASS
    j exit
invalid:
    la a0, msg_invalid
    li a7, 4
    ecall  # 輸入不合法 → 印 INVALID
    j exit
bad:
    la a0, msg_fail
    li a7, 4
    ecall  # 印 FAIL
exit:
    # ===== 結束程式 =====
    addi a7, zero, 10
    ecall
