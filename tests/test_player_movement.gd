extends SceneTree
## Functional test: third-person player movement on the real world scene.
## Presses the real input actions and checks physics results.
## Run: godot --headless --path . --script res://tests/test_player_movement.gd
## Exit code = number of failures (0 = all pass).

var fails := 0
var player: CharacterBody3D
var frame := 0
var phase := "settle"
var mark := Vector3.ZERO
var walk_dist := 0.0

func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + detail + ")" if detail else ""))
	if not ok:
		fails += 1

func _initialize() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "sprint"]:
		var ev := InputMap.action_get_events(a) if InputMap.has_action(a) else []
		check("input action " + a, ev.size() == 1, ev[0].as_text() if ev.size() else "missing")
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	check("main scene set", main_path == "res://scenes/world/world.tscn", main_path)
	var world: Node = load(main_path).instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	check("player is PlayerController", player is PlayerController)
	var rig = player.get_node("CameraRig")
	check("camera rig is ThirdPersonCamera", rig is ThirdPersonCamera)
	check("camera is current", player.get_node("CameraRig/Pitch/SpringArm3D/Camera3D").current)

func _physics_process(_delta: float) -> bool:
	frame += 1
	match phase:
		"settle":
			if frame == 60:
				check("player lands on floor", player.is_on_floor(), "y=%.3f" % player.global_position.y)
				mark = player.global_position
				Input.action_press("move_forward")
				phase = "walk"; frame = 0
		"walk":
			if frame == 60:
				var d := player.global_position - mark
				walk_dist = Vector2(d.x, d.z).length()
				check("W moves forward (-Z, camera facing)", d.z < -2.0 and absf(d.x) < 0.2, "dz=%.2f dx=%.2f" % [d.z, d.x])
				var body_yaw: float = player.get_node("Body").rotation.y
				check("body turns to face travel", absf(wrapf(body_yaw, -PI, PI)) < 0.1, "yaw=%.3f" % body_yaw)
				mark = player.global_position
				Input.action_press("sprint")
				phase = "sprint"; frame = 0
		"sprint":
			if frame == 60:
				var d := player.global_position - mark
				var sd := Vector2(d.x, d.z).length()
				check("sprint is faster than walk", sd > walk_dist * 1.4, "walk=%.2f sprint=%.2f" % [walk_dist, sd])
				Input.action_release("sprint"); Input.action_release("move_forward")
				phase = "stop"; frame = 0
		"stop":
			if frame == 30:
				var hv := Vector2(player.velocity.x, player.velocity.z).length()
				check("stops when keys released", hv < 0.01, "speed=%.3f" % hv)
				mark = player.global_position
				Input.action_press("jump")
				phase = "jump"; frame = 0
		"jump":
			if frame == 2:
				Input.action_release("jump")
			if frame == 20:
				check("jump leaves the ground", player.global_position.y > mark.y + 0.5, "rise=%.2f" % (player.global_position.y - mark.y))
			if frame == 120:
				check("lands again after jump", player.is_on_floor())
				# Walk back toward the wall at z=+6 and confirm it blocks the player.
				Input.action_press("move_back")
				phase = "wall"; frame = 0
		"wall":
			# Long enough to reach the wall from anywhere on this path, so a
			# missing wall would carry the player well past z=5.5.
			if frame == 360:
				Input.action_release("move_back")
				var z := player.global_position.z
				check("wall stops the player at its face", z > 5.2 and z < 5.5, "z=%.2f, wall face z=5.75" % z)
				print("RESULT: %s (%d failures)" % ["ALL PASS" if fails == 0 else "FAILED", fails])
				quit(fails)
	return false
