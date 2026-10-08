.equ N, 4194304       # ← 迴圈次數
.equ STEP, 4          # ← 每次位址加多少；量第二次時改成 0

.text
    li   t0, 0x10000000     # 起始位址（Ripes 的 data 區）
    li   t1, N              # 迴圈次數
loop:
    sw   t0, 0(t0)          # 寫 4 bytes 到記憶體
    addi t0, t0, STEP       # ← 位址往後 STEP bytes
    addi t1, t1, -1         # 次數 -1
    bnez t1, loop           # 還沒到 0 就繼續
    li   a7, 10             # 結束程式
    ecall