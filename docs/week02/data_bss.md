# 第 2 周实验：.data/.bss 与内存初始化

## 1. 实验目标

本周目标是在第 1 周 Hello miniOS 的基础上，理解 C 语言全局变量在裸机程序中的存放和初始化过程。

学生需要完成：

- 区分 `.data` 和 `.bss`。
- 理解为什么 `.bss` 必须在进入 C 代码前清零。
- 观察 `boot/start.S` 中的 `clear_bss`。
- 理解 C 代码如何调用汇编实现的 `memset`、`memcpy`、`strlen`。
- 通过 QEMU 输出验证 `.data/.bss` 行为。

## 2. 背景知识

普通 Linux 程序启动时，操作系统加载器和 C 运行库会准备数据段和清零 `.bss`。miniOS 是裸机程序，这些工作要由启动代码自己完成。

常见段的含义：

- `.text`：代码和只读指令。
- `.rodata`：只读字符串和常量。
- `.data`：有初始值的全局变量或静态变量。
- `.bss`：没有显式初始值的全局变量或静态变量，进入 C 前应为 0。

## 3. 从第 1 周到第 2 周

第 1 周关注最小路径：

```text
_start → 设置 sp → kernel_main → printk → UART
```

第 2 周在这个路径上增加一件事：

```text
_start → 设置 sp → clear_bss → kernel_main
```

也就是在 C 代码读取未初始化全局变量之前，先把 `.bss` 区间清零。

## 4. 关键代码

`kernel/main.c` 中的两个变量用于观察 `.data/.bss`：

```c
static char bss_buffer[16];
static char data_message[] = "data section ok";
```

`data_message` 有初始值，应位于 `.data`，运行时能读出字符串。

`bss_buffer` 没有显式初始值，应位于 `.bss`，启动后第一个字节应为 0。

`boot/start.S` 中的 `clear_bss` 使用链接脚本提供的符号：

```asm
la.global   $t0, __bss_start
la.global   $t1, __bss_end
```

它从 `__bss_start` 到 `__bss_end` 逐字节写 0，保证 C 语言看到的未初始化全局变量符合预期。

`lib/string.S` 提供三个汇编函数：

- `memset`：把一段内存设置为指定字节。
- `memcpy`：从源地址复制字节到目标地址。
- `strlen`：计算字符串长度。

这些函数让学生看到 C 文件可以调用汇编文件中导出的函数名。

## 5. 编译与运行

先检查环境：

```bash
sh scripts/check-env.sh
```

再编译运行：

```bash
make clean
make
make run
```

如果工具链或 QEMU 不存在，记录为“未执行”或“失败”，并写出下一步安装或复查命令。

## 6. 预期输出

第 1-2 周合并验证输出为：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

其中：

- `Hello miniOS on LoongArch64` 验证第 1 周启动和串口输出。
- `data section ok` 验证 `.data` 中的初始化字符串可读。
- `bss section cleared` 验证 `.bss` 已被 `clear_bss` 清零。
- `week1-week2 check done` 表示本阶段检查路径执行完毕。

## 7. 常见错误

- 没有调用 `clear_bss`：`.bss` 变量可能不是 0，输出缺少 `bss section cleared`。
- 链接脚本没有定义 `__bss_start` 或 `__bss_end`：启动汇编无法定位 `.bss` 范围。
- 忘记编译 `lib/string.S`：链接时可能找不到 `memset`、`memcpy` 或 `strlen`。
- 使用宿主机 x86_64 GCC：会生成错误架构的目标文件，不能在 LoongArch QEMU 中运行。
- 未实测就写“已测试通过”：违反课程测试记录要求。

## 8. 思考题

1. `.data` 和 `.bss` 的区别是什么？
2. 为什么 `.bss` 清零必须发生在 `kernel_main()` 之前？
3. `__bss_start` 和 `__bss_end` 是谁提供的？
4. C 代码为什么能调用 `lib/string.S` 中的汇编函数？
5. 如果 QEMU 输出只有 Hello，没有 `.data/.bss` 检查结果，应该从哪些文件排查？
