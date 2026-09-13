# 第 11 次课资料索引

主题：中断/定时器实验 + miniOS 内核服务整理（纯实验课，4 学时连排，不引入新理论）

- 技术编号：`11`
- 建议检查点：`11-irq-kernel-recap`

## 教师 / 学生资料

- [教师讲义 lecture_notes.md](lecture_notes.md)
- [实验指导书 lab.md](lab.md)
- [代码解读 code_walkthrough.md](code_walkthrough.md)（从哪开始读、阅读顺序、涉及知识点的完整介绍）
- [课堂 PPT 11_irq_kernel_recap_course.pptx](11_irq_kernel_recap_course.pptx)（41 页，`python scripts/generate_week11_course_ppt.py` 生成）
- 讲义 PDF / 实验指导书 PDF：待生成（`python scripts/generate_all_labs.py` + `python scripts/md_to_pdf.py`）

## 说明

- 称"第 11 次课"，不称"第 11 周"。
- 理论已在第 10 次课收官，本课只上机巩固与整理。
- 代码：`boot/start.S` 的 `exception_entry` 升级为 144 字节完整寄存器保存；新增
  `kernel/irq.c` + `include/irq.h`（`timer_init`/`irq_dispatch`/`timer_stop`）；
  `kernel/exception.c` 新增 `ESTAT.Ecode==0` 中断分支。已通过 `make run` 在
  QEMU 上实测验证周期性定时器中断（`TIMER_COUNT=0x1000000`，实测约每秒 1–2 次 tick）。
- 总结构见 [../course_structure.md](../course_structure.md)
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)
