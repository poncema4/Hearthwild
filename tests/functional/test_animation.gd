extends SceneTree
## Functional test: the character's animation is anatomically right and smooth.
##
## It measures WHERE the feet and hands actually are (in the model's own space:
## x right, y up, -z forward), never just the joint angles, because an angle
## check agrees with whatever sign the code uses (lesson 42: the jump pose kicked
## the legs backwards and folded the arms across the body, and the first test
## enshrined it). A walk, a sprint, a held-Space hop sequence and a stop are
## recorded frame by frame.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_animation.gd
## Exit code = number of failures (0 = all pass).

const SHOULDER_Y := 1.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var model: AnimalModel = kit.player.get_node("Body/Model")
	var dt := 1.0 / 60.0

	# The animation must run on the physics tick, in lockstep with the movement it shows. In
	# `_process` a slow renderer froze it while the physics kept running (lesson 43).
	kit.check("the animation runs on the physics tick, not per rendered frame", model.is_physics_processing() and not model.is_processing(),
			"physics=%s process=%s" % [model.is_physics_processing(), model.is_processing()])

	# 1. Standing still: feet down, hands hanging below the shoulders.
	await kit.teleport(Vector3(0, NAN, 0), 60)
	var idle := model.limb_positions()
	kit.check("standing: feet on the ground, hands hanging well below the shoulders",
			idle["foot_l"].y < 0.12 and idle["foot_r"].y < 0.12 and idle["hand_l"].y < SHOULDER_Y - 0.25 and idle["hand_r"].y < SHOULDER_Y - 0.25,
			"feet y %.2f/%.2f, hands y %.2f/%.2f" % [idle["foot_l"].y, idle["foot_r"].y, idle["hand_l"].y, idle["hand_r"].y])

	# Record a walk, a sprint, a held-Space hop sequence and a stop, frame by frame.
	var walk := await _record(kit, model, ["move_forward"], 100, Vector3.BACK, 40)
	var sprint := await _record(kit, model, ["move_forward", "sprint"], 100, Vector3.BACK, 40)
	var hops := await _record(kit, model, ["move_forward", "sprint", "jump"], 220, Vector3.BACK, 0)
	var stop := await _record_stop(kit, model)

	# 2. Walk: each foot reaches forward AND back; the arm opposite the forward foot is forward.
	var reach := _reach(walk)
	kit.check("walking: the feet swing 0.2 m or more both forward and back of the hips", reach.x <= -0.2 and reach.y >= 0.2,
			"forward reach %.2f m, back reach %.2f m" % [-reach.x, reach.y])
	var opposite := _arm_leg_opposition(walk)
	kit.check("walking: the arm opposite the forward foot is the forward one (95%+ of 20+ stride frames)", opposite[1] >= 20 and opposite[0] >= 0.95,
			"%.0f%% of %d frames" % [opposite[0] * 100.0, opposite[1]])
	var symmetry := _symmetry(walk)
	kit.check("walking: the left and right legs swing equally (within 15%)", symmetry <= 0.15, "difference %.0f%%" % (symmetry * 100.0))
	var skate := _skating(walk, kit.player.walk_speed, dt)
	kit.check("walking: the planted foot barely slides, in either direction (signed median foot speed between -15% and +50% of body speed)", skate > -0.15 and skate < 0.5,
			"stance foot moves at %+.0f%% of body speed (positive = with the body, negative = dragged backwards)" % (skate * 100.0))

	# Cadence: a believable walk is about 3-4.6 steps a second (a frantic stride passes the skating check).
	var crossings := 0
	for i in range(1, walk.size()):
		if walk[i - 1]["leg_l"] * walk[i]["leg_l"] < 0.0:
			crossings += 1
	var steps_per_second: float = crossings / (walk.size() / 60.0)
	kit.check("walking: a believable cadence (3 to 4.6 steps per second)", steps_per_second >= 3.0 and steps_per_second <= 4.6,
			"%.1f steps per second" % steps_per_second)

	# 3. Sprint: longer strides than the walk, and leaning forward.
	var sprint_reach := _reach(sprint)
	kit.check("sprinting: longer strides than walking", -sprint_reach.x > -reach.x + 0.05, "forward reach %.2f m vs %.2f m walking" % [-sprint_reach.x, -reach.x])
	var lean := _head_lean(sprint)
	kit.check("sprinting: the head leads the body forward (at least 3 cm)", lean <= -0.03, "head is %.2f m ahead of the hips" % -lean)

	# 4. Jump (held Space, sprinting): while airborne both feet are in FRONT of the hips,
	# the arms are out to the sides and never cross the body, and are raised above the shoulders on the way up.
	var airborne := hops.filter(func(f): return f["air"] > 0.9)
	var feet_ahead := 0
	var arms_out := 0
	var arms_up := 0
	for f in airborne:
		if f["foot_l"].z < -0.1 and f["foot_r"].z < -0.1:
			feet_ahead += 1
		if f["hand_l"].x > 0.45 and f["hand_r"].x < -0.45:
			arms_out += 1
		if f["hand_l"].y > SHOULDER_Y + 0.05 and f["hand_r"].y > SHOULDER_Y + 0.05:
			arms_up += 1
	kit.check("jumping: both feet are in front of the hips (knees up, not kicked back)", airborne.size() > 40 and feet_ahead >= airborne.size() * 0.95,
			"%d of %d airborne frames" % [feet_ahead, airborne.size()])
	kit.check("jumping: the arms are out to the sides (hands more than 0.45 m from the centre), never folded across the body", airborne.size() > 40 and arms_out >= airborne.size() * 0.95,
			"%d of %d airborne frames" % [arms_out, airborne.size()])
	kit.check("jumping: the hands go above the shoulders at some point (arms thrown up)", arms_up >= 5, "%d frames with hands above the shoulders" % arms_up)

	# 5. Smoothness: no joint snaps between frames (walk, sprint, hops, stop).
	var worst := 0.0
	var worst_where := ""
	for sequence in [["walk", walk], ["sprint", sprint], ["hops", hops], ["stop", stop]]:
		var frames: Array = sequence[1]
		for i in range(1, frames.size()):
			for key in ["leg_l", "leg_r", "arm_lx", "arm_rx", "arm_lz", "arm_rz"]:
				var change := absf(frames[i][key] - frames[i - 1][key])
				if change > worst:
					worst = change
					worst_where = "%s frame %d %s" % [sequence[0], i, key]
	kit.check("no joint snaps: the biggest change in one frame is under 0.35 rad (the model limits joints to 20 rad/s)", worst < 0.35, "worst %.3f rad (%s)" % [worst, worst_where])
	var worst_move := 0.0
	for sequence in [walk, sprint, hops, stop]:
		for i in range(1, sequence.size()):
			for key in ["foot_l", "foot_r", "hand_l", "hand_r"]:
				worst_move = maxf(worst_move, sequence[i][key].distance_to(sequence[i - 1][key]))
	kit.check("no teleporting limbs: a foot or hand never moves more than 0.2 m in a frame", worst_move < 0.2, "worst %.3f m" % worst_move)

	# 5b. A sharp 180 degree turn at sprint speed: while the body still slides BACKWARDS relative to
	# the way it faces, the legs must not keep running a forward stride (the moonwalk Animator found).
	await kit.teleport(Vector3(0, NAN, 0), 40)
	kit.face(Vector3.BACK)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await kit.physics_frames(60)
	kit.face(Vector3.FORWARD)  # the controls now point the opposite way
	var sliding_frames := 0
	var leg_change_total := 0.0
	var previous_leg: float = model.leg_angles().x
	for i in 40:
		await kit.physics_frames(1)
		var body_forward: Vector3 = -(kit.player.get_node("Body") as Node3D).global_transform.basis.z
		var flat_velocity := Vector3(kit.player.velocity.x, 0, kit.player.velocity.z)
		var leg := model.leg_angles().x
		if flat_velocity.length() > 3.0 and flat_velocity.normalized().dot(body_forward) < 0.0:
			sliding_frames += 1
			leg_change_total += absf(leg - previous_leg)
		previous_leg = leg
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var mean_leg_change := leg_change_total / maxf(sliding_frames, 1)
	kit.check("a sharp turn at sprint: while sliding backwards the legs do not keep striding (mean change under 0.1 rad/frame over 3+ frames)",
			sliding_frames >= 3 and mean_leg_change < 0.1, "%d sliding frames, mean leg change %.3f rad/frame (a running stride is about 0.2)" % [sliding_frames, mean_leg_change])

	# 6. After the stop the character settles back to the idle pose.
	var last: Dictionary = stop[stop.size() - 1]
	kit.check("after stopping, the pose is idle again (legs level, hands hanging)",
			absf(last["leg_l"]) < 0.05 and absf(last["leg_r"]) < 0.05 and last["hand_l"].y < SHOULDER_Y - 0.25 and last["air"] < 0.05,
			"legs %.2f/%.2f, left hand y %.2f, air %.2f" % [last["leg_l"], last["leg_r"], last["hand_l"].y, last["air"]])
	kit.finish()


## Holds `actions` for `frames` frames (after `warmup` frames) and records the pose every frame.
func _record(kit: PlaytestKit, model: AnimalModel, actions: Array, frames: int, facing: Vector3, warmup: int) -> Array:
	await kit.teleport(Vector3(0, NAN, 0), 40)
	kit.face(facing)
	for action in actions:
		Input.action_press(action)
	await kit.physics_frames(warmup)
	var out := []
	for i in frames:
		await kit.physics_frames(1)
		out.append(_sample(model))
	for action in actions:
		Input.action_release(action)
	await kit.physics_frames(30)
	return out


## Sprint, then release everything: records the slow-down.
func _record_stop(kit: PlaytestKit, model: AnimalModel) -> Array:
	await kit.teleport(Vector3(0, NAN, 0), 40)
	kit.face(Vector3.BACK)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await kit.physics_frames(60)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var out := []
	for i in 90:
		await kit.physics_frames(1)
		out.append(_sample(model))
	return out


func _sample(model: AnimalModel) -> Dictionary:
	var limbs := model.limb_positions()
	var arm_l: Node3D = model.find_child("ArmL", true, false)
	var arm_r: Node3D = model.find_child("ArmR", true, false)
	var head: Node3D = model.find_child("Head", true, false)
	return {
		"foot_l": limbs["foot_l"], "foot_r": limbs["foot_r"], "hand_l": limbs["hand_l"], "hand_r": limbs["hand_r"],
		"foot_l_world": (model.find_child("LegL", true, false).get_node("Paw") as Node3D).global_position,
		"foot_r_world": (model.find_child("LegR", true, false).get_node("Paw") as Node3D).global_position,
		"leg_l": model.leg_angles().x, "leg_r": model.leg_angles().y,
		"arm_lx": model.arm_angles().x, "arm_rx": model.arm_angles().y, "arm_lz": arm_l.rotation.z, "arm_rz": arm_r.rotation.z,
		"head_z": model.to_local(head.global_position).z, "air": model.air_amount(),
	}


## (most-forward foot z, most-backward foot z) over a recording; forward is negative z.
func _reach(frames: Array) -> Vector2:
	var forward := 0.0
	var back := 0.0
	for f in frames:
		forward = minf(forward, minf(f["foot_l"].z, f["foot_r"].z))
		back = maxf(back, maxf(f["foot_l"].z, f["foot_r"].z))
	return Vector2(forward, back)


## [fraction of striding frames where the arm opposite the forward foot is the forward arm, number of such frames]
func _arm_leg_opposition(frames: Array) -> Array:
	var good := 0
	var total := 0
	for f in frames:
		var separation: float = f["foot_l"].z - f["foot_r"].z
		if absf(separation) < 0.25:
			continue
		total += 1
		# Left foot forward (smaller z) means the RIGHT hand should be the forward one.
		var left_foot_forward: bool = separation < 0.0
		var right_hand_forward: bool = f["hand_r"].z < f["hand_l"].z
		if left_foot_forward == right_hand_forward:
			good += 1
	return [float(good) / maxf(total, 1), total]


## Relative difference between the left and right legs' peak swing.
func _symmetry(frames: Array) -> float:
	var peak_l := 0.0
	var peak_r := 0.0
	for f in frames:
		peak_l = maxf(peak_l, absf(f["leg_l"]))
		peak_r = maxf(peak_r, absf(f["leg_r"]))
	return absf(peak_l - peak_r) / maxf(maxf(peak_l, peak_r), 0.001)


## Median speed of the lower (planted) foot relative to the ground, as a fraction of body speed.
## SIGNED along the direction of travel (+z here): 0 = planted, positive = the foot still
## travels forward over the ground (slides along with the body), negative = the foot is
## dragged backwards (skating the other way, as with a too-fast stride).
func _skating(frames: Array, body_speed: float, dt: float) -> float:
	var speeds: Array[float] = []
	for i in range(1, frames.size()):
		var lower := "foot_l_world" if frames[i]["foot_l_world"].y < frames[i]["foot_r_world"].y else "foot_r_world"
		var step: Vector3 = frames[i][lower] - frames[i - 1][lower]
		speeds.append(step.dot(Vector3.BACK) / dt)  # the walk is recorded heading +z
	speeds.sort()
	return speeds[speeds.size() / 2] / body_speed


## Average z of the head in the model's space: negative = leaning forward.
func _head_lean(frames: Array) -> float:
	var total := 0.0
	for f in frames:
		total += f["head_z"]
	return total / frames.size()
