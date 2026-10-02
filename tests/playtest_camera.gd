extends SceneTree
## Playtest: the third-person camera in the real world, plus scenic
## screenshots for visual QA. Needs rendering (not --headless); the test
## runner puts it on an invisible virtual display when Xvfb is installed.
##
## Run: godot --path . --script res://tests/playtest_camera.gd -- [<qa_output dir> [<run stamp>]]
## Screenshots go to <qa_output>/camera/<run stamp>/ (gitignored, never deleted).
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	var rig := kit.camera_rig
	var pitch := rig.get_node("Pitch") as Node3D
	var arm := kit.spring_arm

	# The camera captures the mouse on start. Release it straight away: while
	# captured, REAL mouse movement turns the camera and corrupts the test.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await kit.physics_frames(5)
	rig.rotation.y = 0.0
	pitch.rotation.x = deg_to_rad(-15.0)
	await kit.frames(3)
	var body_mesh := kit.player.get_node("Body/BodyMesh") as MeshInstance3D
	var body_material := body_mesh.get_surface_override_material(0) as StandardMaterial3D
	kit.check("player fully visible at normal camera distance", body_material.albedo_color.a > 0.99,
		"alpha=%.2f, arm %.1f m" % [body_material.albedo_color.a, arm.get_hit_length()])
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
	pitch.rotation.x = deg_to_rad(rig.min_pitch_degrees)
	rig.rotation.y = PI * 0.25
	await kit.physics_frames(3)
	await _screenshot("overview")
	arm.spring_length = 4.0
	pitch.rotation.x = deg_to_rad(-15.0)

	# Camera collision: put the player near the east boundary wall facing
	# inward (west), so the camera sits behind them on the wall side, then
	# back the player into the wall. The spring arm must pull the camera in
	# and keep it on the inner side of the wall (inner face x = 58).
	kit.face(Vector3.LEFT)
	await kit.teleport(Vector3(54, NAN, 0))
	Input.action_press("move_back")
	await kit.physics_frames(150)
	Input.action_release("move_back")
	kit.face(Vector3.LEFT)
	await kit.physics_frames(10)
	var px := kit.player.global_position.x
	kit.check("player stopped by boundary wall", px > 57.2 and px < 57.7, "player x=%.2f, wall face x=58.0" % px)
	var hit := arm.get_hit_length()
	kit.check("camera pulls in at wall", hit < arm.spring_length - 1.0,
		"hit length %.2f of %.1f" % [hit, arm.spring_length])
	var cam_x := (arm.get_node("Camera3D") as Node3D).global_position.x
	kit.check("camera stays inside the wall", cam_x < 58.0, "camera x=%.2f, wall face x=58.0" % cam_x)
	# With the camera squeezed against the wall it sits almost inside the
	# player, so the body must have faded away (it filled a third of the
	# screen before this existed).
	await kit.frames(3)
	kit.check("player fades when the camera is squeezed in", body_material.albedo_color.a < 0.1,
		"alpha=%.2f at arm length %.2f m" % [body_material.albedo_color.a, arm.get_hit_length()])
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
	var image := await kit.shot("camera", label)
	kit.check_rendered("camera/" + label, image)
	return image
