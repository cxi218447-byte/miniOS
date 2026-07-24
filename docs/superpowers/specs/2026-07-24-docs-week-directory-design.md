# Docs Week Directory Reorganization Design

## Goal

Organize generated course documents under `docs/` by teaching week so Week 01, Week 02, and later materials do not mix in the top-level `docs/` directory.

## Scope

Move course-facing weekly materials into week subdirectories:

- `docs/week01_qemu_hello.md` -> `docs/week01/qemu_hello.md`
- `docs/week01_slide15_build_pipeline_animation/` -> `docs/week01/slide15_build_pipeline_animation/`
- `docs/week02_data_bss.md` -> `docs/week02/data_bss.md`

Keep cross-week and project-level documents at the top level:

- `docs/course_release_index.md`
- `docs/environment_check.md`
- `docs/manual_wsl_ubuntu_install.md`
- `docs/QEMU-to-Loongson-Pioneer-Porting-Guide.md`
- `docs/superpowers/`

## Link Updates

Update references in course-facing files so links keep working after the move:

- `README.md`
- `docs/course_release_index.md`
- `docs/week01/qemu_hello.md`
- any moved Week 01 animation files if they contain relative links to moved assets

`docs/superpowers/` plans and specs are process history. They may mention old paths and should not be rewritten unless they are actively used as current user-facing documentation.

## Directory Layout

Expected layout after the change:

```text
docs/
  course_release_index.md
  environment_check.md
  manual_wsl_ubuntu_install.md
  QEMU-to-Loongson-Pioneer-Porting-Guide.md
  week01/
    qemu_hello.md
    slide15_build_pipeline_animation/
      index.html
      styles.css
      app.js
      verify-content.js
  week02/
    data_bss.md
  superpowers/
```

## Constraints

- Do not move `docs/superpowers/`.
- Do not change code or generated build outputs.
- Preserve Week 01 and Week 02 document content except for relative path fixes.
- Do not touch unrelated dirty workspace files.

## Verification

After implementation:

- `Test-Path docs/week01/qemu_hello.md` is true.
- `Test-Path docs/week01/slide15_build_pipeline_animation/index.html` is true.
- `Test-Path docs/week02/data_bss.md` is true.
- `README.md` links point to the new week paths.
- `docs/course_release_index.md` links point to the new week paths.
- No course-facing references remain to `docs/week01_qemu_hello.md`, `docs/week02_data_bss.md`, or `docs/week01_slide15_build_pipeline_animation/`.
