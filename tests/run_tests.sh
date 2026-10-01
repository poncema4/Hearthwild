#!/usr/bin/env bash
# Run every Hearthwild check. Used by agents, humans and CI alike.
#
#   tests/run_tests.sh                 all checks (needs a display for the playtest)
#   tests/run_tests.sh --headless-only skip the windowed playtest
#
# Env:
#   GODOT          Godot binary (default: godot)
#   GODOT_RENDER   extra render flags for the windowed playtest
#                  (CI uses: --rendering-driver opengl3 --rendering-method gl_compatibility)
#   QA_OUTPUT      screenshot folder (default: qa_output/)
#
# Exit code is non-zero if ANY check fails. A check that didn't run is a failure.

set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
GODOT_RENDER="${GODOT_RENDER:-}"
QA_OUTPUT="${QA_OUTPUT:-$PWD/qa_output}"
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
run_step "player movement test" "$GODOT" --headless --path . --script res://tests/test_player_movement.gd

if [[ $HEADLESS_ONLY -eq 0 ]]; then
	# shellcheck disable=SC2086
	run_step "camera playtest" "$GODOT" --path . --resolution 1280x720 $GODOT_RENDER \
		--script res://tests/playtest_camera.gd -- "$QA_OUTPUT"
else
	echo
	echo "=== camera playtest: SKIPPED (--headless-only)"
fi

echo
if [[ ${#failed[@]} -eq 0 ]]; then
	echo "ALL CHECKS PASSED"
	exit 0
fi
echo "FAILED: ${failed[*]}"
exit 1
