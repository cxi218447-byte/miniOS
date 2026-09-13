# 第 9 次课实验指导书：异常与中断处理

> 技术编号：`09`　|　建议检查点：`09-trap-irq`  
> 称"第 9 次课"，不称"第 9 周"。配合讲义：`docs/09/lecture_notes.md`。  
> **学生自学教材：** `docs/09/week09_异常与中断处理教材.md`——建议先读教材建立概念，再做下面的 Task1–Task6，卡壳时按 Task 里标注的教材节号去查对应讲解。  
> 合并原第 12 次课（异常入口与异常上下文）+ 原第 13 次课（中断基础与定时器）**理论部分**。
> 定时器上机实现留到第 11 次课（纯实验课），本次课任务以精读、对照与设计为主。  
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

完成本次课最小可验证闭环，主题：**异常与中断处理**。

预期/产出：

```text
exception_entry 指令表 + 异常vs中断对照表 + tick 设计（伪代码）
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
  - `boot/start.S`（`exception_entry`，本课新增）
  - `kernel/exception.c`（本课可运行 demo：`exception_init`/`exception_handler`）
  - `include/exception.h`

### 2.2 关于 `my-weekXX-lab` 分支（必读）

若本次课要求从 tag 建分支，命令形如（**在已进入的 Ubuntu 里执行**）：

```bash
git fetch --tags
git switch -c my-09-lab <本次课tag>
```

| 名称 | 是什么 | 在远程 `origin` 上？ |
|---|---|---|
| 本次课 tag（如 `09-trap-irq`） | 老师发布的固定验收快照 | **有** |
| `master` | 已发布到的最新课次纯净代码 | **有** |
| `my-09-lab` | **你自己的本地实验分支**（名字可改） | **默认没有** |

- 远程没有 `my-weekXX-lab` 是正常设计。
- 详见：`docs/01/student_git_tag_guide.md`、`docs/student_env_runbook.md`。

## 3. 实验任务（默认均在已进入的 Ubuntu、仓库根目录）

### Task1 精读异常入口

- 逐条注释 `exception_entry`，标出伸栈/存 `$ra`/`csrrd`/`bl`/恢复/`ertn`（对照教材 §2 逐行精读）。
- 书面回答：本课的 `exception_entry` 为什么只存 `$ra` 就够了？这是不是"最终版本"（教材 §2.6"教学取舍"）？

### Task2 对照三条路径

- 比较普通 `bl`/`jr $ra`、异常 `ertn`、中断入口骨架三者的异同（讲义 §4.1，教材 §1）。
- 说明为何不宜把普通 C 函数地址直接当异常向量（教材 §1.1）。

### Task3 初始化与观察

- 解释 `exception_init` 写 EENTRY 的作用（教材 §4）。
- 运行 `make run`，观察 `kernel_main` 用 `break 0` 主动触发的异常：`ESTAT`/`ERA` 真实打印值。
- **踩坑题**：`exception_handler` 为什么要 `return era + 4`，而不是原样返回 `era`？（提示：先把 `return era + 4` 改回 `return era`，重新 `make run`，观察会发生什么，再改回来。教材 §3 有完整推导。）

### Task4 异常 vs 中断对照表

- 完成对照表：触发方式、可屏蔽性、教学重点。
- 注释中断入口骨架（讲义 §4.5，教材 §6）为何比 `exception_entry` 更重（教材 §6.1 关键区别：中断可能打在任意一条指令之间）。

### Task5 精读教材 §7.3 真实定时器代码 + tick 设计

教材 §7.3 给出了一段**首尾完整、CSR 编号真实**的定时器使能/处理/清源代码（不是纸面伪代码），本任务要求先精读它，再基于它做设计：

1. **精读使能代码**（教材 §7.3 第一步）：逐行解释为什么是"先 `csrrd` 读出 ECFG/CRMD 当前值，只改需要的那一位，再 `csrwr` 写回"，而不是直接拼一个新值写进去。
2. **精读处理分支**（教材 §7.3 第二步）：在 `exception_handler` 新增的 `is & (1UL << 11)` 分支里，找出"配置→使能→处理→清源"四步（教材 §7.1）分别对应哪几行代码。
3. **对比踩坑**：这个中断分支 `return era`（不 `+4`），Task3 的 `break` 分支 `return era + 4`——书面说明为什么两者刚好相反（教材 §7.3 第三步 vs §3）。
4. **（选做）内联汇编语法**：解释 `__asm__ volatile("csrrd %0, 0x4" : "=r"(ecfg))` 里 `%0`、`"=r"` 分别是什么意思（教材 §7.3"内联汇编语法拆解"）。
5. 基于以上精读结果，设计 `ticks` 变量与打印策略（每 N 次打一次），伪代码即可——具体上机实现放在第 11 次课。
6. 说明 `ticks` 与第 2 次课 `.bss` 清零的关系（教材 §7.2）。

### Task5.5 并发与临界区（必做，书面）

对应教材 §8，本课不要求实现锁，但要求想清楚风险和取舍：

1. 为什么主循环和中断处理函数同时 `printk` 会导致字符交错的乱码？（教材 §8.1，呼应第 8 次课"两个执行流同时 `printk` 会怎样"）
2. "短时间关中断保护共享数据"这个对策的代价是什么？为什么关中断的时间不能太长？（教材 §8.2）
3. 结合 Task4 的中断入口"更重"结论，说说"中断处理函数要尽量短"这条原则和本任务第 2 问是不是同一件事的两个角度。

### Task6 运行验收

```bash
make clean
make
make run
```

核对串口输出（`Ctrl+a` 再 `x` 退出 QEMU）：

```text
exception_init: EENTRY set to exception_entry
[exception] ESTAT=0xc0000 ERA=0x200798
resumed after break: ertn returned control here
week09-trap-irq check done
```

`ERA` 的具体数值会随编译结果小幅变化，属正常现象；`ESTAT=0xc0000`（Ecode=0xC，BRK）应保持稳定。

## 4. 验收标准

- 能说明为何入口要存 `$ra` 再 `bl` 到 C，能区分 ERA 与 `$ra`
- 有书面的 `exception_entry` 指令影响表
- 异常 vs 中断概念对照正确，tick 故事线完整
- 提到 `.bss` 清零与 `ticks` 的关系
- 能逐行解释教材 §7.3 真实代码里"先读再改再写"的 CSR 操作套路，能说明中断分支为什么 `return era` 而不是 `era + 4`（Task5）
- 能说清主循环与中断同时 `printk` 为什么会乱码、关中断保护临界区的代价是什么（Task5.5）
- 能说明：`make` 须在 WSL/Linux 执行，不能在 Windows PowerShell 直接执行
- `make run` 输出与上方 Task6 摘录一致，能解释 `era + 4` 踩坑题

## 5. 实验报告要求

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. 对核心代码/指令的简要注释或流程图
4. 教材 §7.3 真实代码精读笔记（Task5）与并发/临界区书面作答（Task5.5）
5. 问题与解决过程（若有）
6. 思考题作答

## 6. AI 共学边界

允许解释 CSR 摘要、整理中断概念图、协助理解教材 §7.3 的内联汇编语法；编号/寄存器地址以讲义/教材/手册为准，不得凭空编造。

## 7. 思考题

1. 处理函数内再次异常会怎样？
2. 与中断入口的同构点与不同点？
3. 为何中断处理要尽量短？
4. tick 里做复杂内存分配的风险？

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
