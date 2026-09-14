# 手工安装 WSL Ubuntu 22.04 环境（含 LoongArch 工具链自建）

本文面向学生，从零开始把 LoongArch miniOS 实验环境装到 Windows 上的 WSL
Ubuntu 22.04 里，环境目录放在项目上一级目录，避免占用 C 盘。**Ubuntu 22.04
的官方软件源里没有现成的 LoongArch 交叉编译工具链包**，所以第 5 步之后不是
简单一条 `apt install` 就能装完，需要自己下预编译工具链、自己编 QEMU——本文
把这部分也一并讲清楚了，每条命令都配了"这一步在做什么"的解释。

如果不想折腾这些、只想让 apt 一条命令装完，另一条路是装第二个 Ubuntu 26.04
（跟这份 22.04 并列共存，不用卸载重装），仓库里的 LoongArch 包在 26.04 上是
现成的，见 [`manual_wsl_ubuntu26_install.md`](manual_wsl_ubuntu26_install.md)。
两条路选一条走，不用都做。

**本课程统一用老师提供的离线安装包装 Ubuntu**（不走 Microsoft Store /
`wsl --install -d Ubuntu` 联网下载那条路——教室/机房网络访问不了 WSL
发行版下载地址是常态，直接用在线安装大概率会卡住或报错，不要自己尝试；
文档最后有网络允许时的在线安装备用方式）。

## 1. 目录约定

项目目录示例：

```text
<你的课程工作目录>\miniOS
```

环境目录统一放在项目上一级目录：

```text
<你的课程工作目录>\env
├── wsl
├── downloads
├── tools
└── cache
```

如果目录不存在，在 PowerShell 中执行：

```powershell
mkdir "<你的课程工作目录>\env\wsl"
mkdir "<你的课程工作目录>\env\downloads"
mkdir "<你的课程工作目录>\env\tools"
mkdir "<你的课程工作目录>\env\cache"
```

## 2. 检查/启用 WSL 底层组件

在 PowerShell 中执行：

```powershell
wsl --status
wsl --version
wsl -l -v
```

如果 `wsl --status` 提示没有安装 WSL，或者后面装 Ubuntu 时报错
`WslRegisterDistribution failed with error: 0x8007019e`
（提示"适用于 Linux 的 Windows 子系统可选组件未启用"），说明这台机器的
WSL 底层功能还没打开，跟用哪个安装包无关，必须先在**管理员 PowerShell**
执行：

```powershell
wsl --install --no-distribution
```

这条只启用 Windows 自带的两个可选组件（虚拟机平台 + 适用于 Linux 的
Windows 子系统），不装任何发行版。正常几分钟内跑完，跑完会提示类似
"直到重新启动系统前更改将不会生效"——**必须重启电脑**，不重启直接
装 Ubuntu 还是会报同样的 `0x8007019e`。重启后再继续下面的步骤。

## 3. 用老师提供的离线安装包装 Ubuntu

### 3.1 老师给你的文件是什么

Ubuntu 官方发布的 WSL 安装包是一个 `.AppxBundle` 文件（例如
`Ubuntu2204-221101.AppxBundle`），本质上和在 Microsoft Store 里搜
"Ubuntu"联网下载到的是同一个东西，只是老师提前下好、通过 U 盘/群文件/
共享文件夹发给你，装的时候不需要联网。

老师通常会把这个文件放进 `downloads` 文件夹发给你（对应本文档的目录约定
`<你的课程工作目录>\env\downloads`）。拿到后先确认文件完整：正常大小在
1 GB 左右，如果只有几十 KB 或几 MB，说明传输/下载不完整，找老师重发，
不要直接尝试安装。

### 3.2 用 Add-AppxPackage 安装（已在真机验证过）

`.AppxBundle` 是 Windows 应用商店包，**不能**用 `wsl --import`
或 `wsl --install --from-file` 装（这两个命令吃的是 tar 归档/`.wsl`
导出包，喂给它 `.AppxBundle` 会报
`导入的文件不是有效的 Linux 分发 / WSL_E_NOT_A_LINUX_DISTRO`）。
正确方式是像装普通 Windows 应用一样，用 `Add-AppxPackage`：

在**管理员 PowerShell** 中执行（把路径换成你实际存放文件的位置）：

```powershell
Add-AppxPackage -Path "<downloads文件夹路径>\Ubuntu2204-221101.AppxBundle"
```

正常几秒到几十秒完成，没有网络依赖（前提是 §2 的 WSL 底层组件已启用，
否则下一步启动时会报 `0x8007019e`，回去看 §2）。

### 3.3 首次启动，建账号

按 Windows 键，搜索 **Ubuntu**，点开搜到的应用（这一步会把应用注册进
开始菜单）。第一次启动会解压初始化文件系统，然后提示你设置 Linux
用户名和密码——跟着提示输入即可（输密码时终端不会显示字符，是正常的，
照样打完回车）。

这一步装完之后，默认落在 **C 盘**（`%LOCALAPPDATA%\Packages\...`），
下一步再挪走。

### 3.4 确认注册结果

```powershell
wsl -l -v
```

真机验证下来注册出来的名字就是 `Ubuntu`（预期输出）：

```text
  NAME      STATE           VERSION
* Ubuntu    Stopped         2
```

之后直接跳到下面「4. 进入 Ubuntu」继续；如果想把它挪到非 C 盘目录，
接着做 3.5。

### 3.5（建议做）挪到非 C 盘目录

```powershell
wsl --manage Ubuntu --move "<你的课程工作目录>\env\wsl\Ubuntu"
```

（目标目录不存在会自动创建。）执行完提示"操作成功完成"即可；可以
用 `Get-ChildItem -Force "<目标目录>"` 确认里面出现了几百 MB～1 GB 的
`ext4.vhdx` 文件，或者直接 `wsl -d Ubuntu -- pwd` 确认还能正常进入、
数据没丢，来验证搬迁成功。

### 3.6（备用）如果老师给的是已导出的整机镜像（.tar.gz）而不是 .AppxBundle

极少数情况下，老师给你的不是官方 `.AppxBundle`，而是老师自己配好环境后
用 `wsl --export` 导出的整机镜像（`.tar.gz`）。这种镜像里通常**已经装好
本课程要用的整套工具链**（`make`/`loongarch64-linux-gnu-gcc`/
`qemu-system-loongarch64`/`gdb-multiarch`），导入后可以跳过本文档
第 5 步及之后的工具链自建部分。这种情况用 `wsl --import`
（这条命令吃 `.tar.gz` 是对的，跟 3.2 说的"appx 不能这样装"不矛盾）：

```powershell
wsl --import Ubuntu "<你的课程工作目录>\env\wsl\Ubuntu" `
  "<downloads文件夹路径>\ubuntu-export.tar.gz" --version 2
```

文件名以老师实际给的为准；两种包（`.AppxBundle` 裸系统 / 老师导出的
`.tar.gz` 预装工具链）具体给哪一种、装完是否还要执行下面的工具链自建，
以老师课堂说明为准，别自己猜。

## 4. 进入 Ubuntu

```powershell
wsl -d Ubuntu
```

（§3.2 用 Add-AppxPackage 装出来的发行版名字就是 `Ubuntu`（真机验证过）；
只有 §3.6 用 `wsl --import` 且自己改了第一个参数的名字时，这里才需要
换成你改的那个名字。）

进入后设置环境变量，方便后续缓存放到项目父目录：

**注意 `<盘符>` 要换成小写字母、不带冒号**（例如 Windows 里的 `D:` 在这里
写成 `d`，不是 `D:`）。举例：Windows 路径
`D:\工作\日常教学\2026-2027第一学期\汇编语言`，这里就要写成
`/mnt/d/工作/日常教学/2026-2027第一学期/汇编语言`：

```bash
export MINIOS_ENV=/mnt/<盘符>/<你的课程工作目录>/env
export TMPDIR="$MINIOS_ENV/cache"
```

可追加到 `~/.bashrc`：

```bash
cat >> ~/.bashrc <<'EOF'
export MINIOS_ENV=/mnt/<盘符>/<你的课程工作目录>/env
export TMPDIR="$MINIOS_ENV/cache"
EOF
```

**如果写错成了 `/mnt/D:/...`（带冒号/大写）**，`make` 会报
`TMPDIR value ... No such file or directory` 并自动回退用默认的 `/tmp`
（不是致命错误，`make` 还能继续跑）。修正方法：改 `~/.bashrc` 里这一行
的盘符大小写和冒号，`source ~/.bashrc` 生效，再 `mkdir -p "$TMPDIR"`
把目录建出来。

**如果你的课程工作目录路径里带空格**（比如目录名是 `2026-2027 1`），
后面所有 `cd /mnt/...` 命令都要用双引号把路径包起来，比如
`cd "/mnt/d/每学期教学/2026-2027 1/汇编语言/miniOS"`——不加引号
bash 会把空格当成命令参数的分隔符，报 `too many arguments`。

## 5. 尝试安装 LoongArch 实验工具链（这一步会部分失败，往下看原因）

**开始前先确认一件事**：下面所有命令都要在 **WSL 里的 Ubuntu 终端**执行，
不是 Windows 的 PowerShell。提示符如果长得像 `PS C:\...>` 就是还在
PowerShell，先用第 4 步的 `wsl -d Ubuntu` 进去，进去之后提示符会变成
`你的用户名@电脑名:~$` 这种 Linux 风格，再往下走。如果在 PowerShell 里
直接敲 `sudo apt install ...`，会碰到 Windows 11 自带的、跟 Linux `sudo`
完全无关的"Sudo 已在此计算机上禁用"提示——那是 Windows 自己的功能，跟这里
要装的东西没关系，说明你敲错了地方，不是需要去开 Windows 的 sudo 开关。

在 Ubuntu 中执行：

```bash
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu \
  binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

这条命令**在 Ubuntu 22.04 上一定会报错**：

```text
E: Unable to locate package gcc-loongarch64-linux-gnu
E: Unable to locate package binutils-loongarch64-linux-gnu
```

**不是你操作错了**：Ubuntu 22.04 的官方软件源里本来就没有这两个包
（LoongArch 交叉编译工具链是后面版本的 Ubuntu 才收进仓库的），换源、
反复 `apt update` 都没用。

而且这条报错背后其实是**两个不同的问题叠在一起**：

1. **`gcc-loongarch64-linux-gnu` / `binutils-loongarch64-linux-gnu` 根本不
   存在于 Ubuntu 22.04 的官方源**——就是上面这条报错。
2. **就算 `qemu-system-misc` 装成功了，里面的 `qemu-system-loongarch64` 也
   用不了**——22.04 自带的 QEMU 是 6.2 版本，而 QEMU 对 LoongArch 的支持是
   7.1（2022 年 8 月发布）才加进去的，6.2 里根本没有这个模拟目标。这个问题
   **不会**在 `apt install` 这一步报错提示你，只会在你后面敲
   `qemu-system-loongarch64` 时显示"命令不存在"，容易让人以为是自己装错了。

另外，因为上面这条命令**整体失败**，`make`、`qemu-system-misc`、
`gdb-multiarch` 这几个 22.04 官方源里本来就有的包，**这次也一个都没装上**
——`apt install` 一次装多个包是一整个事务，只要有一个包名解析不了，整条
命令直接中止，不会"跳过装不了的、先把能装的装上"。所以下面收尾部分还要把
`gdb`/`gdb-multiarch` 单独补装一遍，不能默认这条命令已经把它们装好了。

所以下面分两部分修：**A 部分解决 GCC/binutils**，**B 部分解决 QEMU**。

## A 部分：装官方预编译的 GCC/binutils 交叉工具链

思路是：既然 apt 仓库里没有编译好的包，就直接去上游（龙芯官方在 GitHub 维护的
`build-tools` 仓库）下载已经编译好的二进制工具链，解压之后加进 `PATH` 就能用，
不需要自己编译 GCC（编译 GCC 本身要几十分钟到几小时，且依赖链很长，教学环境不
划算，这一步用预编译包，B 部分编 QEMU 才是真的从源码编）。

### A1. 下载

打开 https://github.com/loongson/build-tools/releases ，在最新的 release 里找
文件名类似这样的（**host 是 x86_64、target 是 loongarch64、glibc 版本不要选
musl**——glibc 是标准 C 库，miniOS 编译不依赖它，但选它能保证工具链行为跟主流
发行版一致，减少后面踩坑）：

```text
x86_64-cross-tools-loongarch64-binutils_2.45-gcc_15.1.0-glibc_2.42.tar.xz
```

具体版本号会随时间变化，以页面上实际能看到的最新一个为准。复制下载链接，在
Ubuntu 22.04 里：

```sh
cd ~
wget <你复制的下载链接>
```

`wget` 就是命令行下载工具，把浏览器里复制的链接原样粘进来即可。

### A2. 解压到固定目录

```sh
sudo mkdir -p /opt/loongarch64-toolchain
sudo tar xf x86_64-cross-tools-loongarch64-*.tar.xz -C /opt/loongarch64-toolchain --strip-components=1
```

- `/opt` 是 Linux 里约定俗成放"非系统自带的第三方软件"的目录，跟你自己的
  `home` 目录分开，好管理、不容易被误删。
- `--strip-components=1` 的作用：压缩包内部通常会多包一层目录（比如解压出来是
  `some-dir/bin/...` 而不是直接 `bin/...`），这个参数的意思是"解压时去掉最外层
  那一级目录"，让 `bin`、`lib` 这些直接落在 `/opt/loongarch64-toolchain` 下面，
  路径更短更好记。如果解压完发现 `bin` 目录不在预期位置，先跑
  `tar tf x86_64-cross-tools-loongarch64-*.tar.xz | head -20` 看看压缩包内部
  实际的目录层级，再调整这个数字。

### A3. 把工具链目录加进 PATH

```sh
echo 'export PATH=/opt/loongarch64-toolchain/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

- `PATH` 是 shell 用来找可执行文件的目录列表，你敲一条命令时，shell 会依次去
  `PATH` 里列的每个目录找同名文件。工具链解压在 `/opt/...` 下，不在 `PATH`
  默认包含的目录（比如 `/usr/bin`）里，不加这一步的话，敲 `loongarch64-xxx-gcc`
  会直接提示 `command not found`，哪怕文件其实已经在磁盘上了。
- `>> ~/.bashrc` 是追加写入你的 shell 配置文件，这样以后每次开新终端都会自动
  生效，不用每次手动 `export`。
- `source ~/.bashrc` 是让这次改动**立刻**在当前终端生效，不用关掉重开。

### A4. 关键坑：这份工具链的文件名前缀跟仓库预期的不一样

先看一眼实际装出来的可执行文件叫什么：

```sh
ls /opt/loongarch64-toolchain/bin | grep gcc
```

会看到类似 `loongarch64-unknown-linux-gnu-gcc`，而不是
`loongarch64-linux-gnu-gcc`。这不是装错了——`unknown-linux-gnu` 是标准的
**GNU 目标三元组**写法（格式是 `<CPU 架构>-<vendor 厂商字段>-<操作系统>-<ABI>`），
`unknown` 表示这份工具链没有绑定某个特定发行版/厂商，是很常见的命名方式
（比如 Rust 的 `x86_64-unknown-linux-gnu` 也是同一套习惯），编译器功能完全正常，
只是名字比 apt 官方包（`loongarch64-linux-gnu`，少了 vendor 那一段）多了一节。

问题在于：本仓库的 `Makefile`（见 `Makefile` 第 1 行 `CROSS_COMPILE`）和
`scripts/check-env.sh` 认的是字面量 `loongarch64-linux-gnu-*`，名字对不上就会
报"找不到"，即使编译器其实能用。解决办法是建一批软链接，把长名字"链接"成短名字：

```sh
cd /opt/loongarch64-toolchain/bin
for f in loongarch64-unknown-linux-gnu-*; do
    sudo ln -sf "$f" "${f/unknown-linux-gnu/linux-gnu}"
done
```

逐段解释这条 `for` 循环在做什么：

- `for f in loongarch64-unknown-linux-gnu-*; do ... done`：把当前目录下所有以
  `loongarch64-unknown-linux-gnu-` 开头的文件（`gcc`、`objcopy`、`ld` 等一整套）
  依次取出来，赋给变量 `f`，逐个处理。
- `"${f/unknown-linux-gnu/linux-gnu}"`：bash 的字符串替换语法，把文件名里的
  `unknown-linux-gnu` 替换成 `linux-gnu`，也就是把
  `loongarch64-unknown-linux-gnu-gcc` 变成目标名字 `loongarch64-linux-gnu-gcc`。
- `sudo ln -sf "$f" "新名字"`：建一个指向原文件的**软链接**（快捷方式），
  `-s` 表示软链接，`-f` 表示如果目标名字已经存在就直接覆盖，不用先手动删。
  软链接的好处是不用复制一份文件，占用空间几乎为零，原文件更新了链接自动跟着更新。

跑完这段之后，`ls /opt/loongarch64-toolchain/bin` 里会同时看到长名字（真身）和
短名字（链接），两套名字都能用，指向的是同一个可执行文件。

### A5. 验证

```sh
which loongarch64-linux-gnu-gcc
which loongarch64-linux-gnu-objcopy
loongarch64-linux-gnu-gcc --version
```

`which` 能打印出路径、`--version` 能打印出版本号（例如 `GCC 15.1.0`），说明 A
部分完成。

## B 部分：从源码编译 QEMU（补上 LoongArch 支持）

前面说过，22.04 apt 里的 QEMU 版本太老，装不到带 LoongArch 支持的版本。这部分
自己从源码编一份新的，装到 `/usr/local/bin`（跟 apt 装的旧版本互不冲突，`PATH`
里 `/usr/local/bin` 通常排在 `/usr/bin` 前面，新编的这份会被优先用到）。

### B1. 拿到 QEMU 源码

```sh
cd ~
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
```

QEMU 官方仓库体积比较大（有几十年的历史和所有架构的代码），`clone` 可能要花几分钟，
教室网络不好的话可以让老师提前下载好源码包分发，跳过这一步的联网下载。

### B2. 装编译 QEMU 需要的依赖

QEMU 用 [meson](https://mesonbuild.com/) 这个构建系统（不是传统的直接写
`Makefile`），加上它自身要连接一堆图形/网络/虚拟化相关的库，编译前要先把这些
依赖装齐，不然 `./configure` 会在检测阶段挨个报"找不到某某库"：

```sh
sudo apt install -y ninja-build python3-venv python3-tomli pkg-config \
  libglib2.0-dev libpixman-1-dev libslirp-dev flex bison libfdt-dev
```

逐个说明每个包是干什么的：

- `ninja-build`：meson 生成的构建文件最终由 `ninja` 这个工具去执行编译，
  类似 `make` 但速度更快，是 meson 项目的标配搭档。
- `python3-venv`：QEMU 的构建脚本会在项目目录下建一个独立的 Python 虚拟环境
  （`build/pyvenv`）来跑 meson，避免污染系统的 Python 环境，这个包提供
  "建虚拟环境"这个能力。
- `python3-tomli`：**这是我们之前实际踩过的坑**——meson 需要解析项目里的
  `pyproject.toml` 配置文件（TOML 格式），Python 3.11 才在标准库里自带了
  解析 TOML 的模块（`tomllib`），Ubuntu 22.04 自带的 Python 是 3.10，没有这个
  模块，得靠 `tomli` 这个第三方包补上，不装的话 `./configure` 会卡在
  `found no usable tomli, please install it` 这一步，后面 `make` 会因为
  `build/` 目录下没生成出 `Makefile` 而报 `No rule to make target 'Makefile'`
  ——两条报错看着不一样，根源是同一个。
- `pkg-config`：编译时用来查询"某个库装在哪、编译参数是什么"的标准工具，
  几乎所有 C/C++ 项目编译带外部依赖的库时都要用到。
- `libglib2.0-dev` / `libpixman-1-dev`：QEMU 内部大量用到 GLib（通用数据结构/
  事件循环）和 Pixman（图像像素处理，用于模拟显示设备），`-dev` 后缀表示装的是
  "开发包"（含头文件和链接用的库），不是只能运行、不能编译用的运行时包。
- `libslirp-dev`：对应下面 `configure` 时开的 `--enable-slirp` 选项，slirp 是
  QEMU 提供的一种用户态网络模拟方式，不需要 root 权限、不需要配置网桥就能让
  虚拟机联网，教学环境里最省事的联网方式，这个库不装的话 `--enable-slirp`
  这个选项会在 configure 阶段报错。
- `flex` / `bison`：经典的词法/语法分析器生成工具，QEMU 编译过程里有几处用到
  （比如解析设备树相关的语法），没装会在编译到那几个文件时报错。
- `libfdt-dev`：解析/生成设备树（Device Tree）用的库，LoongArch 的 `virt`
  这类虚拟机平台会用设备树描述硬件，QEMU 编译 loongarch64 相关目标要用到。

### B3. 配置编译选项

```sh
./configure --target-list=loongarch64-softmmu,loongarch64-linux-user --enable-slirp
```

- `./configure` 是 QEMU 源码树自带的配置脚本，作用是检测系统环境、生成实际
  驱动编译过程的 `build/` 目录（里面才是 meson/ninja 真正用的文件）。
- `--target-list=loongarch64-softmmu,loongarch64-linux-user`：QEMU 默认会把
  **所有支持的 CPU 架构**都编一遍（x86、ARM、RISC-V……几十种），编译时间会
  非常长、产物也很占空间。这个参数显式指定"只编 LoongArch 相关的两个目标"，
  大幅缩短编译时间：
  - `loongarch64-softmmu` 对应可执行文件 `qemu-system-loongarch64`——**全系统
    模拟**，模拟一整台虚拟机（CPU、内存、外设），miniOS 实验用的就是这个。
  - `loongarch64-linux-user` 对应可执行文件 `qemu-loongarch64`——**用户态模拟**，
    只运行单个 Linux 可执行文件（不模拟整台机器），miniOS 实验不需要这个，
    这里顺带编上主要是为了能快速测试交叉编译器产出的二进制对不对（见文档最后
    的"可选：快速测一下交叉编译器"）。
- `--enable-slirp`：开启前面装的 `libslirp-dev` 对应的用户态网络支持。

如果这一步又报别的"找不到某个库"，一般是 B2 那份依赖列表没装全，照着报错信息
里提到的库名（比如报 `Xxx not found, please install libxxx-dev`）用
`sudo apt install libxxx-dev` 补上，重新跑这条 `./configure` 即可，不用回头
重新走一遍前面的步骤。

### B4. 编译

```sh
make -j$(nproc)
```

- `make` 会读取 B3 生成的 `build/` 目录里的构建文件，实际执行编译。
- `-j$(nproc)`：`nproc` 是打印"当前系统有几个 CPU 核心"的命令，`$(nproc)`
  是把这个命令的输出（一个数字）代入进去，`-j` 是"并行编译"参数，意思是
  "同时开这么多个编译任务"。QEMU 源码量大，不加 `-j` 只用单核编译可能要
  半小时以上，开并行能显著缩短时间（具体缩短多少取决于 CPU 核心数）。

这一步耗时视机器性能而定，几分钟到十几分钟不等，正常现象，不用中途打断。

### B5. 安装

```sh
sudo make install
```

把编译产物（`qemu-system-loongarch64`、`qemu-loongarch64` 等）拷贝安装到系统
目录（默认是 `/usr/local/bin`），加 `sudo` 是因为 `/usr/local` 这类系统目录
普通用户没有写权限。装完之后这些命令就能像装 apt 包一样直接在任意目录下敲，
不用每次都进 `~/qemu/build` 目录去找可执行文件。

### B6. 验证

```sh
qemu-system-loongarch64 --version
```

能打印出版本号（比如 `QEMU emulator version 9.1.0`）就说明 B 部分完成。

## 6. 补装 gdb/gdb-multiarch，然后检查工具链

```sh
sudo apt install -y gdb gdb-multiarch
```

这两个包 22.04 官方源里**本来就有**，第 5 步开头那条合并命令因为
`gcc`/`binutils` 两个包解析失败而整体中止，它俩这次也没装上，这里单独补一遍。

**这一步要在 `git clone` 之后、`git switch -c my-01-lab 01-qemu-hello`
（或任何 `my-XX-lab`）之前做**——`scripts/check-env.sh` 只在 `master`
上有，切到具体课次 tag 之后这个文件不存在，会报
`cannot open scripts/check-env.sh: No such file`（课次 tag 按"只保留本次
课必需代码"原则不包含它）。如果你已经切到某个 tag 了，改用下面的手动
命令，效果一样、不依赖任何仓库文件：

```bash
which make
which loongarch64-linux-gnu-gcc
which qemu-system-loongarch64
which gdb-multiarch
```

还没切 tag、就在 `master` 上的话，进入项目目录：

```bash
cd /mnt/<盘符>/<你的课程工作目录>/miniOS
```

执行：

```bash
sh scripts/check-env.sh
```

**如果这一步报 `scripts/check-env.sh: 2: set: Illegal option -`**：不是脚本本身
写错了，是这个文件在你磁盘上的行尾符变成了 Windows 的 CRLF（而不是 Linux 的
LF）。常见原因是项目 clone 在 Windows 盘上、Git for Windows 默认开着
`core.autocrlf=true`，checkout 的时候会把换行符转换掉，Linux 的 `sh` 解析到
`set -eu` 这行末尾多出来的隐藏字符 `\r`，会把它当成非法的选项参数。仓库后续版本
已经用 `.gitattributes` 修了这个问题（新 clone 不会再遇到），如果你这份是修复
之前 clone 的，或者还是碰到了，本地直接修一下这个文件就行，不影响其他文件：

```sh
sed -i 's/\r$//' scripts/check-env.sh
sh scripts/check-env.sh
```

必须能找到：

```text
make
qemu-system-loongarch64
loongarch64-linux-gnu-gcc
loongarch64-linux-gnu-objcopy
gdb-multiarch
```

五项全部 `[OK]` 就说明 22.04 这条自建路线走通了。

## 7. 第 1 次课验证命令

当前阶段只做第 1 次课 QEMU Hello miniOS：

```bash
make clean
make
make run
```

第 1 次课验收输出：

```text
Hello miniOS on LoongArch64
```

如果输出不一致，停在第 1 次课排查，不继续第 2 次课。

## 8. 退出 QEMU 和 WSL

如果 `make run` 正在运行 QEMU，看到第 1 次课输出后，可以按下面的按键退出 QEMU：

```text
Ctrl + A
X
```

操作方式是：先按住 `Ctrl` 再按 `A`，松开后再按 `X`。

如果只是退出 WSL 中的 Linux shell：

```bash
exit
```

如果要在 Windows PowerShell 中关闭整个 WSL：

```powershell
wsl --shutdown
```

## 可选：快速测一下交叉编译器产出的二进制对不对

不是必须步骤，纯粹想在正式跑 miniOS 之前，先确认 A 部分装的 GCC 能编出正确的
LoongArch64 程序：

```sh
cat > ~/hello.c <<'EOF'
#include <stdio.h>
int main(void) { printf("hello loongarch\n"); return 0; }
EOF
loongarch64-linux-gnu-gcc -static -o ~/hello ~/hello.c
qemu-loongarch64 ~/hello
```

- `-static`：编成**静态链接**的可执行文件，把用到的库函数（比如这里的
  `printf`）直接打包进最终的可执行文件里，不依赖运行时再去找一份共享库。
  不加 `-static` 的话，`qemu-loongarch64`（用户态模拟）跑这个程序时会去找
  LoongArch64 版本的动态链接器 `/lib64/ld-linux-loongarch-lp64d.so.1`，但
  宿主机上没有这份 LoongArch64 的系统库，会报
  `Could not open '/lib64/ld-linux-loongarch-lp64d.so.1': No such file or directory`
  ——这是我们实际踩过的坑，加 `-static` 就完全绕开了这个问题，因为不需要
  运行时再去找任何外部库。
- 能打印出 `hello loongarch` 就说明 A 部分的交叉编译器和 B 部分编的
  `qemu-loongarch64` 都是好的。**miniOS 实验本身不需要这一步**——内核代码用
  `-nostdlib` 编译（见 `Makefile`），从来不链接 glibc，也从来不用
  `qemu-loongarch64`，全程只用 `qemu-system-loongarch64` 全系统模拟；这一步
  纯粹是给你一个比"直接跑 miniOS"更快、更容易定位问题的独立验证手段。

## 附录：网络允许时的在线安装方式（本课程不默认使用）

上面 §3 是本课程统一使用的离线安装方式，不依赖网络，教室/机房环境下
优先用它。如果你自己的电脑网络能正常访问 Microsoft/WSL 下载地址（比如
在家、或者学校网络这次没有限制），也可以跳过 §3，直接联网安装：

```powershell
wsl --install -d Ubuntu --location "<你的课程工作目录>\env\wsl\Ubuntu"
```

安装完成后，第一次启动 Ubuntu 时按提示创建 Linux 用户名和密码，
检查结果：

```powershell
wsl -l -v
```

预期能看到类似：

```text
NAME      STATE      VERSION
Ubuntu    Stopped    2
```

如果这条命令报网络错误（例如 `WININET_E_CANNOT_CONNECT`），说明当前
网络访问不了 WSL 发行版下载地址，回到 §3 用离线包装，不要在这条上
反复重试。装完之后的步骤（进入 Ubuntu、装工具链、跑验收）跟 §3 走完
之后完全一样，直接从「4. 进入 Ubuntu」继续即可。
