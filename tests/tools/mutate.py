#!/usr/bin/env python3
"""Negative controls in ONE call: break the code on purpose, run a test, expect it to FAIL, restore the file byte-for-byte.

Usage:  python3 tests/tools/mutate.py mutations.json
        (run it from the repo root, or in a /tmp copy of the repo; reviewers use a /tmp copy)

mutations.json is a list of objects:
  {"name": "W rebound to Q", "file": "project.godot", "old": "\"physical_keycode\":87,", "new": "\"physical_keycode\":81,",
   "cmd": "godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_keys.gd"}
`old` must occur EXACTLY ONCE in `file` (else the mutation is reported as BAD so a typo can never pass as a control).
A mutation is CAUGHT when the command exits non-zero or prints a line starting with FAIL, and MISSED otherwise (a check that
cannot fail: fix the test). After every mutation the file is written back from memory and compared with the original bytes;
a mismatch is reported as RESTORE FAILED. Exit code 0 only when every mutation is CAUGHT and every file restored.
Replaces hand-written one-off scripts (lessons 8.3 rule 1 and 60: one call instead of ten tool rounds).
"""
import json
import subprocess
import sys
from pathlib import Path

TIMEOUT = 300


def run_one(root: Path, m: dict) -> tuple[str, str]:
    path = root / m["file"]
    original = path.read_bytes()
    text = original.decode("utf-8")
    if text.count(m["old"]) != 1:
        return "BAD", f"'old' occurs {text.count(m['old'])} times in {m['file']} (must be exactly 1)"
    try:
        path.write_bytes(text.replace(m["old"], m["new"]).encode("utf-8"))
        try:
            done = subprocess.run(m["cmd"], shell=True, cwd=root, capture_output=True, text=True, timeout=TIMEOUT)
            output = done.stdout + done.stderr
            fails = [line.strip()[:120] for line in output.splitlines() if line.startswith("FAIL")]
            code = done.returncode
        except subprocess.TimeoutExpired:
            fails, code = [], -1
        verdict = "CAUGHT" if fails or code != 0 else "MISSED"
        detail = f"exit {code}, {len(fails)} FAIL line(s)" + ("".join(f"\n      {f}" for f in fails[:2]))
    finally:
        path.write_bytes(original)
    if path.read_bytes() != original:
        return "RESTORE FAILED", m["file"]
    return verdict, detail


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    root = Path.cwd()
    mutations = json.loads(Path(sys.argv[1]).read_text())
    bad = 0
    for m in mutations:
        verdict, detail = run_one(root, m)
        print(f"[{verdict}] {m['name']}: {detail}")
        bad += verdict != "CAUGHT"
    print(f"MUTATIONS: {len(mutations) - bad} of {len(mutations)} caught, files restored byte-for-byte" if not bad else f"MUTATIONS: {bad} of {len(mutations)} NOT caught")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
