# 第 7 次课资料索引

主题：memset/memcpy/strlen 汇编实现，以及更复杂的 memmove/strcmp/zero_and_copy

- 技术编号：`07`
- 建议检查点：`07-libc-asm`

## 教师 / 学生资料

- [学生阅读材料 student_notes.md](student_notes.md)（**教材没有覆盖这次课的内容，PPT 又比较浓缩，
  这份材料专门写给学生：库函数是什么、miniOS 为什么要自己写、链接器怎么工作、六个函数逐个讲解，
  每个抽象概念都配一个生活化类比——刷墙/复印文件/量绳子/挪书架/对暗号/打扫房间搬家具等，
  可独立阅读，不依赖 PPT）
- [教师讲义 lecture_notes.md](lecture_notes.md)
- [讲义 PDF](07_lecture_notes.pdf)
- [实验指导书 lab.md](lab.md)
- [实验指导书 PDF](07_lab.pdf)
- [课堂 PPT 07_libc_asm_course.pptx](07_libc_asm_course.pptx)（30 页。教材没讲库函数的作用和
  底层机制，PPT 里专门用 3 页补上（静态/动态链接对比、从函数调用到真正跑起来的链接器机制、
  miniOS 链接的边界与 undefined reference 真实后果），扣着"miniOS 是从裸机搭操作系统"这条线；
  另含 memmove/zero_and_copy 各一页"反例对比图"（不判断方向会怎样、只用 memcpy 不清零会怎样），
  正面讲透"为什么"而不只是"是什么"；纯知识与例子，不含实验
  任务/验收标准/故障速查（那些在 lab.md）。两套版式库支撑全部内容——概念/背景知识页用
  `scripts/general_knowledge_slide_styles.py`（概念定义式/类比讲解式/要点拆解式/对比讲解式/
  时间线式，样式取自 `scripts/general_knowledge_slide_styles.pptx`）；代码讲解页用
  `scripts/code_slide_styles.py`（逐行注释式/高亮聚焦式/对比讲解式/流程图解式/寄存器追踪式，
  样式取自 `scripts/code_slide_styles.pptx`；全部代码讲解页统一用这五种版式，不再有裸代码
  块+散装说明的旧样式）。开篇先讲背景——库函数在操作系统里的位置、
  miniOS 为什么要自己写、现实中库函数和汇编的关系（glibc/IFUNC）——PPT 本身即完整知识，
  不依赖讲义；`python scripts/generate_week07_course_ppt.py` 生成）
- [系统总览动画 week07_system_overview.html](week07_system_overview.html)（单文件、内嵌 CSS/JS，
  可直接双击打开；基于仓库真实代码，展示 Makefile → boot/start.S → kernel/main.c →
  include/string.h → lib/string.S 的构建/调用/返回关系，可点击展开源码、可播放调用流程动画；
  `lib/string.S` 内容已同步到含 memmove/strcmp/zero_and_copy 的最新版本）

## 说明

- 称“第 7 次课”，不称“第 7 周”。
- 总结构见 [../course_structure.md](../course_structure.md)
- 总索引见 [../lecture_notes_index.md](../lecture_notes_index.md)
