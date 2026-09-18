# 2K0300 开发板上手指南（学生版：接线→装驱动→串口连通→改代码→编译→上板→命令行 shell）

> 本学期人手一块真实龙芯 2K0300（先锋派）开发板，这是第 12 次课（板级
> 迁移 + 综合实验：从 miniOS 到 Agent OS）的实验指导书。从第 11 次课的
> 检查点（`12-board-agent-demo`）出发，一步步把代码改成 2K0300 版本、编译、
> 送上板、跑起来（§0-7），再补一个命令行 shell 把板级迁移之外的工作量
> 填满 4 学时（§8-9）。跟着做，照抄这里给的代码和命令，能编译过、能在
> 串口里看到 week01-08 的验收输出就算完成板级迁移部分。

## 0. 需要准备的资料/软件

| 东西 | 用途 | 获取方式 |
|---|---|---|
| 板卡官方资料网盘 | 官方《2K0300 先锋派快速使用指南》、驱动、U-Boot/内核源码、设备树等 | 板卡自带说明书上的网盘链接；截至目前拿到的链接是`https://pan.baidu.com/s/1l1-X7BOmLP0jimjzj4qHeg?pwd=1234`（提取码 1234）——**这个链接可能随板卡批次/厂商更新而变化，以你自己拿到的说明书为准，对不上就找购板渠道要最新的** |
| TYPE-C 数据线 | 接开发板 UART0 调试口（同时供电） | 随板附带，或自备一根支持数据传输的 TYPE-C 线（不能是纯充电线） |
| 串口驱动 | 让 Windows 识别出 USB 转串口设备、分配 COM 口 | 见 §2，多数板子用的是沁恒 WCH 的芯片，从网盘或 [沁恒官网](https://www.wch.cn/) 下载对应驱动 |
| 串口终端软件 | 打开 COM 口看输出、发命令 | PuTTY 或 Tera Term（Windows 图形界面，二选一即可）；WSL 里的 minicom/screen 不推荐，因为串口设备挂在 Windows 侧，不好穿透到 WSL |
| 交叉编译工具链 | 编译 miniOS 的 2K0300 版本 | 已经装好，见 `docs/student_env_runbook.md`，不用重装 |

## 1. 接线与上电

1. TYPE-C 一端接开发板的 **UART0 调试口**（不是给负载供电的那个 USB-A 口），另一端接电脑 USB 口。
2. 按下开发板 POWER 键上电（部分板子插上 TYPE-C 就自动上电，具体看你板子的丝印说明）。
3. 电源指示灯亮，说明板子上电正常；这一步过不去先排查供电，不用往下走。

## 2. Windows 识别开发板、装串口驱动

### 2.1 先确认 Windows 有没有认出设备

打开「设备管理器」（右键开始菜单 → 设备管理器），看「端口 (COM 和 LPT)」
这一栏：

- **能看到一个新的 `COMx`**：驱动已经装好，直接跳到 §3。
- **看不到新端口，但「通用串行总线控制器」或其它分类里多了一个带黄色感叹号
  / 显示"USB Serial"之类名字但没有 COM 口的设备**：驱动没装对，继续 §2.2。

也可以用 PowerShell 快速看一眼（在 Claude Code 里输入 `!` 加命令直接跑，
或者自己开 PowerShell 窗口）：

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.Class -eq 'Ports' -or $_.FriendlyName -match 'USB|Serial|UART|CH340|CH343|CP210|FTDI' } | Select-Object FriendlyName, InstanceId, Status
```

如果某一条 `Status` 是 `Error`，可以再挖一下具体原因（多半是"代码 28：
未安装驱动"）：

```powershell
Get-CimInstance Win32_PnPEntity | Where-Object { $_.Status -eq 'Error' } | Select-Object Name, DeviceID, ConfigManagerErrorCode
```

### 2.2 装驱动

先看设备的 `InstanceId`/`HardwareID` 里的 `VID_xxxx&PID_xxxx`，对应买的是
哪颗 USB 转串口芯片（同一款板子不同批次可能用不同芯片，以你自己看到的为
准，下表第一行是实测确认过的）：

| 常见芯片 | VID\_PID 举例 | 对应驱动 |
|---|---|---|
| WCH CH340K | `VID_1A86&PID_7522` | 沁恒 **CH341SER**（教师机实测：Windows 自动装的就是这个驱动，设备名显示"USB-SERIAL CH340K"） |
| WCH CH9102/CH343 | 其它 `VID_1A86&PID_xxxx` | 沁恒 **CH343SER**（比 CH341SER 新，如果 CH341SER 装完还是没反应，换这个试） |
| Silicon Labs CP210x | `VID_10C4&PID_EA60` 等 | Silicon Labs 官方 CP210x 驱动 |

驱动优先从 §0 的板卡官方网盘拿（厂商验证过、兼容性有保证）；网盘里没有
就去沁恒官网对应下载页拿：

- CH341SER：<https://www.wch.cn/downloads/CH341SER_ZIP.html>
- CH343SER：<https://www.wch.cn/downloads/CH343SER_ZIP.html>

这两个页面是前端动态加载的，打开后找页面里 "CH341SER"/"CH343SER" 那一条
对应的下载/立即下载链接点开，下载下来是一个 `.ZIP` 压缩包。

**解压安装步骤：**

1. 把下载的 `.ZIP` 解压到一个**路径不含中文、不含空格**的目录（例如
   `D:\drivers\CH341SER`）——装驱动这类程序对中文路径经常不兼容，踩过坑
   的话优先怀疑这个。
2. 解压出来的文件夹里找 `SETUP.EXE`（有的版本文件名是 `CH341SER.EXE` /
   `CH343SER.EXE`），双击运行。如果弹出"是否允许此应用对设备进行更改"
   的用户账户控制（UAC）提示，点 **是**——装驱动必须要管理员权限。
3. 会弹出一个小窗口，通常只有 **INSTALL（安装）** 和 **UNINSTALL（卸载）**
   两个按钮（有的是中文"安装驱动"）。点 **INSTALL**，等它提示安装成功
   （一般几秒钟就好）。
4. 关掉安装窗口，**拔掉再重新插上** TYPE-C 线（不重新插拔的话 Windows
   有时不会立刻重新枚举设备）。
5. 打开设备管理器，「端口 (COM 和 LPT)」下应该出现一个新的 `COMx`，
   设备名类似 `USB-SERIAL CH340` / `CH343 USB to UART` 之类。记下这个口号，
   下一步要用。

如果装完还是没有出现 `COMx`：先按 §2.1 的 PowerShell 命令看一眼设备状态，
`ConfigManagerErrorCode` 不是 0 的话把这个值发给老师；也可以直接换成
CH343SER 那个包重试一次（两个驱动包互不冲突，可以都装）。

## 3. 打开串口终端，验证连通

1. 打开 PuTTY（或 Tera Term），新建一个 **Serial** 连接：
   - 端口：上一步记下的 `COMx`
   - 波特率：**115200**
   - 数据位：**8**，停止位：**1**，校验：**无**，硬件流控：**无**
2. 按开发板 POWER 键（或复位键）重新上电。
3. **预期**：终端里能看到 U-Boot 的启动打印（`LoongArch Initializing ...`
   之类），几秒后进入预置系统或停在 U-Boot 菜单。

看到输出，说明串口链路（线、驱动、终端配置）全部正常——**这一步不通过，
后面移植 miniOS 的任何"无输出"都无法判断是代码问题还是线/口问题**，一定
先跑通这一步再往下做。

看不到任何输出，按下面顺序排查：

| 现象 | 先查 |
|---|---|
| 终端里完全没反应 | COM 口选对了没有；波特率是不是 115200；有没有按电源/复位键触发一次新的启动打印 |
| 能看到乱码 | 波特率/数据位/校验设置和板子实际不一致 |
| 设备管理器里 COM 口时有时无、拔插会消失 | 换一根数据线（很多 TYPE-C 线只能充电不能传数据）；换一个 USB 口（优先用主板自带口，不要用容易掉电的 USB Hub） |

### 3.1 进入预置系统后，控制台被内核日志刷屏

如果没有手动截住 U-Boot（没按 `m`/`c`），板子会自动 `boot` 进预置的
Linux/Busybox 系统。这时终端里可能会每隔一段时间自动蹦出一堆类似下面的
内核日志，把你正在看/正在敲的东西刷掉：

```
[  994.233773] usb 1-1: request firmware rtlwifi/rtl8188fufw.bin
[  994.233773] usb 1-1: request firmware rtlwifi/rtl8188fufw.bin loaded
```

这是板载/外接的 rtl8188fu WiFi 模块在反复重新枚举、重新加载固件（后面带
`loaded` 说明每次都成功，不是报错），**不影响硬件安全**，纯粹是刷屏烦人，
不用担心板子坏了。

**关闭方法**（当前这次开机的会话内有效，断电重启会恢复，不影响系统本身）：

```
echo 0 > /proc/sys/kernel/printk
```

想更彻底一点、连带把这个反复触发的驱动卸载掉：

```
lsmod | grep -i rtl
rmmod <上面查到的模块名，通常是 rtl8188fu 或 8188fu>
```

**坑 1：默认登录账户不一定是 root。** 有的镜像默认自动登录的是普通用户
（比如 `loongson@loongson-gd:~$` 这种提示符），直接执行上面的命令会报
`Permission denied`。先切到 root：

```
su -
```

密码先试 `123`（《快速使用指南》里写的默认 root 密码），不行再试空密码
（直接回车）或跟登录用户名相同的密码。

**坑 2：`sudo` 配合重定向不生效。** 如果系统装了 `sudo`，不要写成

```
sudo echo 0 > /proc/sys/kernel/printk   # 错误，仍然 Permission denied
```

`>` 重定向是当前这个非 root 的 shell 在做的，`sudo` 只提权了 `echo` 这一条
命令本身，文件还是打不开。正确写法是让 `sudo` 提权整个 shell：

```
sudo sh -c 'echo 0 > /proc/sys/kernel/printk'
```

**注意**：以上都是在**已经进入 Linux 系统之后**才能做的操作，跟下面
miniOS 实验要用的 U-Boot console 是两个不同阶段。如果你是为了继续做
miniOS 上板实验，清完屏后记得 `reboot`，这次开机时按住 `m`（进菜单）或
按 `c`（直接进 console），别让它又自动 `boot` 进 Linux。

## 4. 把仓库改成"平台可插拔"结构

**先建立本次课的个人实验分支**（每次课都要重新做一次，不是学期初做过
就行——教师每次课都会发布新的检查点 tag，哪怕上次已经 `fetch` 过，这次
开始前也要重新 `git fetch --tags`，否则要么找不到 tag，要么代码是过期
的）：

```bash
git fetch --tags
git switch -c my-12-lab 12-board-agent-demo
```

`my-12-lab` 是本地分支，远程没有同名分支是正常现象。若教师尚未发布
tag，以课堂指定 checkpoint 为准。

有了分支之后，目标是：`make`（不带 `PLATFORM` 参数）行为跟之前完全
一样，`make PLATFORM=2k0300` 编译出真机能跑的版本。照下面的步骤改，
改完的结构和值都是真机实测跑通过的，直接抄。

### 4.1 拆分链接脚本

```bash
git mv kernel/linker.ld kernel/linker_qemu_virt.ld
```

新建 `kernel/linker_2k0300.ld`：

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

    .got : ALIGN(8) {
        *(.got .got.*)
    }

    __bss_start = .;
    .bss : ALIGN(4K) {
        *(.bss .bss.*)
        *(COMMON)
    }
    __bss_end = .;
}
```

`.got` 这段是必需的，不是可选优化——如果不显式给它分配位置，链接器会把它当"孤儿段"塞在 `__bss_start = .;` 这行赋值生效的地方，`clear_bss` 每次开机都会把它连带清零，之后任何用 `la.global` 取地址、还要在函数调用之后继续用这个地址的代码（比如 §8.4 会写到的、给一条命令加一个固定字符串）都会悄悄拿到全 0，表现成"打印不出来但也不报错"，很难查——`kernel/linker.ld`（QEMU 版本的原型）也一并修了这个问题。

### 4.2 拆分 UART 平台头文件

新建目录 `include/platform/`，两个文件：

`include/platform/qemu_virt.h`：

```c
#ifndef MINIOS_PLATFORM_QEMU_VIRT_H
#define MINIOS_PLATFORM_QEMU_VIRT_H

/* QEMU loongarch64 virt 常见 16550 串口地址，高半区直接映射。 */
#define UART0_BASE            0x900000001fe001e0UL
#define UART_LSR_OFF           5
#define UART_TX_EMPTY_MASK     0x20
#define UART_NEEDS_CLOCK_INIT  0

#endif
```

`include/platform/2k0300.h`：

```c
#ifndef MINIOS_PLATFORM_2K0300_H
#define MINIOS_PLATFORM_2K0300_H

#define UART0_BASE             0x8000000016100000UL
#define UART_LSR_OFF            5
#define UART_TX_EMPTY_MASK      0x20
#define UART_NEEDS_CLOCK_INIT   1

#endif
```

### 4.3 `include/uart.h` 改为按平台切换

```c
#ifndef MINIOS_UART_H
#define MINIOS_UART_H

#if defined(PLATFORM_2K0300)
#include "platform/2k0300.h"
#else
#include "platform/qemu_virt.h"
#endif

void uart_platform_init(void);
void uart_putc(char ch);
void uart_puts(const char *s);

#endif
```

### 4.4 `kernel/printk.c` 补轮询 + 平台初始化钩子

```c
#include "printk.h"
#include "uart.h"

void uart_platform_init(void)
{
    /* 实测这颗芯片不需要额外配置就能收发，留空即可。 */
}

void uart_putc(char ch)
{
    volatile unsigned char *uart = (volatile unsigned char *)UART0_BASE;

    /* 等发送保持寄存器空再写，QEMU 的 16550 模型这一位恒为就绪，
     * 这段代码在 QEMU 下原样兼容。 */
    while ((uart[UART_LSR_OFF] & UART_TX_EMPTY_MASK) == 0) {
    }

    *uart = (unsigned char)ch;
}

void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

void printk(const char *s)
{
    uart_puts(s);
}

/* printk_udec / printk_hex 内容不变，照抄现有文件即可。 */
```

这里涉及 `kernel/main.c` 两处**不同位置**的改动，别混在一起：

1. **文件最上面**，跟着已有的一串 `#include` 加一行：
   ```c
   #include "uart.h"
   ```
2. **`void kernel_main(void) { ... }` 函数体内部**——不是文件顶层、不是
   跟在 `#include` 后面——在 `long r;` 这行变量声明**之后**、原来紧接着
   的"使能浮点单元"那段代码**之前**，加一行：
   ```c
   uart_platform_init();
   ```
   加错位置（比如放到函数外面）编译会报 `data definition has no type or
   storage class` / `conflicting types` 这类错误——出现这个报错就是加错
   位置了，回去确认是不是加到 `kernel_main` 函数体里面了。

### 4.5 `Makefile` 加平台开关

```makefile
# 平台选择：qemu_virt（默认）｜2k0300
PLATFORM ?= qemu_virt

ifeq ($(PLATFORM),2k0300)
CFLAGS_PLATFORM := -DPLATFORM_2K0300
LINKER_SCRIPT   := kernel/linker_2k0300.ld
else
CFLAGS_PLATFORM := -DPLATFORM_QEMU_VIRT
LINKER_SCRIPT   := kernel/linker_qemu_virt.ld
endif
```

把原来 `CFLAGS := ...` 那一行下面加 `CFLAGS += $(CFLAGS_PLATFORM)`，再加
一行 `CFLAGS += -MMD -MP`（头文件改了会自动触发重新编译，避免"改了头文件
但没重新编译"这种坑）。

把原来 `LDFLAGS := -T kernel/linker.ld -nostdlib -static` 改成：

```makefile
LDFLAGS := -T $(LINKER_SCRIPT) -nostdlib -static
```

`$(TARGET)` 规则依赖里把 `kernel/linker.ld` 换成 `$(LINKER_SCRIPT)`：

```makefile
$(TARGET): $(OBJS) $(LINKER_SCRIPT)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)
```

文件最后一行加上（配合 `-MMD -MP` 生成的依赖文件）：

```makefile
-include $(OBJS:.o=.d)
```

`run`/`debug` 目标加一个平台保护，防止误在 2k0300 配置下启动 QEMU：

```makefile
run: $(TARGET)
ifneq ($(PLATFORM),qemu_virt)
	@echo "PLATFORM=$(PLATFORM) 不能用 QEMU 运行，请走板级烧录流程"; exit 1
else
	$(QEMU) $(QEMU_ARGS)
endif
```

`debug` 结构一样，只是里面的命令换成原来 `debug` 那行：

```makefile
debug: $(TARGET)
ifneq ($(PLATFORM),qemu_virt)
	@echo "PLATFORM=$(PLATFORM) 不能用 QEMU 调试，请走板级烧录流程"; exit 1
else
	$(QEMU) $(QEMU_ARGS) -S -s
endif
```

### 4.6 先在 QEMU 上回归测试

```bash
make clean
make PLATFORM=qemu_virt
make PLATFORM=qemu_virt run
```

**预期**：串口输出跟改动前完全一样（逐字节一致）。不一致说明改坏了
QEMU 路径，先在这一步排除，不要带着这个不确定性去测板子。

## 5. 编译 2K0300 版本

```bash
make clean
make PLATFORM=2k0300
```

产出 `build/minios.bin`。**注意（真实踩过的坑）**：只改头文件、没改
`.c` 文件本体时，如果没有 §4.5 那个 `-MMD -MP`，`make` 可能静默复用旧的
`.o` 文件——改完平台相关的头文件，不确定的话直接 `make clean` 再编译。

## 6. 把 minios.bin 送进板子内存

到这一步只有串口连着，没有额外硬件，可以先试 U-Boot 自带的 `loady`
（Ymodem 协议）：

1. 先确认支持：在 `=>` 提示符下 `help loady`。
2. 执行：
   ```
   loady 0x9000000000200000
   ```
   会打印 `## Ready for binary (ymodem) download...` 然后卡住等待，这是
   正常的，它在等对端发送文件。
3. 在终端软件里找发送文件的入口：
   - **MobaXterm**：右键终端空白处 → 找 "Zmodem" 相关菜单项（虽然协议名
     写的是 Zmodem，配合 `loady` 实测可用）
   - **Tera Term**（免安装版：<https://github.com/TeraTermProject/teraterm/releases/download/v5.7.0/teraterm-5.7.0-x64.zip>，
     解压直接运行 `ttermpro.exe`）：菜单 **File → Transfer → YMODEM →
     Send...**，官方明确支持 Ymodem，比 MobaXterm 那个含糊的菜单更可靠
   - 选 `build/minios.bin`
4. 传完看 u-boot 打印的 `Total Size`，**必须**跟 `ls -la build/minios.bin`
   看到的字节数对上——不对就是传错文件或传输出问题了，不要往下走。

**如果传输反复报协议错误**（比如 `Retry: Got xx for sector ACK`，重试、
断开终端重连都解决不了）：先试试完全退出终端软件重新打开再来一次；还不行
就换 U 盘方式——U 盘格式化成 **MBR 分区表 + FAT32**（很多 U 盘出厂是
GPT/exFAT，U-Boot 认不了，用 Windows"磁盘管理"转换一下），把 `minios.bin`
拷进去插到板子 USB-A 口：

```
usb start
fatload usb 0:1 0x9000000000200000 minios.bin
```

## 7. 跳转执行

传完确认字节数对上之后：

```
go 0x9000000000200000
```

**预期输出**：能看到 `Hello miniOS on LoongArch64` 打头的一长串验收信息，
一路到 `week08-uart-syscall check done`，跟 QEMU 上跑出来的逐字节一致。

**跑到 `exception_init: EENTRY set to exception_entry` 之后卡住、串口
出现一段像固件级"未处理异常"的转储（不是我们自己代码打印的格式）——
这是已知的、目前还没解决的边界（week09 的 `break` 异常测试在真机上会
碰到这个），不用觉得是自己哪里做错了，也不要求解决。跑到这里、能复现、
截图/复制这段输出就算完成板级迁移这部分该做的。**（这是在还没做 §8/§9
之前、代码里仍然自动触发一次 `break` 时的表现——做完 §9 之后这里的行为
会变，能看到命令行提示符而不是卡住，见 §9。）

不管出现哪种情况，**都不会有硬件损坏风险**——`go` 只是让 CPU 跳去执行内存
里的代码，U-Boot 本身存在 Flash/EMMC 里，这个操作根本碰不到它，跑飞了
断电重启/复位键就恢复，跟没发生过一样。

如果连 week01 的 `Hello miniOS` 都没看到（完全无输出/乱码/传输失败这几种），
按下面这张表排查：

| 现象 | 先怀疑 |
|---|---|
| 传输（`loady`/`fatload`）本身就失败或不稳定 | 换终端软件重连一次；实在不行走 U 盘方式 |
| 传输成功（字节数对上了），但 `go` 之后完全无输出 | 检查 §4.1/§4.2 的地址和代码是不是照抄对了，特别是 `include/platform/2k0300.h` 和 `kernel/linker_2k0300.ld` 里的那两个地址常量 |
| 有输出但是乱码 | 波特率是不是设成了 115200；`UART_LSR_OFF`/`UART_TX_EMPTY_MASK` 是不是抄对了 |

把 `week01-08` 的完整串口输出记录下来交上去。

## 8. 命令行 shell（板级迁移本身工作量填不满 4 学时，这一步补上）

先在 QEMU 里把这几步做完、验证过，再进 §9 挪到真机能摸到的位置——
QEMU 快得多，出问题也容易看清是哪一步。

### 8.1 最小内核堆分配器

新建 `include/kmalloc.h`：

```c
#ifndef MINIOS_KMALLOC_H
#define MINIOS_KMALLOC_H

#include "types.h"

void *kmalloc(size_t size);
void kfree(void *ptr);
void kmalloc_stats(unsigned long *used, unsigned long *capacity,
                    unsigned long *free_blocks);

#endif
```

新建 `kernel/kmalloc.c`：

```c
#include "kmalloc.h"

#define HEAP_SIZE (16 * 1024)
#define ALIGN_UP(x, a) (((x) + ((a) - 1)) & ~((a) - 1))

struct block_header {
    size_t size;               /* 这块空间的大小，不含 header 本身 */
    int free;                  /* 1 = 在空闲链表里，可以被复用 */
    struct block_header *next; /* 仅在 free==1 时有意义 */
};

static unsigned char g_heap[HEAP_SIZE];
static unsigned long g_bump = 0;           /* 堆里"从未分配过"区域的起始偏移 */
static struct block_header *g_free_list = 0;

static struct block_header *find_free_block(size_t size)
{
    struct block_header *cur = g_free_list;
    struct block_header *prev = 0;

    while (cur) {
        if (cur->size >= size) {
            if (prev) {
                prev->next = cur->next;
            } else {
                g_free_list = cur->next;
            }
            cur->free = 0;
            return cur;
        }
        prev = cur;
        cur = cur->next;
    }
    return 0;
}

void *kmalloc(size_t size)
{
    struct block_header *blk;
    unsigned long need;

    if (size == 0) {
        return 0;
    }

    size = ALIGN_UP(size, 8);

    blk = find_free_block(size);
    if (blk) {
        return (void *)(blk + 1);
    }

    need = sizeof(struct block_header) + size;
    if (g_bump + need > HEAP_SIZE) {
        return 0; /* 堆用尽，教学最小实现：不做扩容/换页，直接失败 */
    }

    blk = (struct block_header *)(g_heap + g_bump);
    blk->size = size;
    blk->free = 0;
    blk->next = 0;
    g_bump += need;

    return (void *)(blk + 1);
}

void kfree(void *ptr)
{
    struct block_header *blk;

    if (!ptr) {
        return;
    }

    blk = (struct block_header *)ptr - 1;
    blk->free = 1;
    blk->next = g_free_list;
    g_free_list = blk;
}

void kmalloc_stats(unsigned long *used, unsigned long *capacity,
                    unsigned long *free_blocks)
{
    struct block_header *cur;
    unsigned long n = 0;

    if (used) {
        *used = g_bump;
    }
    if (capacity) {
        *capacity = HEAP_SIZE;
    }
    if (free_blocks) {
        for (cur = g_free_list; cur; cur = cur->next) {
            n++;
        }
        *free_blocks = n;
    }
}
```

堆本体是一段静态数组（不依赖 MMU/分页，跟 `boot_stack` 是同一类"编译期
留好一块内存"的思路）。`kmalloc` 优先从空闲链表里找能复用的旧块
（first-fit，够用就行，不求最优），找不到再从"从未分配过"的区域切新的。
**不做相邻空闲块合并（coalescing）**——这是有意留下的真实局限，长时间
小块分配/释放会产生碎片，先把"能分配、能回收复用"这条链路跑通。

`Makefile` 的 `SRCS_C` 列表里加一行 `kernel/kmalloc.c`。

### 8.2 异常分类

`kernel/exception.c` 在已有的 `exception_handler` 里，把 `ESTAT.Ecode`
翻译成人能看懂的名字：

```c
#define ECODE_ADE 0x8  /* 地址错误：取指/访存地址不合法 */
#define ECODE_ALE 0x9  /* 地址不对齐：访存地址没按指令要求的边界对齐 */
#define ECODE_SYS 0xb  /* 系统调用：syscall 指令主动触发 */
#define ECODE_BRK 0xc  /* 断点：break 指令主动触发 */
#define ECODE_INE 0xd  /* 非法指令：指令编码不属于任何已定义指令 */

static const char *ecode_name(unsigned long ecode)
{
    switch (ecode) {
    case ECODE_ADE: return "ADE(地址错误)";
    case ECODE_ALE: return "ALE(地址不对齐)";
    case ECODE_SYS: return "SYS(系统调用)";
    case ECODE_BRK: return "BRK(断点)";
    case ECODE_INE: return "INE(非法指令)";
    default:        return "未分类";
    }
}
```

`exception_handler` 原来直接打印 `[exception] ESTAT=0x...` 的地方，改成
先打印 `ecode_name(ecode)`：

```c
printk("[exception] ");
printk(ecode_name(ecode));
printk(" ESTAT=0x");
printk_hex(estat);
printk(" ERA=0x");
printk_hex(era);
printk("\n");
```

### 8.3 `uart_getc` + 命令行循环

之前的课只教过 `uart_putc`（发送），没教过接收。`include/uart.h` 加一行
声明：

```c
char uart_getc(void);
```

`include/platform/qemu_virt.h` 和 `include/platform/2k0300.h` 各加一行
（16550 标准 LSR bit0=接收数据就绪）：

```c
#define UART_RX_READY_MASK     0x01
```

`kernel/printk.c` 补实现：

```c
char uart_getc(void)
{
    volatile unsigned char *uart = (volatile unsigned char *)UART0_BASE;

    while ((uart[UART_LSR_OFF] & UART_RX_READY_MASK) == 0) {
    }

    return (char)(*uart);
}
```

跟 `uart_putc` 等 `TX_EMPTY` 位是对称的写法：等"接收数据就绪"位置位，
再从数据寄存器（跟 `uart_putc` 写的是同一个偏移，16550 里发送/接收共用
一个地址，读为 RBR、写为 THR）读一个字节返回。

命令按空格切成"命令名"+"参数"两段这件事，本身就是一个逐字节扫描的活，
跟第 5/7 次课的 `strlen`/`strcmp` 是同一类，这里也写成汇编，接回这门课
的主线，而不是全用 C 堆起来。`include/string.h` 加一行声明：

```c
char *split_command(char *line);
```

`lib/string.S` 补实现（照 `strlen`/`strcmp` 的风格写，找的目标字符从
`'\0'` 换成空格）：

```asm
/*
 * char *split_command(char *line)
 * 原地把第一个空格改写成 '\0'（line 从此变成命令名这一段，调用者手上
 * 已经有这个指针，不用另外返回），返回值是参数段的起始地址——跳过
 * 空格后面可能连续的空格，停在第一个非空格字符（或者字符串末尾的
 * '\0'，代表没有参数）。叶子函数：函数体内没有 bl。
 */
    .globl split_command
split_command:
1:                              /* 找第一个空格或 '\0' */
    ld.bu       $t0, $a0, 0
    beqz        $t0, 4f         /* 到字符串结尾都没找到空格：没有参数 */
    addi.d      $t1, $zero, 0x20  /* 0x20 = ' ' */
    beq         $t0, $t1, 2f
    addi.d      $a0, $a0, 1
    b           1b

2:                              /* a0 指向命令名后的第一个空格：切断它 */
    st.b        $zero, $a0, 0
    addi.d      $a0, $a0, 1

3:                              /* 跳过空格后面可能还有的连续空格 */
    ld.bu       $t0, $a0, 0
    beqz        $t0, 4f
    addi.d      $t1, $zero, 0x20
    bne         $t0, $t1, 4f
    addi.d      $a0, $a0, 1
    b           3b

4:
    jr          $ra
```

命令行循环、内置命令处理函数，`kernel/main.c` 里 `kernel_main` 前面加：

```c
static void shell_meminfo(void)
{
    unsigned long used, capacity, free_blocks;

    kmalloc_stats(&used, &capacity, &free_blocks);
    printk("used=");
    print_i64_dec((long)used);
    printk(" capacity=");
    print_i64_dec((long)capacity);
    printk(" free_blocks=");
    print_i64_dec((long)free_blocks);
    printk("\n");
}

static void crash_sys(void)
{
    printk("triggering SYS (syscall instruction) ...\n");
    __asm__ volatile("syscall 0");
    printk("resumed after SYS\n");
}

static void crash_brk(void)
{
    printk("triggering BRK (break instruction) ...\n");
    __asm__ volatile("break 0");
    printk("resumed after BRK\n");
}

static void crash_ine(void)
{
    printk("triggering INE (illegal instruction) ...\n");
    __asm__ volatile(".word 0xffffffff");
    printk("resumed after INE\n");
}

static void shell_crash(const char *arg)
{
    if (strcmp(arg, "sys") == 0) {
        crash_sys();
    } else if (strcmp(arg, "brk") == 0) {
        crash_brk();
    } else if (strcmp(arg, "ine") == 0) {
        crash_ine();
    } else {
        printk("usage: crash <sys|brk|ine>\n");
    }
}

static int shell_read_line(char *buf, int maxlen)
{
    int n = 0;
    char c;

    for (;;) {
        c = uart_getc();

        if (c == '\r' || c == '\n') {
            uart_putc('\r');
            uart_putc('\n');
            break;
        }

        if (c == 0x7f || c == 0x08) { /* Backspace/Delete：退一格 */
            if (n > 0) {
                n--;
                printk("\b \b");
            }
            continue;
        }

        if (n < maxlen - 1) {
            buf[n++] = c;
            uart_putc(c); /* 本地回显：QEMU -serial stdio 不会自动回显 */
        }
    }

    buf[n] = '\0';
    return n;
}

static void shell_dispatch(char *line)
{
    char *cmd = line;
    /* 按空格切成"命令名"+"参数"两段，实现见 lib/string.S split_command */
    char *arg = split_command(line);

    if (cmd[0] == '\0') {
        return;
    }

    if (strcmp(cmd, "help") == 0) {
        printk("commands: help, echo <text>, meminfo, crash <sys|brk|ine>\n");
    } else if (strcmp(cmd, "echo") == 0) {
        printk(arg);
        printk("\n");
    } else if (strcmp(cmd, "meminfo") == 0) {
        shell_meminfo();
    } else if (strcmp(cmd, "crash") == 0) {
        shell_crash(arg);
    } else {
        printk("unknown command: ");
        printk(cmd);
        printk(" (try 'help')\n");
    }
}
```

`kernel_main` 末尾原来的 `while (1) { idle }` 换成：

```c
printk("week12-shell check done\n");
for (;;) {
    char line[64];

    printk("> ");
    shell_read_line(line, sizeof(line));
    shell_dispatch(line);
}
```

**验收**：`make run` 后在 QEMU 里能交互式敲 `help`/`echo <text>`/
`meminfo`/`crash <sys|brk|ine>`，行为符合预期（shell 是死循环，
`week12-shell check done` 只在进入循环前打印一次）。

### 8.4 把 `echo` 的动作函数也改成汇编（示例：从 C 到汇编的常见踩坑）

到 8.3 为止，`help`/`echo`/`meminfo`/`crash` 这几个命令"识别"命令名靠
的是 `strcmp`（第 7 次课已经是汇编），但每个命令"做什么"（动作函数）
还都是 C。这一节把 `echo` 的动作函数改写成汇编，顺便把一个真实会踩的
坑和排查过程走一遍——这个坑本身比"照抄能跑的代码"更值得体会。

**目标接口**：把 `shell_dispatch` 里内联的

```c
} else if (strcmp(cmd, "echo") == 0) {
    printk(arg);
    printk("\n");
}
```

改成调用一个汇编函数：

```c
} else if (strcmp(cmd, "echo") == 0) {
    cmd_echo(arg);
}
```

`kernel/main.c` 顶部（其它 `static` 辅助函数附近）加一行声明：

```c
/* echo 命令的动作函数，实现见 lib/shell_cmds.S */
extern void cmd_echo(const char *arg);
```

#### 第一次尝试

`echo` 要做的事看起来很简单——调 `printk(arg)`，再输出一个换行——
新建 `lib/shell_cmds.S`，可能很自然会写成这样：

```asm
    .globl cmd_echo
cmd_echo:
    bl          printk              /* printk(arg)，arg 已经在 $a0 里 */

    addi.d      $a0, $zero, 0x0d    /* '\r' */
    bl          uart_putc
    addi.d      $a0, $zero, 0x0a    /* '\n' */
    bl          uart_putc

    jr          $ra
```

`Makefile` 的 `SRCS_S` 列表里加一行 `lib/shell_cmds.S`，编译、`make run`，
敲 `echo hello`：

```text
> echo hello
hello
>
```

**看起来完全正确**——`hello` 换行也对，但敲下一条命令（比如 `meminfo`）
会发现：**shell 再也没反应了，连 `> ` 提示符都不会再出现**，输入什么
都没用，只能重启 QEMU。

#### 动手调试：用 GDB 亲手看到问题出在哪

别急着回去翻第 6 次课的笔记，先用第 10 次课学过的 GDB 亲手看一遍——
这次多一个命令：`ni`（nexti，跟 `si` 一样按指令步进，但碰到 `bl` 会把
被调用的整个函数当一步跳过去，不会跟进 `printk`/`uart_putc` 内部）。

开两个 WSL 终端，都 `cd` 到仓库目录：

**终端 A**（保持这个进程占着，之后要在这里敲 `echo hello`）：

```bash
make PLATFORM=qemu_virt debug
```

**终端 B**：

```bash
gdb-multiarch build/minios.elf
```

```text
target remote :1234
b cmd_echo
c
```

`c` 敲下去之后终端 B 会卡住（等断点命中），切到**终端 A**，等它把
week01-11 的验收输出滚完、出现 `> ` 提示符后，敲：

```text
echo hello
```

回车。这时候终端 B 应该会打印 `Breakpoint 1, cmd_echo ()...`——命中了。
回到终端 B，依次敲：

```text
x/6i $pc
info registers ra pc
```

`x/6i $pc` 能看到 `cmd_echo` 的全部 6 条指令（3 个 `bl`，夹在中间的两条
`li.d`，最后一条 `jr $ra`）；`info registers ra pc` 记一下**当前**的
`$ra`——这是 `shell_dispatch` 调用 `cmd_echo` 时交代的"你做完了要回到
这里"，先记住这个值，后面要用它对比。

然后用 `ni` 一步一步"跳过"（不进去）每个 `bl`，每步完看一眼寄存器：

```text
ni
info registers ra pc
ni
info registers ra pc
ni
info registers ra pc
```

前两次 `ni`（跳过 `bl printk`、跳过第一个 `bl uart_putc`）之后，
`$ra` 每次都会变成"`cmd_echo` 内部下一条指令的地址"——这本身没问题，
是每次 `bl` 都会做的事。**关键看第三次**：跳过第二个 `bl uart_putc`
之后，再看 `info registers ra pc`——**`$ra` 和 `$pc` 会是同一个地址**
（`$pc` 正好停在 `cmd_echo` 最后那条 `jr $ra` 上）。这一步就是问题所在：
`$ra` 现在指向的不是"回到 `shell_dispatch`"，而是**指向它自己脚下这条
`jr` 指令**。再敲一次：

```text
si
info registers ra pc
```

会看到 `$pc` 还是停在原地没挪动——`jr $ra` 把自己送回了自己，陷进了
死循环，这就是终端 A 里 shell 卡死、`meminfo` 敲了也没反应的真正原因。
调试完 `Ctrl+C` 结束 gdb，终端 A 那边的 QEMU 也重启一下（`Ctrl+a` 再
`x`，或者直接关掉终端）。

#### 定位

对照上面亲手看到的现象，回想第 6 次课的规则就说得通了：`bl` 指令把
"调用者要我返回去的地址"存进 `$ra`；`cmd_echo` 内部又调用了
`printk`/`uart_putc`——每一次 `bl` 都会把 `$ra` 覆盖成"这次调用要返回
去的地址"。`cmd_echo` 自己也调用了别的函数（是"非叶子函数"），如果
不在一开始就把 `$ra` 先存到栈上、等所有内部调用都做完了再取回来，
那么执行到最后一个 `bl uart_putc` 时，`$ra` 就会被改成"`uart_putc`
要返回到 `cmd_echo` 里 `jr $ra` 这一行"——而不是"`cmd_echo` 的调用者
要我返回去的地址"，正是刚才在 GDB 里亲眼看到的那个"`$ra` 等于 `$pc`"。

这跟第 6 次课 `sa_add3`、第 7 次课 `zero_and_copy` 的规则是同一条：
**函数体内只要有 `bl`（非叶子函数），就必须在开头保存 `$ra`、结尾恢复
`$ra`**——这次不只是读到规则，是自己用 GDB 亲手确认了不遵守这条规则
会具体坏成什么样子。

#### 修正

```asm
    .globl cmd_echo
cmd_echo:
    addi.d      $sp, $sp, -16
    st.d        $ra, $sp, 8

    bl          printk              /* printk(arg)，arg 已经在 $a0 里 */

    addi.d      $a0, $zero, 0x0d    /* '\r' */
    bl          uart_putc
    addi.d      $a0, $zero, 0x0a    /* '\n' */
    bl          uart_putc

    ld.d        $ra, $sp, 8
    addi.d      $sp, $sp, 16
    jr          $ra
```

重新编译、`make run`，再敲 `echo hello` 然后接一条 `meminfo`：

```text
> echo hello
hello
> meminfo
used=0 capacity=16384 free_blocks=0
>
```

这次 `meminfo` 的提示符和结果都正常出现，说明 `cmd_echo` 真的回到了
`shell_dispatch`，而不是卡在自己里面。

**这条经验可以直接套用到你以后想自己再多写几个命令的动作函数上**：
只要函数体内出现了 `bl`（哪怕只调了一次别的函数），开头保存 `$ra`、
结尾恢复 `$ra` 就不能省——省了不一定马上报错或输出乱码，很可能是像
这次一样，表面上输出完全正确，只在"该返回的时候"悄悄卡死，从现象上
很难第一时间联想到是 `$ra` 的问题。

## 9. 把 shell 挪到真机安全触发位置

这一步不是新写算法，是调整**已有代码摆放的位置** + 补一个小命令，
但决定 shell 能不能在真机上真正摸到。

`exception_init()` 本身很安全，只是把处理函数地址写进 `CSR.EENTRY`，
不会主动触发任何异常/中断。**真正危险的是"真的撞出一次异常或中断"**
——2K0300 真机上一旦发生（不限于 `break`，定时器 tick 走的也是同一条
入口路径，同样会卡住），会卡进一段固件级的"未处理异常"转储里，回不来
了，就是 §7 记录的那个已知边界。

`kernel_main` 里 `week08-uart-syscall check done` 之后，原来的写法是
`exception_init()` 后紧跟着自动 `break 0`（week09 demo）、再自动使能
一次定时器中断（week11 demo），最后才轮到 §8 写的 shell——真机上代码
执行到自动 `break` 那一步就已经卡住，shell 永远排不上号。

**改法**：把这两段自动触发的代码整段删掉，`exception_init()` 打印完
确认信息之后**直接**进入 shell 循环：

```c
printk("week08-uart-syscall check done\n");

exception_init();
printk("exception_init: EENTRY set to exception_entry\n");

/* week09 的 break、week11 的定时器不再自动跑，改成命令触发 */

printk("week12-shell check done\n");
for (;;) {
    char line[64];

    printk("> ");
    shell_read_line(line, sizeof(line));
    shell_dispatch(line);
}
```

week09 的 `break` 不用另外补代码——本来就是 `crash brk` 做的事，§8.3
已经写好了，删掉自动触发那两行，敲 `crash brk` 一样能验证到。

week11 的定时器需要补一个新命令 `timer`，在 `shell_dispatch` 里加一个
分支，处理函数：

```c
static void shell_timer(void)
{
    const unsigned long TIMER_COUNT = 0x1000000UL;
    /*
     * irq_ticks() 是全局递增计数器，不会自动清零——如果直接写
     * while (irq_ticks() < 5)，这个命令敲第二次时计数器早就超过 5
     * 了，会立刻返回、什么都等不到。记下调用这一刻的读数，用这次
     * 调用前后的差值跟 5 比较，才能保证每次敲都等到 5 个新 tick。
     */
    unsigned long start = irq_ticks();

    timer_init(TIMER_COUNT);
    printk("timer_init: periodic timer interrupt enabled\n");
    while (irq_ticks() - start < 5) {
        __asm__ volatile("idle 0");
    }
    timer_stop();
    printk("collected 5 timer ticks via interrupt, timer_stop() called\n");
}
```

`shell_dispatch` 加一行 `else if (strcmp(cmd, "timer") == 0) { shell_timer(); }`，
`help` 的输出也把 `timer` 加进去。

改完之后 QEMU 上重新走一遍全部验收，确认输出没有变化（只是触发方式从
"自动"变成"敲命令触发"）；真机重新编译、传输、`go`，这次预期能看到
week01-08 输出之后紧接着出现 `week12-shell check done` 和交互提示符，
可以真的在真机上敲 `help`/`echo`/`meminfo`（`crash`/`timer` 一旦真的
触发异常/中断，大概率还是会撞上 §7 的已知边界，这属于预期内）。

**真机上一条一条手动敲回车，不要一次粘贴多行**——`uart_getc` 这个最小
实现没有流控，一次涌进一长串字符容易丢字节、命令粘连成乱码，粘贴前如果
开着中文输入法，候选框残留文字也可能混进剪贴板，不是代码写错了。

把 `week01-08` 的完整串口输出记录下来交上去。
