/*
 * miniOS 启动入口。
 * 第 1 次课：设栈 → 进入 kernel_main → halt。
 * 第 2 次课：在进入 C 前增加 clear_bss。
 * 第 10 次课：新增 exception_entry，供 exception_init 写入 CSR.EENTRY。
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

/*
 * ---- 第 10 次课：异常入口 ----
 * 硬件在异常发生时直接跳到 CSR.EENTRY 记录的地址（这里），
 * 而不是走 bl/jr $ra 的普通调用路径，所以现场要自己主动保存。
 * 返回用 ertn（把 PC 恢复为 ERA），不是 jr $ra。
 */
    .globl exception_entry
exception_entry:
    addi.d      $sp, $sp, -32
    st.d        $ra, $sp, 24        /* 先存 $ra：下面 bl 会覆盖它 */

    csrrd       $a0, 0x5            /* ESTAT：异常状态/原因 */
    csrrd       $a1, 0x6            /* ERA：异常返回地址 */
    bl          exception_handler   /* 返回值 $a0 = 处理函数给出的新 ERA */

    csrwr       $a0, 0x6            /* 写回 ERA：break/syscall 这类精确异常
                                       ERA 指向触发指令本身，不写回会在原地死循环 */
    ld.d        $ra, $sp, 24
    addi.d      $sp, $sp, 32
    ertn                            /* 异常返回：PC <- ERA，而不是 jr $ra */

    .section .bss.stack, "aw", @nobits
    .align 12
boot_stack:
    .space 4096
boot_stack_top:
