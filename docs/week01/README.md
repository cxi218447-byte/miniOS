# 第 1 次课资料索引

主题：QEMU Hello miniOS

课次说明：本课程按“2 节课 = 1 次课”组织。第 1 次课对应课程第 1-2 节；如果实际排课一周 4 节课，则同一行政周的第 3-4 节通常进入课程第 2 次课。

## 学生实验

- [实验指导手册](qemu_hello.md)

## 课堂资料

- [课堂讲义](week01_qemu_hello_lecture_notes.md)
- [课程 PPT](week01_qemu_hello_course.pptx)
- [课堂进度检查点分支说明](branch_checkpoints.md)

## 课堂动画

- [Slide 8：C 到 CPU 执行路径动画](week01_slide8_c_to_cpu_animation/index.html)
- [Slide 15：编译流水线动画](slide15_build_pipeline_animation/index.html)
- [一场接力赛：裸机启动动画](relay_race_boot_animation/index.html)

## 本次课验收输出

```text
Hello miniOS on LoongArch64
```

第 1 次课只验收 Hello 输出链路。当前 `master` 可能已经包含第 2 次课 `.data/.bss` 检查输出，学生应按本次课 tag `week01-qemu-hello` 获取第 1 次课最终版本。
