/*
 * week01-00-skeleton：_start 还没有调用这个函数，这里先留一个空壳。
 */

#include "printk.h"

void kernel_main(void)
{
    while (1) {
        __asm__ volatile("idle 0");
    }
}