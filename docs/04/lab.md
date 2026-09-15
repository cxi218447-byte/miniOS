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

本实验配合 4 学时（每学时 45 分钟）教学，分成两个 90 分钟实验单元，均采用
"**预测—运行—解释**"闭环。完成后应能：

1. 计算基址+偏移形成的有效地址。
2. 解释访存宽度、加载扩展和存储截断。
3. 跑通"内存→浮点寄存器/运算→结果观察"的示例。
4. 区分普通读改写、原子操作和访存顺序。

> 注：本课具体的串口验收数值（如 `0x80` 加载后的结果、浮点位模式等）不在
> 这里提前给出——它们正是 §3.2 预测表要你自己先猜的内容，答案会在 §4 各
> Task 完成后逐步核对，不提前剧透。

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

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实验
checkpoint（新 tag），有时还会同步更新公共代码（如 `kernel/`、`lib/`）。哪怕你
上周已经 `fetch` 过，这周开始实验前也必须**重新**执行下面的 `git fetch --tags`
——不然要么找不到这周的 tag，要么本地代码是过期的。

教师发布 tag 后执行：

```bash
git fetch --tags
git switch -c my-04-lab 04-load-store
```

如果不确定这周的 tag 是否已经拉到本地，可以先看一眼完整 tag 列表：

```bash
git tag -l
```

看到 `04-load-store` 就说明已经是最新的了；如果没看到，先执行
`git fetch --tags` 再重新检查。

`my-04-lab` 是学生本地分支，远程没有同名分支是正常现象。若教师尚未发布 tag，以课堂指定 checkpoint 为准，不要把占位文字当成命令参数。

**如果执行 `git switch -c my-04-lab 04-load-store` 时报错：**

```text
error: Your local changes to the following files would be overwritten by checkout:
        kernel/main.c
Please commit your changes or stash them before you switch branches.
Aborting
```

说明上一次实验（如 `my-03-lab`）里 `kernel/main.c` 还留有没保存的改动，Git 不敢直接切分支把它们弄丢。**先看清楚到底改了什么，再决定怎么处理**：

```bash
git status
git diff -- kernel/main.c
```

根据看到的内容三选一：

- **改动没用**（比如多余的空格/空行、临时调试代码）——丢弃后再切分支：

  ```bash
  git restore kernel/main.c
  git switch -c my-04-lab 04-load-store
  ```

- **改动是上次实验没做完、想保留**——先提交到当前分支，再切：

  ```bash
  git add -A
  git commit -m "wip: 03 实验未完成的记录"
  git switch -c my-04-lab 04-load-store
  ```

  **如果这里的 `git commit` 报错：**

  ```text
  Author identity unknown

  *** Please tell me who you are.

  Run

    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"

  fatal: empty ident name (for <cc@abc.localdomain>) not allowed
  ```

  说明这台 WSL 从没配置过 Git 身份（换新电脑、重装 WSL 后第一次 `git commit` 都会遇到），跟前面的分支切换报错是两个独立问题。照提示做**一次性全局配置**即可，以后不会再问：

  ```bash
  git config --global user.name "你的姓名或学号"
  git config --global user.email "你的邮箱"
  ```

  配置完再重新执行一次 `git commit -m "wip: 03 实验未完成的记录"` 就会成功。

  **这里的 `user.name`/`user.email` 只是本地提交记录用的署名，填什么都行**（姓名拼音、学号、随便一个邮箱格式的字符串都可以），**不需要真的注册 GitHub 或 Gitee 账号，也不会被拿去校验**——本课程克隆的是公开仓库，匿名就能 `clone`/`fetch`，实验报告也是走 §6 报告要求里的提交渠道，不需要 `git push` 到远程。

  如果你确实想注册一个真实账号（比如想留着以后自己写代码、面试展示），可以：

  - GitHub：<https://github.com/signup>（国内访问可能较慢，可配合科学上网，或直接用下面的 Gitee）
  - Gitee：<https://gitee.com/signup>（国内访问稳定，注册即用）

  注册好之后把 `user.email` 改成注册用的邮箱即可，跟账号本身没有强绑定关系，改不改都不影响本课程实验。

- **不确定要不要，先"存起来"以后再看**：

  ```bash
  git stash
  git switch -c my-04-lab 04-load-store
  # 以后想找回：git stash list 然后 git stash pop
  ```

**不要**为了绕过报错就 `git checkout -- .` 强行覆盖或删库重新 `clone`——这样会连带丢掉可能有用的改动，也丢掉了本该学会的排错过程。

### 2.3 重点文件

```text
lib/mem_fp.S
include/mem_fp.h
kernel/main.c
```

## 3. 实验安排与预测

### 3.1 教学单元与学时安排

| 教学单元 | 对应学时 | 实验内容 | 建议完成点 |
|---|---|---|---|
| 单元一：普通访存闭环 | 第 1–2 学时 | Task1–2 | 第 2 学时结束 |
| 单元二：并发推演与浮点闭环 | 第 3–4 学时 | Task3 + Task4 | 第 4 学时结束 |

Task3 是第 3 学时的纸面推演（填表），不要求改内核；Task4 是第 4 学时的动手改代码 + 截图实验。教师可在第 2 学时结束时先验收普通访存部分，在第 4 学时结束时完成总验收。

### 3.2 实验前预测表（每个单元运行前填写）

| 问题 | 预测 |
|---|---|
| `$sp=0x80001000`，`ld.d $t1,$sp,16` 的有效地址 |  |
| 内存字节为 `0x80`，`ld.b` 后的 64 位值 |  |
| 同一字节用 `ld.bu` 后的 64 位值 |  |
| `$t2=0x1122334455667788`，`st.h` 写入哪两字节 |  |
| `1.5f+2.5f` 的数值与 binary32 十六进制位模式 |  |

不得先抄运行结果。预测错误不扣除过程分，但必须在实验后解释错误原因。

## 4. 实验任务

### 单元一：普通访存闭环（第 1–2 学时）

#### Task1 有效地址与状态变化

先打开 `lib/mem_fp.S`，找到本任务两道题分别对应的真实代码：

- `mem_copy_d`（第 25–29 行）：`ld.d`/`st.d` 的例子；
- `mem_byte_add3`（第 32–38 行）：`ld.bu`/`st.b` 字节数组相加的例子。

分析下面这条指令：它是刻意改过寄存器名和偏移量的**抽象练习题**，仓库代码
里搜不到，不用去找——分析思路跟 `mem_copy_d` 里的 `ld.d $t0, $a0, 0` 完全
一样，只是换了寄存器名和偏移量：

```asm
ld.d    $t1, $sp, 16
```

在报告里依次回答下面四点：

**问题 1.1：这条指令的动作是什么？搬运的数据宽度是几位？**

**问题 1.2：三个操作数（`$t1`、`$sp`、`16`）分别扮演什么角色？**

**问题 1.3：有效地址是多少？写出具体的计算式。**

**问题 1.4：执行后，哪个寄存器的值变了？哪些寄存器、哪些内存区域没变？**

**问题 2：动手写一段汇编代码，实现字节数组相加（要接进工程里跑起来）**

题目：内存里有一个字节数组，把 `base[0]` 和 `base[1]` 这两个字节的值相加，
结果存到 `base[2]`。数组首地址（也就是 `base`）已经放在 `$t0` 寄存器里。
请用 `ld.bu`（无符号字节加载）取出两个字节、`add.d` 相加、`st.b`（字节存
储）写回，写出完整的 3~5 行代码。

这次不是纸上写写就交——要改到工程里，`make run` 真的跑一遍，具体改哪三
个文件、改在哪个位置，如下：

1. **`include/mem_fp.h`**：仿照 `mem_byte_add3` 那一行声明，紧接着加一行

   ```c
   /* 学生自己实现：base[2] = base[0] + base[1]（练习用，参数约定同 mem_byte_add3） */
   void mem_byte_add3_self(unsigned char *base);
   ```

2. **`lib/mem_fp.S`**：紧跟在 `mem_byte_add3`（第 32–38 行）后面新增一个函
   数骨架，`move` 那一行和 `jr` 那一行已经给你写好（题目设定基址在
   `$t0`，但 ABI 规定参数从 `$a0` 进，所以先 `move` 一下），中间 3 行你自
   己写：

   ```asm
   /* ---- 学生练习：自己实现 base[2] = base[0] + base[1] ---- */
       .globl mem_byte_add3_self
   mem_byte_add3_self:
       move    $t0, $a0        /* 题目设定基址在 $t0，这里先从 $a0 搬过去 */
       /* TODO: 你的代码写在这里（3 行左右）：
          用 ld.bu 取 base[0]、base[1]；add.d 相加；st.b 写回 base[2] */
       jr      $ra
   ```

3. **`kernel/main.c`**：找到现有的 `mem_byte_add3(byte_area);` 那一段（"访
   存"验收段里），紧接着加一段调用，故意用一组加起来超过 255 的数，用来
   验证 store 截断：

   ```c
   {
       unsigned char my_area[3] = {200, 100, 0};
       mem_byte_add3_self(my_area);
       printk("mem byte_add3 (self): 200+100 = ");
       print_i64_dec(my_area[2]);
       printk("\n");
   }
   ```

4. 保存后执行：

   ```bash
   make clean
   make
   make run
   ```

   串口应新增一行 `mem byte_add3 (self): 200+100 = 44`（`300` 超过 8 位后
   截断成 `44`，即 `300 mod 256`）。如果你的代码没写对，这一行要么编译报
   错，要么数字不是 `44`——先检查寄存器有没有搞混，再回来核对第 2 步的
   骨架。

在报告里依次回答：

1. 贴出你在 `lib/mem_fp.S` 里补全的那 3 行代码，以及 `make run` 输出这一
   行的截图。
2. 输出的 `44` 是怎么来的？说明 `st.b` 为什么只截取加法结果的低 8 位，
   而不是报错或者自动扩宽 `base` 数组。
3. 对照 `mem_byte_add3`（第 32–38 行——逻辑和你写的完全一样，只是基址寄
   存器从 `$a0` 换成了先 `move` 到 `$t0` 再用）：你的代码在"取数 → 相加 →
   写回"这三步的顺序和寄存器使用上，跟它是否一致？如果不一致，差在哪里？

#### Task2 有符号与无符号加载

阅读 `lib/mem_fp.S` 中的 `mem_load_byte_signed`（第 41–44 行，`ld.b`）和
`mem_load_byte_unsigned`（第 47–50 行，`ld.bu`）。先完成预测表，再运行：

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

**补充：补码位模式怎么求原始值（以 `0x80` 这一字节为例）**

同一个字节 `0x80`，当成"补码表示的有符号数"和当成"无符号数"，读出来的原始值不一样。求有符号原始值有两种等价方法，任选一种：

- **方法一：按位取反再加一（求负数的模）**

  ```text
  0x80  = 1000 0000    （先写出 8 位二进制）
  最高位（符号位）= 1  → 这是一个负数
  按位取反：       0111 1111   （0x7F）
  再 +1：          1000 0000   （二进制加法，结果是 128）
  所以原始值 = -128
  ```

- **方法二：公式 `signed = U - 2^n`（`U` 是按无符号读出的值，`n` 是位宽）**

  ```text
  U = 0x80 按无符号读 = 128
  n = 8（1 字节 = 8 位），2^8 = 256
  最高位是 1（负数）→ signed = U - 2^n = 128 - 256 = -128
  最高位是 0（正数）→ signed = U 本身，不用减
  ```

两种方法结果一致：**`0x80` 当有符号数原始值是 `-128`**。而当无符号数时不用管符号位，直接把 8 位二进制读成数值：`1000 0000 = 128`。

这也是 `ld.b`（有符号加载）和 `ld.bu`（无符号加载）唯一的区别：两条指令从内存里取出的字节位模式完全相同（`0x80`），区别只在于**扩展到 64 位寄存器时怎么补高位**——`ld.b` 按符号位把高位全部补 `1`（符号扩展，结果是 `0xFFFF_FFFF_FFFF_FF80` = 十进制 `-128`），`ld.bu` 把高位全部补 `0`（零扩展，结果是 `0x0000_0000_0000_0080` = 十进制 `128`）。

解释两条指令为何读取相同字节却得到不同的 64 位寄存器值。说明为什么 store 家族没有 `st.bu`。

### 单元二 A：并发访存纸面推演（第 3 学时）

#### Task3 LL/SC 纸面推演（填表）

**背景：** 内存里有个共享变量 `a`，初始值是 `3`。两个"执行流"（可以理解成
两个核，具体怎么跑的不深究）都想做"读出来 +1 再写回去"这件事，跑的都是
下面这段 LL/SC 代码（`$a0` 已经指向 `a` 所在地址）：

```asm
retry:
    ll.w      $t0, $a0, 0     # 链接加载：读 a，同时 CPU 记下"链接"
    addi.w    $t1, $t0, 1     # t1 = a + 1
    sc.w      $t1, $a0, 0     # 条件存储：链接没被打断才真正写回，t1 变成成功标志
    beqz      $t1, retry      # t1==0（失败）就回 retry 重来
```

**表 1：只有一个执行流在跑，没人插队**

| 步骤 | 指令 | 执行前 `a` | `$t0` | `$t1` |
|---|---|---|---|---|
| 1 | `ll.w $t0, $a0, 0` | 3 |  | — |
| 2 | `addi.w $t1, $t0, 1` |  |  |  |
| 3 | `sc.w $t1, $a0, 0` |  |  |  |
| 4 | `beqz $t1, retry` | — | — |  |

填完后回答：第 3 步执行完 `$t1` 是几？这表示 `sc.w` 成功还是失败？`a` 最终变成多少？

**表 2：执行流 B 在执行流 A 做完 `ll.w`/`addi.w`、还没做 `sc.w` 时插了一脚**

初始 `a=3`。执行流 A 先做了 `ll.w`（此时 A 的 `$t0=3`）和 `addi.w`（A 的
`$t1=4`）；就在 A 要执行 `sc.w` 之前，执行流 B 完整跑了一遍同样的代码，
把 `a` 改成了别的值。

| 步骤 | 执行者 | 动作 | 这一步之后 `a` 的值 | A 的 `$t0` | A 的 `$t1` |
|---|---|---|---|---|---|
| 1 | A | `ll.w $t0, $a0, 0` | 3 | 3 | — |
| 2 | A | `addi.w $t1, $t0, 1` | 3 | 3 | 4 |
| 3 | B | 完整跑一遍 `ll.w`/`addi.w`/`sc.w`（B 自己的寄存器不用填） |  | 3（不变） | 4（不变） |
| 4 | A | `sc.w $t1, $a0, 0` |  |  |  |
| 5 | A | `beqz $t1, retry` |  |  |  |
| 6 | A | 若失败，重新执行第 1–3 条指令一遍 |  |  |  |

填完后回答：第 3 步之后 `a` 变成几？第 4 步 A 的 `sc.w` 会成功还是失败，为什么（提示：A 的"链接"在第 3 步发生了什么）？如果失败，A 重新跑一遍第 1–3 条指令后，最终 `a` 会稳定在多少？

**概念问答：完成两张表后，再用一两句话（每条不超过 100 字）回答下面三点**

- LL/SC 这一整套机制主要解决的是什么问题？（对照表 2 里"链接被打断"那一步说明）
- `DBAR` 解决的是另一类什么问题？和 LL/SC 解决的问题有什么不同？
- `IBAR` 与 `DBAR` 的作用对象有什么区别？

本任务只做概念推演。当前实验不要求多核运行、异常处理或实现锁。

### 单元二 B：浮点闭环（第 4 学时）

#### Task4 浮点运算：动手改代码 + 截图验证

本任务涉及的函数都在 `lib/mem_fp.S` 里：`fp_add_s`（第 55–58 行）、
`fp_add_d`（第 61–64 行）、`fp_bits_s`（第 67–70 行）；声明在
`include/mem_fp.h`；调用点在 `kernel/main.c` 第 4 次课验收段里。

**第一步：改测试数值，重新验证**

打开 `kernel/main.c`，找到调用 `fp_add_s`/`fp_add_d` 的那两行（当前测的是
`1.5f + 2.5f` / `1.5 + 2.5`）。换成你自己选的一组小数（两个加数都要带小数
部分，不要用整数；可以结合自己学号构造），重新编译运行：

```bash
make clean && make && make run
```

**截图 1**：串口输出里 `float fadd.s`/`float fadd.d` 这两行。在报告里手算
你选的这组小数相加后的结果，对照 `fadd.s` 那行的 binary32 位模式是否算得
上（拆 S/E/F 还原一遍），验证截图和手算一致。

**第二步：仿照现有函数，新增一个 `fp_sub_s`（单精度减法）**

1. 在 `include/mem_fp.h` 里仿照 `fp_add_s` 的声明，加一行 `fp_sub_s` 的函数原型。
2. 在 `lib/mem_fp.S` 里仿照 `fp_add_s`（第 55–58 行）实现 `fp_sub_s`：把
   `fadd.s` 换成 `fsub.s`，参数/返回值寄存器约定不变（`$fa0`/`$fa1` 传参，
   结果回 `$fa0`）。
3. 在 `kernel/main.c` 浮点验收段里新增一行调用，仿照 `fadd.s` 那几行的写法
   （变量 `fs`、`bits` 都已经声明好，直接复用）：

   ```c
   fs = fp_sub_s(5.5f, 2.5f);
   bits = fp_bits_s(fs);
   printk("float fsub.s: 5.5-2.5 -> bits 0x");
   print_u64_hex((unsigned long)(bits & 0xffffffffUL));
   printk("\n");
   ```

4. `make clean && make && make run`。

**截图 2**：串口新增的 `float fsub.s: 5.5-2.5 -> bits ...` 这一行。在报告
里手算 `5.5-2.5=3.0` 的 binary32 位模式，核对是否与截图一致。

**第三步：位模式搬运 vs 数值转换（阅读，不改代码）**

下面四条指令分别摘自 `lib/mem_fp.S` 的 `fp_int_to_double`（第 73–77 行）和
`fp_double_to_int`（第 80–83 行）——把两个函数各自的两条核心指令拼在了一
起（省略了 `jr $ra`），阅读：

```asm
movgr2fr.w    $fa0, $a0
ffint.d.w     $fa0, $fa0

ftintrz.w.d   $fa0, $fa0
movfr2gr.s    $a0, $fa0
```

逐条标记"搬位模式"或"转换数值"，说明 `ftintrz` 中 `rz` 的舍入方向，以及为什么只执行 `movgr2fr.w` 不能得到数值意义上的 `7.0`。

**提交要求：** 报告中必须贴出截图 1、截图 2，以及第三步的文字解释；截图缺失按未完成计。将实验前预测与真实输出逐项对照，报告中至少选择一个预测错误或最容易错的项目，解释根因。

## 5. 验收标准

- [ ] 能按"助记符—操作数—状态变化"解释代表性访存和浮点指令。
- [ ] 有效地址、访问宽度和加载扩展均判断正确。
- [ ] 能解释 store 的低位截断。
- [ ] 能区分浮点位模式搬运、数值转换和浮点运算。
- [ ] 能解释普通读改写、LL/SC 和 `DBAR` 的职责差异。
- [ ] `make run` 产生与 checkpoint 一致的真实输出。

## 6. 报告要求（从简）

报告至少包含：

1. OS/WSL、交叉编译器和 QEMU 版本摘要；
2. 实验前预测表及运行后订正；
3. 必做任务的代码注释、地址演算和真实输出；
4. 至少一幅内存/FPR 状态变化图；
5. 遇到的问题、定位过程和解决办法；
6. Task3 的纸面推演表格与概念问答；
7. 提交清单：实验报告（Markdown 或 PDF）+ 关键串口输出摘录（含 Task1 问题 2 的 `mem byte_add3 (self)` 截图、Task4 的截图 1 和截图 2）+ 按教师要求提交的代码补丁或课堂笔记。

## 7. AI 共学边界

可以让 AI 辅助画内存格子、检查 IEEE 754 拆位或模拟指令交错；最终报告必须保留学生自己的预测、逐步状态变化和真实运行输出，不得用生成内容替代运行。

## 8. 常见故障

| 现象 | 处理 |
|---|---|
| PowerShell 报找不到 `make` | 先执行 `wsl -d Ubuntu`，进入仓库后再构建 |
| `wsl -d Ubuntu` 失败 | 用 `wsl -l -v` 核对发行版名称 |
| Ubuntu 中找不到工具 | 按 `docs/student_env_runbook.md` 安装课程工具链 |
| 找不到 Makefile | 检查当前目录是否为 miniOS 仓库根目录 |
| 执行浮点指令后异常 | 检查 `CSR.EUEN.FPE` 是否在浮点代码前使能 |
| 退出不了 QEMU | `Ctrl+a`，再按 `x` |
| `git switch -c` 报错 "local changes ... would be overwritten" | 见 2.2 节：先 `git status` / `git diff` 看改了什么，再从 `git restore`（丢弃）/ `git commit`（保留）/ `git stash`（暂存）三选一，禁止直接删库重 clone |
| `git commit` 报错 "Author identity unknown" | 见 2.2 节：WSL 从没配置过 Git 身份，一次性执行 `git config --global user.name "..."` 和 `git config --global user.email "..."` 后重新提交 |
