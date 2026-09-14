# 补救方案：Ubuntu 22.04 装不上 LoongArch 工具链，改装 Ubuntu 26.04

## 什么情况下要看这份文档

如果你按 [`manual_wsl_ubuntu22_toolchain_build.md`](manual_wsl_ubuntu22_toolchain_build.md)
装好了 Ubuntu 22.04，在第 5 步执行

```bash
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu \
  binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

时报错：

```text
E: Unable to locate package gcc-loongarch64-linux-gnu
E: Unable to locate package binutils-loongarch64-linux-gnu
```

**这不是你操作错了**：Ubuntu 22.04 的官方软件源里本来就没有这两个包（LoongArch
交叉编译工具链是后面版本才加进 Ubuntu 仓库的），换源、反复 `apt update`
都没用。解决办法是另外装一个新版本的 Ubuntu（26.04），仓库里已经有这两个包，
跟现有的 22.04 那份**互不影响、并列共存**，不需要卸载旧的。

## 1. 确认商店里有 Ubuntu-26.04

在 **PowerShell** 中执行：

```powershell
wsl --list --online
```

在输出里找 `Ubuntu-26.04` 这一行，记住准确的名字（不同时期名字写法可能有差异，
比如也可能是 `Ubuntu-26.04-LTS`，以这条命令的实际输出为准）。如果列表里根本
没有 26.04，找老师，不要自己瞎猜名字硬装。

## 2. 安装到项目目录同级的 env 目录（不占 C 盘）

```powershell
mkdir "<你的课程工作目录>\env\wsl"
wsl --install -d Ubuntu-26.04 --location "<你的课程工作目录>\env\wsl\Ubuntu-26.04"
```

`<你的课程工作目录>` 换成你实际存放 `miniOS` 项目的上一级目录，跟原来装
22.04 时用的是同一个目录约定。

## 3. 首次启动，建账号

```powershell
wsl -d Ubuntu-26.04
```

跟着提示设置 Linux 用户名和密码（可以跟你 22.04 那份的用户名密码不一样，
互不影响；输密码时终端不会显示字符，是正常的，照样打完回车）。

## 4. 确认两个发行版都在、名字没冲突

```powershell
wsl -l -v
```

预期能看到两行，例如：

```text
  NAME           STATE      VERSION
* Ubuntu         Stopped    2
  Ubuntu-26.04   Stopped    2
```

## 5. 进 26.04 里装工具链

```powershell
wsl -d Ubuntu-26.04
```

```bash
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu \
  binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

## 6. 检查工具链

**这一步要在 `git clone` 之后、`git switch -c my-01-lab 01-qemu-hello`
（或任何 `my-XX-lab`）之前做**，原因和用法跟 22.04 那份文档完全一样，
参见 [`manual_wsl_ubuntu22_toolchain_build.md`](manual_wsl_ubuntu22_toolchain_build.md) 第 6 节。

用仓库自带脚本（在 `master` 分支、项目目录下）：

```bash
sh scripts/check-env.sh
```

或者不依赖仓库文件，直接手动逐条检查：

```bash
which make
which qemu-system-loongarch64
which loongarch64-linux-gnu-gcc
which loongarch64-linux-gnu-objcopy
which gdb-multiarch
```

每条命令有输出路径（比如 `/usr/bin/loongarch64-linux-gnu-gcc`）就是装好了；
没输出说明还缺，回头检查第 5 步是不是有包装失败。

顺便看版本号：

```bash
qemu-system-loongarch64 --version
loongarch64-linux-gnu-gcc --version
make --version
```

## 7. 之后的操作完全一样

环境变量设置、进入项目目录、`make`/`make run`、退出 QEMU/WSL 的方式，
跟 [`manual_wsl_ubuntu22_toolchain_build.md`](manual_wsl_ubuntu22_toolchain_build.md)
第 4、7、8 节完全一致，唯一区别是每次要进的是 `Ubuntu-26.04` 而不是 `Ubuntu`：

```powershell
wsl -d Ubuntu-26.04
```

之后照旧课的实验流程走即可，不用重复看那几节。
