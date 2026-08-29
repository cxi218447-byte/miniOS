/*
 * 第 4 次课：§3.2 访存 + 第 4 章浮点 demo 声明。
 * 实现见 lib/mem_fp.S。
 */
#ifndef MINIOS_MEM_FP_H
#define MINIOS_MEM_FP_H

/* ld.d/st.d：把 base[0..7] 的双字复制到 base[8..15] */
void mem_copy_d(long *base);

/* ld.bu/st.b：base[2] = base[0] + base[1]（按字节，无符号） */
void mem_byte_add3(unsigned char *base);

/* ld.b：有符号字节加载（0x80-0xff → 负数） */
long mem_load_byte_signed(signed char *p);

/* ld.bu：无符号字节加载（0x80-0xff → 128-255） */
long mem_load_byte_unsigned(unsigned char *p);

/* fadd.s：单精度加法 */
float fp_add_s(float a, float b);

/* fadd.d：双精度加法 */
double fp_add_d(double a, double b);

/* movfr2gr.s：取单精度浮点数的 IEEE754 位模式（符号扩展到 64 位） */
long fp_bits_s(float x);

/* movgr2fr.w + ffint.d.w：32 位整数 → 双精度浮点（数值转换） */
double fp_int_to_double(int x);

/* ftintrz.w.d + movfr2gr.s：双精度浮点 → 32 位整数（向零截断） */
long fp_double_to_int(double x);

#endif
