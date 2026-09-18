# 第 5 次课实验指导书：分支、循环与汇编程序设计基础

> 技术编号：`05`　|　建议检查点：`05-branch-loop（可逐步补齐）`　|　**4 学时**（2026-09-17 起由 2 学时扩展，见 `docs/course_structure.md` §2.7）  
> 称"第 5 次课"，不称"第 5 周"。配合讲义：`docs/05/lecture_notes.md`。  
> **环境总手册：** `docs/student_env_runbook.md`

## 1. 实验目标

**2026-09-17 更新：实验重新设计为三个任务，前两个完全独立于 miniOS 仓库。**

```text
Task1：独立纯汇编程序——给寄存器赋值 5 和 8，交换，打印结果；改造成三寄存器轮换
Task2：独立纯汇编程序——最简单的计数循环，打印 1 到 5；改造成反向打印 5 到 1
Task3：回到 miniOS 仓库——现场共写数组查找 bl_find_first，独立实现 bl_find_last
```

Task1、Task2 都是**单文件、不依赖 miniOS 代码或 Makefile** 的最小汇编程序，跑在
`qemu-loongarch64`（用户态模拟）上，直接用 Linux 系统调用打印结果——不用写启动
代码，不用自己配 UART，专注在"寄存器怎么赋值/交换/循环"这几个动作本身。
两个都是"编程 + 截图"任务，当堂完成、当堂提交。

**Task1、Task2 各多一步"改造"要求**：给出的原始代码只是起点，照着敲完、跑通、
截图之后，还要在这份代码基础上独立改出一个新功能（不给代码，只给要求），防止
变成纯打字练习——真正考察的是这一步。

Task3 回到 miniOS 仓库加代码，延续第 3–4 学时"独立按功能写一段汇编代码"的能力
目标：先跟课堂现场共写 `bl_find_first`（在数组里找目标值第一次出现的位置，找到
就提前退出），再独立实现结构相反的 `bl_find_last`（不提前退出，扫完整个数组、
记录最后一次命中的下标）。

## 2. Task1/Task2 环境准备（不需要克隆 miniOS 仓库）

Task1、Task2 只需要：

- WSL Ubuntu（第 1 次课已装好）
- 交叉工具链 `loongarch64-linux-gnu-gcc`（第 1 次课已装好）
- **新增工具 `qemu-loongarch64`**（用户态模拟，之前课次都没用过，只有这两个任务需要）：

  ```bash
  sudo apt install -y qemu-user
  which qemu-loongarch64
  ```

  能打印出路径就说明装好了。详细步骤/排错见 `docs/05/install_qemu_user.md`（建议提前发给学生课前装好）或 `docs/student_env_runbook.md` §5.1。

- 在**任意位置**（不用在 miniOS 仓库里）新建一个空目录，例如：

  ```bash
  mkdir -p ~/asm-standalone
  cd ~/asm-standalone
  ```

  Task1、Task2 的源文件都放这里，跟 miniOS 仓库完全无关，不涉及 git 分支/tag。

## 3. Task1：寄存器赋值、交换与打印

**题目**：给寄存器 1 赋值 5、寄存器 2 赋值 8，交换两者的值，再把交换后的结果打印出来。

这里"寄存器 1"对应 LoongArch 的 `$t0`，"寄存器 2"对应 `$t1`（临时寄存器，本课示例
里一直用这两个）。交换需要借助第三个寄存器 `$t2` 先存一份，否则会覆盖丢失。

打印用的是 Linux 系统调用（不是 miniOS 的 `printk`）：`write(fd, buf, len)` 系统
调用号是 64，`exit(code)` 是 93，参数从 `$a0` 开始依次放，系统调用号放在 `$a7`，
执行 `syscall 0` 触发。这几个寄存器约定是 Linux ABI 规定的，本课不展开原理，照抄
即可——重点仍然是前面的赋值、交换这几条指令。

新建 `task1.S`：

```asm
    .section .text
    .globl _start

_start:
    /* 寄存器 1 = $t0，赋值 5；寄存器 2 = $t1，赋值 8 */
    addi.d  $t0, $zero, 5
    addi.d  $t1, $zero, 8

    /* 交换：借助临时寄存器 $t2，否则会覆盖丢失其中一个值 */
    move    $t2, $t0
    move    $t0, $t1
    move    $t1, $t2

    /* 把交换后的值填进消息里对应的问号位置（个位数 +'0' 就是对应字符） */
    la.local $a3, msg
    addi.d  $t3, $t0, '0'
    st.b    $t3, $a3, 9
    addi.d  $t3, $t1, '0'
    st.b    $t3, $a3, 15

    /* write(1, msg, 17)：fd=1(标准输出)，buf=msg，len=17 */
    addi.d  $a0, $zero, 1
    move    $a1, $a3
    addi.d  $a2, $zero, 17
    addi.d  $a7, $zero, 64
    syscall 0

    /* exit(0) */
    addi.d  $a0, $zero, 0
    addi.d  $a7, $zero, 93
    syscall 0

    .section .data
msg:
    .ascii "swap: t0=?, t1=?\n"
```

编译并运行（`-nostdlib -static`：不链接任何库，纯裸程序，跟 `qemu-loongarch64`
配合不需要目标机上有动态链接器）：

```bash
loongarch64-linux-gnu-gcc -nostdlib -static -o task1 task1.S
qemu-loongarch64 ./task1
```

**截图 1**：终端输出应为：

```text
swap: t0=8, t1=5
```

（已实测跑通，交换前 t0=5/t1=8，交换后 t0=8/t1=5，与预期一致。）

### 3.1 改造：三寄存器轮换（不给代码，自己改）

在 `task1.S` 基础上（建议另存一份 `task1_rotate.S`，别覆盖掉截图 1 用过的版本），
把"两个寄存器交换"升级成"三个寄存器轮换"：

**题目**：`$t0=5`，`$t1=8`，`$t2=3`；轮换后要求 `$t0` 拿到原来 `$t1` 的值、`$t1`
拿到原来 `$t2` 的值、`$t2` 拿到原来 `$t0` 的值（每个寄存器往前挪一位，最后一个
绕回第一个）。

- 提示：跟两两交换一样，只需要 **1 个临时寄存器**就够——想清楚先保存哪个值、
  再按什么顺序赋值，顺序错了会导致某个值被提前覆盖、永久丢失。
- 打印格式和消息缓冲区的写法照抄 `task1.S` 的思路自己扩展（原来 2 个问号变
  3 个，注意字符串长度和 `write` 的 `len` 参数也要跟着改）。

编译并运行：

```bash
loongarch64-linux-gnu-gcc -nostdlib -static -o task1_rotate task1_rotate.S
qemu-loongarch64 ./task1_rotate
```

**截图 2**：终端输出应为：

```text
rotate: t0=8, t1=3, t2=5
```

（已实测跑通。）

## 4. Task2：最简单的计数循环

**题目**：写一个从 1 数到 5 的循环，每数一次就打印当前这个数字，最后换行。

结构完全是本课的 while 模板（条件 / 体 / 步进 / 回跳），只是把"体"换成了
"打印当前计数"：

新建 `task2.S`：

```asm
    .section .text
    .globl _start

_start:
    /* $t0 = 循环计数 i，从 1 数到 5 */
    addi.d  $t0, $zero, 1
    addi.d  $t1, $zero, 6       /* 终止条件：i==6 就停（即打印完 5 后结束） */

1:
    beq     $t0, $t1, 2f        /* 条件：i==6 结束 */

    /* 体：把 i 转成字符（个位数 +'0'），写进缓冲区，打印这一个字符 */
    addi.d  $t2, $t0, '0'
    la.local $a1, buf
    st.b    $t2, $a1, 0
    addi.d  $a0, $zero, 1
    addi.d  $a2, $zero, 1
    addi.d  $a7, $zero, 64
    syscall 0

    addi.d  $t0, $t0, 1         /* 步进：i++ */
    b       1b                  /* 回跳 */

2:
    /* 循环结束后打印一个换行，收尾 */
    la.local $a1, nl
    addi.d  $a0, $zero, 1
    addi.d  $a2, $zero, 1
    addi.d  $a7, $zero, 64
    syscall 0

    addi.d  $a0, $zero, 0
    addi.d  $a7, $zero, 93
    syscall 0

    .section .data
buf:
    .byte 0
nl:
    .ascii "\n"
```

编译并运行：

```bash
loongarch64-linux-gnu-gcc -nostdlib -static -o task2 task2.S
qemu-loongarch64 ./task2
```

**截图 3**：终端输出应为：

```text
12345
```

（已实测跑通。）

提交时附一句话：**把终止条件 `addi.d $t1, $zero, 6` 改成 `addi.d $t1, $zero, 4`
会打印出什么？为什么？**（不用真的去改代码验证，口算说明即可，检验对循环边界的
理解。）

### 4.1 改造：反向打印（不给代码，自己改）

在 `task2.S` 基础上（建议另存一份 `task2_reverse.S`），把"从 1 数到 5"改成
"从 5 数到 1"。

**题目**：循环方向反过来，输出应该是 `54321`（不是 `12345` 倒过来贴，是循环本身
真的倒着数）。

- 提示：循环的"条件""体""步进"三个角色都要重新想一遍——初值从哪开始、终止
  条件是什么、每次是 `+1` 还是 `-1`。不是简单改一个数字就行。

编译并运行：

```bash
loongarch64-linux-gnu-gcc -nostdlib -static -o task2_reverse task2_reverse.S
qemu-loongarch64 ./task2_reverse
```

**截图 4**：终端输出应为：

```text
54321
```

（已实测跑通。）

## 5. Task3：回到 miniOS 仓库——数组查找（本课核心产出）

Task3 延续第 3–4 学时"独立按功能写一段汇编代码"的能力目标，要在 miniOS 仓库里
增加代码，需要先克隆仓库、检出本次课 tag（步骤同前几次课，见
`docs/student_env_runbook.md` §6，或本文件 §0 的克隆说明——这里从略，按标准流程
`git fetch --tags && git switch -c my-05-lab 05-branch-loop` 即可）。

分两部分：**5.1 完整走一遍 miniOS 代码链路**（老师带着过，`bl_find_first` 代码
直接给完整的，重点是看懂"改哪、怎么接、怎么跑"这条链路）+ **5.2 独立实现**（题
目之外什么代码都不给，自己从零写）。

### 5.1 完整走一遍 miniOS 代码链路：以 bl_find_first 为例

**这一步的目的不是"现场编出一个新函数"，而是把"改一个功能要动仓库里哪几个地方、
改完怎么编译、怎么运行、怎么在串口看到结果"这条完整链路走踏实**——因为 5.2 要
独立完成同样的链路，这里必须先把链路本身吃透。

**题目**（帮助理解链路用，代码直接给）：写一个函数，在一个 `long` 数组里找目标
值第一次出现的下标；找到就返回下标，没找到返回 -1。

miniOS 里"加一个函数"永远是同一条链路，缺一步都跑不起来：

```text
① 声明接口（.h）→ ② 写实现（.S）→ ③ 接入调用点（.c）→ ④ 编译（make）→ ⑤ 运行核对（qemu）
```

跟着走一遍，把下面的代码**亲手敲进仓库**（不是复制粘贴课件截图，是自己在编辑器
里打字，这样才会对"改哪、怎么接"有真实的肌肉记忆），三处都要改：

**① 声明接口 —— `include/branch_loop.h`**：仿照 `bl_count_nonzero` 那一行声明，紧接着加一行

   ```c
   /* 第 4 学时链路演示（提前退出）：数组中查找 target 第一次出现的下标，没找到返回 -1 */
   long bl_find_first(const long *base, long len, long target);
   ```

**② 写实现 —— `lib/branch_loop.S`**：紧跟在 `bl_count_nonzero` 后面新增一个函数：

   ```asm
   /* ---- 第 4 学时链路演示：数组查找（提前退出） ----
    * $a0 = base（long 数组首地址），$a1 = len，$a2 = target。
    * 找到返回下标，没找到返回 -1，结果从 $a0 返回。
    */
       .globl bl_find_first
   bl_find_first:
       move    $t0, $a0           /* t0 = 遍历指针，从 base 开始 */
       addi.d  $t1, $zero, 0      /* t1 = i = 0 */

   1:
       beq     $t1, $a1, 3f       /* 条件：i==len，扫完了还没找到 -> 3 */
       ld.d    $t2, $t0, 0        /* t2 = base[i] */
       beq     $t2, $a2, 2f       /* 找到 -> 提前退出到 2（不回 1b） */
       addi.d  $t0, $t0, 8        /* 指针前进到 base[i+1]（long 占 8 字节） */
       addi.d  $t1, $t1, 1        /* 步进：i++ */
       b       1b                 /* 回跳 */

   2:
       move    $a0, $t1           /* 找到：返回下标 */
       jr      $ra

   3:
       addi.d  $a0, $zero, -1     /* 没找到：返回 -1 */
       jr      $ra
   ```

**③ 接入调用点 —— `kernel/main.c`**：找到 `bl_count_nonzero` 那段调用（"第 5 次课"
   验收段里），紧接着加一段调用——这一步就是"函数写好了没人调用，什么都不会发生"
   的具体体现，`include/branch_loop.h` 的声明能不能被 `kernel/main.c` 看到、
   `lib/branch_loop.S` 的符号能不能被链接器找到，都在这一步暴露：

   ```c
   {
       static const long arr[6] = {3, 7, 3, 9, 3, 2};
       r = bl_find_first(arr, 6, 3);
       printk("loop  find_first {3,7,3,9,3,2} target=3 = ");
       print_i64_dec(r);
       printk("\n");
   }
   ```

**④⑤ 编译 + 运行核对**：

   ```bash
   make clean
   make
   make run
   ```

   应新增一行 `loop  find_first {3,7,3,9,3,2} target=3 = 0`（3 第一次出现在下标 0）。
   走到这里，"改一个功能要动仓库里哪几个地方"这条链路就完整看过一遍了——5.2 要
   独立走同样的五步，只是这次连代码本身也要自己写。

### 5.2 独立实现：bl_find_last（不提前退出）

**这是本课真正的独立产出：下面不给任何汇编代码，`lib/branch_loop.S` 里一行都
没有预先写好，从五问到最终代码全部自己完成。**

**题目**：在同一个数组里找目标值**最后一次**出现的下标；这次**不能提前退出**，
必须扫完整个数组，把每次匹配都记下来，最后返回最后一次匹配的下标；没找到仍然
返回 -1。

**函数约定**（对照 5.1 的 `bl_find_first`，只是语义改了，寄存器角色你自己分配）：

- 输入：`$a0` = 数组首地址（`long` 数组），`$a1` = 长度，`$a2` = 目标值
- 输出：最后一次命中的下标，或 -1（没找到），从 `$a0` 返回
- 约束：**不能在找到时提前 `jr $ra` 返回**，必须扫完整个数组

自己走一遍 5.1 那条链路，三处都要自己写：

1. **`include/branch_loop.h`**：加一行声明（函数名、参数、返回值按上面的约定自己写）。
2. **`lib/branch_loop.S`**：紧跟在 `bl_find_first` 后面新增 `bl_find_last` 的完整实现——
   自己走一遍五问：输入在哪、输出写到哪、需要几个临时寄存器分别存什么、循环不
   变量是什么、终止条件是什么，再自己画流程图、写伪代码，最后翻译成汇编。
3. **`kernel/main.c`**：找到 `bl_find_first` 那段调用，紧接着加一段类似的调用，
   数组用同一个 `{3, 7, 3, 9, 3, 2}`，目标值用 3，打印格式仿照 5.1 那一行
   （比如 `"loop  find_last  {3,7,3,9,3,2} target=3 = "`）。

保存后 `make clean && make && make run`。

**截图 5**：串口新增的两行（`find_first` 那行来自 5.1，`find_last` 那行是你自己
写的）：

```text
loop  find_first {3,7,3,9,3,2} target=3 = 0
loop  find_last  {3,7,3,9,3,2} target=3 = 4
```

两个函数结果不同（0 vs 4），正好证明"提前退出"和"扫完整个数组"确实是两种不同
的行为——如果你的 `bl_find_last` 也打印出 0，说明很可能在找到时提前退出了，没
有真正扫完整个数组，回去检查循环体是不是漏了继续往下扫的逻辑。

提交时附一句话：**如果 `bl_find_last` 也在找到时提前 `jr $ra` 返回，会变成什么
函数？（提示：跟 `bl_find_first` 比较一下。）**

## 6. 验收标准

- 截图 1（Task1 原始 swap）、截图 3（Task2 原始 1-5）均为真实 `qemu-loongarch64`
  输出，内容分别是 `swap: t0=8, t1=5` 和 `12345`
- 截图 2（Task1 改造：三寄存器轮换）、截图 4（Task2 改造：反向打印）均为真实
  `qemu-loongarch64` 输出，内容分别是 `rotate: t0=8, t1=3, t2=5` 和 `54321`，且
  是在原代码基础上独立改出来的，不是抄同学的
- 截图 5 为真实 `make run` 输出，两行分别是 `find_first ... = 0` 和
  `find_last ... = 4`
- 能讲清 Task1 里 `$t2`（含改造版的临时寄存器）为什么必须存在（不能只用寄存器
  互相赋值完成交换/轮换）
- 能答对 Task2 末尾关于终止条件的问题
- `bl_find_last` 是独立写出，不是照抄 `bl_find_first` 整段再随便改；能说清"提前
  退出"和"扫完整个数组"这两种循环结束方式的区别

## 7. 实验报告要求（从简，当堂交）

- 截图 1、截图 2、截图 3、截图 4、截图 5
- Task2 末尾问题的口算答案
- Task3 末尾问题的答案

## 8. AI 共学边界

允许用 AI 检查语法错误；所有代码须学生能讲解每一行在做什么，包括系统调用那几行
分别对应什么参数；Task1/Task2 的改造部分和 Task3 §5.2 一样，不允许直接让 AI 生成
整段代码后原样提交。

## 9. 提交清单

- [ ] 截图 1（Task1 原始 swap 真实输出）
- [ ] 截图 2（Task1 改造：三寄存器轮换真实输出）
- [ ] 截图 3（Task2 原始 1-5 真实输出）
- [ ] 截图 4（Task2 改造：反向打印真实输出）
- [ ] 截图 5（Task3 真实输出，`find_first`/`find_last` 两行）
- [ ] Task2 末尾问题的口算答案
- [ ] Task3 末尾问题的答案

## 10. 常见故障速查

| 现象 | 处理 |
|---|---|
| `sudo apt install -y qemu-user` 报错/找不到包 | 先 `sudo apt update` 再重试；仍不行按 `docs/student_env_runbook.md` §5 的两条补救路线之一处理工具链 |
| `qemu-loongarch64: Could not open '/lib64/ld-linux-loongarch-lp64d.so.1'` | 编译时漏了 `-static`，补上 `-nostdlib -static` 重新编译 |
| 三寄存器轮换后某个值不对/丢了 | 多半是赋值顺序错了——先想清楚哪个值会被第一条 `move` 覆盖掉，需要先用临时寄存器存下来 |
| 反向打印死循环或不停 | 检查终止条件是不是还在用 `+1`/原来的判等值，倒着数要用 `-1` 步进，且终止值要改成 0（不是 6） |
| PowerShell 报 `ObjectNotFound: make`（Task3） | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称；确认第 1 周已安装 Ubuntu |
| 找不到 Makefile（Task3） | 检查是否已在 Ubuntu 中 `cd` 到 miniOS 根目录 |
| 退不出 QEMU（Task3，全系统模拟才需要） | Ctrl+a 然后 x（Task1/Task2 的 `qemu-loongarch64` 跑完直接退出，不需要这一步） |
| Task3 `make run` 里 `find_last` 结果不对 | 多半是漏了继续扫描——检查匹配到之后有没有误加 `jr $ra`（提前退出会导致 `bl_find_last` 退化成 `bl_find_first`），以及有没有漏掉指针/下标的步进 |
