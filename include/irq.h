/*
 * 第 11 次课：定时器中断实验声明。
 * 实现见 kernel/irq.c；由 kernel/exception.c 的 exception_handler
 * 在识别到 ESTAT.Ecode==0（中断类）时调用 irq_dispatch。
 */
#ifndef MINIOS_IRQ_H
#define MINIOS_IRQ_H

/* 配置并使能周期性定时器中断。
 * count 是写入 CSR.TCFG 的 InitVal（教学取值，不对应具体物理时间单位，
 * 用实测 tick 间隔估算即可）。 */
void timer_init(unsigned long count);

/* 关闭定时器中断线（清 ECFG 对应位），用于演示结束后让系统安静下来 */
void timer_stop(void);

/* 由 exception_handler 在中断类异常（Ecode==0）时调用，
 * 按 ESTAT 的 IS 位段分发到具体中断源；目前只认识定时器。 */
void irq_dispatch(unsigned long estat);

/* 当前累计的定时器 tick 数 */
unsigned long irq_ticks(void);

#endif
