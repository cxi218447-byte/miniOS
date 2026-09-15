# 第 8 次课实验指导书：UART 驱动、输出子系统与系统调用 sys_write

> 技术编号：`08`　|　建议检查点：`08-uart-syscall`  
> 称“第 8 次课”，不称“第 8 周”。配合讲义：`docs/08/lecture_notes.md`。  
> 合并原第 10 次课（UART 驱动与输出子系统）+ 原第 11 次课（系统调用 sys_write）。  
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

完成本次课最小可验证闭环，主题：**UART 驱动、输出子系统与系统调用 sys_write**。

预期/产出：

```text
调用图 + 抽象改进提案 + sys_write 约定文档 + 合法/非法 fd 测试记录
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
# 再执行本次课的 git / make
```

退出 QEMU：Ctrl+a 然后 x。  
若在 PowerShell 直接 `make` 出现 `ObjectNotFound`：说明还没执行步骤 1。

- 工具：`make`、`loongarch64-linux-gnu-gcc`、`qemu-system-loongarch64`
- 重点文件：
  - `kernel/printk.c`（第 1 次课已有的 UART 输出路径）
  - `include/uart.h`
  - `kernel/syscall.c`（本课可运行 demo：`sys_write`/`syscall_dispatch`）
  - `include/syscall.h`

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-08-lab <本次课tag>
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `08-uart-syscall`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-08-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

### Task1 调用图

- 画出 `printk → uart_puts → uart_putc → MMIO`，再接上 `sys_write → syscall_dispatch`。

### Task2 输出子系统代码阅读

- 解释 `volatile` 与 `UART0_BASE`。
- 说明为何 `\n` 要补 `\r`。

### Task3 抽象提案

- 写一页：如何把基址/init 收拢到 platform 层（`struct uart_device` 思路，见讲义 §4.3）。

### Task4 sys_write 精读与约定

- 精读 `sys_write` 与 `syscall_dispatch`。
- 文档化：系统调用号、参数寄存器、返回值、错误码。
- 说明 `printk` 与 `sys_write` 的关系与差异。

### Task5 测试

- 验证合法 fd（1/2）与非法 fd 的返回行为（可加临时测试代码，提交前说明）。

### Task6（选做）

- 给出轮询 LSR 再发送的伪代码或汇编骨架（`uart_putc_robust`）。

### Task7 运行验收

```bash
make clean
make
make run
```

核对串口输出（`Ctrl+a` 再 `x` 退出 QEMU）：

```text
sys_write via dispatch
sys_write fd=1 : return len = 23
sys_write fd=99: return = -1 (应为 -1，非法 fd 被拒绝)
dispatch nr=?? : return = -1 (应为 -1，未知系统调用号)
week08-uart-syscall check done
```

## 4. 验收标准

- 调用图正确，覆盖 UART 与 syscall 两层
- 能从访存角度解释串口写
- 有可执行的平台参数集中化建议
- 分发逻辑清楚，约定文档可给同学照做
- 有真实运行/返回值记录（含非法 fd 的 -1）
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行
- `make run` 输出与上方 Task7 摘录一致

## 5. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 问题与解决过程（若有）
5. 思考题作答

## 6. AI 共学边界

允许查 16550 概念、对比 Linux write 语义；基址与行为以课程头文件/代码为准，不得凭空编造。

## 7. 思考题

1. 多上下文同时 `printk` 的风险？
2. 轮询 vs 中断驱动？
3. 为何要统一入口而不是给每个服务一个裸函数地址？
4. 用户指针校验在真实 OS 中为何关键？

## 8. 提交清单

- [ ] 实验报告（PDF/Markdown）
- [ ] 关键输出摘录
- [ ] 需要提交的代码补丁或笔记（按教师要求）

## 9. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称；确认第 1 周已安装 Ubuntu |
| Ubuntu 里 `command not found: make` | 见 runbook 安装交叉工具链 |
| 找不到 Makefile | 检查是否已在 Ubuntu 中 `cd` 到 miniOS 根目录 |
| 退不出 QEMU | Ctrl+a 然后 x |
