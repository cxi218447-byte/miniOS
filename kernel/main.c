/*
 * week01-02-kernel-main-empty：_start 已调用这里，但还没有输出。
 */

#include "printk.h"

void kernel_main(void)
{
    while (1) {
        __asm__ volatile("idle 0");
    }
}