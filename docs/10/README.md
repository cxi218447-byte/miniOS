# 第 10 号资料索引（课外自学，不占课堂学时）

主题：构建、链接与调试（合并原第 7 次课 Makefile/链接脚本/镜像结构 + 原第 8 次课 GDB 调试与反汇编分析）

> **2026-09-17 更新：本材料转为课外自学，不再是课堂课次，不占用课堂学时**——腾出的
> 2 学时给了第 5 次课扩容（详见 [../course_structure.md](../course_structure.md) §2.7）。
> 第 11、12 次课编号、tag、目录均不受影响。下方 tag 为**可选自学验收**，教师不在课堂验收。

- 技术编号：`10`
- 建议检查点：`10-build-debug`（可选自学验收，非课堂检查点）

## 教师 / 学生资料

- [教师讲义 lecture_notes.md](lecture_notes.md)
- [实验指导书 lab.md](lab.md)
- [课堂 PPT 10_build_debug_course.pptx](10_build_debug_course.pptx)（40 页，`python scripts/generate_week10_course_ppt.py` 生成）
- 讲义 PDF / 实验指导书 PDF：待生成（`python scripts/generate_all_labs.py` + `python scripts/md_to_pdf.py`）

## 说明

- 称“技术编号 10 · 课外自学材料”，不称“第 10 次课”“第 10 周”（2026-09-17 起不再是课堂课次）。
- **2026-09-17 更新**：由课堂课次转为课外自学，不占用课堂学时；第 11、12 次课紧接第 9 次课（异常与中断处理）之后正常上课，详见 [../course_structure.md](../course_structure.md) §2.7。
- **2026-09-07 更新（历史记录）**：本材料曾在本学期实际排课中位于理论收官位置，紧接原第 9 次课之后；第 7–9 次课改为先讲 `memset/memcpy/strlen`、UART/系统调用、异常与中断，详见 [../course_structure.md](../course_structure.md) §2.6。
- 建议检查点 `10-build-debug` 与 `09-trap-irq` 指向同一提交（本课不新增源文件，构建/调试内容建立在此前所有课次代码之上）。
- 本次课正文已按 2026-08-29 合并方案精简改写完成（原始未合并素材 `docs/week07`/`docs/week08`
  已比对完毕并清理，不再保留）。
- 总结构见 [../course_structure.md](../course_structure.md)
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)
