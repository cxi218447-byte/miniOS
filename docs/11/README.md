# 第 11 次课资料索引

主题：库函数独立实现 + 中断/定时器实验 + miniOS 内核服务整理（纯实验课，4 学时连排，不引入新理论）

- 技术编号：`11`
- 建议检查点：`11-irq-kernel-recap`

## 教师 / 学生资料

- [实验指导书 lab_v2.md](lab_v2.md)
- [代码解读 code_walkthrough.md](code_walkthrough.md)（中断/定时器部分从哪开始读、阅读顺序、涉及知识点的完整介绍；库函数部分见 lab_v2.md §4）
- [课堂 PPT 11_irq_kernel_recap_course.pptx](11_irq_kernel_recap_course.pptx)（`python scripts/generate_week11_course_ppt.py` 生成，待同步新的三单元结构）
- 讲义 PDF / 实验指导书 PDF：待生成（`python scripts/generate_all_labs.py` + `python scripts/md_to_pdf.py`）

## 三个单元（4 学时连排）

| 单元 | 学时 | 内容 | 提交方式 |
|---|---|---|---|
| 单元一：库函数独立实现 | 第 1 学时 | 复习 `memset`/`memcpy`/`strlen`/`memmove`/`strcmp`/`zero_and_copy`，独立实现 `strncmp`（不给代码） | 跑通截图 |
| 单元二：定时器中断上机 | 第 2–3 学时 | Task1–3.7：读代码、运行验收、调参、`timer_read_remaining`/三档变速/`timer_pause`/`timer_resume` | 实验报告 |
| 单元三：内核服务整理 + 集成demo | 第 4 学时 | 服务地图/边界问答（直接给出，阅读理解）+ 跟做 `kernel_integration_demo()` | 跑通截图 |

## 说明

- 称"第 11 次课"，不称"第 11 周"。
- 理论已在第 9 次课收官，本课只上机复习、验证与整理，不引入新理论；单元一虽涉及库函数，但
  函数代码从 tag `07-libc-asm` 起已在仓库里，属于复习+独立扩展，不是新讲。
- 代码：`boot/start.S` 的 `exception_entry` 升级为 144 字节完整寄存器保存；新增
  `kernel/irq.c` + `include/irq.h`（`timer_init`/`irq_dispatch`/`timer_stop`）；
  `kernel/exception.c` 新增 `ESTAT.Ecode==0` 中断分支。已通过 `make run` 在
  QEMU 上实测验证周期性定时器中断（`TIMER_COUNT=0x1000000`，实测约每秒 1–2 次 tick）。
- 总结构见 [../course_structure.md](../course_structure.md)
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)
