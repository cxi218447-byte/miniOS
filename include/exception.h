/*
 * 第 10 次课：异常入口与异常上下文声明。
 * exception_entry 实现见 boot/start.S；exception_init/handler 见 kernel/exception.c。
 */
#ifndef MINIOS_EXCEPTION_H
#define MINIOS_EXCEPTION_H

/* 异常入口地址，由 exception_init 写入 CSR.EENTRY(0xc)，不由 C 直接调用 */
void exception_entry(void);

void exception_init(void);

/* 返回值是"下一次该从哪里继续执行"的新 ERA，由 exception_entry 写回 CSR.ERA */
unsigned long exception_handler(unsigned long estat, unsigned long era);

#endif
