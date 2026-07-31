# 第 2 次课实验指导手册：.data/.bss 初始化与 C/汇编混合启动

本手册用于《LoongArch 汇编语言》第 2 次课自学与课堂实验。课程资料按“2 节课 = 1 次课”组织，第 2 次课对应课程第 3-4 节。若实际排课为一周 4 节课，本次课通常安排在行政第 1 周的后半段。

第 1 次课已经回答：CPU 如何进入 C 函数，并把字符输出到终端。  
第 2 次课继续回答更接近真实 C 程序的问题：

> 在没有操作系统和 C 运行库的裸机环境中，全局变量的初始状态由谁准备？`.data` 和 `.bss` 分别意味着什么？

本次课在第 1 次课 Hello 链路之上，增加 `.bss` 清零与 C/汇编混合调用观察，形成完整验收输出。

```text
_start
 ↓
设置 $sp
 ↓
clear_bss
 ↓
kernel_main()
 ├─ printk("Hello miniOS on LoongArch64")
 ├─ 读取 .data 中的 data_message
 ├─ 检查 .bss 中的 bss_buffer
 └─ printk("week1-week2 check done")
```

---

## 1. 实验定位

本实验是第 1 次课启动路径的自然延伸。

第 1 次课解决的是：

- 入口不在 `main()`，而在 `_start`
- 进入 C 之前必须设置 `$sp`
- 用 `printk()` + UART 输出 Hello

第 2 次课解决的是：

- 有初始值的全局变量放在哪里、如何读到
- 无显式初始值的全局变量为什么必须清零
- 启动汇编如何在进入 C 之前完成 `.bss` 清零
- C 代码如何调用汇编实现的 `memset` / `memcpy` / `strlen`

本次课**不要求**你从零实现完整运行库，也不要求背完整 ABI。重点是：

1. 能跑通并记录真实输出  
2. 能沿着源码解释 `.data/.bss`  
3. 能说明 `clear_bss` 为何必须在 `kernel_main()` 之前  

---

## 2. 学习目标

完成本实验后，你应该能够：

### 2.1 知识目标

- 区分 `.text`、`.rodata`、`.data`、`.bss` 的基本含义
- 说明 `data_message` 与 `bss_buffer` 分别对应哪一类全局变量
- 解释为什么 `.bss` 必须在进入 C 代码前清零
- 说明 `__bss_start`、`__bss_end` 由谁提供、表示什么

### 2.2 能力目标

- 从 tag `week02-data-bss` 创建自己的实验分支
- 完成环境检查、`make clean`、`make`、`make run`
- 沿着 `boot/start.S` 找到 `clear_bss`
- 沿着 `kernel/main.c` 找到 `.data/.bss` 验证代码
- 沿着 `kernel/linker.ld` 找到 `__bss_start` / `__bss_end`
- 理解 `kernel/main.c` 如何调用 `lib/string.S` 中的函数
- 在实验报告中区分：真实输出、预期输出、失败原因

### 2.3 AI 共学目标

第 2 次课起，允许在教师规定范围内使用 AI 辅助：

- 解释源码与反汇编
- 分析真实错误信息
- 整理实验报告结构

但实验结果**必须**来自你自己执行的命令输出，不能由 AI 编造。

---

## 3. 实验前准备

### 3.1 前置条件

建议已完成第 1 次课：

- 能说明 `_start → kernel_main() → printk() → UART` 的基本路径
- 能执行 `make clean && make && make run`，或能记录明确失败原因
- 知道退出 QEMU 的方式：`Ctrl-a` 后按 `x`

### 3.2 推荐环境

推荐在 **Linux 或 WSL Ubuntu** 中完成。需要的工具：

| 工具 | 作用 |
|---|---|
| `make` | 编译入口 |
| `qemu-system-loongarch64` | 运行 LoongArch 虚拟机 |
| `loongarch64-linux-gnu-gcc` | 交叉编译 C/汇编 |
| `loongarch64-linux-gnu-objdump` | 反汇编观察 |
| `loongarch64-linux-gnu-nm` | 查看符号地址（可选） |
| `gdb-multiarch` | 调试（可选，本次课非强制） |

若工具尚未安装，先阅读：

- `../manual_wsl_ubuntu_install.md`
- `../environment_check.md`

### 3.3 进入仓库

```bash
cd miniOS
```

若仓库在 Windows 磁盘、通过 WSL 访问，路径通常类似：

```bash
cd /mnt/<盘符>/<你的课程工作目录>/miniOS
```

### 3.4 建议 Git 起点

第 2 次课建议从稳定 tag 创建个人实验分支，不要直接在课程远端分支上改：

```bash
git fetch --tags
git switch -c my-week02-lab week02-data-bss
```

如果当前仓库尚未发布 `week02-data-bss` tag，可先在教师指定的分支上完成实验，并在报告中写明：

```text
Git 起点：当前分支 <branch-name>，尚未检出 week02-data-bss tag。
```

---

## 4. 背景知识：段（section）是什么

编译、链接后的程序不是“一整块无差别内存”，而是按用途分成若干段。本次课至少要理解下表。

| 段 | 大致内容 | C 语言中常见对应 | 本次课理解要求 |
|---|---|---|---|
| `.text` | 机器指令 | 函数代码 | CPU 真正执行的代码 |
| `.rodata` | 只读常量 | 字符串字面量等 | 只读，一般不修改 |
| `.data` | 有初始值的全局/静态变量 | `static char s[] = "hi";` | 运行时应能读到初始值 |
| `.bss` | 无显式初始值的全局/静态变量 | `static char buf[16];` | 进入 C 前应为 0 |

### 4.1 为什么要有 `.bss`

如果把大量“全是 0 的初始值”都原样写进镜像文件，镜像会变大、浪费空间。  
常见做法是：

- 链接时只记录 `.bss` 需要占用的地址范围
- 运行时在进入 C 之前，把这段内存清成 0

普通 Linux 用户程序里，加载器和 C 运行库会做这件事。  
miniOS 是裸机程序，**没有**完整操作系统和 C 运行库，所以必须由启动汇编自己做。

### 4.2 两个容易混淆的点

1. **“C 语言说初始为 0”不等于“硬件自动变成 0”**  
   C 语义要求未初始化的静态存储期对象初值为 0；在裸机中，必须有人真正写 0。

2. **`__bss_start` / `__bss_end` 不是 C 全局数组**  
   它们是链接脚本提供的**地址符号**，用来告诉启动代码：从哪里清零到哪里。

---

## 5. 从第 1 次课到第 2 次课

### 5.1 第 1 次课最小路径

```text
QEMU 加载 build/minios.elf
 ↓
CPU 进入 _start
 ↓
设置 $sp
 ↓
kernel_main()
 ↓
printk() → UART
 ↓
Hello miniOS on LoongArch64
```

### 5.2 第 2 次课在路径上增加的关键一步

```text
QEMU 加载 build/minios.elf
 ↓
CPU 进入 _start
 ↓
设置 $sp
 ↓
clear_bss          ← 本次课新增关键步骤
 ↓
kernel_main()
 ├─ Hello 输出（保留第 1 次课）
 ├─ 验证 .data 可读
 └─ 验证 .bss 已清零
```

可以这样记：

> 第 1 次课：让 CPU 安全进入 C。  
> 第 2 次课：让 C 代码看到“可信的全局变量初始状态”。

---

## 6. 工程目录与本次课重点文件

先观察工程目录：

```bash
ls
```

本次课重点文件：

```text
boot/start.S        启动入口；本次课重点看 clear_bss
kernel/main.c       .data/.bss 验证逻辑
kernel/linker.ld    定义 __bss_start / __bss_end 与各段布局
lib/string.S        汇编实现的 memset / memcpy / strlen
include/string.h    上述函数的 C 声明
Makefile            确保 lib/string.S 被编译进镜像
```

阅读建议顺序：

```text
1. kernel/main.c      先看“要验证什么”
2. boot/start.S       再看“进入 C 前做了什么”
3. kernel/linker.ld   再看“清零边界从哪来”
4. lib/string.S       最后看“C 如何调用汇编库”
   include/string.h
```

---

## 7. 环境检查

```bash
sh scripts/check-env.sh
```

至少确认下列命令可用：

```text
make
qemu-system-loongarch64
loongarch64-linux-gnu-gcc
loongarch64-linux-gnu-objdump
```

如果某个工具缺失，报告中不要写“已通过”。应记录真实情况，例如：

```text
环境检查未通过：找不到 loongarch64-linux-gnu-gcc。
下一步：安装 gcc-loongarch64-linux-gnu 后重新执行 sh scripts/check-env.sh。
```

---

## 8. 编译与运行

### 8.1 清理与编译

```bash
make clean
make
```

编译成功后通常生成：

```text
build/minios.elf
build/minios.bin
```

### 8.2 运行

```bash
make run
```

等价命令：

```bash
qemu-system-loongarch64 -M virt -m 512M -nographic -kernel build/minios.elf
```

### 8.3 退出 QEMU

`make run` 使用 `-nographic`，会占用当前终端。退出方式：

```text
Ctrl-a x
```

先按 `Ctrl-a`，松开后再按 `x`。

---

## 9. 预期输出与逐行解释

第 2 次课验收输出为：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

| 输出行 | 说明 | 主要对应代码 |
|---|---|---|
| `Hello miniOS on LoongArch64` | 第 1 次课启动链路仍有效 | `kernel/main.c` 中 `printk(msg)` |
| `data section ok` | 有初始值的全局字符串可读 | `data_message[]` + `memcpy`/`strlen` |
| `bss section cleared` | 未初始化全局数组已被清零 | `bss_buffer` + `clear_bss` |
| `week1-week2 check done` | 本阶段检查路径执行完毕 | `kernel/main.c` 末尾 `printk` |

说明：

- 当前代码路径会**同时保留**第 1 次课 Hello 输出。
- 第 2 次课重点验收后三行，尤其是 `data section ok` 与 `bss section cleared`。
- 若只有 Hello、没有后面三行，说明 `.data/.bss` 检查路径未按预期执行，需要按第 14 节排查。

---

## 10. 任务一：阅读 kernel/main.c

打开：

```text
kernel/main.c
```

### 10.1 两个关键全局变量

```c
static char bss_buffer[16];
static char data_message[] = "data section ok";
```

请自己回答：

| 变量 | 有没有显式初始值 | 更可能落在哪个段 | 运行时期望 |
|---|---|---|---|
| `data_message` | 有，`"data section ok"` | `.data` | 能读出该字符串 |
| `bss_buffer` | 无 | `.bss` | 每个字节应为 0 |

### 10.2 kernel_main 在做什么

按执行顺序理解：

1. **输出 Hello**  
   验证第 1 次课路径：`printk("Hello miniOS on LoongArch64\n")`

2. **验证 `.data`**  
   - 用 `memset` 把局部数组 `buf` 清零  
   - 用 `strlen` 得到 `data_message` 长度  
   - 用 `memcpy` 把 `data_message` 复制到 `buf`  
   - 用 `printk(buf)` 输出  
   若看到 `data section ok`，说明有初始值的全局数据可读，且 C 成功调用了汇编库函数。

3. **验证 `.bss`**  
   ```c
   if (bss_buffer[0] == 0) {
       printk("bss section cleared\n");
   }
   ```  
   只有启动阶段把 `.bss` 清成 0，这里才会打印。

4. **打印阶段完成标记**  
   `printk("week1-week2 check done\n");`

5. **停机循环**  
   ```c
   while (1) {
       __asm__ volatile("idle 0");
   }
   ```  
   防止 `kernel_main` 返回后 CPU 跑飞。

### 10.3 本任务思考

1. 如果删掉 `clear_bss`，`bss_buffer[0] == 0` 是否一定成立？为什么？  
2. `buf` 是局部变量，它和 `bss_buffer` 的“初始状态责任人”一样吗？  
3. 为什么这里用 `memcpy` 复制 `data_message`，而不是直接 `printk(data_message)`？（两种写法都可能工作；本实验是为了同时练 C/汇编库调用。）

---

## 11. 任务二：阅读 boot/start.S

打开：

```text
boot/start.S
```

### 11.1 _start 的完整职责（第 1+2 周）

```asm
_start:
    la.global   $sp, boot_stack_top
    bl          clear_bss
    bl          kernel_main
```

含义：

1. 设置内核栈顶到 `$sp`  
2. 调用 `clear_bss` 清零 `.bss`  
3. 调用 `kernel_main` 进入 C  

若 `kernel_main` 返回，后面还有 `halt` 循环。

### 11.2 clear_bss 逐行理解

```asm
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
```

用自然语言翻译：

```text
t0 = __bss_start
t1 = __bss_end
while (t0 != t1) {
    *t0 = 0;          // 写一个字节 0
    t0 = t0 + 1;      // 前进一字节
}
return;
```

关键点：

- 清零区间是 **`[__bss_start, __bss_end)`**（左闭右开）
- 使用 `st.b` 逐字节写 0（教学上清晰，不追求性能）
- `bl clear_bss` 在 `bl kernel_main` **之前**，保证 C 代码第一次读 `bss_buffer` 时已经是 0

### 11.3 本任务必须能回答

1. CPU 第一条指令对应哪个符号？  
2. 为什么不能跳过 `clear_bss` 直接 `kernel_main`？  
3. `clear_bss` 如何知道从哪清到哪？

---

## 12. 任务三：阅读 kernel/linker.ld

打开：

```text
kernel/linker.ld
```

### 12.1 入口与布局

```ld
ENTRY(_start)
```

告诉链接器：程序入口符号是 `_start`，不是 `main`。

段顺序大致为：

```text
.text
.rodata
.data
.bss     ← __bss_start ... __bss_end
```

### 12.2 本次课最关键的两行

```ld
__bss_start = .;
.bss : ALIGN(4K) {
    *(.bss .bss.*)
    *(COMMON)
}
__bss_end = .;
```

含义：

- 链接器把所有 `.bss` 相关内容排在一起  
- 在 `.bss` 段前记录当前地址为 `__bss_start`  
- 在 `.bss` 段后记录当前地址为 `__bss_end`  
- `boot/start.S` 用这两个符号做循环边界  

因此：

> `__bss_start` / `__bss_end` 是**链接时生成的地址标签**，不是你在 C 里定义的数组名。

### 12.3 可选观察命令

编译成功后可执行：

```bash
loongarch64-linux-gnu-nm build/minios.elf | grep -E "bss|data_message|bss_buffer|_start|kernel_main"
```

或：

```bash
loongarch64-linux-gnu-objdump -t build/minios.elf | grep -E "bss|data_message|_start"
```

观察目标：

- 能否找到 `__bss_start`、`__bss_end`
- `_start`、`kernel_main` 是否存在
- 与 `data_message` / `bss_buffer` 相关符号是否出现（名称可能被编译器修饰或局部化，以实际输出为准）

报告中可贴真实命令输出摘要。

---

## 13. 任务四：C 与汇编混合调用

### 13.1 C 侧声明

`include/string.h`：

```c
void *memset(void *dst, int value, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
size_t strlen(const char *s);
```

`kernel/main.c` 通过 `#include "string.h"` 获得声明，编译器据此生成函数调用。

### 13.2 汇编侧实现

`lib/string.S` 导出三个全局符号：

| 函数 | 作用 | 本次课在 main 中的用途 |
|---|---|---|
| `memset` | 把 `n` 字节写成指定值 | 清零局部 `buf` |
| `memcpy` | 复制 `n` 字节 | 把 `data_message` 拷到 `buf` |
| `strlen` | 计算字符串长度 | 决定复制多少字节 |

以 `memset` 为例（逐字节教学版）：

```asm
memset:
    move        $t0, $a0          /* 保存原始 dst，作为返回值 */
    beqz        $a2, 2f

1:
    st.b        $a1, $a0, 0
    addi.d      $a0, $a0, 1
    addi.d      $a2, $a2, -1
    bnez        $a2, 1b

2:
    move        $a0, $t0
    jr          $ra
```

本次课只需建立这些认知：

1. **同名符号**：C 调用 `memset`，汇编用 `.globl memset` 导出  
2. **统一约定**：参数通过约定寄存器传递（本阶段不必背完整 ABI，先知道“有约定”）  
3. **一起链接**：`Makefile` 把 `lib/string.S` 编进 `OBJS`，最终链入 `build/minios.elf`

查看 `Makefile` 中相关行：

```make
SRCS_S := \
	boot/start.S \
	lib/string.S
```

如果漏掉 `lib/string.S`，链接阶段通常会报找不到 `memset` / `memcpy` / `strlen`。

### 13.3 调用关系图

```text
kernel/main.c
    |
    |  #include "string.h"   （声明）
    |  调用 memset/memcpy/strlen
    v
lib/string.S
    |
    |  .globl memset/memcpy/strlen  （定义）
    v
链接器把两者放进同一个 ELF
```

---

## 14. 实验任务清单（按顺序做）

### Task A：建立实验分支

```bash
git fetch --tags
git switch -c my-week02-lab week02-data-bss
```

记录当前分支：

```bash
git branch --show-current
git describe --tags --always
```

### Task B：环境检查

```bash
sh scripts/check-env.sh
```

### Task C：编译运行

```bash
make clean
make
make run
```

记录四行验收输出是否齐全。

### Task D：源码阅读（必做）

完成并写入报告：

1. `data_message` 与 `bss_buffer` 的区别  
2. `clear_bss` 的流程（可用文本流程图）  
3. `__bss_start` / `__bss_end` 来自哪里  
4. C 为何能调用 `lib/string.S` 中的函数  

### Task E：可选加深（加分/拓展，非必须）

1. 用 `objdump -d` 搜索 `clear_bss`、`kernel_main`  
2. 用 `nm` 查看 `__bss_start` / `__bss_end`  
3. 思考：若故意注释掉 `bl clear_bss` 再编译运行，输出会怎样？（**做完后务必改回**，不要提交破坏启动路径的版本）

反汇编示例：

```bash
loongarch64-linux-gnu-objdump -d build/minios.elf | less
```

在输出中搜索：

```text
_start
clear_bss
kernel_main
memset
```

---

## 15. 常见错误与处理

| 现象 | 可能原因 | 处理方式 |
|---|---|---|
| `make: command not found` | 未安装 `make` | 在 Linux/WSL 安装 `make` |
| `loongarch64-linux-gnu-gcc: command not found` | 未安装交叉编译器 | 安装 `gcc-loongarch64-linux-gnu` |
| `qemu-system-loongarch64: command not found` | 未安装 QEMU LoongArch 支持 | 安装 `qemu-system-misc` |
| 链接报 undefined reference to `memset` 等 | 未编译/未链接 `lib/string.S` | 检查 `Makefile` 的 `SRCS_S` |
| 只有 Hello，没有 `data section ok` | `main.c` 验证路径未执行、字符串段异常、或未进入后续代码 | 对照 `kernel/main.c`，重新 `make clean && make && make run` |
| 有 Hello 和 data，没有 `bss section cleared` | `clear_bss` 未调用、区间错误、或 `bss_buffer` 未落在 `.bss` | 检查 `boot/start.S` 与 `linker.ld` |
| 输出乱码或无输出 | 用了错误架构编译器，或镜像不是 LoongArch | 确认使用 `loongarch64-linux-gnu-gcc`，不要用宿主机 gcc 裸编内核 |
| 不知道如何退出 QEMU | `-nographic` 占用终端 | `Ctrl-a` 然后 `x` |
| 报告写“已通过”但无真实输出 | 未实测 | 改为“未执行/失败”，并写原因与下一步 |

如果错误不在表中，报告至少记录：

- 执行的命令  
- 关键错误行  
- 已尝试的处理  
- 下一步排查计划  

---

## 16. 验收标准

### 16.1 必须完成

- 从第 2 次课起点创建实验分支，或说明当前使用的分支/tag  
- 执行环境检查并记录真实结果  
- 执行 `make clean`、`make`、`make run`，或记录明确失败原因  
- 若 QEMU 跑通，记录完整四行输出：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

### 16.2 必须理解

- `.data` 与 `.bss` 的区别  
- 为什么 `clear_bss` 在 `kernel_main()` 之前  
- `__bss_start` / `__bss_end` 是链接脚本提供的地址边界  
- C 文件如何通过声明 + 链接调用汇编函数  

### 16.3 不作为第 2 次课验收

- 自己重写高性能 `memset`/`memcpy`（后续课次再深入）  
- 完整 LoongArch ABI 背诵  
- 开发板移植  
- 修改异常、系统调用、中断相关框架代码  

---

## 17. 实验报告模板

可直接复制下面结构撰写。

````markdown
# 第 2 次课实验报告：.data/.bss 初始化与 C/汇编混合启动

### 1. 实验环境

- 操作系统：
- 是否使用 WSL：
- QEMU 版本：
- LoongArch GCC 版本：
- 仓库路径：

### 2. Git 起点

```bash
git branch --show-current
git describe --tags --always
```

结果：

```text
在这里填写。
```

### 3. 环境检查结果

```bash
sh scripts/check-env.sh
```

真实输出摘要：

```text
在这里填写真实输出或关键结果。
```

### 4. 编译结果

```bash
make clean
make
```

结果：

```text
成功生成 build/minios.elf，或填写失败原因。
```

### 5. QEMU 运行结果

```bash
make run
```

真实输出：

```text
在这里粘贴真实串口输出。
```

若未成功运行，填写失败原因和下一步处理计划。

### 6. 源码阅读记录

#### 6.1 kernel/main.c

- `data_message` 的作用与所在段理解：
- `bss_buffer` 的作用与所在段理解：
- 为什么看到 `data section ok` 能说明 `.data` 可读：
- 为什么看到 `bss section cleared` 能说明 `.bss` 已清零：

#### 6.2 boot/start.S

- `_start` 中调用顺序：
- `clear_bss` 文本流程图：

```text
在这里画流程图。
```

#### 6.3 kernel/linker.ld

- `__bss_start` / `__bss_end` 是谁提供的：
- 它们表示什么范围：

#### 6.4 C/汇编混合

- `string.h` 的作用：
- `lib/string.S` 提供了哪些函数：
- `Makefile` 如何把汇编库链进镜像：

### 7. 错误与解决过程

| 问题 | 原因 | 处理方式 | 是否解决 |
|---|---|---|---|
| | | | |

### 8. AI 使用记录

- 我向 AI 提问的问题：
- AI 帮助我理解了什么：
- 实验结果是否全部来自真实命令输出：是 / 否

### 9. 思考题回答

1. `.data` 和 `.bss` 的区别是什么？
2. 为什么 `.bss` 清零必须发生在 `kernel_main()` 之前？
3. `__bss_start` 和 `__bss_end` 是谁提供的？
4. C 代码为什么能调用 `lib/string.S` 中的汇编函数？
5. 如果 QEMU 输出只有 Hello，没有 `.data/.bss` 检查结果，应该从哪些文件排查？
````

注意：

- 没有执行就写“未执行”  
- 失败就写失败原因  
- 禁止未运行却写“已测试通过”  
- 禁止只贴预期输出、不贴真实输出  

---

## 18. AI 共学要求

### 18.1 允许

- 解释 `clear_bss` 执行流程  
- 画出 `_start → clear_bss → kernel_main()` 流程图  
- 解释 `.text/.rodata/.data/.bss`  
- 根据真实 `make` / `make run` 错误信息分析原因  
- 辅助整理报告结构与文字表达  

### 18.2 不允许

- 让 AI 编造“已跑通”的串口输出  
- 不读源码，直接让 AI 代写全部分析后原样提交  
- 把 AI 猜测结果写成实测结果  

### 18.3 建议提问模板

```text
请根据 boot/start.S 解释 clear_bss 如何使用 __bss_start 和 __bss_end。
```

```text
请画出 _start -> 设置 sp -> clear_bss -> kernel_main 的文本流程图，并标注第 1 次课和第 2 次课新增部分。
```

```text
这是我的 make / make run 真实错误信息：
<粘贴错误>
请分析可能原因，但不要替我编造运行成功的输出。
```

```text
请对比 kernel/main.c 中的 data_message 和 bss_buffer，说明它们分别对应 .data 还是 .bss，以及为什么。
```

---

## 19. 思考题

1. `.data` 和 `.bss` 的区别是什么？请结合 `data_message` 与 `bss_buffer` 说明。  
2. 为什么 `.bss` 清零必须发生在 `kernel_main()` 之前？如果放在之后会怎样？  
3. `__bss_start` 和 `__bss_end` 是谁提供的？它们是 C 变量吗？  
4. C 代码为什么能调用 `lib/string.S` 中的汇编函数？至少从“声明、定义、链接”三点回答。  
5. 如果 QEMU 输出只有 Hello，没有 `.data/.bss` 检查结果，应该从哪些文件、按什么顺序排查？  
6. 普通 Linux 程序通常由谁负责准备 `.data` 和清零 `.bss`？这和 miniOS 有什么不同？  
7. 为什么镜像中往往不直接保存一整段全 0 的 `.bss` 内容？  
8. `clear_bss` 使用逐字节清零，有什么优点？后续若改为按 8 字节清零，需要注意什么？（开放题）

---

## 20. 拓展阅读与下一周预告

完成本次课必做内容后，可继续阅读：

- `README.md`：仓库总体说明与第 1-2 次课验收输出  
- `lesson_plan.md`：本次课教师教案（了解课堂节奏）  
- `../week01/qemu_hello.md`：第 1 次课启动路径复习  
- `../course_structure.md`：16 次课课程主线  
- `../QEMU-to-Loongson-Pioneer-Porting-Guide.md`：为何先 QEMU 再开发板  

**第 3 次课预告**：分支、循环与字符串输出——在已经能输出字符、能理解数据段的基础上，用控制流组织更复杂的输出逻辑。

---

## 21. 一页速查

### 命令

```bash
git fetch --tags
git switch -c my-week02-lab week02-data-bss
sh scripts/check-env.sh
make clean
make
make run
# 退出 QEMU: Ctrl-a x
```

### 验收输出

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

### 核心结论

```text
裸机 C 程序不是“天然能正确运行”
启动汇编必须准备最小运行环境：
  1) 设置栈
  2) 清零 .bss
  3) 再进入 kernel_main
.data 有初值，.bss 无显式初值但语义为 0
C 与汇编通过统一符号名和链接过程协同工作
```
