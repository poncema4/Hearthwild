extends SceneTree
## Functional test: the interact key (E), the prompt, doors and the notice board.
##
## Drives the REAL player: stands in front of a cottage door, presses E, walks
## through, and checks what the on-screen prompt says at every step. Every check
## was proven by breaking the feature (AGENTS.md section 8 and lesson 41).
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_interaction.gd
## Exit code = number of failures (0 = all pass).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var player := kit.player
	var interactor: Interactor = player.get_node("Interactor")
	var hud: InteractionPrompt = player.get_node("HUD")
	var house := kit.village.houses[0]
	var door := house.door
	var body := player.get_node("Body") as Node3D

	var bound_to_e := false
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_E:
			bound_to_e = true
	kit.check("the interact action exists and is bound to E", InputMap.has_action("interact") and bound_to_e)

	# Stand 1.5 m in front of the door, facing it.
	var toward_door: Vector3 = -house.global_transform.basis.z
	await _stand(kit, house.door_outside(1.5), toward_door)
	kit.check("a closed door in front of the player is the target", interactor.current_target == door and not door.is_open,
			"target=%s" % interactor.current_target)
	kit.check("the prompt says Open door", hud.prompt_text() == "Open door", "prompt='%s'" % hud.prompt_text())

	# Turned away: no target, no prompt (the player has to face a door to use it).
	await _stand(kit, house.door_outside(1.5), -toward_door)
	kit.check("facing away from the door: no target and no prompt", interactor.current_target == null and hud.prompt_text() == "",
			"target=%s prompt='%s'" % [interactor.current_target, hud.prompt_text()])

	# Too far away.
	await _stand(kit, house.door_outside(6.0), toward_door)
	kit.check("6 m from the door: no target", interactor.current_target == null, "target=%s" % interactor.current_target)

	# Press E: the door swings open (and the prompt hides while it moves).
	await _stand(kit, house.door_outside(1.5), toward_door)
	await kit.tap("interact")
	await kit.physics_frames(3)  # the interactor refreshes the prompt a frame after the press
	kit.check("pressing E starts the door swinging; no prompt mid-swing", door.is_open and door.is_moving() and hud.prompt_text() == "",
			"open=%s moving=%s prompt='%s'" % [door.is_open, door.is_moving(), hud.prompt_text()])
	await kit.physics_frames(50)
	kit.check("the door ends fully open (about 100 degrees) and at rest", door.is_open and not door.is_moving() and absf(door.leaf_angle_degrees() - 100.0) < 2.0,
			"angle %.1f degrees" % door.leaf_angle_degrees())
	kit.check("the prompt now says Close door", hud.prompt_text() == "Close door", "prompt='%s'" % hud.prompt_text())

	# The open door lets the player in.
	kit.face(toward_door)
	await kit.hold(["move_forward"], 100)
	kit.check("after pressing E the player can walk in", house.is_inside(player.global_position), kit.where())

	# Standing IN the doorway, the door cannot close (it would trap the player).
	await _stand(kit, house.door_center(), toward_door)
	door.close()
	await kit.physics_frames(50)
	kit.check("a door will not close on a player standing in the doorway", door.is_open and interactor.current_target == null,
			"open=%s target=%s" % [door.is_open, interactor.current_target])

	# From outside again: E closes it, and it blocks again.
	await _stand(kit, house.door_outside(1.5), toward_door)
	await kit.tap("interact")
	await kit.physics_frames(50)
	kit.check("pressing E again closes the door", not door.is_open and absf(door.leaf_angle_degrees()) < 2.0,
			"open=%s angle %.1f" % [door.is_open, door.leaf_angle_degrees()])
	kit.face(toward_door)
	await kit.hold(["move_forward"], 100)
	kit.check("the closed door blocks the player again", not house.is_inside(player.global_position), kit.where())

	# The notice board shows its message.
	var board: Node3D = null
	for prop in kit.village.props:
		if prop.get_meta("kind", "") == "NoticeBoard":
			board = prop
	var reader: Interactable = board.get_node("ReadBoard")
	var fired := [0]
	reader.interacted.connect(func(_who): fired[0] += 1)
	await _stand(kit, reader.global_position + Vector3(0, 0, 0.8), Vector3.FORWARD)
	kit.check("standing at the notice board: prompt is Read the notice board", hud.prompt_text() == "Read the notice board", "prompt='%s'" % hud.prompt_text())
	await kit.tap("interact")
	await kit.physics_frames(3)
	kit.check("pressing E at the notice board shows its message and fires `interacted`",
			hud.message_text().begins_with("Welcome to Hearthwild") and fired[0] == 1, "message='%s', fired %d" % [hud.message_text(), fired[0]])

	# Edges of the rules (a regression in any number here must fail, not just the dead-centre case).
	# Cone: a door 60 degrees off the facing is still targeted; 100 degrees is not.
	var base_yaw := atan2(-toward_door.x, -toward_door.z)
	for entry in [[60.0, true], [-60.0, true], [100.0, false], [-100.0, false]]:
		await _stand(kit, house.door_outside(1.5), toward_door)
		body.rotation.y = base_yaw + deg_to_rad(entry[0])
		await kit.physics_frames(4)
		var targeted := interactor.current_target == door
		kit.check("a door %+.0f degrees off the facing is %s" % [entry[0], "targeted" if entry[1] else "NOT targeted"], targeted == entry[1],
				"targeted=%s" % targeted)
	# Range: 2.3 m from the door's anchor is in range, 3.0 m is not (the range is 2.6 m).
	for entry in [[2.15, true], [2.85, false]]:
		await _stand(kit, house.door_outside(entry[0]), toward_door)
		kit.check("%.1f m from the door is %s" % [entry[0] + 0.15, "in range" if entry[1] else "out of range"], (interactor.current_target == door) == entry[1],
				"target=%s" % interactor.current_target)
	# The door will not close on someone standing beside the doorway line, but will for someone clear of it.
	door.open_instantly()
	await _stand(kit, house.door_outside(1.5), toward_door)
	await kit.teleport(Vector3(house.to_global(Vector3(0.5, 0, House.DEPTH * 0.5 - 0.15 + 0.45)).x, NAN, house.to_global(Vector3(0.5, 0, House.DEPTH * 0.5 - 0.15 + 0.45)).z), 10)
	door.close()
	await kit.physics_frames(50)
	kit.check("a player 0.45 m outside the door leaf, off to the side, still blocks the door from closing", door.is_open, "open=%s" % door.is_open)
	await kit.teleport(Vector3(house.door_outside(1.2).x, NAN, house.door_outside(1.2).z), 10)
	door.close()
	await kit.physics_frames(50)
	kit.check("a player 1.2 m outside does not block it: the door closes", not door.is_open, "open=%s" % door.is_open)
	# The notice-board reader is on the board (it once followed the reader wherever it was).
	var board_node: Node3D = null
	for prop in kit.village.props:
		if prop.get_meta("kind", "") == "NoticeBoard":
			board_node = prop
	kit.check("the notice board's reader is within 1.5 m of the board itself",
			board_node.get_node("ReadBoard").global_position.distance_to(board_node.global_position) < 1.5)

	# Snapping a door in the same frame as a swing must leave the leaf solid (a deferred collision write
	# once landed after the snap and left a closed door you could walk through).
	door.open_instantly()
	door.close_instantly()
	door.open()
	door.close_instantly()
	await kit.physics_frames(6)
	var snap_hit := get_root().get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			house.to_global(Vector3(0, 1.0, House.DEPTH * 0.5 + 1.0)), house.to_global(Vector3(0, 1.0, House.DEPTH * 0.5 - 1.5))))
	kit.check("a door snapped shut in the same frame as a swing is still solid", not door.is_open and not snap_hit.is_empty(), "open=%s hit=%s" % [door.is_open, snap_hit.get("collider")])

	# Nothing in range: pressing E does nothing and breaks nothing.
	await _stand(kit, Vector3(0, 0, 0), Vector3.FORWARD)
	var pressed := interactor.try_interact()
	kit.check("pressing E with nothing near does nothing", not pressed and interactor.current_target == null)
	kit.finish()


## Puts the player at `where`, the body AND camera facing `facing`, and lets the interactor update.
func _stand(kit: PlaytestKit, where: Vector3, facing: Vector3) -> void:
	await kit.teleport(Vector3(where.x, NAN, where.z), 15)
	kit.face(facing)
	var flat := Vector3(facing.x, 0, facing.z).normalized()
	(kit.player.get_node("Body") as Node3D).rotation.y = atan2(-flat.x, -flat.z)
	await kit.physics_frames(4)
