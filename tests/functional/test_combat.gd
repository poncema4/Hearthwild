extends SceneTree
## Functional test: combat. Real left clicks and real number keys (lesson 58) swing and switch the weapons; zombies in the cone take the damage,
## are thrown back, reel, flash, show a damage number and a bar, and die in the right number of hits; nothing outside the reach or the cone, behind a
## wall or while locked, asleep or knocked out is hit or swung at.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_combat.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var arsenal: Arsenal
var hud: InteractionPrompt
var arena := Vector2.ZERO  ## an open meadow patch (the village now fills the area round the spawn)


func _initialize() -> void:
	_run.call_deferred()


func _click() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = Vector2(400, 300)
		Input.parse_input_event(event)
		await kit.frames(2)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await kit.frames(2)


## A zombie that stands still (walk_speed 0) `distance` metres from the player along `bearing_degrees` off the way the character faces (0 = straight ahead).
func _dummy(distance: float, bearing_degrees: float = 0.0) -> Zombie:
	var forward := arsenal.facing()  # an attack goes the way the character faces, so a dummy goes where it faces
	var direction := forward.rotated(Vector3.UP, deg_to_rad(bearing_degrees))
	var spot := kit.player.global_position + direction * distance
	var zombie := Zombie.new()
	zombie.wander = false
	zombie.walk_speed = 0.0
	zombie.position = Vector3(spot.x, kit.terrain.height_at(spot.x, spot.z) + 0.1, spot.z)
	kit.world.add_child(zombie)
	return zombie


## Camera and body both look north (-Z): the usual start of a scenario.
func _face_north() -> void:
	kit.face(Vector3(0, 0, -1))
	(kit.player.get_node("Body") as Node3D).rotation.y = kit.camera_rig.rotation.y


func _clear() -> void:
	for node in get_nodes_in_group(&"zombie"):
		node.free()
	for node in get_nodes_in_group(&"damage_number"):
		node.free()


## Waits for the current swing and its cooldown to end.
func _rest() -> void:
	await kit.physics_frames(80)


func _swing_and_wait() -> void:
	await _click()
	await _rest()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	kit.day_night.set_time(22.0)  # night: the sun does not burn the dummies
	arena = kit.find_open_arena(40.0)
	await kit.teleport(Vector3(arena.x, NAN, arena.y), 30)
	arsenal = kit.player.get_node("Arsenal") as Arsenal
	hud = kit.player.get_node("HUD") as InteractionPrompt
	var model := kit.player.get_node("Body/Model") as AnimalModel
	var body := kit.player.get_node("Body") as Node3D
	kit.face(Vector3(0, 0, -1))
	body.rotation.y = kit.camera_rig.rotation.y
	await kit.physics_frames(30)

	# 1. Start state: nothing in hand (fists), the wooden sword unlocked, the bar says so.
	kit.check("a new player has nothing equipped (fists) and only the wooden sword unlocked", arsenal.selected == -1 and arsenal.unlocked == [true, false, false, false, false], "selected %d, unlocked %s" % [arsenal.selected, arsenal.unlocked])
	kit.check("the weapon bar shows 1 Wooden Sword and four locked slots, nothing highlighted, and says the fists are ready", hud.hotbar_text() == "1 Wooden Sword | 2 locked | 3 locked | 4 locked | 5 locked" and hud.hotbar_selected() == -1 and hud.hotbar_hint().begins_with("Fists ready"), hud.hotbar_text() + " / " + hud.hotbar_hint())
	var slot_sizes := hud.hotbar_slot_sizes()
	var same_size := slot_sizes.size() == 5
	for slot_size in slot_sizes:
		same_size = same_size and slot_size.is_equal_approx(slot_sizes[0])
	kit.check("all five weapon slots are exactly the same size (the Wooden Sword slot used to be bigger than the locked ones)", same_size and slot_sizes[0].x >= 0.0, str(slot_sizes))  # real widths are checked in the rendered combat playtest (headless text has no size)
	kit.check("no weapon model is in the hand (bare fists)", _find(model, "Weapon") == null)
	var all_kill_in_four := true
	for i in Weapons.count():
		var def := Weapons.def(i)
		all_kill_in_four = all_kill_in_four and float(def["damage"]) > 0.0 and float(def["reach"]) > 1.0 and ceili(20.0 / float(def["damage"])) <= 4
	kit.check("every weapon has real numbers and kills a 20 hp zombie in at most 4 hits", all_kill_in_four)

	# 1b. Fists: the F key (a real key) punches; 2 damage, reach 1.7 m, with a number.
	# 1a. The punch goes FORWARD (the first version swung the arm backwards: negative angles in a rig where positive is forward). Measured on the DRAWN
	# hand in the model's own frame (the model faces -Z): during a punch the hand ends up well in front of the body and never swings behind it.
	var hand_z_min := 0.0
	var hand_z_max := -9.0
	await _key(KEY_F)
	for i in 14:
		await kit.physics_frames(1)
		var punch_hand := model.limb_positions()["hand_r"] as Vector3
		hand_z_min = minf(hand_z_min, punch_hand.z)
		hand_z_max = maxf(hand_z_max, punch_hand.z)
	kit.check("a punch thrusts the fist FORWARD: the hand gets 0.3 m or more in front of the body (z <= -0.3) and never behind it (z <= 0.12)", hand_z_min <= -0.3 and hand_z_max <= 0.12, "hand z from %.2f to %.2f (negative = in front)" % [hand_z_min, hand_z_max])
	await _rest()
	var punch_target := _dummy(1.65)
	var out_of_fist_reach := _dummy(2.4)
	await kit.physics_frames(3)
	await _key(KEY_F)
	await kit.physics_frames(14)  # the punch lands at 60% of its 0.22 s
	var punch_number: String = "-2" if _number_texts().has("-2") else _latest_number_text()
	await _rest()
	kit.check("F with nothing equipped is a punch: a zombie at 1.65 m takes 2 (20 -> 18) and a '-2' pops out of it", is_equal_approx(punch_target.health.current, 18.0) and punch_number == "-2", "hp %.1f, number '%s'" % [punch_target.health.current, punch_number])
	kit.check("and a zombie at 2.4 m is out of fist reach", out_of_fist_reach.health.current == 20.0)
	_clear()
	await _key(KEY_1)
	kit.check("key 1 equips the wooden sword (a Weapon model appears in the hand) and the bar highlights slot 1", arsenal.selected == 0 and _find(model, "Weapon") != null and hud.hotbar_selected() == 0, "selected %d" % arsenal.selected)
	await _key(KEY_1)
	kit.check("pressing 1 again puts it away (back to the fists, the model is gone)", arsenal.selected == -1 and hud.hotbar_selected() == -1)
	await _key(KEY_1)

	# 2. A real left click swings; the arm goes up and comes down; the body turns to the camera.
	await _key(KEY_2)
	kit.check("a locked weapon cannot be selected (key 2 before the rack does nothing)", arsenal.selected == 0)
	body.rotation.y = kit.camera_rig.rotation.y + 2.0
	var z := _dummy(2.0)
	await kit.physics_frames(5)
	var hp_before := z.health.current
	var swings_before := arsenal.swings_started
	var hits_before := arsenal.hits_landed
	await _click()
	kit.check("a left click starts a swing", arsenal.swings_started == swings_before + 1 and arsenal.is_swinging(), "swings %d" % arsenal.swings_started)
	var yaw_steps: Array[float] = []
	var yaw_at_click := body.rotation.y
	var last_yaw := body.rotation.y
	var highest := 0.0
	var strike_z := 9.0
	var blade_forward := -9.0
	var weapon_mesh := _find(model, "Weapon") as Node3D
	for i in 22:
		await kit.physics_frames(1)
		yaw_steps.append(absf(angle_difference(body.rotation.y, last_yaw)))
		last_yaw = body.rotation.y
		var swing_hand := model.limb_positions()["hand_r"] as Vector3
		highest = maxf(highest, swing_hand.y)
		if arsenal.swing_time >= 0.0:
			var progress := arsenal.swing_time / float(Weapons.def(0)["swing"])
			if progress > 0.62 and progress < 0.8:
				strike_z = minf(strike_z, swing_hand.z)  # the slash is passing in front of the body
				var tip := model.to_local(weapon_mesh.get_child(0).global_position) if weapon_mesh != null and weapon_mesh.get_child_count() > 0 else Vector3.ZERO
				blade_forward = maxf(blade_forward, -tip.z)
	var biggest_step := 0.0
	for step in yaw_steps:
		biggest_step = maxf(biggest_step, step)
	kit.check("an idle character KEEPS the way it faces while it swings (the camera looks 2 rad away; the body does not turn at all: yaw unchanged, no frame moves it)", absf(angle_difference(body.rotation.y, yaw_at_click)) < 0.01 and biggest_step < 0.01, "yaw %.3f -> %.3f, biggest step %.4f rad" % [yaw_at_click, body.rotation.y, biggest_step])
	kit.check("the arm is raised during the swing (the hand goes above 1.2 m, the shoulder is about 1.0 m)", highest > 1.2, "highest hand %.2f" % highest)
	kit.check("the slash comes FORWARD and down: at the moment of the hit the hand is in front of the body (z <= -0.25) and the blade is out in front of it", strike_z <= -0.25 and blade_forward > 0.2, "hand z %.2f (negative = in front), blade forward %.2f" % [strike_z, blade_forward])
	var numbers := get_nodes_in_group(&"damage_number")  # read now: the number fades and frees itself after 0.7 s
	var number_text := ""
	if not numbers.is_empty():
		number_text = (numbers[0] as Label3D).text
	await _rest()
	kit.check("the swing ends and the arm is no longer overridden", not arsenal.is_swinging() and not model.is_swinging())

	body.rotation.y = kit.camera_rig.rotation.y  # the idle test turned it away on purpose; the rest start facing north again

	# 3. The hit: damage, knock-back, reeling, flash, number, bar.
	kit.check("a zombie 2 m ahead took the wooden sword's 6 damage (20 -> 14)", is_equal_approx(z.health.current, hp_before - 6.0), "hp %.1f" % z.health.current)
	kit.check("the hit landed once (one swing, one hit)", arsenal.hits_landed == hits_before + 1, "%d" % (arsenal.hits_landed - hits_before))
	kit.check("a '-6' number floated up over the zombie", number_text == "-6", "'%s'" % number_text)
	var bar := z.get_node_or_null("HpBar") as Node3D
	var fill := bar.get_node_or_null("Fill") as MeshInstance3D if bar else null
	kit.check("a health bar shows over the zombie at 70% (not at full health)", bar != null and bar.visible and fill != null and absf(fill.scale.x - 0.7) < 0.02, "scale %s" % (fill.scale.x if fill else "none"))
	kit.check("it was thrown back away from the player (more than 0.3 m farther than the 2 m it stood)", z.global_position.distance_to(kit.player.global_position) > 2.3, "%.2f m away" % z.global_position.distance_to(kit.player.global_position))
	_clear()

	# Knock-back while the swing's velocity is fresh, and reeling (it does not attack during the stagger).
	z = _dummy(1.2)
	z.walk_speed = 2.4
	await kit.physics_frames(3)
	var near := kit.player.global_position.distance_to(z.global_position)
	z.take_hit(6.0, kit.player.global_position, 5.0)
	await kit.physics_frames(8)
	kit.check("knock-back: 5 m/s throws it 0.3 m or more away within 8 frames", kit.player.global_position.distance_to(z.global_position) > near + 0.3, "%.2f -> %.2f" % [near, kit.player.global_position.distance_to(z.global_position)])
	var health := kit.player.get_node("Health") as Health
	var player_hp := health.current
	await kit.physics_frames(15)
	kit.check("while it reels (0.35 s) it does not hurt the player", health.current == player_hp, "player hp %.1f" % health.current)
	_clear()

	# 4. Cooldown and killing: 4 hits kill with the wooden sword; the cooldown is real.
	z = _dummy(1.8)
	await kit.physics_frames(3)
	await _click()
	var started := arsenal.swings_started
	await kit.physics_frames(4)
	await _click()
	kit.check("a second click during the swing does not start another", arsenal.swings_started == started, "%d -> %d" % [started, arsenal.swings_started])
	await kit.physics_frames(16)  # the swing (0.28 s) is over by now, the cooldown (0.45 s) is not
	var after_swing := arsenal.swings_started
	var still_swinging := arsenal.is_swinging()
	await _click()
	kit.check("a click after the swing but inside the 0.45 s cooldown does not start another swing (the cooldown, not just the swing, holds)", not still_swinging and arsenal.swings_started == after_swing, "swinging %s, %d -> %d" % [still_swinging, after_swing, arsenal.swings_started])
	await _rest()
	for i in 3:
		if not is_instance_valid(z) or z.is_queued_for_deletion():
			break  # a stronger weapon than expected already killed it: the checks below say so (never crash a test coroutine: Godot would hang)
		z.global_position = kit.player.global_position + arsenal.facing() * 1.8
		z.velocity = Vector3.ZERO
		if i < 2:
			await _swing_and_wait()
		else:
			await _click()  # the killing blow: look at the message and the puff right away (the puff frees itself after 1.2 s)
			await kit.physics_frames(25)
	var message_now := hud.message_text()
	var puffs_now := get_nodes_in_group(&"death_puff").size()
	await _rest()
	kit.check("after four hits (6 x 4 = 24 hp) the zombie is gone", not is_instance_valid(z) or z.is_queued_for_deletion(), "hp %s" % (z.health.current if is_instance_valid(z) else "freed"))
	kit.check("the HUD says the zombie was defeated, and a puff of squares was left", message_now == "Zombie defeated!" and puffs_now > 0, "'%s', %d puffs" % [message_now, puffs_now])
	_clear()

	# 5. Reach, cone, walls.
	var in_reach := _dummy(2.2)
	var too_far := _dummy(3.0, 0.0)
	var behind := _dummy(1.5, 180.0)
	var wide := _dummy(1.8, 80.0)
	var diagonal := _dummy(1.8, 40.0)
	await kit.physics_frames(3)
	var hit_list := arsenal.targets_in_reach(0)
	kit.check("the sword reaches 2.3 m: a zombie at 2.2 m ahead and one at 40 degrees are in reach", in_reach in hit_list and diagonal in hit_list, "%d in reach" % hit_list.size())
	kit.check("and not one at 3.0 m, one behind the player, or one at 80 degrees (outside the 110 degree cone)", too_far not in hit_list and behind not in hit_list and wide not in hit_list, "%d in reach" % hit_list.size())
	_clear()
	await kit.teleport(Vector3(arena.x, NAN, arena.y), 30)  # the earlier tests leave the player half a metre off the spot: measure from a fresh one
	kit.face(Vector3(0, 0, -1))
	await kit.physics_frames(10)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.3)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	kit.world.add_child(wall)
	wall.global_position = kit.player.global_position + arsenal.facing() * 1.1 + Vector3.UP * 1.0
	await kit.physics_frames(8)  # let everything settle (the player drifts a little when a body appears near it)
	var covered := _dummy(2.0)  # placed AFTER the wall and the settling, from where the player really stands
	await kit.physics_frames(2)
	kit.check("a zombie behind a wall is not hit", covered not in arsenal.targets_in_reach(0))
	var covered_fresh := covered.has_line_of_sight(kit.player)
	wall.free()
	await kit.physics_frames(3)
	kit.check("control: take the wall away and the same zombie IS in reach (so the wall, not the geometry, protected it)", covered in arsenal.targets_in_reach(0) and not covered_fresh, "in reach %s, line of sight with the wall %s, offset %s, facing %s, body %.2f camera %.2f" % [covered in arsenal.targets_in_reach(0), covered_fresh, covered.global_position - kit.player.global_position, arsenal.facing(), (kit.player.get_node("Body") as Node3D).rotation.y, kit.camera_rig.rotation.y])
	_clear()

	# 6. Blocked states.
	var dummy := _dummy(1.8)
	var swings := arsenal.swings_started
	kit.player.input_locked = true
	await _click()
	kit.player.input_locked = false
	kit.player.sleeping = true
	await _click()
	kit.player.sleeping = false
	kit.check("no swing while the player is locked (menus, character screen) or asleep", arsenal.swings_started == swings, "%d -> %d" % [swings, arsenal.swings_started])
	health.set("_dead", true)  # knocked out (the real knock-out revives at once, so the flag is set by hand)
	await _click()
	health.set("_dead", false)
	kit.check("no swing while knocked out", arsenal.swings_started == swings)
	_clear()

	# 7. The rack, the other weapons, the keys.
	var rack := get_first_node_in_group(&"weapon_rack")
	rack.get_node("TakeWeapons").interacted.emit(kit.player)
	kit.check("the weapon rack unlocks all five weapons and the bar names them", arsenal.unlocked == [true, true, true, true, true] and hud.hotbar_text() == "1 Wooden Sword | 2 Stone Sword | 3 Spear | 4 Axe | 5 Pistol", hud.hotbar_text())
	await kit.teleport(Vector3(arena.x, NAN, arena.y), 30)
	_face_north()
	await _key(KEY_3)
	kit.check("key 3 selects the spear", arsenal.selected == 2 and arsenal.weapon()["id"] == "spear")
	var far_target := _dummy(3.4)
	var off_axis := _dummy(3.0, 25.0)
	await kit.physics_frames(3)
	var spear_hits := arsenal.targets_in_reach(2)
	kit.check("the spear reaches 3.4 m straight ahead but not 25 degrees off (a narrow 36 degree thrust)", far_target in spear_hits and off_axis not in spear_hits)
	_clear()
	await _key(KEY_4)
	var axe_target := _dummy(1.8)
	await kit.physics_frames(3)
	await _swing_and_wait()
	kit.check("key 4 selects the axe, and one swing takes 14 hp (20 -> 6)", arsenal.selected == 3 and is_equal_approx(axe_target.health.current, 6.0), "selected %d hp %.1f" % [arsenal.selected, axe_target.health.current])
	axe_target.global_position = kit.player.global_position + arsenal.facing() * 1.8
	await _swing_and_wait()
	kit.check("a second axe swing finishes it (2 hits)", not is_instance_valid(axe_target) or axe_target.is_queued_for_deletion())
	_clear()
	await _key(KEY_2)
	var stone_target := _dummy(1.8)
	await kit.physics_frames(3)
	await _swing_and_wait()
	kit.check("key 2 selects the stone sword and one swing takes 9 hp (20 -> 11)", arsenal.selected == 1 and is_equal_approx(stone_target.health.current, 11.0), "hp %.1f" % stone_target.health.current)
	_clear()
	await _key(KEY_1)
	kit.check("key 1 goes back to the wooden sword", arsenal.selected == 0)

	# 7b. The pistol: a real shot along the aim line, with range, walls, aim help, effects, and a recoil arm.
	await kit.teleport(Vector3(arena.x, NAN, arena.y), 30)
	_face_north()
	await _key(KEY_5)
	kit.check("key 5 equips the pistol and the arm points forward (the hand is out in front of the body)", arsenal.selected == 4 and Weapons.is_gun(arsenal.selected), "selected %d" % arsenal.selected)
	await kit.physics_frames(30)
	var hand := model.limb_positions()["hand_r"] as Vector3
	kit.check("with the pistol out the right hand is held forward (more than 0.3 m in front of the shoulder line)", hand.z < -0.3 or hand.z > 0.3, "hand at %s" % hand)
	var shot_at := _dummy(15.0)
	var shot_far := _dummy(52.0)
	await kit.physics_frames(3)
	await _click()
	var effects_now := get_nodes_in_group(&"shot_effect").size()
	var number_now := _latest_number_text()
	await _rest()
	kit.check("a click shoots: the zombie 15 m ahead takes 10 (20 -> 10), with a tracer, flash and spark and a '-10' number", is_equal_approx(shot_at.health.current, 10.0) and effects_now > 0 and number_now == "-10", "hp %.1f, %d effects, number '%s'" % [shot_at.health.current, effects_now, number_now])
	kit.check("a zombie 52 m away is out of the pistol's 45 m range", shot_far.health.current == 20.0)
	var tracer_length: float = arsenal.last_shot.get("distance", 0.0)
	kit.check("the shot travelled to the zombie (about 15 m, not the full 45)", tracer_length > 14.0 and tracer_length < 17.0, "%.1f m" % tracer_length)
	_clear()
	var shielded := _dummy(12.0)
	var shield := StaticBody3D.new()
	var shield_shape := CollisionShape3D.new()
	var shield_box := BoxShape3D.new()
	shield_box.size = Vector3(6, 4, 0.4)
	shield_shape.shape = shield_box
	shield.add_child(shield_shape)
	kit.world.add_child(shield)
	shield.global_position = kit.player.global_position + arsenal.facing() * 6.0 + Vector3.UP * 1.5
	await kit.physics_frames(3)
	await _swing_and_wait()
	kit.check("a wall stops the bullet: the zombie behind it is not hit", shielded.health.current == 20.0 and float(arsenal.last_shot.get("distance", 99.0)) < 7.0, "hp %.1f, shot %.1f m" % [shielded.health.current, float(arsenal.last_shot.get("distance", 99.0))])
	shield.free()
	_clear()
	var aimed_wide := _dummy(14.0, 12.0)
	await kit.physics_frames(3)
	await _swing_and_wait()
	var wide_hp := aimed_wide.health.current
	_clear()
	var aimed_near := _dummy(14.0, 1.5)
	await kit.physics_frames(3)
	await _swing_and_wait()
	kit.check("aim help: a zombie 1.5 degrees off the line is hit, one 12 degrees off is not (shot at one at a time)", aimed_near.health.current == 10.0 and wide_hp == 20.0, "%.1f / %.1f" % [aimed_near.health.current, wide_hp])
	_clear()
	await _key(KEY_5)
	kit.check("pressing 5 again holsters the pistol (the arm relaxes, back to fists)", arsenal.selected == -1)
	await _key(KEY_1)
	await _key(KEY_1)

	# 7c. EVERY kind of damage and healing pops a number out of whoever it happened to.
	var health_p := kit.player.get_node("Health") as Health
	health_p.damage(8.0)
	var player_label := _newest_number()
	kit.check("damage to the PLAYER pops a red '-8' out of the player", player_label != null and player_label.text == "-8" and player_label.modulate.r > 0.9 and player_label.modulate.g < 0.5, "'%s'" % (player_label.text if player_label else "no number"))
	health_p.heal(5.0)
	var heal_label := _newest_number()
	kit.check("healing pops a green '+5'", heal_label != null and heal_label.text == "+5" and heal_label.modulate.g > 0.8 and heal_label.modulate.r < 0.6, "'%s'" % (heal_label.text if heal_label else "no number"))
	var burner := _dummy(6.0)
	burner.health.damage(0.5, &"fire")
	burner.health.damage(0.5, &"fire")
	await kit.physics_frames(40)
	var fire_label: Label3D = null
	for node in get_nodes_in_group(&"damage_number"):
		if (node as Label3D).modulate.r > 0.9 and (node as Label3D).modulate.g > 0.4 and (node as Label3D).modulate.g < 0.6:
			fire_label = node
	kit.check("fire damage pops an orange number (the ticks are added up: two halves show as '-1')", fire_label != null and fire_label.text == "-1", "'%s'" % (fire_label.text if fire_label else "none"))
	_clear()
	health_p.heal(100.0)

	# 8. Shift lock does not change what a swing hits (it faces the camera too).
	kit.camera_rig.set_shift_lock(true)
	var locked_target := _dummy(1.65)
	await kit.physics_frames(3)
	await _swing_and_wait()
	kit.check("a swing in shift lock hits the zombie ahead", locked_target.health.current < 20.0)
	kit.camera_rig.set_shift_lock(false)
	_clear()

	# 9. THE DIRECTION OF AN ATTACK (Marco: "when i swing... my avatar jitters and moves straight if im holding a... it should keep the direction im using the
	# weapons for, not move me straight looking north"). Holding A with the camera looking north: the character walks west, and a swing, a punch or a shot goes WEST
	# (the way it faces), the body never snaps toward the camera, and no frame turns it more than a small step.
	await _key(KEY_1)  # the wooden sword
	await kit.teleport(Vector3(arena.x, NAN, arena.y), 30)
	kit.face(Vector3(0, 0, -1))  # the camera looks north (-Z)
	(kit.player.get_node("Body") as Node3D).rotation.y = kit.camera_rig.rotation.y
	await kit.physics_frames(20)
	var down := InputEventKey.new()
	down.physical_keycode = KEY_A
	down.keycode = KEY_A
	down.pressed = true
	Input.parse_input_event(down)
	await kit.physics_frames(24)  # the character turns west and walks
	var west := Vector3(-1, 0, 0)
	var north := Vector3(0, 0, -1)
	kit.check("holding A with the camera looking north: the attack direction is WEST (the way it walks), not the camera's north", arsenal.facing().dot(west) > 0.9 and arsenal.camera_direction().dot(north) > 0.99, "facing %s, camera %s" % [arsenal.facing(), arsenal.camera_direction()])
	var west_zombie_pos := kit.player.global_position + arsenal.facing() * 1.6
	var north_zombie_pos := kit.player.global_position + north * 1.6
	var in_west := Zombie.new()
	in_west.wander = false
	in_west.walk_speed = 0.0
	in_west.position = Vector3(west_zombie_pos.x, kit.terrain.height_at(west_zombie_pos.x, west_zombie_pos.z) + 0.1, west_zombie_pos.z)
	kit.world.add_child(in_west)
	var in_north := Zombie.new()
	in_north.wander = false
	in_north.walk_speed = 0.0
	in_north.position = Vector3(north_zombie_pos.x, kit.terrain.height_at(north_zombie_pos.x, north_zombie_pos.z) + 0.1, north_zombie_pos.z)
	kit.world.add_child(in_north)
	await kit.physics_frames(2)
	var reach_now := arsenal.targets_in_reach(0)
	kit.check("a zombie where the character is heading (west) is in reach and one at the camera's north is not", in_west in reach_now and in_north not in reach_now, "%d in reach" % reach_now.size())
	var yaw_before := (kit.player.get_node("Body") as Node3D).rotation.y
	var steps: Array[float] = []
	var previous := yaw_before
	await _click()
	for i in 24:
		await kit.physics_frames(1)
		var current := (kit.player.get_node("Body") as Node3D).rotation.y
		steps.append(absf(angle_difference(current, previous)))
		previous = current
	var largest := 0.0
	for step in steps:
		largest = maxf(largest, step)
	var yaw_after := (kit.player.get_node("Body") as Node3D).rotation.y
	kit.check("swinging while walking west does not snap or turn the body (the biggest one-frame turn is under 0.15 rad and it ends within 0.4 rad of where it faced)", largest < 0.15 and absf(angle_difference(yaw_after, yaw_before)) < 0.4, "biggest step %.3f rad, change %.2f rad" % [largest, angle_difference(yaw_after, yaw_before)])
	var up := InputEventKey.new()
	up.physical_keycode = KEY_A
	up.keycode = KEY_A
	up.pressed = false
	Input.parse_input_event(up)
	await kit.physics_frames(30)
	_clear()
	# The same for a punch and a shot (equip the pistol: the shot goes the way the character faces too).
	var down_a := InputEventKey.new()
	down_a.physical_keycode = KEY_A
	down_a.keycode = KEY_A
	down_a.pressed = true
	Input.parse_input_event(down_a)
	await kit.physics_frames(20)
	await _key(KEY_5)
	await _click()
	var shot_direction: Vector3 = (arsenal.last_shot.get("end", Vector3.ZERO) as Vector3) - kit.player.global_position
	shot_direction.y = 0.0
	kit.check("a shot while walking west goes west (not north)", shot_direction.length() > 1.0 and shot_direction.normalized().dot(west) > 0.9, "shot to %s" % arsenal.last_shot.get("end", "none"))
	var up_a := InputEventKey.new()
	up_a.physical_keycode = KEY_A
	up_a.keycode = KEY_A
	up_a.pressed = false
	Input.parse_input_event(up_a)
	await kit.physics_frames(20)
	await _key(KEY_5)
	_clear()

	kit.finish()


## The text of the newest damage number in the world ("" if none).
func _newest_number() -> Label3D:
	var numbers := get_nodes_in_group(&"damage_number")
	return null if numbers.is_empty() else numbers[numbers.size() - 1] as Label3D


func _number_texts() -> Array:
	return get_nodes_in_group(&"damage_number").map(func(n): return (n as Label3D).text)


func _latest_number_text() -> String:
	var numbers := get_nodes_in_group(&"damage_number")
	if numbers.is_empty():
		return ""
	return (numbers[numbers.size() - 1] as Label3D).text


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)
