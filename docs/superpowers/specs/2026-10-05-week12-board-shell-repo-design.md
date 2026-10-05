# 第 12 次课重构：独立出板级迁移 + shell 仓库，重写 lab.md

## 背景与动机

第 12 次课（板级迁移）目前的真实实现只存在于 `teacher-2k0300-notes` 分支
（本地 worktree：`miniOS-teacher-ref`），该分支是完整 134-commit 的 miniOS
主仓库，不便直接交给学生——其 `docs/12/manual_board_bringup_2k0300.md`
记录了完整的教师调试过程（`.got`/`clear_bss` bug、真机异常向量问题排查、
echo bug 的 GDB 走忸答案），这些内容一旦随 git 历史交给学生就等于剧透。

主仓库 `master` 上的 `docs/12/board_2k0300_setup.md` 是一份 719 行的单体
走忸文档，没有按 week05+ 建立的"lab.md = Task 结构"惯例组织，且覆盖范围
（接线→装驱动→平台拆分→真机烧录→shell 全部内容）塞进同一份文档，没有
按"第 12 次课是 4 学时连排"的惯例拆成两个教学单元。

本次重构目标：

1. 把板级迁移 + shell 的完整实现（代码 + 教学文档）从 `teacher-2k0300-notes`
   分支独立成一个全新、干净历史的仓库，交给学生使用。
2. 课时结构改为两个教学单元：第 1-2 节板级迁移，第 3-4 节命令行 shell
   （与 week11 `lab_v2.md` 按"单元"组织 Task 的风格一致）。
3. 重写 `lab.md`，取代原来的 `board_2k0300_setup.md`。
4. 主仓库 `docs/12` 简化为指向新仓库的说明，不再承载完整走忸内容。

## 范围（In Scope）

- 在 `D:\工作\日常教学\2026-2027第一学期\汇编语言\miniOS-board-shell`
  新建一个本地仓库（全新 git 历史，不保留 `teacher-2k0300-notes` 的调试
  过程提交历史）。
- 新仓库内容 = 完整 week01-11 代码快照（对齐当前 `11-irq-kernel-recap`
  状态）+ 板级迁移基础设施 + shell 全套实现，**但删掉第 3-8 次课的演示
  代码**（见下）。
- 新仓库根目录新增 `lab.md`（本次设计的核心产出），取代
  `board_2k0300_setup.md` 的角色。
- 新仓库 README 精简为独立仓库的快速上手说明。
- 主仓库 `docs/12/board_2k0300_setup.md` 改写为简短指引，链接到新仓库。

## 不在范围内（Out of Scope，本次不做）

- 不 push 新仓库到 GitHub/Gitee（先在本地定稿，push 时机由用户自行决定）。
- 不修改 `teacher-2k0300-notes` 分支本身（它继续作为教师调试记录保留）。
- 不处理 `12-board-agent-demo` tag 的历史语义（只改 `docs/12` 文字说明，
  tag 本身保留作历史标记，不再是第 12 次课的真正入口）。
- `manual_board_bringup_2k0300.md` 的调试叙事、`.pptx`、测试报告 `.md`、
  `~$...` 临时锁文件——均不带入新仓库。

## 新仓库结构

```
miniOS-board-shell/
├── boot/start.S
├── kernel/
│   ├── main.c              # 精简后：week01-02 + exception_init + shell 循环
│   ├── printk.c
│   ├── exception.c         # 第9次课，shell crash 命令依赖
│   ├── irq.c                # 第11次课，shell timer/demo 命令依赖
│   ├── kmalloc.c             # 第12次课新增
│   ├── linker_qemu_virt.ld
│   └── linker_2k0300.ld
├── lib/
│   ├── string.S              # 保留（memset/memcpy/strlen/strcmp/
│   │                          # split_command/strncmp 等被 shell 或
│   │                          # kmalloc 依赖）
│   └── shell_cmds.S          # cmd_echo/cmd_help
├── include/
│   ├── printk.h / uart.h / string.h / types.h
│   ├── exception.h / irq.h / kmalloc.h
│   └── platform/{qemu_virt.h,2k0300.h}
├── Makefile
├── README.md                 # 独立仓库快速上手
├── lab.md                    # 本次核心产出
└── scripts/（环境检查脚本，按需保留）
```

**删除**（第 3-8 次课纯演示代码，shell 不依赖）：
`lib/regs_alu.S`、`lib/mem_fp.S`、`lib/branch_loop.S`、`lib/stack_abi.S`、
`kernel/syscall.c`、`include/regs_alu.h`、`include/mem_fp.h`、
`include/branch_loop.h`、`include/stack_abi.h`、`include/syscall.h`，
以及 `kernel_main` 里对应的验收代码段。

**保留**：week01-02（Hello/data/bss）、第9次课 `exception_init`、第11次课
`irq.c`/`timer_init`/`ksleep`/`strncmp`（含启动时自动跑的 `strncmp` 自测）
——这些是 shell `crash`/`timer`/`demo` 命令的运行时依赖，不能删。

## `lab.md` 大纲

```
# 第 12 次课实验指导书：板级迁移 + 命令行 shell

## 本课主线

## 0. 实验环境与准备（照做）
  0.1 需要准备的资料/软件
  0.2 接线与上电
  0.3 Windows 识别开发板、装串口驱动
  0.4 打开串口终端，验证连通

## 单元一：板级迁移（第 1-2 节）

### Task 1：把仓库改成"平台可插拔"结构（写代码）
  - 拆分链接脚本（qemu_virt / 2k0300 两份）
  - 拆分 UART 平台头文件（include/platform/）
  - uart.h 按 PLATFORM 宏切换
  - printk.c 补轮询 + 平台初始化钩子
  - Makefile 加 PLATFORM 开关

### Task 2：QEMU 回归测试
  - make PLATFORM=qemu_virt run，确认 week01-11 输出逐字节不变

### Task 3：编译 2K0300 版本，送上真机，跳转执行（真机验收）
  - make PLATFORM=2k0300
  - loady 传输 minios.bin
  - go 跳转，核对串口输出（week01-08 内容）

### 单元一阶段验收

## 过渡：精简代码库，为 shell 让路（照做，不计入 Task 编号）
  - 删 kernel_main 里 week03-08 的验收代码段
  - 删 lib/regs_alu.S、mem_fp.S、branch_loop.S、stack_abi.S
  - 删 kernel/syscall.c、include/{regs_alu,mem_fp,branch_loop,stack_abi,syscall}.h
  - 验收：make 干净编译通过，QEMU 跑到 week11-strncmp check done 后
    直接进 shell，没有 week03-08 的输出

## 单元二：命令行 shell（第 3-4 节）

### Task 4：最小内核堆分配器 kmalloc（写代码）

### Task 5：异常分类（写代码）
  - ECODE_ADE/ALE/SYS/BRK/INE 等常量
  - crash 命令：sys/brk/ine/ale/ade 五个子类型

### Task 6：uart_getc + 命令行循环框架（写代码）
  - shell_read_line / shell_dispatch
  - 基础命令：help / echo / meminfo

### Task 7：把 echo 的动作函数改成汇编（写代码 + 调试）
  - cmd_echo，含"第一次尝试 → 用 GDB 定位 → 修正"的完整 debug 过程

### Task 8：把 help 也改成汇编（写代码）
  - cmd_help，尾调用（b 而不是 bl）

### Task 9：把 shell 挪到真机安全触发位置（写代码）
  - 把 break（week09）、timer（week11）从"自动触发"改成 shell 命令
  - 新增 timer 命令

### Task 10（选做——真机已知边界，只建议 QEMU 验证）：
  demo 命令：串联 week11 的 strncmp 自测 / ksleep / break

### 单元二阶段验收

## 验收标准
## 提交清单
## AI 共学边界
## 常见故障速查
## 思考题
```

真机已知边界（timer/crash/demo 在真机上可能卡死或复位）写成"预期现象"
提示（"这是已知边界，不代表你代码写错了"），**不展开**
`manual_board_bringup_2k0300.md` §5.2/§5.6 式的具体排查过程——按
[[feedback_teacher_answer_branching]] 的原则，调试过程本身不下发给学生。

## 风险/待确认事项

- "精简代码库"这一步删除 `kernel_main` 里大段代码，需要先确认
  `print_u64_dec`/`print_u64_hex`/`print_i64_dec`/`print_char` 等辅助
  打印函数是否被保留部分（`shell_meminfo`/`crash_ale` 等）引用，不能
  连带删除——留给实施阶段用编译器报错/链接报错验证，不是设计阶段能
  静态穷举完的细节。
- `lab.md` 的具体措辞、验收标准细节、是否需要"关键函数/CSR速查"附录，
  留给实施阶段按 week11 `lab_v2.md` 的行文风格现场撰写，不在本设计文档
  里预先写死全文。
