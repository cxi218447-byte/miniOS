# AGENTS.md

## 1. 项目定位

本项目用于建设《LoongArch 汇编与 miniOS 实验》课程实验线。

核心路线：

```text
PC / WSL Ubuntu
    ↓
LoongArch64 交叉编译
    ↓
QEMU virt 仿真运行
    ↓
miniOS 内核雏形
    ↓
龙芯 2K0300 先锋板移植验证
```

项目目标不是开发完整操作系统，而是为教学服务，形成一套“能编译、能运行、能讲解、能迁移到板子”的 LoongArch 汇编实验体系。

---

## 2. 总体原则

1. 所有实验必须先在 QEMU 中跑通，再考虑龙芯 2K0300 先锋板。
2. 不允许一开始直接依赖真实开发板。
3. 不允许只写文档不验证代码。
4. 不允许一次性堆叠复杂功能。
5. 每次修改必须保持项目可编译。
6. 每个阶段必须提供：

   * 实验目标
   * 核心代码
   * 编译命令
   * 运行命令
   * 预期输出
   * 实际测试结果
   * 常见错误与排查方法
7. 代码必须适合大二学生阅读，优先清晰，不追求炫技。
8. 所有关键代码必须添加中文注释。
9. 不要引入复杂依赖，优先使用 Makefile、GCC、binutils、QEMU。
10. 任何失败都要先定位原因，不允许跳过失败继续开发后续内容。

### 2.1 反幻觉与实测口径

1. 未在当前机器执行过的命令，不得写成“已通过”。
2. 未确认的硬件地址、寄存器位、启动地址，必须标注“待查证”或“待实测确认”。
3. QEMU 版本号、GCC 版本号、GDB 版本号必须来自实际命令输出：

   ```bash
   qemu-system-loongarch64 --version
   loongarch64-linux-gnu-gcc --version
   gdb-multiarch --version
   ```

4. 如果本机缺少工具链，只能给出安装命令和预期验证步骤，不能伪造编译结果。
5. QEMU 输出必须来自真实 `make run` 或等价 QEMU 命令，不能根据代码推断后写成实测输出。
6. QEMU 版本和龙芯 2K0300 先锋板版本必须分开描述，不能把 QEMU 设备地址直接当作开发板地址。
7. 发现资料不确定时，应写“假设”“待验证”或“需查阅板卡手册”，不得补全不存在的细节。
8. 更新测试报告时必须区分：

   * 已执行；
   * 未执行；
   * 失败原因；
   * 下一步命令。

示例：

```text
已执行：git init。
未执行：make run。
失败原因：当前系统未安装 make 和 qemu-system-loongarch64。
下一步：安装工具链后执行 make clean && make && make run。
```

---

## 3. 目标平台

### 3.1 第一目标平台：QEMU

默认先支持：

```text
qemu-system-loongarch64
machine: virt
arch: loongarch64
```

QEMU 阶段要求：

* 能通过串口输出调试信息；
* 能加载裸机 miniOS；
* 不依赖 Linux 用户态；
* 不依赖真实龙芯开发板；
* 所有基础实验均应在 QEMU 中完成。

### 3.2 第二目标平台：龙芯 2K0300 先锋板

QEMU 跑通后，再考虑迁移到龙芯 2K0300 先锋板。

2K0300 阶段要求：

* 单独建立 board/2k0300/ 目录；
* 不要污染 QEMU 通用代码；
* 明确记录 QEMU 与 2K0300 的差异；
* 重点关注：

  * 启动方式差异；
  * UART 地址差异；
  * 内存布局差异；
  * 中断控制器差异；
  * 镜像加载方式差异。

---

## 4. 推荐项目结构

```text
miniOS/
├── AGENTS.md
├── README.md
├── Makefile
├── linker.ld
├── boot/
│   └── boot.S
├── kernel/
│   ├── main.c
│   ├── printk.c
│   ├── exception.c
│   └── syscall.c
├── lib/
│   ├── memset.S
│   ├── memcpy.S
│   └── strlen.S
├── include/
│   ├── types.h
│   ├── printk.h
│   ├── uart.h
│   ├── exception.h
│   └── syscall.h
├── drivers/
│   └── uart.c
├── board/
│   ├── qemu-virt/
│   │   ├── board.h
│   │   └── uart.h
│   └── 2k0300/
│       ├── board.h
│       └── uart.h
├── tests/
│   ├── test_memset.c
│   ├── test_strlen.c
│   └── test_syscall.c
└── docs/
    ├── week01_qemu_hello.md
    ├── week02_data_bss.md
    ├── week03_branch_loop.md
    ├── week04_stack_abi.md
    ├── week05_syscall.md
    ├── week06_exception.md
    ├── week07_mem_opt.md
    ├── week08_minios_demo.md
    └── qemu_to_2k0300_porting.md
```

---

## 5. 实验周次主线

### 第 1 周：QEMU Hello miniOS

目标：

* 建立最小裸机工程；
* 编写 boot.S；
* 编写 linker.ld；
* 初始化栈；
* 跳转到 kernel_main；
* 通过 UART 输出：

```text
Hello miniOS on LoongArch64
```

验收标准：

* make 成功；
* QEMU 能启动；
* 串口能看到输出。

---

### 第 2 周：数据段与内存初始化

目标：

* 理解 .text、.data、.bss；
* 完成 .bss 清零；
* 测试全局变量、静态变量；
* 理解链接脚本。

验收标准：

* .bss 变量初始值为 0；
* .data 变量有正确初值；
* 能在 printk 中输出验证信息。

---

### 第 3 周：分支、循环与字符串输出

目标：

* 使用 LoongArch 汇编实现循环；
* 实现字符串遍历；
* 理解条件跳转；
* 完善 printk 基础能力。

验收标准：

* 能逐字符输出字符串；
* 能输出循环计数；
* 能解释分支指令行为。

---

### 第 4 周：函数调用约定与栈帧

目标：

* 理解 LoongArch ABI；
* 理解参数传递、返回值、ra、sp；
* 用汇编实现 strlen、memset；
* C 调用汇编函数。

验收标准：

* C 代码能调用汇编函数；
* strlen、memset 结果正确；
* 文档中画出栈帧示意。

---

### 第 5 周：系统调用

目标：

* 先从教学上理解 syscall；
* 实现 sys_write；
* 建立用户态调用接口雏形；
* 说明 syscall 本质是一类异常。

验收标准：

* 用户侧函数能调用 sys_write；
* 内核侧能分发 syscall number；
* 串口能输出用户传入字符串。

---

### 第 6 周：异常与中断基础

目标：

* 建立 exception entry；
* 保存必要寄存器；
* 读取异常原因；
* 输出异常调试信息；
* 解释 syscall 与 exception 的关系。

验收标准：

* 能触发一次可控异常；
* 能进入 exception_handler；
* 能打印异常编号或状态信息。

---

### 第 7 周：memset / memcpy 优化

目标：

* 对比 C 实现与汇编实现；
* 优化 memset、memcpy；
* 设计简单 benchmark；
* 说明性能优化思路。

验收标准：

* 有基础性能对比；
* 结果写入 docs/week07_mem_opt.md；
* 不追求极限优化，重点是教学可解释。

---

### 第 8 周：miniOS 综合实验与 2K0300 移植准备

目标：

* 整合 boot、printk、syscall、exception、lib；
* 形成 miniOS demo；
* 编写 QEMU → 2K0300 移植说明；
* 准备板级适配目录。

验收标准：

* QEMU 中完整运行；
* 形成 docs/qemu_to_2k0300_porting.md；
* 明确哪些代码可复用，哪些代码需要适配。

---

## 6. 开发顺序约束

必须按以下顺序推进：

```text
环境检查
  ↓
QEMU Hello World
  ↓
链接脚本与启动代码
  ↓
UART 输出
  ↓
.data/.bss
  ↓
分支循环
  ↓
函数调用与栈
  ↓
syscall
  ↓
exception
  ↓
memcpy/memset 优化
  ↓
miniOS 整合
  ↓
2K0300 移植
```

如果某一步失败，必须停在当前步骤排查，不允许继续后续功能。

---

## 7. 工具链约束

优先使用以下工具：

```bash
loongarch64-linux-gnu-gcc
loongarch64-linux-gnu-ld
loongarch64-linux-gnu-objdump
loongarch64-linux-gnu-objcopy
qemu-system-loongarch64
gdb-multiarch
make
```

不要默认使用系统 gcc 编译 LoongArch 代码。

不要默认使用 x86_64 编译器。

不要默认引入 CMake，除非用户明确要求。

---

## 8. 环境检查命令

开始开发前必须执行：

```bash
which make
which qemu-system-loongarch64
which loongarch64-linux-gnu-gcc
which loongarch64-linux-gnu-ld
which loongarch64-linux-gnu-objdump
which loongarch64-linux-gnu-objcopy
which gdb-multiarch
```

并记录到：

```text
docs/environment_check.md
```

如果使用仓库脚本，也必须把输出摘要写入 `docs/environment_check.md`：

```bash
sh scripts/check-env.sh
```

Windows 侧仅用于检查宿主环境，不作为 LoongArch 裸机实验的最终验证环境：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-env.ps1
```

如果缺少工具，提示安装：

```bash
sudo apt update
sudo apt install -y make qemu-system-misc \
  gcc-loongarch64-linux-gnu \
  binutils-loongarch64-linux-gnu \
  gdb-multiarch
```

### 8.1 安装位置约束

本项目环境安装、下载缓存和临时工具不得放在 C 盘。统一使用项目上一级父目录：

```text
../env/
├── wsl/        # WSL 发行版安装位置
├── downloads/  # 安装包和发行版下载
├── tools/      # 手工下载的工具链或辅助工具
└── cache/      # apt、构建和其他缓存
```

如果使用 `wsl --install` 安装 Ubuntu，必须指定 `--location`：

```powershell
wsl --install -d Ubuntu --location "<你的课程工作目录>\env\wsl\Ubuntu"
```

如果该命令不可用，改用 `wsl --import`，安装位置仍必须在 `../env/wsl/` 下。

WSL 内部建议把临时下载缓存放到项目父目录映射路径：

```bash
export MINIOS_ENV=/mnt/<盘符>/<你的课程工作目录>/env
export TMPDIR="$MINIOS_ENV/cache"
```

---

## 9. 编码规范

1. C 代码使用简单 C，不使用复杂宏技巧。
2. 汇编代码必须逐段中文注释。
3. 所有板级差异放在 board/ 目录。
4. 不要把 QEMU 地址硬编码到通用驱动中。
5. 不要把 2K0300 地址硬编码到 QEMU 配置中。
6. printk 先实现最小版本，不要求完整 printf。
7. syscall 先实现 sys_write，不要扩展太多系统调用。
8. exception 先实现基本入口和打印，不要一开始做复杂调度。
9. 所有实验代码应能通过 make clean && make 重新构建。
10. 每次新增功能后更新 README 或 docs。
11. 全体文件统一使用 UTF-8 编码保存，避免在 Codex、Claude、VS Code、WSL、PowerShell 之间切换时出现中文乱码。
12. 新增或修改中文文档时，不得使用 GBK、ANSI 或其他本地编码。
13. 如果发现已有文件乱码，先确认原始字节编码，再转换为 UTF-8，不得直接按乱码内容继续编辑。

---

## 10. Makefile 要求

Makefile 至少支持：

```bash
make
make run
make clean
make disasm
```

推荐支持：

```bash
make qemu
make debug
make objdump
```

其中：

* make：编译 miniOS.elf；
* make run：启动 QEMU；
* make clean：清理构建产物；
* make disasm：生成反汇编文件；
* make debug：启动 QEMU 并等待 GDB 连接。

---

## 11. QEMU 运行要求

默认 QEMU 运行命令应类似：

```bash
qemu-system-loongarch64 \
  -machine virt \
  -nographic \
  -serial mon:stdio \
  -kernel build/miniOS.elf
```

如果该命令不可用，必须记录原因，并调整为实际可运行方案。

---

## 12. 2K0300 移植约束

在 QEMU 阶段未完全跑通前，不允许开始 2K0300 实机移植。

开始 2K0300 前必须先完成：

```text
docs/qemu_to_2k0300_porting.md
```

该文档至少包含：

1. QEMU virt 与 2K0300 的启动差异；
2. UART 地址和初始化差异；
3. 内存布局差异；
4. 镜像格式差异；
5. U-Boot 加载方式；
6. 串口调试方式；
7. 风险清单；
8. 回退方案。

---

## 13. 文档输出要求

每周实验文档统一格式：

```markdown
# 第 X 周实验：标题

## 1. 实验目标

## 2. 背景知识

## 3. 目录结构

## 4. 核心代码说明

## 5. 编译方法

## 6. 运行方法

## 7. 预期输出

## 8. 实际测试结果

## 9. 常见错误

## 10. 思考题
```

---

## 14. 测试报告要求

项目必须维护：

```text
docs/LoongArch_miniOS_实验测试报告.md
```

每次完成实验后追加：

```markdown
## 日期：YYYY-MM-DD

### 测试内容

### 测试环境

### 编译结果

### 运行结果

### 问题记录

### 下一步计划
```

报告中不得只写“预期输出”。每次实验必须明确写出：

```markdown
### 实际测试结果

- 已执行：
- 未执行：
- 失败原因：
- 下一步命令：
```

如果当前环境无法运行 QEMU，应写“未实测”，不得写“验证通过”。

---

## 15. 禁止事项

严禁：

1. 未测试就声称“已跑通”；
2. 使用 x86 工具链冒充 LoongArch；
3. 跳过 QEMU 直接适配 2K0300；
4. 把 Linux 用户态程序当作裸机 miniOS；
5. 一次性引入进程、文件系统、虚拟内存等复杂内容；
6. 生成大量无法验证的代码；
7. 忽略编译错误继续写后续内容；
8. 删除已有可运行代码；
9. 将课程实验变成复杂科研项目；
10. 使用英文注释替代中文教学注释。
11. 根据代码推断串口输出并冒充实际运行结果；
12. 在没有板卡手册或实测输出时编造 2K0300 UART、中断控制器、内存布局细节。

---

## 16. 当前优先任务

当前只允许先完成第 1 周实验：

```text
QEMU Hello miniOS
```

必须产出：

1. boot/boot.S
2. linker.ld
3. drivers/uart.c
4. kernel/printk.c
5. kernel/main.c
6. include/*.h
7. Makefile
8. docs/week01_qemu_hello.md
9. docs/environment_check.md
10. docs/LoongArch_miniOS_实验测试报告.md

运行后必须看到：

```text
Hello miniOS on LoongArch64
```

完成第 1 周后，等待用户确认，再继续第 2 周。

---

## 17. 给 Codex 的执行口径

你是课程实验工程助教，不是自由发挥的系统内核开发者。

你的任务是：

```text
每次只推进一个最小可验证步骤。
每次都保证代码能编译、能运行、能解释。
优先让教师能讲、学生能做、实验能复现。
```

遇到不确定的 2K0300 硬件细节时，不要猜测，先在文档中标记为“待查证”，并给出需要用户确认的信息。
