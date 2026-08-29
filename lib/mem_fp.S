/*
 * 第 4 次课：按教材《汇编语言编程基础 基于 LoongArch》
 *   §3.2 访存指令 + 第 4 章浮点指令 编写的可运行 demo。
 *
 * 访存部分 → 本文件代表指令：
 *   ld.d / st.d   基址 + 偏移，双字搬运
 *   ld.bu / st.b  无符号字节搬运（字符串/字节数组常用）
 *   ld.b vs ld.bu 对比有/无符号加载的符号扩展差异
 *
 * 浮点部分 → 本文件代表指令：
 *   fadd.s / fadd.d   单/双精度加法
 *   movfr2gr.s        取浮点数的位模式（配合 IEEE754 讲解）
 *   movgr2fr.w / ffint.d.w     整数 → 双精度
 *   ftintrz.w.d / movfr2gr.s   双精度 → 整数（向零截断）
 *
 * ABI：-mabi=lp64d 下，float/double 参数与返回值走 $f0-$f7（$fa0-$fa7），
 * 与 $a0-$a7 走通用寄存器是同一套调用约定，只是"格子"不同。
 */

    .section .text

/* ==================== 访存：§3.2 ==================== */

/* ---- ld.d / st.d：基址 + 偏移，把 base+0 处的双字复制到 base+8 ---- */
    .globl mem_copy_d
mem_copy_d:
    ld.d    $t0, $a0, 0        /* t0 = mem[base+0] */
    st.d    $t0, $a0, 8        /* mem[base+8] = t0 */
    jr      $ra

/* ---- ld.bu / st.b：字节数组相加，base[2] = base[0] + base[1] ---- */
    .globl mem_byte_add3
mem_byte_add3:
    ld.bu   $t0, $a0, 0        /* t0 = base[0]（零扩展） */
    ld.bu   $t1, $a0, 1        /* t1 = base[1]（零扩展） */
    add.d   $t0, $t0, $t1
    st.b    $t0, $a0, 2        /* base[2] = t0 的低 8 位 */
    jr      $ra

/* ---- ld.b：有符号字节加载，0x80-0xff 会被符号扩展成很大的负数 ---- */
    .globl mem_load_byte_signed
mem_load_byte_signed:
    ld.b    $a0, $a0, 0
    jr      $ra

/* ---- ld.bu：无符号字节加载，同样的位模式只会得到 0-255 ---- */
    .globl mem_load_byte_unsigned
mem_load_byte_unsigned:
    ld.bu   $a0, $a0, 0
    jr      $ra

/* ==================== 浮点：第 4 章 ==================== */

/* ---- fadd.s：单精度加法（参数/返回值在 $fa0/$fa1，即 $f0/$f1） ---- */
    .globl fp_add_s
fp_add_s:
    fadd.s  $fa0, $fa0, $fa1
    jr      $ra

/* ---- fadd.d：双精度加法 ---- */
    .globl fp_add_d
fp_add_d:
    fadd.d  $fa0, $fa0, $fa1
    jr      $ra

/* ---- 取浮点数的 IEEE754 位模式：movfr2gr.s（低 32 位，符号扩展到 64 位） ---- */
    .globl fp_bits_s
fp_bits_s:
    movfr2gr.s  $a0, $fa0
    jr          $ra

/* ---- 整数 → 双精度：movgr2fr.w 搬位模式，ffint.d.w 做数值转换 ---- */
    .globl fp_int_to_double
fp_int_to_double:
    movgr2fr.w  $fa0, $a0      /* 只是把 32 位位模式搬进浮点寄存器，还不是数值转换 */
    ffint.d.w   $fa0, $fa0     /* 按数值语义：32 位整数 → 双精度浮点 */
    jr          $ra

/* ---- 双精度 → 整数：ftintrz.w.d 向零截断，movfr2gr.s 取出结果 ---- */
    .globl fp_double_to_int
fp_double_to_int:
    ftintrz.w.d $fa0, $fa0     /* 向零截断成 32 位整数，结果仍在浮点寄存器里 */
    movfr2gr.s  $a0, $fa0      /* 取出到通用寄存器（movfr2gr 按 FPR 侧宽度取后缀：.s=32位/.d=64位） */
    jr          $ra
