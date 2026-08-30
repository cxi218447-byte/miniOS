/*
 * 第 6 次课：函数调用约定与栈帧 demo 声明。
 * 实现见 lib/stack_abi.S。
 */
#ifndef MINIOS_STACK_ABI_H
#define MINIOS_STACK_ABI_H

/* 叶子函数：x + 1（不保存 $ra，因为不调用其他函数） */
long sa_add_one(long x);

/* 叶子函数：x + y（被 sa_add3 调用两次） */
long sa_add(long x, long y);

/* 非叶子函数：a + b + c（栈帧保存/恢复 $ra，内部两次 bl sa_add） */
long sa_add3(long a, long b, long c);

#endif
