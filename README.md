# LoongArch 汇编 miniOS 实验

本仓库用于 LoongArch 汇编课程实验。课程资料按“2 节课 = 1 次课”组织，共 16 次课。若实际排课为一周 4 节课，则一个行政教学周通常连续完成两次课。

## 课次代码纯净原则

**每次课的代码通过 git tag 区分；除“本次课跑通所必需”的内容外，不提前混入后续课次的框架代码。**

| 原则 | 说明 |
|---|---|
| 按 tag 取代码 | 学生用 `git switch -c my-lab <tag>`，不要在混杂的全量树上做早期实验 |
| 必需才保留 | 如第 1 次课必须有 UART/`printk` 才能 Hello；第 2 次课必须有 `clear_bss` 与最小 `string.S` |
| 后续课后置 | 异常入口、系统调用、中断等**只在对应课次 tag 出现**，早期 tag 中不出现 |
| `master` 含义 | 当前已发布到的最新课次纯净树（现为第 2 次课） |

**第 1–2 次课主题固定**（工程入口）：

- 第 1 次课：从 0 启动 LoongArch miniOS（tag：`week01-qemu-hello`）
- 第 2 次课：`.data/.bss` 初始化与 C/汇编混合启动（tag：`week02-data-bss`）

**从第 3 次课起**回填并系统化汇编基础（寄存器、基础指令、访存、程序设计、调用约定），再进入构建、调试、内核服务、板级与 Agent。详见本地 `docs/course_structure.md`。

```bash
git fetch --tags
git switch -c my-week01-lab week01-qemu-hello
git switch -c my-week02-lab week02-data-bss
```

### 已发布 tag 与源码范围

| tag | 课次 | 源码范围（相对前一阶段的增量） |
|---|---|---|
| `week01-00-skeleton` | 第 1 次课检查点 | 仅有 `_start` 原地 halt |
| `week01-01-stack-setup` | 第 1 次课检查点 | 设置 `$sp` |
| `week01-02-kernel-main-empty` | 第 1 次课检查点 | `bl kernel_main`，主函数为空 |
| `week01-03-printk-uart` | 第 1 次课检查点 | `printk` + UART，输出 Hello |
| `week01-qemu-hello` | 第 1 次课验收 | 与 `week01-03` 相同，正式验收点 |
| `week02-data-bss` | 第 2 次课验收 | `clear_bss` + `.data/.bss` 验证 + 最小 `string.S` |

第 1 次课**不包含**：`clear_bss`、`lib/string.S`、异常、系统调用。  
第 2 次课**不包含**：异常、系统调用、中断；`string.S` 仅为 C 调汇编演示用的最小实现（精讲在第 9 次课）。

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
wsl --install -d Ubuntu --location "<你的课程工作目录>\env\wsl\Ubuntu"
```

然后进入 Ubuntu，在仓库目录对应的 `/mnt/<盘符>/<你的课程工作目录>/miniOS` 下执行上面的 `apt`
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

## 第 1-2 次课阶段预期输出

第 1 次课（`week01-qemu-hello`）：

```text
Hello miniOS on LoongArch64
```

第 2 次课（`week02-data-bss` / 当前 `master`）：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

## 目录结构（第 2 次课）

```text
miniOS/
├── boot/start.S      # 设栈、clear_bss、进入 kernel_main
├── kernel/main.c     # Hello + .data/.bss 验证
├── kernel/printk.c   # 串口输出
├── kernel/linker.ld  # 入口与段布局（含 __bss_start/__bss_end）
├── lib/string.S      # 最小 memset/memcpy/strlen
├── include/          # printk/uart/string/types
├── Makefile
└── user/             # 后续课次再用（本次课不用）
```

## 许可证与用途

仅用于课程教学与实验。
