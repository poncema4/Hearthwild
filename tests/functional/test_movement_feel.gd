extends SceneTree
## Functional test: how the movement FEELS, in numbers.
##
## Measures response times (in physics frames; 60 = 1 second) and distances
## for the standard moves, prints every measurement, and checks each against a
## band. The bands are the "movement feel spec" (AGENTS.md section 8.5): wide
## enough that normal tuning passes, tight enough that a broken change
## (instant snap, sluggish slide, wrong jump) fails. When you tune the feel on
## purpose, change the band in the same PR and say why.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_movement_feel.gd
## Exit code = number of failures (0 = all pass).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var player := kit.player
	var walk := player.walk_speed
	var sprint := player.sprint_speed
	var body := player.get_node("Body") as Node3D

	# 1. Walk start: frames from standstill to 90% of walk speed.
	await _reset(kit)
	var frames := await _frames_until(kit, ["move_forward"], func(): return kit.horizontal_speed() >= walk * 0.9, 120)
	kit.check("walk reaches 90% speed quickly but not instantly", frames >= 2 and frames <= 24,
		"%d frames (%.2f s); target 2-24" % [frames, frames / 60.0])

	# 2. Sprint start (from standstill).
	await _reset(kit)
	frames = await _frames_until(kit, ["move_forward", "sprint"], func(): return kit.horizontal_speed() >= sprint * 0.9, 120)
	kit.check("sprint reaches 90% speed in a quarter second or less", frames >= 3 and frames <= 30,
		"%d frames (%.2f s); target 3-30" % [frames, frames / 60.0])

	# 3. Stop: after walking at full speed, release; frames to nearly stopped, and the slide distance.
	await _reset(kit)
	await kit.hold(["move_forward"], 40)
	var start := kit.player.global_position
	frames = await _frames_until(kit, [], func(): return kit.horizontal_speed() < 0.1, 120)
	var slide := Vector2(kit.player.global_position.x - start.x, kit.player.global_position.z - start.z).length()
	kit.check("walking stops in 0.05-0.33 s (not an instant halt, not icy)", frames >= 3 and frames <= 20, "%d frames; target 3-20" % frames)
	kit.check("walking stop slide is under 0.6 m", slide < 0.6, "slide %.2f m" % slide)

	# 4. Turn 180 degrees: walk forward, then walk back; frames for the body to face within 10 deg.
	await _reset(kit)
	await kit.hold(["move_forward"], 40)
	var target := PI  # facing +Z after pressing S with the camera facing -Z
	frames = await _frames_until(kit, ["move_back"], func(): return absf(angle_difference(body.rotation.y, target)) < deg_to_rad(10.0), 120)
	kit.check("a 180 degree turn finishes in 0.1-0.5 s", frames >= 6 and frames <= 30, "%d frames (%.2f s); target 6-30" % [frames, frames / 60.0])

	# 5. Strafe reversal: walk left, then right; frames until the velocity points right.
	await _reset(kit)
	await kit.hold(["move_left"], 40)
	frames = await _frames_until(kit, ["move_right"], func(): return player.velocity.x > 0.0, 120)
	kit.check("reversing sideways takes 0.05-0.5 s", frames >= 3 and frames <= 30, "%d frames; target 3-30" % frames)

	# 6. Jump: apex height and time in the air (standing jump on the flat clearing).
	await _reset(kit)
	var ground := kit.player.global_position.y
	await kit.tap("jump")
	var apex := 0.0
	var air := 1
	while not kit.player.is_on_floor() or air < 3:
		await kit.physics_frames(1)
		air += 1
		apex = maxf(apex, kit.player.global_position.y - ground)
		if air > 200:
			break
	kit.check("jump apex is 1.0-1.5 m", apex >= 1.0 and apex <= 1.5, "apex %.2f m" % apex)
	kit.check("jump airtime is 0.7-1.2 s", air >= 42 and air <= 72, "%d frames (%.2f s)" % [air, air / 60.0])

	# 7. Holding Space hops again on every landing (the player asked for continuous jumps),
	# but never faster than the natural airtime and never a double jump. Count the TAKEOFFS
	# over time (floor -> air transitions): an end-state check passes for almost anything (lesson 27).
	await _reset(kit)
	Input.action_press("jump")
	var takeoff_frames: Array[int] = []
	var was_on_floor := true
	for i in 300:
		await kit.physics_frames(1)
		var on_floor := kit.player.is_on_floor()
		if was_on_floor and not on_floor:
			takeoff_frames.append(i)
		was_on_floor = on_floor
	Input.action_release("jump")
	var min_gap := 999
	for k in range(1, takeoff_frames.size()):
		min_gap = mini(min_gap, takeoff_frames[k] - takeoff_frames[k - 1])
	kit.check("holding Space keeps hopping: 4-5 takeoffs in 300 frames", takeoff_frames.size() >= 4 and takeoff_frames.size() <= 5,
			"%d takeoffs at frames %s" % [takeoff_frames.size(), takeoff_frames])
	kit.check("held hops are never faster than the airtime (no double jump): gaps of at least 55 frames", min_gap >= 55, "closest gap %d frames" % min_gap)

	# 8. A single tap is still exactly one hop.
	await _reset(kit)
	await kit.tap("jump")
	var tap_takeoffs := 1
	was_on_floor = false
	for i in 200:
		await kit.physics_frames(1)
		var on_floor_now := kit.player.is_on_floor()
		if was_on_floor and not on_floor_now:
			tap_takeoffs += 1
		was_on_floor = on_floor_now
	kit.check("a single tap is exactly one hop", tap_takeoffs == 1, "%d takeoffs" % tap_takeoffs)

	# 8b. Coyote time: a jump pressed a moment after leaving the ground still works
	# (running off a bump or downhill must never eat the jump).
	# Lifted 0.9 m (well above the 0.5 m floor snap, which would otherwise pull the player back down and
	# fake a pass: Sage proved it), so only the coyote window can allow the jump. Both bounds: 2 frames
	# after leaving the ground works; 0.25 s later (15 frames, still airborne) does not.
	for delay in [2, 15]:
		await _reset(kit)
		kit.player.global_position += Vector3(0, 0.9, 0)
		await kit.physics_frames(delay)
		var airborne := not kit.player.is_on_floor()
		Input.action_press("jump")
		var best_vy := -99.0
		for i in 3:
			await kit.physics_frames(1)
			best_vy = maxf(best_vy, kit.player.velocity.y)
		Input.action_release("jump")
		if delay == 2:
			kit.check("a jump pressed 2 frames after leaving the ground still works (coyote time)", airborne and best_vy > 3.0,
					"airborne=%s, best upward speed %.2f m/s" % [airborne, best_vy])
		else:
			kit.check("a jump pressed 15 frames (0.25 s) after leaving the ground does NOT work (no air jump)", airborne and best_vy < 1.0,
					"airborne=%s, best upward speed %.2f m/s" % [airborne, best_vy])

	# 9. Sprint is continuous: holding Shift keeps full speed (with or without jumping) on
	# an open lane (south of the spawn: nothing solid for 28 m), and letting go ends it.
	for jumping in [false, true]:
		await _reset(kit)
		kit.face(Vector3.BACK)
		Input.action_press("sprint")
		Input.action_press("move_forward")
		if jumping:
			Input.action_press("jump")
		var slowest := 99.0
		var air_hops := 0
		var was_floor := true
		for i in 240:
			await kit.physics_frames(1)
			if i > 40:
				slowest = minf(slowest, kit.horizontal_speed())
			var floor_now := kit.player.is_on_floor()
			if was_floor and not floor_now:
				air_hops += 1
			was_floor = floor_now
		var label := "while jumping" if jumping else "on foot"
		kit.check("holding Shift keeps sprinting %s: never under 6.5 m/s for 4 s" % label, slowest >= 6.5, "slowest %.2f m/s" % slowest)
		if not jumping:
			kit.check("running on foot never hops off the ground by itself (floor snap)", air_hops == 0, "%d times left the ground" % air_hops)
		Input.action_release("jump")
		Input.action_release("sprint")
		await kit.physics_frames(40)
		if not jumping:
			kit.check("letting go of Shift ends the sprint (back to walk speed 4 m/s)", kit.horizontal_speed() < 4.3 and kit.horizontal_speed() > 3.5,
					"%.2f m/s 40 frames after release" % kit.horizontal_speed())
		Input.action_release("move_forward")

	kit.finish()


func _reset(kit: PlaytestKit) -> void:
	kit.face(Vector3.FORWARD)
	await kit.teleport(Vector3(0, NAN, 0), 40)


## Presses `actions`, and returns how many physics frames passed until `done` is true.
## Releases the actions afterwards. Returns the frame limit if it never happened.
func _frames_until(kit: PlaytestKit, actions: Array, done: Callable, limit: int) -> int:
	for action in actions:
		Input.action_press(action)
	var frames := 0
	while frames < limit:
		await kit.physics_frames(1)
		frames += 1
		if done.call():
			break
	for action in actions:
		Input.action_release(action)
	return frames
