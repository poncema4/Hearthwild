#!/usr/bin/env python3
"""Prints a compact REVIEW PACK for the lead to paste into agent briefs.

Usage: python3 tests/tools/review_pack.py [qa_output_dir]

It replaces the exploring every agent used to do (and the lead's own brief-writing):
what changed (against master, including untracked files), which screenshots
CHANGED in the newest run (from qa_output/INDEX.md), the newest run's result, and
WHICH agents this change actually needs (AGENTS.md 9.6 dispatch matrix, applied
mechanically). Read-only; prints markdown; costs nothing.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
QA = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "qa_output"


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True).stdout.strip()


branch = git("branch", "--show-current")
commit = git("rev-parse", "--short", "HEAD")
tracked = [l.split("\t")[-1] for l in git("diff", "--name-status", "master").splitlines() if l]
untracked = git("ls-files", "--others", "--exclude-standard").splitlines()
changed = sorted(set(tracked) | set(untracked))
stat = git("diff", "--shortstat", "master")


def any_path(*prefixes: str) -> bool:
    return any(c.startswith(prefixes) for c in changed)


code = [c for c in changed if c.endswith((".gd", ".tscn", ".sh", ".py", ".godot"))]
needs = []
if any_path("scripts/player/animal_", "scripts/player/outfits", "scripts/player/player_controller", "tests/functional/test_animation", "tests/playtests/playtest_animation", "tests/functional/test_movement_feel"):
    needs.append("**Animator**: character, animation or movement-feel files changed")
if any_path("scripts/mobs/", "scripts/player/health", "scripts/world/day_night", "scripts/world/sleep_system", "tests/functional/test_zombie"):
    needs.append("**Ghoul**: zombie, spawner, sun, sleep or health files changed (also **Animator** if the zombie model or its fire moved)")
if any_path("scripts/mobs/", "scripts/player/outfits", "scripts/player/animal_"):
    needs.append("**Animator**: a mob model or the wardrobe/animals changed (measure mesh geometry, not pivots; lesson 63)")
if any_path("scripts/world/", "scenes/world/", "scripts/interaction/"):
    needs.append("**Mason**: world, village, door or interaction files changed")
if any_path("scripts/", "scenes/", "tests/playtests/"):
    needs.append("**Hawkeye**: only the REVIEW images listed below (never the whole set)")
if code:
    needs.append("**Sage**: code, tests or tooling changed (give it the pack; it should read the diff, not the repo)")
if any_path(".claude/agents/", "AGENTS.md"):
    needs.append("**Sage** also, because agent files or AGENTS.md changed (lessons gate)")
if not needs:
    needs.append("none: docs or comments only (the repo check and runner are enough)")

print(f"# REVIEW PACK  branch `{branch}`  commit `{commit}` (+ uncommitted)\n")
print(f"{len(changed)} files changed vs master ({stat or 'uncommitted only'}):\n")
groups: dict[str, list[str]] = {}
for c in changed:
    groups.setdefault("/".join(c.split("/")[:2]) if "/" in c else "(root)", []).append(pathlib.Path(c).name)
for g, names in sorted(groups.items()):
    print(f"- `{g}`: {', '.join(names[:8])}{' ...' if len(names) > 8 else ''}")

print("\n## Newest test run")
meta = sorted((QA / "run_meta").glob("*.json")) if (QA / "run_meta").exists() else []
if meta:
    print(meta[-1].read_text().strip()[:400])
else:
    print("no run_meta found: run tests/run_tests.sh first")

print("\n## Screenshots that CHANGED in the newest run (review only these)")
index = QA / "INDEX.md"
rows = []
if index.exists():
    latest = index.read_text().split("## All runs")[0]
    for line in latest.splitlines():
        if line.startswith("| **REVIEW**"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            rows.append((cells[1].strip("`"), cells[2]))
for path, what in rows:
    print(f"- `{QA.name}/{path}`: {what[:110]}")
if not rows:
    print("none flagged (or no INDEX.md)")

print("\n## Agents this change needs (AGENTS.md 9.6)")
for n in needs:
    print(f"- {n}")
print("- Warden: **skip** when the lead ran BOTH renderers green and CI will run on the PR (CI is the independent gate)")
print("- Scout: only for a new controls/physics system the soak test does not walk")
print("- Write each brief with `python3 tests/tools/make_brief.py AGENT [--delta]` (budget, evidence, traps included)")
