from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_AUTO_SHAPE_TYPE
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "week01" / "week01_qemu_hello_course.pptx"

COLORS = {
    "ink": RGBColor(34, 37, 43),
    "muted": RGBColor(91, 99, 112),
    "bg": RGBColor(248, 249, 251),
    "line": RGBColor(216, 221, 230),
    "blue": RGBColor(28, 83, 160),
    "green": RGBColor(42, 126, 78),
    "orange": RGBColor(184, 95, 34),
    "teal": RGBColor(0, 116, 130),
    "red": RGBColor(164, 68, 64),
    "code_bg": RGBColor(32, 36, 44),
    "code_fg": RGBColor(238, 241, 246),
    "white": RGBColor(255, 255, 255),
}


def apply_font(run, size=22, bold=False, color=None, name="Microsoft YaHei"):
    run.font.name = name
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color or COLORS["ink"]


def set_speaker_notes(slide, text):
    notes = slide.notes_slide
    notes.notes_text_frame.text = text
    return slide


def set_background(slide):
    slide.background.fill.solid()
    slide.background.fill.fore_color.rgb = COLORS["bg"]


def add_text(slide, x, y, w, h, body, size=22, bold=False, color=None, align=PP_ALIGN.LEFT, font_name="Microsoft YaHei"):
    box = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = box.text_frame
    tf.clear()
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = align
    r = p.add_run()
    r.text = body
    apply_font(r, size=size, bold=bold, color=color, name=font_name)
    return box


def add_title(slide, heading, subtitle=None, lesson=None):
    if lesson:
        add_text(slide, 0.7, 0.28, 2.4, 0.3, lesson, size=13, bold=True, color=COLORS["blue"])
    add_text(slide, 0.7, 0.55, 12.0, 0.58, heading, size=30, bold=True)
    if subtitle:
        add_text(slide, 0.72, 1.14, 11.9, 0.35, subtitle, size=14, color=COLORS["muted"])
    line = slide.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.RECTANGLE, Inches(0.7), Inches(1.48), Inches(11.95), Inches(0.02))
    line.fill.solid()
    line.fill.fore_color.rgb = COLORS["line"]
    line.line.fill.background()


def add_bullet_slide(prs, heading, items, subtitle=None, lesson=None):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, heading, subtitle, lesson)
    box = slide.shapes.add_textbox(Inches(0.95), Inches(1.85), Inches(11.45), Inches(5.15))
    tf = box.text_frame
    tf.clear()
    tf.word_wrap = True
    for i, item in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(9)
        r = p.add_run()
        r.text = item
        apply_font(r, size=20 if len(item) < 34 else 17)
    return slide


def add_code_slide(prs, heading, code_text, subtitle=None, lesson=None, font_size=13):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, heading, subtitle, lesson)
    shape = slide.shapes.add_shape(
        MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
        Inches(0.82),
        Inches(1.75),
        Inches(11.72),
        Inches(5.08),
    )
    shape.fill.solid()
    shape.fill.fore_color.rgb = COLORS["code_bg"]
    shape.line.color.rgb = COLORS["code_bg"]
    tf = shape.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.margin_left = Inches(0.2)
    tf.margin_right = Inches(0.2)
    tf.margin_top = Inches(0.16)
    p = tf.paragraphs[0]
    r = p.add_run()
    r.text = code_text
    apply_font(r, size=font_size, color=COLORS["code_fg"], name="Consolas")
    return slide


def add_code_annotated_slide(prs, heading, code_text, annotations, subtitle=None, lesson=None, font_size=12):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, heading, subtitle, lesson)
    code_shape = slide.shapes.add_shape(
        MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
        Inches(0.7),
        Inches(1.75),
        Inches(6.6),
        Inches(5.08),
    )
    code_shape.fill.solid()
    code_shape.fill.fore_color.rgb = COLORS["code_bg"]
    code_shape.line.color.rgb = COLORS["code_bg"]
    tf = code_shape.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.margin_left = Inches(0.18)
    tf.margin_right = Inches(0.18)
    tf.margin_top = Inches(0.14)
    p = tf.paragraphs[0]
    r = p.add_run()
    r.text = code_text
    apply_font(r, size=font_size, color=COLORS["code_fg"], name="Consolas")

    box = slide.shapes.add_textbox(Inches(7.5), Inches(1.85), Inches(5.15), Inches(4.95))
    note_tf = box.text_frame
    note_tf.clear()
    note_tf.word_wrap = True
    for i, item in enumerate(annotations):
        para = note_tf.paragraphs[0] if i == 0 else note_tf.add_paragraph()
        para.space_after = Pt(8)
        run = para.add_run()
        run.text = item
        apply_font(run, size=14)
    return slide


def add_section_slide(prs, lesson, heading, goal):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_text(slide, 0.85, 1.1, 2.3, 0.35, lesson, size=15, bold=True, color=COLORS["blue"])
    add_text(slide, 0.85, 1.72, 11.4, 0.78, heading, size=36, bold=True)
    add_text(slide, 0.9, 2.86, 10.9, 0.95, goal, size=23, color=COLORS["muted"])
    add_text(slide, 0.9, 6.55, 11.4, 0.28, "本节结束时，学生要能用自己的话解释核心概念。", size=13, color=COLORS["muted"])
    return slide


def add_flow_slide(prs, heading, steps, subtitle=None, lesson=None):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, heading, subtitle, lesson)
    x = 0.62
    width = 2.18 if len(steps) == 5 else 2.45
    gap = 0.25
    for i, (name, body, color) in enumerate(steps):
        rect = slide.shapes.add_shape(MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE, Inches(x), Inches(2.35), Inches(width), Inches(1.75))
        rect.fill.solid()
        rect.fill.fore_color.rgb = COLORS["white"]
        rect.line.color.rgb = COLORS["line"]
        add_text(slide, x + 0.16, 2.53, width - 0.32, 0.32, name, size=16, bold=True, color=color, align=PP_ALIGN.CENTER)
        add_text(slide, x + 0.18, 2.96, width - 0.36, 0.82, body, size=13, align=PP_ALIGN.CENTER)
        x += width + gap
        if i < len(steps) - 1:
            add_text(slide, x - 0.05, 3.0, 0.25, 0.3, "→", size=20, bold=True, color=COLORS["muted"], align=PP_ALIGN.CENTER)
    return slide


def add_table_slide(prs, heading, subtitle, lesson, headers, rows, col_widths, footer):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, heading, subtitle, lesson)
    table_shape = slide.shapes.add_table(len(rows) + 1, len(headers), Inches(0.8), Inches(1.9), Inches(11.75), Inches(4.25))
    table = table_shape.table
    for idx, width in enumerate(col_widths):
        table.columns[idx].width = Inches(width)
    for col, header in enumerate(headers):
        cell = table.cell(0, col)
        cell.text = header
        cell.fill.solid()
        cell.fill.fore_color.rgb = COLORS["blue"]
        for p in cell.text_frame.paragraphs:
            for r in p.runs:
                apply_font(r, size=13, bold=True, color=COLORS["white"])
    for row_idx, row in enumerate(rows, start=1):
        for col, value in enumerate(row):
            cell = table.cell(row_idx, col)
            cell.text = value
            cell.fill.solid()
            cell.fill.fore_color.rgb = COLORS["white"]
            for p in cell.text_frame.paragraphs:
                for r in p.runs:
                    apply_font(r, size=12)
    add_text(slide, 0.82, 6.55, 11.7, 0.35, footer, size=13, color=COLORS["muted"])
    return slide


def build():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)

    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_text(slide, 0.82, 0.95, 11.8, 0.78, "第 1 周：从 0 启动一个 LoongArch miniOS", size=34, bold=True)
    add_text(slide, 0.88, 1.88, 11.5, 0.44, "4 节课导入 + QEMU Hello miniOS 实验", size=21, color=COLORS["blue"])
    add_text(slide, 0.9, 3.0, 11.5, 0.65, "对象：已系统学习 C 语言的大二计算机类学生", size=24)
    add_text(slide, 0.9, 6.42, 11.6, 0.3, "实验以本仓库 miniOS 代码与 docs/week01_qemu_hello.md 为准。", size=13, color=COLORS["muted"])

    add_bullet_slide(
        prs,
        "本周课程结构",
        [
            "课程知识：为什么学习汇编，为什么选择 LoongArch，为什么先用 QEMU。",
            "课堂 Demo：编译、反汇编、调试、QEMU 运行、结果分析。",
            "实验实践：完成最小可验证 Hello miniOS。",
            "AI 共学：第一周只体验解释和流程图，不直接生成实验代码。",
            "思考拓展：回答启动入口、栈、printf、QEMU 的核心问题。",
        ],
        "对应 AGENTS.md 的 Why / How / Do / AI / 思考结构。",
    )
    add_bullet_slide(
        prs,
        "四节课安排",
        [
            "第 1 节：为什么学习汇编，机器语言、汇编语言、C 语言是什么关系。",
            "第 2 节：LoongArch 最小知识包：寄存器、指令、寻址、分支。",
            "第 3 节：从 C 到可执行文件：预处理、编译、汇编、链接、ELF。",
            "第 4 节：读 miniOS 第 1 周代码，在 QEMU 中看到 Hello 输出。",
        ],
        "第一周不追求掌握全部指令，而是建立正确的底层执行模型。",
    )

    add_section_slide(prs, "第 1 节", "为什么学习汇编", "把学生熟悉的 C 语言，连接到 CPU 真正执行的指令。")
    add_flow_slide(
        prs,
        "从 C 代码到 CPU 执行",
        [
            ("C 语言", "变量\n函数\n循环", COLORS["green"]),
            ("汇编语言", "寄存器\n跳转\n访存", COLORS["blue"]),
            ("机器指令", "二进制编码\nCPU 取指执行", COLORS["orange"]),
            ("硬件行为", "运算\n读写内存\n访问外设", COLORS["teal"]),
        ],
        "汇编课的目标不是背指令，而是看清 C 程序如何落到机器执行。",
        "第 1 节",
    )
    add_bullet_slide(
        prs,
        "用 C 语言经验理解汇编",
        [
            "C 里的变量：很多时候会临时放在寄存器或内存里。",
            "C 里的 if / while：底层会变成比较和跳转指令。",
            "C 里的函数调用：底层涉及参数寄存器、返回地址和栈。",
            "C 里的指针：底层就是地址，访存指令按地址读写数据。",
        ],
        lesson="第 1 节",
    )
    add_bullet_slide(
        prs,
        "第一节课堂活动",
        [
            "让学生写一个最简单的 C 函数：int add(int a, int b)。",
            "提问：CPU 真的认识变量名 a 和 b 吗？",
            "提问：return a + b 最终需要哪些底层动作？",
            "结论：汇编帮助我们建立 C 语言和机器执行之间的桥。",
        ],
        lesson="第 1 节",
    )

    add_section_slide(prs, "第 2 节", "LoongArch 最小知识包", "只讲读懂第 1 周代码需要的寄存器、指令和寻址方式。")
    add_bullet_slide(
        prs,
        "第二节学习目标",
        [
            "知道 LoongArch 指令长度固定为 32 位。",
            "先认识通用寄存器编号 r0~r31，再认识 ABI 别名 zero、ra、sp、a0、t0。",
            "理解三类基础指令：算术运算、访存、转移。",
            "能读懂 boot/start.S 中的主路径。",
        ],
        lesson="第 2 节",
    )
    add_table_slide(
        prs,
        "LoongArch 通用寄存器最小表",
        "第一周先认编号和常用 ABI 别名。",
        "第 2 节",
        ["编号", "ABI 别名", "主要用途", "课堂说明"],
        [
            ("r0", "zero", "常量 0", "硬件恒为 0"),
            ("r1", "ra", "返回地址", "bl 调用函数时写入"),
            ("r3", "sp", "栈指针", "进入 C 前必须设置"),
            ("r4-r11", "a0-a7", "参数寄存器", "函数参数，前两个也可作返回值"),
            ("r12-r20", "t0-t8", "临时寄存器", "短期计算常用"),
            ("r22-r31", "fp/s0-s9", "保存寄存器", "函数调用约定后续展开"),
        ],
        [1.35, 2.1, 2.3, 5.95],
        "讲解顺序：先用 r 编号建立硬件视角，再用 ABI 别名阅读源码。",
    )
    add_code_slide(
        prs,
        "基础指令例子",
        """addi.d  r3, r3, -32       # sp = sp - 32
st.d    r1, r3, 24        # 保存 ra
ld.d    r1, r3, 24        # 恢复 ra
bne     r12, r0, L        # r12 != 0 时跳转
bl      func              # 调用函数，返回地址写入 r1/ra
jirl    r0, r1, 0         # 返回到 ra 指向的位置""",
        "先用 r 编号讲硬件动作，再映射到 ABI 别名。",
        "第 2 节",
    )
    add_code_slide(
        prs,
        "源码写法和教材写法如何对应",
        """# 教材/反汇编常见写法
addi.d  r3, r3, -32
st.d    r1, r3, 24
jirl    r0, r1, 0

# GNU 汇编器也接受 ABI 别名
addi.d  $sp, $sp, -32     # $sp 就是 r3
st.d    $ra, $sp, 24      # $ra 就是 r1
jirl    $zero, $ra, 0     # $zero 就是 r0""",
        "避免学生误以为课件、教材和源码是三套体系。",
        "第 2 节",
    )
    add_bullet_slide(
        prs,
        "第二节练习",
        [
            "先不分类：圈出指令名、寄存器和数字，猜哪一行像改栈、哪一行像跳转。",
            "把 bne r12, r0, L 解释成 C 语言里的 if 条件跳转。",
            "解释 bl 为什么会影响 r1/ra。",
            "解释为什么设置 r3/sp 后才能放心进入 C 函数。",
        ],
        lesson="第 2 节",
    )

    add_section_slide(prs, "第 3 节", "从 C 到可执行文件", "让学生知道 Makefile 背后发生了什么。")
    add_flow_slide(
        prs,
        "编译流程，用到本实验里",
        [
            (".c/.S", "源代码\nC 和汇编", COLORS["green"]),
            ("编译", "生成目标文件\n处理 include", COLORS["blue"]),
            ("链接", "合成 ELF\n确定地址入口", COLORS["orange"]),
            ("QEMU", "加载内核\n开始执行", COLORS["teal"]),
        ],
        "第 1 周只需要说出每一步的作用。",
        "第 3 节",
    )
    add_code_slide(
        prs,
        "Makefile 的核心含义",
        """CROSS_COMPILE ?= loongarch64-linux-gnu-
CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
QEMU    ?= qemu-system-loongarch64

TARGET  := build/minios.elf
LDFLAGS := -T kernel/linker.ld -nostdlib -static""",
        "不能用宿主机 x86_64 gcc 冒充 LoongArch 工具链。",
        "第 3 节",
    )
    add_code_slide(
        prs,
        "链接脚本先讲三件事",
        """ENTRY(_start)

SECTIONS
{
    . = 0x9000000000200000;

    .text : { *(.text.boot) *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}""",
        "入口是谁、从哪个地址开始、各类内容放在哪里。",
        "第 3 节",
    )
    add_bullet_slide(
        prs,
        "普通程序和裸机程序的启动差异",
        [
            "普通 Linux 程序：操作系统和 C 运行库准备运行环境。",
            "miniOS 裸机程序：没有 libc，没有操作系统帮忙调用 main。",
            "所以我们需要 _start、栈、链接脚本和串口输出。",
            "这正是第 1 周 Hello miniOS 的教学价值。",
        ],
        lesson="第 3 节",
    )

    add_section_slide(prs, "第 4 节", "QEMU Hello miniOS 实验", "把前 3 节概念落到仓库代码和真实运行命令。")
    add_bullet_slide(
        prs,
        "第 1 周核心文件",
        [
            "boot/start.S：启动入口，设置栈，跳转 kernel_main。",
            "kernel/linker.ld：规定入口地址和段布局。",
            "kernel/main.c：C 语言内核入口，调用 printk。",
            "kernel/printk.c：最小字符串输出。",
            "include/printk.h、include/uart.h：函数原型和 UART 地址。",
            "Makefile：编译、运行和清理命令。",
        ],
        lesson="第 4 节",
    )
    add_bullet_slide(
        prs,
        "当前 master 比第 1 周略多",
        [
            "boot/start.S 已包含 clear_bss，这是第 2 周 .bss 的铺垫。",
            "kernel/main.c 已包含 data/bss/string 检查，第一周只追踪 Hello 链路。",
            "lib/string.S、kernel/exception.c、kernel/syscall.c 属于后续周次铺垫。",
            "课堂第 1 周不要展开 .data/.bss、异常和系统调用细节。",
        ],
        lesson="第 4 节",
    )
    add_code_slide(
        prs,
        "boot/start.S 主路径",
        """    .section .text.boot, "ax"
    .globl _start

_start:
    # 设置内核栈，$sp 是 r3 的 ABI 别名
    la.global   $sp, boot_stack_top

    # 进入 C 语言内核主函数
    bl          kernel_main

halt:
    idle        0
    b           halt""",
        "第一周关注：_start、设置 sp、调用 kernel_main、halt 循环。",
        "第 4 节",
    )
    add_code_slide(
        prs,
        "建议第 1 周使用的最小 kernel_main",
        """#include "printk.h"

void kernel_main(void)
{
    printk("Hello miniOS on LoongArch64\\n");

    while (1) {
        __asm__ volatile("idle 0");
    }
}""",
        "当前 master 有第 2 周检查代码；课堂先抽出这条最小路径。",
        "第 4 节",
    )
    add_code_slide(
        prs,
        "printk 到 UART",
        """void uart_putc(char ch)
{
    volatile unsigned char *uart =
        (volatile unsigned char *)UART0_BASE;

    *uart = (unsigned char)ch;
}

void printk(const char *s)
{
    while (*s) {
        uart_putc(*s++);
    }
}""",
        "UART0_BASE 是 QEMU virt 平台地址，不代表 2K0300 开发板地址。",
        "第 4 节",
    )
    add_flow_slide(
        prs,
        "第 1 周最小运行链路",
        [
            ("make", "交叉编译\n生成 ELF", COLORS["blue"]),
            ("QEMU", "模拟 virt\n加载内核", COLORS["teal"]),
            ("_start", "设置 sp\n调用 C", COLORS["orange"]),
            ("kernel_main", "调用 printk\n输出字符串", COLORS["green"]),
            ("UART", "终端显示\nHello", COLORS["red"]),
        ],
        "这条链路跑通，才进入第 2 周。",
        "第 4 节",
    )
    add_code_slide(
        prs,
        "实验命令",
        """# 环境检查
sh scripts/check-env.sh

# 编译
make clean
make

# 运行
make run""",
        "实际测试结果必须来自学生机器真实命令输出。",
        "第 4 节",
    )
    add_bullet_slide(
        prs,
        "预期输出与测试记录",
        [
            "预期串口输出：Hello miniOS on LoongArch64。",
            "未执行过 make run，就不能写“已通过”。",
            "工具链缺失时，记录为“未执行”，并写明失败原因。",
            "测试报告必须包含：已执行、未执行、失败原因、下一步命令。",
        ],
        lesson="第 4 节",
    )
    add_bullet_slide(
        prs,
        "AI 共学边界",
        [
            "可以让 AI 解释 boot/start.S 的作用。",
            "可以让 AI 绘制 miniOS 启动流程图。",
            "可以让 AI 解释 QEMU 的作用。",
            "不允许让 AI 直接生成实验代码。",
        ],
        "第一周仅体验 AI 辅助理解，不能替代学生读代码和做实验。",
        "第 4 节",
    )
    add_bullet_slide(
        prs,
        "第一周学生作业",
        [
            "画出 miniOS 第 1 周执行路径图。",
            "把 Hello 字符串改成自己的姓名和学号，重新编译运行。",
            "解释 boot/start.S 中 sp、bl、b、idle 的作用。",
            "提交环境检查结果和真实运行截图或日志。",
        ],
        lesson="第 4 节",
    )
    add_bullet_slide(
        prs,
        "本周边界",
        [
            "不讲完整操作系统。",
            "不讲进程、文件系统、虚拟内存。",
            "不直接适配 2K0300 开发板。",
            "不把未实测结果写成已通过。",
            "下一周再展开 .data、.bss 和内存初始化。",
        ],
        lesson="第 4 节",
    )
    add_bullet_slide(
        prs,
        "思考题",
        [
            "CPU 第一条指令在哪里？",
            "为什么裸机程序不是从 main() 开始？",
            "为什么进入 C 函数前要设置 sp？",
            "为什么 miniOS 不能直接使用 printf？",
            "为什么先 QEMU 再开发板？",
        ],
    )

    prs.save(OUT)
    print(OUT)
    print(f"slides={len(prs.slides)}")


if __name__ == "__main__":
    build()
