extends SceneTree
## Functional test: third-person player movement in the real world scene.
## Presses the real input actions and checks physics results.
## Run: godot --headless --path . --script res://tests/functional/test_player_movement.gd
## Exit code = number of failures (0 = all pass).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)

	for action in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]:
		var events := InputMap.action_get_events(action) if InputMap.has_action(action) else []
		kit.check("input action " + action, events.size() == 1, events[0].as_text() if events.size() else "missing")
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	kit.check("main scene set", main_path == PlaytestKit.WORLD_SCENE, main_path)

	await kit.load_world()
	kit.check("player is PlayerController", kit.player is PlayerController)
	kit.check("camera rig is ThirdPersonCamera", kit.camera_rig is ThirdPersonCamera)
	kit.check("camera is current", kit.spring_arm.get_node("Camera3D").current)
	var ground := kit.terrain.height_at(0, 0)
	kit.check("player lands on the ground at spawn", kit.player.is_on_floor()
		and absf(kit.player.global_position.y - ground) < 0.1, kit.where())

	# Walk forward in the flat spawn clearing (camera faces -Z at start).
	var start := kit.player.global_position
	await kit.hold(["move_forward"], 60)
	var d := kit.player.global_position - start
	kit.check("W moves forward (-Z, camera facing)", d.z < -3.0 and d.z > -4.2 and absf(d.x) < 0.2,
		"dz=%.2f dx=%.2f" % [d.z, d.x])
	var body_yaw: float = kit.player.get_node("Body").rotation.y
	kit.check("body turns to face travel", absf(wrapf(body_yaw, -PI, PI)) < 0.1, "yaw=%.3f" % body_yaw)

	# Sprint vs walk, measured as steady-state speed.
	await kit.teleport(Vector3(0, NAN, 0))
	await kit.hold(["move_forward"], 40)
	var walk := kit.horizontal_speed()
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await kit.physics_frames(40)
	var sprint := kit.horizontal_speed()
	Input.action_release("sprint")
	Input.action_release("move_forward")
	kit.check("walk speed is walk_speed", absf(walk - kit.player.walk_speed) < 0.1, "%.2f" % walk)
	kit.check("sprint speed is sprint_speed", absf(sprint - kit.player.sprint_speed) < 0.1, "%.2f" % sprint)

	await kit.physics_frames(30)
	kit.check("stops when keys released", kit.horizontal_speed() < 0.01, kit.where())

	# Jump in the clearing.
	await kit.teleport(Vector3(0, NAN, 0), 30)
	var before_jump := kit.player.global_position.y
	await kit.tap("jump")
	await kit.physics_frames(18)
	kit.check("jump leaves the ground", kit.player.global_position.y > before_jump + 0.8,
		"rise=%.2f" % (kit.player.global_position.y - before_jump))
	await kit.physics_frames(90)
	kit.check("lands again after jump", kit.player.is_on_floor(), kit.where())

	# Walls: the east boundary wall (inner face 2 m inside the terrain edge: x = 118 on the 240 m world) stops the player.
	# Start well inside and walk long enough that a missing wall would carry
	# the player off the edge (x > 60) and into a respawn.
	var wall_face: float = kit.terrain.half_size() - 2.0  # derived, not a literal: the world grew once already
	kit.face(Vector3.RIGHT)
	await kit.teleport(Vector3(wall_face - 8.0, NAN, 0))
	await kit.hold(["move_forward"], 300)
	var x := kit.player.global_position.x
	kit.check("boundary wall stops the player at its face", x > wall_face - 0.8 and x < wall_face - 0.3,
		"x=%.2f, wall face x=%.1f" % [x, wall_face])

	# Trees are solid: walk into the tree nearest the spawn.
	var trees := kit.nature.get_trees()
	kit.check("trees were placed", trees.size() > 20, "%d trees" % trees.size())
	if trees.size() > 0:
		var tree_node := _nearest(trees, Vector3.ZERO)
		var trunk := tree_node.get_node("TrunkCollision")
		var trunk_radius: float = (trunk.shape as CylinderShape3D).radius * tree_node.scale.x
		var from_tree := Vector3(-tree_node.position.x, 0, -tree_node.position.z).normalized()
		await kit.teleport(Vector3(tree_node.position.x, NAN, tree_node.position.z) + from_tree * 3.0)
		kit.face(-from_tree)
		# Track the closest the player gets, every frame: against a round
		# trunk the player correctly slides around it while W is held, so the
		# final position says nothing. Closest gap must be AT the trunk
		# surface: not inside it (no collision) and not short of it (blocked
		# by something else).
		var closest := INF
		Input.action_press("move_forward")
		for i in 90:
			await physics_frame
			var p := kit.player.global_position
			closest = minf(closest, Vector2(p.x - tree_node.position.x, p.z - tree_node.position.z).length())
		Input.action_release("move_forward")
		var expected := trunk_radius + 0.4
		kit.check("tree trunk stops the player", closest > expected - 0.05 and closest < expected + 0.1,
			"closest gap=%.2f expected %.2f (trunk %.2f + player 0.40)" % [closest, expected, trunk_radius])

	# Opposite keys cancel out. Measured horizontally, after the player has
	# settled: a drop from the teleport would otherwise count as movement.
	await kit.teleport(Vector3(0, NAN, 0), 60)
	var before := kit.player.global_position
	await kit.hold(["move_forward", "move_back"], 60)
	await kit.hold(["move_left", "move_right"], 60)
	var drift := Vector2(kit.player.global_position.x - before.x, kit.player.global_position.z - before.z).length()
	kit.check("opposite keys cancel out (W+S, A+D)", drift < 0.05, "horizontal drift=%.3f m" % drift)

	# The camera arm pulls in against a tree trunk. The arm is offset 0.5 m
	# to the camera's right (shoulder), so the trunk must sit ON the arm's
	# line, not on the player's.
	if trees.size() > 0:
		var trunk_tree := _nearest(trees, Vector3(20, 0, 20))
		var look := Vector3.FORWARD
		var right := Vector3.RIGHT
		var arm_line_point := Vector3(trunk_tree.position.x, 0, trunk_tree.position.z) + look * 2.0
		var player_spot := arm_line_point - right * 0.5
		kit.face(look)
		await kit.teleport(Vector3(player_spot.x, NAN, player_spot.z), 30)
		var trunk_r: float = ((trunk_tree.get_node("TrunkCollision") as CollisionShape3D).shape as CylinderShape3D).radius * trunk_tree.scale.x
		var hit := kit.spring_arm.get_hit_length()
		var expected_hit := 2.0 - trunk_r - 0.2
		kit.check("camera arm pulls in against a tree trunk", absf(hit - expected_hit) < 0.35,
			"arm %.2f m of %.1f, expected about %.2f (2.0 - trunk %.2f - probe 0.2)" % [hit, kit.spring_arm.spring_length, expected_hit, trunk_r])

	# Falling out of the world respawns at the spawn point.
	await kit.teleport(Vector3(0, -60, 0), 5)
	var back := kit.player.global_position
	kit.check("falling out of the world respawns at spawn",
		Vector2(back.x, back.z).length() < 0.5 and back.y > -5.0, kit.where())

	kit.finish()


func _nearest(nodes: Array[Node3D], point: Vector3) -> Node3D:
	var best: Node3D = nodes[0]
	for node in nodes:
		if node.position.distance_to(point) < best.position.distance_to(point):
			best = node
	return best
