#include "exception.h"
#include "printk.h"

extern void exception_entry(void);

void exception_init(void)
{
    unsigned long entry = (unsigned long)exception_entry;

    /*
     * EENTRY(CSR 0x0c) 保存异常入口地址。
     * 第 5 次课实验可以打开真实异常触发代码观察输出。
     */
    __asm__ volatile("csrwr %0, 0xc" : : "r"(entry) : "memory");
}

void exception_handler(unsigned long estat, unsigned long era)
{
    printk("[exception] ESTAT=");
    printk_hex(estat);
    printk(" ERA=");
    printk_hex(era);
    printk("\n");
}
