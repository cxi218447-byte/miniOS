# Week 01 Lecture Notes Design

## Goal

Create a complete teacher-facing lecture note for Week 01 of the LoongArch miniOS course.

## Output

- `docs/week01_qemu_hello_lecture_notes.md`

## Audience

The note is for the teacher, not only for students. It should provide enough explanation, classroom prompts, demo flow, and expected student misunderstandings so the PPT can be used as a teaching outline rather than the only source of detail.

## Structure

The lecture note follows the Week 01 four-lesson PPT:

1. Why learn assembly.
2. LoongArch minimum knowledge package.
3. From C to ELF.
4. QEMU Hello miniOS experiment.

It also includes:

- Course positioning.
- Demo script.
- Student lab tasks.
- AI co-learning boundary.
- Common questions and teaching responses.
- Suggested blackboard notes.
- Thinking questions with reference answers.

## Boundaries

- Week 01 focuses on `CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS`.
- Expected output is exactly `Hello miniOS on LoongArch64`.
- `.data/.bss`, `clear_bss`, `memset`, `memcpy`, and `strlen` are only mentioned as Week 02 preview or current-master context.
- AI co-learning is explanation-only in Week 01 and must not generate lab code.
- Do not claim build or QEMU verification passed unless actually executed.
