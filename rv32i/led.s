
.data
.align 4
new_p:  # 轉的時候暫存新狀態（new_o 緊接在後面，差 8）
    .zero 8
new_o:
    .zero 8
move_tab:  # 每種轉法 16 bytes：前 8 個 source、後 8 個 twist
    .byte 1,4,2,0,3,5,6,0,  1,2,0,2,1,0,0,0    # 0 R
    .byte 4,3,2,1,0,5,6,0,  0,0,0,0,0,0,0,0    # 1 R2
    .byte 3,0,2,4,1,5,6,0,  1,2,0,2,1,0,0,0    # 2 R'
    .byte 0,1,2,4,5,6,3,0,  0,0,0,1,2,1,2,0    # 3 B
    .byte 0,1,2,5,6,3,4,0,  0,0,0,0,0,0,0,0    # 4 B2
    .byte 0,1,2,6,3,4,5,0,  0,0,0,1,2,1,2,0    # 5 B'
    .byte 0,2,5,3,1,4,6,0,  0,0,0,0,0,0,0,0    # 6 D
    .byte 0,5,4,3,2,1,6,0,  0,0,0,0,0,0,0,0    # 7 D2
    .byte 0,4,1,3,5,2,6,0,  0,0,0,0,0,0,0,0    # 8 D'
stick_pos:  # 24 格各在哪個位置（7 = 固定的 FUL）
    .byte 6,3,7,0, 6,7,5,2, 7,0,2,1, 0,3,1,4, 3,6,4,5, 2,1,5,4
stick_slot:
    .byte 0,0,0,0, 2,1,1,2, 2,1,1,2, 2,1,1,2, 2,1,1,2, 0,0,0,0
home:  # 8 塊角各自的 3 個顏色（0 號、1 號、2 號），第 4 個補 0 湊成 4 bytes
    .byte 0,2,3,0,  5,3,2,0,  5,2,1,0,  0,3,4,0
    .byte 5,4,3,0,  5,1,4,0,  0,4,1,0,  0,1,2,0
cube_p:
    .byte 0,1,2,3,4,5,6,7
cube_o:
    .byte 0,0,0,0,0,0,0,0
sticker_off:                       # 每格左上角離 BASE 幾個 byte（init 用 WIDTH 算好填進來）
    .zero 96
sticker_face:                      # 每格現在是哪一面的顏色（0～5）
    .byte 0,0,0,0, 1,1,1,1, 2,2,2,2, 3,3,3,3, 4,4,4,4, 5,5,5,5
sticker_x:                         # 每格左上角的 x
    .byte 9,13,9,13, 0,4,0,4, 9,13,9,13, 18,22,18,22, 27,31,27,31, 9,13,9,13
sticker_y:                         # 每格左上角的 y（跟 sticker_x 差 24）
    .byte 0,0,3,3, 7,7,10,10, 7,7,10,10, 7,7,10,10, 7,7,10,10, 14,14,17,17
.align 4
face_rgb:   # U 白、L 橘、F 綠、R 紅、B 藍、D 黃
    .word 0x00FFFFFF, 0x00FF8000, 0x0000FF00, 0x00FF0000, 0x000000FF, 0x00FFFF00

.text
   

#  turn：照第 a0 種轉法，把 cube_p / cube_o 轉一次
turn:
    slli a0, a0, 4  # m × 16（每種轉法 16 bytes）
    la   a1, move_tab
    add  a1, a1, a0  # a1 指著這種轉法的 source[0]
    la   a3, new_p  # a3 指著 new_p[0]
    addi a5, zero, 0 # i = 0
    addi a6, zero, 7  # 7 個位置
turn_loop:
    lbu  a2, 0(a1)  # j = source[i]
    la   a7, cube_p
    add  a7, a7, a2  # cube_p[j] 的地址
    lbu  a4, 0(a7)  # 位置 j 的塊
    sb   a4, 0(a3)  # new_p[i] = 那塊
    lbu  a4, 8(a7)    # 位置 j 的方向（cube_o 在 cube_p 後面 8 個）
    lbu  a2, 8(a1)  # twist[i]（在 source 後面 8 個）
    add  a4, a4, a2  # 方向 + twist（最多 4）
    addi a7, zero, 3
    blt  a4, a7, o_ok  # < 3 就不用減
    addi a4, a4, -3
o_ok:
    sb   a4, 8(a3)   # new_o[i] = 新方向
    addi a1, a1, 1
    addi a3, a3, 1
    addi a5, a5, 1
    blt  a5, a6, turn_loop  # 7 個位置都做完
    la   a1, new_p   # 新狀態抄回 cube
    la   a3, cube_p
    addi a5, zero, 0
copy_loop:
    lbu  a4, 0(a1)
    sb   a4, 0(a3)  # cube_p[i] = new_p[i]
    lbu  a4, 8(a1)
    sb   a4, 8(a3)  # cube_o[i] = new_o[i]
    addi a1, a1, 1
    addi a3, a3, 1
    addi a5, a5, 1
    blt  a5, a6, copy_loop
    ret
render:
    la   a1, stick_pos
    la   a4, stick_slot
    la   a3, sticker_face
    addi a5, zero, 0
    addi a6, zero, 24
calc_loop:
    lbu  a2, 0(a1)   # k
    lbu  a0, 0(a4)   # s
    la   a7, cube_o
    add  a7, a7, a2
    lbu  a7, 0(a7)   # o
    sub  a0, a0, a7 
    la   a7, cube_p
    add  a7, a7, a2
    lbu  a2, 0(a7)  # c
    bge  a0, zero, t_ok
    addi a0, a0, 3  # 負的就 +3
t_ok:
    slli a2, a2, 2
    add  a2, a2, a0   
    la   a7, home
    add  a7, a7, a2
    lbu  a2, 0(a7) # 這格的面
    sb   a2, 0(a3) # 存進 sticker_face
    addi a1, a1, 1
    addi a4, a4, 1
    addi a3, a3, 1
    addi a5, a5, 1
    blt  a5, a6, calc_loop

    li   a7, LED_MATRIX_0_WIDTH
    addi a2, zero, 35
    blt a7, a2, no_draw   # WIDTH < 35 → 不畫，跳到 no_draw
    li   a7, LED_MATRIX_0_HEIGHT
    addi a2, zero, 20
    blt a7, a2, no_draw  # HEIGHT < 20 → 不畫，跳到 no_draw

    li   a0, LED_MATRIX_0_BASE # a0 = LED 的開頭
    li   a6, LED_MATRIX_0_WIDTH
    slli a6, a6, 2
    la   a4, sticker_off   # a4 指著 sticker_off[0]
    la   a1, sticker_face # a1 指著 sticker_face[0]
    addi a5, zero, 24
draw_loop:
    lw   a3, 0(a4)    # 第 1 步：a3 = 這格的位移
    add  a3, a0, a3    # 第 2 步：a3 = BASE + 位移
    lbu  a2, 0(a1)  # 第 3 步：a2 = 這格是哪一面（0～5）
    slli a2, a2, 2    # a2 = 面 × 4（.word 要 ×4）
    la   a7, face_rgb
    add  a7, a7, a2   # a7 = face_rgb[面] 的地址
    lw  a2, 0(a7)  # a2 = 顏色
    sw  a2, 0(a3)   # 第 5 步：畫 4 × 3
    sw  a2, 4(a3)
    sw  a2, 8(a3)
    sw  a2, 12(a3)
    add a3, a3, a6
    sw  a2, 0(a3)               # 第 2 列
    sw  a2, 4(a3)
    sw  a2, 8(a3)
    sw  a2, 12(a3)
    add a3, a3, a6
    sw  a2, 0(a3)               # 第 3 列
    sw  a2, 4(a3)
    sw  a2, 8(a3)
    sw  a2, 12(a3)
    addi a4, a4, 4    # 第 6 步：sticker_off 下一格（.word，+4）
    addi a1, a1, 1   # sticker_face 下一格（.byte，+1）
    addi a5, a5, -1   # 還剩幾格 − 1
    bne  a5, zero, draw_loop  # 還沒到 0 → 回去畫下一格
no_draw:
    li   a0, 300000     # 空轉 30 萬圈，讓畫面停一下
delay:
    addi a0, a0, -1
    bne  a0, zero, delay
    
    ret   # 畫完，回到呼叫 render 的地方



init:
    la   a1, state  # 從 state 抄
    la   a3, cube_p   # 抄到 cube_p
    addi a5, zero, 0
    addi a6, zero, 7
init_loop:
    lbu  a4, 0(a1)  # state[i]：位置 i 的塊
    sb   a4, 0(a3)  # → cube_p[i]
    lbu  a4, 7(a1)  # state[7 + i]：位置 i 的方向
    sb   a4, 8(a3)  # → cube_o[i]
    addi a1, a1, 1
    addi a3, a3, 1
    addi a5, a5, 1
    blt  a5, a6, init_loop
    # 用 WIDTH 算 24 格的位移，填進 sticker_off 
    li   a0, LED_MATRIX_0_WIDTH
    slli a0, a0, 2    # a0 = 一列幾個 byte（WIDTH × 4）
    la   a1, sticker_x   # a1 指著 sticker_x[0]（y 在 24(a1)）
    la   a3, sticker_off  # a3 指著 sticker_off[0]
    addi a5, zero, 24  # a5 = 還剩幾格
off_loop:
    lbu  a4, 24(a1)  # a4 = y
    addi a6, zero, 0    # a6 = 位移，從 0 開始
mul_loop:
    beq  a4, zero, mul_done   # y 次加完了
    add a6, a6, a0    # 位移 + 一列
    addi a4, a4, -1    # y − 1
    j    mul_loop
mul_done:
    lbu  a4, 0(a1)   # a4 = x
    slli a4, a4, 2  
    add a6, a6, a4 
    sw a6, 0(a3)   # 存進 sticker_off[i]
    addi a1, a1, 1   # 下一格的 x（.byte，+1）
    addi a3, a3, 4  # 下一格的 sticker_off（.word，4）
    addi a5, a5, -1
    bne  a5, zero, off_loop
    ret
    