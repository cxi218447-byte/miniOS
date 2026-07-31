# 第 1 周实验指导手册：QEMU Hello miniOS

本手册用于《LoongArch 汇编语言》第 1 周自学实验。课程资料按“2 节课 = 1 个课程周次”组织，第 1 周对应课程第 1-2 节。目标不是写一个完整操作系统，而是把一个最小 miniOS 从第一条指令启动起来，并在 QEMU 串口中看到第一行输出。

第 1 周只关注 Hello 链路：

```text
CPU
 ↓
boot/start.S
 ↓
kernel_main()
 ↓
printk()
 ↓
UART
 ↓
Hello miniOS
```

## 1. 实验定位

本实验是整门课程的起点。后续的 `.data/.bss`、分支循环、函数调用、异常、中断、系统调用和开发板迁移，都会建立在本周的启动路径之上。

本周你要先回答一个核心问题：

> 在没有操作系统、没有 C 运行库、没有 `printf()` 的情况下，CPU 如何执行到 C 函数，并把字符输出到终端？

本周不要求修改实验代码。重点是能运行、能观察、能解释。

## 2. 学习目标

完成本实验后，你应该能够：

- 说出 miniOS 工程中 `boot/`、`kernel/`、`include/`、`Makefile` 的基本作用。
- 解释为什么裸机程序先执行启动汇编，而不是直接从 `main()` 开始。
- 解释进入 C 函数前为什么必须设置 `$sp`。
- 说明 `kernel_main()`、`printk()` 和 UART 输出之间的关系。
- 使用命令完成环境检查、编译、运行和基础反汇编观察。
- 在实验报告中记录真实命令输出，而不是只写预期结果。

## 3. 实验前准备

推荐在 Linux 或 WSL Ubuntu 中完成本实验。Windows PowerShell 可以用于查看文件和环境检查，但 LoongArch 裸机实验的最终验证以 Linux/WSL 中的交叉编译和 QEMU 运行为准。

需要的工具：

- `make`
- `qemu-system-loongarch64`
- `loongarch64-linux-gnu-gcc`
- `loongarch64-linux-gnu-objdump`
- `gdb-multiarch`

如果工具尚未安装，先阅读：

- `../manual_wsl_ubuntu_install.md`
- `../environment_check.md`

进入仓库目录后再开始实验。示例：

```bash
cd miniOS
```

如果你的仓库在 Windows 磁盘中，WSL 路径通常类似：

```bash
cd /mnt/<盘符>/<你的课程工作目录>/miniOS
```

## 4. 工程目录导览

先观察工程目录：

```bash
ls
```

本周需要认识这些文件和目录：

```text
boot/             启动汇编代码，本周重点看 boot/start.S
kernel/           内核 C 代码、链接脚本和最小输出实现
include/          头文件，保存函数声明和硬件地址定义
lib/              后续周次使用的汇编库函数
scripts/          环境检查脚本
docs/             实验文档和移植说明
Makefile          编译、运行、调试入口
```

本周重点文件：

- `boot/start.S`：内核入口，设置栈，调用 C 函数。
- `kernel/main.c`：本周从 `kernel_main()` 观察 Hello 输出。
- `kernel/printk.c`：最小字符串输出。
- `include/uart.h`：QEMU `virt` 平台 UART 地址定义。
- `kernel/linker.ld`：告诉链接器内核入口和各段布局。
- `Makefile`：把源码编译成 `build/minios.elf`，并启动 QEMU。

## 5. 环境检查

先运行环境检查脚本：

```bash
sh scripts/check-env.sh
```

如果环境完整，你应该能看到各工具存在的检查结果。不同系统输出格式可能不同，但至少要确认以下命令可用：

```text
make
qemu-system-loongarch64
loongarch64-linux-gnu-gcc
loongarch64-linux-gnu-objdump
```

如果某个工具缺失，不要在报告中写“已通过”。应记录真实情况，例如：

```text
环境检查未通过：找不到 qemu-system-loongarch64。
下一步：安装 qemu-system-misc 后重新执行 sh scripts/check-env.sh。
```

## 6. 编译 miniOS

清理旧构建结果：

```bash
make clean
```

重新编译：

```bash
make
```

编译成功后，通常会生成：

```text
build/minios.elf
```

如果 `make` 失败，先看第一条真正的错误信息。常见原因是：

- 没有安装 `make`。
- 没有安装 LoongArch 交叉编译器。
- 当前目录不是 miniOS 仓库根目录。
- 路径中有特殊字符导致某些旧工具处理失败。

报告中应记录实际失败命令和错误摘要。

## 7. 运行 QEMU

编译成功后运行：

```bash
make run
```

第 1 周最小验收输出为：

```text
Hello miniOS on LoongArch64
```

如果直接使用 `master`，可能已经包含第 2 周 `.data/.bss` 检查代码，所以你还可能看到类似后续验证输出。第 1 周建议从 tag 创建实验分支：

```bash
git fetch --tags
git switch -c my-week01-lab week01-qemu-hello
```

第 1 周只验收 `Hello miniOS on LoongArch64` 这条启动输出链路；不要把 `.data/.bss` 当成本周必须解释的内容。

如果看不到输出，先检查：

- 是否已经成功执行 `make`。
- 是否在正确仓库目录中运行 `make run`。
- 是否安装了 `qemu-system-loongarch64`。
- QEMU 是否被其他终端输出覆盖。

## 8. 退出 QEMU

`make run` 使用 `-nographic` 模式，QEMU 会占用当前终端。

常用退出方式：

```text
Ctrl-a x
```

操作方法是先按 `Ctrl-a`，松开后再按 `x`。

如果终端没有响应，可以新开一个终端查找并结束 QEMU 进程。实验报告中应说明你如何退出 QEMU。

## 9. 启动路径总览

普通 C 程序通常从 `main()` 开始，是因为操作系统和 C 运行库已经提前完成了大量准备工作。

miniOS 是裸机程序。QEMU 加载 `build/minios.elf` 后，CPU 从链接脚本指定的入口开始执行。这个入口不是 C 语言的 `main()`，而是汇编符号 `_start`。

本周执行路径是：

```text
QEMU 加载 build/minios.elf
 ↓
CPU 进入 _start
 ↓
boot/start.S 设置 $sp
 ↓
调用 kernel_main()
 ↓
kernel_main() 调用 printk()
 ↓
printk() 逐字符写 UART
 ↓
QEMU 把 UART 输出显示到终端
```

你不需要一次记住所有细节，但要能沿着文件找到这条路径。

## 10. 阅读 boot/start.S

打开：

```text
boot/start.S
```

重点观察三个问题：

1. `_start` 在哪里？
2. `$sp` 是在哪里设置的？
3. `kernel_main` 是在哪里被调用的？

阅读时可以把它理解成“进入 C 语言之前的准备代码”。C 函数需要栈来保存返回地址、局部变量和调用现场。如果不先设置 `$sp`，C 代码即使能跳进去，也可能很快运行异常。

本周不要求你掌握所有 LoongArch 指令。先抓住启动汇编的职责：

- 提供最早的入口。
- 建立最小运行环境。
- 跳转或调用 C 语言内核主函数。
- 如果 C 函数返回，则进入停止循环，避免 CPU 跑飞。

## 11. 阅读 kernel/main.c

打开：

```text
kernel/main.c
```

重点找到：

```text
kernel_main
```

本周只观察它如何输出：

```text
Hello miniOS on LoongArch64
```

如果文件中还有后续周次检查代码，先不要展开。本周先回答：

- 谁调用了 `kernel_main()`？
- `kernel_main()` 调用了哪个输出函数？
- 输出字符串和 QEMU 终端中看到的内容是否一致？

## 12. 阅读 printk 与 UART 输出

继续查看：

```text
kernel/printk.c
include/printk.h
include/uart.h
```

理解顺序：

```text
kernel_main()
 ↓
printk()
 ↓
uart_putc()
 ↓
UART0_BASE
```

`printk()` 是 miniOS 自己提供的最小输出函数，不是标准 C 库的 `printf()`。

裸机程序不能直接使用 `printf()`，因为此时没有完整操作系统，也没有标准输出设备抽象。miniOS 只能直接操作硬件地址。这里的硬件地址由 `include/uart.h` 给出，QEMU `virt` 平台会把这个 UART 输出显示到终端。

## 13. 常用命令解释

环境检查：

```bash
sh scripts/check-env.sh
```

清理构建结果：

```bash
make clean
```

编译：

```bash
make
```

运行：

```bash
make run
```

反汇编观察：

```bash
loongarch64-linux-gnu-objdump -d build/minios.elf | less
```

在反汇编中可以搜索：

```text
_start
kernel_main
```

基础调试入口：

```bash
make debug
```

另开一个终端连接 GDB：

```bash
gdb-multiarch build/minios.elf
```

进入 GDB 后：

```gdb
target remote :1234
break _start
break kernel_main
continue
```

GDB 调试是课堂 Demo 的重要内容。自学时如果暂时没有跑通 GDB，可以先完成环境检查、编译和 QEMU 输出，并在报告中说明调试步骤未完成的原因。

## 14. 常见错误与处理

| 现象 | 可能原因 | 处理方式 |
|---|---|---|
| `make: command not found` | 没有安装 `make` | 在 Linux/WSL 中安装 `make` 后重试 |
| `loongarch64-linux-gnu-gcc: command not found` | 没有安装交叉编译器 | 安装 `gcc-loongarch64-linux-gnu` |
| `qemu-system-loongarch64: command not found` | 没有安装 QEMU LoongArch 支持 | 安装 `qemu-system-misc` |
| `make run` 后没有 Hello 输出 | 编译失败、镜像不存在或 QEMU 未正确启动 | 先重新执行 `make clean` 和 `make`，确认 `build/minios.elf` 存在 |
| 不知道如何退出 QEMU | `-nographic` 模式占用终端 | 使用 `Ctrl-a x` |
| 输出中还有 `.data/.bss` | 当前分支包含第 2 周代码 | 第 1 周只验收 Hello 输出链路 |
| 反汇编命令打不开 `less` | 系统没有安装 `less` | 直接去掉管道：`loongarch64-linux-gnu-objdump -d build/minios.elf` |

如果错误不在表中，报告中至少记录：

- 执行的命令。
- 完整错误信息或关键错误行。
- 你已经尝试过的处理方式。
- 下一步准备如何排查。

## 15. 实验验收标准

本周验收分为三类。

必须完成：

- 能说明 miniOS 工程主要目录作用。
- 能执行 `sh scripts/check-env.sh`，并记录真实结果。
- 能执行 `make clean` 和 `make`，或记录明确失败原因。
- 能执行 `make run`，或记录明确失败原因。
- 如果 QEMU 跑通，能看到并记录：

```text
Hello miniOS on LoongArch64
```

必须理解：

- CPU 为什么先进入 `boot/start.S`。
- 为什么进入 C 函数前需要设置 `$sp`。
- 为什么 miniOS 使用 `printk()` 而不是 `printf()`。
- UART 在本实验中的作用。

不作为第 1 周验收：

- 解释 `.data/.bss` 初始化细节。
- 修改启动代码。
- 完成开发板迁移。
- 编写新的输出驱动。

## 16. 实验报告模板

可以直接按下面结构撰写实验报告。

````markdown
# 第 1 周实验报告：QEMU Hello miniOS

### 1. 实验环境

- 操作系统：
- 是否使用 WSL：
- QEMU 版本：
- LoongArch GCC 版本：
- 仓库路径：

### 2. 环境检查结果

执行命令：

```bash
sh scripts/check-env.sh
```

真实输出摘要：

```text
在这里填写真实输出或关键结果。
```

### 3. 编译结果

执行命令：

```bash
make clean
make
```

结果：

```text
成功生成 build/minios.elf，或填写失败原因。
```

### 4. QEMU 运行结果

执行命令：

```bash
make run
```

真实输出：

```text
Hello miniOS on LoongArch64
```

如果未成功运行，填写失败原因和下一步处理计划。

### 5. 源码阅读记录

- `boot/start.S` 中 `_start` 的作用：
- `$sp` 设置位置和作用：
- `kernel_main()` 在哪里被调用：
- `printk()` 输出路径：
- UART 地址定义在哪里：

### 6. 错误与解决过程

| 问题 | 原因 | 处理方式 | 是否解决 |
|---|---|---|---|
| | | | |

### 7. AI 使用记录

- 我向 AI 提问的问题：
- AI 帮助我理解了什么：
- 我是否让 AI 直接生成实验代码：否

### 8. 思考题回答

1. CPU 第一条指令在哪里？
2. 为什么裸机程序不是从 `main()` 开始？
3. 为什么进入 C 函数前要设置 `$sp`？
4. 为什么 miniOS 不能直接使用 `printf()`？
5. QEMU 在本课程中解决了什么问题？
````

注意：报告中的运行结果必须来自真实执行。没有执行就写“未执行”，失败就写失败原因。

## 17. AI 共学要求

第 1 周可以使用 AI 辅助理解，但必须保留学生自己的阅读和实验过程。

允许：

- 让 AI 解释 `boot/start.S` 的作用。
- 让 AI 画出 miniOS 启动流程。
- 让 AI 解释 QEMU、UART、`printk()` 的作用。
- 把真实错误信息发给 AI，请它帮助分析可能原因。

不允许：

- 不读源码，直接让 AI 代写实验报告。
- 让 AI 修改或生成本周实验代码。
- 没有运行命令，却让 AI 根据代码推测“实验通过”。

不允许让 AI 直接生成实验代码。

建议提问方式：

```text
请根据 boot/start.S 解释 _start、$sp 和 kernel_main 之间的关系。
```

```text
请把 CPU -> boot/start.S -> kernel_main() -> printk() -> UART 的流程画成文本流程图。
```

## 18. 思考题

1. CPU 第一条指令在哪里？它由哪个文件和哪个符号提供？
2. 为什么裸机程序不是从 `main()` 开始？
3. 为什么进入 C 函数前要设置 `$sp`？
4. 为什么 miniOS 不能直接使用 `printf()`？
5. QEMU 在本课程中解决了什么问题？
6. 如果 `kernel_main()` 返回，CPU 接下来应该做什么？为什么？
7. `printk()` 和 `printf()` 的差别体现了裸机程序的哪个特点？

## 19. 拓展阅读

完成本周必做内容后，可以继续阅读：

- `README.md`：了解仓库总体说明。
- `../course_release_index.md`：了解每周实验和 tag 发布方式。
- `../manual_wsl_ubuntu_install.md`：补齐 WSL Ubuntu 环境安装。
- `../QEMU-to-Loongson-Pioneer-Porting-Guide.md`：了解为什么所有实验先在 QEMU 跑通，再考虑迁移。

拓展阅读不属于第 1 周验收重点。第 1 周最重要的是把 Hello 链路真实跑通，并能沿着源码解释它。
