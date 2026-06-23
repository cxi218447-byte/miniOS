# LoongArch 汇编 miniOS 实验

本仓库用于 LoongArch 汇编课程实验。当前阶段只做第 1-2 周验证：

- 第 1 周：启动代码、仓库初始化、串口 Hello World。
- 第 2 周：`.data/.bss` 初始化、内存寻址、C 与汇编混合编译。

后续异常、系统调用和中断实验保留源码框架，但默认启动路径暂不进入，避免影响
第 1-2 周跑通。

## 平台优先级

第一阶段：教学验证

- LoongArch64 GCC
- QEMU `virt` machine
- 串口输出
- 不依赖真实开发板

第二阶段：硬件迁移

- 龙芯先锋板
- 龙芯官方工具链
- UART 驱动适配
- 中断控制器适配

所有实验必须先在 QEMU 跑通，再迁移到开发板。

## 当前环境检查结果

本机 PowerShell 中暂未找到：

- `make`
- `qemu-system-loongarch64`
- `loongarch64-linux-gnu-gcc`
- `loongarch64-linux-gnu-objcopy`
- `gdb` / `gdb-multiarch`

WSL 可执行文件存在，但当前没有可用 Linux 发行版；联网查询 WSL 发行版也受限。

Windows 侧检查：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-env.ps1
```

Linux/WSL 侧检查：

```sh
sh scripts/check-env.sh
```

## 推荐安装方式

建议使用 WSL Ubuntu 或 Linux 主机：

```sh
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

Windows 如果还没有 WSL Ubuntu，可在管理员 PowerShell 中执行：

```powershell
wsl --install -d Ubuntu --location "D:\日常教学\2026-2027第一学期\汇编语言\env\wsl\Ubuntu"
```

然后进入 Ubuntu，在仓库目录对应的 `/mnt/d/.../miniOS` 下执行上面的 `apt`
安装命令。

手工安装步骤见 [docs/manual_wsl_ubuntu_install.md](docs/manual_wsl_ubuntu_install.md)。

## 编译和运行

```sh
make clean
make
make run
```

等价 QEMU 命令：

```sh
qemu-system-loongarch64 -M virt -m 512M -nographic -kernel build/minios.elf
```

调试：

```sh
make debug
gdb-multiarch build/minios.elf
(gdb) target remote :1234
```

## 第 1-2 周预期输出

```text
miniOS booting...
Hello, LoongArch miniOS!
data section ok
bss section cleared
week1-week2 check done
```

## 目录结构

```text
miniOS/
├── boot/       # 启动汇编、异常入口预留
├── kernel/     # 内核主流程、printk、异常、系统调用框架
├── lib/        # 汇编库函数
├── include/    # 头文件
├── scripts/    # 环境检查脚本
├── docs/       # 移植说明
├── user/       # 后续用户态实验预留目录
├── tests/      # 测试说明
├── Makefile
└── README.md
```

## 移植指南

见 [QEMU→龙芯先锋板移植指南](docs/QEMU-to-Loongson-Pioneer-Porting-Guide.md)。
