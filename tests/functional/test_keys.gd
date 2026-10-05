extends SceneTree
## Functional test: the REAL keyboard. Every other movement test presses named actions (`Input.action_press`),
## which would still pass if W, A, S, D, Space or Shift were unbound or rebound. This one injects real key
## events (`InputEventKey`, the same kind the operating system sends), lets Godot's own Input Map turn them
## into actions, and measures where the player really goes. New features must not break these.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_keys.gd
## Exit code = number of failures (0 = all pass).

const EXPECTED_KEYS := {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"jump": KEY_SPACE, "sprint": KEY_SHIFT, "interact": KEY_E, "customize": KEY_F2, "shift_lock": KEY_ALT, "toggle_input_debug": KEY_F3,
}

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


## Sends one real key press or release and waits for Godot to deliver it.
func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await kit.frames(2)


func _release_all() -> void:
	for code in EXPECTED_KEYS.values():
		await _key(code, false)


## Back to the middle of the spawn clearing, camera looking north (-z), nothing held.
func _reset() -> void:
	await _release_all()
	await kit.teleport(Vector3(0.0, NAN, 0.0), 30)
	kit.face(Vector3(0, 0, -1))
	await kit.physics_frames(10)


## Holds the keys for `frames` physics frames and returns how far the player moved (x, z) and the highest rise (y).
func _press(codes: Array, frames: int) -> Vector3:
	await _reset()
	var start := kit.player.global_position
	var top := 0.0
	for code in codes:
		await _key(code, true)
	for i in frames:
		await kit.physics_frames(1)
		top = maxf(top, kit.player.global_position.y - start.y)
	var moved := kit.player.global_position - start
	for code in codes:
		await _key(code, false)
	return Vector3(moved.x, top, moved.z)


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# 1. The Input Map: every action exists and has the right physical key (and only that one).
	var problems := []
	for action in EXPECTED_KEYS:
		var codes := []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				codes.append((event as InputEventKey).physical_keycode)
		if not InputMap.has_action(action) or codes != [EXPECTED_KEYS[action]]:
			problems.append("%s: %s (wanted [%s])" % [action, codes, EXPECTED_KEYS[action]])
	kit.check("W A S D, Space, Shift, E, F2, Alt (shift lock) and F3 (input overlay) are each bound to exactly their own action", problems.is_empty(), str(problems))
	kit.check("a fresh world starts with the player free to move (not input_locked)", not kit.player.input_locked)

	# 2. Each direction key moves the player the right way (camera looks north, so W = -z, D = +x).
	var w := await _press([KEY_W], 45)
	kit.check("real W walks forward (north): about -3 m in z, sideways under 0.5 m", w.z < -2.0 and w.z > -6.0 and absf(w.x) < 0.5, "moved x %.2f z %.2f" % [w.x, w.z])
	var s := await _press([KEY_S], 45)
	kit.check("real S walks backward (south): z grows by about 3 m", s.z > 2.0 and s.z < 6.0 and absf(s.x) < 0.5, "moved x %.2f z %.2f" % [s.x, s.z])
	var a := await _press([KEY_A], 45)
	kit.check("real A strafes left (west): x falls by about 3 m", a.x < -2.0 and a.x > -6.0 and absf(a.z) < 0.5, "moved x %.2f z %.2f" % [a.x, a.z])
	var d := await _press([KEY_D], 45)
	kit.check("real D strafes right (east): x grows by about 3 m", d.x > 2.0 and d.x < 6.0 and absf(d.z) < 0.5, "moved x %.2f z %.2f" % [d.x, d.z])

	# 3. Combinations.
	var wd := await _press([KEY_W, KEY_D], 45)
	kit.check("W + D walks diagonally (north-east): -z and +x, roughly equal", wd.z < -1.5 and wd.x > 1.5 and absf(absf(wd.x) - absf(wd.z)) < 1.0, "moved x %.2f z %.2f" % [wd.x, wd.z])
	var ws := await _press([KEY_W, KEY_S], 45)
	kit.check("W + S together cancel out (under 0.5 m of travel)", Vector2(ws.x, ws.z).length() < 0.5, "moved x %.2f z %.2f" % [ws.x, ws.z])
	var shift_w := await _press([KEY_W, KEY_SHIFT], 45)
	kit.check("Shift + W sprints: clearly farther than W alone in the same time (at least 1.25x)", absf(shift_w.z) > absf(w.z) * 1.25, "sprint %.2f m vs walk %.2f m" % [absf(shift_w.z), absf(w.z)])

	# 4. Releasing the key stops the player.
	await _reset()
	await _key(KEY_W, true)
	await kit.physics_frames(40)
	var moving := kit.horizontal_speed()
	await _key(KEY_W, false)
	await kit.physics_frames(40)
	kit.check("after releasing W the player comes to a stop (moving %.1f m/s, then under 0.3)" % moving, moving > 2.0 and kit.horizontal_speed() < 0.3, "speed after %.2f" % kit.horizontal_speed())

	# 5. Jumping with the real Space bar.
	var jump := await _press([KEY_SPACE], 40)
	kit.check("real Space jumps: rises between 0.5 m and 3 m", jump.y > 0.5 and jump.y < 3.0, "rose %.2f m" % jump.y)
	await kit.physics_frames(90)
	kit.check("and lands again (on the floor, back near the start height)", kit.player.is_on_floor(), "y=%.2f on_floor=%s" % [kit.player.global_position.y, kit.player.is_on_floor()])
	var walk_jump := await _press([KEY_W, KEY_SPACE], 45)
	kit.check("W + Space jumps while moving forward (rose over 0.5 m and travelled over 2 m)", walk_jump.y > 0.5 and walk_jump.z < -2.0, "rose %.2f m, moved z %.2f" % [walk_jump.y, walk_jump.z])

	# 5b. Pressing ANY other key while moving never interrupts the movement or the jumping (a reported bug: "I hold W + Space, press E or T or P, and I
	# stop until I let go"). Real key events, about 50 different keys, one after another, while W + Space (and then W + Shift + Space) stay held.
	var other_keys := [KEY_E, KEY_T, KEY_P, KEY_Q, KEY_R, KEY_F, KEY_G, KEY_H, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_J, KEY_K, KEY_L,
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_TAB, KEY_ENTER, KEY_BACKSPACE, KEY_ALT, KEY_CTRL, KEY_CAPSLOCK, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
			KEY_F1, KEY_F3, KEY_F5, KEY_F6, KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_BRACKETLEFT]
	var interrupt_report := {}
	for sprinting in [false, true]:
		await _reset()
		var start_z := kit.player.global_position.z
		await _key(KEY_W, true)
		await _key(KEY_SPACE, true)
		if sprinting:
			await _key(KEY_SHIFT, true)
		await kit.physics_frames(40)  # up to full speed first
		var slowest := 99.0
		var takeoffs := 0
		var was_on_floor := kit.player.is_on_floor()
		var worst_key := ""
		for code in other_keys:
			await _key(code, true)
			for i in 12:
				await kit.physics_frames(1)
				var speed := kit.horizontal_speed()
				if speed < slowest:
					slowest = speed
					worst_key = OS.get_keycode_string(code)
				if was_on_floor and not kit.player.is_on_floor():
					takeoffs += 1
				was_on_floor = kit.player.is_on_floor()
			await _key(code, false)
		var travelled := start_z - kit.player.global_position.z
		interrupt_report[sprinting] = {"slowest": slowest, "takeoffs": takeoffs, "travelled": travelled, "worst_key": worst_key}
		await _key(KEY_SHIFT, false)
		await _key(KEY_SPACE, false)
		await _key(KEY_W, false)
	kit.camera_rig.set_shift_lock(false)  # the list above includes Alt (shift lock) and F3 (the overlay): put both back
	var overlay := kit.player.get_node("HUD") as InteractionPrompt
	if overlay.input_debug_visible():
		await _key(KEY_F3, true)
		await _key(KEY_F3, false)
	kit.check("holding W + Space and pressing ~50 other keys in turn (E, T, P, letters, digits, Tab, Alt, Ctrl, arrows, F-keys...): the player never slows below 3.5 m/s while walking, and keeps hopping (7+ take-offs)",
			interrupt_report[false]["slowest"] >= 3.5 and interrupt_report[false]["takeoffs"] >= 7, str(interrupt_report[false]))
	kit.check("and the same with Shift held (sprint): never below 6.4 m/s, still hopping", interrupt_report[true]["slowest"] >= 6.4 and interrupt_report[true]["takeoffs"] >= 7, str(interrupt_report[true]))

	# 6. Nothing is left stuck afterwards.
	await _release_all()
	await kit.physics_frames(5)
	var stuck := []
	for action in EXPECTED_KEYS:
		if Input.is_action_pressed(action):
			stuck.append(action)
	kit.check("after releasing every key no action is left pressed", stuck.is_empty(), str(stuck))

	kit.finish()
