# 第 4 次课实验指导书：访存指令与内存数据组织

> 技术编号：`04`　|　建议检查点：`04-load-store`  
> 配合教师讲义：`docs/04/lecture_notes.md`  
> 环境总手册：`docs/student_env_runbook.md`  

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

本实验配合 4 学时（每学时 45 分钟）教学，分成两个 90 分钟实验单元，均采用“**预测—运行—解释**”闭环。完成后应能：

1. 计算基址+偏移形成的有效地址。
2. 解释访存宽度、加载扩展和存储截断。
3. 用访存模型解释 `.bss` 清零和 UART MMIO。
4. 跑通“内存→浮点寄存器/运算→结果观察”的示例。
5. 区分普通读改写、原子操作和访存顺序。

## 2. 环境准备

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

教师发布 tag 后执行：

```bash
git fetch --tags
git switch -c my-04-lab 04-load-store
```

`my-04-lab` 是学生本地分支，远程没有同名分支是正常现象。若教师尚未发布 tag，以课堂指定 checkpoint 为准，不要把占位文字当成命令参数。

### 2.3 重点文件

```text
boot/start.S
lib/mem_fp.S
include/mem_fp.h
kernel/main.c
kernel/printk.c
include/uart.h
kernel/linker.ld
```

## 3. 实验安排

| 教学单元 | 对应学时 | 实验内容 | 建议完成点 |
|---|---|---|---|
| 单元一：普通访存闭环 | 第 1–2 学时 | Task 1–4 + Task 7 中的普通访存输出 | 第 2 学时结束 |
| 单元二：并发推演与浮点闭环 | 第 3–4 学时 | Task 8–10 + Task 5–7 | 第 4 学时结束 |

Task 8–10 是第 3 学时的纸面推演，不要求改内核；Task 5–7 是第 4 学时的运行实验。教师可在第 2 学时结束时先验收普通访存部分，在第 4 学时结束时完成总验收。

## 4. 实验前预测表（每个单元运行前填写）

| 问题 | 预测 |
|---|---|
| `$sp=0x80001000`，`ld.d $t1,$sp,16` 的有效地址 |  |
| 内存字节为 `0x80`，`ld.b` 后的 64 位值 |  |
| 同一字节用 `ld.bu` 后的 64 位值 |  |
| `$t2=0x1122334455667788`，`st.h` 写入哪两字节 |  |
| `1.5f+2.5f` 的数值与 binary32 十六进制位模式 |  |

不得先抄运行结果。预测错误不扣除过程分，但必须在实验后解释错误原因。

## 5. 单元一：普通访存闭环（第 1–2 学时）

### Task 1：有效地址与状态变化

解释：

```asm
ld.d    $t1, $sp, 16
```

报告必须分别写出：

- 助记符的动作和宽度；
- 三个操作数的角色；
- 有效地址计算；
- 哪个寄存器/内存区域改变，哪些保持不变。

再手写字节数组 `base[0] + base[1] → base[2]`，假设基址在 `$t0`。建议使用 `ld.bu` 和 `st.b`，并说明加法结果超过 8 位时 store 会发生什么。

### Task 2：有符号与无符号加载

阅读 `lib/mem_fp.S` 中的有符号/无符号字节加载示例。先完成预测表，再运行：

```bash
make clean
make
make run
```

核对：

```text
mem ld.b  (signed)   0x80 -> -128
mem ld.bu (unsigned) 0x80 -> 128
```

解释两条指令为何读取相同字节却得到不同的 64 位寄存器值。说明为什么 store 家族没有 `st.bu`。

### Task 3：`clear_bss` 与半开区间

在 `boot/start.S` 的清零循环旁做笔记，标出：

| 角色 | 对应寄存器/指令 |
|---|---|
| 当前游标 |  |
| 结束地址 |  |
| 终止条件 |  |
| 写入一个零字节 |  |
| 游标步进 |  |

用 `[start,end)` 表示实际被写入的地址范围，并说明为什么结束地址本身不写。

### Task 4：UART MMIO

阅读 `uart_putc` 或当前工程等价实现：

1. 找出 UART 基地址从哪里获得。
2. 找出最终向设备地址执行的 store。
3. 写出该指令的助记符、操作数和状态变化。
4. 说明普通内存 store 与 MMIO store 的共同点，以及 MMIO 的设备副作用。
5. 说明 C 中 `volatile` 约束的对象是编译器优化；不要把它等同于跨核内存栅障。

### 单元一阶段验收

完成 Task 1–4 后，只核对普通访存部分：

```text
mem ld.d/st.d: copied 0x1122334455667788
mem ld.bu/st.b: 40+2 = 42
mem ld.b  (signed)   0x80 -> -128
mem ld.bu (unsigned) 0x80 -> 128
```

将预测表中地址、扩展和截断三项与结果对照，完成第 2 学时出口题。

## 6. 单元二 A：并发访存纸面推演（第 3 学时）

### Task 8：普通读改写为何丢失更新

假设共享变量 `a=3`，两个执行者都执行：

```asm
ld.w      $t0, $a0, 0
addi.w    $t1, $t0, 1
st.w      $t1, $a0, 0
```

画出一种最终得到 `a=4` 的交错顺序，再回答：问题来自单条 `ld.w` 不原子，还是三条指令合起来不是一个不可分割整体？

### Task 9：LL/SC 纸面推演

```asm
retry:
    ll.w      $t0, $a0, 0
    addi.w    $t1, $t0, 1
    sc.w      $t1, $a0, 0
    beqz      $t1, retry
```

分别推演：

1. 链接期间无人写该地址，`sc.w` 成功。
2. 另一执行者先写该地址，`sc.w` 失败并重试。

注意记录 `sc.w` 执行后 `$t1` 保存的是成功标志，不再是候选新值。

### Task 10：原子性与顺序性

用不超过 100 字回答：

- LL/SC 或 AM 指令族主要解决什么问题？
- `DBAR` 主要解决什么问题？
- `IBAR` 与 `DBAR` 的对象有何不同？

本任务只做概念推演。当前实验不要求多核运行、异常处理或实现锁。

## 7. 单元二 B：浮点闭环（第 4 学时）

### Task 5：浮点表示、运算与访存链

核对串口输出：

```text
float fadd.s: 1.5+2.5 -> bits 0x40800000
float fadd.d: 1.5+2.5 -> (int)4
```

完成以下解释：

1. 把 `0x40800000` 拆成 S、E、F，按 binary32 公式还原为 `4.0`。
2. 在 `fp_add_s` 中指出参数寄存器、目的寄存器和返回值寄存器。
3. 解释 `fadd.s` 改变什么状态；`fp_bits_s` 中的 `movfr2gr.s` 是否重新计算数值。
4. 写出一个“`fld.d` 读两个 double → `fadd.d` → `fst.d` 写第三个位置”的四条指令骨架，逐条标明内存或 FPR 的变化。

### Task 6：位模式搬运与数值转换

阅读：

```asm
movgr2fr.w    $fa0, $a0
ffint.d.w     $fa0, $fa0

ftintrz.w.d   $fa0, $fa0
movfr2gr.s    $a0, $fa0
```

逐条标记“搬位模式”或“转换数值”。核对：

```text
float int->double->int: 7 -> 7
```

说明 `ftintrz` 中 `rz` 的舍入方向，以及为什么只执行 `movgr2fr.w` 不能得到数值意义上的 `7.0`。

### Task 7：完整闭环验收

串口应出现以下摘要（以前面课次输出正常为前提）：

```text
mem ld.d/st.d: copied 0x1122334455667788
mem ld.bu/st.b: 40+2 = 42
mem ld.b  (signed)   0x80 -> -128
mem ld.bu (unsigned) 0x80 -> 128
float fadd.s: 1.5+2.5 -> bits 0x40800000
float fadd.d: 1.5+2.5 -> (int)4
float int->double->int: 7 -> 7
04-load-store check done
```

将实验前预测与真实输出逐项对照。报告中至少选择一个预测错误或最容易错的项目，解释根因。

## 8. 验收标准

- 能按“助记符—操作数—状态变化”解释代表性访存和浮点指令。
- 有效地址、访问宽度和加载扩展均判断正确。
- 能解释 store 的低位截断、`.bss` 半开区间和 UART MMIO 副作用。
- 能区分浮点位模式搬运、数值转换和浮点运算。
- 能解释普通读改写、LL/SC 和 `DBAR` 的职责差异。
- `make run` 产生与 checkpoint 一致的真实输出。

## 9. 实验报告与提交清单

报告至少包含：

1. OS/WSL、交叉编译器和 QEMU 版本摘要；
2. 实验前预测表及运行后订正；
3. 必做任务的代码注释、地址演算和真实输出；
4. 至少一幅内存/FPR 状态变化图；
5. 遇到的问题、定位过程和解决办法；
6. Task 8–10 的纸面答案（教师可按课时指定其中一项）。

提交：

- [ ] 实验报告（Markdown 或 PDF）
- [ ] 关键串口输出摘录
- [ ] 按教师要求提交的代码补丁或课堂笔记

## 10. AI 共学边界

可以让 AI 辅助画内存格子、检查 IEEE 754 拆位或模拟指令交错；最终报告必须保留学生自己的预测、逐步状态变化和真实运行输出，不得用生成内容替代运行。

## 11. 常见故障

| 现象 | 处理 |
|---|---|
| PowerShell 报找不到 `make` | 先执行 `wsl -d Ubuntu`，进入仓库后再构建 |
| `wsl -d Ubuntu` 失败 | 用 `wsl -l -v` 核对发行版名称 |
| Ubuntu 中找不到工具 | 按 `docs/student_env_runbook.md` 安装课程工具链 |
| 找不到 Makefile | 检查当前目录是否为 miniOS 仓库根目录 |
| 执行浮点指令后异常 | 检查 `CSR.EUEN.FPE` 是否在浮点代码前使能 |
| 退出不了 QEMU | `Ctrl+a`，再按 `x` |
