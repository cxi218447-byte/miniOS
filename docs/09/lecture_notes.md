# 第 9 次课教师讲义：异常与中断处理

> 技术编号：`09`　|　建议检查点：`09-trap-irq`  
> 合并原第 12 次课（异常入口与异常上下文）+ 原第 13 次课（中断基础与定时器）的**理论部分**。
> 中断/定时器的**上机实验**部分移到第 11 次课（纯实验课）；本课只讲到能看懂、能讨论的程度。
>
> **2026-09-07 更新**：本学期实际排课把「构建、链接与调试」移到第 10 次课，作为理论部分真正的收官；本课讲完后紧接第 10 次课，第 11–12 次课起不再引入新理论，只巩固、整理与迁移。

## 0. 一句话目标

读懂 `exception_entry`/`exception_init`/`exception_handler` 的同步异常闭环，并建立中断（异步事件）的最小概念模型：使能、中断源、处理、清源。

## 1. 课程定位（Why）

```text
第 1–8 次课：主动执行的代码流（调用/循环/系统调用都是”我方发起”）
     ↓
第 9 次课：代码流可能被”打断”——同步异常（自己触发） vs 异步中断（外部通知）
```

仓库已有框架：`boot/start.S` 的 `exception_entry`、`kernel/exception.c` 的 `exception_init`/`exception_handler`。本次课把框架讲成可观察闭环（先看见异常，再谈高级策略），并把中断作为异常的"异步版本"引出。

## 2. 教学目标

1. 说明异常与普通函数调用的差异；解释 `csrrd` 读 ESTAT/ERA，`csrwr` 写 EENTRY。
2. 逐条讲解 `exception_entry` 栈帧与 `ertn`（不是 `jr $ra`）。
3. 用表格对比异常与中断：触发方式、可屏蔽性、教学重点。
4. 说明中断使能、屏蔽、中断源、处理程序、清源/应答的关系。
5. 给出完整上下文保存的教学骨架，理解为何它比 `exception_entry` 更"重"。
6. 讲述定时器 tick 故事线（配置→使能→计数/处理→清源）与关中断临界区的意义（不要求本课上机实现）。

## 3. 课前准备

- `boot/start.S` 异常段、`kernel/exception.c`
- 复习第 6 次课栈帧、第 8 次课"中断里 `printk` 可能重入"

## 4. 课程知识

### 4.1 两条路径对比：调用 / 异常 / 中断

| | 普通调用 | 异常 | 中断 |
|---|---|---|---|
| 入口 | `bl` | 硬件跳到 EENTRY | 硬件跳到 EENTRY（同一向量体系） |
| 触发 | 主动 | 执行流同步检测到 | 外设异步通知 |
| 返回 | `jr $ra` | `ertn`（回到 ERA 等） | `ertn` |
| 现场 | 约定保存 | 入口需主动保存更多状态 | 通常比异常保存得更多（见 §4.5） |
| 可屏蔽性 | — | 视类型 | 常可屏蔽 |

### 4.2 exception_entry 精读

```asm
exception_entry:
    addi.d      $sp, $sp, -32
    st.d        $ra, $sp, 24

    csrrd       $a0, 0x5          /* ESTAT */
    csrrd       $a1, 0x6          /* ERA */
    bl          exception_handler /* 返回值 $a0 = 处理函数给出的新 ERA */

    csrwr       $a0, 0x6          /* 写回 ERA，供 ertn 使用 */
    ld.d        $ra, $sp, 24
    addi.d      $sp, $sp, 32
    ertn
```

1. **伸栈并保存 `$ra`**：准备 `bl` 到 C，与第 6 次课非叶子函数同构。
2. **`csrrd`**：读控制状态寄存器到通用寄存器。
3. **参数**：`$a0=ESTAT`，`$a1=ERA`。
4. **`exception_handler` 有返回值**：新的 ERA（实测中 `break`/`syscall` 的 ERA 指向触发指令本身，处理函数按需 `+4` 跳过它，见 §5 Demo 的踩坑点），`exception_entry` 用 `csrwr` 写回 CSR.ERA。
5. **恢复后 `ertn`**：异常返回；不要与 `jr $ra` 混为一谈。
6. 教学说明：完整上下文通常还需保存更多寄存器；此处是最小教学骨架。

### 4.3 初始化 EENTRY 与处理函数

```c
void exception_init(void)
{
    unsigned long entry = (unsigned long)exception_entry;
    __asm__ volatile("csrwr %0, 0xc" : : "r"(entry) : "memory");
}

unsigned long exception_handler(unsigned long estat, unsigned long era)
{
    printk("[exception] ESTAT=0x");
    printk_hex(estat);
    printk(" ERA=0x");
    printk_hex(era);
    printk("\n");
    return era + 4;   /* break/syscall：跳过触发指令本身，见 §5 */
}
```

- CSR `0xc`：EENTRY（以课程/手册为准）；不设置则异常到来时"无处可去"。
- 先能**看见**，再谈恢复、杀死上下文、缺页等。

### 4.4 中断：概念对照

| 概念 | 教学说明 |
|---|---|
| 中断源 | 定时器、UART 收等 |
| 中断使能 | 总开关 + 分源开关 |
| 中断入口 | 与异常向量体系相关（平台相关） |
| 上半部 | 入口尽快做完关键事 |
| 清源/应答 | 避免同一中断反复进入 |

### 4.5 中断入口骨架（示意，比 exception_entry 更重）

```asm
interrupt_entry:
    addi.d  $sp, $sp, -256
    st.d    $ra, $sp, 0
    st.d    $a0, $sp, 8
    # ... 保存需要的寄存器 ...
    bl      interrupt_handler
    # ... 恢复 ...
    addi.d  $sp, $sp, 256
    ertn
```

1. 异步入口**不能假设**调用约定现场仍完整——中断可能打在任何一条指令之间。
2. 保存集合通常大于教学用 `exception_entry`。
3. 数字 256 不重要，**"主动保存会被破坏的状态"**才重要。
4. **第 11 次课会把这个想法落到真代码**：LoongArch 的异常和中断实际共享同一个 `EENTRY`（不是两个入口），所以真正的做法是把 `exception_entry` 原地升级为保存全部 caller-saved 寄存器（`$ra`+`$a0`-`$a7`+`$t0`-`$t8`，144 字节），而不是另建一个 `interrupt_entry`——见 `docs/11/lecture_notes.md` §4.4。

### 4.6 定时器最小故事线（概念，上机留到第 11 次课）

1. 配置周期
2. 使能中断
3. 处理函数：`ticks++`，必要时 `printk`，清中断源
4. 主循环可 `idle` 等待

`ticks` 若为全局未初始化变量，必须保证 `.bss` 已清零（回看第 2 次课）。

**首尾完整的真实代码**（含真实 CSR 编号、`exception_handler` 新增的中断分支、内联汇编语法逐项拆解）见学生自学教材 `week09_异常与中断处理教材.md` §7.3——课堂上可以直接投影这段代码带读，不需要重新板书设计，对应 `lab.md` Task5。

### 4.7 并发与临界区

- 主循环与中断同时写 UART → 字符交错。
- 短时间关中断保护共享数据（教学点到，不要求本课实现锁）。
- 对应 `lab.md` Task5.5（必做，书面）；教材 §8 有更完整的类比展开。

## 5. 课堂 Demo

1. 调用 `exception_init`，按课堂安全方案触发可控异常，串口观察 ESTAT/ERA 打印。
2. 无中断：死循环偶尔输出；开定时器（若环境具备）：周期性 tick；讨论关中断后 tick 停止。
3. 对照异常/中断两条入口骨架，圈出"多存了什么"。
4. 可运行 demo：`boot/start.S` 的 `exception_entry` + `kernel/exception.c` 的
   `exception_init`/`exception_handler`。`kernel_main` 用内联汇编 `break 0`
   主动触发一次异常，实测 `ESTAT=0xc0000`（Ecode=0xC，BRK）。**踩坑点**：
   `break`/`syscall` 这类精确异常的 ERA 指向触发指令本身，不是下一条——
   若原样 `ertn` 会在原地死循环；`exception_handler` 返回 `era + 4`，
   `exception_entry` 用 `csrwr $a0, 0x6` 写回 CSR.ERA 后再 `ertn`，才能正确
   继续执行。这是"处理函数里再次触发异常会怎样"（§8 思考题）的具体实例。
   `make run` 核对 `week09-trap-irq check done`。

## 6. 实验实践

**Task A**　给 `exception_entry` 填"指令→影响"表；书面回答为什么这里最终是 `ertn`。

**Task B**　完成"异常 vs 中断"对照表（触发、可屏蔽、教学重点）。

**Task C**　精读教材 §7.3 的真实定时器代码（真实 CSR 编号、`exception_handler` 新增中断分支），说明中断分支为何 `return era` 而不是 `era+4`，再设计 `ticks` 变量与打印策略（每 N 次打一次），伪代码即可——具体上机实现放在第 11 次课。

**Task D（选做）**　扩展打印更多 CSR。

**Task E（必做，书面）**　并发与临界区：为什么主循环和中断同时 `printk` 会乱码？关中断保护共享数据的代价是什么？（教材 §8，对应 `lab.md` Task5.5）

## 7. AI 共学

允许解释 CSR 含义摘要、整理中断概念图；编号/寄存器地址必须以讲义/手册为准，不得凭空编造。

## 8. 思考与拓展

1. 处理函数里再次触发异常会怎样？
2. ERA 与 `$ra` 各服务哪条路径？
3. 为什么中断处理要尽量短？
4. 中断与 syscall（第 8 次课）如何共同构成 OS 的"两扇门"？

## 9. 板书

```text
EENTRY → exception_entry：存 ra → csrrd 参数 → bl handler → ertn
异步中断：更重的现场保存 → 处理 → 清源 → 返回
tick：配置/使能/计数/打印；注意 printk 重入、.bss 清零
理论至第 10 次课收官：第 11 次课起全部上机
```
