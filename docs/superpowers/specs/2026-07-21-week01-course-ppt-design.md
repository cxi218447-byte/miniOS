# Week 01 Course PPT Design

## Goal

Create a clean, maintainable Week 01 course PPT for the LoongArch miniOS course, based on the latest `AGENTS.md` and `docs/week01_qemu_hello.md`.

## Output

- New PPT: `docs/week01_qemu_hello_course.pptx`
- New generator: `scripts/generate_week01_course_ppt.py`

The existing `docs/week01_qemu_hello_4lessons_v4.pptx` remains untouched except for pre-existing workspace edits.

## Course Structure

The PPT is a 4-lesson classroom deck:

1. Why learn assembly: connect C language knowledge to CPU execution.
2. LoongArch minimum knowledge: registers, ABI names, basic instructions, addressing, branches.
3. From C to ELF: compilation, assembly, linking, linker script, QEMU loading.
4. miniOS Hello experiment: `_start`, stack setup, `kernel_main`, `printk`, UART, QEMU run, expected output.

## Teaching Boundaries

- Week 01 focuses on the minimal route: `CPU -> boot/start.S -> kernel_main() -> printk() -> UART -> Hello miniOS`.
- Expected Week 01 output is exactly `Hello miniOS on LoongArch64`.
- `.data/.bss`, `clear_bss`, `memset`, `memcpy`, and `strlen` are mentioned only as Week 02 preview or current-master context.
- AI co-learning in Week 01 is explanation-only: source explanation, flow diagrams, QEMU explanation. It must not generate lab code for students.

## Style

Use a restrained classroom style:

- White or light background.
- Clear Chinese headings.
- Short bullet lists.
- Code slides use dark code blocks with readable monospace text.
- Avoid decorative visuals that distract from code and execution flow.

## Verification

After generation:

- Confirm the PPT file exists and is non-empty.
- Extract PPT slide text and check for the required output string.
- Check that stale strings `Hello, LoongArch miniOS` and `miniOS booting` do not appear in the new PPT.
