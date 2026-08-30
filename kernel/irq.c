/*
 * 第 11 次课：最小定时器中断实验。
 *
 * LoongArch 的稳定定时器由三个 CSR 控制：
 *   TCFG  (0x41) 写：bit0=En 使能，bit1=Periodic 周期模式，
 *                 高位=InitVal 初值（决定倒数多久触发一次）
 *   TVAL  (0x42) 读：当前倒数值（本课不用，留给学生自行探索）
 *   TICLR (0x44) 写 1：清除定时器中断挂起标志，否则会反复重入
 *
 * 中断要真正送达 CPU，还需要两层使能（教学最小模型 §4.4）：
 *   ECFG.LIE 对应位 = 1   ——"分源开关"：允许定时器这一条中断线
 *   CRMD.IE       = 1   ——"总开关"：CPU 全局允许响应中断
 * 定时器中断在 ESTAT.IS（以及 ECFG.LIE）里固定占第 11 位。
 */
#include "irq.h"
#include "printk.h"

#define ESTAT_IS_TIMER (1UL << 11)
#define ECFG_TIMER_BIT (1UL << 11)
#define CRMD_IE_BIT    (1UL << 2)

#define TCFG_EN        (1UL << 0)
#define TCFG_PERIODIC  (1UL << 1)

static volatile unsigned long g_ticks = 0;

/* 分源开关：ECFG.LIE 第 11 位（定时器）置 1，其余位不动 */
static inline void ecfg_enable_timer_line(void)
{
    unsigned long mask = ECFG_TIMER_BIT;
    unsigned long val = ECFG_TIMER_BIT;

    __asm__ volatile("csrxchg %0, %1, 0x4" : "+r"(val) : "r"(mask) : "memory");
}

/* 总开关：CRMD.IE 置 1，其余位（PLV/DA/PG 等）不动 */
static inline void crmd_enable_ie(void)
{
    unsigned long mask = CRMD_IE_BIT;
    unsigned long val = CRMD_IE_BIT;

    __asm__ volatile("csrxchg %0, %1, 0x0" : "+r"(val) : "r"(mask) : "memory");
}

/* 分源开关关闭：ECFG.LIE 第 11 位清 0，其余位不动 */
static inline void ecfg_disable_timer_line(void)
{
    unsigned long mask = ECFG_TIMER_BIT;
    unsigned long val = 0;

    __asm__ volatile("csrxchg %0, %1, 0x4" : "+r"(val) : "r"(mask) : "memory");
}

/* 清源：写 TICLR bit0=1，应答本次定时器中断，否则会立刻再次进入 */
static inline void timer_irq_clear(void)
{
    unsigned long v = 1;

    __asm__ volatile("csrwr %0, 0x44" : "+r"(v) : : "memory");
}

void timer_init(unsigned long count)
{
    unsigned long tcfg = (count << 2) | TCFG_EN | TCFG_PERIODIC;

    __asm__ volatile("csrwr %0, 0x41" : "+r"(tcfg) : : "memory");

    ecfg_enable_timer_line();
    crmd_enable_ie();
}

void timer_stop(void)
{
    ecfg_disable_timer_line();
}

void irq_dispatch(unsigned long estat)
{
    if (estat & ESTAT_IS_TIMER) {
        timer_irq_clear();
        g_ticks++;
        printk("tick #");
        printk_udec(g_ticks);
        printk("\n");
        return;
    }

    printk("[irq] unrecognized interrupt source, ESTAT=0x");
    printk_hex(estat);
    printk("\n");
}

unsigned long irq_ticks(void)
{
    return g_ticks;
}
