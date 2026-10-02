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
run_step "player movement test" "$GODOT" --headless --path . --fixed-fps 60 --script res://tests/test_player_movement.gd
run_step "terrain test" "$GODOT" --headless --path . --fixed-fps 60 --script res://tests/test_terrain.gd

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
		--script res://tests/playtest_camera.gd -- "$QA_OUTPUT" "$RUN_STAMP"
	# shellcheck disable=SC2086
	run_step "visual tour" "${WINDOWED[@]}" "$GODOT" --path . --resolution 1280x720 $GODOT_FLAGS \
		--script res://tests/playtest_visual_tour.gd -- "$QA_OUTPUT" "$RUN_STAMP"
	echo
	echo "Screenshots: $QA_OUTPUT/<topic>/$RUN_STAMP/"
else
	echo
	echo "=== camera playtest: SKIPPED (--headless-only)"
	echo "=== visual tour: SKIPPED (--headless-only)"
fi

echo
if [[ ${#failed[@]} -eq 0 ]]; then
	echo "ALL CHECKS PASSED"
	exit 0
fi
echo "FAILED: ${failed[*]}"
exit 1
