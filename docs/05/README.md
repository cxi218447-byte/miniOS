# 第 5 次课资料索引

主题：分支、循环与汇编程序设计基础

- 技术编号：`05`
- 建议检查点：`05-branch-loop`
- 课时：4 学时 × 45 分钟（**2026-09-17 起由 2 学时扩展为 4 学时**，腾出的 2 学时来自转为课外自学的第 10 次课，详见 [../course_structure.md](../course_structure.md) §2.7）

## 教师 / 学生资料

- [教师讲义 lecture_notes.md](lecture_notes.md)
- [讲义 PDF](05_lecture_notes.pdf)
- [实验指导书 lab.md](lab.md)
- [实验指导书 PDF](05_lab.pdf)
- [课堂 PPT 05_branch_loop_course.pptx](05_branch_loop_course.pptx)（**尚未按 4 学时扩容，仍是 2 学时版本，需另行更新**）
- [课前准备：安装 qemu-user](install_qemu_user.md)（**请提前发给学生，课前装好**）

## 四学时安排

| 学时 | 内容 | 实验衔接 |
|---:|---|---|
| 第 1 学时 | 控制流指令家族（`b`/`beq`/`bne`/`beqz`/`bnez`）、局部标号 `1b`/`2f`、while 计数模板 | 课堂演示，不单列实验任务 |
| 第 2 学时 | if-else 模板、字符串遍历骨架、回看 `clear_bss`、"五问"方法论 | 课堂演示，不单列实验任务 |
| 第 3 学时（新增） | **独立于 miniOS 仓库**的两个最小纯汇编程序：寄存器赋值/交换/打印、最简单的计数循环打印（代码给），都跑在 `qemu-loongarch64`（用户态模拟）上；各带一个**改造要求**（不给代码） | **Task1**：swap 截图 + 三寄存器轮换截图；**Task2**：1-5 截图 + 反向打印截图 |
| 第 4 学时（新增） | 回到 miniOS 仓库，数组查找：5.1 用 `bl_find_first`（找到提前退出）完整走一遍"声明→实现→调用→编译→运行"链路（代码给）；5.2 独立实现 `bl_find_last`（不提前退出，扫完整个数组记录最后一次命中，**不给任何骨架代码**） | **Task3**：`make run` 截图（本课核心产出） |

**2026-09-17 二次更新**：实验重新设计为三个任务，Task1/Task2 完全独立于 miniOS 仓库（不需要克隆仓库、不涉及 git tag），只需额外装 `qemu-user`（见 `docs/student_env_runbook.md` §5.1）；Task3 回到 miniOS 体系，定为"数组查找"（`bl_find_first`/`bl_find_last`），衔接第 3 次课的比较类指令、练"提前退出"这个新控制流模式；5.1 是链路演示（代码直接给），5.2 是真正的独立产出（不给骨架）。前两学时内容仍通过课堂演示和 `lib/branch_loop.S` 已有 demo 讲透，不单独布置书面作业。`bl_find_last` 的完整参考答案由教师保留在本地专用分支，不随本次课资料一起发布，见教师端说明。

**2026-09-17 三次更新**：Task1/Task2 原来给的完整代码只是起点，各追加一个"改造成新功能"的要求（不给代码，只给规格）：Task1 从"两寄存器交换"升级成"三寄存器轮换"（`t0=5,t1=8,t2=3` → `t0=8,t1=3,t2=5`），Task2 从"顺序打印 1-5"改成"反向打印 5-1"。共 5 张截图，详见 `lab.md`。

## 说明

- 称“第 5 次课”，不称“第 5 周”。
- 总结构见 [../course_structure.md](../course_structure.md)
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)
