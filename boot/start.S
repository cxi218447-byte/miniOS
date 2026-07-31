/*
 * miniOS 启动入口。
 * 第 1 次课：设栈 → 进入 kernel_main → halt。
 * 第 2 次课：在进入 C 前增加 clear_bss。
 */

    .section .text.boot, "ax"
    .globl _start

_start:
    /* 设置内核栈。栈从高地址向低地址增长。 */
    la.global   $sp, boot_stack_top

    /* 清零 .bss，保证未初始化的全局变量从 0 开始。 */
    bl          clear_bss

    /* 进入 C 语言内核主函数。 */
    bl          kernel_main

halt:
    idle        0
    b           halt

clear_bss:
    la.global   $t0, __bss_start
    la.global   $t1, __bss_end

1:
    beq         $t0, $t1, 2f
    st.b        $zero, $t0, 0
    addi.d      $t0, $t0, 1
    b           1b

2:
    jr          $ra

    .section .bss.stack, "aw", @nobits
    .align 12
boot_stack:
    .space 4096
boot_stack_top:
