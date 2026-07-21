# Week 01-02 Alignment Design

## Goal

Align the current miniOS repository with the latest course-focused `AGENTS.md` rules for the first two weeks of the LoongArch assembly course.

The current `master` workspace will represent a combined Week 01-02 verification version:

- Week 01 remains the minimal QEMU Hello miniOS teaching path.
- Week 02 adds `.data`, `.bss`, `clear_bss`, and C/assembly memory helpers.

## Scope

Update only the first two weeks' code and teaching documents:

- `kernel/main.c`
- `README.md`
- `docs/week01_qemu_hello.md`
- `docs/week02_data_bss.md`
- `docs/course_release_index.md`

Existing PPT and AGENTS changes are treated as pre-existing workspace changes and are not part of this design commit.

## Behavior

The runtime output for the combined Week 01-02 verification path should be:

```text
Hello miniOS on LoongArch64
data section ok
bss section cleared
week1-week2 check done
```

The extra boot banner `miniOS booting...` should be removed from `kernel/main.c` so code, README, docs, and `AGENTS.md` share the same Week 01 Hello string.

## Documentation

`docs/week01_qemu_hello.md` will focus on:

- The startup route from `_start` to UART output.
- Why the first instruction is not `main()`.
- Why stack setup is required before entering C.
- Why bare-metal code uses `printk()` instead of `printf()`.
- The rule that Week 01 AI usage is explanation-only and must not generate lab code.

`docs/week02_data_bss.md` will focus on:

- `.data` and `.bss` roles.
- Why `.bss` must be cleared before C code reads uninitialized globals.
- How `memset`, `memcpy`, and `strlen` introduce C/assembly mixed compilation.
- The expected combined Week 01-02 output.

`README.md` will state that the current branch contains Week 01-02 combined verification, while teaching should still explain the Week 01 minimal path before Week 02 additions.

`docs/course_release_index.md` will keep statuses conservative unless commands are actually run in the current environment.

## Verification

Run static checks after editing:

- Search for old output text: `Hello, LoongArch miniOS` and `miniOS booting`.
- Search for the aligned output text: `Hello miniOS on LoongArch64`.

If the local LoongArch toolchain or QEMU is unavailable, do not mark build or run verification as passed.
