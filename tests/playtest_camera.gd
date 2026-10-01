extends SceneTree
## Playtest: the third-person camera, driven with real mouse/wheel events.
## Needs a real window (not --headless) because it saves screenshots.
## The mouse is released right after load, so a real mouse can't interfere.
##
## Run: godot --path . --script res://tests/playtest_camera.gd -- <output_dir>
## Default output dir: res://qa_output/ (gitignored).
## Exit code = number of failures (0 = all pass).

var _fails := 0
var _out_dir := ""
var _shot := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://qa_output")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# Keep Godot from importing screenshots saved inside the project.
	FileAccess.open(_out_dir.path_join(".gdignore"), FileAccess.WRITE)
	_run.call_deferred()


func _run() -> void:
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as PlayerController
	var rig := player.get_node("CameraRig") as ThirdPersonCamera
	var pitch := rig.get_node("Pitch") as Node3D
	var arm := rig.get_node("Pitch/SpringArm3D") as SpringArm3D

	# The camera captures the mouse on start. Release it straight away: while
	# captured, REAL mouse movement turns the camera and corrupts the test.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(60)
	rig.rotation.y = 0.0
	pitch.rotation.x = deg_to_rad(-15.0)
	await _screenshot("spawn")

	# Look math, exact: 200 px right turns the camera right by 200 * sensitivity.
	var expected_yaw := -200.0 * rig.mouse_sensitivity
	rig.apply_look(Vector2(200, 0))
	_check("mouse right turns camera right", is_equal_approx(rig.rotation.y, expected_yaw),
		"yaw=%.4f expected %.4f" % [rig.rotation.y, expected_yaw])
	await _screenshot("looked_right")

	# Pitch is clamped: a huge drag can't flip the camera over.
	rig.apply_look(Vector2(0, -5000))
	_check("pitch clamped at max", is_equal_approx(pitch.rotation.x, deg_to_rad(rig.max_pitch_degrees)),
		"pitch=%.2f deg" % rad_to_deg(pitch.rotation.x))
	rig.apply_look(Vector2(0, 5000))
	_check("pitch clamped at min", is_equal_approx(pitch.rotation.x, deg_to_rad(rig.min_pitch_degrees)),
		"pitch=%.2f deg" % rad_to_deg(pitch.rotation.x))

	# Routing: mouse motion is ignored while the mouse is free (not captured).
	var yaw_now := rig.rotation.y
	_mouse_motion(Vector2(300, 0))
	await _frames(2)
	_check("motion ignored while mouse is free", is_equal_approx(rig.rotation.y, yaw_now),
		"yaw %.4f -> %.4f" % [yaw_now, rig.rotation.y])

	# Routing while captured is only reliable with no real mouse attached,
	# so it runs where HW_NO_REAL_MOUSE=1 (CI, on a virtual display).
	if OS.get_environment("HW_NO_REAL_MOUSE") == "1":
		rig.rotation.y = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_motion(Vector2(200, 0))
		await _frames(2)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# 0.02 rad tolerance: tight enough to catch stretch-scaled input
		# (0.9 x = 0.06 off at 1280x720), loose enough for float noise.
		_check("captured motion turns camera (unscaled)", absf(rig.rotation.y - expected_yaw) < 0.02,
			"yaw=%.4f expected %.4f" % [rig.rotation.y, expected_yaw])
	else:
		print("SKIPPED captured-mouse routing (a real mouse can leak in; runs in CI with HW_NO_REAL_MOUSE=1)")

	# Back to a normal view, facing the original direction.
	pitch.rotation.x = deg_to_rad(-15.0)
	rig.rotation.y = 0.0

	# Zoom: wheel up = closer, wheel down = farther, both clamped.
	var length_before := arm.spring_length
	_wheel(MOUSE_BUTTON_WHEEL_UP, 2)
	await _frames(2)
	_check("wheel up zooms in", arm.spring_length < length_before,
		"%.1f -> %.1f" % [length_before, arm.spring_length])
	_wheel(MOUSE_BUTTON_WHEEL_UP, 50)
	await _frames(2)
	_check("zoom-in clamped", is_equal_approx(arm.spring_length, rig.min_distance), "%.1f" % arm.spring_length)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN, 50)
	await _frames(2)
	_check("zoom-out clamped", is_equal_approx(arm.spring_length, rig.max_distance), "%.1f" % arm.spring_length)
	await _screenshot("zoomed_out")
	arm.spring_length = 4.0

	# Camera collision: back the player up to the wall behind it (z = +6).
	# The camera sits behind the player, so the wall is between them and
	# the spring arm must pull the camera in.
	Input.action_press("move_back")
	await _physics_frames(180)
	Input.action_release("move_back")
	rig.rotation.y = 0.0
	await _physics_frames(10)
	_check("player stopped by wall", player.global_position.z > 5.2 and player.global_position.z < 5.5,
		"player z=%.2f, wall face z=5.75" % player.global_position.z)
	var hit := arm.get_hit_length()
	_check("camera pulls in at wall", hit < arm.spring_length - 1.0,
		"hit length %.2f of %.1f" % [hit, arm.spring_length])
	var cam_z := arm.get_node("Camera3D").global_position.z as float
	_check("camera stays in front of wall", cam_z < 5.75, "camera z=%.2f, wall face z=5.75" % cam_z)
	await _screenshot("against_wall")

	print("SCREENSHOTS: " + _out_dir)
	print("RESULT: %s (%d failures)" % ["ALL PASS" if _fails == 0 else "FAILED", _fails])
	quit(_fails)


func _check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + detail + ")" if detail else ""))
	if not ok:
		_fails += 1


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


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	var path := _out_dir.path_join("%02d_%s.png" % [_shot, label])
	root.get_texture().get_image().save_png(path)
	print("SHOT " + path)
