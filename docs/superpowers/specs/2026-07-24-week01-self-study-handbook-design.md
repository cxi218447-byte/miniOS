# Week 01 Self-Study Handbook Design

## Goal

Upgrade `docs/week01_qemu_hello.md` from a concise experiment note into a student-facing self-study handbook for Week 01: QEMU Hello miniOS.

The handbook must let a student independently prepare the environment, understand the project structure, build and run miniOS in QEMU, read the first startup path, record real results, and answer the Week 01 thinking questions.

## Scope

The update stays within the Week 01 learning boundary:

- Focus on `CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS`.
- Require reading and understanding existing code.
- Do not ask students to generate or rewrite experiment code.
- Mention that current `master` may include Week 02 `.data/.bss` output, but exclude it from Week 01 acceptance.
- Keep QEMU as the required validation platform before any board migration.

Out of scope:

- Full 2K0300 board bring-up.
- Week 02 memory initialization as a required task.
- Exception, interrupt, syscall, or user-mode experiments.
- AI-generated replacement code.

## Recommended Approach

Expand the existing `docs/week01_qemu_hello.md` instead of creating a second student handbook.

Reasons:

- Existing links in `README.md` and `docs/course_release_index.md` already point to this file.
- One canonical Week 01 handout reduces maintenance drift.
- First-week students should not have to choose between a short task sheet and a complete manual.

## Proposed Structure

The upgraded document should use this section order:

1. Experiment position and learning outcomes.
2. Before you start.
3. Project directory tour.
4. Environment check.
5. Build miniOS.
6. Run miniOS in QEMU.
7. Exit QEMU.
8. Understand the startup path.
9. Read `boot/start.S`.
10. Read `kernel/main.c`.
11. Read `printk` and UART output.
12. Useful commands: `make`, `make run`, `objdump`, `make debug`.
13. Common errors and fixes.
14. Acceptance criteria.
15. Experiment report template.
16. AI co-learning rules.
17. Thinking questions and optional reading.

## Content Requirements

The handbook should be concrete and executable:

- Show exact commands in shell blocks.
- Tell students what successful output looks like.
- Tell students what to record when a command fails.
- Include common failure patterns for missing `make`, missing `qemu-system-loongarch64`, missing `loongarch64-linux-gnu-gcc`, QEMU not exiting, and confusing Week 02 output.
- Include a report template with fields for environment, commands, real output, source reading notes, errors, AI usage, and thinking-question answers.
- Preserve the expected Week 01 output exactly:

```text
Hello miniOS on LoongArch64
```

## Quality Bar

The final document should be readable as a standalone self-study handout:

- A new student can follow it from clone/check-env through QEMU output.
- It clearly distinguishes "must complete" from "optional understanding".
- It does not over-teach later weeks.
- It uses simple Chinese wording suitable for first-week assembly-language students.
- It keeps the AI boundary explicit: AI may explain code and draw flowcharts, but may not directly generate the experiment code.

## Verification

After editing the handbook, verify by checking that the document contains:

- `Hello miniOS on LoongArch64`
- `boot/start.S`
- `kernel_main`
- `printk`
- `UART`
- `sh scripts/check-env.sh`
- `make clean`
- `make`
- `make run`
- `objdump`
- `make debug`
- `实验报告模板`
- `不允许让 AI 直接生成实验代码`

Also review the file manually for section order, Week 01 scope, and absence of contradictory acceptance requirements.
