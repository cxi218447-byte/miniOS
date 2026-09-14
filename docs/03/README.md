# 第 3 次课资料索引

主题：寄存器、数据表示与基础指令  

**教材进度：系统讲完第 2 章 + 第 3 章 §3.1**（运算指令 3.1.1～3.1.4）

- 技术编号：`03`
- 建议检查点：`03-regs-alu`

## 教师 / 学生资料

- [教师讲义 lecture_notes.md](lecture_notes.md)
- [教案 lesson_plan.md](lesson_plan.md)
- [实验指导书 lab.md](lab.md)（**从简：以 make run 为主**；指令细节在讲义/课件）
- [课堂 PPT 03_regs_alu_course.pptx](03_regs_alu_course.pptx)  
  **教材：第2章 + §3.1 系统讲完**；顺序：第2章风貌 → 寄存器/宽度/存放 → §3.1.1～3.1.4 走读（约 59 页）
- 讲义/实验 PDF（若已生成）：`03_lecture_notes.pdf`、`03_lab.pdf`
- [原码 / 反码 / 补码与溢出 交互动画](animations/sign_ones_twos_overflow_demo.html)
- [条件选择（min）slt/maskeqz/masknez/or 交互动画](animations/cond_select_min_demo.html)（对应课件第45~46页例3.8）

## 本课代码要点

| 文件 | 说明 |
|---|---|
| `lib/regs_alu.S` | `alu_expr` / `alu_low8` / `alu_sum2` |
| `include/regs_alu.h` | C 声明 |
| `kernel/main.c` | 调用并打印验收串 |
| `Makefile` | `SRCS_S` 含 `lib/regs_alu.S` |

预期串口含分类验收（摘要）：

```text
arith add/sub: (3+5)-2 = 6
arith mul: 6*7 = 42
logic andi: 0x1234 & 0xff = 0x34
shift slli: 5<<1 = 10
cond slt: (3<5) = 1
bit ext.w.b: 0x7f -> 127
...
03-regs-alu check done
```

指令覆盖：算术/逻辑/移位/条件/位操作/访存/转移/杂项各 ≥1 条；浮点口述。
## 教材

- 《汇编语言编程基础 基于 LoongArch》（孙国云、敖琪、王锐）
  - **第 3 章** 基础整数指令集 —— 本课主对照（重点 §3.1 运算）
  - **第 4 章** 基础浮点数指令集 —— 本课只划边界
- 读书笔记索引（非替代正版书）：  
  https://blog.csdn.net/loongsoner/article/details/128977015

## 说明

- 称“第 3 次课”，不称“第 3 周”。
- **边界：** 访存与浮点**精讲在第 4 次课**；本课只点到 `st.b` / 口述浮点。
- 总结构见 [../course_structure.md](../course_structure.md)
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)
- PPT 生成：`python scripts/generate_03_course_ppt.py`
