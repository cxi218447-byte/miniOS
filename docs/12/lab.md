# 第 12 次课实验指导书：板级迁移 + 综合实验：从 miniOS 到 Agent OS

> 技术编号：`12`　|　建议检查点：`12-board-agent-demo`　|　4 学时连排（纯实验课）  
> 称"第 12 次课"，不称"第 12 周"。配合讲义：`docs/12/lecture_notes.md`。  
> 合并原「QEMU 到 2K0300 启动与 UART 适配」+ 原「综合实验：从 miniOS 到 Agent OS」。  
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

本实验配合 4 学时（每学时 45 分钟）教学，分成两个前后衔接的单元。完成后应能：

1. 完成 QEMU virt vs 2K0300 差异表，指出仓库中平台相关文件/宏。
2. （条件具备时）在板端得到至少一个可见字符或 Hello 输出。
3. 脱稿讲述全课程三阶段主线，完成一个可运行、可讲解的综合展示。
4. 提交架构图、关键汇编注释、真实运行记录，以及"下一迭代 3 件事"。

## 2. 实验环境与准备（必须先做对）

### 2.1 必须在 WSL/Ubuntu 中构建

在 Windows PowerShell 中进入 Ubuntu：

```powershell
wsl -d Ubuntu
```

提示符变为 `user@host:~$` 后，再进入仓库并检查工具：

```bash
cd "/mnt/d/工作/日常教学/2026-2027第一学期/汇编语言/miniOS"
ls Makefile
which make
which loongarch64-linux-gnu-gcc
which qemu-system-loongarch64
```

不要在 `PS D:\...>` 提示符下直接执行 `make`。退出 QEMU：先按 `Ctrl+a`，再按 `x`。

### 2.2 建立个人实验分支

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-12-lab 12-board-agent-demo
```

`my-12-lab` 是学生本地分支，远程没有同名分支是正常现象。若教师尚未发布 tag，以课堂指定 checkpoint 为准。

### 2.3 重点文件

```text
include/uart.h
kernel/linker.ld
kernel/printk.c
boot/start.S
（综合展示阶段：按选题追加全课程相关模块）
```

## 3. 实验安排

| 教学单元 | 对应学时 | 实验内容 | 建议完成点 |
|---|---|---|---|
| 单元一：板级迁移 | 第 1–2 学时 | Task 1–4 | 第 2 学时结束 |
| 单元二：综合展示 | 第 3–4 学时 | Task 5–8 | 第 4 学时结束 |

## 4. 单元一：板级迁移（第 1–2 学时）

### Task1 差异表

- 填写入口地址、UART、加载方式、调试手段对照（QEMU virt vs 2K0300）。

### Task2 修改点清单

- 列出移植时优先改哪些文件/宏，给出平台目录草案。

### Task3 排错顺序

- 写出：`_start` → `$sp` → `clear_bss` → UART 的定位顺序，对照讲义 §4.4 故障分层表。

### Task4 板端实践

- 条件允许：完成至少一字符或 Hello 输出。
- 否则：给出完整模拟方案与风险分析（哪一步最可能出问题、如何验证）。

### 单元一阶段验收

- 差异表完整，有可执行的移植步骤。
- 故障分层（无输出/乱码/首字符）说得清。

## 5. 单元二：综合展示（第 3–4 学时）

### Task5 选题

- 三选一或组合：A 启动与服务 / B 板级迁移（可直接复用单元一成果）/ C Agent Runtime 雏形。

### Task6 演示准备

- 5–8 分钟讲述稿：主线三阶段 + 现场讲解 4 类点（启动路径、一条运算或访存指令、一个循环或调用、一个系统点）。
- 至少脱稿讲清 `_start` 的四行核心指令，及其回连的课次（讲义 §5.2）。

### Task7 运行证据

- 提交真实输出/板级记录/调试摘录（可截断，不可编造）。

### Task8 展望

- 写出"若继续做 Agent OS，下一迭代 3 件事"。

## 6. 验收标准

- 能脱稿讲清第 1–2 次课与第 3–6 次课的衔接
- 演示可运行、可追问
- 报告含架构图与汇编注释
- 差异表完整，移植步骤可执行
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行

## 7. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 问题与解决过程（若有）
5. 思考题作答

## 8. AI 共学边界

允许整理移植检查单、架构图与报告润色；地址切勿臆造，展示追问必须学生本人回答。

## 9. 思考题

1. 为何先移植输出再移植中断？
2. 乱码优先怀疑什么？教学内核是否开 MMU？
3. 从 miniOS 到通用 OS 你认为最关键的下一步？
4. 不可信技能需要的最小隔离是什么？

## 10. 提交清单

- [ ] 实验报告（PDF/Markdown）
- [ ] 关键输出摘录（含板级/QEMU 对照）
- [ ] 综合展示讲述稿要点
- [ ] 需要提交的代码补丁或笔记（按教师要求）

## 11. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称 |
| Ubuntu 中找不到工具 | 按 `docs/student_env_runbook.md` 安装课程工具链 |
| 板端完全无输出 | 先确认是否跑到 `_start`、加载方式、时钟配置 |
| 板端输出乱码 | 优先怀疑波特率/时钟 |
| 退不出 QEMU | `Ctrl+a`，再按 `x` |
