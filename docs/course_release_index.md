# LoongArch miniOS 课程实验发布计划表

本文用于控制每周实验代码的冻结、分发和回溯。

核心原则：

- `master` 保存当前最新开发进度。
- 每完成一周实验，必须打一个稳定 `tag`。
- 学生按周次获取对应 `tag` 的源码，不直接使用最终版工程学习前几周内容。
- 每个 `tag` 发布前必须更新测试报告，明确“已执行、未执行、失败原因、下一步命令”。
- 未经当前机器或课堂环境实测，不得把状态写成“已测试通过”。

## 1. 每周发布索引

| 周次 | 实验主题 | 实验文档 | Git tag | 源码下载链接 | 发布状态 | 测试状态 |
|---|---|---|---|---|---|---|
| 第 1 周 | QEMU Hello miniOS | [docs/week01/README.md](week01/README.md) | `week01-qemu-hello` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week01-qemu-hello.zip> | 待发布 | 待确认 |
| 第 2 周 | `.data/.bss` 与内存初始化 | [docs/week02/data_bss.md](week02/data_bss.md) | `week02-data-bss` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week02-data-bss.zip> | 待测试 | 未执行 |
| 第 3 周 | 分支、循环与字符串输出 | 待补充 | `week03-branch-loop` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week03-branch-loop.zip> | 未开始 | 未执行 |
| 第 4 周 | 函数调用约定与栈帧 | 待补充 | `week04-stack-abi` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week04-stack-abi.zip> | 未开始 | 未执行 |
| 第 5 周 | 系统调用 `sys_write` | 待补充 | `week05-syscall` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week05-syscall.zip> | 未开始 | 未执行 |
| 第 6 周 | 异常与中断基础 | 待补充 | `week06-exception` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week06-exception.zip> | 未开始 | 未执行 |
| 第 7 周 | `memset/memcpy` 优化 | 待补充 | `week07-mem-opt` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week07-mem-opt.zip> | 未开始 | 未执行 |
| 第 8 周 | miniOS 综合实验与移植准备 | 待补充 | `week08-minios-demo` | <https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week08-minios-demo.zip> | 未开始 | 未执行 |

## 2. 发布状态含义

| 状态 | 含义 |
|---|---|
| 未开始 | 该周实验尚未开发 |
| 开发中 | 代码正在编写，不能分发给学生 |
| 待测试 | 代码已整理完，但尚未完成要求的编译或运行验证 |
| 待发布 | 代码已提交，但还没有创建或推送 tag |
| 已发布 | tag 已推送到 GitHub，可分发给学生 |

## 3. 测试状态含义

| 状态 | 含义 |
|---|---|
| 未执行 | 尚未运行环境检查、编译或 QEMU |
| 部分执行 | 只完成了部分命令，例如只执行了环境检查 |
| 失败 | 已执行，但存在明确失败原因 |
| 已测试通过 | `make clean && make && make run` 或等价命令已真实执行并符合预期 |
| 待确认 | 当前记录不足，需要重新核对测试报告 |

## 4. 每周发布流程

每周完成实验后按以下顺序操作：

```bash
# 1. 环境检查
sh scripts/check-env.sh

# 2. 重新构建
make clean
make

# 3. QEMU 运行验证
make run

# 4. 更新文档
# - docs/weekXX/*.md
# - docs/environment_check.md
# - docs/LoongArch_miniOS_实验测试报告.md
# - docs/course_release_index.md

# 5. 提交
git add .
git commit -m "Complete weekXX topic"

# 6. 打 tag
git tag weekXX-topic

# 7. 推送
git push origin master
git push origin weekXX-topic
```

注意：如果当前机器缺少工具链或 QEMU，只能把测试状态写为“未执行”或“失败”，并记录下一步命令，不能写“已测试通过”。

## 5. 学生获取代码方式

### 方式一：使用 Git

```bash
git clone https://github.com/cxi218447-byte/miniOS.git
cd miniOS
git checkout week01-qemu-hello
```

切换其他周次：

```bash
git checkout week02-data-bss
```

### 方式二：直接下载 ZIP

教师每周只分发对应周次的 ZIP 链接，例如第 1 周：

```text
https://github.com/cxi218447-byte/miniOS/archive/refs/tags/week01-qemu-hello.zip
```

## 6. 教学控制要求

- 第 1 周课堂只使用 `week01-qemu-hello`。
- 第 2 周课堂只使用 `week02-data-bss`。
- 不使用最终版工程回讲前几周实验。
- 如果需要展示后续功能，必须明确说明“这是后续周次内容，不属于本周验收范围”。
- 每周 PPT、实验文档、测试报告和代码 tag 必须互相对应。
