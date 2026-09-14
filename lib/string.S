/*
 * miniOS 最小字符串/内存工具库。
 * memset/memcpy/strlen：最基础的三个逐字节实现，第 2 次课起可用。
 * memmove：memcpy 处理不了重叠区间时的真正解法（比较地址、选方向）。
 * strcmp：逐字节比较两个字符串，返回差值。
 * zero_and_copy：组合 memset+strlen+memcpy，安全地把字符串放进固定缓冲区，
 *   是本文件里唯一的非叶子函数（内部有 bl，要保存 $ra 和跨调用存活的寄存器）。
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

/*
 * ---- memmove：memcpy 处理不了重叠区间的真正解法 ----
 * void *memmove(void *dst, const void *src, size_t n)
 * dst < src：从头往后搬，和 memcpy 一样安全（永远读在写前面）。
 * dst > src：必须从尾往前搬，否则会在读到某个字节之前就把它覆盖掉。
 * 用 sltu（无符号小于）比较两个地址——地址要按无符号理解，不能用 slt。
 * 叶子函数：两条路径都只是循环，函数体内没有 bl。
 */
    .globl memmove
memmove:
    move        $t0, $a0            /* 保存原始 dst，作为返回值。 */
    beqz        $a2, 4f             /* n==0：什么都不用做。 */

    sltu        $t2, $a0, $a1       /* t2 = (dst < src) ? 1 : 0 */
    bnez        $t2, 2f             /* dst < src：正向搬，和 memcpy 一样 */

    /* dst >= src：从尾往前搬，先把两个指针都移到最后一个字节 */
    add.d       $a0, $a0, $a2
    add.d       $a1, $a1, $a2
    addi.d      $a0, $a0, -1
    addi.d      $a1, $a1, -1

1:
    ld.bu       $t1, $a1, 0
    st.b        $t1, $a0, 0
    addi.d      $a0, $a0, -1
    addi.d      $a1, $a1, -1
    addi.d      $a2, $a2, -1
    bnez        $a2, 1b
    b           4f

2:
    ld.bu       $t1, $a1, 0
    st.b        $t1, $a0, 0
    addi.d      $a0, $a0, 1
    addi.d      $a1, $a1, 1
    addi.d      $a2, $a2, -1
    bnez        $a2, 2b

4:
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

/*
 * ---- strcmp ----
 * int strcmp(const char *a, const char *b)
 * 逐字节比较，遇到不同字节或同时读到 '\0' 就停：
 *   返回 0   ：两串相等
 *   返回 !=0 ：第一个不同字节的差值（$t0 - $t1，教学简化，不做饱和处理）
 * 叶子函数：函数体内没有 bl，不用碰 $ra。
 */
    .globl strcmp
strcmp:
1:
    ld.bu       $t0, $a0, 0       /* t0 = *a */
    ld.bu       $t1, $a1, 0       /* t1 = *b */
    bne         $t0, $t1, 2f      /* 字节不同：跳出去算差值 */
    beqz        $t0, 3f           /* 两边都读到 '\0'：字符串相等 */
    addi.d      $a0, $a0, 1
    addi.d      $a1, $a1, 1
    b           1b

2:
    sub.d       $a0, $t0, $t1
    jr          $ra

3:
    move        $a0, $zero
    jr          $ra

/*
 * ---- zero_and_copy（本文件唯一的非叶子函数） ----
 * void *zero_and_copy(void *dst, const char *src, size_t dst_size)
 * 先把整块 dst 清零，再把 src 的内容搬进去——参数形状和 memcpy(dst,src,n)
 * 一样，n 换成了目标缓冲区总大小 dst_size。内部依次 bl memset/strlen/memcpy：
 * dst/src 要跨三次 bl 存活，借用 $s0/$s1（对照 sa_strlen_and_puts 用
 * $s0/$s1 跨两次 bl 保活 s/len 的手法，见 lib/stack_abi.S）。
 *
 * 附带的好处：因为先 memset 清零，dst_size 只要大于 strlen(src)，
 * 结果天然是以 '\0' 结尾的合法 C 字符串——只调用 memcpy 做不到这一点。
 */
    .globl zero_and_copy
zero_and_copy:
    addi.d      $sp, $sp, -32
    st.d        $ra, $sp, 24
    st.d        $s0, $sp, 16     /* s0 = dst，跨三次 bl 保存 */
    st.d        $s1, $sp, 8      /* s1 = src，跨三次 bl 保存 */

    move        $s0, $a0         /* dst */
    move        $s1, $a1         /* src */

    /* 1) memset(dst, 0, dst_size)：$a0=dst、$a2=dst_size 都已经是对的，
     *    只需把 $a1 换成填充字节 0（原来的 $a1=src 已存进 $s1）。 */
    move        $a1, $zero
    bl          memset

    /* 2) strlen(src)：量出真正要搬的长度。 */
    move        $a0, $s1
    bl          strlen           /* a0 = len */

    /* 3) memcpy(dst, src, len)：把 src 内容搬进 dst。 */
    move        $a2, $a0         /* n = len */
    move        $a1, $s1         /* src */
    move        $a0, $s0         /* dst */
    bl          memcpy           /* memcpy 返回 dst，正好也是本函数的返回值 */

    ld.d        $ra, $sp, 24
    ld.d        $s0, $sp, 16
    ld.d        $s1, $sp, 8
    addi.d      $sp, $sp, 32
    jr          $ra
