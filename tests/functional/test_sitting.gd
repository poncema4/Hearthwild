extends SceneTree
## Functional test: sitting on benches. Every bench has a seat; E sits (settled onto the seat, legs forward, hands in
## the lap, no collision); E, Space or a FRESH move key stands up in front of the bench (a held key does not, and the
## E that stands up does not sit straight back down); an occupied seat refuses a second sitter; a bench that vanishes or
## a respawn releases the sitter; a seated player cannot go to bed.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_sitting.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var player: PlayerController
var model: AnimalModel
var shape: CollisionShape3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	player = kit.player
	model = player.get_node("Body/Model")
	shape = player.get_node("CollisionShape3D")
	var hud: InteractionPrompt = player.get_node("HUD")
	var interactor: Interactor = player.get_node("Interactor")
	var screen: SharedScreen = kit.village.screen

	# 1. Every bench has a seat.
	var benches: Array[Node3D] = []
	for prop in kit.village.props:
		if prop.get_meta("kind", "") == "Bench":
			benches.append(prop)
	benches.append_array(screen.benches)
	var without := 0
	for bench in benches:
		var seat := bench.get_node_or_null("Seat") as Seat
		if seat == null or seat.get_prompt() != "Sit down":
			without += 1
	kit.check("every one of the %d benches (village and screen) has a seat that says Sit down" % benches.size(), benches.size() >= 16 and without == 0, "%d benches, %d without a seat" % [benches.size(), without])

	# 2. Facing a bench, E sits: settled on the seat, facing the way it faces, legs forward, hands in the lap.
	var bench: Node3D = screen.benches[1]
	var seat: Seat = bench.get_node("Seat")
	await _stand_before(bench)
	kit.check("standing before the bench, facing it, the prompt says Sit down", hud.prompt_text() == "Sit down" and interactor.current_target == seat, "'%s' target %s" % [hud.prompt_text(), interactor.current_target])
	await kit.tap("interact")
	await kit.physics_frames(40)
	var front := seat.front()
	var body_forward := -(player.get_node("Body") as Node3D).global_transform.basis.z
	kit.check("E sits: the player is on the seat, the seat knows its sitter, there is no collision and the model is seated",
			player.seat == seat and seat.occupant == player and shape.disabled and model.is_seated() and player.global_position.distance_to(seat.sit_point()) < 0.05,
			"seat %s occupant %s disabled=%s seated=%s %.2f m from the seat" % [player.seat, seat.occupant, shape.disabled, model.is_seated(), player.global_position.distance_to(seat.sit_point())])
	kit.check("the sitter faces the way the bench faces", body_forward.dot(front) > 0.95, "dot %.2f" % body_forward.dot(front))
	kit.check("the HUD says how to stand up", hud.message_text().contains("stand up"), "'%s'" % hud.message_text())
	var limbs := model.limb_positions()
	var foot_l: Vector3 = limbs["foot_l"]
	var foot_r: Vector3 = limbs["foot_r"]
	var hand_l: Vector3 = limbs["hand_l"]
	var hand_r: Vector3 = limbs["hand_r"]
	kit.check("the legs stick straight out forward at seat height (feet 0.35 to 0.7 m up, at least 0.3 m in front of the body)",
			foot_l.y > 0.35 and foot_l.y < 0.7 and foot_r.y > 0.35 and foot_r.y < 0.7 and foot_l.z < -0.3 and foot_r.z < -0.3, "feet %s %s" % [foot_l, foot_r])
	kit.check("the hands rest beside the thighs (0.55 to 0.85 m up, not raised)", hand_l.y > 0.55 and hand_l.y < 0.85 and hand_r.y > 0.55 and hand_r.y < 0.85, "hands %s %s" % [hand_l, hand_r])
	kit.check("while seated no prompt is shown (E stands up, so no other prompt may offer anything)", hud.prompt_text() == "" and interactor.current_target == null, "'%s' target %s" % [hud.prompt_text(), interactor.current_target])
	var seat_top := bench.global_position.y + 0.5  # a literal on purpose: the bench's seat is 0.5 m high
	var thigh_bottom := model.leg_bottom_y()
	kit.check("the thighs REST on the seat: their underside is within 3 cm below to 6 cm above the seat top (it was 12 cm inside it before the hips were raised)", thigh_bottom > seat_top - 0.03 and thigh_bottom < seat_top + 0.06, "thigh underside %.3f, seat top %.3f" % [thigh_bottom, seat_top])
	var behind_backrest := 0.0
	for mesh in model.all_meshes():
		if mesh.name in ["Torso", "Stem", "Tip", "Stub"]:
			var local_box := bench.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
			behind_backrest = maxf(behind_backrest, -0.25 - local_box.position.z)  # the backrest's BACK face is at local z = -0.25: inside the 6 cm backrest is invisible, beyond it is a tail poking out
	kit.check("nothing of the sitter pokes out through the back of the backrest (%.3f m beyond it, limit 1 cm)" % behind_backrest, behind_backrest < 0.01, "%.3f m" % behind_backrest)
	var parked := player.global_position
	await kit.physics_frames(60)
	kit.check("nothing moves a seated player who does nothing", player.global_position.distance_to(parked) < 0.01 and player.seat == seat, "moved %.3f" % player.global_position.distance_to(parked))
	kit.check("an occupied seat (and every other seat, for this player) cannot be used", not seat.can_interact(player) and not (screen.benches[0].get_node("Seat") as Seat).can_interact(player))

	# 3. Every stand-up key works, once, and none of them sits straight back down.
	var stand_failures := []
	for key in ["move_forward", "move_back", "move_left", "move_right", "jump", "interact"]:
		if player.seat == null:
			seat.interact(player)
			await kit.physics_frames(6)
		await kit.tap(key)
		await kit.physics_frames(10)
		var ok := player.seat == null and seat.occupant == null and not shape.disabled and not model.is_seated() and not player.input_locked \
				and player.global_position.distance_to(seat.stand_point()) < 0.35 and player.is_on_floor() \
				and _metres_in_front_of(bench, player.global_position) > 0.8 and _metres_in_front_of(bench, player.global_position) < 1.6  # independent of the seat's own constant (lesson 55)
		if not ok:
			stand_failures.append("%s: seat %s, collision disabled %s, seated %s, %.2f m from the stand point, floor %s" % [key, player.seat, shape.disabled, model.is_seated(), player.global_position.distance_to(seat.stand_point()), player.is_on_floor()])
		if key == "interact" and player.seat != null:
			stand_failures.append("the E that stood the player up sat them straight back down")
	kit.check("E, Space and each move key stand the sitter up in front of the bench, free, on the floor (and E does not re-sit)", stand_failures.is_empty(), str(stand_failures))

	# 3b. Standing up snaps to the standing pose (no legs kicking out in mid-air) and a held Space does not hop.
	seat.interact(player)
	await kit.physics_frames(30)
	Input.action_press("jump")
	await kit.physics_frames(2)
	await kit.physics_frames(1)
	var snapped_legs := model.leg_angles()
	var snapped_amount := model.seat_amount()
	var rose := 0.0
	var start_y := player.global_position.y
	for i in 40:
		await kit.physics_frames(1)
		rose = maxf(rose, player.global_position.y - start_y)
	Input.action_release("jump")
	kit.check("standing up with Space and keeping it held does not make the player hop (rose %.2f m, limit 5 cm), and the pose snapped to standing (seat amount %.2f, legs %s)" % [rose, snapped_amount, snapped_legs],
			player.seat == null and rose < 0.05 and snapped_amount == 0.0 and absf(snapped_legs.x) < 0.2 and absf(snapped_legs.y) < 0.2, "rose %.3f amount %.2f legs %s seat %s" % [rose, snapped_amount, snapped_legs, player.seat])
	await kit.physics_frames(10)
	player.global_position = seat.stand_point()
	kit.check("after letting go of Space, jumping works again", await _can_jump(), "no jump")

	# 3c. The fishing rod does not stay in the hand of a sitter.
	await _stand_before(bench)
	model.start_fishing()
	await kit.physics_frames(30)
	var rod_in_hand := model.rod_visible()
	seat.interact(player)
	await kit.physics_frames(30)
	kit.check("a fishing rod is in the hand while fishing and put away when the player sits", rod_in_hand and not model.rod_visible(), "in hand before sitting: %s, visible while seated: %s" % [rod_in_hand, model.rod_visible()])
	model.stop_fishing()
	await kit.tap("move_back")
	await kit.physics_frames(6)

	# 4. A key held from BEFORE sitting does not stand the player up (only a fresh press does).
	await _stand_before(bench)
	Input.action_press("move_forward")
	await kit.physics_frames(4)
	seat.interact(player)
	await kit.physics_frames(40)
	var still_seated := player.seat == seat
	Input.action_release("move_forward")
	await kit.physics_frames(4)
	kit.check("a move key held since before sitting does not stand the player up", still_seated and player.seat == seat, "seated %s then %s" % [still_seated, player.seat])
	await kit.tap("move_back")
	await kit.physics_frames(6)

	# 5. A seated player cannot go to bed; a respawn releases a sitter.
	seat.interact(player)
	await kit.physics_frames(6)
	var sleep_answer := kit.sleep_system.try_sleep(player, kit.village.houses[0].bed)
	kit.check("a seated player is told to stand up first and does not start sleeping", sleep_answer == "Stand up first." and not kit.sleep_system.is_sleeping(), "'%s' sleeping=%s" % [sleep_answer, kit.sleep_system.is_sleeping()])
	player.respawn()
	await kit.physics_frames(6)
	kit.check("a respawn releases a sitter (free, collision back, model standing)", player.seat == null and seat.occupant == null and not shape.disabled and not model.is_seated(), "seat %s disabled %s seated %s" % [player.seat, shape.disabled, model.is_seated()])

	# 6. A bench that vanishes under its sitter releases them.
	await kit.teleport(Vector3(0, NAN, 8), 20)
	var spare := VillageProps.bench()
	spare.name = "SpareBench"
	spare.position = Vector3(0, 0, 7)
	kit.world.add_child(spare)
	var spare_seat: Seat = spare.get_node("Seat")
	spare_seat.interact(player)
	var sat := player.seat == spare_seat
	spare.free()
	await kit.physics_frames(6)
	kit.check("freeing a bench with someone on it releases them", sat and player.seat == null and not shape.disabled and not model.is_seated(), "sat=%s seat=%s disabled=%s seated=%s" % [sat, player.seat, shape.disabled, model.is_seated()])
	kit.finish()


## Puts the player 1.5 m in front of `bench`, facing it.
func _stand_before(bench: Node3D) -> void:
	var spot := bench.to_global(Vector3(0, 0, 1.5))
	await kit.teleport(Vector3(spot.x, NAN, spot.z), 20)
	var toward := -bench.global_transform.basis.z * -1.0  # from the player to the bench is -front
	toward = (bench.global_position - spot)
	toward.y = 0.0
	toward = toward.normalized()
	kit.face(toward)
	(player.get_node("Body") as Node3D).rotation.y = atan2(-toward.x, -toward.z)
	await kit.physics_frames(8)


## How far in front of the bench (along the way it faces) a point is, in metres.
func _metres_in_front_of(bench: Node3D, point: Vector3) -> float:
	var front := bench.global_transform.basis.z
	front.y = 0.0
	return (point - bench.global_position).dot(front.normalized())


## True if holding Space makes the (standing) player leave the floor within half a second.
func _can_jump() -> bool:
	var start_y := player.global_position.y
	Input.action_press("jump")
	var rose := false
	for i in 30:
		await kit.physics_frames(1)
		if player.global_position.y - start_y > 0.3:
			rose = true
			break
	Input.action_release("jump")
	await kit.physics_frames(60)
	return rose
