/*
 * 第 5 次课：分支、循环与汇编程序设计基础 demo。
 * 对应讲义 §4.1 控制流指令家族 + §4.3 结构化模板。
 *
 * 本文件代表指令：
 *   beqz   为 0 则转（while 判空，见 bl_sum1n）
 *   beq    相等则转（if-else，见 bl_are_equal）
 *   bne    不等则转（if-else 反向写法，见 bl_not_equal_demo）
 *   bnez   非 0 则转（for 风格计数循环，见 bl_count_nonzero）
 *   b      无条件跳转（各函数的收尾/跳过 else）
 *
 * 字符串遍历骨架（ld.bu + beqz + addi.d + b）见 lib/string.S 的 strlen，
 * 第 2 次课已具备，第 8 次课精讲；本文件不重复实现。
 */

    .section .text

/* ---- while 计数：sum = 1 + 2 + ... + n（n 在 $a0，和从 $a0 返回） ---- */
    .globl bl_sum1n
bl_sum1n:
    move    $t0, $zero         /* t0 = 累加器，初值 0 */

1:
    beqz    $a0, 2f            /* 条件：n==0 结束 */
    add.d   $t0, $t0, $a0      /* 体：acc += n */
    addi.d  $a0, $a0, -1       /* 步进：n-- */
    b       1b                 /* 回跳 */

2:
    move    $a0, $t0
    jr      $ra

/* ---- if-else（beq 版）：a==b 返回 1，否则返回 0 ---- */
    .globl bl_are_equal
bl_are_equal:
    beq     $a0, $a1, 1f       /* 相等 -> then */
    move    $a0, $zero         /* else：结果 0 */
    b       2f
1:
    addi.d  $a0, $zero, 1      /* then：结果 1 */
2:
    jr      $ra

/* ---- if-else（bne 版）：与 bl_are_equal 语义相同，验证 beq/bne 只是条件方向相反 ---- */
    .globl bl_not_equal_demo
bl_not_equal_demo:
    bne     $a0, $a1, 1f       /* 不等 -> then */
    addi.d  $a0, $zero, 1      /* else（此处对应“相等”）：结果 1 */
    b       2f
1:
    move    $a0, $zero         /* then（此处对应“不等”）：结果 0 */
2:
    jr      $ra

/* ---- for 风格计数循环：统计字节数组中非零元素个数 ----
 * $a0 = base, $a1 = len；计数结果从 $a0 返回。
 */
    .globl bl_count_nonzero
bl_count_nonzero:
    move    $t0, $zero         /* t0 = 计数器 */
    move    $t1, $zero         /* t1 = 下标 i */

1:
    beq     $t1, $a1, 2f       /* 条件：i==len 结束 */
    ld.bu   $t2, $a0, 0
    bnez    $t2, 3f            /* 非零则计数 */
    b       4f
3:
    addi.d  $t0, $t0, 1
4:
    addi.d  $a0, $a0, 1        /* 指针++ */
    addi.d  $t1, $t1, 1        /* 下标++ */
    b       1b

2:
    move    $a0, $t0
    jr      $ra
