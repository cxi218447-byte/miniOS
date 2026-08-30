/*
 * 第 2 次课：提供 memset/memcpy/strlen 的最小逐字节实现，
 * 用于演示「C 调用汇编」。完整精讲与边界测试见第 8 次课。
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
