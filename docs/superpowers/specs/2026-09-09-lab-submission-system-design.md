# 学生实验报告提交与 AI 辅助批改系统 设计

## 目标与边界

课程 12 次课每次课都有 `docs/NN/lab.md` 定义的实验任务和"报告要求"（§6），
目前学生通过校外渠道（教学平台/群/邮件）把报告文件交给老师，老师逐份人工
核对 §5 验收标准。本系统的目标：

1. 给学生一个简单网页，能按各课"报告要求"格式**填写正文 + 上传截图**并提交；
2. 老师能在一个后台页面**按课次筛选、查看、复核**所有提交；
3. 提供一个**独立批改脚本**，让 AI（Claude API）先读数据库里的提交、对照对应
   `lab.md` 的验收标准打一遍分、写建议反馈，供老师复核后再发布给学生。

**非目标（本期不做）：**

- 不做真实身份认证体系（学号+自设密码的轻量防护即可，见"防护"一节），不对接
  学校统一身份认证。
- 不做实时/自动发布 AI 打分（AI 结果必须经老师人工复核才对学生可见，见
  `lab.md` §7 "AI 共学边界"里"不允许编造"的一贯立场——批改同样不能让 AI
  分数未经人看就流出）。
- 不做多教师/多课程的多租户；本系统只服务这一门课、这一个老师账号。
- 不做公网高并发优化；一个班级规模（几十人）的教学工具即可。

## 技术选型

| 选择 | 理由 |
|---|---|
| Flask + Jinja2 模板 | 依赖少、单体好部署，老师已熟悉 Python（`scripts/*.py`），不需要引入前端构建链 |
| SQLite（Python 内置 `sqlite3`） | 免安装数据库服务；文件级存储方便备份/复制；并发写入量级（班级规模）完全够用 |
| `openpyxl` | 导出 Excel 报表用，已是常见教学工具链的一部分 |
| Anthropic Python SDK | 批改脚本调用 Claude API |

不选 Claude Artifact 的 `db` 能力：其要求"读写者都是同一 Claude 组织下的已
登录账号"，而学生没有 Claude 账号，走不通（已与老师确认）。

## 目录结构

新增顶层目录 `tools/lab_submission/`，与 `scripts/`（课件生成工具）区分开——
这是一个常驻运行的小服务，不是一次性生成脚本：

```
tools/lab_submission/
  app.py                 # Flask 入口：路由注册
  models.py              # SQLite 表结构与基本 CRUD（无 ORM，直接 sqlite3）
  db_init.sql             # 建表 SQL
  grade.py                # AI 批改脚本（独立运行，不在 app.py 请求路径里）
  rubric_loader.py        # 从 docs/<lesson>/lab.md 里抽取"验收标准/报告要求"章节
  templates/
    submit.html            # 学生提交页
    submit_success.html
    admin_login.html
    admin_list.html         # 教师端：提交列表（按课次筛选）
    admin_detail.html       # 教师端：单条提交详情 + AI 建议 + 复核表单
  static/
    style.css
  uploads/                # 截图存储（.gitignore 排除，不进仓库）
  data.db                  # SQLite 文件（.gitignore 排除）
  requirements.txt
  README.md               # 老师看的启动/部署说明
```

`tools/lab_submission/uploads/`、`data.db` 加入 `.gitignore`（学生隐私数据不
进代码仓库）。

## 数据模型（SQLite）

```sql
-- 学生身份：学号 + 姓名 + 密码哈希（首次提交时自设，之后校验）
CREATE TABLE students (
  student_id   TEXT PRIMARY KEY,   -- 学号
  name         TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at   TEXT NOT NULL
);

CREATE TABLE submissions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id   TEXT NOT NULL REFERENCES students(student_id),
  lesson       TEXT NOT NULL,      -- 课次编号，如 "03"
  report_text  TEXT NOT NULL,      -- 报告正文（粘贴的 Markdown/纯文本）
  submitted_at TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending'
               -- pending -> ai_graded -> released
);

CREATE TABLE screenshots (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  submission_id INTEGER NOT NULL REFERENCES submissions(id),
  file_path     TEXT NOT NULL,
  uploaded_at   TEXT NOT NULL
);

CREATE TABLE grades (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  submission_id     INTEGER NOT NULL UNIQUE REFERENCES submissions(id),
  ai_score          INTEGER,
  ai_feedback_json  TEXT,          -- AI 返回的结构化 JSON（分项+建议）
  teacher_score     INTEGER,
  teacher_comment   TEXT,
  released          INTEGER NOT NULL DEFAULT 0,  -- 0/1
  graded_at         TEXT
);
```

一名学生同一课次允许重复提交（覆盖式：新增一行 `submissions`，教师端按
`submitted_at` 取最新一条为准，历史记录保留可追溯）。

## 学生端流程

1. `GET /submit`：表单——学号、姓名、密码、课次下拉（01~12）、报告正文
   大文本框、截图多文件上传。
2. `POST /submit`：
   - 学号第一次出现 → 创建 `students` 行，密码哈希保存（`werkzeug.security.
     generate_password_hash`，不存明文）；
   - 学号已存在 → 校验密码，**不匹配则拒绝提交**并提示"学号已注册，密码不对，
     如果不是你本人在用这个学号请联系老师"——这是本系统唯一的防护层，
     目的是防止同学之间互相恶搞冒名提交，不是真实身份认证；
   - 姓名与已存学号的姓名不一致时给警告但不阻断（防止改名/打错字锁死账号）；
   - 写入 `submissions` + `screenshots`，返回提交成功页（显示本次提交编号，
     方便学生截图留存）。
3. 上传文件校验：仅允许图片扩展名（`.png/.jpg/.jpeg`），单文件大小上限（如
   5MB），超限拒绝并提示。

## 教师端流程

1. `/admin/login`：单一共享口令（存在环境变量/配置文件，不写死在代码里），
   登录后 Flask session 标记为教师。
2. `/admin`：提交列表，可按课次筛选，显示学号/姓名/提交时间/状态；
   `pending`（未批改）、`ai_graded`（AI 已给建议待复核）、`released`（已发布）
   用不同颜色标出。
3. `/admin/submission/<id>`：详情页——报告正文、截图缩略图（点击看大图）、
   AI 反馈（若有）、复核表单（老师改分数/写评语/勾选"发布给学生"）。
4. `/admin/export?lesson=03`：导出该课次全部提交 + 最终分数为 `.xlsx`
   （`openpyxl`），列：学号、姓名、提交时间、AI 建议分、老师最终分、评语、
   状态。

学生端不做"查看自己成绩"页（v1 范围外）——教师复核后线下/教学平台通知，
后续如有需要再加 `/my/<学号>`（用同一套学号+密码校验）。

## AI 批改脚本（`grade.py`，教师手动运行，不挂在 Web 请求里）

流程：

1. 查询 `submissions.status = 'pending'` 且尚无 `grades` 行的记录；
2. 对每条记录：
   - `rubric_loader.py` 读取 `docs/<lesson>/lab.md`，抽取"## 5. 验收标准"
     和"## 6. 报告要求"两个章节原文作为评分标准——**直接读仓库文件，不用
     老师额外维护第二份评分表，课程内容改了 lab.md 评分标准自动跟着变**；
   - 组装 Prompt：评分标准原文 + 学生报告正文 + （截图作为图片附件，走
     Claude API 的 vision 输入）；
   - 要求模型返回结构化 JSON：`{"items": [{"criterion": "...", "met": true/false,
     "note": "..."}], "suggested_score": 0-100, "summary": "..."}`；
   - 写入 `grades` 表（`ai_score` = `suggested_score`，`ai_feedback_json` =
     原始 JSON），`submissions.status` 置为 `ai_graded`。
3. 脚本运行方式：`python grade.py --lesson 03`（可指定课次，也可不指定跑
   全部待批改的）；命令行输出处理条数和失败列表（API 报错的条目不阻断
   其它条目，留在 `pending` 下次重跑）。

**明确边界：** AI 打分只是"建议分"，`grades.released` 恒为 0 直到老师在
`/admin/submission/<id>` 里手动勾选发布；`teacher_score`/`teacher_comment`
优先于 `ai_score`——教师端展示时永远清楚标注"这是 AI 建议，尚未确认"和
"这是老师确认结果"两种状态，不混在一起显示成"最终成绩"。

## 部署

单体 Flask 应用，本期只要求能 `python app.py` 在老师本机/校园网内跑通并
可被学生浏览器访问；`README.md` 写清楚：

- 如何装依赖（`pip install -r requirements.txt`）
- 如何设置教师口令、Anthropic API Key（环境变量）
- 如何初始化数据库（首次运行自动建表）
- 局域网内如何让学生访问（本机 IP + 端口，或后续换成任意云端 Python 托管
  不需要改代码——不在本期范围，`README.md` 留一句指引即可）

## 与现有课程材料的关系

- 不改动任何 `docs/NN/lab.md` 的任务内容——批改脚本只是**读取**这些文件的
  验收标准章节，不反向修改它们；lab.md 的"报告要求"章节今后要保持人类可读
  的清晰结构（已经是这样），因为它同时也是 AI 批改的 prompt 输入。
- `README.md`（仓库根）本期不新增学生入口说明，先在 `tools/lab_submission/
  README.md` 里独立说明；后续如果这个系统稳定启用，再补一条从课程
  `README.md`/`lab.md` 指向提交网址的链接（届时会是另一个小改动，不在这次
  范围内）。

## 验收标准（这个系统本身怎么算做完）

- [ ] 学生能在 `/submit` 完整走一遍：首次提交自动创建账号，第二次提交同学号
      不同密码被拒绝
- [ ] 上传的截图能在教师端详情页正确显示
- [ ] `grade.py --lesson 03` 能跑通：读到 `docs/03/lab.md` 的验收标准、调用
      Claude API、把结构化结果写回 `grades` 表
- [ ] 教师端能复核（改分/写评语）并勾选发布，`released` 状态正确变化
- [ ] `/admin/export` 能导出正确的 `.xlsx`
- [ ] `uploads/`、`data.db` 已被 `.gitignore` 排除，不会误提交学生隐私数据
