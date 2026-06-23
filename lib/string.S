/*
 * 第 4/7 周实验：用 LoongArch 汇编实现常用字符串/内存函数。
 * 先写清晰的逐字节版本，再讨论按 8 字节优化。
 */

    .section .text

    .globl memset
memset:
    move        $t0, $a0          /* 保存原始 dst，作为返回值。 */
    beqz        $a2, 2f

1:
    st.b        $a1, $a0, 0
    addi.d      $a0, $a0, 1
    addi.d      $a2, $a2, -1
    bnez        $a2, 1b

2:
    move        $a0, $t0
    jr          $ra

    .globl memcpy
memcpy:
    move        $t0, $a0          /* 保存原始 dst，作为返回值。 */
    beqz        $a2, 2f

1:
    ld.bu       $t1, $a1, 0
    st.b        $t1, $a0, 0
    addi.d      $a0, $a0, 1
    addi.d      $a1, $a1, 1
    addi.d      $a2, $a2, -1
    bnez        $a2, 1b

2:
    move        $a0, $t0
    jr          $ra

    .globl strlen
strlen:
    move        $t0, $a0          /* t0 记录字符串起始地址。 */

1:
    ld.bu       $t1, $a0, 0
    beqz        $t1, 2f
    addi.d      $a0, $a0, 1
    b           1b

2:
    sub.d       $a0, $a0, $t0
    jr          $ra
