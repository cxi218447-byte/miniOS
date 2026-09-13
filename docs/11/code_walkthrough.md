# 第 11 次课代码解读：中断/定时器实验怎么读

> 技术编号：`11`　|　建议检查点：`11-irq-kernel-recap`
> 配合讲义：[lecture_notes.md](lecture_notes.md)　|　配合实验：[lab.md](lab.md)
>
> 本文档面向"看代码但不知道从哪下手"的场景：先给整体定位，再给阅读顺序，
> 再把涉及的知识点讲完整，最后逐文件精读并串成一条完整时序。

## 一、这套代码整体在干什么(一句话总纲)

miniOS 到第 11 次课为止，新增的这一小块代码要解决一件事：**让 CPU 能在
"正常执行主程序"和"硬件发生了某个事件(定时器到点了)"之间自动切换，处理
完再切回来，主程序自己完全无感知**。

跑起来的效果就是 `kernel/main.c` 里那段：CPU 执行到 `idle 0` 就"睡"下去
了，主程序本身**没有任何代码在轮询定时器**；但每隔一段时间它会自动"醒"
一下、打印一行 `tick #N`，然后接着睡，睡够 5 次后 `while` 循环结束。这个
"自动醒来处理事情、处理完自动睡回去"的机制，专业说法就是**中断
(interrupt)**，是所有操作系统的地基之一——键盘敲字、网卡收包、磁盘读写
完成，都是靠这个机制通知 CPU 的。

这次课的代码不是重新发明一套机制，而是**复用**了第 9 次课已经搭好的
"异常处理骨架"(那时候只处理软件主动引发的 `break`)，把它升级成也能接
住硬件随时闯入的中断。

## 二、从哪开始读、沿什么逻辑读

**核心原则：不要一上来就啃 `irq.c`，要先搞清楚"CPU 发生异常/中断时，硬
件自己做了什么、软件必须补什么"这条主线，再看具体外设(定时器)怎么接进
这条主线。**

推荐阅读顺序(共 5 步，每一步都建立在上一步之上)：

```text
第1步  kernel/main.c 里定时器那一段（先看"结果长什么样"，建立直觉）
   ↓
第2步  背景知识：CSR、异常/中断、寄存器约定（本文第三节，边看代码边对照）
   ↓
第3步  boot/start.S 的 exception_entry（硬件跳进来后，软件第一件事做什么）
   ↓
第4步  kernel/exception.c 的 exception_handler（软件怎么判断"这是异常还是中断"）
   ↓
第5步  kernel/irq.c（中断具体是"谁"，定时器这个外设怎么配置、怎么被处理）
```

为什么是这个顺序，而不是"从上往下按文件名读"：`main.c` 是"你能看见效
果"的地方，先看它能让你知道自己在找什么；`exception_entry`→
`exception_handler`→`irq.c` 这条链，是硬件事件发生后**代码真实的执行顺
序**，按这个顺序读，每一步都能回答"接下来去哪了"，不会断片。

## 三、必须先懂的背景知识点(完整介绍)

### 3.1 什么是异常(exception)和中断(interrupt)，为什么需要它们

CPU 平时按顺序一条条执行指令(PC 自动 +4 或跳转)。但有两类情况需要"打
断"这个顺序：

- **异常(exception)**：由**当前正在执行的指令自己**引发，比如执行了
  `break`(软件断点指令)、执行了非法指令、除零。这是**同步的**——一定
  是某条具体指令导致的，可预测在哪发生。
- **中断(interrupt)**：由**外部事件**引发，和 CPU 正在执行哪条指令无
  关，比如定时器倒数到 0、键盘按下、网卡收到包。这是**异步的**——CPU
  完全不知道下一条指令执行到一半时会不会突然被打断。

LoongArch(以及大多数架构)硬件层面把这两类事件**统一处理**：不管是异常
还是中断，硬件都做同一件事——把当前 PC 存起来，跳到一个固定地址(这个
地址就是本课反复出现的 **EENTRY**)。软件再自己判断"这次是异常还是中
断、具体是哪一种"，分别处理。**这就是为什么 `exception_entry` 这一个入
口能同时接住 `break` 和定时器——硬件根本不区分，区分工作是软件做的。**

### 3.2 CSR：控制状态寄存器是什么

CSR(Control and Status Register)是 CPU 里一组专门存"CPU 当前状态/配
置"的特殊寄存器，跟 `$a0`-`$t8` 这种通用寄存器不是一回事——通用寄存器
给程序算数据用，CSR 是给"CPU 这台机器本身"记状态用的，比如"现在是不是
允许中断"、"上次异常是什么原因"。

访问 CSR 要用专门指令，本课代码里出现的三条：

| 指令 | 语法 | 含义 |
|---|---|---|
| `csrrd rd, csr` | 读 | 把编号 `csr` 的 CSR 值读到 `rd` |
| `csrwr rd, csr` | 写(整体覆盖) | 把 `rd` 的值整个写进 `csr`，**同时把 CSR 的旧值带回 `rd`** |
| `csrxchg rd, rj, csr` | 读改写(按位) | `csr = (csr & ~rj) \| (rd & rj)`：只有 `rj` 里是 1 的那些位才会被 `rd` 对应位覆盖，其余位保持原样；旧值带回 `rd` |

**为什么需要 `csrxchg` 而不是全用 `csrwr`**：像 `CRMD`(CPU 模式寄存
器)、`ECFG`(中断使能配置)这种 CSR，一个寄存器里塞了好几个互不相关的开
关位。如果用 `csrwr` 整体覆盖，你只想开一个位，却会把其他位(比如特权
级、地址翻译模式)一起清零，等于误改了不相关的硬件状态。`csrxchg` 用
"掩码 `rj`"精确圈定"我只想动这几位"，是本课里"读改写"思想的具体体现。

### 3.3 本课用到的每个 CSR 逐个讲清楚

| CSR 名 | 编号 | 干什么用 | 本课怎么用 |
|---|---|---|---|
| `CRMD` | `0x0` | Current Mode，CPU 当前运行模式的总闸门(含特权级 PLV、地址翻译开关 DA/PG、**IE 中断总开关**) | 只碰 bit2(IE)，用 `csrxchg` 只置这一位为 1，"中断总开关"打开 |
| `ECFG` | `0x4` | Exception Config，配置"每一种中断源"是否允许上报(LIE 字段，每个中断源占一位) | 只碰 bit11(定时器对应位)，置 1 表示"允许定时器这条线的中断上报" |
| `ESTAT` | `0x5` | Exception Status，记录"刚发生的是什么"——低位 IS 段标出当前有哪些中断处于挂起状态，`Ecode`(bit[21:16]) 标出异常/中断的类别号 | 在 `exception_entry` 里用 `csrrd $a0, 0x5` 读出来传给 `exception_handler`；软件靠这个字段区分"异常 vs 中断"、"哪个中断源" |
| `ERA` | `0x6` | Exception Return Address，硬件在跳入 `EENTRY` 前自动把"该返回去的地址"存在这里 | 读出来判断/修正后写回，`ertn` 靠它决定跳回哪 |
| `EENTRY` | `0xc` | Exception Entry，异常/中断发生时硬件**自动跳去执行**的地址 | 第 9 次课 `exception_init()` 把它设成 `exception_entry` 函数地址；不设置的话"异常发生了但无处可去" |
| `TCFG` | `0x41` | Timer Config，配置定时器：bit0=En(使能)，bit1=Periodic(周期模式，倒数到0后自动重装初值再倒数)，高位=InitVal(倒数初值) | `timer_init` 里把 `count<<2 \| En \| Periodic` 一次性写入 |
| `TVAL` | `0x42` | Timer Value，只读，当前倒数还剩多少 | 本课没用到，可课后自行读读看 |
| `TICLR` | `0x44` | Timer Interrupt Clear，写 1 表示"我已经处理完这次定时器中断了，把挂起标志清掉" | `timer_irq_clear()` 里写 1，**不写就会立刻重复触发同一次中断** |

**关键理解点**：`ECFG` 和 `CRMD.IE` 是**两层开关**，缺一不可——`ECFG`
管"这一路中断线自己允不允许响"，`CRMD.IE` 管"CPU 整体上还愿不愿意理会
任何中断"。就像家里的灯：`ECFG` 是这一盏灯的开关，`CRMD.IE` 是总闸，两
个都要合上灯才会亮。

### 3.4 硬件自动做的事 vs 软件必须自己做的事

这是理解 `exception_entry` 为什么要那样写的关键分界线：

**硬件自动做的(不需要你写代码)**：

- 把当前 PC(下一条要执行、或正在执行的指令地址，取决于异常类型)存进 `ERA`
- 把异常/中断的原因码写进 `ESTAT`
- 跳转到 `EENTRY` 指向的地址

**硬件不会帮你做、必须在 `exception_entry` 里手写汇编做的**：

- 保存"现场"——凡是接下来 C 代码(`exception_handler`)可能用到、会覆盖
  的寄存器，必须先存到栈上，处理完再恢复。这就是本课 144 字节栈帧的由来。
- 读取 `ESTAT`/`ERA` 传给 C 函数(因为 C 函数看不到 CSR，只能通过普通
  寄存器传参)
- 处理完后把结果写回 `ERA`，执行 `ertn` 真正跳回去

### 3.5 寄存器调用约定复习(决定了到底存哪几个寄存器)

这是第 6 次课学过的内容，这里必须回顾，因为它直接决定了
`exception_entry` 存哪 18 个寄存器：

| 寄存器组 | 角色 | 谁负责保存 |
|---|---|---|
| `$a0`-`$a7` | 函数参数/返回值 | **调用者(caller)负责**——如果调用后还要用，调用者自己先存好 |
| `$t0`-`$t8` | 临时变量 | **调用者(caller)负责**，同上 |
| `$s0`-`$s8` | 长期存活的局部变量 | **被调用者(callee)负责**——哪个函数用了它，那个函数自己存/restore |
| `$ra` | 返回地址 | 调用者/被调用者视情况，本课当"现场"的一部分存 |
| `$sp` | 栈指针 | 全程维护，不需要单独存(它自己就是"存到哪"的坐标) |

`exception_entry` 保存 `$ra + $a0-$a7 + $t0-$t8` 正好是 **caller-saved
那一组**——因为中断可能打断"任何一段正在算东西的代码"，那段代码把它
认为"调用别人时会被冲掉"的寄存器(也就是 caller-saved 组)用来存活跃值
是完全合法的，写代码的人不会防着"下一条指令可能被中断打断"。所以
`exception_entry` 必须替它把这些寄存器存好。而 `$s0`-`$s8` 不用管，因
为按约定它们本来就该被"用到它们的函数"自己保护，`exception_handler`
如果用到 `$s` 系列会自己存，不需要 `exception_entry` 代劳。

### 3.6 `ertn` 和 `idle` 这两条特殊指令

- **`ertn`**(Exception Return)：专门用于"从异常/中断返回"，效果是
  `PC ← CSR.ERA`，同时恢复特权级等硬件状态。它和普通函数返回用的
  `jr $ra` 是两回事：`jr $ra` 只是"跳到 `$ra` 存的地址"，不涉及特权
  级/中断状态的恢复；`ertn` 是异常处理这条"隐藏调用链"专属的返回方式。
- **`idle 0`**：让 CPU 停止执行、进入低功耗等待状态，直到下一次异常/
  中断到来才会被唤醒，唤醒后从 `idle` **下一条指令**继续执行。这是
  `main.c` 里能"什么都不干，靠中断自动推进"的关键——如果没有
  `idle`，你得写一个空转的 `while(1);` 去轮询，浪费 CPU。

## 四、逐文件精读(按第二节给的顺序)

### 第1步：`kernel/main.c`(先看结果，建立直觉)

```c
timer_init(TIMER_COUNT);                 // ① 配置并打开定时器中断
printk("timer_init: ...\n");
while (irq_ticks() < 5) {
    __asm__ volatile("idle 0");          // ② 睡下去，等中断把 g_ticks 加到 5
}
timer_stop();                            // ③ 关掉定时器
```

读到这里，你应该能回答："`g_ticks` 是在哪加的？`while` 判断的这个循环
里根本没有代码在改 `irq_ticks()` 的返回值啊？"——这个疑问恰好是往下读
的动机：答案在 `irq_dispatch` 里，是**中断处理函数**在背地里改的，
`main.c` 这条主线完全不知道，只是每次从 `idle` 醒来(因为发生了中断)，
重新判断一次 `while` 条件。

### 第2步：`boot/start.S` 的 `exception_entry`(硬件跳进来后，第一件事)

```asm
exception_entry:
    addi.d $sp, $sp, -144      ; 开栈帧
    st.d   $ra, $sp, 0         ; 依次存 18 个寄存器（对照 §3.5 的 caller-saved 组）
    ...
    st.d   $t8, $sp, 136

    csrrd  $a0, 0x5            ; 读 ESTAT → 当第1个参数
    csrrd  $a1, 0x6            ; 读 ERA   → 当第2个参数
    bl     exception_handler   ; 调用 C 函数，跟普通函数调用没区别

    csrwr  $a0, 0x6            ; C函数返回值 → 写回 ERA
    ld.d   $ra, $sp, 0         ; 依次恢复
    ...
    ld.d   $t8, $sp, 136
    addi.d $sp, $sp, 144
    ertn                       ; 真正跳回去
```

对照着读：`csrrd $a0, 0x5` 之所以能把 `ESTAT` 值"变成"C 函数的第一个参
数，就是因为 LoongArch 的调用约定规定"第 1 个参数放 `$a0`"——这行汇编
利用的正是 §3.5 的知识。同理 `bl exception_handler` 就是普通的"调用函
数"，C 语言看不出这里有什么特殊，`exception_handler` 只是一个正常的两
参数函数。

### 第3步：`kernel/exception.c` 的 `exception_handler`(判断异常还是中断)

```c
unsigned long ecode = (estat >> 16) & 0x3f;   // 取出 ESTAT 的 Ecode 字段
if (ecode == 0) {
    irq_dispatch(estat);   // ecode==0 按硬件定义就是"中断类"
    return era;             // 中断：原样返回，不加4
}
printk(...);                // 否则是同步异常（break等）
return era + 4;              // 异常：跳过触发异常的那条指令本身
```

**为什么中断返回 `era` 不加 4，异常要 `+4`**：`break` 这类同步异常，硬
件存进 `ERA` 的是**触发异常那条指令自己的地址**——如果原样跳回去，会
在原地再次执行 `break`，再次触发异常，死循环；所以软件要人为把 `ERA`
前进一条指令的宽度(LoongArch 定长指令，都是 4 字节)跳过它。而中断是异
步闯入的，硬件存进 `ERA` 的本来就已经是"该继续执行的下一条指令地
址"(比如 `main.c` 里 `idle 0` 的下一条)，不存在"触发指令本身"这个概
念，软件不该去改它，改了反而会跳错地方。

### 第4步：`kernel/irq.c`(定时器这个具体中断源怎么配置、怎么处理)

```c
void timer_init(unsigned long count) {
    unsigned long tcfg = (count << 2) | TCFG_EN | TCFG_PERIODIC;
    __asm__ volatile("csrwr %0, 0x41" : "+r"(tcfg) : : "memory");  // 写 TCFG
    ecfg_enable_timer_line();   // 开分源开关（ECFG）
    crmd_enable_ie();            // 开总开关（CRMD.IE）
}
```

对照 §3.3 的表：这三行分别对应"配置倒数初值+模式"、"开分路开关"、"开
总开关"，跟前面讲的两层开关模型完全对应得上。

```c
void irq_dispatch(unsigned long estat) {
    if (estat & ESTAT_IS_TIMER) {     // 判断这次中断是不是定时器（万一以后有别的中断源）
        timer_irq_clear();             // 先清源（写 TICLR），不清会立刻重新触发
        g_ticks++;                      // 这里！main.c 的 while 条件靠这行推进
        printk("tick #"); ...
        return;
    }
    printk("[irq] unrecognized interrupt source...");  // 兜底：以后接了别的中断源但没处理会走这
}
```

读到这一行 `g_ticks++`，第1步留下的疑问就解开了：`main.c` 的
`while (irq_ticks() < 5)` 每次醒来重新判断，靠的就是这里在"背地里"被
中断处理函数悄悄推进的全局变量。

## 五、串起来的完整时序(建议自己画一遍，比看文字更有效)

```text
main.c 执行 idle 0，CPU 停机
        ↓（定时器倒数到0，硬件自动触发）
硬件：ERA ← idle下一条指令地址；ESTAT ← 中断原因；PC ← EENTRY
        ↓
exception_entry：存18个寄存器 → 读ESTAT/ERA当参数 → 调 exception_handler
        ↓
exception_handler：ecode==0 → 调 irq_dispatch(estat)
        ↓
irq_dispatch：确认是定时器 → 清TICLR → g_ticks++ → printk("tick #N")
        ↓（返回到 exception_handler，再返回到 exception_entry）
exception_entry：ERA写回（值不变）→ 恢复18个寄存器 → ertn
        ↓
CPU 跳回 idle 的下一条指令 → while 重新判断 irq_ticks()<5
        ↓（不满足5次就继续循环，回到 idle 0 再次停机等下一次）
```

把这张图和前面每一步的代码对照着看几遍，理解上还卡住的地方，可以对照
[lecture_notes.md](lecture_notes.md) §4 的课堂讲法，或直接在 `kernel/irq.c`、
`kernel/exception.c`、`boot/start.S` 里找到对应行，边看代码边核对本文的
说明。
