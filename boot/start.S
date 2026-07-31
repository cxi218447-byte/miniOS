/*
 * miniOS 启动入口。
 * week01-02-kernel-main-empty：正式跳进 C，但 kernel_main 还是空的。
 */

    .section .text.boot, "ax"
    .globl _start

_start:
    /* 设置内核栈。栈从高地址向低地址增长。 */
    la.global   $sp, boot_stack_top

    /* 进入 C 语言内核主函数。 */
    bl          kernel_main

halt:
    idle        0
    b           halt

    .section .bss.stack, "aw", @nobits
    .align 12
boot_stack:
    .space 4096
boot_stack_top: