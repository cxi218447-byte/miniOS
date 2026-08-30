/*
 * 第 5 次课：分支、循环与汇编程序设计基础 demo 声明。
 * 实现见 lib/branch_loop.S。
 */
#ifndef MINIOS_BRANCH_LOOP_H
#define MINIOS_BRANCH_LOOP_H

/* while 计数（beqz 判空 + addi.d 步进 + b 回跳）：sum = 1+2+...+n */
long bl_sum1n(long n);

/* if-else（beq 版）：a==b 返回 1，否则返回 0 */
long bl_are_equal(long a, long b);

/* if-else（bne 版，条件方向相反）：与 bl_are_equal 语义相同 */
long bl_not_equal_demo(long a, long b);

/* for 风格计数循环（bnez 判非零 + beq 判越界退出）：统计字节数组中非零元素个数 */
long bl_count_nonzero(const unsigned char *base, long len);

#endif
