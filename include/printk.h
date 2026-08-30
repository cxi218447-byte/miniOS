#ifndef MINIOS_PRINTK_H
#define MINIOS_PRINTK_H

void printk(const char *s);

/* 第 10 次课起：打印一个无符号数的十六进制形式（无前导 0x，无前导零），
 * 供 exception_handler 打印 ESTAT/ERA 使用。 */
void printk_hex(unsigned long v);

/* 第 11 次课起：打印一个无符号数的十进制形式，供 irq_dispatch 打印 tick 计数使用。 */
void printk_udec(unsigned long v);

#endif
