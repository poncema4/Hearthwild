#!/usr/bin/env python3
"""Free, deterministic repo hygiene checks (the runner's first step, about 0.2 s).

Usage: python3 tests/tools/check_repo.py

These are the things reviewers (Sage) used to find by reading, at ~100k tokens a
round: docs that drifted from the code, a test with no README row, a stale
"N steps", loose files, lessons referenced but not written. A machine finds them
for nothing, every run, before any agent is paid. Each failure says how to fix it.
Exit code = number of failures. Never modifies anything.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
failures: list[str] = []
passed = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global passed
    if ok:
        passed += 1
    else:
        failures.append(f"FAIL {name}" + (f"  ({detail})" if detail else ""))


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


runner = read("tests/run_tests.sh")
tests_readme = read("tests/README.md")
readme = read("README.md")
agents_md = read("AGENTS.md")

# 1. Every test file is in the runner AND the tests map.
def mentions(text: str, filename: str) -> bool:
    """Whole-name match: `test_animation.gd` must not be satisfied by `playtest_animation.gd`."""
    return re.search(rf"(?<![A-Za-z0-9_]){re.escape(filename)}", text) is not None


for pattern in ("tests/functional/test_*.gd", "tests/playtests/playtest_*.gd"):
    for path in sorted(ROOT.glob(pattern)):
        rel = path.relative_to(ROOT).as_posix()
        check(f"{rel} is run by tests/run_tests.sh", mentions(runner, path.name), f"add a run_step for {path.name}")
        check(f"{rel} has a row in tests/README.md", mentions(tests_readme, path.name), f"add a row for {path.name}")

# 2. Every agent file is named in the README table and in AGENTS.md section 9.
for path in sorted((ROOT / ".claude/agents").glob("*.md")):
    name = path.stem
    check(f"agent {name} is in the README agent table", re.search(rf"\*\*{name}\*\*", readme, re.I) is not None, f"add a row for {name}")
    check(f"agent {name} has a section in AGENTS.md", f"(`{name}`)" in agents_md, f"add a 9.x section for {name}")

# 3. The number of runner steps matches every place that states it.
steps = len(re.findall(r'^\s*run_step "', runner, re.M))
for rel, pattern in (("README.md", r"\((\d+) steps"), (".claude/agents/warden.md", r"all (\d+) steps"),
                     (".claude/agents/warden.md", r"STEPS \((\d+) expected\)")):
    found = re.findall(pattern, read(rel))
    check(f"{rel} states the right step count ({steps})", bool(found) and all(int(n) == steps for n in found),
          f"says {found}, runner has {steps} run_step lines")

# 4. Every GDScript file has its .uid (Godot writes them on import; the repo tracks them).
for folder in ("scripts", "tests"):
    for path in sorted((ROOT / folder).rglob("*.gd")):
        check(f"{path.relative_to(ROOT).as_posix()} has a .uid file", path.with_name(path.name + ".uid").exists(),
              "run `godot --headless --import` and add the .uid")

# 5. Organization: nothing loose in tests/, no leftovers anywhere, no stray images or logs.
allowed_in_tests = {"run_tests.sh", "README.md"}
loose = [p.name for p in (ROOT / "tests").iterdir() if p.is_file() and p.name not in allowed_in_tests and not p.name.endswith(".uid")]
check("no loose files directly in tests/", not loose, f"move {loose} into functional/, playtests/, support/ or tools/")
leftovers = [p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*")
             if p.is_file() and ".git" not in p.parts and ".godot" not in p.parts and "qa_output" not in p.parts
             and (re.search(r"(dbg|tmp|scratch)", p.stem, re.I) and p.suffix in (".gd", ".tscn", ".py", ".sh") or p.suffix in (".bak", ".orig", ".log", ".tmp"))]
check("no debug, scratch, backup or log files", not leftovers, f"delete {leftovers}")
stray = [p.name for p in ROOT.iterdir() if p.is_file() and p.suffix.lower() in (".png", ".jpg", ".jpeg", ".gif", ".zip", ".mp4")]
check("no stray images or archives in the repo root", not stray, f"screenshots belong in qa_output/: {stray}")

# 6. Lessons: numbered 1..N without gaps; every lesson cited anywhere exists.
lesson_numbers = [int(n) for n in re.findall(r"^\| (\d+) \|", agents_md.split("### 14.1")[1].split("### 14.2")[0], re.M)]
check("lessons in AGENTS.md 14.1 are numbered 1..N with no gaps", lesson_numbers == list(range(1, len(lesson_numbers) + 1)),
      f"found {lesson_numbers[:3]}...{lesson_numbers[-3:]}")
top = max(lesson_numbers, default=0)
cited = set()
for rel in [p.relative_to(ROOT).as_posix() for p in (ROOT / ".claude/agents").glob("*.md")] + ["docs/INTENTIONAL.md", "README.md"]:
    for group in re.findall(r"[Ll]essons? ((?:\d+(?:, ?| and |-)?)+)", read(rel)):
        cited.update(int(n) for n in re.findall(r"\d+", group))
    for path in ROOT.glob("tests/**/*.gd"):
        pass
for path in ROOT.glob("tests/**/*.gd"):
    for group in re.findall(r"lessons? ((?:\d+(?:, ?| and |-)?)+)", path.read_text(encoding="utf-8"), re.I):
        cited.update(int(n) for n in re.findall(r"\d+", group))
missing = sorted(n for n in cited if n > top)
check("every lesson number cited in agents, docs and tests exists in AGENTS.md", not missing, f"cited but not written: {missing} (highest written is {top})")

# 7. The state table and development order mention what exists.
check("AGENTS.md section 13 marks step 6 done when interaction exists",
      not (ROOT / "scripts/interaction/door.gd").exists() or "6. Basic interaction ✅" in agents_md,
      "update the development order")

print(f"repo check: {passed} passed, {len(failures)} failed")
for line in failures:
    print(line)
sys.exit(len(failures))
