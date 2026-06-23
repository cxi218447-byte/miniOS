# 环境检查记录

## 日期：2026-06-23

### 安装位置约束

用户要求：环境下载缓存和安装目录不要放在 C 盘，统一放在本项目所属的上一级父目录。

项目目录：

```text
D:\日常教学\2026-2027第一学期\汇编语言\miniOS
```

环境目录：

```text
D:\日常教学\2026-2027第一学期\汇编语言\env
├── wsl
├── downloads
├── tools
└── cache
```

已执行：

```powershell
New-Item -ItemType Directory -Force -Path '..\env\wsl','..\env\downloads','..\env\tools','..\env\cache'
```

### WSL 状态

已执行：

```powershell
wsl --status
wsl -l -v
wsl --help
```

结果摘要：

- `wsl.exe` 存在。
- 当前没有可用 Linux 发行版。
- `wsl --help` 显示支持 `--install --location <Location>`。
- `wsl --list --online` 当前联网查询失败，错误包含 `WININET_E_CANNOT_CONNECT`。

### 当前缺失工具

PowerShell 中暂未找到：

```text
make
qemu-system-loongarch64
loongarch64-linux-gnu-gcc
loongarch64-linux-gnu-objcopy
gdb
gdb-multiarch
```

### 推荐下一步

WSL Ubuntu 安装需要学生手工完成，不由 Codex 自动安装。

手工说明见：

```text
docs/manual_wsl_ubuntu_install.md
```

优先尝试把 WSL Ubuntu 安装到非 C 盘：

```powershell
wsl --install -d Ubuntu --location "D:\日常教学\2026-2027第一学期\汇编语言\env\wsl\Ubuntu"
```

当前 Codex 侧曾尝试执行该命令，但 120 秒超时，不能视为安装成功。
复查结果：

- `wsl -l -v` 仍显示没有可用 Linux 发行版。
- `env\wsl` 目录为空。
- `env\downloads` 目录为空。

如果联网安装失败，需要手动下载 Ubuntu rootfs 或使用可访问网络后再执行。

进入 WSL Ubuntu 后安装工具链：

```bash
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu \
  binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

安装完成后执行：

```bash
sh scripts/check-env.sh
make clean
make
make run
```
