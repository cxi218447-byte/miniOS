# 第 1 次课讲义：从 0 启动一个 LoongArch miniOS

## 1. 本次课课程定位

本次课是《LoongArch 汇编语言》课程的入口周，按**2 节课课次**组织。学生刚系统学习过 C 语言，通常已经熟悉变量、函数、循环、指针这些概念，但还没有真正建立"CPU 到底在执行什么"的底层模型，也普遍没有操作系统原理和 Makefile 的背景知识。

本次课不追求讲完整操作系统，也不追求掌握大量 LoongArch 指令。核心任务只有一个：让学生亲眼看到一个 LoongArch 裸机程序从启动汇编进入 C 函数，并通过 UART 在 QEMU 终端输出：

```text
Hello miniOS on LoongArch64
```

本次课课程链路：

```text
CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS
```

教师讲课时要反复强调：这不是 Linux 应用程序，不是普通 C 程序，也不是完整操作系统。它是一个最小裸机内核实验，用来回答"没有操作系统时，C 程序如何开始运行"。

原本按四节课分别展开的内容（为什么学习汇编 / LoongArch 最小知识包 / 从 C 到可执行文件 / QEMU Hello miniOS 实验）现在压缩进一次课，按"板块一到板块四 + 收尾"五个板块组织，配合 `docs/week01/week01_qemu_hello_course.pptx` 里对应的 21 张幻灯片使用。

## 2. 教学目标

本次课结束后，学生应能做到：

1. 说清楚为什么学习汇编，以及汇编和 C 语言、机器指令之间的关系。
2. 认识 LoongArch64 最基本的寄存器编号和常用 ABI 别名。
3. 说出操作系统平时为普通 C 程序做了哪些事情，理解裸机程序为什么不一样。
4. 看懂最小 Makefile 的目标/依赖/命令语法，并能对应到本项目 Makefile。
5. 看懂 `boot/start.S` 的主路径：设置栈、调用 `kernel_main()`、进入停机循环。
6. 完整讲出从 QEMU 加载内核到终端显示 Hello 的每一步。
7. 解释为什么裸机程序不能直接从 `main()` 开始，为什么进入 C 函数前必须设置 `$sp`，为什么 `printk()` 可以替代早期裸机环境里的 `printf()`。
8. 能按要求执行环境检查、编译、QEMU 运行，并记录真实测试结果。

本次课的教学评价重点不是"学生记住多少指令"，而是"学生是否建立了正确的启动链路"。

## 3. 课前准备

教师课前应准备：

- 第一周 PPT：`docs/week01/week01_qemu_hello_course.pptx`（21 张，按板块一到板块四 + 收尾组织）
- 第一周实验文档：`docs/week01/qemu_hello.md`
- 当前工程源码：`boot/start.S`、`kernel/main.c`、`kernel/printk.c`、`include/uart.h`、`Makefile`
- 环境检查文档：`docs/environment_check.md`

课堂演示环境建议使用 WSL Ubuntu 或 Linux 主机。需要工具：

```bash
make
qemu-system-loongarch64
loongarch64-linux-gnu-gcc
loongarch64-linux-gnu-objcopy
gdb-multiarch
```

如果现场机器缺少工具链，不要临时编造运行结果。应把状态明确记录为"未执行"或"失败"，并说明下一步安装命令。课程规范要求未经当前机器或课堂环境实测，不得写"已测试通过"。

## 4. 板块一：为什么学习汇编（12 分钟）

### 4.1 导入问题

可以从一个学生熟悉的 C 函数开始：

```c
int add(int a, int b)
{
    return a + b;
}
```

教师提问：

1. CPU 真的认识变量名 `a` 和 `b` 吗？
2. `return a + b` 在 CPU 看来是什么动作？
3. 函数调用时，参数放在哪里？
4. 函数返回后，CPU 怎么知道回到哪里继续执行？

引导学生得出结论：C 语言是给人和编译器看的高层表达，CPU 最终执行的是机器指令。汇编语言是介于 C 语言和机器指令之间的可读表示。这组问题本身就是本板块唯一的课堂互动，不再单独安排一张"课堂活动"幻灯片。

### 4.2 三层关系

可以板书：

```text
C 语言
  ↓ 编译
汇编语言
  ↓ 汇编
机器指令
  ↓ 取指执行
CPU 硬件行为
```

讲解口径：

- C 语言里的变量，底层可能在寄存器里，也可能在内存里。
- C 语言里的 `if` 和 `while`，底层会变成比较和跳转。
- C 语言里的函数调用，底层需要参数寄存器、返回地址和栈。
- C 语言里的指针，本质就是地址，底层通过访存指令读写。

本节不要急着讲复杂指令。目标是让学生意识到：学习汇编不是为了手写所有程序，而是为了看懂 C 程序如何落到 CPU 执行。

## 5. 板块二：LoongArch 最小知识包（13 分钟）

### 5.1 本节边界

本节只讲读懂第一周代码所需的最小知识：通用寄存器编号、常用 ABI 别名、少量算术/访存/跳转指令。不要求完整背诵 ABI 保存规则，也不深入异址、中断、页表、缓存一致性。

### 5.2 寄存器讲解顺序

建议先讲硬件编号，再讲 ABI 别名：

| 编号 | ABI 别名 | 第一周用途 |
|---|---|---|
| `r0` | `zero` | 常量 0 |
| `r1` | `ra` | 函数返回地址 |
| `r3` | `sp` | 栈指针 |
| `r4-r11` | `a0-a7` | 参数寄存器 |
| `r12-r20` | `t0-t8` | 临时寄存器 |

讲解重点：`$sp` 就是 `r3` 的 ABI 别名，`$ra` 就是 `r1` 的 ABI 别名。源码里常用 `$sp`、`$ra`，反汇编或教材里可能出现 `r3`、`r1`，学生不要把两套名字误以为两套寄存器。

### 5.3 第一周常见指令

```asm
addi.d  r3, r3, -32       # sp = sp - 32
st.d    r1, r3, 24        # 保存返回地址
ld.d    r1, r3, 24        # 恢复返回地址
bne     r12, r0, L        # r12 != 0 时跳转
bl      func              # 调用函数，返回地址写入 r1/ra
jirl    r0, r1, 0         # 跳回 ra 指向的位置
```

第一周只要学生能说出：哪些是算术运算、哪些是访存、哪些是跳转；`bl` 会改变返回地址寄存器；`sp` 必须指向一块可用栈空间。同一张幻灯片的副标题里已经带出 `$sp`/`r3` 这类别名等价关系，不再单列一张"源码写法和教材写法如何对应"。

## 6. 板块三：从 C 到可执行文件（25 分钟）

### 6.1 为什么要讲编译流程

学生平时可能只知道"点运行"或"gcc main.c"。miniOS 是裸机程序，必须让学生知道 Makefile 背后发生了什么。

板书：

```text
.c/.S 源代码
   ↓ 编译/汇编
.o 目标文件
   ↓ 链接
.elf 内核镜像
   ↓ QEMU 加载
CPU 从入口地址开始执行
```

### 6.2 Makefile 语法速览（新增内容）

多数学生没写过 Makefile，直接看项目 Makefile 会不知道 `:=`、`?=`、依赖关系是什么意思。先用一个和本项目无关的最小示例讲清楚三段式语法：

```make
目标: 依赖1 依赖2
	命令              # 命令前必须是 Tab，不能是空格

hello.o: hello.c
	gcc -c hello.c -o hello.o

CC := gcc            # := 立即展开赋值
CFLAGS ?= -Wall       # ?= 只在变量还没被设置时才赋值

.PHONY: clean         # 声明伪目标，clean 不是一个真实文件
clean:
	rm -f *.o
```

讲解要点：

- `目标: 依赖` 这一行说明"要生成什么，需要先有什么"；命令行必须以 Tab 开头，用空格缩进会报错，这是新手最常踩的坑。
- `:=` 是变量定义时就展开赋值，`?=` 是"如果这个变量还没被设置才赋值"——项目 Makefile 里 `CROSS_COMPILE ?= loongarch64-linux-gnu-` 就是为了让用户可以在命令行覆盖它。
- `.PHONY` 声明的目标不对应真实文件，`make clean` 每次都会执行，不会因为已经有一个叫 `clean` 的文件而被跳过。

### 6.3 Makefile 关键点（本项目）

有了语法基础后，再讲项目里的具体变量：

```make
CROSS_COMPILE ?= loongarch64-linux-gnu-
CC      := $(CROSS_COMPILE)gcc
OBJCOPY := $(CROSS_COMPILE)objcopy
QEMU    ?= qemu-system-loongarch64

TARGET  := build/minios.elf
LDFLAGS := -T kernel/linker.ld -nostdlib -static
```

强调三点：

1. 不能用宿主机 x86_64 GCC 冒充 LoongArch 工具链。
2. `-nostdlib` 表示不链接普通 C 运行库。
3. `kernel/linker.ld` 决定入口和内存布局。

### 6.4 链接脚本讲三件事

第一周讲链接脚本只讲三件事：入口是谁（`ENTRY(_start)`）、从哪个地址开始放内核、`.text`/`.rodata`/`.data`/`.bss` 大概放在哪里。

```ld
ENTRY(_start)

SECTIONS
{
    . = 0x9000000000200000;

    .text : { *(.text.boot) *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) *(COMMON) }
}
```

此时不要深入 LMA/VMA、重定位、段权限。只需要学生理解：没有链接脚本，裸机程序不知道从哪里开始，也不知道代码和数据如何安排。

### 6.5 操作系统平时帮你做了什么（新增内容）

学生写惯了"点 run 就能跑"的普通 C 程序，很少想过这背后是操作系统在做事。这一段是理解"裸机为什么不一样"的关键铺垫：

- 帮你把程序加载到内存、分配好栈和堆，你的 C 代码打开就能跑。
- 帮你管理多个程序同时运行（进程调度），你不用关心 CPU 什么时候轮到你。
- 帮你把 `printf`、`malloc` 这些函数背后的系统调用接好，你才能直接调用。
- 帮你管理磁盘文件、网络、显示器这些硬件，你只需要调用统一的接口。

一句话收束：普通 C 程序能"写完就跑"，全靠操作系统在背后先把环境搭好。

### 6.6 普通程序和裸机程序的启动差异

- 普通 Linux 程序：操作系统和 C 运行库准备运行环境。
- miniOS 裸机程序：没有 libc，没有操作系统帮忙调用 `main`。
- 所以我们需要 `_start`、栈、链接脚本和串口输出——这些正是操作系统平时替我们做好、而裸机程序必须自己搭建的部分。
- 这正是第 1 次课 Hello miniOS 的教学价值。

## 7. 板块四：QEMU Hello miniOS 实验（30 分钟）

### 7.1 本节核心目标

本节要把前面概念落到真实工程：

```text
make
  ↓
build/minios.elf
  ↓
QEMU virt
  ↓
_start
  ↓
kernel_main()
  ↓
printk()
  ↓
UART
  ↓
Hello miniOS on LoongArch64
```

教师要提醒：当前 `master` 已包含第 2 次课的 `.data/.bss` 检查代码。第一周课堂只看 Hello 链路，后续输出和 `clear_bss` 标注为"下一周内容"，具体说明放在收尾的"本次课边界"里，不在这里展开。

### 7.2 关键文件讲解顺序

建议按这个顺序打开文件：`Makefile` → `kernel/linker.ld` → `boot/start.S` → `kernel/main.c` → `kernel/printk.c` → `include/uart.h`。不要从 `kernel/exception.c` 或 `kernel/syscall.c` 开始，那些文件会让学生误以为第一周就要理解异常和系统调用。

### 7.3 boot/start.S 主路径逐行讲解

配合 PPT 里的注解版幻灯片，逐行讲解真实项目代码（不是虚构示例）：

```asm
    .section .text.boot, "ax"
    .globl _start

_start:
    la.global   $sp, boot_stack_top
    bl          kernel_main

halt:
    idle        0
    b           halt
```

逐行讲解：

1. `.section .text.boot, "ax"` 把这段代码放到链接脚本指定的启动区域，保证它在最前面。
2. `.globl _start` 让链接器能找到这个入口符号，对应链接脚本里的 `ENTRY(_start)`。
3. `la.global $sp, boot_stack_top`：CPU 上电后 `$sp` 是垃圾值，必须先指向预留的栈顶。
4. `bl kernel_main`：调用 C 函数，同时把返回地址写入 `$ra`——但 `kernel_main` 不会返回。
5. `halt` 循环：防止 `kernel_main` 意外返回后，CPU 从未知内存继续取指执行。

如果学生问当前源码里为什么有 `clear_bss`，回答：这是第 2 次课要讲的 `.bss` 初始化，第一周先知道它发生在进入 C 之前，细节下一周展开。

### 7.4 kernel_main 最小路径

第一周建议抽象成：

```c
#include "printk.h"

void kernel_main(void)
{
    printk("Hello miniOS on LoongArch64\n");

    while (1) {
        __asm__ volatile("idle 0");
    }
}
```

讲解：`kernel_main()` 是我们自己的 C 入口，不是标准 C 程序里的 `main()`；裸机没有操作系统帮忙调用它，是启动汇编通过 `bl kernel_main` 调用的；`while (1)` 保证内核不会返回到一个不存在的调用者环境。

### 7.5 printk 到 UART

```c
void uart_putc(char ch)
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
}
```

讲解口径：`UART0_BASE` 是 QEMU `virt` 平台的串口 MMIO 地址；`volatile` 告诉编译器这个地址对应外设，不能随意优化掉访问；`*uart = ch` 看起来像写内存，实际上是在向串口发送寄存器写字节；QEMU 把这个串口输出映射到终端，所以我们能看到 Hello。强调：这个 UART 地址不代表龙芯 2K0300 开发板真实地址，开发板适配要查板卡手册或设备树，不能猜。

### 7.6 裸机启动逐步说明（新增内容）

配合 PPT 里的"第 1 次课最小运行链路"流程图，给出文字版逐步说明，帮学生把流程图里的 5 个节点拆成更细的 8 步：

1. QEMU 把 `build/minios.elf` 加载进虚拟内存，按 ELF 头找到入口地址。
2. CPU 从入口地址（`_start`）取出第一条指令开始执行，此时还没有任何 C 环境。
3. `_start` 把 `$sp` 指向预留的栈空间——没有这一步，C 函数完全不能用。
4. `bl kernel_main` 跳转进 C 代码，从这里开始才是我们熟悉的 C 语言世界。
5. `kernel_main` 调用 `printk`，`printk` 逐字符调用 `uart_putc`。
6. `uart_putc` 直接向 `UART0_BASE` 这个内存地址写字节——这不是普通内存，是外设寄存器。
7. QEMU 把这次写操作翻译成终端输出，我们才看到 Hello miniOS。
8. `kernel_main` 结束后代码进入 `halt` 死循环，因为裸机没有"返回到操作系统"这回事。

### 7.7 课堂 Demo 脚本

**环境检查**：

```bash
sh scripts/check-env.sh
```

如果 `make` 缺失，说明构建工具未安装；如果 `qemu-system-loongarch64` 缺失，说明无法运行 LoongArch QEMU；如果 `loongarch64-linux-gnu-gcc` 缺失，说明无法交叉编译 LoongArch 目标文件。

**编译**：

```bash
make clean
make
```

观察点：`build/` 目录被重新生成，`.c` 和 `.S` 文件被编译为 `.o`，链接后生成 `build/minios.elf`，`objcopy` 生成 `build/minios.bin`。

**运行**：

```bash
make run
```

第一周最小预期输出：

```text
Hello miniOS on LoongArch64
```

如果当前 master 同时输出第 2 次课检查内容（`data section ok` / `bss section cleared` / `week1-week2 check done`），说明这些是第 2 次课内容，第一周课堂只验收 Hello 链路。未执行过 `make run`，就不能写"已通过"；工具链缺失时记录为"未执行"，并写明失败原因；测试报告必须包含：已执行、未执行、失败原因、下一步命令。

**反汇编观察**（如果 Makefile 支持 `make disasm`，否则用命令思路说明）：

```bash
loongarch64-linux-gnu-objdump -d build/minios.elf
```

观察重点：`_start` 是否位于入口附近，是否能看到设置栈的指令，是否能看到调用 `kernel_main` 的分支调用指令。

**GDB 单步**（如果课堂环境支持）：

```bash
make debug
gdb-multiarch build/minios.elf
(gdb) target remote :1234
(gdb) b _start
(gdb) b kernel_main
(gdb) c
```

讲解目标不是让学生掌握所有 GDB 命令，而是让学生看到 CPU 的执行路径确实从 `_start` 进入 `kernel_main()`。

## 8. 收尾：本次课边界、思考题与作业（10 分钟）

### 8.1 本次课边界

- 不讲完整操作系统，不讲进程、文件系统、虚拟内存。
- 不直接适配 2K0300 开发板。
- 不把未实测结果写成已通过——工具链缺失就记录"未执行"。
- 当前 master 已包含第 2 次课 `.data/.bss` 检查代码和 `clear_bss`，第 1 次课课堂只讲 Hello 链路，这部分下周展开。
- `lib/string.S`、`kernel/exception.c`、`kernel/syscall.c` 属于后续课次铺垫，本次课不展开。
- AI 共学：可以让 AI 解释 `boot/start.S` 的作用、绘制 miniOS 启动流程图、解释 QEMU 的作用、分析环境检查失败原因；不允许让 AI 直接生成实验代码、代替学生完成实验报告、根据代码推断运行结果并写成"已测试通过"、编造 2K0300 UART 地址或板级细节。

建议课堂话术：

> 第一周我们用 AI 做"解释器"和"陪读者"，不把 AI 当"代写者"。你可以问它为什么要设置栈、为什么不能 printf、QEMU 做了什么，但不能让它直接替你写实验代码。

### 8.2 思考题与作业

思考题：

1. CPU 第一条指令在哪里？
2. 为什么裸机程序不是从 `main()` 开始？
3. 为什么进入 C 函数前要设置 `$sp`？
4. 为什么 miniOS 不能直接使用 `printf`？
5. 为什么先 QEMU 再开发板？

作业：

- 画出 miniOS 第 1 次课执行路径图。
- 把 Hello 字符串改成自己的姓名和学号，重新编译运行，记录真实输出，不能根据文档预期输出伪造结果。
- 解释 `boot/start.S` 中 `sp`、`bl`、`b`、`idle` 的作用。
- 提交环境检查结果和真实运行截图或日志。

## 9. 常见问题与讲解口径

### 9.1 为什么不是 main()？

普通 C 程序的 `main()` 是被 C 运行库调用的。裸机 miniOS 没有 C 运行库，也没有操作系统加载用户程序，所以 CPU 只能从链接脚本指定的入口 `_start` 开始。本课程里是 `_start` 主动调用 `kernel_main()`。

### 9.2 为什么要设置栈？

C 函数调用需要栈来保存返回地址、局部变量、临时数据和调用现场。即使当前 `kernel_main()` 很简单，也不能假设 C 代码完全不用栈。进入 C 前设置 `$sp` 是裸机启动代码的基本责任。

### 9.3 为什么不能直接 printf？

`printf()` 属于 C 标准库，依赖运行库、系统调用、文件描述符和操作系统输出机制。miniOS 早期没有这些东西，因此先实现最小 `printk()`，直接通过 UART 输出字符。

### 9.4 QEMU 是什么作用？

QEMU 模拟 LoongArch64 `virt` 平台，让学生可以在 PC 上运行 LoongArch 裸机程序。先用 QEMU 的原因：环境可复制，不依赖真实开发板数量，便于 GDB 调试，出问题时更容易定位是代码问题还是硬件连接问题。

### 9.5 为什么先 QEMU 再开发板？

如果一开始直接上开发板，学生会同时遇到串口线、固件、加载地址、板级 UART 地址、供电、烧录等问题，容易掩盖本次课真正要学的启动链路。先在 QEMU 跑通，是为了建立可回归的教学基线。

### 9.6 当前 master 为什么有第 2 次课内容？

当前工程已经包含第 2 次课的 `.data/.bss` 检查代码。第一周课堂只取最小主线：`_start -> kernel_main() -> printk() -> UART`。其他输出可以暂时说明为下一周内容，不作为第一周展开重点。

## 10. 板书建议

### 10.1 主板书

```text
C 语言           汇编语言             CPU
变量/函数/循环 -> 寄存器/跳转/访存 -> 取指执行
```

### 10.2 启动路径

```text
ENTRY(_start)
    ↓
boot/start.S
    ↓ 设置 sp
kernel_main()
    ↓
printk()
    ↓
uart_putc()
    ↓
UART0_BASE
    ↓
QEMU 终端
```

### 10.3 第一周三问

```text
1. 第一条指令在哪里？
2. 为什么不是 main？
3. 为什么不能 printf？
```

## 11. 思考题参考答案

### 11.1 CPU 第一条指令在哪里？

在本实验中，内核入口由链接脚本 `ENTRY(_start)` 指定，入口符号 `_start` 定义在 `boot/start.S` 中。QEMU 加载内核镜像后，从这个入口开始执行。

### 11.2 为什么裸机程序不是从 main() 开始？

`main()` 是普通 C 程序约定的入口，但它通常由 C 运行库在操作系统环境中调用。miniOS 是裸机程序，没有 C 运行库帮忙准备栈、初始化环境并调用 `main()`，所以必须由启动汇编 `_start` 先运行，再进入 C 函数。

### 11.3 为什么进入 C 函数前要设置 `$sp`？

C 函数调用通常依赖栈保存调用现场、返回地址、局部变量和临时数据。如果 `$sp` 没有指向有效内存，C 函数一旦使用栈就可能破坏内存或直接崩溃。

### 11.4 为什么 miniOS 不能直接使用 `printf()`？

`printf()` 依赖 C 标准库和操作系统输出抽象。miniOS 早期还没有标准库、系统调用和文件系统，所以先用 `printk()` 直接操作 UART 完成最小输出。

### 11.5 为什么先 QEMU 再开发板？

QEMU 提供稳定、可复现、易调试的 LoongArch64 实验环境。先在 QEMU 中跑通可以排除大量硬件连接和板级差异问题，再迁移到龙芯 2K0300 时就有明确的回归基线。

## 12. 本次课收束

本次课只要求学生建立一条清晰链路：

```text
CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS
```

只要学生能解释这条链路、说出操作系统平时做了什么、看懂最小 Makefile 语法，并能在真实环境中记录编译、运行和输出结果，就达到了第一周目标。

下一周再展开：`.data` 中已初始化全局变量如何可读、`.bss` 为什么要清零、`clear_bss` 如何工作、C 代码如何调用汇编实现的 `memset`、`memcpy`、`strlen`。
