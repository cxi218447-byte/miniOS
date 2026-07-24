# LoongArch 汇编 miniOS 实验测试报告

## 0. 环境准备

目标：

- 第一阶段所有实验先在 QEMU `virt` machine 跑通。
- 使用 LoongArch64 GCC 交叉编译。
- 使用串口输出作为最小可观察结果。
- 暂不依赖真实龙芯开发板。

当前机器检查结果：

| 工具 | 命令 | 状态 |
| --- | --- | --- |
| WSL | `wsl --status` | 命令存在，但无可用 Linux 发行版 |
| Make | `make --version` | 未找到 |
| QEMU | `qemu-system-loongarch64 --version` | 未找到 |
| LoongArch GCC | `loongarch64-linux-gnu-gcc --version` | 未找到 |
| Objcopy | `loongarch64-linux-gnu-objcopy --version` | 未找到 |
| GDB | `gdb` / `gdb-multiarch` | 未找到 |

推荐安装命令：

```sh
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

Windows 安装 WSL Ubuntu：

```powershell
wsl --install -d Ubuntu --location "<你的课程工作目录>\env\wsl\Ubuntu"
```

注意：WSL Ubuntu 安装由学生手工执行，安装目录必须位于项目上一级父目录
`env\wsl\Ubuntu`，不得放在 C 盘。手工步骤见
`docs/manual_wsl_ubuntu_install.md`。

环境检查命令：

```sh
sh scripts/check-env.sh
```

## 1. 第 1 周：Hello World 输出、启动代码、仓库初始化

实验目标：

- 建立 miniOS 仓库骨架。
- 理解 `_start` 是内核第一段执行代码。
- 设置内核栈，并跳转到 C 语言 `kernel_main()`。
- 通过串口输出 Hello World。

核心代码：

```asm
_start:
    la.global   $sp, boot_stack_top
    bl          clear_bss
    bl          kernel_main
```

```c
void kernel_main(void)
{
    printk("miniOS booting...\n");
    printk("Hello, LoongArch miniOS!\n");
}
```

QEMU 版本：

```sh
make clean
make
make run
```

QEMU 运行命令展开后等价于：

```sh
qemu-system-loongarch64 -M virt -m 512M -nographic -kernel build/minios.elf
```

QEMU 预期输出：

```text
miniOS booting...
Hello, LoongArch miniOS!
```

龙芯先锋板版本：

- 使用龙芯官方工具链或开发板本机 GCC 编译。
- 如果固件支持 ELF，加载 `build/minios.elf`。
- 如果固件只支持裸镜像，加载 `build/minios.bin`，并指定入口地址。
- 串口终端参数以开发板手册为准，常见起点是 `115200 8N1`。

差异分析：

- QEMU 的 `virt` machine 使用固定的虚拟设备模型，适合教学复现。
- 开发板的 UART 地址、固件加载地址和串口初始化状态取决于板级设计。
- QEMU 串口直接出现在终端，开发板需要串口线和终端软件。

移植修改点：

- 修改 `include/uart.h` 中的 `UART0_BASE`。
- 修改 `kernel/linker.ld` 中的内核入口地址。
- 如开发板 UART 未初始化，增加 UART 波特率和 FIFO 初始化代码。

常见错误和排查：

- 找不到 `loongarch64-linux-gnu-gcc`：安装交叉工具链或设置 `CROSS_COMPILE`。
- QEMU 无输出：检查 `-M virt`、`-nographic`、串口基地址和链接地址。
- 链接失败：检查 `kernel/linker.ld` 是否包含 `ENTRY(_start)`。

## 2. 第 2 周：.data/.bss 初始化、内存寻址、C 与汇编混合编译

实验目标：

- 区分 `.text`、`.rodata`、`.data`、`.bss`。
- 用启动汇编清零 `.bss`。
- 在 C 代码中调用汇编实现的 `memset()`、`memcpy()`、`strlen()`。

核心代码：

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

```c
static char bss_buffer[16];
static char data_message[] = "data section ok";

memset(buf, 0, sizeof(buf));
memcpy(buf, data_message, strlen(data_message));
```

QEMU 版本：

```sh
make clean
make
make run
```

QEMU 预期输出：

```text
miniOS booting...
Hello, LoongArch miniOS!
data section ok
bss section cleared
week1-week2 check done
```

龙芯先锋板版本：

- 启动流程保持 `_start -> clear_bss -> kernel_main`。
- 串口输出必须先与 QEMU 结果一致。
- 若输出停在 Hello 之后，优先检查 `.data/.bss` 地址是否落在有效 RAM。

差异分析：

- QEMU 内存布局主要由链接脚本控制。
- 开发板上固件可能占用部分内存，裸机内核入口地址不能直接照搬 QEMU。
- 如果开发板固件搬运镜像，`.data` 的加载地址和运行地址需要额外确认。

移植修改点：

- 根据先锋板内存图调整 `kernel/linker.ld`。
- 必要时增加 `.data` 拷贝逻辑。
- 保留并测试 `clear_bss`，必要时打印 `__bss_start`、`__bss_end`。

常见错误和排查：

- `.bss` 未清零：检查链接脚本是否导出 `__bss_start` 和 `__bss_end`。
- C 调不到汇编函数：检查 `lib/string.S` 中是否声明 `.globl`。
- 输出乱码或无输出：先回到第 1 周，只验证 `printk("A\n")`。
- 程序异常停止：检查栈地址、链接地址和 QEMU/开发板加载地址是否一致。

## 本轮验证结论

已完成：

- Git 仓库初始化。
- 第 1-2 周代码路径收敛。
- QEMU 优先的 Makefile。
- 环境检查脚本。
- 《QEMU→龙芯先锋板移植指南》初版。

未完成：

- 当前机器缺少 `make`、QEMU 和 LoongArch64 GCC，无法在本机真实编译运行。
- WSL Ubuntu 需要学生手工安装到 `<你的课程工作目录>\env\wsl\Ubuntu`。

下一步：

1. 安装 WSL Ubuntu 或进入已有 Linux 环境。
2. 安装 LoongArch64 GCC、QEMU、Make、GDB。
3. 执行 `sh scripts/check-env.sh`。
4. 执行 `make clean && make && make run`。
5. 串口输出与第 2 周预期一致后，再继续第 3 周。
