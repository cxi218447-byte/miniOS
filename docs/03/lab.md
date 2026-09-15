# 第 3 次课实验指导书：寄存器、数据表示与基础指令

> 技术编号：`03`　|　建议检查点：`03-regs-alu`  
> 称“第 3 次课”，不称“第 3 周”。配合讲义：`docs/03/lecture_notes.md`。  
> **本课课堂 = 教材第 2 章 + §3.1 系统讲完**；**实验以跑通验收为主，尽量简单。**  
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

在 Ubuntu 中编译并运行，得到本课分类验收串，确认工程与课堂例题数字一致。

**预期串口输出：**

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

> 注：最后一行代码里实际打印的是 `week03-regs-alu check done`（历史命名遗留的
> 前缀 `week`），不是 `03-regs-alu check done`——验收时以真实串口输出为准，
> 不要因为字符串对不上就以为跑错了。

> 注：以上是 **Task1 跑通**这一步、改代码之前的原始输出。完成 §4 Task5
> 后，你自己会往这份验收串里再加一行 `logic min: min(3,5) = 3`——那是你
> 自己新增的，不是本节漏写。

## 2. 环境准备（每次实验）

| 提示符 | 能否 `make` |
|---|---|
| `PS D:\...>` | **不能**（先进入 Ubuntu） |
| `user@xxx:~$` | **能** |

```powershell
wsl -d Ubuntu
```

```bash
cd "/mnt/<盘符>/.../miniOS"   # D:\foo → /mnt/d/foo
ls Makefile
```

退出 QEMU：Ctrl+a 然后 x。

可选建分支（tag 已发布时）：

**⚠️ 这一步每周都要重新做一次，不是学期初做过就行**：教师每周都会发布新的实
验 checkpoint（新 tag），有时还会同步更新公共代码。哪怕上周已经 `fetch` 过，
这周开始实验前也要**重新**执行 `git fetch --tags`，否则要么找不到这周的 tag，
要么本地代码是过期的。

```bash
git fetch --tags
git switch -c my-03-lab 03-regs-alu
```

## 3. 读源码：文件结构 → 怎么看 → 参数怎么传 → 怎么算

跑通只是第一步；本节带你把 `03-regs-alu` 这一版代码从头到尾读一遍，
搞清楚"程序从哪开始、C 函数怎么把数交给汇编函数、汇编函数怎么把数算出来"。
下面全部内容可以直接在 Ubuntu 里对照真实文件操作，不是纸上谈兵。

### 3.1 本次课 tag 的文件结构一览

先看这一版代码里到底有哪些文件（`03-regs-alu` 只包含前 3 次课需要的内容，
不会提前混入后面课次的代码）：

```bash
git ls-tree -r --name-only 03-regs-alu
```

结果按角色整理如下（**精读**＝本课必须打开看；**扫一眼**＝知道在哪、干什么即可）：

| 文件 | 角色 | 本课要求 |
|---|---|---|
| `boot/start.S` | 汇编入口：`_start` 设栈→`clear_bss`→跳 `kernel_main`→halt | **精读**（§3.2 第一层） |
| `kernel/main.c` | C 入口 `kernel_main`：依次调用各 `alu_*` 并打印验收串 | **精读**（§3.2 第二层） |
| `include/regs_alu.h` | 本课新增：8 个 `alu_*` 函数的 **C 声明**（`main.c` 靠它才能调用汇编函数） | **精读**（§3.3 关键） |
| `lib/regs_alu.S` | 本课新增：8 个 `alu_*` 函数的**汇编实现**（本课重点） | **精读**（§3.2 第三层） |
| `kernel/printk.c` / `include/printk.h` | 串口打印实现，`printk()` 从哪来 | 扫一眼 |
| `kernel/linker.ld` | 链接脚本：决定 `_start` 放在镜像最前面、`.bss` 起止符号从哪来 | 扫一眼（第 10 次课精讲） |
| `lib/string.S` / `include/string.h` | 第 2 次课已有的 `memset`/`memcpy`/`strlen` | 扫一眼，`main.c` 里会用到 |
| `include/types.h` / `include/uart.h` | 基础类型、UART 寄存器定义 | 扫一眼 |
| `Makefile` | 决定编译哪些文件、按什么顺序链接、生成的 ELF 叫什么名字 | 扫一眼（§3.3 会用到里面的路径） |
| `README.md` / `tests/README.md` / `user/README.md` / `.editorconfig` / `.gitignore` | 说明/占位/工程配置，与本课指令无关 | 不用看 |

**一句话记住依赖关系：** `main.c` **只认识** `regs_alu.h` 里声明的函数名字和参数类型，
**不关心** `regs_alu.S` 里是怎么用汇编指令实现的——这正是"C 调用汇编"的分工方式。

### 3.2 三层阅读法：入口层 → 调用层 → 实现层

不要从头到尾按文件顺序读，按"程序真正跑起来的顺序"读，配合讲义 §6.0 的
"读代码五步法"（改谁/用谁/算式/结果/下一步走向）：

**第一层（入口层）—— `boot/start.S`：谁最先跑**

```asm
_start:
    la.global   $sp, boot_stack_top   /* 先有栈，C 函数才能跑 */
    bl          clear_bss             /* 清零 .bss */
    bl          kernel_main           /* 跳进 C 世界，一去不回头 */
halt:
    idle        0
    b           halt
```

CPU 上电后第一条指令就是这里的 `_start`；没有 `main()` 这个说法，"C 语言的入口"
其实是被汇编 `bl kernel_main` **调用**出来的。

**第二层（调用层）—— `kernel/main.c`：谁调用谁、传了什么**

`kernel_main` 里能看到这样的调用（顺序对应验收串顺序）：

```c
r = alu_expr(3, 5, 2);   // 算术 add/sub
r = alu_mul(6, 7);       // 算术 mul
r = alu_low8(0x1234);    // 逻辑 andi
r = alu_slli1(5);        // 移位 slli.d
r = alu_slt(3, 5);       // 条件赋值 slt
r = alu_extb(0x7f);      // 位操作 ext.w.b
r = alu_sum2(7, 1);      // 临时寄存器 + 两次 add
```

**第三层（实现层）—— `lib/regs_alu.S` + `include/regs_alu.h`：具体怎么算**

`regs_alu.h` 只写"长什么样"（函数名、参数、返回值类型），`regs_alu.S` 才是
"具体用哪条指令"。两个文件要对照着看：

```c
/* include/regs_alu.h */
long alu_expr(long a, long b, long c);   /* r = (a + b) - c */
```

```asm
# lib/regs_alu.S
alu_expr:
    add.d   $t0, $a0, $a1      /* t0 = a + b */
    sub.d   $a0, $t0, $a2      /* a0 = t0 - c，直接写回 a0 当返回值 */
    jr      $ra
```

（下面 §3.4 会逐条走读这 3 条指令。）

### 3.3 从入口到计算：参数是怎么"传"过去的？（LP64D 调用约定）

这是本节最关键的问题：`main.c` 里写的是 `alu_expr(3, 5, 2)`，一个**普通 C 函数调用**；
`regs_alu.S` 里的 `alu_expr` 却是一段**只认寄存器**的汇编代码，中间完全没有"变量名"
这种东西。两者能对接上，靠的是编译器和 CPU 共同遵守的一套**调用约定（ABI）**：

> LoongArch64 `lp64d` ABI（本课 `Makefile` 里 `-mabi=lp64d` 就是这个）规定：
> **前 8 个整数/指针参数依次放进 `$a0`~`$a7`**（即 `r4`~`r11`），
> **返回值放在 `$a0`**。函数调用前调用方负责把参数"填"进这些寄存器，
> 被调函数直接从这些寄存器里"取"参数，全程不经过内存、不经过变量名。

对照 `alu_expr(3, 5, 2)`（3 个参数 ≤ 8 个，全部走寄存器），用真实反汇编验证
（下面这段是**实际编译本课 tag 后 `objdump` 出来的原始结果**，不是推测）：

```text
9000000000200168:  li.w  $a2, 2        # 第 3 个参数 c=2 → a2
900000000020016c:  li.w  $a1, 5        # 第 2 个参数 b=5 → a1
9000000000200170:  li.w  $a0, 3        # 第 1 个参数 a=3 → a0
9000000000200174:  bl    alu_expr      # 调用；返回地址自动存进 $ra
9000000000200178:  move  $s0, $a0      # 返回值在 a0，先存到 s0 备用
```

**读法：** 编译器把 C 代码里的"实参 3、5、2"翻译成三条把立即数**装进** `$a0/$a1/$a2`
的指令（先装哪个不重要，装完再 `bl` 才重要），然后才 `bl alu_expr` 真正跳过去；
`alu_expr` 内部只管从 `$a0/$a1/$a2` 里取数，根本不知道、也不需要知道调用方是
"C 函数"还是别的汇编代码——**这就是参数从入口传递到计算函数的完整路径**。

**进阶（选做）：自己动手反汇编验证**

```bash
make clean && make
loongarch64-linux-gnu-objdump -d build/minios.elf | grep -A 40 "<kernel_main>:" | less
```

在输出里找 `bl` 后面跟着函数名的那些行（如 `bl ... <alu_mul>`），往上数
1~3 行就是给该函数传参数的 `li.w`/`move` 指令——自己找一找 `alu_mul(6, 7)`
是怎么把 `6`、`7` 分别装进哪个寄存器的，验证与上面 `alu_expr` 是同一套规则。

### 3.4 参数到了之后怎么算：`alu_expr` 逐指令走读

参数到位后，`alu_expr` 内部只有 3 条指令（同样是本课 tag 编译出的真实反汇编）：

```text
alu_expr:
    add.d   $t0, $a0, $a1   # t0 = a + b
    sub.d   $a0, $t0, $a2   # a0 = t0 - c   （结果直接写回 a0，就是返回值）
    ret                     # 等价于 jr $ra，回到调用点
```

代入 `a=3, b=5, c=2` 逐步走读（练习方式与讲义 §6.0 一致）：

| 步 | 指令 | 计算 | $a0 | $a1 | $a2 | $t0 |
|---|---|---|---|---|---|---|
| 0 | 入口（刚从 §3.3 传参完） | — | 3 | 5 | 2 | ? |
| 1 | `add.d $t0, $a0, $a1` | 3+5=8 | 3 | 5 | 2 | **8** |
| 2 | `sub.d $a0, $t0, $a2` | 8-2=6 | **6** | 5 | 2 | 8 |
| 3 | `ret` | 返回，$a0=6 就是返回值 | 6 | 5 | 2 | 8 |

### 3.5 从计算结果到串口输出：闭环收尾

`alu_expr` 算完 `$a0=6` 后 `ret` 回到 `kernel_main`：

```text
move  $s0, $a0        # 返回值 6 先存进 s0（因为 s0 是"调用后仍保留"的寄存器）
...                    # 打印 "arith add/sub: (3+5)-2 = "
move  $a0, $s0        # 把 6 当作参数传给 print_i64_dec
bl    print_i64_dec   # print_i64_dec 把整数 6 转成字符 '6'，逐字符 printk 出去
```

到这里就是完整的一条链路：**入口 `_start` → `kernel_main` 调用 → 参数装入
`$a0/$a1/$a2` → `alu_expr` 用 `add.d/sub.d` 算出 `$a0=6` → 返回值转成字符串
→ `printk` 写到串口 → 你在 `make run` 里看到的那一行数字**。其余
`alu_mul`/`alu_low8`/`alu_slli1`/`alu_slt`/`alu_extb`/`alu_sum2` 都是同一套
路径，只是参数个数、用的计算指令不同，可按 §3.3 进阶方法自己反汇编验证。

## 4. 实验任务（从简）

### Task1 跑通（必做，核心）

```bash
make clean
make
make run
```

**完成标准：** 串口出现 §1 全文（尤其 `week03-regs-alu check done` 与各 `arith/logic/shift/...` 数字行）。  
**报告：** 粘贴真实输出（可截断中间重复，但关键数字行必须在）。

### Task2 参数传递 + 跟算一行（必做，约 20 分钟）

**先读 §3（尤其 §3.3、§3.4）**，再做本任务——不是另起炉灶，是把 §3 用
`alu_expr` 示范的方法，自己在 **`alu_mul`** 上重做一遍。

**2.1 参数传递（对照 §3.3 的方法）**

在 Ubuntu 中反汇编，找到 `kernel_main` 里调用 `alu_mul(6, 7)` 前的几条指令：

```bash
make clean && make
loongarch64-linux-gnu-objdump -d build/minios.elf | grep -B 2 "<alu_mul>$"
```

（这条命令找的是 `bl ... <alu_mul>` 这一行，`-B 2` 把它前面 2 行——也就是
装参数的 `li.w` 指令——一起带出来。）

在报告中填：`6` 被装进了哪个寄存器？`7` 呢？调用指令是哪一条（`bl ...`）？
这一步对应的是"C 函数调用" `alu_mul(6, 7)` 里的哪两个实参？

**2.2 跟算一行（对照 §3.4 的表格方法）**

打开 `lib/regs_alu.S` 里的 `alu_mul`，仿照 §3.4 的表格，给 **`alu_mul(6, 7)`**
写出逐指令快照（自己定列，至少要有 `$a0`、`$a1` 两列）：

| 步 | 指令 | 计算 | $a0 | $a1 |
|---|---|---|---|---|
| 0 | 入口（参数已按 2.1 传入） | | | |
| 1 | | | | |
| 2 | `ret` | 返回 | | |

**2.3 对照表（不用重新推导，抄一遍加深印象）**

| 串口行关键词 | 对应函数 / 位置 | 代表指令 |
|---|---|---|
| arith add/sub | `alu_expr` | `add.d` `sub.d` |
| arith mul | `alu_mul` | `mul.d` |
| logic andi | `alu_low8` | `andi` |
| shift slli | `alu_slli1` | `slli.d` |
| cond slt | `alu_slt` | `slt` |
| bit ext.w.b | `alu_extb` | `ext.w.b` |
| mem st.b | `clear_bss`（`start.S`） | `st.b` |

### Task3 课堂知识点打勾（必做，不改代码）

听课 / 看讲义后，在报告中用 **一句话** 回答（无需推导长证明）：

（回答请对照教材/课堂讲的**笔记原例**，不必另造数字。）

1. 教材：`imm < 12 bit` 时装立即数用哪条路径？（`addi.* rd, r0, imm`）  
2. 教材：`12 bit < imm < 32 bit` 时，`lu12i.w` 与 `ori` 各做什么？  
3. 笔记例：`r2=0x7f0` 时 `andi r5, r2, 3` 的结果是多少？可用来检查什么对齐？  
4. 笔记例：`r4=0xFFFA` 时 `ext.w.h r5, r4` 后 `r5` 是什么（笔记结果）？这是符号扩展还是零扩展？  
5. 笔记：`move rd, rj` 通常等价于哪条真指令？  
6. **寄存器宽度：** LA32 与 LA64 上整数通用寄存器（GR）各是多少位？本课 miniOS 按哪一种理解？  
7. 笔记中 LA64 的 `add.w r5,r2,r1`：源取全 64 位还是低 32 位？写回前做什么？  
8. 溢出笔记例：`r1=0x7fffffff; add.w r5,r1,r1` 时，LA32 与 LA64 的 `r5` 各是什么？有符号读是多少？  
9. `slt` 与 `sltu` 的差别一句话？  
10. 笔记 `maskeqz rd, rj, rk` 的语义是什么？（`rk==0` 时 rd 变成什么？）

### Task4（选做，极简）

把 `alu_expr` 的测试从 `(3,5,2)` 改成自己算过的三个小数，改 `main.c` 打印字符串后 `make run`，贴输出。

### Task5 实现 `alu_min`（必做，约 15~20 分钟，对照课件例 3.8 + 动画）

**背景：** 课件第 45~46 页例 3.8 `a = (b<c) ? b : c`（取最小值）用
`slt / maskeqz / masknez / or` 四条指令实现，**不走分支跳转**；
配套交互动画：`docs/03/animations/cond_select_min_demo.html`
（可逐步/自动播放，任意输入 b、c 看每一步寄存器变化）。
本任务请你把这个例子自己写成代码接入工程，而不是只看动画。

**5.1 声明 + 实现**

- 在 `include/regs_alu.h` 里仿照其他 `alu_*` 加一行声明：

  ```c
  /* 条件选择 min：r = (b<c) ? b : c，仅用 slt/maskeqz/masknez/or */
  long alu_min(long b, long c);
  ```

- 在 `lib/regs_alu.S` 里实现 `alu_min`，**约束：只能用 `slt`、`maskeqz`、
  `masknez`、`or` 这四条指令，不允许出现任何分支跳转指令**
  （`beq`/`bne`/`blt`/`bge`/…）——目的是逼你走课件那条"分支消除"的路，
  而不是先心算出答案再拿分支翻译。参数约定：`$a0=b`、`$a1=c`，
  返回值（min）放回 `$a0`；中间可以用 `$t0` 存条件位。

**5.2 接入验收串**

在 `kernel/main.c` 第 3 次课验收段里加一行调用（跟在 `alu_extb` 或
`alu_sum2` 后面即可），仿照现有格式：

```c
r = alu_min(3, 5);
printk("logic min: min(3,5) = ");
print_i64_dec(r);
printk("\n");
```

`make clean && make && make run`，确认串口新增一行 `logic min: min(3,5) = 3`。

**5.3 手推快照表（仿 §3.4）**

给 `alu_min(3, 5)` 写出逐指令寄存器快照（列名自定，至少要有 r4(b)/r5(c)/条件位寄存器/返回值寄存器）：

| 步 | 指令 | 计算/含义 | b 寄存器 | c 寄存器 | 条件位寄存器 | 返回值寄存器 |
|---|---|---|---|---|---|---|
| 0 | 入口 | b=3,c=5 | | | | |
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | `or` | 返回 | | | | |

可以先自己推，再打开 `cond_select_min_demo.html` 输入 b=3,c=5 逐步核对每一步是否一致。

**5.4 换一组数再推一遍**

把 `main.c` 里的调用改成 `alu_min(5, 3)`（对应课件"自推一表"的任务），
重新 `make run`，在报告里回答：这一次是**哪一步**把**哪个寄存器**清成了 0？
和 `(3,5)` 那次相比，为什么最终结果同样正确？

### Task6 自选一条指令接入验收串（选做）

从教材/讲义里挑一条本课代码里**还没出现过**的指令（例如 `sltu`、`slti`、
`andn`、`orn`、`nor`……），仿照 Task5 的做法写一个新的 `alu_xxx` 函数
（声明 + 实现 + 接入 `main.c` 验收串），并在报告里用几句话说明：

1. 为什么选这条指令？它计算的是什么？
2. 它和已有代码里哪条指令最容易混淆？区别是什么？

## 5. 验收标准

- [ ] 能在 Ubuntu 中 `make run` 得到验收串  
- [ ] 输出数字与 §1 一致（或 Task4 自洽）  
- [ ] Task2.1 能说出 `alu_mul(6, 7)` 的两个参数各装进了哪个寄存器  
- [ ] Task2.2 逐指令快照表填完  
- [ ] Task3 十问各有一句话  
- [ ] Task5：`alu_min` 只用 `slt/maskeqz/masknez/or` 实现（无分支跳转），串口新增 `logic min: min(3,5) = 3`  
- [ ] Task5.3 快照表填完，Task5.4 能说清 `(5,3)` 那次哪一步清零了哪个寄存器  
- [ ] 知道 `make` 不能在 PowerShell 里直接敲  

## 6. 报告要求（从简）

1. 环境一句（WSL / 工具有无）  
2. **真实** `make run` 输出（含 Task5 新增的 `logic min` 行）  
3. Task2.1 反汇编截图/文本 + 一句话回答；Task2.2 快照表；Task3 十句  
4. Task5：新增代码（`regs_alu.h`/`regs_alu.S`/`main.c` 改动）+ 5.3 快照表 + 5.4 一句话回答；Task6（若做）代码 + 两句说明  
5. 遇到的问题（若无则写「无」）  

## 7. AI 共学边界

允许：解释报错、对照讲义术语。  
不允许：编造串口输出。  
**指令细节以课堂与讲义为准**（立即数、有/无符号、位宽），实验不要求自己造完整指令表。

## 8. 常见故障

| 现象 | 处理 |
|---|---|
| PowerShell 找不到 `make` | 先 `wsl -d Ubuntu` |
| 找不到 Makefile | `cd` 到 miniOS 根目录 |
| 退不出 QEMU | Ctrl+a 然后 x |
