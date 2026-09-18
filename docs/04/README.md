# 第 4 次课资料索引

主题：访存指令与内存数据组织（教材第 3 章 §3.2）+ 浮点基础（教材第 4 章）

- 技术编号：`04`
- 建议检查点：`04-load-store`
- 课时：4 学时 × 45 分钟（两个 90 分钟教学单元）
- 课堂课件：77 页，只读作为讲义与实验的内容依据

## 教师 / 学生资料

- [教师讲义 lecture_notes.md](lecture_notes.md)
- [讲义 PDF](04_lecture_notes.pdf)
- [实验指导书 lab.md](lab.md)
- [实验指导书 PDF](04_lab.pdf)
- [课堂 PPT 04_load_store_course.pptx](04_load_store_course.pptx)
- [LL/SC 与 DBAR 交互动画](animations/llsc_dbar_demo.html)
- [IEEE 754 浮点数格式转换动画](animations/ieee754_animation.html)（十进制 → 二进制展开 → 阶码 → 尾数舍入，逐步演示）

## 内容层级

| 层级 | 内容 | 教学要求 |
|---|---|---|
| 核心精讲 | 有效地址、普通 `ld/st`、宽度、加载扩展、存储截断、对齐 | 会演算、会逐条解释 |
| 工程贯通 | `.data/.bss`、`clear_bss`、栈槽、UART MMIO | 能用统一访存模型解释 |
| 核心精讲 | IEEE 754、FPR、`fld/fst`、浮点运算/比较/转换/传送 | 能区分运算、搬位和转换 |
| 理解性扩展 | 边界检查访存、LL/SC、AM、DBAR/IBAR | 纸面推演，不要求当前内核实现 |
| 后续衔接 | 条件分支、`b/bl/jirl` | 本课只读懂示例，第 5 次课系统学习 |

这样既覆盖课件的完整知识面，又保持课程边界：第 4 次课不变成多核同步实验课，也不提前替代第 5 次课的分支与循环。

## 四学时安排

| 学时 | 内容 | 实验衔接 |
|---:|---|---|
| 第 1 学时 | 地址空间、寻址、有效地址、普通加载与扩展 | 地址与加载预测 |
| 第 2 学时 | 存储截断、对齐、`.data/.bss`、UART MMIO | 普通访存运行验收 |
| 第 3 学时 | 边界检查、LL/SC、AM、DBAR/IBAR | 竞态与同步纸面推演 |
| 第 4 学时 | IEEE 754、FPR、浮点访存/运算/比较/转换 | 浮点运行验收 |

## 实验闭环

实验分两个 90 分钟单元，均采用“预测—运行—解释”：

1. 第 1–2 学时预测有效地址和符号/零扩展，运行 QEMU 验收普通访存；
2. 第 3 学时纸面推演普通读改写、LL/SC 与数据栅障；
3. 第 4 学时预测 IEEE 754 位模式，运行 QEMU 验收浮点闭环；
4. 全程用助记符、操作数和状态变化解释结果。

## 本课代码要点

| 文件 | 说明 |
|---|---|
| `lib/mem_fp.S` | 普通访存与浮点运算/转换示例 |
| `include/mem_fp.h` | 汇编函数的 C 声明 |
| `kernel/main.c` | 使能浮点单元并输出验收结果 |
| `Makefile` | 将 `lib/mem_fp.S` 纳入构建 |

预期串口摘要：

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

## 说明

- 对外表述统一使用“第 4 次课”等课次称谓。
- 汇编语句按“助记符—操作数—状态变化”讲授。
- PPT 正文字号遵守课程要求（不低于 24 磅）；本次更新不修改 PPT。
- 总结构见 [../course_structure.md](../course_structure.md)。
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)。
