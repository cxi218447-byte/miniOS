/*
 * 第 9 次课：从 ESTAT 里取出 Ecode 字段（bit[21:16]，共 6 位）。
 * 对应 C 写法：(estat >> 16) & 0x3f —— 这里用纯汇编实现同一件事，
 * 调用方式和普通 C 函数一样：ecode_from_estat(estat)。
 */

    .section .text

    .globl ecode_from_estat
ecode_from_estat:
    srli.d      $a0, $a0, 16      /* 逻辑右移 16 位，Ecode 落到最低 6 位 */
    andi        $a0, $a0, 0x3f    /* 只保留低 6 位，盖掉其余无关位 */
    jr          $ra               /* 返回值仍在 $a0，LoongArch 调用约定 */
