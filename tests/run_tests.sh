#!/usr/bin/env bash
# Run every Hearthwild check. Used by agents, humans and CI alike.
#
#   tests/run_tests.sh                 all checks (needs a display for the playtest)
#   tests/run_tests.sh --headless-only skip the windowed playtest
#
# Env:
#   GODOT          Godot binary (default: godot)
#   GODOT_FLAGS    extra flags for the windowed playtest. CI has no GPU and no
#                  sound card, so it uses: --rendering-driver opengl3
#                  --rendering-method gl_compatibility --audio-driver Dummy
#   QA_OUTPUT      screenshot root (default: qa_output/), organised as <topic>/<run stamp>/
#   RUN_STAMP      folder name for this run's screenshots (default: date and time)
#   HW_SHOW_WINDOW=1  show the playtest window instead of using a virtual display
#
# Windowed checks run on an invisible virtual display (Xvfb) when it's
# installed, so no window pops up and no real mouse can interfere. Without
# Xvfb they open a real window for a few seconds.
#
# Exit code is non-zero if ANY check fails. A check that didn't run is a failure.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
GODOT_FLAGS="${GODOT_FLAGS:-}"
QA_OUTPUT="${QA_OUTPUT:-$PWD/qa_output}"
# One stamp per run, so all of this run's screenshots share a folder name:
# qa_output/<topic>/<RUN_STAMP>/. Old runs are kept, never deleted.
RUN_STAMP="${RUN_STAMP:-$(date +%Y-%m-%d_%H-%M-%S)}"
# The stamp is ONLY a date and time (never a label): folders sort by name, and
# the screenshot index and "previous run" lookups rely on that (lesson 16).
if [[ ! "$RUN_STAMP" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
	echo "RUN_STAMP must be YYYY-MM-DD_HH-MM-SS (date and time only, no labels); got: $RUN_STAMP"
	exit 1
fi
HEADLESS_ONLY=0
[[ "${1:-}" == "--headless-only" ]] && HEADLESS_ONLY=1

failed=()

# Godot prints script errors but can still exit 0, so every step also
# scans the log for them.
run_step() {
	local name="$1"; shift
	echo
	echo "=== $name"
	local log
	log="$(mktemp)"
	"$@" 2>&1 | tee "$log"
	local code=${PIPESTATUS[0]}
	if grep -qE "SCRIPT ERROR|^ERROR:|Parse Error|Failed to load" "$log"; then
		echo "!!! $name: errors in output"
		code=1
	fi
	if [[ $code -ne 0 ]]; then
		failed+=("$name")
	fi
	rm -f "$log"
}

"$GODOT" --version || { echo "Godot not found ($GODOT)"; exit 1; }

run_step "import project" "$GODOT" --headless --path . --import
run_step "load main scene" "$GODOT" --headless --path . --quit-after 60
# @tool scripts (terrain, nature) also run inside the editor; open the
# editor headless so errors that only happen there are caught too.
run_step "editor load" "$GODOT" --headless --path . -e --quit-after 300
# --fixed-fps 60 turns off real-time sync: the same 60 steps per game second,
# but as fast as the machine can go (13.7 s -> 0.8 s for the movement test).
run_step "player movement test" "$GODOT" --headless --path . --fixed-fps 60 --script res://tests/functional/test_player_movement.gd
run_step "terrain test" "$GODOT" --headless --path . --fixed-fps 60 --script res://tests/functional/test_terrain.gd
run_step "movement feel test" "$GODOT" --headless --path . --fixed-fps 60 --script res://tests/functional/test_movement_feel.gd
run_step "village test" "$GODOT" --headless --path . --fixed-fps 60 --script res://tests/functional/test_village.gd

# Wrap windowed runs in a virtual display unless one is already provided
# (CI runs this whole script under xvfb-run and sets HW_NO_REAL_MOUSE=1).
WINDOWED=()
if [[ -z "${HW_NO_REAL_MOUSE:-}" && "${HW_SHOW_WINDOW:-}" != "1" ]] && command -v xvfb-run >/dev/null; then
	WINDOWED=(env HW_NO_REAL_MOUSE=1 xvfb-run -a -s "-screen 0 1280x720x24")
	echo "(windowed checks run on a virtual display: no pop-up)"
fi

if [[ $HEADLESS_ONLY -eq 0 ]]; then
	# shellcheck disable=SC2086
	run_step "camera playtest" "${WINDOWED[@]}" "$GODOT" --path . --resolution 1280x720 $GODOT_FLAGS \
		--script res://tests/playtests/playtest_camera.gd -- "$QA_OUTPUT" "$RUN_STAMP"
	# shellcheck disable=SC2086
	run_step "visual tour" "${WINDOWED[@]}" "$GODOT" --path . --resolution 1280x720 $GODOT_FLAGS \
		--script res://tests/playtests/playtest_visual_tour.gd -- "$QA_OUTPUT" "$RUN_STAMP"
	# shellcheck disable=SC2086
	run_step "movement playtest" "${WINDOWED[@]}" "$GODOT" --path . --resolution 1280x720 $GODOT_FLAGS \
		--script res://tests/playtests/playtest_movement.gd -- "$QA_OUTPUT" "$RUN_STAMP"
	# shellcheck disable=SC2086
	run_step "village playtest" "${WINDOWED[@]}" "$GODOT" --path . --resolution 1280x720 $GODOT_FLAGS \
		--script res://tests/playtests/playtest_village.gd -- "$QA_OUTPUT" "$RUN_STAMP"
	echo
	echo "Screenshots: $QA_OUTPUT/<topic>/$RUN_STAMP/  (index: $QA_OUTPUT/INDEX.md)"
else
	echo
	echo "=== camera playtest: SKIPPED (--headless-only)"
	echo "=== visual tour: SKIPPED (--headless-only)"
	echo "=== movement playtest: SKIPPED (--headless-only)"
	echo "=== village playtest: SKIPPED (--headless-only)"
	echo "=== qa index: NOT regenerated (--headless-only)"
fi

# Record what this run was (branch, commit, renderer, result) and rebuild the
# screenshot index. Skipped for --headless-only (no screenshots were taken).
write_run_meta() {
	[[ $HEADLESS_ONLY -eq 1 ]] && return 0
	if ! command -v python3 >/dev/null; then
		echo "=== qa index: SKIPPED (python3 not found; no run_meta or INDEX.md written)"
		return 0
	fi
	mkdir -p "$QA_OUTPUT/run_meta"
	local renderer="Forward+"
	[[ "$GODOT_FLAGS" == *gl_compatibility* ]] && renderer="Compatibility"
	python3 - "$QA_OUTPUT" "$RUN_STAMP" "$renderer" "${failed[*]:-}" <<'PY'
import json, os, subprocess, sys
base, stamp, renderer, failed = sys.argv[1:5]
def git(*a):
    try:
        return subprocess.run(["git", *a], capture_output=True, text=True).stdout.strip()
    except Exception:
        return ""
meta = {"run": stamp, "branch": git("branch", "--show-current") or os.environ.get("GITHUB_REF_NAME", ""),
        "commit": git("rev-parse", "--short", "HEAD"), "dirty": bool(git("status", "--porcelain")),
        "renderer": renderer, "result": "FAIL: " + failed if failed else "PASS"}
open(os.path.join(base, "run_meta", stamp + ".json"), "w").write(json.dumps(meta, indent=2))
PY
	# A broken index (unreadable manifest) is a real failure, not something to hide.
	if ! python3 tests/tools/make_qa_index.py "$QA_OUTPUT"; then
		failed+=("qa index")
		# run_meta was written before the index ran: record the real result now.
		python3 - "$QA_OUTPUT/run_meta/$RUN_STAMP.json" "${failed[*]}" <<'PY2'
import json, sys
path, failed = sys.argv[1:3]
meta = json.load(open(path)); meta["result"] = "FAIL: " + failed
open(path, "w").write(json.dumps(meta, indent=2))
PY2
		python3 tests/tools/make_qa_index.py "$QA_OUTPUT" >/dev/null 2>&1 || true
	fi
}
write_run_meta

echo
if [[ ${#failed[@]} -eq 0 ]]; then
	echo "ALL CHECKS PASSED"
	exit 0
fi
echo "FAILED: ${failed[*]}"
exit 1
