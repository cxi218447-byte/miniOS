# 第 2 次课讲义：.data/.bss 初始化与 C/汇编混合启动

> 技术编号：02　|　检查点 tag：02-data-bss
> **本课主题固定**（.data/.bss 与混合启动）。从第 3 次课起再系统回填寄存器与基础指令。

## 1. 本次课课程定位

本次课是《LoongArch 汇编语言》第 2 次课，按**2 节课课次**组织。第 1 次课学生已经看到 miniOS 从 `_start` 进入 `kernel_main()`，通过 UART 输出 `Hello miniOS on LoongArch64`。

第 1 次课回答的问题是"CPU 如何进入 C 函数并输出字符"。本次课继续追问一个更接近真实 C 程序的问题：

> 在没有操作系统和 C 运行库的裸机环境中，全局变量的初始状态由谁准备？`.data` 和 `.bss` 分别意味着什么？

本次课在第 1 次课 Hello 链路之上，增加 `.bss` 清零与 C/汇编混合调用观察，形成完整验收输出：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

本次课不追求完整讲清链接、加载、运行时全部细节，而是通过 `.data` 和 `.bss` 两类全局变量建立一个核心认知：**普通 C 程序中由操作系统和 C 运行库完成的准备工作，在 miniOS 中必须由启动代码自己完成。**

本次课核心路径：

```text
_start → 设置 $sp → clear_bss → kernel_main()
```

教师讲课时要反复强调：裸机 C 程序不是"天然能正确运行"，启动汇编必须先准备 C 代码需要的最小运行环境——设栈、清零 `.bss`，然后才能进入 C。

## 2. 教学目标

本次课结束后，学生应能做到：

1. 区分 `.text`、`.rodata`、`.data`、`.bss` 的基本含义，说出各自存放什么内容。
2. 说明 `data_message`（有初始值）与 `bss_buffer`（无显式初始值）分别对应哪一类全局变量、落在哪个段。
3. 解释为什么 `.bss` 必须在进入 C 代码前清零，以及谁来做这件事。
4. 理解 `__bss_start` 和 `__bss_end` 由链接脚本提供，是地址边界而非 C 变量。
5. 沿着 `boot/start.S` 找到 `clear_bss`，能逐行解释其执行流程。
6. 沿着 `kernel/main.c` 找到 `.data/.bss` 的验证代码，能解释每行输出的含义。
7. 理解 C 代码通过"声明在 `.h`、实现在 `.S`、一起链接"的方式调用汇编函数。
8. 能独立完成环境检查、编译、运行，记录真实输出，区分"预期输出"和"实测输出"。

本次课教学评价的重点不是"学生背诵完整 ABI"，而是"学生是否理解了裸机程序必须自己准备数据段初始状态"。

## 3. 课前准备

教师课前应准备：

- 本次课实验文档：`docs/02/data_bss.md`
- 本次课教案：`docs/02/lesson_plan.md`
- 当前工程源码重点文件：
  - `kernel/main.c` —— `.data/.bss` 验证逻辑
  - `boot/start.S` —— `clear_bss` 实现
  - `kernel/linker.ld` —— `__bss_start` / `__bss_end`
  - `lib/string.S` —— `memset` / `memcpy` / `strlen`
  - `include/string.h` —— 上述函数的 C 声明
  - `Makefile` —— 确认 `lib/string.S` 在 `SRCS_S` 中

课堂演示环境建议使用 WSL Ubuntu 或 Linux 主机。课前确认：

```bash
git fetch --tags
sh scripts/check-env.sh   # 在切 tag 之前跑：02-data-bss 等课次 tag 里没有 scripts/ 目录
git switch -c demo-02 02-data-bss
make clean
make
make run
```

预期输出：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

若当前课堂机器没有工具链或 QEMU，不要临时编造运行结果。应把状态明确记录为"未执行"或"失败"，并说明下一步安装命令。

学生建议起点：

```bash
git fetch --tags
git switch -c my-02-lab 02-data-bss
```

## 4. 板块一：复盘第 1 次课，引入新问题（20 分钟）

### 4.1 复盘第 1 次课启动链路

先快速回顾第 1 次课的核心结论。板书或 PPT 展示：

```text
CPU
 ↓
_start（boot/start.S）
 ↓  设置 $sp
kernel_main()
 ↓
printk()
 ↓
UART（UART0_BASE）
 ↓
Hello miniOS on LoongArch64
```

教师提问（快速过，3 个问题控制在 5 分钟内）：

1. CPU 为什么不直接执行 `main()`？
2. 进入 C 函数前为什么要先设置 `$sp`？
3. `printk()` 和 `printf()` 有什么区别？

如果学生回答困难，用第 1 次课的口径简要回顾：裸机没有 C 运行库调用 `main()`，所以入口是 `_start`；C 函数需要栈，所以要先设 `$sp`；`printf()` 依赖操作系统和标准库，裸机里用直接写 UART 的 `printk()` 代替。

### 4.2 引入本次课核心问题

过渡语：

> 上周我们解决了"CPU 如何进入 C 函数并输出字符"。这周继续追问：C 函数里如果有全局变量，它们的初始状态是谁准备的？

展示 `kernel/main.c` 中的两行代码：

```c
static char bss_buffer[16];
static char data_message[] = "data section ok";
```

引导学生判断：

- `data_message` 有明确的初始值 `"data section ok"`。
- `bss_buffer` 没有显式初始值。
- C 语言语义要求：未初始化的静态存储期对象，初始值应为 0。

关键问题：

> 在普通 Linux 程序里，这件事由操作系统加载器和 C 运行库完成。在 miniOS 这个裸机程序中，谁来保证 `bss_buffer[0] == 0`？

让学生先思考 1 分钟，鼓励他们猜测。典型错误猜测包括"硬件自动清零""编译器会生成清零代码""全局变量天生就是 0"。不要直接否定，而是告诉他们：**这些猜测本身恰恰说明学生把操作系统和 C 运行库的功劳当成了"天然"。**

引出本次课主题：

> 裸机程序的全局变量初值，必须由启动汇编自己准备。本次课就来看这件事怎么做。

## 5. 板块二：段（section）结构讲解（20 分钟）

### 5.1 程序不是"一整块无差别内存"

教师板书或展示表格：

| 段 | 内容 | C 语言中常见对应 | 本次课理解要求 |
|---|---|---|---|
| `.text` | 机器指令 | 函数代码 | CPU 执行的指令 |
| `.rodata` | 只读常量 | 字符串字面量 | 只读，一般不修改 |
| `.data` | 有初始值的全局/静态变量 | `static char s[] = "hi";` | 运行时应能读到初始值 |
| `.bss` | 无显式初始值的全局/静态变量 | `static char buf[16];` | 进入 C 前应为 0 |

### 5.2 为什么要有 `.bss`

关键讲解口径：

> 如果把大量"全是 0 的初始值"都原样写进镜像文件，镜像会变大、浪费存储空间。常见做法是：链接时只记录 `.bss` 需要占用的地址范围，运行时在进入 C 之前把这段内存清成 0。

这里可以打个比方：就像搬进一间空宿舍，你不用把所有"空抽屉"都贴上"空的"标签——只需要在入住前统一擦一遍，确保没留下上任住户的东西。

### 5.3 两个必须强调的易混淆点

**第一点："C 语言说初始为 0"不等于"硬件自动变成 0"。**

C 语言是标准规定——未初始化的静态存储期对象初值为 0。但 CPU 和内存不会自动实现这个规定。在裸机中，必须有人真正执行"写 0"这个动作。普通 Linux 程序里，这件事是操作系统加载器和 C 运行库做的。miniOS 是裸机程序，所以必须由启动汇编来做。

**第二点：`__bss_start` 和 `__bss_end` 不是 C 全局数组。**

它们是链接脚本提供的**地址符号**，用来告诉启动代码"从哪里清零到哪里"。学生容易用 C 变量的思维去理解——以为 `__bss_start` 是一个存着地址值的 `int` 变量。要强调：它们是在链接阶段由链接器根据各段实际大小计算出来的地址标签，`boot/start.S` 用 `la.global` 加载的是它们的地址值，不是去读某个变量的内容。

可以用这个类比：链接脚本就像一张家具摆放图，`__bss_start` 和 `__bss_end` 是图上标注的尺寸线——告诉工人"从这到那"的范围，而不是实物家具。

## 6. 板块三：课堂 Demo —— 源码路径（25 分钟）

按顺序打开四个文件，边展示边讲解。不要让学生同时看所有文件。

### 6.1 kernel/main.c —— 先看"验证了什么"

```c
static char bss_buffer[16];
static char data_message[] = "data section ok";

void kernel_main(void)
{
    char buf[32];
    const char *msg = "Hello miniOS on LoongArch64\n";

    printk(msg);                                    // ① 第 1 次课 Hello 链路

    memset(buf, 0, sizeof(buf));                    // ② 清零局部 buf
    memcpy(buf, data_message, strlen(data_message)); // ③ 从 .data 复制到栈
    printk(buf);                                    // ④ 打印 data section ok
    printk("\n");

    if (bss_buffer[0] == 0) {                       // ⑤ 检查 .bss 是否已清零
        printk("bss section cleared\n");
    }

    printk("week1-week2 check done\n");             // ⑥ 阶段标记

    while (1) {
        __asm__ volatile("idle 0");                 // ⑦ 停机
    }
}
```

按执行顺序逐点讲解：

① 保留第 1 次课 Hello 输出路径 → 验证启动链路仍有效。

②③④ 验证 `.data` 可读：先用 `memset` 清零局部数组 `buf`，再用 `strlen` 得到 `data_message` 的长度，再用 `memcpy` 把 `.data` 里的字符串复制到栈上的 `buf`，最后 `printk(buf)` 输出。如果看到 `data section ok`，说明有初始值的全局数据确实可读，且 C 成功调用了汇编实现的 `memset`/`memcpy`/`strlen`。

⑤ 验证 `.bss` 已清零：`bss_buffer` 是未初始化的全局数组，如果 `bss_buffer[0] == 0`，说明启动阶段确实把 `.bss` 段清零了。只有 `clear_bss` 在 `kernel_main()` 之前执行，这个条件才一定成立。

⑥⑦ 阶段标记和停机循环——防止 `kernel_main` 返回后 CPU 跑飞。

**强调**：这里用 `memcpy` 复制 `data_message` 再输出，而不是直接 `printk(data_message)`，是为了同时练习 C 调用汇编库函数的完整链路。两种写法都能正常工作，但教学目的不同。

### 6.2 boot/start.S —— 再看"进入 C 前做了什么"

```asm
    .section .text.boot, "ax"
    .globl _start

_start:
    la.global   $sp, boot_stack_top     @ ① 设置内核栈顶
    bl          clear_bss               @ ② 清零 .bss ← 本次课新增关键步骤
    bl          kernel_main             @ ③ 进入 C 语言内核

halt:
    idle        0
    b           halt

clear_bss:
    la.global   $t0, __bss_start        @ t0 = bss 起始地址
    la.global   $t1, __bss_end          @ t1 = bss 结束地址

1:
    beq         $t0, $t1, 2f            @ t0 == t1 则跳出
    st.b        $zero, $t0, 0           @ *t0 = 0（写一个字节 0）
    addi.d      $t0, $t0, 1             @ t0 = t0 + 1
    b           1b                       @ 继续循环

2:
    jr          $ra                      @ 返回
```

逐行讲解 `clear_bss`（可用自然语言翻译辅助理解）：

```text
t0 = __bss_start     // 清零起点
t1 = __bss_end       // 清零终点
while (t0 != t1) {
    *t0 = 0;         // 逐字节写 0
    t0 = t0 + 1;     // 指针前进
}
return;
```

讲解要点：

1. `__bss_start` 和 `__bss_end` 来自链接脚本（下个文件会看到），不是在这段汇编里定义的。
2. 清零区间是 `[__bss_start, __bss_end)`（左闭右开）。
3. `st.b $zero, $t0, 0` —— `$zero` 恒为 0，用字节存储指令逐字节清零。教学上清晰，不追求性能（后续课次再讨论按 8 字节批量清零）。
4. `bl clear_bss` 必须在 `bl kernel_main` **之前**——调用顺序不可颠倒。如果先进入 C 再清零，C 代码读到的 `bss_buffer[0]` 可能是垃圾值，验证就会失败。

### 6.3 kernel/linker.ld —— 再看"清零边界从哪来"

```ld
ENTRY(_start)

SECTIONS
{
    . = 0x9000000000200000;

    .text : ALIGN(4K) {
        KEEP(*(.text.boot))
        *(.text .text.*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(4K) {
        *(.data .data.*)
    }

    __bss_start = .;
    .bss : ALIGN(4K) {
        *(.bss .bss.*)
        *(COMMON)
    }
    __bss_end = .;
}
```

讲解聚焦在 `__bss_start` 和 `__bss_end` 这两行：

- `.` 是链接器的位置计数器，表示当前地址。
- `__bss_start = .;` 在 `.bss` 段开始前记录当前地址。
- `__bss_end = .;` 在 `.bss` 段结束后记录当前地址。
- 这两个符号是**链接时生成的地址标签**，不是 C 代码里定义的变量。`boot/start.S` 中的 `la.global $t0, __bss_start` 加载的是这个地址值本身，不是去读一个指针变量。

**讲授技巧**：可以把 `__bss_start` 和 `__bss_end` 比作尺子上的两个刻度——它们是位置标记，不占用 `.bss` 区间内的任何额外空间。

### 6.4 lib/string.S 和 include/string.h —— 最后看"C 如何调用汇编库"

**C 侧声明（`include/string.h`）**：

```c
void *memset(void *dst, int value, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
size_t strlen(const char *s);
```

**汇编侧实现（`lib/string.S`）**，以 `memset` 为例：

```asm
    .globl memset
memset:
    move        $t0, $a0          @ 保存原始 dst
    beqz        $a2, 2f           @ n == 0 则直接返回

1:
    st.b        $a1, $a0, 0       @ *dst = value
    addi.d      $a0, $a0, 1       @ dst++
    addi.d      $a2, $a2, -1      @ n--
    bnez        $a2, 1b           @ n != 0 则继续

2:
    move        $a0, $t0           @ 返回值 = 原始 dst
    jr          $ra
```

讲解要点（本次课不要求背完整 ABI）：

1. **同名符号**：C 调用 `memset`，汇编用 `.globl memset` 导出同名全局符号——链接器负责把它们对接起来。
2. **统一约定**：参数通过寄存器传递（`$a0`-`$a2` 分别是 dst、value、n），返回值放在 `$a0`。本次课只需知道"有约定"，不需要背完整的 LoongArch ABI 寄存器保存规则。
3. **一起链接**：`Makefile` 的 `SRCS_S` 中包含了 `lib/string.S`，编成 `.o` 后一起链入 `build/minios.elf`。如果漏掉这行，链接阶段会报 `undefined reference to memset` 等错误。

**调用关系图**（建议板书）：

```text
kernel/main.c
    |
    |  #include "string.h"        （声明）
    |  调用 memset/memcpy/strlen
    v
lib/string.S
    |
    |  .globl memset/memcpy/strlen（定义）
    v
链接器把两者放进同一个 ELF
```

到这里可以做一个快速 Check：让学生指出 `main.c` 中 `memset` 调用对应的参数分别由哪个寄存器传递，以及汇编函数的返回值最终放在哪里。不要求学生全答对，目的是让他们建立"C 调用和汇编实现之间存在确定规则"的意识。

## 7. 板块四：编译、运行与输出分析（15 分钟）

### 7.1 课堂演示

```bash
make clean
make
make run
```

### 7.2 输出逐行分析

```text
Hello miniOS on LoongArch64       ← 第 1 次课启动链路仍在工作
data section ok                   ← .data 中有初始值的全局字符串可读
bss section cleared               ← .bss 已在进入 C 前清零
week1-week2 check done            ← 第 1-2 次课阶段检查路径执行完毕
```

| 输出行 | 验证了什么 | 如果不出现说明什么 |
|---|---|---|
| `Hello miniOS on LoongArch64` | 第 1 次课路径完整 | 启动链路有问题，先回到第 1 次课排查 |
| `data section ok` | `.data` 段可读，C 成功调用汇编库函数 | `data_message` 可能不在 `.data` 段，或 `memcpy`/`strlen` 实现有误 |
| `bss section cleared` | `clear_bss` 已执行，`.bss` 段为 0 | `clear_bss` 未调用、清零区间错误、或 `bss_buffer` 未落在 `.bss` 段 |
| `week1-week2 check done` | 检查路径完整执行到末尾 | 前面某一步提前失败或卡住 |

如果某行缺失，引导学生按源码顺序从 `kernel/main.c` → `boot/start.S` → `kernel/linker.ld` 逐文件排查，而不是盲目重编。

### 7.3 可选：反汇编观察

```bash
loongarch64-linux-gnu-objdump -d build/minios.elf | less
```

搜索 `_start`、`clear_bss`、`kernel_main`、`memset`，让学生看到汇编代码在反汇编输出中的实际形态。这一步如果课堂时间不够可以略过，留给学生课后探索。

## 8. 板块五：学生实验安排与 AI 共学（20 分钟）

### 8.1 学生实验任务

要求学生完成：

```bash
git fetch --tags
sh scripts/check-env.sh   # 在切 tag 之前跑：02-data-bss 等课次 tag 里没有 scripts/ 目录
git switch -c my-02-lab 02-data-bss
make clean
make
make run
```

任务清单：

1. **建立实验分支**并记录当前分支和 tag（`git branch --show-current`、`git describe --tags --always`）
2. **环境检查**——如实记录，工具缺失不要写"已通过"
3. **编译运行**——记录四行验收输出是否齐全
4. **源码阅读（必做）**：
   - `data_message` 与 `bss_buffer` 分别对应哪个段，区别是什么
   - `clear_bss` 的执行流程（可用文本流程图）
   - `__bss_start` / `__bss_end` 来自哪里，是什么
   - C 为何能调用 `lib/string.S` 中的函数
5. **可选加深**：用 `objdump -d` 观察反汇编，用 `nm` 查看符号地址

### 8.2 AI 共学边界

第 2 次课起，AI 使用范围放宽。明确告知学生：

**允许**：
- 请 AI 解释 `clear_bss` 的执行流程
- 请 AI 画出 `_start → clear_bss → kernel_main()` 的文本流程图
- 把真实的 `make` / `make run` 错误信息发给 AI 分析原因
- 让 AI 辅助整理实验报告的结构和表达

**不允许**：
- 让 AI 编造"已跑通"的串口输出
- 不读源码，直接让 AI 代写全部分析后原样提交
- 把 AI 猜测结果写成实测结果

建议课堂话术：

> 第二周开始，AI 可以做更多事情了——帮你解释源码、分析错误、整理报告。但它的角色仍然是"助教"而不是"替身"。实验报告里的串口输出，必须来自你终端里真实跑出来的结果。

**建议发给学生的提问模板**（可以直接投屏）：

```text
请根据 boot/start.S 解释 clear_bss 如何使用 __bss_start 和 __bss_end。

请画出 _start → 设置 sp → clear_bss → kernel_main 的文本流程图，
并标注第 1 次课和第 2 次课新增部分。

这是我的 make / make run 真实错误信息：
<粘贴错误>
请分析可能原因，但不要替我编造运行成功的输出。

请对比 kernel/main.c 中的 data_message 和 bss_buffer，
说明它们分别对应 .data 还是 .bss，以及为什么。
```

## 9. 收尾：本次课边界与思考题（10 分钟）

### 9.1 本次课边界

明确告知学生本次课**不讲**的内容，避免混淆：

- 不要求从零实现 `memset`/`memcpy` 的高性能版本（后续课次深入）
- 不要求背诵完整 LoongArch ABI 寄存器保存规则
- 不涉及开发板移植——仍然是 QEMU
- 仓库按 tag 保持课次纯净：第 1–2 次课源码中**不包含**异常、系统调用、中断相关文件
- 那些内容只在对应后续课次的 tag 中引入，本次课既不展开、也不预埋空壳

### 9.2 核心结论（建议板书保留到下课）

```text
裸机 C 程序不是"天然能正确运行"
启动汇编必须准备最小运行环境：
  1) 设置栈
  2) 清零 .bss
  3) 再进入 kernel_main

.data 有初值，.bss 无显式初值但语义为 0
C 与汇编通过统一符号名和链接过程协同工作
```

### 9.3 思考题

1. `.data` 和 `.bss` 的区别是什么？请结合 `data_message` 与 `bss_buffer` 说明。
2. 为什么 `.bss` 清零必须发生在 `kernel_main()` 之前？如果放在之后会怎样？
3. `__bss_start` 和 `__bss_end` 是谁提供的？它们是 C 变量吗？
4. C 代码为什么能调用 `lib/string.S` 中的汇编函数？至少从"声明、定义、链接"三点回答。
5. 如果 QEMU 输出只有 Hello，没有 `.data/.bss` 检查结果，应该从哪些文件、按什么顺序排查？
6. 普通 Linux 程序通常由谁负责准备 `.data` 和清零 `.bss`？这和 miniOS 有什么不同？
7. 为什么镜像中往往不直接保存一整段全 0 的 `.bss` 内容？
8. `clear_bss` 使用逐字节清零，有什么优点？后续若改为按 8 字节清零，需要注意什么？

### 9.4 作业

- 完成实验并撰写实验报告（模板见 `docs/02/data_bss.md` 第 17 节）
- 报告中的输出必须来自真实命令执行，不能照抄文档预期输出
- 实验报告模板中的 9 个部分必须完整覆盖

### 9.5 下一周预告

> 第 3 次课将进入分支、循环与字符串输出——在已经能输出字符、能理解数据段的基础上，用控制流组织更复杂的输出逻辑。

## 10. 常见问题与讲解口径

### 10.1 学生以为 C 全局变量"天然就有正确初值"

这是本次课最常见的误区。讲解口径：C 语言标准规定了"未初始化的静态存储期对象应为 0"，但标准是给人看的，CPU 不会自动替你清零。在普通 Linux 程序中，是操作系统的加载器在程序启动前做了这件事；在裸机中，启动代码必须自己清。

### 10.2 学生把 `__bss_start` 当成 C 变量

学生可能会写 `int x = __bss_start;` 并期待得到"bss 的起始地址"。讲解口径：`__bss_start` 是链接器生成的符号，它的**地址**就是 bss 的起始位置。汇编中用 `la.global $t0, __bss_start` 加载的是这个地址值，而 C 中如果 `extern char __bss_start;`，那么 `&__bss_start` 才是 bss 的起始地址——`__bss_start` 本身不占用空间。

### 10.3 学生问"为什么不用 memset 来清零 bss？"

这是个好问题。答案是：`clear_bss` 发生在进入 `kernel_main` 之前，此时 C 运行环境还没完全准备好；而且 `clear_bss` 本身就是为 C 代码准备环境的一环——如果用它来清零 `.bss`，谁又来保证 `memset` 自己的 `.bss` 变量是干净的？所以 `.bss` 清零不能依赖任何 C 函数，必须用纯汇编实现。

### 10.4 学生把普通程序经验和裸机混为一谈

学生可能说"我写的 C 程序从来不用关心 .bss 也能跑"。讲解口径：对的，那是因为 Linux 和 C 运行库帮你做了。miniOS 让你看到幕后发生了什么。学完这周，你应该对"操作系统为你做了什么"有更具体的认识。

### 10.5 只有 Hello，没有后面的输出

这是学生实验中最常见的故障。排查顺序：① 确认当前分支是 `02-data-bss` 而非 `week01-*`；② `make clean && make` 确保全量重编；③ 检查 `boot/start.S` 中 `bl clear_bss` 是否在 `bl kernel_main` 之前；④ 检查 `kernel/main.c` 中验证代码是否完整；⑤ 检查 `kernel/linker.ld` 中 `__bss_start`/`__bss_end` 定义是否存在。

### 10.6 bss 段清零用逐字节循环，是否效率太低

讲解口径：教学上优先保证清晰易懂，逐字节循环能让学生一眼看出"从起点到终点，每字节写 0"。后续课次（第 10 次课）会讨论按 8 字节批量清零的优化方案，以及对齐、缓存等注意事项。本次课先建立正确逻辑，性能优化不是本次课目标。

## 11. 板书建议

### 11.1 主板书——第 1 次课 vs 第 2 次课路径对比

```text
第 1 次课：_start → 设置 sp → kernel_main → printk → UART

第 2 次课：_start → 设置 sp → clear_bss → kernel_main
                                              ├─ Hello
                                              ├─ 验证 .data 可读
                                              └─ 验证 .bss 已清零
```

### 11.2 段结构速查

```text
.text     → 指令
.rodata   → 只读常量
.data     → 有初始值的全局变量（运行时应能读到）
.bss      → 无显式初始值的全局变量（进入 C 前必须清零）
```

### 11.3 clear_bss 伪代码

```text
t0 = __bss_start
t1 = __bss_end
while (t0 != t1) {
    *t0 = 0
    t0++
}
```

### 11.4 C/汇编混合调用

```text
C 声明 (.h)  ←→  汇编实现 (.S)  ←→  链接器 (Makefile)
   同名符号          .globl 导出         一起链入 ELF
```

## 12. 思考题参考答案

### 12.1 `.data` 和 `.bss` 的区别是什么？

`.data` 存放有显式初始值的全局/静态变量（如 `static char s[] = "hi";`），其初始值保存在镜像文件中，运行时可直接读取。`.bss` 存放无显式初始值的全局/静态变量（如 `static char buf[16];`），C 语义要求它们初始为 0，但镜像文件中通常不保存大量 0，而是由启动代码在进入 C 之前将对应内存区域清零。

### 12.2 为什么 `.bss` 清零必须发生在 `kernel_main()` 之前？

`kernel_main()` 是第一个 C 函数，C 代码一执行就可能读取全局变量。如果 `.bss` 没有提前清零，`bss_buffer[0]` 读到的将是内存里的随机垃圾值，`bss_buffer[0] == 0` 的判断可能失败。放在之后清零则 C 代码已经读到了错误值。

### 12.3 `__bss_start` 和 `__bss_end` 是谁提供的？

由链接脚本（`kernel/linker.ld`）在链接阶段生成。它们不是 C 代码中定义的变量，也不是 CPU 或硬件自动提供的。链接器根据各段大小和布局，在 `.bss` 段前后插入这两个地址标签，供启动汇编作为清零循环的起止边界。

### 12.4 C 代码为什么能调用 `lib/string.S` 中的汇编函数？

三个环节：（1）**声明**：`include/string.h` 向 C 编译器声明了函数的参数和返回值类型；（2）**定义**：`lib/string.S` 用 `.globl` 导出同名全局符号，并按 LoongArch ABI 约定在对应寄存器中接收参数、返回结果；（3）**链接**：`Makefile` 把 `lib/string.S` 编译成 `lib/string.o`，与其他目标文件一起链接进最终镜像，链接器将 C 侧的调用引用与汇编侧的符号定义对接。

### 12.5 如果 QEMU 输出只有 Hello，没有 `.data/.bss` 检查结果，应该从哪些文件排查？

按以下顺序排查：（1）确认分支正确——是否在 `02-data-bss` 或其衍生分支上；（2）查看 `kernel/main.c`——`.data/.bss` 验证代码是否完整存在；（3）查看 `boot/start.S`——`bl clear_bss` 是否在 `bl kernel_main` 之前；（4）查看 `kernel/linker.ld`——`__bss_start` 和 `__bss_end` 定义是否存在；（5）查看 `Makefile`——`lib/string.S` 是否在 `SRCS_S` 中。每一步都执行 `make clean && make && make run` 验证。

### 12.6 普通 Linux 程序通常由谁负责准备 `.data` 和清零 `.bss`？

由操作系统的程序加载器（loader）和 C 运行库（crt0 等）共同完成。加载器按 ELF 程序头的 LOAD 段信息将各段映射到内存，C 运行库的启动代码负责清零 `.bss` 等初始化工作，最后才调用 `main()`。miniOS 是裸机程序，没有这些基础设施，所以必须由 `boot/start.S` 中的 `clear_bss` 自己完成。

### 12.7 为什么镜像中往往不直接保存一整段全 0 的 `.bss` 内容？

因为 `.bss` 变量没有显式初始值，全部是 0。如果把一个大数组（比如 `char buf[1000000]`）的 0 全部写进镜像文件，镜像文件会变得很大且浪费存储空间。更高效的做法是：链接时只记录 `.bss` 需要的地址范围，运行时用一段小循环把这块内存清零。这样镜像文件小，加载后行为完全一致。

### 12.8 `clear_bss` 使用逐字节清零，有什么优点？后续若改为按 8 字节清零，需要注意什么？

逐字节清零的优点是逻辑简单清晰，不需要考虑对齐问题，便于教学理解。改为按 8 字节清零时需要注意：（1）对齐——`__bss_start` 是否 8 字节对齐？不对齐的情况下，开头和结尾可能需要先按字节清零到对齐边界；（2）大小——区间长度可能不是 8 的整数倍，最后不足 8 字节的尾巴仍需逐字节处理；（3）指令选择——LoongArch 的 `st.d` 可以一次写 8 字节，但前提是地址 8 字节对齐。

## 13. 本次课收束

第 1 次课学生建立了一条链路：CPU → `_start` → `kernel_main` → `printk` → UART → Hello。

第 2 次课在这条链路上增加了一个关键步骤：`clear_bss`。同时引入了段的基本概念和 C/汇编混合调用。

把两周连起来，学生应该理解的核心叙事是：

> 要让一个裸机 C 程序跑起来，必须有人在进入 C 之前把舞台搭好。第 1 次课搭了"栈"（让 C 函数有地方保存调用现场），第 2 次课搭了"数据初始状态"（让全局变量有可信的初值）。后面每一周都会在这个舞台上添加新的基础设施。

下一周（第 3 次课）将在能输出字符、能理解数据段的基础上，引入分支与循环控制流，组织更复杂的字符串输出逻辑。