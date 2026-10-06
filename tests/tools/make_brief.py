#!/usr/bin/env python3
"""Prints a SHORT, standard brief for one review agent, so the lead pastes it instead of writing it (and agents stop re-deriving what is known).

Usage:
  python3 tests/tools/make_brief.py AGENT [--copy /tmp/hw_review] [--images DIR] [--evidence FILE] [--finding "F1: text :: ONE command"]... [--delta]

AGENT is one of: sage, hawkeye, scout, ghoul, animator, mason, warden.
  --copy      the /tmp copy of the repo the agent works in (agents never touch the real repo)
  --images    a folder of screenshots with a manifest.json (the playtest wrote it): listed with their what/expect text
  --evidence  a text file with the lead's own results (test lines, mutation output, measurements): pasted so the agent does not redo them
  --finding   a finding being re-checked, with the single command that verifies it (repeat the flag); implies --delta
  --delta     a re-review after fixes: tighter budget, verify ONLY the listed findings

Why it exists (lessons 60 and 63): briefs written by hand were open-ended, forgot the evidence, and let one delta run 15 minutes. This prints the
agent's hard budget, what changed, what is already proven, what to focus on (the traps earlier rounds fell into) and the report contract.
Read-only; costs nothing.
"""
import argparse
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]

# (minutes, tool calls) for a first review and for a delta re-review. Measured: Hawkeye ~40 s, Scout ~90 s, Sage ~90 s first, Sage delta should be < 5 min.
BUDGETS = {
    "sage": ((5, 10), (3, 8)),
    "hawkeye": ((3, 8), (2, 6)),
    "scout": ((5, 12), (3, 8)),
    "ghoul": ((5, 10), (3, 8)),
    "animator": ((6, 10), (3, 8)),
    "mason": ((6, 10), (3, 8)),
    "warden": ((10, 4), (5, 3)),
}

# What each agent should look at FIRST: the specific traps earlier rounds fell into (see AGENTS.md section 14).
FOCUS = {
    "sage": [
        "checks that can pass while the thing they guard is broken: circular tests (expected value read from the object under test), one-sided tunables, a timer's two code paths, a vacuous measuring helper (lessons 41, 45, 62, 64)",
        "ONE call of `python3 tests/tools/mutate.py` (JSON list) proves 3 to 6 suspicions; never hand-run mutations one at a time",
        "the lessons gate: new lessons in AGENTS.md section 14 AND in the relevant agent files, docs and step counts (`check_repo.py` once)",
    ],
    "hawkeye": [
        "look at every image, crop and zoom 5x on the subject; direction (which way arms/legs/eyes point) cannot be judged from a thumbnail (lesson 63); say in words which way the hand and weapon point at the strike frame (lesson 68)",
        "effects and particles: judge them in BOTH renderers (Forward+ and Compatibility, CI's); a bleached or invisible effect is a finding",
        "readability: the subject must stand out from what is BESIDE it (lighter AND different), not only exist",
    ],
    "scout": [
        "press REAL keys (`InputEventKey` + `kit.frames(2)`), not named actions, when a claim is about controls (lesson 58)",
        "size thresholds from real numbers: walk 4 m/s, sprint 7 m/s, about 8 frames to reach 90% speed; zombie 2.4 m/s",
        "one scenario script, at most 3 launches; scan all output for ERROR / SCRIPT ERROR",
    ],
    "ghoul": [
        "probe INTERACTIONS between systems (zombie vs wall, seat, sleep, knock-out, spawner, sun), not what test_zombie.gd already pins (lesson 62)",
        "stroll, wall-following and unstick: long walls, trees, corners, a boxed-in zombie, the 25 s time limit",
        "pose and particles belong to Animator: report and name it",
    ],
    "animator": [
        "measure the DRAWN MESH centres against the facing direction (arms forward and level, legs down, eyes front), never a pivot point (lesson 63)",
        "DIRECTION SIGNS (lesson 68): the rig faces -Z and a POSITIVE X rotation swings a limb FORWARD; for every new attack/pose check the hand and the tip at the strike frame are in front (z <= -0.3 in the model frame) and never behind; compare with the fishing pose (+1.25)",
        "walk cycle: legs in opposition, no snap, no NaN, stops when standing; items worn on every animal (the wardrobe test covers 9 x 25: probe what it does not)",
        "particles and fire light: emit only when they should, rise, cover feet to head, read in both renderers",
    ],
    "mason": [
        "flat footprints, door scale vs the capsule, solid walls and props, pockets a player could enter but not leave",
        "use the village test's numbers; probe only what it does not walk",
    ],
    "warden": [
        "run the suite once; report every step name, PASS/FAIL counts with numbers, every SKIPPED line verbatim",
    ],
}


def run(*args: str) -> str:
    return subprocess.run(args, capture_output=True, text=True, cwd=ROOT).stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("agent", choices=sorted(BUDGETS))
    parser.add_argument("--copy", default="/tmp/hw_review")
    parser.add_argument("--images")
    parser.add_argument("--evidence")
    parser.add_argument("--finding", action="append", default=[])
    parser.add_argument("--delta", action="store_true")
    args = parser.parse_args()
    delta = args.delta or bool(args.finding)
    minutes, calls = BUDGETS[args.agent][1 if delta else 0]
    name = args.agent.upper()

    print(f"You are {name}, the {'DELTA re-review' if delta else 'review'} agent for the Hearthwild Godot 4.7.2 game.")
    print(f"FIRST read {args.copy}/.claude/agents/{args.agent}.md and {args.copy}/docs/INTENTIONAL.md (what is NOT a bug), then follow the findings contract in {args.copy}/AGENTS.md 9.0.")
    print(f"Work ONLY in the throwaway copy {args.copy} (already imported; `godot` is on PATH). Never touch the real repo. No rendered runs, never tests/run_tests.sh.")
    print(f"BUDGET (hard): {minutes} minutes and at most {calls} tool calls. At the budget stop and send what you have, with NOT TESTED for the rest. A late complete report is worse than an on-time partial one.")

    changed = run("git", "diff", "--name-status", "master").splitlines()
    untracked = run("git", "ls-files", "--others", "--exclude-standard").splitlines()
    print(f"\nCHANGED vs master ({run('git', 'diff', '--shortstat', 'master')}); full diff: write `git diff master > {args.copy}/REVIEW_DIFF.patch`")
    groups: dict[str, list[str]] = {}
    for line in changed:
        path = line.split("\t")[-1]
        groups.setdefault("/".join(path.split("/")[:2]) if "/" in path else "(root)", []).append(path.split("/")[-1])
    for path in untracked:
        groups.setdefault("/".join(path.split("/")[:2]) if "/" in path else "(root)", []).append(path.split("/")[-1] + " (new)")
    for group, names in sorted(groups.items()):
        print(f"- {group}: {', '.join(names[:10])}{' ...' if len(names) > 10 else ''}")

    if args.evidence:
        text = pathlib.Path(args.evidence).read_text().strip().splitlines()
        print("\nLEAD'S EVIDENCE (trust it unless it contradicts what you see; do NOT redo it):")
        for line in text[:40]:
            print(f"  {line}")
        if len(text) > 40:
            print(f"  ... ({len(text) - 40} more lines in {args.evidence})")

    if args.finding:
        print("\nFINDINGS TO RE-CHECK (verify ONLY these, each with its ONE command; do not re-audit the diff):")
        for finding in args.finding:
            print(f"- {finding}")

    if args.images:
        manifest = pathlib.Path(args.images) / "manifest.json"
        print(f"\nIMAGES in {args.images}:")
        if manifest.exists():
            for entry in json.loads(manifest.read_text()).get("images", []):
                print(f"- {entry['file']}: {entry.get('what', '')[:150]}")
        else:
            for png in sorted(pathlib.Path(args.images).glob("*.png")):
                print(f"- {png.name}")

    print("\nFOCUS (the traps earlier rounds fell into):")
    for item in FOCUS[args.agent]:
        print(f"- {item}")

    print("\nREPORT in the 9.0 contract: CONFIRMED FINDINGS (evidence, reproduction, severity, confidence, why not intentional), DISMISSED, UNCONFIRMED, EXERCISED (numbers), NOT TESTED, and END with VERDICT: SHIP or FIX FIRST.")
    print("Batch your probes into ONE headless script; prove check suspicions with ONE `python3 tests/tools/mutate.py` call.")


if __name__ == "__main__":
    main()
