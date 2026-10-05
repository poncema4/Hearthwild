extends SceneTree
## Functional test: the Roblox-style third-person mouse and the F3 input overlay. Real mouse-button and key events: hold the RIGHT mouse button to look
## around, Alt for shift lock (the character faces where the camera looks, the camera moves over the shoulder, a reticle shows), Esc turns it off, the
## left button never takes the mouse, Shift stays run, and the F3 overlay shows exactly the keys the game receives. (The real cursor mode is checked in the
## rendered camera playtest: a headless display cannot capture a mouse.)
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_camera_input.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await kit.frames(2)


func _mouse_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(400, 300)
	Input.parse_input_event(event)
	await kit.frames(2)


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	var player := kit.player
	var rig := kit.camera_rig
	var body := player.get_node("Body") as Node3D
	var hud := player.get_node("HUD") as InteractionPrompt
	var arm := kit.spring_arm
	var base_shoulder := 0.5
	await kit.physics_frames(30)

	# 1. Start state and the right mouse button.
	kit.check("a fresh game has no shift lock and no look in progress, and the cursor is the free one (not captured)", not rig.shift_lock and not rig.look_held and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,
			"shift_lock %s, look_held %s, mouse mode %d" % [rig.shift_lock, rig.look_held, Input.mouse_mode])
	await _mouse_button(MOUSE_BUTTON_LEFT, true)
	await _mouse_button(MOUSE_BUTTON_LEFT, false)
	kit.check("a left click does NOT take the mouse (clicks belong to menus and the paste box)", not rig.look_held and not rig.shift_lock)
	await _mouse_button(MOUSE_BUTTON_RIGHT, true)
	kit.check("holding the RIGHT mouse button starts looking around", rig.look_held)
	await _mouse_button(MOUSE_BUTTON_RIGHT, false)
	kit.check("letting go of the right button stops it", not rig.look_held)
	rig.look_held = true
	rig.refresh_mouse()
	kit.check("a stale 'right button held' (it was released while a menu was open) is forgotten by refresh_mouse()", not rig.look_held)

	# 2. Alt toggles shift lock; the reticle and message follow; Esc turns it off.
	kit.check("before Alt the reticle is hidden", not hud.reticle_visible())
	await _key(KEY_ALT, true)
	await _key(KEY_ALT, false)
	await kit.physics_frames(2)
	kit.check("Alt turns shift lock ON: the reticle shows and the HUD says so", rig.shift_lock and hud.reticle_visible() and hud.message_text().contains("Shift Lock ON"), "shift_lock %s, reticle %s, '%s'" % [rig.shift_lock, hud.reticle_visible(), hud.message_text()])
	await _key(KEY_ALT, true)
	await _key(KEY_ALT, false)
	await kit.physics_frames(2)
	kit.check("Alt again turns it OFF (reticle hidden)", not rig.shift_lock and not hud.reticle_visible() and hud.message_text().contains("Shift Lock OFF"))
	await _key(KEY_ALT, true)
	await _key(KEY_ALT, false)
	await _key(KEY_ESCAPE, true)
	await _key(KEY_ESCAPE, false)
	kit.check("Esc also turns shift lock off", not rig.shift_lock and not hud.reticle_visible())
	await _key(KEY_ALT, true)
	await _key(KEY_ALT, false)
	player.input_locked = true
	await _key(KEY_ALT, true)
	await _key(KEY_ALT, false)
	player.input_locked = false
	kit.check("while the player is locked (character screen, sleeping) Alt does nothing", rig.shift_lock, "shift_lock %s (it should still be ON from before)" % rig.shift_lock)
	rig.set_shift_lock(false)

	# 3. Facing: without shift lock the body turns to where it WALKS; with it, to where the camera looks, walking, strafing, backing up or standing.
	await kit.teleport(Vector3(0.0, NAN, 0.0), 20)
	kit.face(Vector3(0, 0, -1))
	body.rotation.y = 0.0
	await _key(KEY_A, true)
	await kit.physics_frames(50)
	await _key(KEY_A, false)
	var strafed_off := body.rotation.y
	kit.check("shift lock OFF: strafing left turns the body toward its movement (about +90 degrees, left)", strafed_off > deg_to_rad(60.0), "body yaw %.1f degrees" % rad_to_deg(strafed_off))
	rig.set_shift_lock(true)
	rig.rotation.y = deg_to_rad(40.0)
	await kit.physics_frames(60)
	var standing := body.rotation.y
	kit.check("shift lock ON: a standing character turns to face the camera's direction (40 degrees) within 1 s", absf(angle_difference(standing, deg_to_rad(40.0))) < deg_to_rad(4.0), "body %.1f, camera 40.0" % rad_to_deg(standing))
	var start_pos := player.global_position
	await _key(KEY_A, true)
	await kit.physics_frames(45)
	await _key(KEY_A, false)
	var moved := player.global_position - start_pos
	var camera_left := Vector3(-cos(deg_to_rad(40.0)), 0.0, sin(deg_to_rad(40.0)))  # the camera looks along (-sin yaw..): its left in the world
	kit.check("and strafing with shift lock moves sideways relative to the CAMERA (it did not turn the character): moved %.1f m, body still faces the camera" % moved.length(),
			moved.length() > 1.5 and moved.normalized().dot(camera_left) > 0.9 and absf(angle_difference(body.rotation.y, deg_to_rad(40.0))) < deg_to_rad(6.0),
			"direction dot %.2f, body %.1f" % [moved.normalized().dot(camera_left), rad_to_deg(body.rotation.y)])
	await _key(KEY_S, true)
	await kit.physics_frames(45)
	var backing_speed := kit.horizontal_speed()
	await _key(KEY_S, false)
	kit.check("backing up with shift lock works and the character still faces the camera", backing_speed > 3.0 and absf(angle_difference(body.rotation.y, deg_to_rad(40.0))) < deg_to_rad(6.0), "speed %.1f, body %.1f" % [backing_speed, rad_to_deg(body.rotation.y)])

	# 4. The camera glides over the shoulder with shift lock and back without it.
	await kit.physics_frames(30)
	var locked_x := arm.position.x
	rig.set_shift_lock(false)
	await kit.physics_frames(60)
	var free_x := arm.position.x
	kit.check("the camera sits further over the shoulder with shift lock (0.95 m) than without (0.5 m)", is_equal_approx(locked_x, rig.shift_lock_shoulder) and is_equal_approx(free_x, base_shoulder), "locked %.2f, free %.2f" % [locked_x, free_x])

	# 4b. Zoomed all the way in the character is dead centre (no shoulder offset), with and without shift lock; zoomed out the offset is back.
	var zoom_before := arm.spring_length
	arm.spring_length = rig.min_distance
	await kit.physics_frames(90)
	var close_x := arm.position.x
	rig.set_shift_lock(true)
	await kit.physics_frames(90)
	var close_locked_x := arm.position.x
	arm.spring_length = rig.max_distance
	await kit.physics_frames(90)
	var far_locked_x := arm.position.x
	rig.set_shift_lock(false)
	arm.spring_length = zoom_before
	await kit.physics_frames(90)
	kit.check("zoomed fully in the character is in the MIDDLE of the screen (shoulder offset 0, also with shift lock); zoomed out it is over the shoulder again",
			absf(close_x) < 0.01 and absf(close_locked_x) < 0.01 and is_equal_approx(far_locked_x, rig.shift_lock_shoulder),
			"close %.3f, close+lock %.3f, far+lock %.2f" % [close_x, close_locked_x, far_locked_x])

	# 5. Shift is still RUN (shift lock lives on Alt), and Alt/F3 are bound to their own actions.
	await _key(KEY_W, true)
	await _key(KEY_SHIFT, true)
	await kit.physics_frames(50)
	var run_speed := kit.horizontal_speed()
	await _key(KEY_SHIFT, false)
	await _key(KEY_W, false)
	kit.check("holding Shift while walking runs (about 7 m/s): Shift is not the shift-lock key", run_speed > 6.4 and not rig.shift_lock, "speed %.1f, shift_lock %s" % [run_speed, rig.shift_lock])

	# 6. The F3 input overlay shows exactly what the game receives.
	kit.check("the input overlay starts hidden", not hud.input_debug_visible())
	await _key(KEY_F3, true)
	await _key(KEY_F3, false)
	kit.check("F3 shows it", hud.input_debug_visible())
	await _key(KEY_W, true)
	await _key(KEY_SPACE, true)
	await _key(KEY_E, true)
	var held_text := hud.input_debug_text()
	kit.check("with W, Space and E held the overlay lists all three (and says what the cursor and speed are)", held_text.contains("W") and held_text.contains("Space") and held_text.contains("E") and held_text.contains("Speed") and held_text.contains("cursor"), held_text.replace("\n", " | "))
	await _key(KEY_E, false)
	var after_e := hud.input_debug_text()
	kit.check("when E is released it disappears from the list while W and Space stay (so a dropped key is visible)", after_e.contains("Space") and after_e.contains("W") and not after_e.contains("Keys: E") and not after_e.split("\n")[1].contains("E  ") and not after_e.split("\n")[1].ends_with("E"), after_e.split("\n")[1])
	await _key(KEY_SPACE, false)
	await _key(KEY_W, false)
	kit.check("with everything released the overlay says Keys: none", hud.input_debug_text().contains("Keys: none"), hud.input_debug_text().split("\n")[1])
	await _key(KEY_F3, true)
	await _key(KEY_F3, false)
	kit.check("F3 again hides it", not hud.input_debug_visible())

	# 7. The character screen hands the mouse back through the camera: shift lock survives opening and closing it.
	rig.set_shift_lock(true)
	var creator := kit.creator
	creator.open(PlayerProfile.make_default(), true)
	await kit.physics_frames(3)
	var locked_while_open := player.input_locked
	creator.cancel()
	await kit.physics_frames(3)
	kit.check("opening and cancelling the character screen locks and unlocks the player and keeps shift lock on", locked_while_open and not player.input_locked and rig.shift_lock)
	rig.set_shift_lock(false)

	kit.finish()
