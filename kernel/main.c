/*
 * 内核 C 入口。
 * 第 1 次课：Hello；第 2 次课：.data/.bss；
 * 第 3 次课：按教材第 3 章每类指令至少 1 条的验收输出；
 * 第 4 次课：精讲 §3.2 访存与第 4 章浮点的验收输出；
 * 第 5 次课：分支、循环与汇编程序设计基础的验收输出；
 * 第 6 次课：函数调用约定与栈帧的验收输出；
 * 第 8 次课：memset/memcpy/strlen 边界测试的验收输出
 *   （实现见 lib/string.S，第 2 次课已具备，本课只做边界验收）。
 */

#include "printk.h"
#include "string.h"
#include "regs_alu.h"
#include "mem_fp.h"
#include "branch_loop.h"
#include "stack_abi.h"

static char bss_buffer[16];
static char data_message[] = "data section ok";

static void print_char(char c)
{
    char s[2];
    s[0] = c;
    s[1] = '\0';
    printk(s);
}

static void print_u64_dec(unsigned long v)
{
    char buf[24];
    int i = 0;
    int j;

    if (v == 0) {
        printk("0");
        return;
    }

    while (v > 0) {
        buf[i++] = (char)('0' + (v % 10));
        v /= 10;
    }
    for (j = i - 1; j >= 0; j--) {
        char s[2];
        s[0] = buf[j];
        s[1] = '\0';
        printk(s);
    }
}

static void print_u64_hex(unsigned long v)
{
    const char *digits = "0123456789abcdef";
    char buf[20];
    int i = 0;
    int j;

    if (v == 0) {
        printk("0");
        return;
    }

    while (v > 0) {
        buf[i++] = digits[v & 0xf];
        v >>= 4;
    }
    for (j = i - 1; j >= 0; j--) {
        char s[2];
        s[0] = buf[j];
        s[1] = '\0';
        printk(s);
    }
}

static void print_i64_dec(long v)
{
    if (v < 0) {
        printk("-");
        print_u64_dec((unsigned long)(-v));
    } else {
        print_u64_dec((unsigned long)v);
    }
}

void kernel_main(void)
{
    char buf[32];
    const char *msg = "Hello miniOS on LoongArch64\n";
    long r;

    /*
     * 使能浮点单元：CSR.EUEN（0x2）的 bit0 = FPE。
     * 复位后浮点默认关闭，直接执行 fadd.s 等指令会触发“指令未使能”异常
     * （异常处理机制第 12 次课才讲，这里只做前提设置，不展开）。
     * csrwr rd, csr：把 rd 写入 CSR，并把 CSR 旧值读回 rd（此处旧值不用）。
     */
    {
        unsigned long euen = 1;
        __asm__ volatile("csrwr %0, 0x2" : "+r"(euen));
    }

    printk(msg);

    memset(buf, 0, sizeof(buf));
    memcpy(buf, data_message, strlen(data_message));
    printk(buf);
    printk("\n");

    if (bss_buffer[0] == 0) {
        printk("bss section cleared\n");
    }

    /* ---- 第 3 次课：指令分类验收（每类 ≥1 条） ---- */

    /* 算术 add/sub */
    r = alu_expr(3, 5, 2);
    printk("arith add/sub: (3+5)-2 = ");
    print_i64_dec(r);
    printk("\n");

    /* 算术 mul */
    r = alu_mul(6, 7);
    printk("arith mul: 6*7 = ");
    print_i64_dec(r);
    printk("\n");

    /* 逻辑 andi */
    r = alu_low8(0x1234);
    printk("logic andi: 0x1234 & 0xff = 0x");
    print_u64_hex((unsigned long)r);
    printk("\n");

    /* 移位 slli.d 立即数 */
    r = alu_slli1(5);
    printk("shift slli: 5<<1 = ");
    print_i64_dec(r);
    printk("\n");

    /* 条件赋值 slt */
    r = alu_slt(3, 5);
    printk("cond slt: (3<5) = ");
    print_i64_dec(r);
    printk("\n");

    /* 位操作 ext.w.b：0x7f 正数字节 */
    r = alu_extb(0x7f);
    printk("bit ext.w.b: 0x7f -> ");
    print_i64_dec(r);
    printk("\n");

    /* 临时寄存器 + 两次 add（对照移位） */
    r = alu_sum2(7, 1);
    printk("arith temp: (7+1)+(7+1) = ");
    print_i64_dec(r);
    printk("\n");

    /*
     * 访存 st.b：见 clear_bss（上方 bss section cleared）
     * 转移 bl/jr/beq：见 boot/start.S
     * 杂项 idle：本函数末尾
     * 浮点：第 4 章，本课不运行
     */
    printk("mem st.b: see clear_bss\n");
    printk("branch: see bl/jr/beq in start.S\n");
    printk("misc idle: halt loop below\n");
    printk("float: textbook ch4, not run here\n");

    printk("week03-regs-alu check done\n");

    /* ---- 第 4 次课：§3.2 访存 + 第 4 章浮点验收 ---- */
    {
        long mem_area[2] = {0x1122334455667788L, 0};
        unsigned char byte_area[3] = {40, 2, 0};
        float fs;
        double fd;
        long bits, di;

        /* ld.d/st.d：把 mem_area[0] 复制到 mem_area[1] */
        mem_copy_d(mem_area);
        printk("mem ld.d/st.d: copied 0x");
        print_u64_hex((unsigned long)mem_area[1]);
        printk("\n");

        /* ld.bu/st.b：40 + 2 写回 byte_area[2] */
        mem_byte_add3(byte_area);
        printk("mem ld.bu/st.b: 40+2 = ");
        print_i64_dec(byte_area[2]);
        printk("\n");

        /* ld.b vs ld.bu：同一个 0x80，一个变负数，一个仍是 128 */
        {
            signed char neg_byte = (signed char)0x80;
            printk("mem ld.b  (signed)   0x80 -> ");
            print_i64_dec(mem_load_byte_signed(&neg_byte));
            printk("\nmem ld.bu (unsigned) 0x80 -> ");
            print_i64_dec(mem_load_byte_unsigned((unsigned char *)&neg_byte));
            printk("\n");
        }

        /* fadd.s：1.5f + 2.5f = 4.0f，顺带看它的 IEEE754 位模式 */
        fs = fp_add_s(1.5f, 2.5f);
        bits = fp_bits_s(fs);
        printk("float fadd.s: 1.5+2.5 -> bits 0x");
        print_u64_hex((unsigned long)(bits & 0xffffffffUL));
        printk("\n");

        /* fadd.d：1.5 + 2.5 = 4.0，转回整数打印（暂无浮点转字符串） */
        fd = fp_add_d(1.5, 2.5);
        di = fp_double_to_int(fd);
        printk("float fadd.d: 1.5+2.5 -> (int)");
        print_i64_dec(di);
        printk("\n");

        /* 整数 -> 双精度 -> 整数：验证 movgr2fr.w/ffint.d.w 与 ftintrz.w.d/movfr2gr.s 是一对可逆操作 */
        di = fp_double_to_int(fp_int_to_double(7));
        printk("float int->double->int: 7 -> ");
        print_i64_dec(di);
        printk("\n");
    }

    printk("week04-load-store check done\n");

    /* ---- 第 5 次课：分支、循环与汇编程序设计基础验收 ---- */
    {
        static const unsigned char bytes[5] = {0, 3, 0, 7, 9};

        /* while 计数：beqz 判空 + addi.d 步进 + b 回跳 */
        r = bl_sum1n(5);
        printk("loop  while sum: 1+..+5 = ");
        print_i64_dec(r);
        printk("\n");

        /* if-else：beq 版 */
        r = bl_are_equal(3, 3);
        printk("branch beq  : (3==3) = ");
        print_i64_dec(r);
        printk("\n");

        /* if-else：bne 版，与上面语义相同，条件方向相反 */
        r = bl_not_equal_demo(3, 4);
        printk("branch bne  : (3==4) = ");
        print_i64_dec(r);
        printk("\n");

        /* for 风格计数循环：bnez 判非零 + beq 判越界退出 */
        r = bl_count_nonzero(bytes, 5);
        printk("loop  bnez count nonzero {0,3,0,7,9} = ");
        print_i64_dec(r);
        printk("\n");

        /* 字符串遍历骨架（第 2 次课已有 strlen，见 lib/string.S） */
        r = (long)strlen(data_message);
        printk("loop  strlen(data_message) = ");
        print_i64_dec(r);
        printk("\n");
    }

    printk("week05-branch-loop check done\n");

    /* ---- 第 6 次课：函数调用约定与栈帧验收 ---- */
    {
        /* 叶子函数：不碰 $ra */
        r = sa_add_one(41);
        printk("leaf  sa_add_one: 41+1 = ");
        print_i64_dec(r);
        printk("\n");

        /* 非叶子函数：栈帧保存/恢复 $ra，内部两次 bl sa_add */
        r = sa_add3(1, 2, 3);
        printk("frame sa_add3 (bl x2, $ra saved): 1+2+3 = ");
        print_i64_dec(r);
        printk("\n");
    }

    printk("week06-stack-abi check done\n");

    /* ---- 第 8 次课：memset/memcpy/strlen 边界测试 ---- */
    {
        char buf1[4] = { 'X', 'X', 'X', 'X' };
        char buf2[4] = { 'X', 'X', 'X', 'X' };

        /* memset n=0：契约上不得改动任何字节 */
        memset(buf1, 'Z', 0);
        printk("memset n=0 : buf[0]='");
        print_char(buf1[0]);
        printk("' (应仍为 X，未改动)\n");

        /* memset n=1：只写第 0 字节，buf[1] 不受影响 */
        memset(buf1, 'Z', 1);
        printk("memset n=1 : buf[0]='");
        print_char(buf1[0]);
        printk("' buf[1]='");
        print_char(buf1[1]);
        printk("' (应为 Z / X)\n");

        /* memcpy n=0：契约上 dst 不得改动 */
        memcpy(buf2, "AB", 0);
        printk("memcpy n=0: dst[0]='");
        print_char(buf2[0]);
        printk("' (应仍为 X，未改动)\n");

        /* memcpy n=1：只搬第 0 字节，dst[1] 不受影响 */
        memcpy(buf2, "AB", 1);
        printk("memcpy n=1: dst[0]='");
        print_char(buf2[0]);
        printk("' dst[1]='");
        print_char(buf2[1]);
        printk("' (应为 A / X)\n");

        /* strlen 边界：空串长度为 0 */
        r = (long)strlen("");
        printk("strlen \"\"  : len = ");
        print_i64_dec(r);
        printk(" (应为 0；非空串已在第 5 次课验收)\n");
    }

    printk("week08-libc-asm check done\n");

    while (1) {
        __asm__ volatile("idle 0");
    }
}
