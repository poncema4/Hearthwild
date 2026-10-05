extends SceneTree
## Playtest: the third-person camera in the real world, plus scenic
## screenshots for visual QA. Needs rendering (not --headless); the test
## runner puts it on an invisible virtual display when Xvfb is installed.
##
## Run: godot --path . --script res://tests/playtests/playtest_camera.gd -- [<qa_output dir> [<run stamp>]]
## Screenshots go to <qa_output>/camera/<run stamp>/ (gitignored, never deleted).
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit

## What each screenshot shows and what a correct frame looks like (goes into manifest.json).
const SHOTS := {
	"spawn": ["Spawn: player from behind on the flat clearing, default camera (4 m arm, -15 deg pitch).",
		"Upright capsule with a shadow, round tree and pines ahead, hills and sky; nothing clipping."],
	"toward_pond": ["Camera turned toward the pond (north-east), default distance.",
		"Meadow with trees; the pond may be out of frame; no clipping."],
	"toward_forest": ["Camera turned west toward the forest edge.",
		"Soft shadows on hills; trees on the slope; bright foreground; hill shading not gloomy."],
	"overview": ["Camera zoomed out to 8 m at -35 deg pitch (a high view), turned toward the village.",
		"Player small in the clearing, the dirt path leading away toward the village, hills and sky at the top, grass and flowers around; no black patches."],
	"against_wall": ["Player backed into the east boundary wall; the camera arm is squeezed to ~0.2 m.",
		"The player's body has faded out; the whole valley, pond and trees are visible; nothing covers the view."],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	var rig := kit.camera_rig
	var pitch := rig.get_node("Pitch") as Node3D
	var arm := kit.spring_arm

	# The cursor is FREE on start (Roblox-style: the right mouse button looks around, Alt is shift lock). Make sure of it: while captured, REAL mouse
	# movement turns the camera and corrupts the test.
	kit.check("the cursor is free right after the world loads (not captured)", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mode %d" % Input.mouse_mode)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await kit.physics_frames(5)
	rig.rotation.y = 0.0
	pitch.rotation.x = deg_to_rad(-15.0)
	await kit.frames(3)
	var model := kit.player.get_node("Body/Model") as AnimalModel
	kit.check("player fully visible at normal camera distance", model.get_alpha() > 0.99,
		"alpha=%.2f, arm %.1f m" % [model.get_alpha(), arm.get_hit_length()])
	await _screenshot("spawn")

	# Look math, exact: 200 px right turns the camera right by 200 * sensitivity.
	var expected_yaw := -200.0 * rig.mouse_sensitivity
	rig.apply_look(Vector2(200, 0))
	kit.check("mouse right turns camera right", is_equal_approx(rig.rotation.y, expected_yaw),
		"yaw=%.4f expected %.4f" % [rig.rotation.y, expected_yaw])

	# Pitch is clamped: a huge drag can't flip the camera over.
	rig.apply_look(Vector2(0, -5000))
	kit.check("pitch clamped at max", is_equal_approx(pitch.rotation.x, deg_to_rad(rig.max_pitch_degrees)),
		"pitch=%.2f deg" % rad_to_deg(pitch.rotation.x))
	rig.apply_look(Vector2(0, 5000))
	kit.check("pitch clamped at min", is_equal_approx(pitch.rotation.x, deg_to_rad(rig.min_pitch_degrees)),
		"pitch=%.2f deg" % rad_to_deg(pitch.rotation.x))

	# Routing: mouse motion is ignored while the mouse is free (not captured).
	var yaw_now := rig.rotation.y
	_mouse_motion(Vector2(300, 0))
	await kit.frames(2)
	kit.check("motion ignored while mouse is free", is_equal_approx(rig.rotation.y, yaw_now),
		"yaw %.4f -> %.4f" % [yaw_now, rig.rotation.y])

	# Routing while captured is only reliable with no real mouse attached,
	# so it runs where HW_NO_REAL_MOUSE=1 (CI and the local virtual display).
	if OS.get_environment("HW_NO_REAL_MOUSE") == "1":
		rig.rotation.y = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await kit.frames(1)
		_mouse_motion(Vector2(200, 0))
		await kit.frames(2)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# 0.02 rad tolerance: tight enough to catch stretch-scaled input
		# (0.9 x = 0.06 off at 1280x720), loose enough for float noise.
		kit.check("captured motion turns camera (unscaled)", absf(rig.rotation.y - expected_yaw) < 0.02,
			"yaw=%.4f expected %.4f" % [rig.rotation.y, expected_yaw])
	else:
		print("SKIPPED captured-mouse routing (a real mouse can leak in; runs with HW_NO_REAL_MOUSE=1)")
	pitch.rotation.x = deg_to_rad(-15.0)

	# The real cursor under the Roblox-style controls (needs a window that can capture a mouse: this runs on Xvfb / CI only).
	if OS.get_environment("HW_NO_REAL_MOUSE") == "1":
		var right_down := InputEventMouseButton.new()
		right_down.button_index = MOUSE_BUTTON_RIGHT
		right_down.pressed = true
		right_down.position = Vector2(300, 200)
		Input.parse_input_event(right_down)
		await kit.frames(3)
		var held_mode := Input.mouse_mode
		var right_up := InputEventMouseButton.new()
		right_up.button_index = MOUSE_BUTTON_RIGHT
		right_up.pressed = false
		right_up.position = Vector2(300, 200)
		Input.parse_input_event(right_up)
		await kit.frames(3)
		kit.check("holding the right mouse button captures the cursor to look around; letting go frees it again", held_mode == Input.MOUSE_MODE_CAPTURED and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
				"held mode %d, after release %d" % [held_mode, Input.mouse_mode])
		var alt_down := InputEventKey.new()
		alt_down.physical_keycode = KEY_ALT
		alt_down.keycode = KEY_ALT
		alt_down.pressed = true
		Input.parse_input_event(alt_down)
		await kit.frames(3)
		var lock_mode := Input.mouse_mode
		var alt_up := InputEventKey.new()
		alt_up.physical_keycode = KEY_ALT
		alt_up.keycode = KEY_ALT
		alt_up.pressed = false
		Input.parse_input_event(alt_up)
		await kit.frames(3)
		kit.check("Alt (shift lock) captures the cursor and keeps it captured with no button held", lock_mode == Input.MOUSE_MODE_CAPTURED and rig.shift_lock and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
				"mode %d, shift_lock %s" % [lock_mode, rig.shift_lock])
		alt_down.pressed = true
		Input.parse_input_event(alt_down)
		await kit.frames(3)
		alt_up.pressed = false
		Input.parse_input_event(alt_up)
		await kit.frames(3)
		kit.check("Alt again frees the cursor", not rig.shift_lock and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mode %d" % Input.mouse_mode)
	else:
		print("SKIPPED right-mouse / shift-lock cursor modes (a real mouse can leak in; runs with HW_NO_REAL_MOUSE=1)")

	# Zoom: wheel up = closer, wheel down = farther, both clamped.
	var length_before := arm.spring_length
	_wheel(MOUSE_BUTTON_WHEEL_UP, 2)
	await kit.frames(2)
	kit.check("wheel up zooms in", arm.spring_length < length_before,
		"%.1f -> %.1f" % [length_before, arm.spring_length])
	_wheel(MOUSE_BUTTON_WHEEL_UP, 50)
	await kit.frames(2)
	kit.check("zoom-in clamped", is_equal_approx(arm.spring_length, rig.min_distance), "%.1f" % arm.spring_length)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN, 50)
	await kit.frames(2)
	kit.check("zoom-out clamped", is_equal_approx(arm.spring_length, rig.max_distance), "%.1f" % arm.spring_length)
	arm.spring_length = 4.0

	# Scenic shots for visual QA: toward the pond, the forest edge, and an
	# overview from high up.
	var pond := Vector3(kit.terrain.pond_center.x, 0, kit.terrain.pond_center.y)
	kit.face(pond.normalized())
	await kit.physics_frames(3)
	await _screenshot("toward_pond")
	kit.face(Vector3(-1, 0, 0.4).normalized())
	await kit.physics_frames(3)
	await _screenshot("toward_forest")
	arm.spring_length = rig.max_distance
	pitch.rotation.x = deg_to_rad(-35.0)  # high, but with the hills and sky in frame: a flat top-down meadow is always borderline (lesson 35)
	kit.face(Vector3(-20, 0, 14).normalized())  # toward the village: the dirt path gives the frame real variety (lesson 35)
	await kit.physics_frames(3)
	await _screenshot("overview")
	arm.spring_length = 4.0
	pitch.rotation.x = deg_to_rad(-15.0)

	# Camera collision: put the player near the east boundary wall facing
	# inward (west), so the camera sits behind them on the wall side, then
	# back the player into the wall. The spring arm must pull the camera in
	# and keep it on the inner side of the wall (inner face = terrain half size - 2).
	var wall_face: float = kit.terrain.half_size() - 2.0
	kit.face(Vector3.LEFT)
	await kit.teleport(Vector3(wall_face - 4.0, NAN, 0))
	Input.action_press("move_back")
	await kit.physics_frames(150)
	Input.action_release("move_back")
	kit.face(Vector3.LEFT)
	await kit.physics_frames(10)
	var px := kit.player.global_position.x
	kit.check("player stopped by boundary wall", px > wall_face - 0.8 and px < wall_face - 0.3, "player x=%.2f, wall face x=%.1f" % [px, wall_face])
	var hit := arm.get_hit_length()
	kit.check("camera pulls in at wall", hit < arm.spring_length - 1.0,
		"hit length %.2f of %.1f" % [hit, arm.spring_length])
	var cam_x := (arm.get_node("Camera3D") as Node3D).global_position.x
	kit.check("camera stays inside the wall", cam_x < wall_face, "camera x=%.2f, wall face x=%.1f" % [cam_x, wall_face])
	# With the camera squeezed against the wall it sits almost inside the
	# player, so the body must have faded away (it filled a third of the
	# screen before this existed).
	await kit.frames(3)
	kit.check("player fades when the camera is squeezed in", model.get_alpha() < 0.1,
		"alpha=%.2f at arm length %.2f m" % [model.get_alpha(), arm.get_hit_length()])
	var wall_image := await _screenshot("against_wall")
	# What the player actually SEES (lesson 14): the same frame with the body
	# hidden outright must look the same, i.e. the faded body no longer covers
	# the screen. Comparing real pixels also proves the renderer honours the fade.
	var body := kit.player.get_node("Body") as Node3D
	body.visible = false
	await kit.frames(3)
	var without_body := await kit.capture()
	body.visible = true
	var covered := kit.fraction_different(wall_image, without_body)
	kit.check("faded player no longer covers the view", covered < 0.02,
		"%.1f%% of pixels differ from the body-hidden frame" % (covered * 100.0))

	print("SCREENSHOTS: " + kit.shots_base.path_join("camera").path_join(kit.shots_stamp))
	kit.finish()


func _mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.screen_relative = relative
	Input.parse_input_event(event)


func _wheel(button: MouseButton, clicks: int) -> void:
	for i in clicks:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = true
		Input.parse_input_event(event)


func _screenshot(label: String) -> Image:
	var image := await kit.shot("camera", label, SHOTS[label][0], SHOTS[label][1])
	kit.check_rendered("camera/" + label, image)
	return image
