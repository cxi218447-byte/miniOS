/*
 * 第 3 次课：按教材第 3 章「每类指令至少 1 条」的 demo 声明。
 * 实现见 lib/regs_alu.S。
 */
#ifndef MINIOS_REGS_ALU_H
#define MINIOS_REGS_ALU_H

/* 算术 add/sub：r = (a + b) - c */
long alu_expr(long a, long b, long c);

/* 算术 mul：r = a * b */
long alu_mul(long a, long b);

/* 逻辑 andi：r = x & 0xff */
long alu_low8(long x);

/* 移位：r = x << n（sll.d，n 在寄存器） */
long alu_slli(long x, long n);

/* 移位立即数代表：r = x << 1（slli.d） */
long alu_slli1(long x);
/* 条件赋值 slt：r = (a < b) ? 1 : 0 */
long alu_slt(long a, long b);

/* 位操作 ext.w.b：对低 8 位做符号扩展到字再扩展到双字 */
long alu_extb(long x);

/* 算术+临时寄存器：(x+y)+(x+y)，对照移位实现「×2」 */
long alu_sum2(long x, long y);

#endif
