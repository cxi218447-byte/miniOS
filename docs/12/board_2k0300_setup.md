# 2K0300 开发板上手指南（学生版：接线→装驱动→串口连通）

> 面向**手上有真实龙芯 2K0300（先锋派）开发板**的同学。目的只有一个：
> 让串口终端里能看到板卡的输出。看到输出之后，再回到
> `docs/12/lab.md` Task4「板端实践」和讲义 §4 继续做移植/排错。
>
> 没有真实硬件的同学不需要看这份文档，按 `lab.md` Task4 的"完整模拟方案"
> 走 QEMU 即可，不影响验收。
>
> 本文档只讲"怎么连上、怎么看到输出"这一层——串口通了之后，UART 基地址
> 等芯片级参数是 Task1/Task2 要你自己从资料里查、从代码里推的部分，这里
> 不提供，按 §4 的方法自己去确认。

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

## 4. 后续

串口连通之后：

- U-Boot 菜单/启动流程、默认账户（root/123）、如何切换启动介质等用法，
  参考你从 §0 网盘拿到的官方《快速使用指南》。
- miniOS 移植需要的芯片级参数（UART 基地址、入口地址等）不在这份文档里，
  按 `lab.md` Task1 的要求自己从资料/代码里查——提示：官方《快速使用
  指南》多半只讲用法，不一定有寄存器地址；真机跑起来的 Linux 系统里
  `ls -l /sys/class/tty/ttyS*` 这类命令能反查到真实的外设物理地址，这
  比啃手册通常更快，值得一试。**不要直接照抄 QEMU 版 `include/uart.h`
  里的地址**，那是 QEMU 模拟出来的，跟真实芯片没有必然关系。
- 回到 `docs/12/lab.md` Task2/Task4，继续设计平台拆分、板端实践。
