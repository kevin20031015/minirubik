.data
fact:   .word 720, 120, 24, 6, 2, 1, 1
input:  .string "54721631111111"    # 測試用：改成 "12345672111113" 應印出 0 243
state:  .zero 14
.align 2
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
    addi t3, zero, 0
    addi t4, zero, 14
loop:
    lbu t2, 0(t0)
    addi t2, t2, -49
    sb t2, 0(t1)
    addi t0, t0, 1
    addi t1, t1, 1
    addi t3, t3, 1
    blt t3, t4, loop
# ===== 第 1.5 塊：檢查輸入 =====
    la t0, state
    addi t3, zero, 0
    addi t4, zero, 7
    addi t5, zero, 7
chk_p:
    lbu t2, 0(t0)
    bge t2, t4, invalid
    addi t0, t0, 1
    addi t3, t3, 1
    blt t3, t5, chk_p
    addi t4, zero, 3
    addi t5, zero, 14
chk_o:
    lbu t2, 0(t0)
    bge t2, t4, invalid
    addi t0, t0, 1
    addi t3, t3, 1
    blt t3, t5, chk_o

    # ===== 第 2 塊：位置編號 p（放在 s0）=====
    la s1, state
    la s2, fact
    addi s0, zero, 0
    addi t0, zero, 0
    addi t4, zero, 7
outer:
    add t6, s1, t0
    lbu t2, 0(t6)
    lw t5, 0(s2)
    addi t1, t0, 1
inner:
    bge t1, t4, inner_done
    add t6, s1, t1
    lbu t3, 0(t6)
    bge t3, t2, skip
    add s0, s0, t5
skip:
    addi t1, t1, 1
    j inner
inner_done:
    addi s2, s2, 4
    addi t0, t0, 1
    blt t0, t4, outer

    # ===== 第 3 塊：方向編號 o（放在 s3）=====
    addi s3, zero, 0
    addi t0, zero, 7
    addi t4, zero, 13
ori_loop:
    add t6, s1, t0
    lbu t2, 0(t6)
    add t5, s3, s3
    add s3, s3, t5
    add s3, s3, t2
    addi t0, t0, 1
    blt t0, t4, ori_loop
# ===== 第 4a 塊：h = max(p_distance[p], o_distance[o])，放在 s5 =====
    la s7, move_face
    la s8, p_move_rows
    la s9, p_distance
    la s10, o_move_rows
    la s11, o_distance
    addi s2, zero, 9
    add t0, s9, s0
    lbu t1, 0(t0)
    add t0, s11, s3
    lbu t2, 0(t0)
    addi s5, t1, 0
    bge t1, t2, have_h
    addi s5, t2, 0
have_h:
# ===== 第 4b 塊：IDA* 搜尋 =====
new_bound:
    la s4, frames
    addi s6, zero, 0
    sw s0, 0(s4)
    sw s3, 4(s4)
    addi t0, zero, 0
    sw t0, 8(s4)
    sw s2, 12(s4)
    bne s0, zero, try_move
    bne s3, zero, try_move
    j found
try_move:
    beq s6, s5, back
    lw t1, 8(s4)
    beq t1, s2, back
    addi t0, t1, 1
    sw t0, 8(s4)
    add t2, s7, t1
    lbu t2, 0(t2)
    lw t3, 12(s4)
    add t3, s7, t3
    lbu t3, 0(t3)
    beq t2, t3, try_move
    
    slli t2, t1, 2
    add t0, s8, t2
    lw t0, 0(t0)
    lw t2, 0(s4)
    slli t2, t2, 1
    add t0, t0, t2
    lhu t4, 0(t0)
    sub t5, s5, s6
    addi t5, t5, -1
    add t0, s9, t4
    
    lbu t2, 0(t0)
    bgt t2, t5, try_move
    
    slli t2, t1, 2
    add t0, s10, t2
    lw t0, 0(t0)
    lw t2, 4(s4)
    slli t2, t2, 1
    add t0, t0, t2
    lhu t6, 0(t0)
    add t0, s11, t6
    
    lbu t2, 0(t0)
    bgt t2, t5, try_move
    addi s4, s4, 16
    addi s6, s6, 1
    sw t4, 0(s4)
    sw t6, 4(s4)
    sw zero, 8(s4)
    sw t1, 12(s4)
    bne t4, zero, try_move
    bne t6, zero, try_move
    j found

back:
    bne s6, zero, pop
    addi s5, s5, 1
    addi t0, zero, 11
    bgt s5, t0, fail
    j new_bound

pop:
    addi s4, s4, -16
    addi s6, s6, -1
    j try_move

fail:
    addi s6, zero, -1


found:
    mv a0, s6
    li a7, 1
    ecall
    la t3, frames
    addi t3, t3, 16
    addi t4, s6, 0
    addi t5, s0, 0
    addi t6, s3, 0
check_loop:
     bge zero, t4, check_done
     lw t1, 12(t3)
     la a0, move_names
     slli t2, t1, 2
     add a0, a0, t2
     addi a7, zero, 4
     ecall
     
     slli t2, t1, 2
     add t0, s8, t2
     lw t0, 0(t0)
     slli t2, t5, 1
     add t0, t0, t2
     lhu t5, 0(t0)
     
     slli t2, t1, 2
     add t0, s10, t2
     lw t0, 0(t0)
     slli t2, t6, 1
     add t0, t0, t2
     lhu t6, 0(t0)

     addi t3, t3, 16
     addi t4, t4, -1
     j check_loop
check_done:
    bne t5, zero, bad
    bne t6, zero, bad
        la a0, msg_pass
    li a7, 4
    ecall
    j exit
invalid:
    la a0, msg_invalid
    li a7, 4
    ecall
    j exit
bad:
    la a0, msg_fail
    li a7, 4
    ecall
exit:
    # ===== 結束程式 =====
    addi a7, zero, 10
    ecall