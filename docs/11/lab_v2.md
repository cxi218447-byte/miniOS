# 第 11 次课实验指导书：库函数独立实现 + 定时器中断 + 内核时间

> 技术编号：`11`　|　建议检查点：`11-irq-kernel-recap`　|　4 学时连排（纯实验课）  
> 称"第 11 次课"，不称"第 11 周"。  
> **环境总手册：** `docs/student_env_runbook.md`  

## 本课主线

这次实验只有一条主线：**让时钟中断真正为内核所用**。

```text
strncmp（库函数，你亲手写）
   └─ 用自测表验证 + 用 GDB 单步观察
定时器中断（配置 → 使能 → 清源）
   └─ ISR（中断服务程序，Interrupt Service Routine，也就是 `irq_dispatch` 这个中断处理函数）瘦身：中断里只记账，打印交给主循环
        └─ ksleep(n)：用 tick 实现"睡 n 个时钟节拍"
             └─ 把它们串成一段你自己写的小 demo
```

每一步的产出都是下一步的零件，不再是互不相关的功能演示。

## 0. 克隆仓库到本地（首次 / 换新位置 / GitHub 打不开用 Gitee）

**只需做一次**——已经克隆过、能正常 `cd` 进仓库的同学跳过，直接看「实验环境与准备」。
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

完成后应能：

1. 看懂 `memset`/`memcpy`/`strlen`/`memmove`/`strcmp`/`zero_and_copy` 六个已有函数的实现（§4.0），并在此基础上独立实现一个新的库函数（`strncmp`），把寄存器、访存、循环、调用约定组合起来，用 GDB 单步验证它。
2. 说清定时器三个 CSR（`TCFG`/`TVAL`/`TICLR`）与两层使能（`ECFG`/`CRMD.IE`）的分工。
3. 跑通周期性定时器中断，能调参观察节奏变化，并能亲手复现"忘记清源"的故障。
4. 解释异常与中断为何共享同一个 `EENTRY` 入口、中断入口为何要保存更多寄存器，以及同步异常与中断返回时为什么处理 `era` 的方式不同。
5. 理解"中断里只做最少的事"：把 ISR 瘦身成只记账、把打印挪到主循环。
6. 用 tick 实现 `ksleep()`，并自己写一段小 demo 把库函数、异常、中断串起来。

## 2. 实验环境与准备（必须先做对）

### 2.1 必须在 WSL/Ubuntu 中构建

```powershell
wsl -d Ubuntu
```

提示符变为 `user@host:~$` 后，`cd` 进你克隆下来的 `miniOS` 仓库目录，然后确认工具链：

```bash
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
git switch -c my-11-lab 11-irq-kernel-recap
```

`my-11-lab` 是学生本地分支，远程没有同名分支是正常现象。若教师尚未发布 tag，以课堂指定 checkpoint 为准。

### 2.3 重点文件

```text
include/string.h       （单元一：strncmp 声明加在这里）
lib/string.S            （单元一：memset/memcpy/strlen/memmove/strcmp/zero_and_copy 已有，strncmp 待你实现）
boot/start.S          （exception_entry，第9次课已有，本课升级为144字节栈帧）
kernel/exception.c    （exception_handler，本课新增 Ecode==0 分支）
kernel/irq.c          （timer_init/irq_dispatch/timer_stop；本课在此新增 timer_read_remaining 与 ksleep）
include/irq.h         （单元三：ksleep 声明加在这里）
kernel/main.c         （strncmp 自测表、定时器验收段、你自己写的小 demo 都在这里）
```

## 3. 实验安排

| 教学单元 | 学时 | 实验内容 | 建议完成点 |
|---|---|---|---|
| 单元一：库函数独立实现 | 第 1 学时 | §4.0 六个已有函数 + §4.1 实现 `strncmp` + GDB 单步 | 第 1 学时结束 |
| 单元二：定时器中断上机 | 第 2 学时 + 第 3 学时前半 | §5 Task 1–3 | 第 3 学时中段 |
| 单元三：中断驱动的内核时间 | 第 3 学时后半 + 第 4 学时 | §6 Task 1–3 | 第 4 学时结束 |

## 4. 单元一：库函数独立实现（第 1 学时）

`memset`/`memcpy`/`strlen`/`memmove`/`strcmp`/`zero_and_copy` 六个函数的代码
已经在 `lib/string.S` 里（本 checkpoint 起点就带着，不用重写），实现思路见
下面 §4.0。看懂之后，本单元**唯一的编程任务**是独立实现第七个——
`strncmp`，`strcmp` 的"最多比较 n 个字符"版本。不给任何汇编代码，自己写。

### 4.0 六个已有函数怎么写的

打开 `lib/string.S` 对照着看。

**`memset`/`memcpy`/`strlen`：同一种循环骨架，都是叶子函数**（内部没有
`bl`，不用搭栈帧）。以 `memset(dst, byte, n)` 为例：

```asm
memset:
    move        $t0, $a0          # 保存原始 dst，作为返回值
    beqz        $a2, 2f           # n==0：什么都不用做

1:
    st.b        $a1, $a0, 0       # *dst = byte
    addi.d      $a0, $a0, 1       # dst++
    addi.d      $a2, $a2, -1      # n--
    bnez        $a2, 1b           # n!=0 继续循环

2:
    move        $a0, $t0          # 换回原始 dst 作为返回值
    jr          $ra
```

`$a0` 一开始是地址，循环里被当成"当前写到哪"的游标用，所以必须先用
`$t0` 存一份原始值，循环结束后再换回来当返回值。`memcpy` 是同一骨架多
一个源指针 `$a1`：每次循环用 `ld.bu`（无符号加载）读一个字节再 `st.b`
写出去——必须是 `ld.bu` 不能是 `ld.b`，否则最高位是 1 的字节（如
`0x80`）会被符号扩展成一堆 1，拷贝出错误数据。`strlen` 不数循环次数，
靠读到 `'\0'` 判断结束，返回值是指针相减得到的长度。

**`memmove`：先判断方向，再选搬运路径。** `memcpy` 假设两块内存不重叠；
如果 `dst`/`src` 有重叠，从头往后搬可能在读到某个字节之前就把它覆盖掉。
拿一个具体例子看清楚问题：`buf` 初始内容是 `ABCDEFGH`（下标 0–7），调用
`memmove(buf+2, buf, 6)`——把下标 `[0,6)` 的内容搬到 `[2,8)`，`dst`（从
下标 2 开始）比 `src`（从下标 0 开始）靠后，且两段区间在下标 2–5 重叠。

```text
初始：下标  0   1   2   3   4   5   6   7
     内容  A   B   C   D   E   F   G   H
           └───src[0..5]───┘
                   └───dst[0..5]───┘
```

**如果像 `memcpy` 一样从前往后搬**（`dst[i] = src[i]`，`i` 从 0 递增）：

```text
第1步 dst[0]=src[0]：buf[2] ← buf[0]('A')
      下标  0   1   2   3   4   5   6   7
      内容  A   B   A   D   E   F   G   H
                  ↑
          原来的 'C' 被冲掉了——但它马上要在第3步被当 src[2] 读取！

第2步 dst[1]=src[1]：buf[3] ← buf[1]('B')
      下标  0   1   2   3   4   5   6   7
      内容  A   B   A   B   E   F   G   H

第3步 dst[2]=src[2]：buf[4] ← buf[2]，
      但 buf[2] 此刻已经是第1步写入的 'A'，不再是原始的 'C'！
      下标  0   1   2   3   4   5   6   7
      内容  A   B   A   B   A   F   G   H
                          ↑
                  本该拷贝原始 'C'，实际拷贝到了被污染的 'A'
```

从第 3 步起，每一步读到的都是被污染过的数据，错误会一路传下去，最终结果
和期望的 `ABABCDEF` 完全对不上——**写指针追上并超过了读指针，把还没读
过的数据提前覆盖了**。

**正确做法：判断出 `dst >= src` 后，从最后一个字节开始往前搬**
（`dst[5]→dst[4]→…→dst[0]`）：

```text
第1步 dst[5]=src[5]：buf[7] ← buf[5]('F')
      下标  0   1   2   3   4   5   6   7
      内容  A   B   C   D   E   F   G   F

第2步 dst[4]=src[4]：buf[6] ← buf[4]('E')
      下标  0   1   2   3   4   5   6   7
      内容  A   B   C   D   E   F   E   F
      ……一路往前搬，每次写的位置都比当前读指针靠后，
      还没轮到读的字节就不会被提前覆盖。
```

搬完六步，结果是 `ABABCDEF`，符合预期。`memmove` 用 `sltu`（无符号小于
比较，地址要按无符号理解）判断 `dst < src` 还是 `dst >= src`：前者正向
搬（和 `memcpy` 一样，天然安全，因为读指针一直领先于写指针）；后者就要
反过来从最后一个字节往前搬，核心原则都是同一句话——**永远读在写前面**。

**`strcmp`：逐字节比较，返回差值而不是 -1/0/1**：

```asm
strcmp:
1:
    ld.bu       $t0, $a0, 0       # t0 = *a
    ld.bu       $t1, $a1, 0       # t1 = *b
    bne         $t0, $t1, 2f      # 字节不同：跳出去算差值
    beqz        $t0, 3f           # 两边都读到 '\0'：字符串相等
    addi.d      $a0, $a0, 1
    addi.d      $a1, $a1, 1
    b           1b

2:
    sub.d       $a0, $t0, $t1     # 返回两个不同字节的差值
    jr          $ra

3:
    move        $a0, $zero        # 返回 0：相等
    jr          $ra
```

停止条件有两个：遇到不同字节，或两边同时读到 `'\0'`。

**`zero_and_copy`：本文件唯一的非叶子函数。** `zero_and_copy(dst, src,
dst_size)` 依次调用 `memset(dst,0,dst_size)` → `strlen(src)` →
`memcpy(dst,src,len)`，先清零再拷贝，这样只要 `dst_size` 够大，结果天然
是 `'\0'` 结尾的合法字符串（只调用 `memcpy` 做不到这点）。内部有三次
`bl`，所以 `$ra` 必须先存后取；`dst`/`src` 要跨这三次调用活着，而
`$a0`-`$a2`、`$t0`-`$t8` 都会被每次被调用者自由覆盖，所以借用
callee-saved 的 `$s0`/`$s1` 来保活。

看完这六个，下面 4.1 的 `strncmp` 就是在 `strcmp` 的骨架上加一个"最多
比 n 个字节"的限制——怎么改循环条件自己想，不要直接调用 `strcmp` 再
截断（等比较完整个字符串才发现超过 n，已经晚了）。

### 4.1 任务：实现 `strncmp`

**函数原型**：`int strncmp(const char *a, const char *b, size_t n)`

| 寄存器 | 含义 |
|---|---|
| `$a0` | 字符串 `a` 的地址 |
| `$a1` | 字符串 `b` 的地址 |
| `$a2` | `n`：最多比较的字节数 |
| 返回（`$a0`） | 0：前 n 个字节相等（或双方在 n 个字节内已同时遇到 `'\0'`）；非 0：第一个不同字节的差值 |

**行为约定**（对照 `strcmp`，只是多了一个"最多比几个"的限制）：

- `n == 0`：不读取 `a`/`b` 的任何字节，直接返回 0。
- 比较到第 n 个字节为止：前 n 个字节全部相同，即使后面还有不同字符，也返回 0（不能比过 n）。
- 在第 n 个字节以内遇到不同字节，返回那一对字节的差值（同 `strcmp`：**无符号**加载后相减，教学简化，不做饱和处理）。
- 在第 n 个字节以内两边同时读到 `'\0'`，直接判定相等，返回 0（不需要凑满 n 次）。

**要求**：

1. 在 `include/string.h` 里加一行声明。
2. 在 `lib/string.S` 里独立实现，并加上 `.globl strncmp`——自己写循环处理 `n`，不允许直接调用现成的 `strcmp` 敷衍了事（那样处理不了 `n` 的截断）。
3. `strncmp` 是**叶子函数**（里面没有再调用别的函数），不需要搭栈帧，想清楚为什么。

### 4.2 自测表（老师已提供，直接加进 `kernel/main.c`）

自己随便打印三行容易漏掉边界。下面这张表由老师给出，**你只需要把它抄进 `kernel/main.c`，在 `kernel_main` 里调用一次 `strncmp_selftest()`**，让程序自己判分：

```c
#include "string.h"

/* 期望值只比较符号：-1 表示 a<b，0 表示相等，1 表示 a>b */
static const struct {
    const char   *a;
    const char   *b;
    unsigned long n;
    int           expect;
} strncmp_cases[] = {
    { "abcdef", "abcxyz", 3,  0 },  /* 0: n 之外不同 -> 相等 */
    { "abcdef", "abcxyz", 4, -1 },  /* 1: n 以内不同，'d' < 'x' */
    { "abc",    "abc",    10, 0 },  /* 2: n 以内双方同时遇到 '\0' */
    { "abc",    "abd",    0,  0 },  /* 3: n == 0 */
    { "abc",    "ab",     5,  1 },  /* 4: 一边先结束，'c' > '\0' */
    { "",       "",       3,  0 },  /* 5: 空串 */
    { "\xff",   "\x01",   1,  1 },  /* 6: 必须无符号比较：0xff > 0x01 */
};

static void strncmp_selftest(void)
{
    unsigned long i, pass = 0;
    unsigned long total = sizeof(strncmp_cases) / sizeof(strncmp_cases[0]);

    for (i = 0; i < total; i++) {
        int r = strncmp(strncmp_cases[i].a, strncmp_cases[i].b, strncmp_cases[i].n);
        int s = (r > 0) - (r < 0);
        printk("  strncmp case ");
        printk_udec(i);
        if (s == strncmp_cases[i].expect) {
            pass++;
            printk(": PASS\n");
        } else {
            printk(": FAIL\n");
        }
    }
    printk("strncmp selftest: ");
    printk_udec(pass);
    printk("/");
    printk_udec(total);
    printk(" passed\n");
}
```

注意最后一个用例专门检查你是用 `ld.bu`（无符号）还是 `ld.b`（有符号）加载字节。

### 4.3 GDB 单步观察（必做，约 15 分钟）

后面的课程考核要求用 GDB 记录真实寄存器，本课先热身一次。GDB 要连到一个
正在运行的 QEMU 上，所以要**同时开两个终端**，一个负责跑 QEMU，一个负责跑
GDB，两边都要进入 WSL Ubuntu、`cd` 到仓库根目录（§2.1 的步骤再做一遍）。

**终端 A：冻结 CPU，等 GDB 来连**

```bash
make debug
```

这条命令和平时的 `make run` 不一样：它会让 QEMU 把 CPU **冻结在复位点**，
然后在本机 1234 端口等一个调试器连上来。执行后终端会卡住、没有任何
`Hello miniOS...` 之类的输出——这是正常现象，CPU 还没真的开始跑，先别关
这个窗口，后面全程留着。

**终端 B：启动 GDB，连接终端 A 里冻结的 CPU**

```bash
gdb-multiarch -q build/minios.elf
```

进入 `(gdb)` 提示符后，输入：

```
target remote :1234
```

看到 `Remote debugging using :1234` 就是连上了（可能会跟着一两行
`warning: Architecture rejected target-supplied description`，不影响使用，
忽略即可）。

**下面每条命令都要一行一行敲回车，不要把好几行整段复制粘贴进终端**：部分
终端粘贴多行文本到 GDB 时不会老老实实地把每一行都当一次回车处理，GDB 会把
好几行粘成一条命令去解析，报 `A syntax error in expression` 之类的错——粘
贴翻车不代表命令本身写错了，一行一行敲（或者一行一行地粘贴+回车）就没事。

**不要用"下断点 + `continue`"这条路**：本课程这套工具链版本下，断点配合
`continue` 不稳定，设了断点、`continue` 下去，程序往往会直接跑到底，根本不
会在断点处停下来——你如果照网上的 GDB 教程先试了这条路，卡住或者"程序跑完了
也没停"都是这个原因，不是你操作错了。下面改用更直接、更稳的办法：直接把参
数寄存器和 `$pc`（程序计数器，决定 CPU 下一条执行哪条指令）手动设到
`strncmp` 入口，让 CPU 从那里开始单步——这只用到"读写寄存器"和"单步执行"
两个最基础的 GDB 能力，不依赖断点。

**第一步：挑一组测试数据，填进参数寄存器**

拿 §4.2 已经抄进 `kernel/main.c` 的 `strncmp_cases` 当参数来源，挑下标 1
这组（`"abcdef"` vs `"abcxyz"`，`n=4`——前 3 个字节相同、第 4 个字节才不同，
能看到好几轮循环，比第 0 组更适合观察）。按 `strncmp(a, b, n)` 的调用约定
（`$a0`=a，`$a1`=b，`$a2`=n，§4.1 表格已经列过）手动赋值：

```
set $a0 = (long)strncmp_cases[1].a
set $a1 = (long)strncmp_cases[1].b
set $a2 = (long)strncmp_cases[1].n
```

用下面两条确认 `$a0`/`$a1` 真的指向了这两个字符串（不是看错了别的地址）：

```
print (char*)$a0
print (char*)$a1
```

**第二步：把 `$pc` 直接改到 `strncmp` 入口**

```
set $ra = $pc
set $pc = strncmp
```

先把当前 `$pc`（CPU 刚冻结时的复位地址）存进 `$ra`，是留一条退路：万一后面
单步一直走到了 `strncmp` 末尾的 `jr $ra`，CPU 顶多跳回冻结时的地址，不会
跳到随机内存把 QEMU 搞挂。`set $pc = strncmp` 才是真正"让 CPU 从 `strncmp`
第一条指令开始执行"的那一步。用 `x/i $pc` 确认当前 `$pc` 已经指向
`strncmp` 的第一条指令。

**第三步：单步观察，记录每轮 `$a0`/`$a1`/`$a2`**

```
nexti
info registers a0 a1 a2
```

（`nexti` 可以简写成 `ni`。）反复执行这两条命令，**至少看两轮循环**——也
就是看到 `$a0`、`$a1` 各自往前走了至少两次——把每一轮 `info registers`
打出来的真实数值记下来。`info registers` 里 `$a0`/`$a1` 旁边那一长串十进
制数不用管，只看十六进制地址那一列有没有在变。

**省力写法：一次设置，之后敲回车就能连续单步。** 不想每一轮都重新敲一遍
`info registers`，可以让 GDB 每停一次就自动帮你打印这三个寄存器，设置好以
后只要反复按回车：

```
display/x $a0
display/x $a1
display/x $a2
```

（这三行同样要一行一行敲回车，设置过程只做一次。）设置完，执行一次
`nexti`，之后**对着空提示符直接按回车**（不用再输入 `nexti` 两个字）——
GDB 会自动重复上一条命令，每次停下来都会把 `$a0`/`$a1`/`$a2` 的最新值连
带打印出来，一边按回车一边看着这三行变化即可。

**退出**

```
quit
```

会问 `Quit anyway? (y or n)`，输入 `y`。回到终端 A，按 `Ctrl+a` 再按 `x`
关掉这个 QEMU。

### 4.4 验收与提交

```bash
make clean
make
make run
```

串口里应能看到 7 行 `PASS` 和最后的 `strncmp selftest: 7/7 passed`。

**提交：** 截图（含 7/7 输出）+ 一张 GDB 单步截图（§4.3 必做，电子提交即可，不进纸质报告）。纸质报告（附件2模板）里单元一只需贴 `strncmp` 汇编代码 + 运行截图（含 7/7 输出），篇幅见 §9.1。

## 5. 单元二：定时器中断上机（第 2–3 学时）

### 5.0 背景知识：定时器 CSR、两层开关、共享入口（上机前先读一遍）

下面这段硬件细节由教师串讲演示时对照着讲，这里先把要用到的概念
一次性列全，方便串讲时随时回头查。

**本课用到的中断相关 CSR**

| CSR | 编号 | 读/写 | 作用 |
|---|---|---|---|
| `EENTRY` | `0xc` | 写 | 异常/中断统一入口地址，`exception_init()` 设成 `exception_entry`；只设一次，第9次课已经设过（见下文"为什么第11次课不见 `exception_init()`"） |
| `CRMD` | `0x0` | 读改写 | bit2=IE，中断总开关：CPU 整体允不允许响应任何中断 |
| `ECFG` | `0x4` | 读改写 | bit11=定时器这条中断线的分源开关：这一条线自己允不允许响 |
| `ESTAT` | `0x5` | 读 | 异常/中断发生后，`exception_entry` 用 `csrrd` 读出来传给 `exception_handler`；bit[21:16]=`Ecode`（异常/中断分类），bit[12:0]=`IS`（哪条中断线在响，定时器固定 bit11） |
| `ERA` | `0x6` | 读 | 同上，和 `ESTAT` 一起被读出来；发生陷入时该返回去的地址 |
| `TCFG` | `0x41` | 写 | bit0=En（使能），bit1=Periodic（周期模式：倒数到 0 自动重装初值再倒数），高位=InitVal（倒数初值） |
| `TVAL` | `0x42` | 读 | 当前倒数值（Task 2 会用 `csrrd` 把它读出来，验证"周期模式自动重装"） |
| `TICLR` | `0x44` | 写 1 | bit0 写 1，硬件会把 `ESTAT.IS` 里定时器那个挂起位（bit11，就是上面 `ESTAT` 这行、也是 `irq_dispatch` 检查的那一位）清掉；**不清的话这一位会一直是 1，`ertn` 返回后立刻又被当成"还有中断"重新触发**（Task 3 要亲手复现这个故障，详细推演见 §13.4） |

`EENTRY`/`CRMD`/`ECFG` 三个是"中断基础设施"，不管哪条中断线都要用到；
`TCFG`/`TVAL`/`TICLR` 是定时器专属；`ESTAT`/`ERA` 是每次陷入时硬件自动
给出的"案情报告"，不是程序主动配置的。

```c
void timer_init(unsigned long count)
{
    unsigned long tcfg = (count << 2) | TCFG_EN | TCFG_PERIODIC;
    __asm__ volatile("csrwr %0, 0x41" : "+r"(tcfg) : : "memory");  /* 配置：0x41 = TCFG */
    ecfg_enable_timer_line();   /* 使能：分源开关 */
    crmd_enable_ie();            /* 使能：总开关 */
}
```

`count << 2`：`TCFG` 的 InitVal 字段从 bit2 开始，低两位留给 En/Periodic 两个
标志位。这一行是"配置"；下面两行是"使能"——教师串讲时会在 `kernel/irq.c`
里真的找到这三类代码，分别标出来。

**两层使能，缺一不可**

| 开关 | CSR/位 | 类比 |
|---|---|---|
| 分源开关 | `ECFG`（`0x4`）bit11 | 这一条中断线自己允不允许响 |
| 总开关 | `CRMD`（`0x0`）bit2（IE） | CPU 整体允不允许响应任何中断 |

```c
static inline void ecfg_enable_timer_line(void)
{
    unsigned long mask = 1UL << 11;
    unsigned long val  = 1UL << 11;
    __asm__ volatile("csrxchg %0, %1, 0x4" : "+r"(val) : "r"(mask) : "memory");  /* 0x4 = ECFG */
}
```

**先看 `rd`/`rj` 对应代码里的谁。** 内联汇编里 `%0` 是第一个输出操作数、
`%1` 是第一个输入操作数，`"csrxchg %0, %1, 0x4"` 展开后实际执行的是
`csrxchg val, mask, 0x4`——对照指令格式 `csrxchg rd, rj, csr`，**`rd` =
`val`，`rj` = `mask`**。

`csrxchg rd, rj, csr`：`csr = (csr & ~rj) | (rd & rj)`——只有 `rj` 里是 1 的
那些位才会被 `rd` 对应位覆盖，其余位保持原样，`rd` 同时带回旧值。逐位代入
走一遍：假设执行前 `ECFG` 的 bit0、bit2 已经为别的中断源（比如 UART）开着，
bit11 还是 0：

```text
rj (mask) = ...0000 1000 0000 0000        只有 bit11 是 1
rd (val)  = ...0000 1000 0000 0000        bit11 是 1，其余位是 0

~rj               = ...1111 0111 1111 1111      除 bit11 全是 1
csr & ~rj         = ...0000 0000 0101           bit0/bit2 原样保留，bit11 本来就是0
rd & rj           = ...0000 1000 0000 0000      只留下 rd 里 bit11 这一位

新 csr = (csr & ~rj) | (rd & rj)
       = ...0000 0000 0101  |  ...0000 1000 0000 0000
       = ...0000 1000 0000 0101
```

按位对齐画出来更直观（`bit` 行是位号，箭头指出哪几位被 `rj` 选中）：

```text
bit      13 12 11 10  9  8  7  6  5  4  3  2  1  0
csr_old   0  0  0  0  0  0  0  0  0  0  0  1  0  1
rj_mask   0  0  1  0  0  0  0  0  0  0  0  0  0  0
rd_val    0  0  1  0  0  0  0  0  0  0  0  0  0  0
                ^                          ^     ^
             rj=1：改成 rd 的值(1)    rj=0：原样保留 csr_old
csr_new   0  0  1  0  0  0  0  0  0  0  0  1  0  1
```

bit11 那一列 `rj` 是 1，所以这一位被 `rd` 的值（1）覆盖；bit2、bit0 那两列
`rj` 是 0，所以 `csr_new` 原样抄 `csr_old`，没被 `rd`（这两列都是 0）带偏。

结果：bit11 被置成 1，bit0/bit2 原来是什么还是什么，一个没动——这就是
"只置 1 这一位、其余位保持原样"。`val`/`mask` 填成同一个值不是偶然：`rj`
负责划定"能动的范围"（只有 bit11），`rd` 负责"范围内填什么"（bit11 填
1）；`rd` 在 `rj` 之外的那些位填什么无所谓，反正会被 `~rj` 过滤掉、不会
写进 csr，干脆让两者长一样，省得纠结其余位填 0 还是 1。

**`val` 为什么是 `"+r"` 不是 `"r"`：** `rd`（即 `val`）这个寄存器被一个
寄存器两用——指令执行前装的是"要写的新值"，执行后被硬件覆盖成"csr 修改
前的旧值"带回来。既被读又被写，必须标 `"+r"`（读写操作数），标成 `"r"`
的话编译器会以为这个值用完就扔，可能做出不符合预期的优化。

这里不用整体 `csrwr` 的原因，上面的例子已经说明：`ECFG`/`CRMD` 这类 CSR
塞了好几个互不相关的开关位（`ECFG` 里还有别的中断源，`CRMD` 里还有特权
级、地址翻译模式），`csrwr(ECFG, 1UL<<11)` 这种整体赋值会把 bit0/bit2 这
些本来开着的位一起清零，顺手关掉别的中断线——`csrxchg` 靠 `rj` 这个掩码
保证"只碰声明要碰的那一位，其余位原样放回去"。

**使能 vs 清源：先分清这两件事**

上面讲了"使能"（`ECFG`/`CRMD`），`TICLR` 清源的细节在 §13.4 才会展开，但
这两个概念很容易混成一回事——都是写个寄存器、都是"不做就不正常"，先在
这里把区别立住：

| | 使能（`ECFG`/`CRMD`） | 清源（`TICLR`） |
|---|---|---|
| 回答什么问题 | "这条中断线 / CPU 允不允许响" | "刚才响过的这次信号，我处理完了，别再响" |
| 什么时候做 | 一次性——`timer_init()` 设好就不用再管 | 每次中断触发都要做一次——在 `irq_dispatch` 里 |
| 不做会怎样 | 中断永远不会发生，`tick` 一直不出现 | 中断照常发生，但处理完立刻原地重触发，刷屏停不下来（Task 3） |
| 用的指令 | `csrxchg`（软件拿掩码只改一位，保护寄存器里的其他开关） | `csrwr`（硬件自带"写1精确清对应位"的语义，不需要软件保护） |

一句话区分：**使能是静态的闸门，决定"信号过不过得去"，设一次管一直；
清源是动态的应答，决定"这次已经到达的信号算不算完"，来一次就要应答
一次**。两者都漏不得，但漏了哪个的症状完全不一样（一直没动静 vs 动起来
停不下来），故障排查时先分清是哪一类。

还有一个容易踩的坑：`ECFG`/`ESTAT` 里定时器固定用 **bit11**，但 `TICLR`
是另一个独立的"确认"寄存器，它清源用的 bit0 和前面的 bit11 **没有任何
对应关系**——不要想着"应该也是第11位"去套。

**异常与中断共享同一个入口**

LoongArch 里，同步异常（`break`/`syscall`……）和异步中断（定时器）走同一个
`CSR.EENTRY`，硬件根本不区分，区分靠软件读 `ESTAT.Ecode`（bit[21:16]）：

```c
unsigned long ecode = ecode_from_estat(estat);   /* 第9次课起改成纯汇编实现，见 lib/ecode.S */
if (ecode == 0) {
    irq_dispatch(estat);   /* 中断类 */
    return era;              /* 原样返回，不加 4 */
}
/* 否则是同步异常，第9次课的 era+4 逻辑 */
```

**为什么中断返回 `era` 不加 4，`break` 要加 4**：`break` 这类同步异常，硬件
存进 `ERA` 的是触发异常**那条指令自己**的地址——原样跳回去会在原地再次执
行 `break`，再次触发异常，死循环，所以要人为 `+4`（LoongArch 定长指令，4
字节）跳过它。中断是异步闯入的，硬件存进 `ERA` 的本来就已经是"该继续执行
的下一条指令地址"（比如 `idle 0` 的下一条），不存在"触发指令本身"这个概
念，软件不该去改它，改了反而会跳错地方。

**为什么中断入口要比第 9 次课保存更多寄存器**

第 9 次课的 `exception_entry` 只存 `$ra`，够用是因为 `break` 是**软件主动**
触发的——写这段代码的人知道即将发生什么。中断不同：它可能打断**任何**正
在执行的代码，包括正在用 `$a0`-`$a7`、`$t0`-`$t8` 存活跃数据的代码（这组
寄存器按调用约定是 caller-saved，调用者"主动调用别人"时才会想着先存它
们——中断不是一次主动调用，写业务代码的人完全没有防备）。所以本课把
`exception_entry` 升级成保存 18 个寄存器（`$ra` + `$a0`-`$a7` + `$t0`-`$t8`，
144 字节栈帧），把中断随时可能打断的每一种活跃寄存器都先存好，处理完再
原样恢复。

**为什么第 11 次课的代码里不见 `exception_init()`**：翻 `kernel/main.c` 会
发现第11次课定时器那一段只调了 `timer_init()`，没有再调一次 `exception_init()`——
不是漏写，是真的不需要。`exception_init()` 只做一件事：把 `CSR.EENTRY`
设成 `exception_entry` 的地址，这是"不管发生什么异常/中断，CPU 该跳到哪"
的全局设置，跟具体是 `break`、`syscall`、还是定时器中断无关（上面刚讲过
"共享同一入口"）。第 9 次课已经调用过一次，执行到第 11 次课这段代码时
`EENTRY` 早就指对了，再调一次只是把同一个值重复写一遍，没有新效果，
所以省了。

真正属于"定时器要新做的事"，是 `timer_init()` 里做的另外两件事，跟
`EENTRY` 是两个不同层面的开关：`ecfg_enable_timer_line()`（分源开关）和
`crmd_enable_ie()`（总开关）。这里有个容易忽略的点：`break`/`syscall` 是
**同步**异常，CPU 正在执行这条指令本身就触发了陷入，不受"要不要响应中断"
这个开关管——第 9 次课全程没碰过 `CRMD.IE`，`break` 照样能触发、能
`ertn` 正常恢复；`CRMD.IE` 管的只是**异步**中断（定时器、外部硬件）要不要
被允许打断当前执行流，这正是 `timer_init()` 必须调 `crmd_enable_ie()` 的
原因——不打开这个总开关，定时器信号到了也会被挡在外面，CPU 永远感觉
不到。

一句话总结：**`EENTRY` 只用设一次（第9次课已经设过），`timer_init()` 管的
是"定时器专属配置 + 真正打开异步中断这条路"，是两件不同的事。** 如果没有
第9次课在前面、单独只跑第11次课的定时器实验，确实要在 `timer_init()` 之前
先调一次 `exception_init()`——不设置 `EENTRY`，中断来了也是"无处可去"。

**把上面散落的内容串成一张图**：从 `kernel_main()` 的初始化开始，到定时器
真正触发一次中断、再回到 `kernel_main()`，每一步涉及的函数和 CSR 读/写：

```text
kernel_main()
  │
  ├─ exception_init()                             【第9次课，只做一次】
  │     csrwr 0xc, &exception_entry                → 写 EENTRY：中断/异常统一入口
  │
  ├─ timer_init(count)                             【本课新增】
  │     csrwr 0x41, (count<<2 | En | Periodic)      → 写 TCFG：配置定时器
  │     ecfg_enable_timer_line()
  │         csrxchg 0x4, mask=val=1<<11             → ECFG.LIE bit11=1：分源开关开
  │     crmd_enable_ie()
  │         csrxchg 0x0, mask=val=1<<2              → CRMD.IE  bit2=1：总开关开
  │
  └─ while (irq_ticks() < 5) { idle 0; }            → CPU 停在这里，等中断唤醒
        │
       ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ 以下由硬件自己发生，不是软件调用 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
        ▼
   TCFG 倒数到 0，硬件把 ESTAT.IS bit11 置 1（"挂起"）
        │   （前提：ECFG.LIE bit11 和 CRMD.IE 都已经是 1，上面两个开关都开着）
        ▼
   CPU 跳到 EENTRY 指向的地址
       ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ 回到软件，一层层普通函数调用 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
        ▼
boot/start.S : exception_entry
  │   保存 18 个寄存器（$ra + $a0-$a7 + $t0-$t8）
  │   csrrd $a0, 0x5                                → 读 ESTAT，当第1个参数
  │   csrrd $a1, 0x6                                → 读 ERA，当第2个参数
  │   bl exception_handler
  ▼
kernel/exception.c : exception_handler(estat, era)
  │   ecode = ecode_from_estat(estat)                → 取 ESTAT.Ecode（bit[21:16]）
  │   ecode==0（中断类）？
  │       │ 是
  │       ▼
  │   irq_dispatch(estat)
  │       │
  │       ▼
  │   kernel/irq.c : irq_dispatch(estat)
  │       estat & ESTAT_IS_TIMER（即 ESTAT.IS bit11）？
  │           │ 是
  │           ▼
  │       timer_irq_clear()
  │           csrwr 0x44, v=1                        → 写 TICLR bit0：清掉 ESTAT.IS bit11
  │                                                     （硬件内部直接接线，专为定时器这一位铺的清零通路）
  │                                                     （不清会在 ertn 后立刻重新触发，Task 3）
  │       g_ticks++
  │       printk("tick #N")
  │       ◄── 返回
  │   return era（原样返回，不加 4）
  ▼
exception_entry：把 era 写回 CSR.ERA，恢复 18 个寄存器，ertn
       ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ ertn 跳回软件，继续往下跑 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
        ▼
回到 kernel_main()：刚才 idle 0 的下一条指令
  │
  └─ irq_ticks() 再查一次：够 5 次就跳出循环（调 timer_stop），不够就再 idle 0 等下一次
```

这张图对应教师串讲要讲的完整时间线——串讲时可以直接对着这张图，
一行一行去 `kernel_main()`/`boot/start.S`/`kernel/exception.c`/`kernel/irq.c`
里找到对应的真实代码。

**上机第一步：听串讲 + 跑基线，不是独立任务，不用交学习过程。** 教师对照
上面「5.0 背景知识」和这张流程图，带着大家把 `boot/start.S`→`kernel/irq.c`→
`kernel/exception.c` 过一遍完整的执行时间线。听完之后，自己跑一遍确认环境
和基线都是好的，不要求、也不接受提交任何听课笔记或代码批注：

```bash
make clean
make
make run
```

核对串口输出（`Ctrl+a` 再 `x` 退出 QEMU）：

```text
timer_init: periodic timer interrupt enabled
tick #1
tick #2
tick #3
tick #4
tick #5
collected 5 timer ticks via interrupt, timer_stop() called
week11-irq-kernel-recap check done
```

跑通之后再动手做下面的 Task 1。

### Task 1 调参实验

- 修改 `kernel/main.c` 中的 `TIMER_COUNT`（改成原值的一半、两倍），重新 `make run`，记录 tick 出现的快慢变化（肉眼感受节奏即可，不要求精确计时）。
- 写一句话结论：`TIMER_COUNT` 与 tick 间隔是正相关还是负相关？
- 本任务不需要截图提交，把两组取值与观察到的变化、以及一句话结论写进实验报告即可。

### Task 2 读出 TVAL，验证"周期模式自动重装"（写代码）

在 `kernel/irq.c` 里新增（仿照已有的 `timer_irq_clear()`，把 `csrwr` 换成 `csrrd`、CSR 编号换成 `0x42`，TVAL 只读）：

```c
static inline unsigned long timer_read_remaining(void)
{
    unsigned long v;
    __asm__ volatile("csrrd %0, 0x42" : "=r"(v));
    return v;
}
```

在 `irq_dispatch` 打印 `tick #N` 之后追加一行打印当前 TVAL：

```c
printk("  TVAL now=0x");
printk_hex(timer_read_remaining());
printk("\n");
```

重新 `make run`，核对：每次 tick 时的 TVAL 都接近初始 InitVal（`TIMER_COUNT`），而不是减到 0 不再变化——用代码亲手验证"周期模式会自动重装初值"，而不是只背结论。（这行调试打印在 §6 Task 1 会随 ISR 瘦身一起搬走，不用担心。）

### Task 3 故障复现：忘记清源（必做，约 10 分钟）

- 临时注释掉 `kernel/irq.c` 中 `irq_dispatch` 里的 `timer_irq_clear()` 调用，重新编译运行。
- 记录现象（提示：会不会刷屏？tick 数涨得正常吗？），写出原因：`TICLR` 清的是哪个"源"？不清它，中断返回后会发生什么？
- 改回来，确认恢复正常。

### 单元二阶段验收

- `make run` 输出与上面运行验收的摘录一致，且能看到 Task 2 的 TVAL 行。
- 有至少两组 `TIMER_COUNT` 取值的调参记录（Task 1）。
- 有 Task 3 的真实现象记录与原因解释。
- 能解释中断入口为什么要保存比第 9 次课更多的寄存器（见上面「5.0 背景知识」）。

## 6. 单元三：中断驱动的内核时间（第 3 学时后半 + 第 4 学时）

到这里你已经有了"每隔一段时间自动执行一次的代码"。这一单元学会**正确地使用它**。

### Task 1 ISR 瘦身：中断里只记账，打印留给主循环

**背景知识：上半部 / 下半部。** "中断服务程序尽量短、剩下的事挪到别处做"不是
miniOS 自己的土办法，是真实操作系统的通用设计，有专门名字：硬件一发生中断就
必须立刻处理的部分叫**上半部**（这里是清中断源 `timer_irq_clear()`、给计数
加一），可以晚一点、不那么紧急的部分叫**下半部**（这里是打印）。Linux 内核里
对应的机制叫 softirq/tasklet，miniOS 没有那一整套框架，只用"主循环自己去检查
tick 有没有变化"这种最朴素的方式模拟同样的思想：中断只负责"喊一声"，真正干
活的代码留到主循环里慢慢做。

现在的 `irq_dispatch` 在中断里直接调用了 `printk`。这是个坏习惯：

- 中断随时会打断主循环。如果主循环正好在 `printk` 中间被打断，ISR 里再调一次 `printk`，两次输出会交织甚至破坏共享状态（可重入问题）。
- ISR 越长，被打断的代码被拖得越久。

**任务**：把 `irq_dispatch` 改成只做两件事——tick 计数加一、`timer_irq_clear()` 清源。`tick #N` 以及 §5 Task 2 的 TVAL 打印搬到 `kernel/main.c` 的主循环里：主循环醒来后检查"有没有新 tick"，有才打印。

提示：主循环需要自己记住"上次已经处理到第几个 tick"，用一个局部变量与 `irq_ticks()` 比较。

验收：`make run` 的串口输出与上面运行验收的一致。

### Task 2 实现 `ksleep(ticks)`（写代码）

**背景知识：什么是"睡眠"，为什么不能用空转凑时间。** 你可能在 Linux 命令行用
过 `sleep 5`，或者以后学操作系统课时会碰到 `msleep()`、`schedule_timeout()`
这类函数——它们的共同点是**阻塞等待**（blocking wait）：调用它时 CPU 不是
"干等着耗电"，而是进入低功耗等待，时间到了才被唤醒继续跑。这跟第 1 次课就
见过的"忙等"（busy-wait）是两回事：

```c
for (i = 0; i < 1000000; i++) { }   /* 忙等：CPU 全速空转"凑时间" */
```

忙等有两个毛病：一是白白烧 CPU（这段时间 CPU 100% 占用却什么正事没干），
二是凑出来的时长不准——换一块板子、换个编译优化等级，同样的循环次数耗时都
不一样。`ksleep` 要做到"靠谱的 n 个 tick"，必须依赖硬件定时器这个真实的时间
基准，而不是数循环次数。

实现思路正是把你已经熟悉的 `idle 0`（第 1 次课讲过：CPU 停止执行、进入低
功耗等待，直到下一次中断把它唤醒）和本课新学的 tick 计数接起来：先读一次
当前 tick 数、算出"到第几个 tick 就该醒"，然后反复"`idle 0` 睡一下→醒来看
看 tick 到没到→没到就继续睡"，直到到达目标。CPU 大部分时间都在 `idle 0`
里躺着，只有每次定时器中断来时才会被唤醒检查一次，这就是"睡眠"比"忙等"
省电的原因。

**提醒一点边界**：miniOS 现在只有一条执行流，没有"进程"概念，所以这里的
`ksleep` 和真实操作系统里"让出 CPU 给别的进程/线程跑"的 `sleep()` 并不完全
一样——它只是让这唯一的一条代码暂停着等时间到，并不存在"趁机去跑别的任务"
这件事。先建立"阻塞等待 vs 忙等"这个区别，调度相关的内容以后专门课程再展开。

在 `kernel/irq.c` 新增，并在 `include/irq.h` 声明：

```c
void ksleep(unsigned long ticks);   /* 睡眠 ticks 个时钟节拍后返回 */
```

要求：

- 进入时**只读一次** `irq_ticks()` 算出结束时刻，之后只和这个结束时刻比较（想想：如果每次循环都重新算，会发生什么？）。
- 等待期间执行 `idle 0`，不要空转烧 CPU。
- 不需要处理计数回绕（教学简化）。
- 前提：定时器此时必须是开着的，否则 `ksleep` 永远醒不来——这是调用约定，写进函数头注释。

### Task 3 自己写一段小 demo（写代码，约 15 行）

在 `kernel/main.c` 里写一个函数 `kernel_demo(void)`，**不提供代码**，按下面的顺序要求自己组装，调用点放在 `week11-irq-kernel-recap check done` 之前：

1. 打开定时器（`timer_init`）。
2. 调用 `strncmp_selftest()`，打印 `step 1: lib ok`。
3. `ksleep(2)`，打印 `step 2: slept 2 ticks`。
4. 执行一次 `break 0`（同步异常，应安全恢复），打印 `step 3: exception survived`。
   `break 0` 不是 C 函数，是一条汇编指令，C 代码里要用内联汇编触发它——
   写法参照第 9 次课 `kernel_main` 里已经出现过的那一行
   `__asm__ volatile("break 0");`。
5. `ksleep(3)`，打印 `step 4: slept 3 ticks`。
6. `timer_stop()`，打印 `kernel_demo: done`。

自检要点（写进报告）：

- 步骤 3 的 `break 0` 返回时 `era` 为什么需要 `+4`，而定时器中断返回时不需要？
- 两次 `ksleep` 之间 tick 数应当增加多少？你实际看到的是否吻合？

验收：`make run` 能完整看到上述六行，不卡死、不刷屏。

### 单元三阶段验收

- §5 Task 2 之后输出与上面运行验收的一致，且 `irq_dispatch` 里已没有 `printk`。
- `ksleep` 实现正确，`kernel_demo()` 六行输出齐全。

## 7. 验收标准

- 单元一：`strncmp` 独立实现，自测 `7/7 passed`，GDB 单步截图。
- 单元二：定时器中断真实跑通；听完教师串讲后能说清 `ESTAT.Ecode` 如何区分异常与中断；TVAL 打印体现周期模式自动重装；有调参记录（Task 1）与"忘记清源"的故障记录（Task 3）。
- 单元三：ISR 已瘦身；`ksleep` 与 `kernel_demo()` 跑通。

## 8. 提交清单

- [ ] 单元一：`strncmp` 自测截图（`7/7 passed`）+ GDB 单步截图（GDB 截图电子提交，不进纸质报告）
- [ ] 单元一、二、三：实验报告（见第 9 节，纸质用附件2模板，篇幅要求见 §9.1）
- [ ] 单元三：`kernel_demo()` 完整输出截图

## 9. 实验报告要求（覆盖单元一、二、三）

报告至少包含：

1. 环境说明（OS、是否 WSL、工具版本摘要）
2. 关键命令与**真实输出**（可截断，但不可编造）
3. `strncmp` 汇编代码 + 运行截图（含 7/7 输出，单元一）
4. 调参记录（§5 Task 1）与故障复现记录（§5 Task 3）
5. TVAL 输出摘录（§5 Task 2）
6. `kernel_demo()` 中两个自检问题的回答（§6 Task 3）
7. 问题与解决过程（若有）
8. 思考题作答（见本文档 §11）

### 9.1 纸质提交篇幅要求（附件2 模板）

本次课起，纸质报告用 `docs/11/附件2.上机类实验报告模板.docx` 填写并打印
提交（电子版代码仍按 §2.2 的分支/tag 方式走，两者不冲突）。模板里"上机
内容与结果"一栏本身写明"详细代码上交工程文件"——纸质报告**不贴整份文
件**，只贴能体现考核点的片段，照下面的清单贴即可：

| 片段 | 来源 | 约行数 |
|---|---|---|
| `strncmp` 汇编实现 | 单元一 §4.1 | ~20 行 |
| `timer_read_remaining()` | §5 Task 2 | ~6 行 |
| `irq_dispatch` 瘦身前后对比 | §6 Task 1 | ~15 行 |
| `ksleep()` 完整实现 | §6 Task 2 | ~20 行 |
| `kernel_demo()` 完整实现 | §6 Task 3 | ~15 行 |

合计约 76 行，模板默认字号单倍行距一页能排 45–55 行代码，**3 页以内绰绰
有余**，不需要纠结压缩字号。

截图只截"相关输出那几行"（比如串口窗口裁到 `tick` 附近 10 行即可），不要
整屏截图；单张宽度建议不超过 15cm，必要时一页并排放 2 张，确保**每张截图
不超过 1 页**。建议贴这 4 张（对应单元一 + §5 Task 2/3 + §6 Task 3，§5 Task 1 不要求截图）：

1. 单元一 `strncmp` 运行截图（含 `7/7 passed`）
2. §5 Task 2 TVAL 读数
3. §5 Task 3 故障复现（忘记清源）
4. §6 Task 3 `kernel_demo()` 完整输出

## 10. AI 共学边界

- 单元一（`strncmp`）：允许对照 ABI 检查、解释 GDB 命令；**禁止只交无注释的长代码，禁止直接向 AI 索要完整实现**——这是本课唯一的汇编编程任务，独立完成才有意义。
- 单元二/三：允许协助核对 CSR 位定义、排查编译报错；调参、TVAL 读数、故障现象、demo 输出必须来自本机 `make run` / GDB 的真实结果，不得编造。

## 11. 思考题

1. `strncmp` 和 `strcmp` 共用同一个"字节比较+提前退出"的骨架，为什么不能直接调用 `strcmp` 再截断结果？
2. 若一个中断处理函数（ISR）执行时间过长，会挡住其他更紧急的中断，如何权衡？
3. `irq_dispatch` 目前只认识定时器，如果要接入 UART 接收中断，接口应该怎么扩展？
4. `ksleep` 进入时"只读一次"结束时刻，而不是每次循环都重新计算"还要等多久"——如果改成后者，会出现什么问题？

## 12. 常见故障速查

| 现象 | 处理 |
|---|---|
| PowerShell 报 `ObjectNotFound: make` | 先 `wsl -d Ubuntu` 进入 Ubuntu，再 `cd` 仓库后 `make` |
| `wsl -d Ubuntu` 失败 | `wsl -l -v` 核对发行版名称 |
| Ubuntu 中找不到工具 | 按 `docs/student_env_runbook.md` 安装课程工具链 |
| `undefined reference to 'strncmp'` | 只在 `.h` 声明、没在 `lib/string.S` 实现，或忘了 `.globl strncmp` |
| `strncmp` 自测 case 3（`n=0`）FAIL 或读到垃圾 | 循环入口要先判断 `$a2==0`，不能先读一个字节再判断 |
| `strncmp` 自测 case 0（n 之外不同）FAIL | 检查计数减到 0 时是否正确返回相等，而不是继续往后读 |
| `strncmp` 自测 case 6 FAIL | 字节加载用了有符号的 `ld.b`，应使用 `ld.bu` |
| tick 一直不出现 | 检查 `ECFG`/`CRMD.IE` 两层开关是否都打开 |
| tick 刷屏停不下来 | 检查 `TICLR` 清源是否被误删（对照 §5 Task 3） |
| `ksleep` 永远不返回 | 定时器没开或已 `timer_stop()`；或结束时刻每轮重新计算了 |
| 编译报 `ksleep` 隐式声明或链接错误 | `include/irq.h` 忘了声明，或 `kernel/main.c` 忘了 `#include "irq.h"` |
| 退不出 QEMU | `Ctrl+a`，再按 `x` |

## 13. 附录：`kernel/irq.c` 函数逐一说明

本附录按 checkpoint 起点的 `kernel/irq.c`（还没加 §5 Task 2、§6 Task 1、§6 Task 3 的新增内容）从上到下逐个函数过一遍，供随时查阅；`ecfg_enable_timer_line`/`timer_init` 已经在 §5.0 深入推导过的部分这里不重复，只给结论和跳转。使能和清源这两个概念容易混，§5.0 末尾有专门的对比，不清楚先回去看那段。

### 13.0 模块状态：`g_ticks`

```c
static volatile unsigned long g_ticks = 0;
```

整个文件唯一的状态：记录"定时器中断一共发生了几次"。写它的只有 `irq_dispatch`（在中断里 `g_ticks++`），读它的是主循环（通过 §13.8 的 `irq_ticks()`）——一个写、一个读，分别发生在 ISR 和主循环这两条"异步"的执行路径上，这正是它必须声明为 `volatile` 的原因：编译器单看主循环这条执行路径，看不到背后还有中断随时会在它不知情的情况下改写这个变量，不加 `volatile` 就可能把本该每次重新读内存的访问优化成只读一次的寄存器缓存。§6 Task 2 的 `ksleep()` 也要靠读它来判断"睡够了没"。

### 13.1 `ecfg_enable_timer_line(void)` —— 分源开关：开

把 `ECFG`（`0x4`）第 11 位（定时器那条中断线）置 1，其余位不动。用 `csrxchg` 而不是整体 `csrwr`——完整推导、逐位走一遍的例子、配图见 §5.0。

### 13.2 `crmd_enable_ie(void)` —— 总开关：开

```c
static inline void crmd_enable_ie(void)
{
    unsigned long mask = CRMD_IE_BIT;
    unsigned long val = CRMD_IE_BIT;

    __asm__ volatile("csrxchg %0, %1, 0x0" : "+r"(val) : "r"(mask) : "memory");  /* 0x0 = CRMD */
}
```

跟 §13.1 同一个 `csrxchg` 套路，CSR 换成 `0x0`（`CRMD`），掩码换成 `1UL<<2`（`CRMD.IE`）。`CRMD` 的位布局：

| 位 | 名字 | 含义 |
|---|---|---|
| bit[1:0] | `PLV` | 当前特权级 |
| **bit2** | **`IE`** | 中断总开关，本函数要改的就是这一位 |
| bit3 | `DA` | 直接地址翻译模式 |
| bit4 | `PG` | 分页地址翻译模式 |

`PLV`/`DA`/`PG` 本课不涉及（裸机跑在启动阶段设好的直接地址模式下），但正因为它们和 `IE` 挤在同一个寄存器里，才必须用 `csrxchg` 只碰 bit2，不能整体 `csrwr`——否则会把这几位一起清零，可能直接让 CPU 跑飞。

### 13.3 `ecfg_disable_timer_line(void)` —— 分源开关：关

```c
static inline void ecfg_disable_timer_line(void)
{
    unsigned long mask = ECFG_TIMER_BIT;
    unsigned long val = 0;

    __asm__ volatile("csrxchg %0, %1, 0x4" : "+r"(val) : "r"(mask) : "memory");  /* 0x4 = ECFG */
}
```

跟 §13.1 镜像：`mask`（`rj`）不变，还是只认 bit11；`val`（`rd`）从 `1` 变成 `0`。代入 §5.0 的公式 `rd & rj` 算出来是 0，bit11 被强制清成 0，其余位不受影响——同一个机制，这次用来关而不是开。

### 13.4 `timer_irq_clear(void)` —— 清源

```c
static inline void timer_irq_clear(void)
{
    unsigned long v = 1;

    __asm__ volatile("csrwr %0, 0x44" : "+r"(v) : : "memory");  /* 0x44 = TICLR */
}
```

**先说清楚"挂起标志"具体是哪一位，别停在"有个标志"这种抽象说法上。**
定时器倒数到 0 的那一刻，硬件做的动作是：把 `ESTAT.IS` 这个位段（§13.7
表格里那个"哪条中断线在响"的位段）的 **bit11 置成 1**——没错，就是
`irq_dispatch` 里 `estat & ESTAT_IS_TIMER` 检查的**同一位**。这一位是
"记事贴"：它被贴上之后，只要 `ECFG`/`CRMD` 两层使能还开着，CPU 每次
执行完一条指令都会去看一眼"有没有贴着记事贴的中断"，看到就跳进
`exception_entry`。

**这张"记事贴"不会自己撕掉**——`ertn` 返回之后它原样还贴在那儿。于是：

```text
倒数到0 → ESTAT.IS bit11 置1（贴上记事贴）
       → CPU 跳进 exception_entry → exception_handler → irq_dispatch
       → irq_dispatch 里本该调 timer_irq_clear() 把这张贴纸撕掉……
         （§5 Task 3 故意注释掉这一行：贴纸没人撕）
       → ertn 返回
       → CPU 执行下一条指令前检查：ESTAT.IS bit11 还是 1，两层使能也还开着
       → 立刻又跳进 exception_entry ——根本没机会跑到 idle 0 或主循环
       → 不断重复，串口被 tick #N 刷屏
```

`timer_irq_clear()` 存在的唯一目的，就是在 `irq_dispatch` 里处理完的
那一刻**撕掉这张记事贴**——把 `ESTAT.IS` 的 bit11 清回 0，告诉硬件"这次
的我已经处理了，先别再跳"。`TICLR`（`0x44`）bit0 写 1，硬件就会把
`ESTAT.IS` 对应的那个 bit11 清掉——**写的位置（`TICLR` bit0）和被清掉的
位置（`ESTAT.IS` bit11）不是同一个寄存器、也不是同一个位号**，这是
`TICLR` 这个"清源专用"寄存器的硬件设计：你写它的 bit0，它内部去把
定时器那条线在 `ESTAT.IS` 里的挂起位清掉，不需要你自己算"该清哪一位"。

**为什么这里用普通 `csrwr`，不是 §13.1-13.3 的 `csrxchg`？** 因为 `TICLR`
"写 1 清对应位"是它自带的硬件语义——不是"把寄存器整体覆盖成这个值"，
而是"哪一位写 1，就精确清哪一位"，天然不会误伤别的位，不需要软件再拿
`rj` 掩码保护一层。`csrwr` 顺带把清零前的旧值读回 `v`，这里直接丢弃不用。

### CSR 速查（本节出现过的全部编号）

| CSR | 编号 | 名字 |
|---|---|---|
| `CRMD` | `0x0` | 当前模式 |
| `ECFG` | `0x4` | 中断分源使能 |
| `ESTAT` | `0x5` | 异常/中断状态（§13.7 细讲） |
| `ERA` | `0x6` | 异常返回地址 |
| `TCFG` | `0x41` | 定时器配置 |
| `TVAL` | `0x42` | 定时器当前倒数值（只读，§5 Task 2 用） |
| `TICLR` | `0x44` | 定时器中断清源 |

`ESTAT`/`ERA` 这两个编号不在 `irq.c` 里出现（它们是在 `boot/start.S` 的 `exception_entry` 里用 `csrrd` 读出来，再当参数传给 `exception_handler`/`irq_dispatch` 的），放在这里一起列出，方便对照着查"一次中断/异常经过了哪些 CSR"。

### 13.5 `timer_init(unsigned long count)` —— 对外接口：配置 + 两层使能

```c
void timer_init(unsigned long count)
{
    unsigned long tcfg = (count << 2) | TCFG_EN | TCFG_PERIODIC;

    __asm__ volatile("csrwr %0, 0x41" : "+r"(tcfg) : : "memory");  /* 0x41 = TCFG */

    ecfg_enable_timer_line();
    crmd_enable_ie();
}
```

`TCFG`（`0x41`）的三个字段从低位到高位排布：

| 位 | 字段 | 含义 |
|---|---|---|
| bit0 | `En` | 1=使能这个定时器 |
| bit1 | `Periodic` | 1=周期模式（倒数到 0 自动重装 `InitVal` 继续倒数，不是倒数一次就停） |
| bit[63:2] | `InitVal` | 倒数初值，所以代码里 `count << 2` 要把 `count` 左移 2 位，空出最低两位给 `En`/`Periodic` |

三步对应 §5.0 的"配置→使能→使能"：第一步整体 `csrwr` 写 `TCFG`——能直接整体覆盖，是因为这三个字段（`En`/`Periodic`/`InitVal`）本来就都属于定时器、都要一起设，不像 `ECFG`/`CRMD` 混了别的无关功能；第二、三步调用 §13.1/§13.2 打开两层开关。教师串讲就是对照这个函数讲一遍"配置/使能/使能"分别是哪几行。

### 13.6 `timer_stop(void)` —— 对外接口：只关一条线

```c
void timer_stop(void)
{
    ecfg_disable_timer_line();
}
```

只调用 §13.3，关掉定时器这一条线的分源开关。不碰 `CRMD.IE`（总开关留给别的中断线用）、不碰 `TCFG`（倒计时初值留着无所谓）——只关该关的那一条线，影响面刚好够用。

### 13.7 `irq_dispatch(unsigned long estat)` —— 中断分发

```c
void irq_dispatch(unsigned long estat)
{
    if (estat & ESTAT_IS_TIMER) {
        timer_irq_clear();
        g_ticks++;
        printk("tick #");
        printk_udec(g_ticks);
        printk("\n");
        return;
    }

    printk("[irq] unrecognized interrupt source, ESTAT=0x");
    printk_hex(estat);
    printk("\n");
}
```

由 `exception_handler` 在判出 `ESTAT.Ecode==0`（中断类）之后调用，把 `ESTAT`（CSR `0x5`）的原始值整个传进来。`ESTAT` 一个寄存器里塞了三个不同用途的位段，`irq_dispatch` 只用到其中一个：

| 位段 | 位置 | 这个函数用了吗 | 含义 |
|---|---|---|---|
| `IS` | bit[12:0] | **用了**：`estat & ESTAT_IS_TIMER` 查的就是这里的 bit11 | 每一位对应一条中断线有没有在"响"，bit11 固定是定时器 |
| `Ecode` | bit[21:16] | 没用（`exception_handler` 已经查过了才进来） | 区分"这次陷入是异常还是中断"（`0`=中断） |
| `EsubCode` | bit[31:22] | 没用 | 异常的子分类，本课不展开 |

`Ecode` 回答"是异常还是中断"（`exception_handler` 已经判过才进来），`IS` 回答"是哪一条中断线"（这里才判）——两件事，别搞混。定时器在 `ECFG.LIE`（§13.1）和 `ESTAT.IS`（这里）固定都是 bit11，同一条线在两个寄存器里用同一个位号，不用换算。

逻辑很直白：认出是定时器就清源（§13.4）、计数、打印；认不出就打印一行警告，不会崩（扩展口——思考题 §11.3 的 UART 中断就是往这里加一个 `else if`）。**这个函数是 §6 Task 1 要瘦身的对象**：中断里直接 `printk` 是故意留的坏习惯，§6 Task 1 会把 `tick #N` 这行打印搬到主循环。

### 13.8 `irq_ticks(void)` —— 对外接口：读计数

```c
unsigned long irq_ticks(void)
{
    return g_ticks;
}
```

把 §13.0 的 `g_ticks` 读出来返回，仅此而已——函数本身不做任何同步/保护，真正的保护在 `g_ticks` 声明时的 `volatile`（§13.0）。主循环靠反复调用它来检测"有没有新 tick"（§6 Task 1 的瘦身写法）、`ksleep()`（§6 Task 2）靠它判断"到没到该醒的时刻"。
