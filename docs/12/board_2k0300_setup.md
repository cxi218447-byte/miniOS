# 2K0300 开发板上手指南（学生版：接线→装驱动→串口连通→编译→上板→排错）

> 面向**手上有真实龙芯 2K0300（先锋派）开发板**的同学（本学期人手一块，
> Task4 是必做项，见 `docs/12/lab.md`）。§1-§3 讲怎么把板子接上、看到
> 串口输出；§4-§6 讲怎么把你自己在 Task1/Task2 做出来的 2K0300 版 miniOS
> 编译、送进板子、跳转执行、看结果排错。
>
> **芯片级参数（UART 基地址、入口地址等）不在这份文档里**，是 Task1/Task2
> 要你自己从资料里查、从代码里推、上板实测验证的部分——这里只给"怎么做
> 这件事"的方法和工具用法，不给具体数值，照抄别人的地址大概率行不通
> （不同批次/供应商可能不一样，实测验证永远比抄答案可靠）。

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

## 4. 编译 2K0300 版本

串口连通、Task1（差异表）、Task2（平台拆分：`include/uart.h`/`kernel/linker.ld`
按平台拆开、`Makefile` 加开关）做完之后，应该能编译出一个 2K0300 专用的
镜像。参考做法（具体文件名/宏名是你自己 Task2 设计的结果，这里只给流程）：

```bash
make clean
make PLATFORM=2k0300    # 你自己在 Task2 里加的开关名，不一定叫这个
```

产出的 `build/minios.bin` 就是要送进板子的内容。**注意（真实踩过的坑）**：
只改头文件、没改 `.c` 文件本体时，`make` 有可能静默复用旧的 `.o` 文件——
改完平台相关的头文件，保险起见先 `make clean` 再编译。

## 5. 把 minios.bin 送进板子内存

到这一步只有串口连着，没有额外硬件，可以先试 U-Boot 自带的 `loady`
（Ymodem 协议）：

1. 先确认支持：在 `=>` 提示符下 `help loady`。
2. 执行 `loady <addr>`（`<addr>` 填你 Task1 推导出来的入口地址）——会打印
   `## Ready for binary (ymodem) download...` 然后卡住等待，这是正常的。
3. 在终端软件里找发送文件的入口：
   - **MobaXterm**：右键终端空白处 → 找 "Zmodem" 相关菜单项（虽然协议名
     写的是 Zmodem，配合 `loady` 实测可用）
   - **Tera Term**（免安装版：<https://github.com/TeraTermProject/teraterm/releases/download/v5.7.0/teraterm-5.7.0-x64.zip>，
     解压直接运行 `ttermpro.exe`）：菜单 **File → Transfer → YMODEM →
     Send...**，官方明确支持 Ymodem，比 MobaXterm 那个含糊的菜单更可靠
   - 选 `build/minios.bin`
4. 传完看 u-boot 打印的 `Total Size`，**必须**跟编译出来的文件字节数对上
   （`ls -la build/minios.bin` 核对）——字节数不对就是传错文件或传输出
   问题了，不要往下走。

**如果传输反复报协议错误**（比如 `Retry: Got xx for sector ACK`，重试、
断开终端重连都解决不了）：换成 U 盘方式——U 盘格式化成 **MBR 分区表 +
FAT32**（很多 U 盘出厂是 GPT/exFAT，U-Boot 认不了，用 Windows"磁盘管理"
转换一下），把 `minios.bin` 拷进去插到板子 USB-A 口：

```
usb start
fatload usb 0:1 <addr> minios.bin
```

## 6. 跳转执行与排错方法论

传完确认字节数对上之后：

```
go <addr>
```

不管出现哪种情况，**都不会有硬件损坏风险**——`go` 只是让 CPU 跳去执行内存
里的代码，U-Boot 本身存在 Flash/EMMC 里，这个操作根本碰不到它，跑飞了
断电重启/复位键就恢复，跟没发生过一样。

盯着串口看接下来几秒，会是下面几种情况之一，**每种对应的排查方向都不一样，
不要一看不对就急着换地址重试**：

| 现象 | 说明 | 先怀疑 |
|---|---|---|
| 看到 `Hello miniOS on LoongArch64` 等验收输出 | 成功 | 继续往后跑，看能跑到第几周的验收 |
| 传输（`loady`/`fatload`）本身就失败或不稳定 | 这跟入口地址是否正确无关，是这个地址在当前环境下访问本身有问题（可能不在任何已配置的映射窗口内） | 换一个已经验证过传输能成功的地址再试，不要跟"代码跑不跑得起来"这个问题混在一起排查 |
| 传输**成功**（字节数对上了），但 `go` 之后完全无输出、卡死 | 这里最容易踩的坑：**传输成功只能证明这块内存可读写，不能证明代码从这里执行是对的**。LoongArch 有不止一种高位直接映射窗口，其中的区别足以让"内存读写正常"但"外设寄存器访问失效"同时成立——写操作可能被吞掉、根本没送到硬件总线上，代码其实在正常执行，只是你永远看不到输出，从外部完全没法跟"卡死"区分 | 先怀疑：入口地址（代码/栈跑的地方）和 UART 地址（外设寄存器）是不是应该用**不同类型**的映射窗口；不要两个混用同一种假设 |
| 有输出但是乱码 | 代码确实跑起来了，UART 时钟/寄存器偏移这类参数不对 | 波特率除数、时钟输入频率、是否严格 16550 兼容 |

排查这类问题的正确心态是**一次只改一个变量、每次都记录现象**（哪个地址、
传输成不成功、`go` 之后什么反应），不要凭感觉一次改好几个假设——这正是
真实硬件移植的常态：没有教材上现成的地址表，只能一步步实验缩小范围。

回到 `docs/12/lab.md` Task4，继续板端实践；Task3 的排错顺序对照本节表格
和讲义 §4.4 一起用。
