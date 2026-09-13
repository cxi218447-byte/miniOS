# 第 9 次课资料索引

主题：异常与中断处理（合并原第 12 次课异常入口与异常上下文 + 原第 13 次课中断基础与定时器**理论部分**）

- 技术编号：`09`
- 建议检查点：`09-trap-irq`

## 教师 / 学生资料

- [教师讲义 lecture_notes.md](lecture_notes.md)
- [实验指导书 lab.md](lab.md)
- [学生自学教材 week09_异常与中断处理教材.md](week09_异常与中断处理教材.md)（配合讲义/实验指导书的自学材料，含 §7.3 真实定时器 CSR 代码与内联汇编语法拆解；建议先读教材再做 lab.md 的 Task1–Task6）
- [课堂 PPT 09_trap_irq_course.pptx](09_trap_irq_course.pptx)（40 页，`python scripts/generate_week09_course_ppt.py` 生成）
- [教材配套 PPT 第09次课_异常与中断处理教材PPT.pptx](第09次课_异常与中断处理教材PPT.pptx)
- 讲义 PDF / 实验指导书 PDF：待生成（`python scripts/generate_all_labs.py` + `python scripts/md_to_pdf.py`）

## 说明

- 称"第 9 次课"，不称"第 9 周"。
- **理论到本课收官**：本学期实际排课把「构建、链接与调试」移到第 10 次课收尾理论部分，第 11–12 次课起不再引入新理论，只巩固、整理与迁移。
- 原第 13 次课"中断基础与定时器"的**上机实验**部分（定时器初始化等）不在本课，随第 11 次课
  "中断/定时器实验 + miniOS 内核服务整理"一起新写。
- 本次课正文已按 2026-08-29 合并方案精简改写完成（原始未合并素材 `docs/week12`/`docs/week13`
  已比对完毕并清理，不再保留）。
- 总结构见 [../course_structure.md](../course_structure.md)
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)
