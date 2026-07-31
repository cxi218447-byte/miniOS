# 手工安装 WSL Ubuntu 环境

本文面向学生，用于把 LoongArch miniOS 实验环境安装到项目上一级目录，
避免占用 C 盘。

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

## 2. 检查 WSL

在 PowerShell 中执行：

```powershell
wsl --status
wsl --version
wsl -l -v
```

如果提示没有安装 WSL，先用管理员 PowerShell 执行：

```powershell
wsl --install --no-distribution
```

执行完成后按系统提示重启。

## 3. 安装 Ubuntu 到非 C 盘

优先使用 `--location`：

```powershell
wsl --install -d Ubuntu --location "<你的课程工作目录>\env\wsl\Ubuntu"
```

安装完成后，第一次启动 Ubuntu 时按提示创建 Linux 用户名和密码。

检查结果：

```powershell
wsl -l -v
```

预期能看到类似：

```text
NAME      STATE      VERSION
Ubuntu    Stopped    2
```

## 4. 如果在线安装失败

如果出现网络错误，例如 `WININET_E_CANNOT_CONNECT`，说明当前网络无法访问
WSL 发行版下载地址。可选处理方式：

1. 换到能访问 Microsoft/WSL 下载地址的网络后重试。
2. 由教师提前下载 Ubuntu rootfs 或 `.appx` 安装包，放到：

```text
<你的课程工作目录>\env\downloads
```

3. 使用 `wsl --import` 安装到非 C 盘：

```powershell
wsl --import Ubuntu-miniOS `
  "<你的课程工作目录>\env\wsl\Ubuntu-miniOS" `
  "<你的课程工作目录>\env\downloads\ubuntu-rootfs.tar.gz" `
  --version 2
```

注意：`ubuntu-rootfs.tar.gz` 文件名以实际下载文件为准。

## 5. 进入 Ubuntu

```powershell
wsl -d Ubuntu
```

如果使用 `wsl --import` 的名字是 `Ubuntu-miniOS`，则执行：

```powershell
wsl -d Ubuntu-miniOS
```

进入后设置环境变量，方便后续缓存放到项目父目录：

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

## 6. 安装 LoongArch 实验工具链

在 Ubuntu 中执行：

```bash
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu \
  binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

## 7. 检查工具链

进入项目目录：

```bash
cd /mnt/<盘符>/<你的课程工作目录>/miniOS
```

执行：

```bash
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

## 8. 第 1 次课验证命令

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

## 9. 退出 QEMU 和 WSL

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
