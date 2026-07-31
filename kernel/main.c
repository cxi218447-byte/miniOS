/*
 * 第 1 次课：Hello miniOS 输出链路。
 */

#include "printk.h"

void kernel_main(void)
{
    printk("Hello miniOS on LoongArch64\n");

    while (1) {
        __asm__ volatile("idle 0");
    }
}