# Week 01 Lesson 1-2 PPT/Lecture-Notes Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the Week 01 course deck's Lesson 1 ("为什么学习汇编") and Lesson 2 ("LoongArch 最小知识包") — a combined 90-minute session — with enough depth, worked examples, timed activities, and speaker-note pacing to actually fill the time, and keep the matching lecture notes document in sync.

**Architecture:** All changes are made in `scripts/generate_week01_course_ppt.py` (a python-pptx generator script that is re-run to produce the `.pptx`, never hand-edited) plus `docs/week01/week01_qemu_hello_lecture_notes.md` (hand-edited Markdown). No new files, no new dependencies.

**Tech Stack:** Python 3, `python-pptx`, Markdown, Git Bash for verification commands.

## Global Constraints

- Corrected output path for the generated deck must be exactly `docs/week01/week01_qemu_hello_course.pptx` (the script currently writes to the stale `docs/week01_qemu_hello_course.pptx`).
- Any illustrative/representative compiler output that was not actually compiled on this machine must be labeled in both the slide and the lecture notes as "教学示意，非本机实测编译输出" (this machine has no `loongarch64-linux-gnu-gcc` installed).
- Whatever appears in the PPT for the new/expanded content must have a corresponding, matching section in `docs/week01/week01_qemu_hello_lecture_notes.md`.
- Do not modify `docs/week01/qemu_hello.md` (student lab handout).
- Do not touch `docs/week01/week01_qemu_hello_course_v2 (1).pptx` (untracked, unrelated file — leave it alone).
- Do not expand Lesson 3 or Lesson 4 content — this plan is scoped to the Lesson 1+2 combined 90-minute session only.
- Keep using the existing slide-builder pattern (`add_bullet_slide`, `add_code_slide`, `add_flow_slide`, `add_section_slide`, `add_table_slide`) — extend it, don't replace the architecture.

---

### Task 1: Generator infrastructure — speaker notes, generic table slide, annotated-code slide, output path fix

**Files:**
- Modify: `scripts/generate_week01_course_ppt.py:1-176`
- Verify: `docs/week01/week01_qemu_hello_course.pptx` (regenerated)

**Interfaces:**
- Produces: `set_speaker_notes(slide, text) -> slide`, `add_table_slide(prs, heading, subtitle, lesson, headers, rows, col_widths, footer) -> slide` (replaces the old hardcoded no-arg version), `add_code_annotated_slide(prs, heading, code_text, annotations, subtitle=None, lesson=None, font_size=12) -> slide`.
- Consumes: existing `apply_font`, `set_background`, `add_title`, `COLORS`, `MSO_AUTO_SHAPE_TYPE`, `Inches`, `Pt` (all already defined/imported in the file).

- [ ] **Step 1: Fix the output path**

In `scripts/generate_week01_course_ppt.py`, find:

```python
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "week01_qemu_hello_course.pptx"
```

Replace with:

```python
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "week01" / "week01_qemu_hello_course.pptx"
```

- [ ] **Step 2: Add `set_speaker_notes` helper**

Find:

```python
def apply_font(run, size=22, bold=False, color=None, name="Microsoft YaHei"):
    run.font.name = name
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color or COLORS["ink"]


def set_background(slide):
```

Replace with:

```python
def apply_font(run, size=22, bold=False, color=None, name="Microsoft YaHei"):
    run.font.name = name
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color or COLORS["ink"]


def set_speaker_notes(slide, text):
    notes = slide.notes_slide
    notes.notes_text_frame.text = text
    return slide


def set_background(slide):
```

- [ ] **Step 3: Add `add_code_annotated_slide` helper**

Find:

```python
def add_section_slide(prs, lesson, heading, goal):
```

Replace with:

```python
def add_code_annotated_slide(prs, heading, code_text, annotations, subtitle=None, lesson=None, font_size=12):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, heading, subtitle, lesson)
    code_shape = slide.shapes.add_shape(
        MSO_AUTO_SHAPE_TYPE.ROUNDED_RECTANGLE,
        Inches(0.7),
        Inches(1.75),
        Inches(6.6),
        Inches(5.08),
    )
    code_shape.fill.solid()
    code_shape.fill.fore_color.rgb = COLORS["code_bg"]
    code_shape.line.color.rgb = COLORS["code_bg"]
    tf = code_shape.text_frame
    tf.clear()
    tf.word_wrap = True
    tf.margin_left = Inches(0.18)
    tf.margin_right = Inches(0.18)
    tf.margin_top = Inches(0.14)
    p = tf.paragraphs[0]
    r = p.add_run()
    r.text = code_text
    apply_font(r, size=font_size, color=COLORS["code_fg"], name="Consolas")

    box = slide.shapes.add_textbox(Inches(7.5), Inches(1.85), Inches(5.15), Inches(4.95))
    note_tf = box.text_frame
    note_tf.clear()
    note_tf.word_wrap = True
    for i, item in enumerate(annotations):
        para = note_tf.paragraphs[0] if i == 0 else note_tf.add_paragraph()
        para.space_after = Pt(8)
        run = para.add_run()
        run.text = item
        apply_font(run, size=14)
    return slide


def add_section_slide(prs, lesson, heading, goal):
```

- [ ] **Step 4: Generalize `add_table_slide`**

Find:

```python
def add_table_slide(prs):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, "LoongArch 通用寄存器最小表", "第一周先认编号和常用 ABI 别名。", "第 2 节")
    rows = [
        ("r0", "zero", "常量 0", "硬件恒为 0"),
        ("r1", "ra", "返回地址", "bl 调用函数时写入"),
        ("r3", "sp", "栈指针", "进入 C 前必须设置"),
        ("r4-r11", "a0-a7", "参数寄存器", "函数参数，前两个也可作返回值"),
        ("r12-r20", "t0-t8", "临时寄存器", "短期计算常用"),
        ("r22-r31", "fp/s0-s9", "保存寄存器", "函数调用约定后续展开"),
    ]
    table_shape = slide.shapes.add_table(len(rows) + 1, 4, Inches(0.8), Inches(1.9), Inches(11.75), Inches(4.25))
    table = table_shape.table
    for idx, width in enumerate([1.35, 2.1, 2.3, 5.95]):
        table.columns[idx].width = Inches(width)
    headers = ["编号", "ABI 别名", "主要用途", "课堂说明"]
    for col, header in enumerate(headers):
        cell = table.cell(0, col)
        cell.text = header
        cell.fill.solid()
        cell.fill.fore_color.rgb = COLORS["blue"]
        for p in cell.text_frame.paragraphs:
            for r in p.runs:
                apply_font(r, size=13, bold=True, color=COLORS["white"])
    for row_idx, row in enumerate(rows, start=1):
        for col, value in enumerate(row):
            cell = table.cell(row_idx, col)
            cell.text = value
            cell.fill.solid()
            cell.fill.fore_color.rgb = COLORS["white"]
            for p in cell.text_frame.paragraphs:
                for r in p.runs:
                    apply_font(r, size=12)
    add_text(slide, 0.82, 6.55, 11.7, 0.35, "讲解顺序：先用 r 编号建立硬件视角，再用 ABI 别名阅读源码。", size=13, color=COLORS["muted"])
    return slide
```

Replace with:

```python
def add_table_slide(prs, heading, subtitle, lesson, headers, rows, col_widths, footer):
    slide = prs.slides.add_slide(prs.slide_layouts[6])
    set_background(slide)
    add_title(slide, heading, subtitle, lesson)
    table_shape = slide.shapes.add_table(len(rows) + 1, len(headers), Inches(0.8), Inches(1.9), Inches(11.75), Inches(4.25))
    table = table_shape.table
    for idx, width in enumerate(col_widths):
        table.columns[idx].width = Inches(width)
    for col, header in enumerate(headers):
        cell = table.cell(0, col)
        cell.text = header
        cell.fill.solid()
        cell.fill.fore_color.rgb = COLORS["blue"]
        for p in cell.text_frame.paragraphs:
            for r in p.runs:
                apply_font(r, size=13, bold=True, color=COLORS["white"])
    for row_idx, row in enumerate(rows, start=1):
        for col, value in enumerate(row):
            cell = table.cell(row_idx, col)
            cell.text = value
            cell.fill.solid()
            cell.fill.fore_color.rgb = COLORS["white"]
            for p in cell.text_frame.paragraphs:
                for r in p.runs:
                    apply_font(r, size=12)
    add_text(slide, 0.82, 6.55, 11.7, 0.35, footer, size=13, color=COLORS["muted"])
    return slide
```

- [ ] **Step 5: Update the only existing call site to pass explicit arguments**

Find:

```python
    add_table_slide(prs)
```

Replace with:

```python
    add_table_slide(
        prs,
        "LoongArch 通用寄存器最小表",
        "第一周先认编号和常用 ABI 别名。",
        "第 2 节",
        ["编号", "ABI 别名", "主要用途", "课堂说明"],
        [
            ("r0", "zero", "常量 0", "硬件恒为 0"),
            ("r1", "ra", "返回地址", "bl 调用函数时写入"),
            ("r3", "sp", "栈指针", "进入 C 前必须设置"),
            ("r4-r11", "a0-a7", "参数寄存器", "函数参数，前两个也可作返回值"),
            ("r12-r20", "t0-t8", "临时寄存器", "短期计算常用"),
            ("r22-r31", "fp/s0-s9", "保存寄存器", "函数调用约定后续展开"),
        ],
        [1.35, 2.1, 2.3, 5.95],
        "讲解顺序：先用 r 编号建立硬件视角，再用 ABI 别名阅读源码。",
    )
```

- [ ] **Step 6: Run the generator and verify no regression**

Run:

```bash
python scripts/generate_week01_course_ppt.py
```

Expected: prints the new path ending in `docs/week01/week01_qemu_hello_course.pptx` and a slide count (should be unchanged from before this task — still the original slide count, since no slides were added yet, only refactored).

Run:

```bash
python - <<'PY' | tee week01_ppt_dump.txt
from pptx import Presentation
prs = Presentation("docs/week01/week01_qemu_hello_course.pptx")
for i, slide in enumerate(prs.slides):
    for shape in slide.shapes:
        if shape.has_text_frame:
            print(f"{i}: {shape.text_frame.text}".replace("\n", " | "))
        if shape.has_table:
            for row in shape.table.rows:
                print(f"{i}: " + " / ".join(c.text for c in row.cells))
PY
grep -c "LoongArch 通用寄存器最小表" week01_ppt_dump.txt
grep -c "讲解顺序：先用 r 编号建立硬件视角" week01_ppt_dump.txt
rm week01_ppt_dump.txt
```

Expected: both `grep -c` calls print `1` (register table slide still renders with the same heading and footer as before).

- [ ] **Step 7: Commit**

```bash
git add scripts/generate_week01_course_ppt.py docs/week01/week01_qemu_hello_course.pptx
git commit -m "$(cat <<'EOF'
Fix week01 PPT output path and generalize table/annotated-code slide builders

Prepares the generator for Lesson 1-2 content expansion without behavior
change: corrects the stale output path, and turns the register-table
builder into a reusable generic table slide.
EOF
)"
```

---

### Task 2: Add the 90-minute time budget slide

**Files:**
- Modify: `scripts/generate_week01_course_ppt.py` (inside `build()`, between the "四节课安排" bullet slide and the Lesson 1 section slide)
- Verify: `docs/week01/week01_qemu_hello_course.pptx` (regenerated)

**Interfaces:**
- Consumes: `add_table_slide` and `set_speaker_notes` from Task 1.

- [ ] **Step 1: Insert the time budget slide**

Find:

```python
    add_bullet_slide(
        prs,
        "四节课安排",
        [
            "第 1 节：为什么学习汇编，机器语言、汇编语言、C 语言是什么关系。",
            "第 2 节：LoongArch 最小知识包：寄存器、指令、寻址、分支。",
            "第 3 节：从 C 到可执行文件：预处理、编译、汇编、链接、ELF。",
            "第 4 节：读 miniOS 第 1 周代码，在 QEMU 中看到 Hello 输出。",
        ],
        "第一周不追求掌握全部指令，而是建立正确的底层执行模型。",
    )

    add_section_slide(prs, "第 1 节", "为什么学习汇编", "把学生熟悉的 C 语言，连接到 CPU 真正执行的指令。")
```

Replace with:

```python
    add_bullet_slide(
        prs,
        "四节课安排",
        [
            "第 1 节：为什么学习汇编，机器语言、汇编语言、C 语言是什么关系。",
            "第 2 节：LoongArch 最小知识包：寄存器、指令、寻址、分支。",
            "第 3 节：从 C 到可执行文件：预处理、编译、汇编、链接、ELF。",
            "第 4 节：读 miniOS 第 1 周代码，在 QEMU 中看到 Hello 输出。",
        ],
        "第一周不追求掌握全部指令，而是建立正确的底层执行模型。",
    )

    timebox_slide = add_table_slide(
        prs,
        "第 1+2 节时间预算（90 分钟连堂）",
        "每张幻灯片的讲者备注中也标注了建议停留时间。",
        None,
        ["节次", "环节", "时间", "说明"],
        [
            ("第 1 节", "导入问题 + 三层关系", "8 分钟", "C 语言函数为例，引出 C→汇编→机器指令→硬件"),
            ("第 1 节", "为什么选择 LoongArch", "5 分钟", "定位说明，不展开架构历史"),
            ("第 1 节", "C 语言经验类比汇编", "8 分钟", "变量/if/函数调用/指针如何落到底层"),
            ("第 1 节", "真实例子逐行拆解", "12 分钟", "add() 函数编译结果逐行讲解"),
            ("第 1 节", "课堂活动", "12 分钟", "独立思考 5 分钟 + 小组讨论 5 分钟 + 分享 2 分钟"),
            ("第 2 节", "学习目标 + 寄存器表", "10 分钟", "编号优先，再讲 ABI 别名"),
            ("第 2 节", "基础指令例子 + 源码对照", "10 分钟", "r 编号写法与 $ 别名写法对照"),
            ("第 2 节", "寻址方式", "8 分钟", "4 种方式各配真实指令例子"),
            ("第 2 节", "快速匹配活动", "7 分钟", "圈出指令中用到的寄存器角色"),
            ("第 2 节", "练习 + 小测 + 讲评", "10 分钟", "指令分类练习 + 4 题选择题小测"),
        ],
        [1.3, 3.3, 1.35, 5.8],
        "以下每张幻灯片的讲者备注中都标注了本页建议停留时间。",
    )
    set_speaker_notes(timebox_slide, "本页用于开场对齐节奏，教师可据此把控第 1+2 节 90 分钟的整体进度。")

    add_section_slide(prs, "第 1 节", "为什么学习汇编", "把学生熟悉的 C 语言，连接到 CPU 真正执行的指令。")
```

- [ ] **Step 2: Run the generator and verify**

```bash
python scripts/generate_week01_course_ppt.py
python - <<'PY' | tee week01_ppt_dump.txt
from pptx import Presentation
prs = Presentation("docs/week01/week01_qemu_hello_course.pptx")
for i, slide in enumerate(prs.slides):
    for shape in slide.shapes:
        if shape.has_table:
            for row in shape.table.rows:
                print(f"{i}: " + " / ".join(c.text for c in row.cells))
    if slide.has_notes_slide:
        print(f"{i} NOTES: {slide.notes_slide.notes_text_frame.text}")
PY
grep -c "第 1+2 节时间预算" week01_ppt_dump.txt
grep -c "开场对齐节奏" week01_ppt_dump.txt
rm week01_ppt_dump.txt
```

Expected: both counts are `1`.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_week01_course_ppt.py docs/week01/week01_qemu_hello_course.pptx
git commit -m "$(cat <<'EOF'
Add 90-minute time budget slide for week01 lesson 1-2

Gives the teacher an upfront pacing table so the combined 90-minute
session for Lesson 1 and Lesson 2 doesn't run short or overrun.
EOF
)"
```

---

### Task 3: Expand Lesson 1 — "为什么选择 LoongArch", annotated add() example, revised activity

**Files:**
- Modify: `scripts/generate_week01_course_ppt.py` (Lesson 1 block inside `build()`)
- Verify: `docs/week01/week01_qemu_hello_course.pptx` (regenerated)

**Interfaces:**
- Consumes: `add_code_annotated_slide` and `set_speaker_notes` from Task 1.

- [ ] **Step 1: Replace the Lesson 1 block**

Find (this is the entire Lesson 1 slide sequence, from the section slide through the closing activity slide):

```python
    add_section_slide(prs, "第 1 节", "为什么学习汇编", "把学生熟悉的 C 语言，连接到 CPU 真正执行的指令。")
    add_flow_slide(
        prs,
        "从 C 代码到 CPU 执行",
        [
            ("C 语言", "变量\n函数\n循环", COLORS["green"]),
            ("汇编语言", "寄存器\n跳转\n访存", COLORS["blue"]),
            ("机器指令", "二进制编码\nCPU 取指执行", COLORS["orange"]),
            ("硬件行为", "运算\n读写内存\n访问外设", COLORS["teal"]),
        ],
        "汇编课的目标不是背指令，而是看清 C 程序如何落到机器执行。",
        "第 1 节",
    )
    add_bullet_slide(
        prs,
        "用 C 语言经验理解汇编",
        [
            "C 里的变量：很多时候会临时放在寄存器或内存里。",
            "C 里的 if / while：底层会变成比较和跳转指令。",
            "C 里的函数调用：底层涉及参数寄存器、返回地址和栈。",
            "C 里的指针：底层就是地址，访存指令按地址读写数据。",
        ],
        lesson="第 1 节",
    )
    add_bullet_slide(
        prs,
        "第一节课堂活动",
        [
            "让学生写一个最简单的 C 函数：int add(int a, int b)。",
            "提问：CPU 真的认识变量名 a 和 b 吗？",
            "提问：return a + b 最终需要哪些底层动作？",
            "结论：汇编帮助我们建立 C 语言和机器执行之间的桥。",
        ],
        lesson="第 1 节",
    )
```

Replace with:

```python
    add_section_slide(prs, "第 1 节", "为什么学习汇编", "把学生熟悉的 C 语言，连接到 CPU 真正执行的指令。")
    add_flow_slide(
        prs,
        "从 C 代码到 CPU 执行",
        [
            ("C 语言", "变量\n函数\n循环", COLORS["green"]),
            ("汇编语言", "寄存器\n跳转\n访存", COLORS["blue"]),
            ("机器指令", "二进制编码\nCPU 取指执行", COLORS["orange"]),
            ("硬件行为", "运算\n读写内存\n访问外设", COLORS["teal"]),
        ],
        "汇编课的目标不是背指令，而是看清 C 程序如何落到机器执行。",
        "第 1 节",
    )
    why_loongarch_slide = add_bullet_slide(
        prs,
        "为什么选择 LoongArch",
        [
            "LoongArch 是国产自主指令集架构，本课程借此建立本土系统软件平台意识。",
            "课程链路：LoongArch 汇编 → miniOS → Agent Runtime → Agent OS → 龙芯智能体开发。",
            "第一阶段用 QEMU，避开开发板数量、连线、固件问题，先把底层概念学扎实。",
            "x86、ARM、LoongArch 的机器指令不是一套东西——汇编语言和 CPU 架构强绑定。",
        ],
        "了解定位，不展开架构历史和特权级细节。",
        lesson="第 1 节",
    )
    set_speaker_notes(why_loongarch_slide, "时间预算 5 分钟。提醒学生本节不展开架构历史和特权级细节，重点是建立定位。")

    add_bullet_slide(
        prs,
        "用 C 语言经验理解汇编",
        [
            "C 里的变量：很多时候会临时放在寄存器或内存里。",
            "C 里的 if / while：底层会变成比较和跳转指令。",
            "C 里的函数调用：底层涉及参数寄存器、返回地址和栈。",
            "C 里的指针：底层就是地址，访存指令按地址读写数据。",
        ],
        lesson="第 1 节",
    )
    example_slide = add_code_annotated_slide(
        prs,
        "真实例子逐行拆解：add() 函数",
        """int add(int a, int b)
{
    return a + b;
}

# 对应 LoongArch 汇编（-O0，教学示意）
add:
    addi.d  $sp, $sp, -16      # 开辟栈空间
    st.w    $a0, $sp, 12       # 参数 a 存入栈
    st.w    $a1, $sp, 8        # 参数 b 存入栈
    ld.w    $t0, $sp, 12       # 取回 a
    ld.w    $t1, $sp, 8        # 取回 b
    add.w   $a0, $t0, $t1      # 计算 a + b，结果放入返回值寄存器
    addi.d  $sp, $sp, 16       # 释放栈空间
    jirl    $zero, $ra, 0      # 返回调用者""",
        [
            "① $a0、$a1 是参数寄存器，对应 a、b。",
            "② 出现栈上存取是因为 -O0 未优化；优化后可能直接用寄存器完成，不落栈。",
            "③ add.w 是唯一“做加法”的指令，其余都是数据搬运。",
            "④ 返回值放在 $a0。",
            "⑤ jirl $zero, $ra, 0 配合 $ra 完成函数返回。",
            "教学示意汇编，非本机实测编译输出：本机未装 loongarch64-linux-gnu-gcc。",
        ],
        "第一周不要求记住确切编码，只要求理解“参数进、比较或运算、结果出”的结构。",
        "第 1 节",
    )
    set_speaker_notes(
        example_slide,
        "时间预算 12 分钟。强调这只是教学示意，不同优化等级/编译器版本产出会不同。若课堂机器装有"
        "loongarch64-linux-gnu-gcc，建议现场执行 `loongarch64-linux-gnu-gcc -O0 -S -o - add.c` 展示真实输出替换本页。",
    )

    activity_slide = add_bullet_slide(
        prs,
        "第一节课堂活动：徒手推演 max()",
        [
            "任务：int max(int a, int b) { return a > b ? a : b; }",
            "独立思考 5 分钟：不写真实汇编语法，只用文字描述 CPU 需要做哪几步。",
            "小组讨论 5 分钟：两人一组对比思路，讨论“比较”和“选择”在硬件层面可能对应什么动作。",
            "分享 2 分钟：抽 1-2 组口头说明，为第 2 节的分支跳转指令做铺垫。",
        ],
        lesson="第 1 节",
    )
    set_speaker_notes(
        activity_slide,
        "时间预算 12 分钟（5+5+2）。参考答案：取参数（a0/a1）→ 比较（关系比较）→ 条件跳转选择分支 → "
        "结果放入返回值寄存器。提醒教师这里不需要给出真实指令，第 2 节会正式讲分支指令。",
    )
```

- [ ] **Step 2: Run the generator and verify**

```bash
python scripts/generate_week01_course_ppt.py
python - <<'PY' | tee week01_ppt_dump.txt
from pptx import Presentation
prs = Presentation("docs/week01/week01_qemu_hello_course.pptx")
for i, slide in enumerate(prs.slides):
    for shape in slide.shapes:
        if shape.has_text_frame:
            print(f"{i}: {shape.text_frame.text}".replace("\n", " | "))
    if slide.has_notes_slide:
        print(f"{i} NOTES: {slide.notes_slide.notes_text_frame.text}")
PY
grep -c "为什么选择 LoongArch" week01_ppt_dump.txt
grep -c "教学示意汇编，非本机实测编译输出" week01_ppt_dump.txt
grep -c "徒手推演 max" week01_ppt_dump.txt
grep -c "让学生写一个最简单的 C 函数" week01_ppt_dump.txt
rm week01_ppt_dump.txt
```

Expected: first three `grep -c` calls print `1` or more; the last one (the old duplicated activity text) prints `0` — confirming the redundant activity content was replaced, not just appended.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_week01_course_ppt.py docs/week01/week01_qemu_hello_course.pptx
git commit -m "$(cat <<'EOF'
Expand week01 Lesson 1 with LoongArch rationale, worked example, new activity

Surfaces lecture-notes content that was missing from the deck (why
LoongArch), adds a line-by-line annotated compile example, and replaces
the activity slide that duplicated the opening questions with a distinct
max() walkthrough exercise.
EOF
)"
```

---

### Task 4: Expand Lesson 2 — addressing modes, quick-match activity, practice answers, quiz

**Files:**
- Modify: `scripts/generate_week01_course_ppt.py` (Lesson 2 block inside `build()`)
- Verify: `docs/week01/week01_qemu_hello_course.pptx` (regenerated)

**Interfaces:**
- Consumes: `add_table_slide` and `set_speaker_notes` from Task 1.

- [ ] **Step 1: Replace the Lesson 2 block**

Find (entire Lesson 2 slide sequence, from the section slide through the closing practice slide):

```python
    add_section_slide(prs, "第 2 节", "LoongArch 最小知识包", "只讲读懂第 1 周代码需要的寄存器、指令和寻址方式。")
    add_bullet_slide(
        prs,
        "第二节学习目标",
        [
            "知道 LoongArch 指令长度固定为 32 位。",
            "先认识通用寄存器编号 r0~r31，再认识 ABI 别名 zero、ra、sp、a0、t0。",
            "理解三类基础指令：算术运算、访存、转移。",
            "能读懂 boot/start.S 中的主路径。",
        ],
        lesson="第 2 节",
    )
    add_table_slide(
        prs,
        "LoongArch 通用寄存器最小表",
        "第一周先认编号和常用 ABI 别名。",
        "第 2 节",
        ["编号", "ABI 别名", "主要用途", "课堂说明"],
        [
            ("r0", "zero", "常量 0", "硬件恒为 0"),
            ("r1", "ra", "返回地址", "bl 调用函数时写入"),
            ("r3", "sp", "栈指针", "进入 C 前必须设置"),
            ("r4-r11", "a0-a7", "参数寄存器", "函数参数，前两个也可作返回值"),
            ("r12-r20", "t0-t8", "临时寄存器", "短期计算常用"),
            ("r22-r31", "fp/s0-s9", "保存寄存器", "函数调用约定后续展开"),
        ],
        [1.35, 2.1, 2.3, 5.95],
        "讲解顺序：先用 r 编号建立硬件视角，再用 ABI 别名阅读源码。",
    )
    add_code_slide(
        prs,
        "基础指令例子",
        """addi.d  r3, r3, -32       # sp = sp - 32
st.d    r1, r3, 24        # 保存 ra
ld.d    r1, r3, 24        # 恢复 ra
bne     r12, r0, L        # r12 != 0 时跳转
bl      func              # 调用函数，返回地址写入 r1/ra
jirl    r0, r1, 0         # 返回到 ra 指向的位置""",
        "先用 r 编号讲硬件动作，再映射到 ABI 别名。",
        "第 2 节",
    )
    add_code_slide(
        prs,
        "源码写法和教材写法如何对应",
        """# 教材/反汇编常见写法
addi.d  r3, r3, -32
st.d    r1, r3, 24
jirl    r0, r1, 0

# GNU 汇编器也接受 ABI 别名
addi.d  $sp, $sp, -32     # $sp 就是 r3
st.d    $ra, $sp, 24      # $ra 就是 r1
jirl    $zero, $ra, 0     # $zero 就是 r0""",
        "避免学生误以为课件、教材和源码是三套体系。",
        "第 2 节",
    )
    add_bullet_slide(
        prs,
        "第二节练习",
        [
            "先不分类：圈出指令名、寄存器和数字，猜哪一行像改栈、哪一行像跳转。",
            "把 bne r12, r0, L 解释成 C 语言里的 if 条件跳转。",
            "解释 bl 为什么会影响 r1/ra。",
            "解释为什么设置 r3/sp 后才能放心进入 C 函数。",
        ],
        lesson="第 2 节",
    )
```

Replace with:

```python
    add_section_slide(prs, "第 2 节", "LoongArch 最小知识包", "只讲读懂第 1 周代码需要的寄存器、指令和寻址方式。")
    add_bullet_slide(
        prs,
        "第二节学习目标",
        [
            "知道 LoongArch 指令长度固定为 32 位。",
            "先认识通用寄存器编号 r0~r31，再认识 ABI 别名 zero、ra、sp、a0、t0。",
            "理解三类基础指令：算术运算、访存、转移。",
            "能读懂 boot/start.S 中的主路径。",
        ],
        lesson="第 2 节",
    )
    add_table_slide(
        prs,
        "LoongArch 通用寄存器最小表",
        "第一周先认编号和常用 ABI 别名。",
        "第 2 节",
        ["编号", "ABI 别名", "主要用途", "课堂说明"],
        [
            ("r0", "zero", "常量 0", "硬件恒为 0"),
            ("r1", "ra", "返回地址", "bl 调用函数时写入"),
            ("r3", "sp", "栈指针", "进入 C 前必须设置"),
            ("r4-r11", "a0-a7", "参数寄存器", "函数参数，前两个也可作返回值"),
            ("r12-r20", "t0-t8", "临时寄存器", "短期计算常用"),
            ("r22-r31", "fp/s0-s9", "保存寄存器", "函数调用约定后续展开"),
        ],
        [1.35, 2.1, 2.3, 5.95],
        "讲解顺序：先用 r 编号建立硬件视角，再用 ABI 别名阅读源码。",
    )
    add_code_slide(
        prs,
        "基础指令例子",
        """addi.d  r3, r3, -32       # sp = sp - 32
st.d    r1, r3, 24        # 保存 ra
ld.d    r1, r3, 24        # 恢复 ra
bne     r12, r0, L        # r12 != 0 时跳转
bl      func              # 调用函数，返回地址写入 r1/ra
jirl    r0, r1, 0         # 返回到 ra 指向的位置""",
        "先用 r 编号讲硬件动作，再映射到 ABI 别名。",
        "第 2 节",
    )
    add_code_slide(
        prs,
        "源码写法和教材写法如何对应",
        """# 教材/反汇编常见写法
addi.d  r3, r3, -32
st.d    r1, r3, 24
jirl    r0, r1, 0

# GNU 汇编器也接受 ABI 别名
addi.d  $sp, $sp, -32     # $sp 就是 r3
st.d    $ra, $sp, 24      # $ra 就是 r1
jirl    $zero, $ra, 0     # $zero 就是 r0""",
        "避免学生误以为课件、教材和源码是三套体系。",
        "第 2 节",
    )
    addressing_slide = add_table_slide(
        prs,
        "寻址方式",
        "第一周先能看懂启动代码里用到的这几种寻址方式。",
        "第 2 节",
        ["方式", "说明", "真实例子"],
        [
            ("寄存器寻址", "操作数直接在寄存器里", "add.w $a0, $t0, $t1"),
            ("立即数寻址", "常数直接写在指令里", "addi.d $sp, $sp, -16"),
            ("基址加偏移", "一个寄存器给基地址，加偏移访存", "st.w $a0, $sp, 12"),
            ("PC 相对跳转", "跳转目标和当前指令位置有关", "bne $t0, $zero, L1"),
        ],
        [2.3, 5.0, 4.4],
        "不深入编码格式，第一周只要求能看懂启动代码里用到的这几种。",
    )
    set_speaker_notes(addressing_slide, "时间预算 8 分钟。不深入编码格式，第一周只要求能看懂启动代码里用到的这几种。")

    match_slide = add_bullet_slide(
        prs,
        "寄存器/指令快速匹配活动",
        [
            "复用“基础指令例子”里的 6 条指令。",
            "圈出/写出每行里出现的寄存器角色（sp / ra / a0-a7 / t0-t8 / zero）。",
            "判断这条指令属于算术、访存还是跳转。",
            "同桌互查，教师抽查 2-3 条讲评。",
        ],
        lesson="第 2 节",
    )
    set_speaker_notes(
        match_slide,
        "时间预算 7 分钟。参考答案：addi.d→sp，算术；st.d→ra+sp，访存；ld.d→ra+sp，访存；"
        "bne→t0+zero，跳转；bl→隐式写 ra，跳转；jirl→zero+ra，跳转。",
    )

    practice_slide = add_bullet_slide(
        prs,
        "第二节练习",
        [
            "先不分类：圈出指令名、寄存器和数字，猜哪一行像改栈、哪一行像跳转。",
            "把 bne r12, r0, L 解释成 C 语言里的 if 条件跳转。",
            "解释 bl 为什么会影响 r1/ra。",
            "解释为什么设置 r3/sp 后才能放心进入 C 函数。",
        ],
        lesson="第 2 节",
    )
    set_speaker_notes(
        practice_slide,
        "时间预算 6 分钟。参考答案：1) addi.d/st.d/ld.d 类改栈或访存，bne/bl/jirl 类跳转；"
        "2) 相当于 if (r12 != 0) goto L; 3) bl 调用函数时把返回地址写入 r1(ra)；"
        "4) C 函数可能需要栈保存返回地址、局部变量和调用现场，sp 必须先指向有效内存。",
    )

    quiz_slide = add_bullet_slide(
        prs,
        "小测",
        [
            "1. 下面哪条指令是访存指令？ A) addi.d  B) st.d  C) bne  D) bl",
            "2. $ra 对应哪个寄存器编号？ A) r0  B) r1  C) r3  D) r12",
            "3. bl 指令执行后，哪个寄存器的值一定会被改变？ A) $sp  B) $a0  C) $ra  D) $zero",
            "4. 进入 C 函数之前为什么必须先设置好 $sp？（简答，口头回答）",
        ],
        "用于检验第 2 节是否听懂，可现场举手或口头点名回答。",
        lesson="第 2 节",
    )
    set_speaker_notes(
        quiz_slide,
        "时间预算 4 分钟。答案：1) B  2) B  3) C  4) 参考“第二节练习”第 4 题答案——C 函数可能需要栈"
        "保存返回地址、局部变量和调用现场，sp 必须先指向有效内存。",
    )
```

- [ ] **Step 2: Run the generator and verify**

```bash
python scripts/generate_week01_course_ppt.py
python - <<'PY' | tee week01_ppt_dump.txt
from pptx import Presentation
prs = Presentation("docs/week01/week01_qemu_hello_course.pptx")
for i, slide in enumerate(prs.slides):
    for shape in slide.shapes:
        if shape.has_text_frame:
            print(f"{i}: {shape.text_frame.text}".replace("\n", " | "))
        if shape.has_table:
            for row in shape.table.rows:
                print(f"{i}: " + " / ".join(c.text for c in row.cells))
    if slide.has_notes_slide:
        print(f"{i} NOTES: {slide.notes_slide.notes_text_frame.text}")
print(f"slides={len(prs.slides)}")
PY
grep -c "寻址方式" week01_ppt_dump.txt
grep -c "快速匹配活动" week01_ppt_dump.txt
grep -c "^.*: 小测" week01_ppt_dump.txt
rm week01_ppt_dump.txt
```

Expected: all three counts are `1` or more.

- [ ] **Step 3: Commit**

```bash
git add scripts/generate_week01_course_ppt.py docs/week01/week01_qemu_hello_course.pptx
git commit -m "$(cat <<'EOF'
Expand week01 Lesson 2 with addressing modes, matching activity, and quiz

Surfaces lecture-notes content missing from the deck (addressing modes),
adds a register/instruction matching activity, and adds a 4-question
comprehension check with answers in the speaker notes.
EOF
)"
```

---

### Task 5: Sync lecture notes with the new PPT content

**Files:**
- Modify: `docs/week01/week01_qemu_hello_lecture_notes.md`
- Verify: same file (grep checks)

**Interfaces:**
- None (Markdown-only change, no code interfaces).

- [ ] **Step 1: Add the 90-minute pacing note at the start of Section 4**

Find:

```markdown
## 4. 第 1 节：为什么学习汇编

### 4.1 导入问题
```

Replace with:

```markdown
## 4. 第 1 节：为什么学习汇编

> 本次课时长 90 分钟，覆盖第 1 节和第 2 节，时间预算见 PPT 对应幻灯片（时间预算表）与各页讲者备注。

### 4.1 导入问题
```

- [ ] **Step 2: Add sections 4.4 and 4.5 after 4.3, before Section 5**

Find:

```markdown
不要在第一周展开架构历史或复杂特权级细节。只需让学生知道：汇编语言和 CPU 架构绑定，x86、ARM、LoongArch 的机器指令不是一套东西。

## 5. 第 2 节：LoongArch 最小知识包
```

Replace with:

````markdown
不要在第一周展开架构历史或复杂特权级细节。只需让学生知道：汇编语言和 CPU 架构绑定，x86、ARM、LoongArch 的机器指令不是一套东西。

### 4.4 课堂活动：徒手推演 max() 执行步骤

给出函数：

```c
int max(int a, int b)
{
    return a > b ? a : b;
}
```

活动步骤：

1. 独立思考（5 分钟）：不要求写真实汇编语法，只用文字或伪步骤描述 CPU 需要做哪几步，例如"取参数 -> 比较 -> 按结果选值 -> 把结果放到某个位置返回"。
2. 小组讨论（5 分钟）：两人一组对比思路，重点讨论"比较"和"选择"在硬件层面可能对应什么动作，为第 2 节的分支跳转指令做铺垫。
3. 分享（2 分钟）：抽 1-2 组口头说明。

参考答案要点：

- 取参数：a、b 通过参数寄存器传入。
- 比较：需要一条"比较"动作，判断 a 是否大于 b。
- 选择：根据比较结果走不同分支，这就是第 2 节要学的条件跳转指令。
- 返回：把选中的值放入返回值寄存器，再跳回调用者。

提醒学生：这里不需要给出真实指令，第 2 节会正式讲分支指令，本活动的目的是先建立"比较之后要跳转"的直觉。

### 4.5 真实例子逐行拆解

以 `docs/week01/week01_qemu_hello_course.pptx` 中"真实例子逐行拆解"一页配合讲解：

```c
int add(int a, int b)
{
    return a + b;
}
```

```asm
# 对应 LoongArch 汇编（-O0，教学示意）
add:
    addi.d  $sp, $sp, -16      # 开辟栈空间
    st.w    $a0, $sp, 12       # 参数 a 存入栈
    st.w    $a1, $sp, 8        # 参数 b 存入栈
    ld.w    $t0, $sp, 12       # 取回 a
    ld.w    $t1, $sp, 8        # 取回 b
    add.w   $a0, $t0, $t1      # 计算 a + b，结果放入返回值寄存器
    addi.d  $sp, $sp, 16       # 释放栈空间
    jirl    $zero, $ra, 0      # 返回调用者
```

必须向学生说明：这是教学示意汇编，不是本机实测编译输出——当前 Windows 主机没有安装 `loongarch64-linux-gnu-gcc`，无法现场编译验证。不同编译器版本、不同优化等级产出会不同，第一周不要求学生记住确切编码，只要求理解"参数进、比较或运算、结果出"这类结构。

如果课堂机器已安装工具链，建议现场执行并用真实输出替换本页：

```bash
loongarch64-linux-gnu-gcc -O0 -S -o - add.c
```

逐行讲解要点：

- `$a0`、`$a1` 是参数寄存器，对应 a、b。
- 出现栈上存取是因为 `-O0` 未优化；真实项目里编译器优化后可能直接用寄存器完成，不落栈。
- `add.w` 是唯一"做加法"的指令，其余都是数据搬运。
- 返回值放在 `$a0`。
- `jirl $zero, $ra, 0` 配合 `$ra` 完成函数返回。

## 5. 第 2 节：LoongArch 最小知识包
````

- [ ] **Step 3: Add sections 5.5, 5.6, 5.7 after 5.4, before Section 6**

Find:

```markdown
不要在第一周讲太多编码格式。第一周先让学生能读懂启动代码。

## 6. 第 3 节：从 C 到 ELF
```

Replace with:

````markdown
不要在第一周讲太多编码格式。第一周先让学生能读懂启动代码。

### 5.5 寄存器/指令快速匹配活动

给出以下 6 条指令（与"基础指令例子"幻灯片一致）：

```asm
addi.d  r3, r3, -32       # sp = sp - 32
st.d    r1, r3, 24        # 保存 ra
ld.d    r1, r3, 24        # 恢复 ra
bne     r12, r0, L        # r12 != 0 时跳转
bl      func              # 调用函数，返回地址写入 r1/ra
jirl    r0, r1, 0         # 返回到 ra 指向的位置
```

要求学生圈出/写出每行里出现的寄存器角色（sp / ra / a0-a7 / t0-t8 / zero），并判断这条指令属于算术、访存还是跳转。

参考答案：

| 指令 | 用到的寄存器角色 | 类型 |
|---|---|---|
| `addi.d r3, r3, -32` | sp | 算术 |
| `st.d r1, r3, 24` | ra、sp | 访存 |
| `ld.d r1, r3, 24` | ra、sp | 访存 |
| `bne r12, r0, L` | t0（此处用 r12 举例）、zero | 跳转 |
| `bl func` | 隐式写 ra | 跳转 |
| `jirl r0, r1, 0` | zero、ra | 跳转 |

时间预算：7 分钟。

### 5.6 巩固练习与参考答案

配合"第二节练习"幻灯片，练习题与参考答案：

1. 先不分类：圈出指令名、寄存器和数字，猜哪一行像改栈、哪一行像跳转。
   参考答案：`addi.d`/`st.d`/`ld.d` 类改栈或访存；`bne`/`bl`/`jirl` 类跳转。
2. 把 `bne r12, r0, L` 解释成 C 语言里的 if 条件跳转。
   参考答案：相当于 `if (r12 != 0) goto L;`。
3. 解释 `bl` 为什么会影响 `r1`/`ra`。
   参考答案：`bl` 调用函数时会把返回地址写入 `r1`（`ra`），供函数返回时使用。
4. 解释为什么设置 `r3`/`sp` 后才能放心进入 C 函数。
   参考答案：C 函数可能需要用栈保存返回地址、局部变量和调用现场，`sp` 必须先指向有效内存。

时间预算：6 分钟。

### 5.7 小测参考答案

配合"小测"幻灯片：

1. 下面哪条指令是访存指令？ A) `addi.d` B) `st.d` C) `bne` D) `bl` —— 答案 B。
2. `$ra` 对应哪个寄存器编号？ A) r0 B) r1 C) r3 D) r12 —— 答案 B。
3. `bl` 指令执行后，哪个寄存器的值一定会被改变？ A) `$sp` B) `$a0` C) `$ra` D) `$zero` —— 答案 C。
4. 进入 C 函数之前为什么必须先设置好 `$sp`？（简答，口头回答）—— 参考 5.6 第 4 题答案。

时间预算：4 分钟。

## 6. 第 3 节：从 C 到 ELF
````

- [ ] **Step 4: Verify the new sections landed**

```bash
grep -c "本次课时长 90 分钟" docs/week01/week01_qemu_hello_lecture_notes.md
grep -c "### 4.4 课堂活动：徒手推演 max" docs/week01/week01_qemu_hello_lecture_notes.md
grep -c "### 4.5 真实例子逐行拆解" docs/week01/week01_qemu_hello_lecture_notes.md
grep -c "### 5.5 寄存器/指令快速匹配活动" docs/week01/week01_qemu_hello_lecture_notes.md
grep -c "### 5.6 巩固练习与参考答案" docs/week01/week01_qemu_hello_lecture_notes.md
grep -c "### 5.7 小测参考答案" docs/week01/week01_qemu_hello_lecture_notes.md
```

Expected: every command prints `1`.

- [ ] **Step 5: Commit**

```bash
git add docs/week01/week01_qemu_hello_lecture_notes.md
git commit -m "$(cat <<'EOF'
Sync week01 lecture notes with expanded Lesson 1-2 PPT content

Adds the activity, worked example, addressing-mode, and quiz sections
that now exist in the deck, plus their timing and reference answers, so
the teacher script matches what's on screen.
EOF
)"
```

---

### Task 6: Final full-deck verification

**Files:**
- Verify: `docs/week01/week01_qemu_hello_course.pptx`
- Verify: `docs/week01/week01_qemu_hello_lecture_notes.md`

**Interfaces:**
- None — this is an end-to-end check across the outputs of Tasks 1-5.

- [ ] **Step 1: Regenerate from a clean state and confirm the final slide count**

```bash
python scripts/generate_week01_course_ppt.py
```

Expected: prints `docs/week01/week01_qemu_hello_course.pptx` (via the corrected `OUT` path) and `slides=` followed by the total slide count for the whole deck (Lesson 1+2 should now contribute about 18-19 slides, up from the original 10).

- [ ] **Step 2: Confirm required strings and absence of stale duplicated text**

```bash
python - <<'PY' | tee week01_ppt_dump.txt
from pptx import Presentation
prs = Presentation("docs/week01/week01_qemu_hello_course.pptx")
for i, slide in enumerate(prs.slides):
    for shape in slide.shapes:
        if shape.has_text_frame:
            print(f"{i}: {shape.text_frame.text}".replace("\n", " | "))
        if shape.has_table:
            for row in shape.table.rows:
                print(f"{i}: " + " / ".join(c.text for c in row.cells))
    if slide.has_notes_slide:
        print(f"{i} NOTES: {slide.notes_slide.notes_text_frame.text}")
PY
for needle in "Hello miniOS on LoongArch64" "为什么选择 LoongArch" "教学示意汇编" "寻址方式" "快速匹配活动" "小测" "第 1+2 节时间预算"; do
  count=$(grep -c "$needle" week01_ppt_dump.txt)
  echo "$needle -> $count"
done
grep -c "让学生写一个最简单的 C 函数" week01_ppt_dump.txt
rm week01_ppt_dump.txt
```

Expected: every needle in the loop reports a count of `1` or more; the final stale-text check reports `0`.

- [ ] **Step 3: Confirm git status shows only the expected files changed**

```bash
git status --short
```

Expected: no unexpected files beyond `scripts/generate_week01_course_ppt.py`, `docs/week01/week01_qemu_hello_course.pptx`, and `docs/week01/week01_qemu_hello_lecture_notes.md` (all already committed by Tasks 1-5, so this should be clean unless something was missed).

- [ ] **Step 4: If Step 3 finds uncommitted changes, commit them**

```bash
git add -A -- scripts/generate_week01_course_ppt.py docs/week01/week01_qemu_hello_course.pptx docs/week01/week01_qemu_hello_lecture_notes.md
git commit -m "$(cat <<'EOF'
Finalize week01 Lesson 1-2 expansion

Closing commit after end-to-end verification of the expanded deck and
lecture notes.
EOF
)"
```
