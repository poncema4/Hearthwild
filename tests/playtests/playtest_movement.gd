extends SceneTree
## Playtest: movement as FILMSTRIPS for visual review (Hawkeye).
##
## Each filmstrip is ONE image: a grid of thumbnails read left to right, top to
## bottom = time. manifest.json next to it lists, per thumbnail, the time,
## position, speed and body rotation, so movement can be judged from a single
## picture plus numbers. Needs rendering (not --headless).
##
## Run: godot --path . --script res://tests/playtests/playtest_movement.gd -- [<qa_output dir> [<run stamp>]]
## Shots: <qa_output>/movement/<run stamp>/ (gitignored, never deleted).
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var jump_samples := []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var rig := kit.camera_rig
	var pitch := rig.get_node("Pitch") as Node3D

	await _start(rig, pitch)
	await _sheet("walk_start", ["move_forward"], 50, 10,
		"Standing still (thumbnail 1, t = 0), then holding W; a thumbnail about every 1/6 s (6 thumbnails).",
		"Thumbnail 1 is standing still (speed 0). Then the scene scrolls smoothly toward the player's heading; the capsule stays upright and centred; speed reaches 4 m/s within the first one or two moving thumbnails; the shadow stays under the player. Check t against distance moved.", 3)

	await _start(rig, pitch)
	await _sheet("sprint", ["move_forward", "sprint"], 50, 10,
		"Standing still (thumbnail 1), then holding W + Shift (6 thumbnails).",
		"Same as walking but faster: more ground covered per thumbnail (7 m/s); no camera jitter or sudden jumps in the view.", 3)

	await _start(rig, pitch)
	await kit.hold(["move_forward"], 40)
	await _sheet("turn_180", ["move_back"], 40, 8,
		"Walking forward at full speed (thumbnail 1), then reversing direction with S (6 thumbnails).",
		"The camera stays behind-and-above; the dog's body (muzzle first) swings around to the new heading within about 0.25 s, with no flip or spin; the player keeps moving, then travels the other way.", 3)

	await _start(rig, pitch)
	await kit.tap("jump")
	await _sheet("jump_arc", [], 72, 8,
		"A standing jump (9 thumbnails over ~1.2 s; the first is at take-off, the last is after landing).",
		"The camera follows vertically, so the capsule stays at about the SAME screen position: the rise shows as the horizon and ground shifting and the shadow separating from the capsule, then rejoining on landing. Use the sample y values: about 1.3 m apex, and the LAST thumbnail is back on the floor (y about 0, on_floor true). The camera never clips into the ground.", 3)
	jump_samples = kit.last_samples

	await _start(rig, pitch)
	kit.face(Vector3.RIGHT)
	await _sheet("sprint_over_terrain", ["move_forward", "sprint"], 105, 15,
		"Standing still (thumbnail 1), then sprinting east across the meadow toward the pond-side hills (8 thumbnails). A tree may briefly hide the player as they pass (see docs/INTENTIONAL.md).",
		"The player follows the ground over the gentle hills without floating or sinking; trees pass by on the sides; the view stays level.", 4)

	# The jump strip must actually contain a jump (it once showed a player standing
	# still and nothing flagged it; lesson 32).
	var jump_sheet_samples := jump_samples
	var max_y := 0.0
	var airborne := false
	for s in jump_sheet_samples:
		max_y = maxf(max_y, s["pos"][1])
		airborne = airborne or not s["on_floor"]
	var last: Dictionary = jump_sheet_samples[jump_sheet_samples.size() - 1]
	var landed: bool = last["on_floor"] and last["pos"][1] < 0.05
	kit.check("movement/jump_arc contains a real jump that lands", max_y > 1.0 and airborne and landed,
		"max y %.2f m, some sample airborne: %s, last sample on floor at y %.2f: %s" % [max_y, airborne, last["pos"][1], landed])

	print("SCREENSHOTS: %s/movement/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


func _start(rig: ThirdPersonCamera, pitch: Node3D) -> void:
	await kit.teleport(Vector3(0, NAN, 0), 40)
	# Each sheet starts clean: the body from the previous sheet would otherwise still be turned.
	(kit.player.get_node("Body") as Node3D).rotation.y = 0.0
	rig.rotation.y = 0.0
	pitch.rotation.x = deg_to_rad(-15.0)
	kit.spring_arm.spring_length = 4.0
	await kit.frames(2)


func _sheet(name: String, actions: Array, total: int, every: int, what: String, expect: String, columns: int) -> void:
	var sheet := await kit.filmstrip("movement", name, actions, total, every, what, expect, columns)
	kit.check_rendered("movement/" + name, sheet)
