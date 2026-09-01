# LoongArch 汇编 miniOS 实验

本仓库用于 LoongArch 汇编课程实验。课程资料按“2 节课 = 1 次课”组织，共 12 次课（第 3、4、11、12 次课各为 4 节课连排；2026-08-29 起的学时重排与课次合并详见 `docs/course_structure.md`）。若实际排课为一周 4 节课，则一个行政教学周通常连续完成两次课。

## 课次代码纯净原则

**每次课的代码通过 git tag 区分；除“本次课跑通所必需”的内容外，不提前混入后续课次的框架代码。**

| 原则 | 说明 |
|---|---|
| 按 tag 取代码 | 学生用 `git switch -c my-lab <tag>`，不要在混杂的全量树上做早期实验 |
| 必需才保留 | 如第 1 次课必须有 UART/`printk` 才能 Hello；第 2 次课必须有 `clear_bss` 与最小 `string.S` |
| 后续课后置 | 异常入口、系统调用、中断等**只在对应课次 tag 出现**，早期 tag 中不出现 |
| `master` 含义 | 当前已发布到的最新课次纯净树（现为第 12 次课） |

**第 1–2 次课主题固定**（工程入口）：

- 第 1 次课：从 0 启动 LoongArch miniOS（tag：`01-qemu-hello`）
- 第 2 次课：`.data/.bss` 初始化与 C/汇编混合启动（tag：`02-data-bss`）

**从第 3 次课起**回填并系统化汇编基础（寄存器、基础指令、访存、程序设计、调用约定），再进入构建、调试、内核服务、板级与 Agent：

- 第 3 次课：寄存器、数据表示与基础指令（tag：`03-regs-alu`）
- 第 4 次课：访存指令与内存数据组织 + 浮点基础（tag：`04-load-store`）
- 第 5 次课：分支、循环与汇编程序设计基础（tag：`05-branch-loop`）
- 第 6 次课：函数调用约定与栈帧（tag：`06-stack-abi`）
- 第 7 次课：构建、链接与调试（tag：`07-build-debug`）
- 第 8 次课：`memset`/`memcpy`/`strlen` 汇编实现（tag：`08-libc-asm`）
- 第 9 次课：UART 驱动、输出子系统与系统调用 `sys_write`（tag：`09-uart-syscall`）
- 第 10 次课：异常与中断处理（理论部分）（tag：`10-trap-irq`）
- 第 11 次课：中断/定时器实验 + miniOS 内核服务整理（tag：`11-irq-kernel-recap`）
- 第 12 次课：板级迁移 + 综合实验：从 miniOS 到 Agent OS（tag：`12-board-agent-demo`，与 `11-irq-kernel-recap` 同一代码状态——板级迁移需要真实 2K0300 硬件，综合展示直接复用已有 `kernel_main`）

详见本地 `docs/course_structure.md`。

```bash
git fetch --tags
git switch -c my-01-lab 01-qemu-hello     # 第 1 次课：本地实验分支
git switch -c my-02-lab 02-data-bss       # 第 2 次课：另建本地分支
git switch -c my-03-lab 03-regs-alu       # 第 3 次课：另建本地分支
git switch -c my-04-lab 04-load-store     # 第 4 次课：另建本地分支
git switch -c my-05-lab 05-branch-loop    # 第 5 次课：另建本地分支
git switch -c my-06-lab 06-stack-abi      # 第 6 次课：另建本地分支
git switch -c my-07-lab 07-build-debug    # 第 7 次课：另建本地分支
git switch -c my-08-lab 08-libc-asm       # 第 8 次课：另建本地分支
git switch -c my-09-lab 09-uart-syscall   # 第 9 次课：另建本地分支
git switch -c my-10-lab 10-trap-irq       # 第 10 次课：另建本地分支
git switch -c my-11-lab 11-irq-kernel-recap  # 第 11 次课：另建本地分支
git switch -c my-12-lab 12-board-agent-demo  # 第 12 次课：另建本地分支
```

**说明（重要）：**

- `01-qemu-hello` … `12-board-agent-demo` 是**远程已发布的课程 tag**（全班统一起点）。2026-08-29 起技术编号去掉 `week` 前缀改为纯数字；原 `week01-qemu-hello` 等 tag 已在远程删除，如你之前已 fetch 过旧 tag，请重新 `git fetch --tags --prune` 同步。  
- `my-01-lab` … `my-12-lab` 是**你在本机新建的个人实验分支**，**默认不会、也不需要**出现在 GitHub 上。  
- 命令含义是「从 tag 复制一份到本地再改」，不是「去远程领取一个叫 my-NN-lab 的分支」。  
- 课程远程只维护 `master` + 各课次 tag；个人分支请留在本地（详见实验指导书与 `docs/01/student_git_tag_guide.md`）。

### 已发布 tag 与源码范围

| tag | 课次 | 源码范围（相对前一阶段的增量） |
|---|---|---|
| `01-00-skeleton` | 第 1 次课检查点 | 仅有 `_start` 原地 halt |
| `01-01-stack-setup` | 第 1 次课检查点 | 设置 `$sp` |
| `01-02-kernel-main-empty` | 第 1 次课检查点 | `bl kernel_main`，主函数为空 |
| `01-03-printk-uart` | 第 1 次课检查点 | `printk` + UART，输出 Hello |
| `01-qemu-hello` | 第 1 次课验收 | 与 `01-03` 相同，正式验收点 |
| `02-data-bss` | 第 2 次课验收 | `clear_bss` + `.data/.bss` 验证 + 最小 `string.S` |
| `03-regs-alu` | 第 3 次课验收 | `lib/regs_alu.S` + `include/regs_alu.h`：教材第 3 章 §3.1 每类运算指令 ≥1 条 |
| `04-load-store` | 第 4 次课验收 | `lib/mem_fp.S` + `include/mem_fp.h`：§3.2 访存（`ld/st` 全家）+ 第 4 章浮点（`fadd`/位模式/转换） |
| `05-branch-loop` | 第 5 次课验收 | `lib/branch_loop.S` + `include/branch_loop.h`：`b`/`beq`/`bne`/`beqz`/`bnez` 全覆盖 |
| `06-stack-abi` | 第 6 次课验收 | `lib/stack_abi.S` + `include/stack_abi.h`：叶子/非叶子函数，栈帧保存/恢复 `$ra` |
| `07-build-debug` | 第 7 次课验收 | 与 `06-stack-abi` 相同代码：本课不新增源文件，只用 readelf/nm/objdump/GDB 分析已有构建产物 |
| `08-libc-asm` | 第 8 次课验收 | `kernel/main.c` 新增 `memset`/`memcpy`/`strlen` 边界测试（实现沿用第 2 次课 `lib/string.S`） |
| `09-uart-syscall` | 第 9 次课验收 | `kernel/syscall.c` + `include/syscall.h`：`sys_write`/`syscall_dispatch`（UART 驱动沿用第 1 次课） |
| `10-trap-irq` | 第 10 次课验收 | `boot/start.S` 新增 `exception_entry`；`kernel/exception.c` + `include/exception.h`：`exception_init`/`exception_handler` |
| `11-irq-kernel-recap` | 第 11 次课验收 | `boot/start.S` `exception_entry` 升级为144字节完整寄存器保存；`kernel/irq.c` + `include/irq.h`：`timer_init`/`irq_dispatch`/`timer_stop`，`exception_handler` 新增 `Ecode==0` 中断分支 |
| `12-board-agent-demo` | 第 12 次课验收 | 与 `11-irq-kernel-recap` 相同代码：板级迁移需要真实硬件，综合展示复用已有 `kernel_main` |

第 1 次课**不包含**：`clear_bss`、`lib/string.S`、异常、系统调用。  
第 2 次课**不包含**：异常、系统调用、中断；`string.S` 仅为 C 调汇编演示用的最小实现（精讲在第 8 次课）。  
第 3 次课**不包含**：访存精讲（仅 `st.b` 点到）、浮点实现、异常、系统调用、中断。  
第 4 次课**不包含**：分支/循环系统讲解（`b/bl/jirl` 只读懂示例，第 5 次课系统学）、多核实现（LL/SC、DBAR/IBAR 只做纸面推演）、异常、系统调用、中断。  
第 5 次课**不包含**：过程调用约定与栈帧（第 6 次课系统学）、异常、系统调用、中断。  
第 6 次课**不包含**：`exception_entry` 完整实现（仅在讲义中预告结构，第 10 次课系统学）、系统调用、中断。  
第 7 次课**不包含**：任何新指令/新库代码——纯工具链与调试课。  
第 8 次课**不包含**：按 8 字节对齐的优化实现（仅课堂讨论方向，不要求实现）、异常、系统调用、中断。  
第 9 次课**不包含**：真正的用户态陷入指令（教学阶段内核内直接调用 `syscall_dispatch`）、中断。  
第 10 次课**不包含**：中断/定时器代码实现（留到第 11 次课）；`exception_handler` 只演示 `break` 触发的同步异常，不识别具体 Ecode 分类处理。  
第 11 次课**不包含**：除定时器外的其他中断源（如 UART 接收中断）；用户态/多任务调度。  
第 12 次课**不包含**：真实 2K0300 板级验证（无硬件）、Agent Runtime 的实际调度/隔离实现（仅讨论）。

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

**如果这条 `apt install` 报 `Unable to locate package gcc-loongarch64-linux-gnu` /
`binutils-loongarch64-linux-gnu`**：不是操作错了，是 Ubuntu 22.04 官方源里本来
就没有这两个包。两条补救路线选一条走：

- [docs/manual_wsl_ubuntu26_install.md](docs/manual_wsl_ubuntu26_install.md)：
  改装 Ubuntu 26.04（跟现有 22.04 并列共存，不用卸载旧的），仓库里已经有这两个
  包，最省事。
- [docs/manual_wsl_ubuntu22_toolchain_build.md](docs/manual_wsl_ubuntu22_toolchain_build.md)：
  留在现有 22.04 上，自己装预编译工具链 + 编译 QEMU。

Windows 如果还没有 WSL Ubuntu，可在管理员 PowerShell 中执行：

```powershell
wsl --install -d Ubuntu --location "<你的课程工作目录>\env\wsl\Ubuntu"
```

然后进入 Ubuntu，在仓库目录对应的 `/mnt/<盘符>/<你的课程工作目录>/miniOS` 下执行上面的 `apt`
安装命令。

手工安装步骤见 [docs/manual_wsl_ubuntu22_toolchain_build.md](docs/manual_wsl_ubuntu22_toolchain_build.md)。

## 编译和运行（先进入 Ubuntu，再 make）

> **课程默认：第 1 周已装好 WSL + Ubuntu。**  
> 做实验时：**先进入 Ubuntu，再 `cd` 仓库，最后才 `make`。**  
> **禁止**在 Windows PowerShell（提示符 `PS ...>`）里直接敲 `make`。  
> 完整说明：本地 `docs/student_env_runbook.md`、各次课实验指导书 §2。

### 标准做法（每次实验都按这个顺序）

**① 在 PowerShell 中进入 Ubuntu（还不能 make）：**

```powershell
wsl -d Ubuntu
```

成功后提示符从 `PS D:\...>` 变成 `用户名@主机名:~$`。  
（也可从开始菜单打开 **Ubuntu**。）

若报错找不到发行版，先执行 `wsl -l -v` 查看名称，再 `wsl -d <NAME>`。

**② 已进入 Ubuntu 之后，再编译运行：**

```sh
cd "/mnt/<盘符>/<你的路径>/miniOS"   # 例：D:\foo\miniOS → /mnt/d/foo/miniOS
ls Makefile
make clean
make
make run
```

退出 QEMU：先 **Ctrl+a**，再按 **x**。

### 等价 QEMU 命令

```sh
qemu-system-loongarch64 -M virt -m 512M -nographic -kernel build/minios.elf
```

### 调试

```sh
make debug
gdb-multiarch build/minios.elf
(gdb) target remote :1234
```

## 第 1-4 次课阶段预期输出

第 1 次课（`01-qemu-hello`）：

```text
Hello miniOS on LoongArch64
```

第 2 次课（`02-data-bss`）：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

第 3 次课（`03-regs-alu`）：

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
arith add/sub: (3+5)-2 = 6
arith mul: 6*7 = 42
logic andi: 0x1234 & 0xff = 0x34
shift slli: 5<<1 = 10
cond slt: (3<5) = 1
bit ext.w.b: 0x7f -> 127
arith temp: (7+1)+(7+1) = 16
mem st.b: see clear_bss
branch: see bl/jr/beq in start.S
misc idle: halt loop below
float: textbook ch4, not run here
week03-regs-alu check done
```

第 4 次课（`04-load-store` / 当前 `master`，在第 3 次课输出之后追加）：

```text
mem ld.d/st.d: copied 0x1122334455667788
mem ld.bu/st.b: 40+2 = 42
mem ld.b  (signed)   0x80 -> -128
mem ld.bu (unsigned) 0x80 -> 128
float fadd.s: 1.5+2.5 -> bits 0x40800000
float fadd.d: 1.5+2.5 -> (int)4
float int->double->int: 7 -> 7
week04-load-store check done
```

以上输出已在 WSL Ubuntu + `loongarch64-linux-gnu-gcc` + `qemu-system-loongarch64` 下实际构建运行验证。控制台里的 `week03-regs-alu check done` / `week04-load-store check done` / `week1-week2 check done` 是内核代码里编译进去的字符串常量，随 `03-regs-alu`/`04-load-store` 等 tag 一并发布验收，本次改名只影响 tag/分支/文档编号，不改这些已验证过的运行时输出。

## 目录结构（第 4 次课）

```text
miniOS/
├── boot/start.S      # 设栈、clear_bss、进入 kernel_main
├── kernel/main.c     # Hello + .data/.bss + 第3次课ALU验收 + 第4次课访存/浮点验收
├── kernel/printk.c   # 串口输出
├── kernel/linker.ld  # 入口与段布局（含 __bss_start/__bss_end）
├── lib/string.S      # 最小 memset/memcpy/strlen
├── lib/regs_alu.S    # 第3次课：§3.1 每类运算指令 ≥1 条代表
├── lib/mem_fp.S      # 第4次课：§3.2 访存 + 第4章浮点代表指令
├── include/          # printk/uart/string/types/regs_alu/mem_fp
├── Makefile
└── user/             # 后续课次再用（本阶段不用）
```

## 许可证与用途

仅用于课程教学与实验。
