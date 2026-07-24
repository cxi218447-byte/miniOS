# QEMU→龙芯先锋板移植指南

## 阶段划分

第一阶段：教学验证

- 平台：QEMU `virt` machine
- 工具链：LoongArch64 GCC
- 输出方式：QEMU 串口输出
- 约束：所有实验必须先在 QEMU 跑通，不依赖真实开发板

第二阶段：硬件迁移

- 平台：龙芯先锋板
- 工具链：龙芯官方工具链或板上本机 GCC
- 重点：UART 驱动适配、中断控制器适配、启动方式适配
- 约束：迁移前必须保留 QEMU 可运行版本作为回归基线

## 通用差异

| 项目 | QEMU virt | 龙芯先锋板 | 移植修改点 |
| --- | --- | --- | --- |
| 启动方式 | `qemu-system-loongarch64 -M virt -kernel build/minios.elf` | 通常由 PMON/U-Boot/固件加载 | 明确固件加载地址、入口地址、镜像格式 |
| 串口 | 本实验使用 `UART0_BASE` 作为 QEMU 串口 MMIO 基址 | 以板卡原理图/设备树为准 | 修改 `include/uart.h`，必要时增加 UART 初始化 |
| 内存布局 | 链接脚本固定内核入口 | 取决于板载内存和固件保留区 | 修改 `kernel/linker.ld` |
| 中断控制器 | QEMU 虚拟控制器 | 板载中断控制器 | 第 5 周以后单独抽象 irqchip |
| 调试 | QEMU `-S -s` + GDB | JTAG、串口日志或板载 GDB server | 保留串口日志，增加硬件调试说明 |

## 第 1 周：Hello World 输出

QEMU 版本：

- 目标：`_start` 设置栈后进入 `kernel_main()`，通过串口输出 Hello。
- 编译：`make`
- 运行：`make run`
- 预期输出：

```text
Hello miniOS on LoongArch64
```

龙芯先锋板版本：

- 固件加载 `build/minios.elf` 或转换后的裸二进制镜像。
- 串口终端连接开发板默认 UART，常用参数为 `115200 8N1`，实际以板卡手册为准。
- 若固件不支持 ELF，使用 `build/minios.bin` 并指定加载地址和入口地址。

差异分析：

- QEMU 的 `virt` 平台设备地址稳定且便于复现。
- 先锋板的 UART 基址、时钟、复位状态和固件加载地址都可能不同。
- QEMU 可以直接把串口映射到终端，开发板需要真实串口线和终端软件。

移植修改点：

- 修改 `include/uart.h` 中的 `UART0_BASE`。
- 如开发板 UART 默认未初始化，补充波特率、FIFO、线路控制寄存器初始化。
- 修改 `kernel/linker.ld` 的入口地址，使其匹配固件加载位置。

## 第 2 周：.data/.bss 与 C/汇编混合编译

QEMU 版本：

- 目标：验证 `.data` 中已初始化全局变量可读，`.bss` 被启动汇编清零。
- 编译：`make clean && make`
- 运行：`make run`
- 预期输出：

```text
data section ok
bss section cleared
week1-week2 check done
```

龙芯先锋板版本：

- 启动路径仍复用 `_start -> clear_bss -> kernel_main`。
- 串口输出一致后，再确认全局变量地址是否落在有效 RAM 范围。

差异分析：

- QEMU 内存布局由 `virt` machine 和链接脚本共同决定。
- 先锋板上固件可能占用低地址或保留部分内存，链接地址不能随意选择。
- 如果镜像由固件搬运，`.data` 的加载地址和运行地址必须一致，或显式实现搬运。

移植修改点：

- 根据开发板内存图调整 `kernel/linker.ld`。
- 必要时增加 `.data` 从 LMA 到 VMA 的拷贝逻辑。
- 保留 `clear_bss`，并用串口打印 `__bss_start/__bss_end` 辅助排查。

## 迁移原则

1. 每周实验先在 QEMU 通过，再创建对应的先锋板分支或配置。
2. 不把板级地址散落在 C 文件中，统一放到 `include/` 或后续 `platform/` 目录。
3. 每次迁移只改一个平台差异点：入口地址、UART、中断控制器、计时器分开验证。
4. QEMU 输出作为回归标准，开发板输出必须先做到同样的最小文本。
