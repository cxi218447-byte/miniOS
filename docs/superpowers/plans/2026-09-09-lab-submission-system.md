# 学生实验报告提交与 AI 辅助批改系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 `tools/lab_submission/` 下的 Flask + SQLite 小系统：学生提交实验报告正文+截图，教师后台复核，独立脚本让 AI 读数据库并给出批改建议（不自动发布）。

**Architecture:** 单体 Flask 应用（app factory 模式，便于测试），DB 访问全部收在 `models.py`（无 ORM，原生 `sqlite3` + 参数化查询），批改逻辑是独立可重跑的 CLI 脚本 `grade.py`（不挂在 Web 请求路径里），课程评分标准直接从各课 `docs/NN/lab.md` 的"验收标准"/"报告要求"章节抽取，不另存一份。

**Tech Stack:** Python 3.12、Flask 3.x、SQLite（内置 `sqlite3`）、`werkzeug.security`（密码哈希，随 Flask 安装）、`openpyxl`（导出 Excel）、`anthropic`（AI 批改）、`pytest`（测试）。

**Spec:** `docs/superpowers/specs/2026-09-09-lab-submission-system-design.md`

## Global Constraints

- 所有数据库读写必须经过 `models.py` 的函数，路由/脚本不直接拼 SQL。
- 学生密码只存哈希（`werkzeug.security.generate_password_hash`），任何日志/模板都不得回显明文密码。
- `grades.released` 默认 0；AI 批改结果（`ai_score`/`ai_feedback_json`）绝不直接展示为"最终成绩"，只在教师端标注为"AI 建议，待确认"。
- 存到数据库里的截图相对路径一律用正斜杠（`Path.as_posix()`），兼容 Windows 开发机与将来可能的 Linux 部署。
- `tools/lab_submission/data.db`、`tools/lab_submission/uploads/` 不进 git（加入 `.gitignore`）。
- 课次编号统一用两位数字符串（`"01"`~`"12"`），与 `docs/NN/` 目录名一致。
- 每个任务写完代码后跑对应测试，全绿才进行下一任务；每个任务结束提交一次 git commit。

---

## Task 1: 项目骨架 + 数据库 schema + 连接/初始化

**Files:**
- Create: `tools/lab_submission/requirements.txt`
- Create: `tools/lab_submission/db_init.sql`
- Create: `tools/lab_submission/models.py`
- Create: `tools/lab_submission/tests/__init__.py`（空文件，让 pytest 把 tests 当包处理）
- Create: `tools/lab_submission/tests/conftest.py`
- Create: `tools/lab_submission/tests/test_models_init.py`
- Modify: `.gitignore`（仓库根）

**Interfaces:**
- Produces: `models.get_connection(db_path: str) -> sqlite3.Connection`；`models.init_db(conn: sqlite3.Connection) -> None`；`models.now_iso() -> str`

- [ ] **Step 1: 安装依赖**

```bash
pip install flask openpyxl anthropic pytest
```

- [ ] **Step 2: 建目录，写 `requirements.txt`**

```text
Flask>=3.0,<4
openpyxl>=3.1,<4
anthropic>=0.40,<1
pytest>=8.0,<9
```

- [ ] **Step 3: 写 `db_init.sql`**

```sql
CREATE TABLE IF NOT EXISTS students (
  student_id    TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS submissions (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id   TEXT NOT NULL REFERENCES students(student_id),
  lesson       TEXT NOT NULL,
  report_text  TEXT NOT NULL,
  submitted_at TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS screenshots (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  submission_id INTEGER NOT NULL REFERENCES submissions(id),
  file_path     TEXT NOT NULL,
  uploaded_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS grades (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  submission_id    INTEGER NOT NULL UNIQUE REFERENCES submissions(id),
  ai_score         INTEGER,
  ai_feedback_json TEXT,
  teacher_score    INTEGER,
  teacher_comment  TEXT,
  released         INTEGER NOT NULL DEFAULT 0,
  graded_at        TEXT
);

CREATE INDEX IF NOT EXISTS idx_submissions_lesson  ON submissions(lesson);
CREATE INDEX IF NOT EXISTS idx_submissions_student ON submissions(student_id);
```

- [ ] **Step 4: 写 `models.py`（本任务只放连接/初始化）**

```python
"""数据库访问层：所有 SQL 只写在这个文件里，其余模块通过这里的函数读写数据。"""
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

SCHEMA_PATH = Path(__file__).parent / "db_init.sql"


def get_connection(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    schema = SCHEMA_PATH.read_text(encoding="utf-8")
    conn.executescript(schema)
    conn.commit()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()
```

- [ ] **Step 5: 写 `tests/__init__.py`（空）与 `tests/conftest.py`**

```python
# tools/lab_submission/tests/conftest.py
"""让测试在不打包成 module 的情况下也能 `import models` 等同级模块。"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest

import models


@pytest.fixture
def db_conn(tmp_path):
    db_path = tmp_path / "test.db"
    conn = models.get_connection(str(db_path))
    models.init_db(conn)
    yield conn
    conn.close()
```

- [ ] **Step 6: 写失败测试 `tests/test_models_init.py`**

```python
# tools/lab_submission/tests/test_models_init.py
def test_init_db_creates_all_tables(db_conn):
    tables = {
        row["name"]
        for row in db_conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
    }
    assert {"students", "submissions", "screenshots", "grades"} <= tables


def test_now_iso_returns_iso_string():
    import models

    value = models.now_iso()
    assert "T" in value
    assert value.endswith("+00:00")
```

- [ ] **Step 7: 跑测试确认通过**

```bash
cd tools/lab_submission
python -m pytest tests/test_models_init.py -v
```

Expected: 2 个测试全部 PASS。

- [ ] **Step 8: 给根 `.gitignore` 追加条目**

```
tools/lab_submission/data.db
tools/lab_submission/uploads/
tools/lab_submission/__pycache__/
tools/lab_submission/tests/__pycache__/
tools/lab_submission/.pytest_cache/
```

- [ ] **Step 9: Commit**

```bash
git add tools/lab_submission/requirements.txt tools/lab_submission/db_init.sql \
        tools/lab_submission/models.py tools/lab_submission/tests/__init__.py \
        tools/lab_submission/tests/conftest.py tools/lab_submission/tests/test_models_init.py \
        .gitignore
git commit -m "feat(lab-submission): scaffold project + db schema + connection helpers"
```

---

## Task 2: 学生身份模型（学号 + 自设密码防恶作剧）

**Files:**
- Modify: `tools/lab_submission/models.py`
- Test: `tools/lab_submission/tests/test_models_students.py`

**Interfaces:**
- Consumes: `models.get_connection`、`models.init_db`、`models.now_iso`（Task 1）
- Produces: `models.AuthError`（异常类）；`models.create_or_verify_student(conn, student_id: str, name: str, password: str) -> None`；`models.get_student(conn, student_id: str) -> sqlite3.Row | None`

- [ ] **Step 1: 写失败测试**

```python
# tools/lab_submission/tests/test_models_students.py
import pytest

import models


def test_first_submission_creates_student(db_conn):
    models.create_or_verify_student(db_conn, "S001", "张三", "pw123")
    row = models.get_student(db_conn, "S001")
    assert row is not None
    assert row["name"] == "张三"
    assert row["password_hash"] != "pw123"  # 不能存明文


def test_second_submission_same_password_ok(db_conn):
    models.create_or_verify_student(db_conn, "S001", "张三", "pw123")
    # 不应该抛异常
    models.create_or_verify_student(db_conn, "S001", "张三", "pw123")


def test_second_submission_wrong_password_rejected(db_conn):
    models.create_or_verify_student(db_conn, "S001", "张三", "pw123")
    with pytest.raises(models.AuthError):
        models.create_or_verify_student(db_conn, "S001", "张三", "wrong-password")


def test_get_student_missing_returns_none(db_conn):
    assert models.get_student(db_conn, "NOPE") is None
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_models_students.py -v
```

Expected: FAIL（`AttributeError: module 'models' has no attribute 'create_or_verify_student'`）。

- [ ] **Step 3: 在 `models.py` 追加实现**

```python
from werkzeug.security import check_password_hash, generate_password_hash


class AuthError(Exception):
    """学号已注册但密码不匹配时抛出——本系统唯一的防冒名机制。"""


def create_or_verify_student(conn: sqlite3.Connection, student_id: str, name: str, password: str) -> None:
    row = conn.execute(
        "SELECT * FROM students WHERE student_id = ?", (student_id,)
    ).fetchone()
    if row is None:
        conn.execute(
            "INSERT INTO students (student_id, name, password_hash, created_at) VALUES (?, ?, ?, ?)",
            (student_id, name, generate_password_hash(password), now_iso()),
        )
        conn.commit()
        return
    if not check_password_hash(row["password_hash"], password):
        raise AuthError("学号已注册，密码不对，如果这不是你本人的学号请联系老师")


def get_student(conn: sqlite3.Connection, student_id: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM students WHERE student_id = ?", (student_id,)
    ).fetchone()
```

- [ ] **Step 4: 跑测试确认通过**

```bash
python -m pytest tests/test_models_students.py -v
```

Expected: 4 个测试全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add tools/lab_submission/models.py tools/lab_submission/tests/test_models_students.py
git commit -m "feat(lab-submission): add student create/verify with password guard"
```

---

## Task 3: 提交与截图模型

**Files:**
- Modify: `tools/lab_submission/models.py`
- Test: `tools/lab_submission/tests/test_models_submissions.py`

**Interfaces:**
- Consumes: Task 1/2 全部函数
- Produces: `models.create_submission(conn, student_id: str, lesson: str, report_text: str) -> int`；`models.add_screenshot(conn, submission_id: int, file_path: str) -> int`；`models.list_submissions(conn, lesson: str | None = None) -> list[sqlite3.Row]`（含 `student_name` 字段）；`models.get_submission(conn, submission_id: int) -> sqlite3.Row | None`；`models.get_screenshots(conn, submission_id: int) -> list[sqlite3.Row]`

- [ ] **Step 1: 写失败测试**

```python
# tools/lab_submission/tests/test_models_submissions.py
import models


def _make_student(conn, student_id="S001", name="张三"):
    models.create_or_verify_student(conn, student_id, name, "pw123")


def test_create_submission_and_get_it_back(db_conn):
    _make_student(db_conn)
    sub_id = models.create_submission(db_conn, "S001", "03", "报告正文")
    row = models.get_submission(db_conn, sub_id)
    assert row["student_id"] == "S001"
    assert row["lesson"] == "03"
    assert row["status"] == "pending"


def test_add_and_list_screenshots(db_conn):
    _make_student(db_conn)
    sub_id = models.create_submission(db_conn, "S001", "03", "报告正文")
    models.add_screenshot(db_conn, sub_id, "S001/03/a.png")
    models.add_screenshot(db_conn, sub_id, "S001/03/b.png")
    rows = models.get_screenshots(db_conn, sub_id)
    assert [r["file_path"] for r in rows] == ["S001/03/a.png", "S001/03/b.png"]


def test_list_submissions_filters_by_lesson_and_joins_name(db_conn):
    _make_student(db_conn, "S001", "张三")
    _make_student(db_conn, "S002", "李四")
    models.create_submission(db_conn, "S001", "03", "report 1")
    models.create_submission(db_conn, "S002", "04", "report 2")

    lesson03 = models.list_submissions(db_conn, "03")
    assert len(lesson03) == 1
    assert lesson03[0]["student_name"] == "张三"

    all_rows = models.list_submissions(db_conn)
    assert len(all_rows) == 2


def test_get_submission_missing_returns_none(db_conn):
    assert models.get_submission(db_conn, 999) is None
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_models_submissions.py -v
```

Expected: FAIL（`create_submission` 未定义）。

- [ ] **Step 3: 在 `models.py` 追加实现**

```python
def create_submission(conn: sqlite3.Connection, student_id: str, lesson: str, report_text: str) -> int:
    cur = conn.execute(
        "INSERT INTO submissions (student_id, lesson, report_text, submitted_at, status) "
        "VALUES (?, ?, ?, ?, 'pending')",
        (student_id, lesson, report_text, now_iso()),
    )
    conn.commit()
    return cur.lastrowid


def add_screenshot(conn: sqlite3.Connection, submission_id: int, file_path: str) -> int:
    cur = conn.execute(
        "INSERT INTO screenshots (submission_id, file_path, uploaded_at) VALUES (?, ?, ?)",
        (submission_id, file_path, now_iso()),
    )
    conn.commit()
    return cur.lastrowid


def list_submissions(conn: sqlite3.Connection, lesson: str | None = None) -> list[sqlite3.Row]:
    query = (
        "SELECT s.*, st.name AS student_name FROM submissions s "
        "JOIN students st ON st.student_id = s.student_id "
    )
    params: tuple = ()
    if lesson:
        query += "WHERE s.lesson = ? "
        params = (lesson,)
    query += "ORDER BY s.submitted_at DESC"
    return conn.execute(query, params).fetchall()


def get_submission(conn: sqlite3.Connection, submission_id: int) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM submissions WHERE id = ?", (submission_id,)
    ).fetchone()


def get_screenshots(conn: sqlite3.Connection, submission_id: int) -> list[sqlite3.Row]:
    return conn.execute(
        "SELECT * FROM screenshots WHERE submission_id = ? ORDER BY id", (submission_id,)
    ).fetchall()
```

- [ ] **Step 4: 跑测试确认通过**

```bash
python -m pytest tests/test_models_submissions.py -v
```

Expected: 4 个测试全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add tools/lab_submission/models.py tools/lab_submission/tests/test_models_submissions.py
git commit -m "feat(lab-submission): add submission/screenshot model functions"
```

---

## Task 4: 批改结果模型（AI 建议 + 教师复核 + 导出行）

**Files:**
- Modify: `tools/lab_submission/models.py`
- Test: `tools/lab_submission/tests/test_models_grades.py`

**Interfaces:**
- Consumes: Task 1-3 全部函数
- Produces: `models.upsert_ai_grade(conn, submission_id: int, ai_score: int | None, ai_feedback_json: str) -> None`；`models.get_grade(conn, submission_id: int) -> sqlite3.Row | None`；`models.review_grade(conn, submission_id: int, teacher_score: int | None, teacher_comment: str, release: bool) -> None`；`models.list_pending_for_grading(conn, lesson: str | None = None) -> list[sqlite3.Row]`；`models.export_rows(conn, lesson: str) -> list[dict]`

- [ ] **Step 1: 写失败测试**

```python
# tools/lab_submission/tests/test_models_grades.py
import json

import models


def _make_submission(conn, student_id="S001", lesson="03"):
    models.create_or_verify_student(conn, student_id, "张三", "pw123")
    return models.create_submission(conn, student_id, lesson, "报告正文")


def test_upsert_ai_grade_sets_status_ai_graded(db_conn):
    sub_id = _make_submission(db_conn)
    models.upsert_ai_grade(db_conn, sub_id, 88, json.dumps({"summary": "不错"}))

    grade = models.get_grade(db_conn, sub_id)
    assert grade["ai_score"] == 88
    assert grade["released"] == 0

    submission = models.get_submission(db_conn, sub_id)
    assert submission["status"] == "ai_graded"


def test_upsert_ai_grade_twice_updates_not_duplicates(db_conn):
    sub_id = _make_submission(db_conn)
    models.upsert_ai_grade(db_conn, sub_id, 60, json.dumps({}))
    models.upsert_ai_grade(db_conn, sub_id, 95, json.dumps({}))

    grade = models.get_grade(db_conn, sub_id)
    assert grade["ai_score"] == 95
    count = db_conn.execute(
        "SELECT COUNT(*) AS c FROM grades WHERE submission_id = ?", (sub_id,)
    ).fetchone()["c"]
    assert count == 1


def test_review_grade_release_updates_submission_status(db_conn):
    sub_id = _make_submission(db_conn)
    models.upsert_ai_grade(db_conn, sub_id, 70, json.dumps({}))

    models.review_grade(db_conn, sub_id, teacher_score=90, teacher_comment="很好", release=True)

    grade = models.get_grade(db_conn, sub_id)
    assert grade["teacher_score"] == 90
    assert grade["teacher_comment"] == "很好"
    assert grade["released"] == 1

    submission = models.get_submission(db_conn, sub_id)
    assert submission["status"] == "released"


def test_review_grade_without_prior_ai_grade_creates_row(db_conn):
    sub_id = _make_submission(db_conn)
    models.review_grade(db_conn, sub_id, teacher_score=100, teacher_comment="满分", release=False)
    grade = models.get_grade(db_conn, sub_id)
    assert grade["teacher_score"] == 100
    assert grade["released"] == 0


def test_list_pending_for_grading_excludes_graded(db_conn):
    sub1 = _make_submission(db_conn, "S001", "03")
    sub2 = _make_submission(db_conn, "S002", "03")
    models.upsert_ai_grade(db_conn, sub1, 80, json.dumps({}))

    pending = models.list_pending_for_grading(db_conn, "03")
    ids = [row["id"] for row in pending]
    assert sub2 in ids
    assert sub1 not in ids


def test_export_rows_joins_student_and_grade(db_conn):
    sub_id = _make_submission(db_conn)
    models.review_grade(db_conn, sub_id, teacher_score=77, teacher_comment="ok", release=True)

    rows = models.export_rows(db_conn, "03")
    assert len(rows) == 1
    assert rows[0]["student_id"] == "S001"
    assert rows[0]["name"] == "张三"
    assert rows[0]["teacher_score"] == 77
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_models_grades.py -v
```

Expected: FAIL（`upsert_ai_grade` 未定义）。

- [ ] **Step 3: 在 `models.py` 追加实现**

```python
def upsert_ai_grade(conn: sqlite3.Connection, submission_id: int, ai_score, ai_feedback_json: str) -> None:
    conn.execute(
        "INSERT INTO grades (submission_id, ai_score, ai_feedback_json, released, graded_at) "
        "VALUES (?, ?, ?, 0, ?) "
        "ON CONFLICT(submission_id) DO UPDATE SET "
        "ai_score = excluded.ai_score, "
        "ai_feedback_json = excluded.ai_feedback_json, "
        "graded_at = excluded.graded_at",
        (submission_id, ai_score, ai_feedback_json, now_iso()),
    )
    conn.execute(
        "UPDATE submissions SET status = 'ai_graded' WHERE id = ?", (submission_id,)
    )
    conn.commit()


def get_grade(conn: sqlite3.Connection, submission_id: int) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM grades WHERE submission_id = ?", (submission_id,)
    ).fetchone()


def review_grade(
    conn: sqlite3.Connection,
    submission_id: int,
    teacher_score,
    teacher_comment: str,
    release: bool,
) -> None:
    existing = get_grade(conn, submission_id)
    released_flag = 1 if release else 0
    if existing is None:
        conn.execute(
            "INSERT INTO grades (submission_id, teacher_score, teacher_comment, released, graded_at) "
            "VALUES (?, ?, ?, ?, ?)",
            (submission_id, teacher_score, teacher_comment, released_flag, now_iso()),
        )
    else:
        conn.execute(
            "UPDATE grades SET teacher_score = ?, teacher_comment = ?, released = ?, graded_at = ? "
            "WHERE submission_id = ?",
            (teacher_score, teacher_comment, released_flag, now_iso(), submission_id),
        )
    if release:
        conn.execute(
            "UPDATE submissions SET status = 'released' WHERE id = ?", (submission_id,)
        )
    conn.commit()


def list_pending_for_grading(conn: sqlite3.Connection, lesson: str | None = None) -> list[sqlite3.Row]:
    query = "SELECT * FROM submissions WHERE status = 'pending'"
    params: tuple = ()
    if lesson:
        query += " AND lesson = ?"
        params = (lesson,)
    query += " ORDER BY submitted_at ASC"
    return conn.execute(query, params).fetchall()


def export_rows(conn: sqlite3.Connection, lesson: str) -> list[dict]:
    rows = conn.execute(
        "SELECT s.student_id, st.name, s.submitted_at, s.status, "
        "g.ai_score, g.teacher_score, g.teacher_comment "
        "FROM submissions s "
        "JOIN students st ON st.student_id = s.student_id "
        "LEFT JOIN grades g ON g.submission_id = s.id "
        "WHERE s.lesson = ? ORDER BY s.submitted_at",
        (lesson,),
    ).fetchall()
    return [dict(row) for row in rows]
```

- [ ] **Step 4: 跑测试确认通过**

```bash
python -m pytest tests/test_models_grades.py -v
```

Expected: 6 个测试全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add tools/lab_submission/models.py tools/lab_submission/tests/test_models_grades.py
git commit -m "feat(lab-submission): add AI grade + teacher review model functions"
```

---

## Task 5: 评分标准抽取（从 `docs/NN/lab.md` 读章节）

**Files:**
- Create: `tools/lab_submission/rubric_loader.py`
- Test: `tools/lab_submission/tests/test_rubric_loader.py`

**Interfaces:**
- Produces: `rubric_loader.RubricNotFoundError`（异常类）；`rubric_loader.load_rubric(lesson: str, repo_root: pathlib.Path | None = None) -> str`

**背景（已核实）：** 各课 `lab.md` 的验收标准/报告要求标题编号不统一（`## 4. 验收标准`、`## 5. 验收标准`、`## 6. 验收标准` 都存在；报告要求有的叫"报告要求"有的叫"实验报告要求"），所以抽取逻辑按**关键词**匹配二级标题，不按固定编号。

- [ ] **Step 1: 写失败测试（用临时构造的 lab.md，覆盖不同编号写法）**

```python
# tools/lab_submission/tests/test_rubric_loader.py
import pytest

import rubric_loader

SAMPLE_LAB_MD = """# 第 3 次课实验指导书

## 1. 实验目标

跑通。

## 4. 验收标准

- [ ] 能跑通
- [ ] 数字对得上

## 5. 实验报告要求

1. 环境一句
2. 输出

## 6. 常见故障

无关内容，不应该被抽进去。
"""


def _make_repo(tmp_path, lesson="03", content=SAMPLE_LAB_MD):
    lab_dir = tmp_path / "docs" / lesson
    lab_dir.mkdir(parents=True)
    (lab_dir / "lab.md").write_text(content, encoding="utf-8")
    return tmp_path


def test_load_rubric_extracts_both_sections_regardless_of_numbering(tmp_path):
    repo_root = _make_repo(tmp_path)
    rubric = rubric_loader.load_rubric("03", repo_root=repo_root)
    assert "## 4. 验收标准" in rubric
    assert "能跑通" in rubric
    assert "## 5. 实验报告要求" in rubric
    assert "环境一句" in rubric
    assert "常见故障" not in rubric


def test_load_rubric_missing_lesson_raises(tmp_path):
    repo_root = _make_repo(tmp_path)
    with pytest.raises(rubric_loader.RubricNotFoundError):
        rubric_loader.load_rubric("99", repo_root=repo_root)


def test_load_rubric_no_matching_sections_raises(tmp_path):
    repo_root = _make_repo(tmp_path, content="# 空文档\n\n啥都没有\n")
    with pytest.raises(rubric_loader.RubricNotFoundError):
        rubric_loader.load_rubric("03", repo_root=repo_root)


def test_load_rubric_against_real_lesson03_lab_md():
    """回归测试：确保真实仓库里 docs/03/lab.md 能被正确抽取。"""
    rubric = rubric_loader.load_rubric("03")
    assert "验收标准" in rubric
    assert "报告要求" in rubric
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_rubric_loader.py -v
```

Expected: FAIL（`ModuleNotFoundError: No module named 'rubric_loader'`）。

- [ ] **Step 3: 写 `rubric_loader.py`**

```python
"""从各课 docs/NN/lab.md 里抽取“验收标准”“报告要求”章节，当 AI 批改的评分标准。

标题编号在各课之间不统一（见课程 docs/NN/lab.md 历史），所以按关键词匹配二级
标题（`## `），不依赖固定编号。
"""
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]  # tools/lab_submission/ -> 仓库根

SECTION_KEYWORDS = ("验收标准", "报告要求")


class RubricNotFoundError(Exception):
    """找不到 lab.md，或 lab.md 里没有能匹配到的章节时抛出。"""


def _extract_section(lines: list[str], keyword: str) -> str:
    start = None
    for i, line in enumerate(lines):
        if line.startswith("## ") and keyword in line:
            start = i
            break
    if start is None:
        return ""
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if lines[j].startswith("## "):
            end = j
            break
    return "\n".join(lines[start:end]).strip()


def load_rubric(lesson: str, repo_root: Path | None = None) -> str:
    root = repo_root or REPO_ROOT
    lab_path = root / "docs" / lesson / "lab.md"
    if not lab_path.exists():
        raise RubricNotFoundError(f"找不到 {lab_path}")

    lines = lab_path.read_text(encoding="utf-8").splitlines()
    parts = [_extract_section(lines, kw) for kw in SECTION_KEYWORDS]
    combined = "\n\n".join(p for p in parts if p)
    if not combined:
        raise RubricNotFoundError(
            f"{lab_path} 里没找到包含 {SECTION_KEYWORDS} 关键词的二级标题章节"
        )
    return combined
```

- [ ] **Step 4: 跑测试确认通过**

```bash
python -m pytest tests/test_rubric_loader.py -v
```

Expected: 4 个测试全部 PASS（最后一个是对真实 `docs/03/lab.md` 的回归测试）。

- [ ] **Step 5: Commit**

```bash
git add tools/lab_submission/rubric_loader.py tools/lab_submission/tests/test_rubric_loader.py
git commit -m "feat(lab-submission): extract grading rubric from lesson lab.md files"
```

---

## Task 6: Flask app 骨架（app factory + 基础模板 + 首页跳转）

**Files:**
- Create: `tools/lab_submission/app.py`
- Create: `tools/lab_submission/templates/base.html`
- Create: `tools/lab_submission/static/style.css`
- Test: `tools/lab_submission/tests/test_app_basic.py`

**Interfaces:**
- Consumes: `models.get_connection`、`models.init_db`（Task 1）
- Produces: `app.create_app(config: dict | None = None) -> flask.Flask`；`app.LESSONS: list[str]`（`["01".."12"]`）

- [ ] **Step 1: 在 `conftest.py` 追加 `app`/`client` fixture**

```python
# 追加到 tools/lab_submission/tests/conftest.py 末尾
import app as app_module


@pytest.fixture
def app(tmp_path):
    flask_app = app_module.create_app(
        {
            "DB_PATH": str(tmp_path / "test.db"),
            "UPLOAD_DIR": str(tmp_path / "uploads"),
            "ADMIN_PASSWORD": "testpass",
            "SECRET_KEY": "test-secret",
            "TESTING": True,
        }
    )
    yield flask_app


@pytest.fixture
def client(app):
    return app.test_client()
```

- [ ] **Step 2: 写失败测试**

```python
# tools/lab_submission/tests/test_app_basic.py
def test_index_redirects_to_submit(client):
    resp = client.get("/")
    assert resp.status_code == 302
    assert resp.headers["Location"].endswith("/submit")


def test_lessons_list_has_twelve_entries():
    import app as app_module

    assert app_module.LESSONS == [f"{i:02d}" for i in range(1, 13)]
```

- [ ] **Step 3: 跑测试确认失败**

```bash
python -m pytest tests/test_app_basic.py -v
```

Expected: FAIL（`ModuleNotFoundError: No module named 'app'`）。

- [ ] **Step 4: 写 `templates/base.html`**

```html
<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{% block title %}实验报告提交{% endblock %}</title>
  <link rel="stylesheet" href="{{ url_for('static', filename='style.css') }}">
</head>
<body>
  <main class="page">
    {% block content %}{% endblock %}
  </main>
</body>
</html>
```

- [ ] **Step 5: 写 `static/style.css`**

```css
body { font-family: system-ui, "Microsoft YaHei", sans-serif; background:#f6f7f9; color:#1b2533; margin:0; }
.page { max-width: 900px; margin: 0 auto; padding: 24px; }
h1 { margin-top: 0; }
form label { display:block; margin: 12px 0; font-weight: 600; }
input, select, textarea { width:100%; padding:8px; font-size:16px; box-sizing:border-box; font-weight:normal; margin-top:4px; }
button { margin-top:16px; padding:10px 20px; font-size:16px; cursor:pointer; }
table { width:100%; border-collapse:collapse; margin-top:16px; }
th, td { border:1px solid #ccc; padding:6px 10px; text-align:left; }
.errors { color:#b00020; }
.screenshots img { max-width:220px; margin:8px 8px 0 0; border:1px solid #ccc; }
pre.report-text, pre.ai-feedback { white-space:pre-wrap; background:#fff; border:1px solid #ddd; padding:12px; }
tr.status-pending { background:#fff8e1; }
tr.status-ai_graded { background:#e3f2fd; }
tr.status-released { background:#e8f5e9; }
```

- [ ] **Step 6: 写 `app.py`**

```python
"""学生实验报告提交 + 教师复核系统。用法：cd 到本目录后 `python app.py`。"""
from pathlib import Path

from flask import Flask, g, redirect, url_for

import models

LESSONS = [f"{i:02d}" for i in range(1, 13)]


def create_app(config: dict | None = None) -> Flask:
    app = Flask(__name__)
    app.config.update(
        DB_PATH=str(Path(__file__).parent / "data.db"),
        UPLOAD_DIR=str(Path(__file__).parent / "uploads"),
        ADMIN_PASSWORD="changeme",
        SECRET_KEY="dev-secret-change-me",
        MAX_CONTENT_LENGTH=20 * 1024 * 1024,  # 一次提交最多 20MB（含多张截图）
    )
    if config:
        app.config.update(config)

    Path(app.config["UPLOAD_DIR"]).mkdir(parents=True, exist_ok=True)

    def get_db():
        if "db" not in g:
            g.db = models.get_connection(app.config["DB_PATH"])
            models.init_db(g.db)
        return g.db

    @app.teardown_appcontext
    def close_db(exception=None):
        db = g.pop("db", None)
        if db is not None:
            db.close()

    app.get_db = get_db

    @app.route("/")
    def index():
        return redirect(url_for("submit"))

    return app


if __name__ == "__main__":
    import os

    application = create_app(
        {
            "ADMIN_PASSWORD": os.environ.get("LAB_ADMIN_PASSWORD", "changeme"),
            "SECRET_KEY": os.environ.get("FLASK_SECRET_KEY", "dev-secret-change-me"),
        }
    )
    application.run(host="0.0.0.0", port=5000, debug=False)
```

注：`submit` 这个 endpoint 现在还没定义，Task 7 会加上；在那之前 `test_index_redirects_to_submit` 会因为 `url_for('submit')` 找不到端点而报错，属于预期——继续往下做 Task 7 即可消化。

- [ ] **Step 7: 跑测试确认部分通过**

```bash
python -m pytest tests/test_app_basic.py -v
```

Expected: `test_lessons_list_has_twelve_entries` PASS；`test_index_redirects_to_submit` 这条先 FAIL（缺 `submit` endpoint），留到 Task 7 一起变绿——在本步骤的 commit message 里说明这一点。

- [ ] **Step 8: Commit**

```bash
git add tools/lab_submission/app.py tools/lab_submission/templates/base.html \
        tools/lab_submission/static/style.css tools/lab_submission/tests/test_app_basic.py \
        tools/lab_submission/tests/conftest.py
git commit -m "feat(lab-submission): add Flask app factory skeleton and base template

test_index_redirects_to_submit intentionally still failing here (submit
route lands in the next task); test_lessons_list_has_twelve_entries passes."
```

---

## Task 7: `/submit` 表单（学号+密码+课次+正文+截图上传）

**Files:**
- Modify: `tools/lab_submission/app.py`
- Create: `tools/lab_submission/templates/submit.html`
- Create: `tools/lab_submission/templates/submit_success.html`
- Test: `tools/lab_submission/tests/test_app_submit.py`

**Interfaces:**
- Consumes: `models.create_or_verify_student`、`models.AuthError`、`models.create_submission`、`models.add_screenshot`（Task 2/3）
- Produces: 路由 `GET/POST /submit`（endpoint 名 `submit`），提交成功后渲染 `submit_success.html`

- [ ] **Step 1: 写失败测试**

```python
# tools/lab_submission/tests/test_app_submit.py
import io


def _form(**overrides):
    base = {
        "student_id": "S001",
        "name": "张三",
        "password": "pw123",
        "lesson": "03",
        "report_text": "报告正文内容",
    }
    base.update(overrides)
    return base


def test_get_submit_shows_form(client):
    resp = client.get("/submit")
    assert resp.status_code == 200
    assert "学号".encode() in resp.data


def test_post_submit_without_screenshots_succeeds(client):
    resp = client.post("/submit", data=_form(), content_type="multipart/form-data")
    assert resp.status_code == 200
    assert "提交成功".encode() in resp.data


def test_post_submit_with_screenshot_saves_file(client, app):
    data = _form()
    data["screenshots"] = (io.BytesIO(b"fake-png-bytes"), "shot.png")
    resp = client.post("/submit", data=data, content_type="multipart/form-data")
    assert resp.status_code == 200

    upload_dir = app.config["UPLOAD_DIR"]
    from pathlib import Path

    saved = list(Path(upload_dir).rglob("*.png"))
    assert len(saved) == 1


def test_post_submit_rejects_bad_extension(client):
    data = _form()
    data["screenshots"] = (io.BytesIO(b"not an image"), "shot.exe")
    resp = client.post("/submit", data=data, content_type="multipart/form-data")
    assert resp.status_code == 200
    assert "不支持的文件类型".encode() in resp.data


def test_post_submit_wrong_password_for_existing_student_rejected(client):
    client.post("/submit", data=_form(), content_type="multipart/form-data")
    resp = client.post(
        "/submit", data=_form(password="different"), content_type="multipart/form-data"
    )
    assert resp.status_code == 400
    assert "密码不对".encode() in resp.data


def test_post_submit_missing_report_text_rejected(client):
    resp = client.post(
        "/submit", data=_form(report_text=""), content_type="multipart/form-data"
    )
    assert resp.status_code == 400


def test_index_redirects_to_submit(client):
    resp = client.get("/")
    assert resp.status_code == 302
    assert resp.headers["Location"].endswith("/submit")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_app_submit.py -v
```

Expected: FAIL（404，`/submit` 还没注册）。

- [ ] **Step 3: 写 `templates/submit.html`**

```html
{% extends "base.html" %}
{% block title %}提交实验报告{% endblock %}
{% block content %}
<h1>提交实验报告</h1>

{% if errors %}
<ul class="errors">
  {% for e in errors %}<li>{{ e }}</li>{% endfor %}
</ul>
{% endif %}

<form method="post" enctype="multipart/form-data">
  <label>学号
    <input type="text" name="student_id" value="{{ form.student_id if form else '' }}" required>
  </label>
  <label>姓名
    <input type="text" name="name" value="{{ form.name if form else '' }}" required>
  </label>
  <label>密码（第一次提交自动注册，之后每次提交要用同一个密码）
    <input type="password" name="password" required>
  </label>
  <label>课次
    <select name="lesson" required>
      <option value="">请选择</option>
      {% for l in lessons %}
      <option value="{{ l }}" {% if form and form.lesson == l %}selected{% endif %}>第 {{ l|int }} 次课</option>
      {% endfor %}
    </select>
  </label>
  <label>报告正文
    <textarea name="report_text" rows="16" required>{{ form.report_text if form else '' }}</textarea>
  </label>
  <label>截图（可多选，png/jpg/jpeg，单张不超过 5MB）
    <input type="file" name="screenshots" accept=".png,.jpg,.jpeg" multiple>
  </label>
  <button type="submit">提交</button>
</form>
{% endblock %}
```

- [ ] **Step 4: 写 `templates/submit_success.html`**

```html
{% extends "base.html" %}
{% block title %}提交成功{% endblock %}
{% block content %}
<h1>提交成功</h1>
<p>你的提交编号是 <strong>#{{ submission_id }}</strong>，建议截图留存。</p>
{% if file_errors %}
<h2>以下截图未能保存</h2>
<ul class="errors">
  {% for e in file_errors %}<li>{{ e }}</li>{% endfor %}
</ul>
{% endif %}
<p><a href="{{ url_for('submit') }}">再提交一份</a></p>
{% endblock %}
```

- [ ] **Step 5: 在 `app.py` 里追加路由（`create_app` 函数内，`index` 路由之后）**

```python
import uuid
from flask import render_template, request

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
```

（这三行放在文件顶部 import 区/常量区，不在函数内。）

```python
    @app.route("/submit", methods=["GET"])
    def submit():
        return render_template("submit.html", lessons=LESSONS)

    @app.route("/submit", methods=["POST"])
    def submit_post():
        db = get_db()
        student_id = request.form.get("student_id", "").strip()
        name = request.form.get("name", "").strip()
        password = request.form.get("password", "")
        lesson = request.form.get("lesson", "")
        report_text = request.form.get("report_text", "").strip()

        errors = []
        if not student_id:
            errors.append("学号不能为空")
        if not name:
            errors.append("姓名不能为空")
        if not password:
            errors.append("密码不能为空")
        if lesson not in LESSONS:
            errors.append("请选择有效课次")
        if not report_text:
            errors.append("报告正文不能为空")
        if errors:
            return render_template("submit.html", lessons=LESSONS, errors=errors, form=request.form), 400

        try:
            models.create_or_verify_student(db, student_id, name, password)
        except models.AuthError as exc:
            return render_template("submit.html", lessons=LESSONS, errors=[str(exc)], form=request.form), 400

        submission_id = models.create_submission(db, student_id, lesson, report_text)

        upload_dir = Path(app.config["UPLOAD_DIR"]) / student_id / lesson
        upload_dir.mkdir(parents=True, exist_ok=True)

        file_errors = []
        for f in request.files.getlist("screenshots"):
            if not f or not f.filename:
                continue
            ext = f.filename.rsplit(".", 1)[-1].lower() if "." in f.filename else ""
            if ext not in ALLOWED_EXTENSIONS:
                file_errors.append(f"{f.filename}：不支持的文件类型，只允许 png/jpg/jpeg")
                continue
            dest = upload_dir / f"{uuid.uuid4().hex}.{ext}"
            f.save(str(dest))
            if dest.stat().st_size > MAX_FILE_SIZE:
                dest.unlink()
                file_errors.append(f"{f.filename}：超过 5MB 大小限制")
                continue
            rel_path = dest.relative_to(Path(app.config["UPLOAD_DIR"])).as_posix()
            models.add_screenshot(db, submission_id, rel_path)

        return render_template(
            "submit_success.html", submission_id=submission_id, file_errors=file_errors
        )
```

（把这两个路由函数加在 `create_app` 里 `index` 路由定义之后、`return app` 之前；`render_template`/`request`/`uuid` 的 import 加到文件顶部。）

- [ ] **Step 6: 跑测试确认通过**

```bash
python -m pytest tests/test_app_submit.py tests/test_app_basic.py -v
```

Expected: 全部 PASS（Task 6 里留的那条 `test_index_redirects_to_submit` 现在也变绿）。

- [ ] **Step 7: Commit**

```bash
git add tools/lab_submission/app.py tools/lab_submission/templates/submit.html \
        tools/lab_submission/templates/submit_success.html tools/lab_submission/tests/test_app_submit.py
git commit -m "feat(lab-submission): add /submit form with screenshot upload"
```

---

## Task 8: 教师登录/登出

**Files:**
- Modify: `tools/lab_submission/app.py`
- Create: `tools/lab_submission/templates/admin_login.html`
- Test: `tools/lab_submission/tests/test_app_admin_auth.py`

**Interfaces:**
- Produces: `GET/POST /admin/login`（endpoint `admin_login`）、`POST /admin/logout`（endpoint `admin_logout`）、`require_admin()` 内部辅助函数（判断 `session["is_admin"]`）

- [ ] **Step 1: 写失败测试**

```python
# tools/lab_submission/tests/test_app_admin_auth.py
def test_admin_login_page_loads(client):
    resp = client.get("/admin/login")
    assert resp.status_code == 200


def test_admin_login_wrong_password_rejected(client):
    resp = client.post("/admin/login", data={"password": "wrong"})
    assert resp.status_code == 400


def test_admin_login_correct_password_sets_session(client):
    resp = client.post("/admin/login", data={"password": "testpass"})
    assert resp.status_code == 302
    with client.session_transaction() as sess:
        assert sess.get("is_admin") is True


def test_admin_logout_clears_session(client):
    client.post("/admin/login", data={"password": "testpass"})
    client.post("/admin/logout")
    with client.session_transaction() as sess:
        assert not sess.get("is_admin")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_app_admin_auth.py -v
```

Expected: FAIL（404，路由未注册）。

- [ ] **Step 3: 写 `templates/admin_login.html`**

```html
{% extends "base.html" %}
{% block title %}教师登录{% endblock %}
{% block content %}
<h1>教师登录</h1>
{% if error %}<p class="errors">{{ error }}</p>{% endif %}
<form method="post">
  <label>口令 <input type="password" name="password" required></label>
  <button type="submit">登录</button>
</form>
{% endblock %}
```

- [ ] **Step 4: 在 `app.py` 里追加（顶部 import 增加 `session`；`submit_post` 路由之后）**

```python
from flask import session
```

```python
    def require_admin() -> bool:
        return bool(session.get("is_admin"))

    @app.route("/admin/login", methods=["GET", "POST"])
    def admin_login():
        if request.method == "GET":
            return render_template("admin_login.html")
        password = request.form.get("password", "")
        if password == app.config["ADMIN_PASSWORD"]:
            session["is_admin"] = True
            return redirect(url_for("admin_list"))
        return render_template("admin_login.html", error="口令不对"), 400

    @app.route("/admin/logout", methods=["POST"])
    def admin_logout():
        session.pop("is_admin", None)
        return redirect(url_for("admin_login"))
```

注：这里引用了 `admin_list` endpoint，Task 9 才会定义；在那之前跑 `test_admin_login_correct_password_sets_session` 会因为 `url_for('admin_list')` 报 `BuildError`。

- [ ] **Step 5: 跑测试，确认除"登录成功跳转"外全部通过**

```bash
python -m pytest tests/test_app_admin_auth.py -v
```

Expected: `test_admin_login_page_loads`、`test_admin_login_wrong_password_rejected`、`test_admin_logout_clears_session` PASS；`test_admin_login_correct_password_sets_session` 先 FAIL（缺 `admin_list` endpoint），留到 Task 9 一起变绿。

- [ ] **Step 6: Commit**

```bash
git add tools/lab_submission/app.py tools/lab_submission/templates/admin_login.html \
        tools/lab_submission/tests/test_app_admin_auth.py
git commit -m "feat(lab-submission): add admin login/logout

test_admin_login_correct_password_sets_session intentionally still
failing here (admin_list endpoint lands in the next task)."
```

---

## Task 9: 教师端列表 + 详情 + 复核发布

**Files:**
- Modify: `tools/lab_submission/app.py`
- Create: `tools/lab_submission/templates/admin_list.html`
- Create: `tools/lab_submission/templates/admin_detail.html`
- Test: `tools/lab_submission/tests/test_app_admin_views.py`

**Interfaces:**
- Consumes: `models.list_submissions`、`models.get_submission`、`models.get_screenshots`、`models.get_grade`、`models.review_grade`（Task 3/4）；`require_admin()`（Task 8）
- Produces: `GET /admin`（endpoint `admin_list`）、`GET/POST /admin/submission/<int:submission_id>`（endpoint `admin_detail`）、`GET /uploads/<path:relpath>`（endpoint `uploaded_file`，教师登录后才能看截图原图）

- [ ] **Step 1: 写失败测试**

```python
# tools/lab_submission/tests/test_app_admin_views.py
def _login(client):
    client.post("/admin/login", data={"password": "testpass"})


def _submit(client, **overrides):
    data = {
        "student_id": "S001",
        "name": "张三",
        "password": "pw123",
        "lesson": "03",
        "report_text": "报告正文",
    }
    data.update(overrides)
    client.post("/submit", data=data, content_type="multipart/form-data")


def test_admin_list_requires_login(client):
    resp = client.get("/admin")
    assert resp.status_code == 302
    assert "/admin/login" in resp.headers["Location"]


def test_admin_list_shows_submission(client):
    _submit(client)
    _login(client)
    resp = client.get("/admin")
    assert resp.status_code == 200
    assert "S001".encode() in resp.data


def test_admin_list_filters_by_lesson(client):
    _submit(client, lesson="03")
    _submit(client, student_id="S002", lesson="04")
    _login(client)

    resp = client.get("/admin?lesson=03")
    assert "S001".encode() in resp.data
    assert "S002".encode() not in resp.data


def test_admin_detail_requires_login(client):
    resp = client.get("/admin/submission/1")
    assert resp.status_code == 302


def test_admin_detail_shows_report_text(client):
    _submit(client)
    _login(client)
    resp = client.get("/admin/submission/1")
    assert resp.status_code == 200
    assert "报告正文".encode() in resp.data


def test_admin_detail_missing_submission_404(client):
    _login(client)
    resp = client.get("/admin/submission/999")
    assert resp.status_code == 404


def test_admin_review_saves_score_and_releases(client):
    _submit(client)
    _login(client)
    resp = client.post(
        "/admin/submission/1",
        data={"teacher_score": "90", "teacher_comment": "很好", "release": "on"},
    )
    assert resp.status_code == 302

    import models

    conn = models.get_connection(client.application.config["DB_PATH"])
    grade = models.get_grade(conn, 1)
    assert grade["teacher_score"] == 90
    assert grade["released"] == 1
    conn.close()
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_app_admin_views.py -v
```

Expected: FAIL（404，路由未注册）。

- [ ] **Step 3: 写 `templates/admin_list.html`**

```html
{% extends "base.html" %}
{% block title %}提交列表{% endblock %}
{% block content %}
<h1>提交列表</h1>
<form method="get">
  <label>课次
    <select name="lesson" onchange="this.form.submit()">
      <option value="">全部</option>
      {% for l in lessons %}
      <option value="{{ l }}" {% if selected_lesson == l %}selected{% endif %}>第 {{ l|int }} 次课</option>
      {% endfor %}
    </select>
  </label>
</form>
{% if selected_lesson %}
<p><a href="{{ url_for('admin_export', lesson=selected_lesson) }}">导出本课次 Excel</a></p>
{% endif %}
<table>
  <thead><tr><th>ID</th><th>学号</th><th>姓名</th><th>课次</th><th>提交时间</th><th>状态</th></tr></thead>
  <tbody>
    {% for s in submissions %}
    <tr class="status-{{ s.status }}">
      <td><a href="{{ url_for('admin_detail', submission_id=s.id) }}">{{ s.id }}</a></td>
      <td>{{ s.student_id }}</td>
      <td>{{ s.student_name }}</td>
      <td>{{ s.lesson }}</td>
      <td>{{ s.submitted_at }}</td>
      <td>{{ s.status }}</td>
    </tr>
    {% endfor %}
  </tbody>
</table>
{% endblock %}
```

（`admin_export` 是 Task 10 才定义的 endpoint；这里先写上，Task 10 完成前如果 `selected_lesson` 有值会在渲染时报 `BuildError`——为避免这个模板在 Task 9 阶段就报错，`selected_lesson` 恒不为空时才会触发，而测试里 `test_admin_list_filters_by_lesson` 会用到 `?lesson=03`，所以必须紧跟着做 Task 10，或者暂时注释掉这一行。按计划顺序做（Task 9 做完立刻做 Task 10）不会让主线测试变红超过一个任务的时间。）

- [ ] **Step 4: 写 `templates/admin_detail.html`**

```html
{% extends "base.html" %}
{% block title %}提交详情 #{{ submission.id }}{% endblock %}
{% block content %}
<h1>提交详情 #{{ submission.id }}</h1>
<p>学号：{{ submission.student_id }}　课次：{{ submission.lesson }}　提交时间：{{ submission.submitted_at }}　状态：{{ submission.status }}</p>

<h2>报告正文</h2>
<pre class="report-text">{{ submission.report_text }}</pre>

<h2>截图</h2>
{% if screenshots %}
<div class="screenshots">
  {% for sc in screenshots %}
  <a href="{{ url_for('uploaded_file', relpath=sc.file_path) }}" target="_blank">
    <img src="{{ url_for('uploaded_file', relpath=sc.file_path) }}" alt="screenshot">
  </a>
  {% endfor %}
</div>
{% else %}
<p>没有截图</p>
{% endif %}

<h2>AI 批改建议</h2>
{% if grade and grade.ai_feedback_json %}
<pre class="ai-feedback">{{ grade.ai_feedback_json }}</pre>
<p>AI 建议分：{{ grade.ai_score }}（仅供参考，尚未经过教师确认）</p>
{% else %}
<p>还没有 AI 批改结果。</p>
{% endif %}

<h2>教师复核</h2>
<form method="post">
  <label>最终分数
    <input type="number" name="teacher_score" min="0" max="100"
      value="{{ grade.teacher_score if grade and grade.teacher_score is not none else '' }}">
  </label>
  <label>评语
    <textarea name="teacher_comment" rows="4">{{ grade.teacher_comment if grade and grade.teacher_comment else '' }}</textarea>
  </label>
  <label><input type="checkbox" name="release" {% if grade and grade.released %}checked{% endif %}> 发布给学生</label>
  <button type="submit">保存</button>
</form>
{% endblock %}
```

- [ ] **Step 5: 在 `app.py` 里追加（`admin_logout` 路由之后；顶部 import 增加 `send_from_directory`）**

```python
from flask import send_from_directory
```

```python
    @app.route("/admin", methods=["GET"])
    def admin_list():
        if not require_admin():
            return redirect(url_for("admin_login"))
        db = get_db()
        lesson = request.args.get("lesson") or None
        submissions = models.list_submissions(db, lesson)
        return render_template(
            "admin_list.html", submissions=submissions, lessons=LESSONS, selected_lesson=lesson
        )

    @app.route("/admin/submission/<int:submission_id>", methods=["GET", "POST"])
    def admin_detail(submission_id):
        if not require_admin():
            return redirect(url_for("admin_login"))
        db = get_db()
        if request.method == "POST":
            teacher_score = request.form.get("teacher_score", type=int)
            teacher_comment = request.form.get("teacher_comment", "")
            release = request.form.get("release") == "on"
            models.review_grade(db, submission_id, teacher_score, teacher_comment, release)
            return redirect(url_for("admin_detail", submission_id=submission_id))

        submission = models.get_submission(db, submission_id)
        if submission is None:
            return "提交不存在", 404
        screenshots = models.get_screenshots(db, submission_id)
        grade = models.get_grade(db, submission_id)
        return render_template(
            "admin_detail.html", submission=submission, screenshots=screenshots, grade=grade
        )

    @app.route("/uploads/<path:relpath>")
    def uploaded_file(relpath):
        if not require_admin():
            return redirect(url_for("admin_login"))
        return send_from_directory(app.config["UPLOAD_DIR"], relpath)
```

- [ ] **Step 6: 跑测试**

```bash
python -m pytest tests/test_app_admin_views.py -v
```

Expected: 大部分 PASS；`test_admin_list_filters_by_lesson` 因为模板引用了还不存在的 `admin_export` endpoint 而 FAIL（`BuildError`）——这是预期的，Task 10 会补上。

- [ ] **Step 7: Commit**

```bash
git add tools/lab_submission/app.py tools/lab_submission/templates/admin_list.html \
        tools/lab_submission/templates/admin_detail.html tools/lab_submission/tests/test_app_admin_views.py
git commit -m "feat(lab-submission): add admin list/detail/review views

test_admin_list_filters_by_lesson intentionally still failing here
(admin_export endpoint used by the template lands in the next task)."
```

---

## Task 10: 导出 Excel

**Files:**
- Create: `tools/lab_submission/export.py`
- Modify: `tools/lab_submission/app.py`
- Test: `tools/lab_submission/tests/test_export.py`
- Test: `tools/lab_submission/tests/test_app_admin_views.py`（把 Task 9 留下的那条测试跑绿，无需改测试代码本身）

**Interfaces:**
- Consumes: `models.export_rows`（Task 4）
- Produces: `export.build_workbook(rows: list[dict]) -> io.BytesIO`；路由 `GET /admin/export?lesson=NN`（endpoint `admin_export`）

- [ ] **Step 1: 写失败测试 `tests/test_export.py`**

```python
# tools/lab_submission/tests/test_export.py
from openpyxl import load_workbook

import export


def test_build_workbook_has_header_and_rows():
    rows = [
        {
            "student_id": "S001",
            "name": "张三",
            "submitted_at": "2026-09-09T00:00:00+00:00",
            "status": "released",
            "ai_score": 80,
            "teacher_score": 90,
            "teacher_comment": "不错",
        }
    ]
    buf = export.build_workbook(rows)
    wb = load_workbook(buf)
    ws = wb.active
    header = [cell.value for cell in ws[1]]
    assert header == ["学号", "姓名", "提交时间", "状态", "AI建议分", "老师最终分", "评语"]
    data_row = [cell.value for cell in ws[2]]
    assert data_row[0] == "S001"
    assert data_row[5] == 90
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_export.py -v
```

Expected: FAIL（`ModuleNotFoundError: No module named 'export'`）。

- [ ] **Step 3: 写 `export.py`**

```python
"""把提交+分数导出成 Excel 报表，供老师存档/发邮件。"""
import io

from openpyxl import Workbook

COLUMNS = ["学号", "姓名", "提交时间", "状态", "AI建议分", "老师最终分", "评语"]


def build_workbook(rows: list[dict]) -> io.BytesIO:
    wb = Workbook()
    ws = wb.active
    ws.title = "grades"
    ws.append(COLUMNS)
    for row in rows:
        ws.append(
            [
                row.get("student_id", ""),
                row.get("name", ""),
                row.get("submitted_at", ""),
                row.get("status", ""),
                row.get("ai_score", ""),
                row.get("teacher_score", ""),
                row.get("teacher_comment", ""),
            ]
        )
    buf = io.BytesIO()
    wb.save(buf)
    buf.seek(0)
    return buf
```

- [ ] **Step 4: 跑测试确认通过**

```bash
python -m pytest tests/test_export.py -v
```

Expected: PASS。

- [ ] **Step 5: 在 `app.py` 里追加路由（顶部 import 增加 `send_file` 和 `export` 模块；`uploaded_file` 路由之后）**

```python
from flask import send_file
import export
```

```python
    @app.route("/admin/export")
    def admin_export():
        if not require_admin():
            return redirect(url_for("admin_login"))
        lesson = request.args.get("lesson", "")
        if lesson not in LESSONS:
            return "请指定有效课次，例如 ?lesson=03", 400
        db = get_db()
        rows = models.export_rows(db, lesson)
        buf = export.build_workbook(rows)
        return send_file(
            buf,
            mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            as_attachment=True,
            download_name=f"lesson-{lesson}-grades.xlsx",
        )
```

- [ ] **Step 6: 跑全部 app 测试确认 Task 9 留的那条也变绿**

```bash
python -m pytest tests/ -v
```

Expected: 全部 PASS（包括 Task 9 里 `test_admin_list_filters_by_lesson`）。

- [ ] **Step 7: Commit**

```bash
git add tools/lab_submission/export.py tools/lab_submission/app.py tools/lab_submission/tests/test_export.py
git commit -m "feat(lab-submission): add Excel export for admin"
```

---

## Task 11: AI 批改脚本 `grade.py`

**Files:**
- Create: `tools/lab_submission/grade.py`
- Test: `tools/lab_submission/tests/test_grade.py`

**Interfaces:**
- Consumes: `models.list_pending_for_grading`、`models.get_screenshots`、`models.upsert_ai_grade`（Task 3/4）；`rubric_loader.load_rubric`（Task 5）
- Produces: `grade.build_prompt(rubric: str, report_text: str) -> str`；`grade.grade_one(client, rubric: str, report_text: str, screenshot_paths: list[Path]) -> dict`；`grade.main(argv=None) -> int`（CLI 入口，供 `python grade.py` 与测试共用）

- [ ] **Step 1: 写失败测试（用假的 Anthropic client，不打真实 API）**

```python
# tools/lab_submission/tests/test_grade.py
import json
from types import SimpleNamespace

import grade
import models


class FakeTextBlock:
    def __init__(self, text):
        self.type = "text"
        self.text = text


class FakeMessages:
    def __init__(self, response_json):
        self.response_json = response_json
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        return SimpleNamespace(content=[FakeTextBlock(json.dumps(self.response_json))])


class FakeClient:
    def __init__(self, response_json):
        self.messages = FakeMessages(response_json)


def test_build_prompt_includes_rubric_and_report():
    prompt = grade.build_prompt("评分标准内容", "学生报告内容")
    assert "评分标准内容" in prompt
    assert "学生报告内容" in prompt


def test_grade_one_parses_json_response():
    fake = FakeClient({"suggested_score": 88, "summary": "不错", "items": []})
    result = grade.grade_one(fake, "标准", "报告", screenshot_paths=[])
    assert result["suggested_score"] == 88
    assert fake.messages.calls[0]["model"] == grade.MODEL


def test_main_grades_pending_submissions_and_writes_back(tmp_path, monkeypatch):
    db_path = tmp_path / "test.db"
    conn = models.get_connection(str(db_path))
    models.init_db(conn)
    models.create_or_verify_student(conn, "S001", "张三", "pw123")
    models.create_submission(conn, "S001", "03", "跑通了，输出和讲义一致")
    conn.close()

    fake_client = FakeClient({"suggested_score": 92, "summary": "验收标准都满足"})
    monkeypatch.setattr(grade.anthropic, "Anthropic", lambda api_key: fake_client)
    monkeypatch.setenv("ANTHROPIC_API_KEY", "fake-key-for-test")

    exit_code = grade.main(
        ["--lesson", "03", "--db", str(db_path), "--upload-dir", str(tmp_path / "uploads")]
    )
    assert exit_code == 0

    conn = models.get_connection(str(db_path))
    row = models.get_grade(conn, 1)
    assert row["ai_score"] == 92
    conn.close()


def test_main_without_api_key_returns_error(tmp_path, monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    exit_code = grade.main(["--db", str(tmp_path / "test.db")])
    assert exit_code == 1


def test_main_with_nothing_pending_returns_zero(tmp_path, monkeypatch):
    db_path = tmp_path / "test.db"
    conn = models.get_connection(str(db_path))
    models.init_db(conn)
    conn.close()

    monkeypatch.setenv("ANTHROPIC_API_KEY", "fake-key-for-test")
    exit_code = grade.main(["--db", str(db_path)])
    assert exit_code == 0
```

- [ ] **Step 2: 跑测试确认失败**

```bash
python -m pytest tests/test_grade.py -v
```

Expected: FAIL（`ModuleNotFoundError: No module named 'grade'`）。

- [ ] **Step 3: 写 `grade.py`**

```python
#!/usr/bin/env python3
"""AI 批改脚本：读取待批改提交，调用 Claude API 打分建议，写回数据库。

结果只写入 grades.ai_score / ai_feedback_json，submissions.status 变成
'ai_graded'——不会自动发布给学生，教师必须在 /admin 里复核后手动发布。

用法：
    python grade.py                 # 批改所有 pending 提交
    python grade.py --lesson 03     # 只批改第 3 次课
"""
import argparse
import base64
import json
import os
import sys
from pathlib import Path

import anthropic

import models
import rubric_loader

MODEL = "claude-sonnet-5"

SYSTEM_PROMPT = (
    "你是这门 LoongArch 汇编课程的助教，负责给学生的实验报告打初步分数建议。"
    "只依据给定的验收标准和报告要求评分，不要编造学生没有提供的信息，"
    "拿不准的地方在 note 里说明，不要给出虚假的确定性。"
    "只输出一个 JSON 对象，不要输出任何其他文字，不要用 markdown 代码块包裹。"
)


def build_prompt(rubric: str, report_text: str) -> str:
    return (
        f"## 本课验收标准与报告要求\n{rubric}\n\n"
        f"## 学生提交的报告正文\n{report_text}\n\n"
        "请对照上面的验收标准，输出如下结构的 JSON：\n"
        '{"items": [{"criterion": "标准里的一条", "met": true, "note": "简短说明"}], '
        '"suggested_score": 85, "summary": "一到两句话总评"}'
    )


def _image_blocks(screenshot_paths: list[Path]) -> list[dict]:
    blocks = []
    for path in screenshot_paths:
        if not path.exists():
            continue
        media_type = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
        data = base64.standard_b64encode(path.read_bytes()).decode("ascii")
        blocks.append(
            {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": data}}
        )
    return blocks


def grade_one(client, rubric: str, report_text: str, screenshot_paths: list[Path]) -> dict:
    content = _image_blocks(screenshot_paths)
    content.append({"type": "text", "text": build_prompt(rubric, report_text)})
    message = client.messages.create(
        model=MODEL,
        max_tokens=1024,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": content}],
    )
    text = "".join(block.text for block in message.content if block.type == "text")
    return json.loads(text)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="AI 批改待批改的实验报告提交")
    parser.add_argument("--lesson", help="只批改指定课次，如 03；不填则批改全部待批改的")
    parser.add_argument("--db", default=str(Path(__file__).parent / "data.db"))
    parser.add_argument("--upload-dir", default=str(Path(__file__).parent / "uploads"))
    args = parser.parse_args(argv)

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print("请先设置环境变量 ANTHROPIC_API_KEY", file=sys.stderr)
        return 1

    client = anthropic.Anthropic(api_key=api_key)
    conn = models.get_connection(args.db)
    models.init_db(conn)

    pending = models.list_pending_for_grading(conn, args.lesson)
    if not pending:
        print("没有待批改的提交。")
        conn.close()
        return 0

    ok, failed = 0, []
    for sub in pending:
        lesson = sub["lesson"]
        try:
            rubric = rubric_loader.load_rubric(lesson)
        except rubric_loader.RubricNotFoundError as exc:
            failed.append((sub["id"], str(exc)))
            continue

        screenshots = models.get_screenshots(conn, sub["id"])
        paths = [Path(args.upload_dir) / row["file_path"] for row in screenshots]

        try:
            result = grade_one(client, rubric, sub["report_text"], paths)
        except Exception as exc:  # noqa: BLE001 - 单条失败不阻断其余提交
            failed.append((sub["id"], f"AI 调用失败：{exc}"))
            continue

        score = result.get("suggested_score")
        models.upsert_ai_grade(conn, sub["id"], score, json.dumps(result, ensure_ascii=False))
        ok += 1
        print(f"[{sub['id']}] {sub['student_id']} 第{lesson}次课 -> 建议分 {score}")

    print(f"完成：成功 {ok} 条，失败 {len(failed)} 条。")
    for sub_id, msg in failed:
        print(f"  提交 #{sub_id}: {msg}")

    conn.close()
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: 跑测试确认通过**

```bash
python -m pytest tests/test_grade.py -v
```

Expected: 5 个测试全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add tools/lab_submission/grade.py tools/lab_submission/tests/test_grade.py
git commit -m "feat(lab-submission): add AI grading CLI script (review-before-release)"
```

---

## Task 12: README + 全量测试 + 手动冒烟检查

**Files:**
- Create: `tools/lab_submission/README.md`
- Test: 全量测试套件

**Interfaces:** 无新代码接口，收尾任务。

- [ ] **Step 1: 写 `README.md`**

（下面用 4 个反引号包住整段内容，是为了在这份计划文档里嵌套显示 3 个
反引号的代码块——实际创建 `README.md` 时，文件内容就是 4 个反引号之间的
原文，`bash`/`powershell` 代码块保持 3 个反引号不变，不要额外转义。）

````markdown
# 学生实验报告提交系统

老师本机/校园网内跑的小工具：学生提交实验报告正文+截图，老师在后台复核并
可选让 AI 先给批改建议。设计文档：
`docs/superpowers/specs/2026-09-09-lab-submission-system-design.md`。

## 安装依赖

在仓库根目录：

\`\`\`bash
pip install -r tools/lab_submission/requirements.txt
\`\`\`

## 配置（环境变量，都是可选的，不设会用默认值）

| 变量 | 作用 | 默认值 |
|---|---|---|
| `LAB_ADMIN_PASSWORD` | 教师后台 `/admin` 登录口令 | `changeme`（**务必在正式使用前修改**） |
| `FLASK_SECRET_KEY` | Flask session 签名密钥 | `dev-secret-change-me`（**务必修改**） |
| `ANTHROPIC_API_KEY` | 批改脚本调用 Claude API 用，仅 `grade.py` 需要 | 无默认值，不设会报错退出 |

Windows PowerShell 设置环境变量示例：

\`\`\`powershell
$env:LAB_ADMIN_PASSWORD = "改成你自己的口令"
$env:FLASK_SECRET_KEY = "随便一串随机字符串"
\`\`\`

## 启动网页服务

\`\`\`bash
cd tools/lab_submission
python app.py
\`\`\`

首次运行会自动建 `data.db` 和 `uploads/` 目录。默认监听 `0.0.0.0:5000`，
同一局域网内的学生用 `http://<你的电脑IP>:5000/submit` 访问；仅本机测试用
`http://127.0.0.1:5000/submit`。

- 学生提交页：`/submit`
- 教师后台：`/admin`（先访问会跳到 `/admin/login`）

## 跑 AI 批改

\`\`\`powershell
$env:ANTHROPIC_API_KEY = "sk-ant-..."
cd tools/lab_submission
python grade.py --lesson 03
\`\`\`

不加 `--lesson` 就批改所有课次里状态还是"待批改"的提交。批改结果只是
**建议分**，不会自动发给学生——去 `/admin` 里对应提交的详情页，看到"AI 批改
建议"后自己决定分数、写评语，勾选"发布给学生"再保存，学生才会看到最终结果
（v1 版本学生端还没有"查看我的成绩"页面，发布状态目前只影响后台列表颜色和
导出 Excel 里的数据，实际通知学生走教学平台/群，这是本期已知的范围外事项）。

## 导出 Excel

`/admin` 页面按课次筛选后，点"导出本课次 Excel"，或直接访问
`/admin/submission... /admin/export?lesson=03`。

## 数据在哪

- `tools/lab_submission/data.db`：SQLite 数据库文件（不进 git）
- `tools/lab_submission/uploads/<学号>/<课次>/`：学生上传的截图（不进 git）

备份就是复制这两样东西。

## 运行测试

\`\`\`bash
cd tools/lab_submission
python -m pytest tests/ -v
\`\`\`
```

- [ ] **Step 2: 跑全量测试，确认整个系统所有测试都绿**

```bash
cd tools/lab_submission
python -m pytest tests/ -v
```

Expected: 全部 PASS（Task 1~11 的所有测试文件加起来）。

- [ ] **Step 3: 手动冒烟检查（人工执行，非自动化）**

```bash
cd tools/lab_submission
python app.py
```

在浏览器里：

1. 打开 `http://127.0.0.1:5000/submit`，填一份假报告+一张截图提交，看到"提交成功"。
2. 打开 `http://127.0.0.1:5000/admin`，用默认口令 `changeme` 登录，能看到刚才那条提交。
3. 点进详情页，能看到报告正文和截图缩略图；填分数+评语，勾选发布，保存后
   重新打开这条记录，分数/评语/勾选状态都还在。
4. 回列表页选课次筛选，点"导出本课次 Excel"，能下载打开一个 `.xlsx`，内容
   跟后台看到的一致。

确认无误后 Ctrl+C 停掉本地服务。

- [ ] **Step 4: Commit**

```bash
git add tools/lab_submission/README.md
git commit -m "docs(lab-submission): add setup/usage README"
```

---

## 完成后的收尾（不属于本计划的任务，实施完成后单独确认）

- 是否要把学生入口链接补进课程根 `README.md` 或各课 `lab.md` §6"报告要求"，
  这是设计文档里明确写的"本期不做，后续单独处理"的事项，实施完这个计划后
  再跟老师确认。
- `LAB_ADMIN_PASSWORD`/`FLASK_SECRET_KEY` 的默认值只用于开发/测试，正式给
  学生用之前必须由老师自己设置成非默认值——README 里已经标注，执行计划的人
  不需要在代码里做更多强制校验（YAGNI，教室内部工具）。
