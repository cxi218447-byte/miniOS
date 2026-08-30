/*
 * 第 10 次课：异常入口初始化与最小处理函数。
 * 先能"看见"异常（打印 ESTAT/ERA），再谈恢复、分类处理等策略。
 * 第 11 次课：LoongArch 的中断也是通过同一个 EENTRY 入口送达的——
 * ESTAT.Ecode（bit[21:16]）为 0 时表示"中断类"（INT），此时分发给
 * irq_dispatch；非 0 则是同步异常，按第 10 次课的方式打印并跳过。
 */
#include "exception.h"
#include "printk.h"
#include "irq.h"

#define ESTAT_ECODE_MASK 0x3fUL
#define ESTAT_ECODE_SHIFT 16

void exception_init(void)
{
    unsigned long entry = (unsigned long)exception_entry;

    /* CSR 0xc：EENTRY。不设置则异常到来时"无处可去"。 */
    __asm__ volatile("csrwr %0, 0xc" : : "r"(entry) : "memory");
}

unsigned long exception_handler(unsigned long estat, unsigned long era)
{
    unsigned long ecode = (estat >> ESTAT_ECODE_SHIFT) & ESTAT_ECODE_MASK;

    if (ecode == 0) {
        /*
         * 中断类：ERA 硬件已经给出正确的续跑点（中断可能打在任意一条
         * 指令中间，不存在"触发指令本身"这个概念），原样返回，不加 4。
         */
        irq_dispatch(estat);
        return era;
    }

    printk("[exception] ESTAT=0x");
    printk_hex(estat);
    printk(" ERA=0x");
    printk_hex(era);
    printk("\n");

    /*
     * break/syscall 是软件主动触发的"精确异常"：ERA 指向触发指令本身，
     * 不是它的下一条。教学简化：统一把 ERA 前进 4 字节（一条指令宽度），
     * 交给 exception_entry 写回 CSR.ERA，否则 ertn 后会在原地再次触发
     * 同一异常，形成死循环。真实 OS 会按异常类型（PIL/PIS/ALE/... 需要
     * 重新执行 vs BRK/SYS 需要跳过）精细处理，这里只讲最小闭环。
     */
    return era + 4;
}
