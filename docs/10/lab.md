# 第 10 号课外自学实验材料：构建、链接与调试

> **2026-09-17 更新：本材料转为课外自学，不占用课堂学时，不是正式课堂检查点**
> （详见 `docs/course_structure.md` §2.7）。感兴趣或想深入理解构建/调试链路的
> 同学可自行完成，教师不在课堂验收，也不作为第 11 次课的前置要求。  
> 技术编号：`10`　|　**可选自学验收 tag**：`10-build-debug`（与 `09-trap-irq` 同一提交）  
> 配合讲义：`docs/10/lecture_notes.md`（同为课外自学材料）。  
> 合并原第 7 次课（Makefile/链接脚本/镜像结构）+ 原第 8 次课（GDB 调试与反汇编分析）。  
> **环境总手册：** `docs/student_env_runbook.md`  

## 0. 克隆仓库到本地（首次 / 换新位置 / GitHub 打不开用 Gitee）

**只需做一次**——已经克隆过、能正常 `cd` 进仓库的同学跳过，直接看下面「实验环境与准备」。
以下命令一律在 **WSL Ubuntu** 终端里执行，**不要**在 Windows PowerShell 里 `clone`
（原因：Windows 版 Git 会把换行符转成 CRLF，跟 WSL 的 LF 混用会导致 `git status`
显示一大片文件"modified"，甚至切分支时报错）。

**默认克隆**（在当前目录下新建 `miniOS` 文件夹）：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git
cd miniOS
```

**想放到指定的新位置**：在命令末尾加目标路径（目录不存在会自动创建）：

```bash
git clone https://github.com/cxi218447-byte/miniOS.git "/mnt/d/你的路径/miniOS"
```

**GitHub 打不开（校园网常见）？** 换成 Gitee 镜像，内容与 GitHub 保持同步：

```bash
git clone https://gitee.com/cxi218447-bytes/miniOS.git
cd miniOS
```

已经用 GitHub 地址克隆过、想改连 Gitee 的话不用重新克隆：

```bash
git remote set-url origin https://gitee.com/cxi218447-bytes/miniOS.git
git fetch --tags
```

## 1. 实验目标

完成本次课最小可验证闭环，主题：**构建、链接与调试**。

预期/产出：

```text
构建依赖图 + readelf/nm/objdump 摘录 + 至少两处 GDB 寄存器抄录（含 bl 前后 $ra）
```

## 2. 实验环境与准备（必须先做对）

### 2.0 课程默认前提

- **第 1 周已完成**：本机装好 **WSL + Ubuntu**（安装步骤按课堂要求，此处不重复）。
- 本实验：**先从 WSL 进入 Ubuntu，再 `cd` 仓库，最后才 `make`。**
- 总手册：`docs/student_env_runbook.md`。

### 2.1 从 WSL 进入 Ubuntu，再 make（每次实验）

| 提示符 | 你在哪 | 能否 `make` |
|---|---|---|
| `PS D:\...>` | Windows PowerShell（未进 Ubuntu） | **不能** |
| `user@xxx:~$` | 已进入 Ubuntu | **能** |

**步骤 1 — 进入 Ubuntu（在 PowerShell 里只做这一步）：**

```powershell
wsl -d Ubuntu
```

或从开始菜单打开 **Ubuntu**。成功标志：提示符变成 `用户名@主机名:~$`（没有 `PS`）。  
若失败：PowerShell 中执行 `wsl -l -v`，用列表中的 NAME：`wsl -d <NAME>`。

**步骤 2 — 已进入 Ubuntu 后：**

```bash
cd "/mnt/<盘符>/.../miniOS"    # D:\foo → /mnt/d/foo
ls Makefile
which make
which gdb-multiarch || which gdb
# 再执行本次课的 git / make
```

退出 QEMU：Ctrl+a 然后 x。  
若在 PowerShell 直接 `make` 出现 `ObjectNotFound`：说明还没执行步骤 1。

- 工具：`make`、`loongarch64-linux-gnu-gcc`（含 `readelf`/`nm`/`objdump`）、`qemu-system-loongarch64`、`gdb-multiarch`（或 `gdb`）
- 重点文件：
  - `Makefile`
  - `kernel/linker.ld`
  - `boot/start.S`
  - `build/minios.elf`（构建产物，含调试信息）

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-10-lab <本次课tag>
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `10-build-debug`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-10-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

### Task1 构建

- `make clean && make`，记录生成的 `minios.elf`/`minios.bin`。

### Task2 读 Makefile 与链接脚本

- 解释 `CFLAGS` 中 freestanding/nostdlib 的含义；指出 `SRCS_C`/`SRCS_S` 包含哪些启动关键文件。
- 在 `kernel/linker.ld` 中找到 `ENTRY(_start)`、`KEEP(.text.boot)`、`__bss_start/__bss_end`。

### Task3 静态工具摘录

- `readelf -S build/minios.elf`、`nm build/minios.elf`（或等价）摘录 `_start` 与 `.bss` 边界相关行。

### Task4 GDB 断点跟踪

```bash
make debug
# 另开一个 Ubuntu 终端
gdb-multiarch build/minios.elf
```

```text
target remote :1234
b _start
b clear_bss
b kernel_main
c
si
info registers
```

- 记录设栈后的 `$sp`。
- **重点**：记录 `bl clear_bss` 前后 `$pc`/`$ra` 的变化，说明为什么返回后能回到正确位置（对照第 6 次课）。

### Task5 综合笔记

- 整理一条从入口到 `printk` 输出路径的指令级要点（不必逐条抄全）。

## 4. 验收标准

- 能画出 源→.o→elf→bin→qemu 链路
- 能说明 `__bss_*` 不是 C 数组，而是链接器生成的符号
- 有真实 GDB/objdump/readelf 记录，重点覆盖 `bl` 对 `$ra` 的影响
- 能区分 `si` 与 `n` 的使用场景
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行

## 5. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 问题与解决过程（若有）
5. 思考题作答

## 6. AI 共学边界

允许解释参数与 GDB 命令；链接报错与寄存器数值必须以真实日志/真实调试会话为准，不得编造。

## 7. 思考题

1. 漏链接 `start.S` 会怎样？
2. 只有 `.bin` 没有 `.elf` 对调试的影响？
3. `-O2` 对单步体验（`si` vs `n`）的影响？
4. 板级没有 GDB 时，如何用 `printk` 做穷人调试？

## 8. 提交清单

- [ ] 实验报告（PDF/Markdown）
- [ ] 关键输出摘录（readelf/nm/objdump + GDB 会话）
- [ ] 需要提交的代码补丁或笔记（按教师要求）

## 9. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称；确认第 1 周已安装 Ubuntu |
| Ubuntu 里 `command not found: make`/`gdb-multiarch` | 见 runbook 安装交叉工具链与 GDB |
| 找不到 Makefile | 检查是否已在 Ubuntu 中 `cd` 到 miniOS 根目录 |
| GDB 连不上 `:1234` | 确认 `make debug` 仍在前台运行，未被 Ctrl+C 中断 |
| 退不出 QEMU | Ctrl+a 然后 x |
