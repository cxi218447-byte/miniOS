/*
 * week01-01：_start 尚未调用本函数，先保留空壳便于后续检查点衔接。
 */

#include "printk.h"

void kernel_main(void)
{
    while (1) {
        __asm__ volatile("idle 0");
    }
}