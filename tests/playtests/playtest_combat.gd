extends SceneTree
## Playtest: combat on screen (topic `combat`), for visual review: the weapon bar with nothing in hand, a sword swing landing with its damage number, a pistol
## shot with its tracer, and damage numbers of every kind at once (yellow on a zombie, red on the player, orange fire, green healing).
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_combat.gd -- <qa_output> <run stamp>

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _click() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = Vector2(400, 300)
		Input.parse_input_event(event)
		await kit.frames(1)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await kit.frames(1)


func _dummy(distance: float) -> Zombie:
	var yaw := kit.camera_rig.rotation.y
	var spot := kit.player.global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)) * distance
	var zombie := Zombie.new()
	zombie.wander = false
	zombie.walk_speed = 0.0
	zombie.position = Vector3(spot.x, kit.terrain.height_at(spot.x, spot.z) + 0.1, spot.z)
	kit.world.add_child(zombie)
	return zombie


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var arsenal := kit.player.get_node("Arsenal") as Arsenal
	var hud := kit.player.get_node("HUD") as InteractionPrompt
	var health := kit.player.get_node("Health") as Health
	kit.day_night.set_time(21.5)
	var arena := kit.find_open_arena(40.0)
	await kit.teleport(Vector3(arena.x, NAN, arena.y), 30)
	kit.face(Vector3(0, 0, -1))
	(kit.camera_rig.get_node("Pitch") as Node3D).rotation.x = deg_to_rad(-14.0)
	await kit.frames(30)

	var image := await kit.shot("combat", "bar_fists", "Night, nothing in hand: the weapon bar along the bottom with five slots (only the Wooden Sword unlocked, the rest locked) and the hint 'Fists ready'.",
			"Along the bottom a row of five square slots numbered 1 to 5 with small coloured icons; slot 1 says Wooden Sword, 2 to 5 say locked and are dim; no slot is gold-highlighted; a line above reads 'Fists ready: F or left click to punch'.")
	kit.check_rendered("combat/bar_fists", image)
	var slot_sizes := hud.hotbar_slot_sizes()
	var same_size := slot_sizes.size() == 5
	for slot_size in slot_sizes:
		same_size = same_size and absf(slot_size.x - slot_sizes[0].x) < 1.0 and absf(slot_size.y - slot_sizes[0].y) < 1.0
	kit.check("all five weapon slots are exactly the same size on screen (the Wooden Sword slot used to be bigger than the locked ones)", same_size and slot_sizes[0].x > 60.0, str(slot_sizes))

	arsenal.unlock_all()
	await _key(KEY_1)
	var zombie := _dummy(1.9)
	await kit.frames(10)
	await _click()
	await kit.physics_frames(9)
	image = await kit.shot("combat", "sword_hit", "The wooden sword swings: the arm is mid-slash with the blade, the zombie 1.9 m ahead has just been hit (red flash, a '-6' number floating over it, a small health bar).",
			"The dog with a wooden sword raised or sweeping across; the zombie in front with a yellow '-6' above its head and a short red-and-dark health bar; the hotbar shows slot 1 gold-highlighted with 'Wooden Sword' in the hint line.")
	kit.check_rendered("combat/sword_hit", image)
	await kit.physics_frames(60)
	zombie.free()

	await _key(KEY_5)
	var far_zombie := _dummy(11.0)
	await kit.frames(10)
	await _click()
	await kit.physics_frames(2)
	image = await kit.shot("combat", "pistol_shot", "The pistol fires at a zombie 11 m ahead: the right arm points forward holding the gun, a bright tracer runs from the muzzle to the zombie, a flash at the muzzle and a spark where it hit.",
			"The dog from behind with the arm stretched forward holding a small dark pistol; a thin yellow-white line from the gun to the distant zombie, a bright ball at the muzzle and an orange spark on the zombie; slot 5 gold-highlighted.")
	kit.check_rendered("combat/pistol_shot", image)
	await kit.physics_frames(40)
	far_zombie.free()

	var target := _dummy(2.4)
	await kit.frames(10)
	target.health.damage(7.0)
	health.damage(8.0)
	target.health.damage(1.0, &"fire")
	target.health.damage(1.0, &"fire")
	health.damage(5.0)
	health.heal(9.0)
	await kit.physics_frames(14)
	image = await kit.shot("combat", "damage_numbers", "Every kind of number at once: a yellow '-7' over the zombie, an orange '-2' (fire) over it, a red '-8' and '-5' over the player, a green '+9' over the player.",
			"Floating numbers over both characters in different colours: yellow over the zombie, orange fire number over the zombie, red numbers over the dog, a green plus number over the dog; they are readable against the night meadow.")
	kit.check_rendered("combat/damage_numbers", image)
	print("SCREENSHOTS: %s/combat/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
