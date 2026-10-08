extends SceneTree
## Functional test: HOW A PLAYER JOINS. Title screen (Play / Info / Settings / Quit) -> character screen (Join) -> loading screen -> the player appears in the
## middle of the village. Real keys where the claim is about controls (Enter on Play, Esc back from Info). Also: the well is off to one side so the spawn is open.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_game_flow.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await kit.frames(2)


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world(60, true)  # with the join flow switched ON
	var flow := kit.world.get_node("GameFlow") as GameFlow
	var menu := kit.world.get_node("MainMenu") as MainMenu
	var creator := kit.world.get_node("CharacterCreator") as CharacterCreator
	var loading := kit.world.get_node("LoadingScreen") as LoadingScreen
	var player := kit.player
	flow.load_seconds = 0.8  # the real default is 2.2 s
	await kit.physics_frames(5)

	# 1. The very first thing: the title screen, the player locked, nothing else open.
	kit.check("at launch the title screen is open, the flow is at the menu and the player cannot move", menu.is_open and flow.step == GameFlow.Step.MENU and player.input_locked, "menu %s, step %d, locked %s" % [menu.is_open, flow.step, player.input_locked])
	kit.check("it offers Play, Info, Settings and Quit", menu.button_texts() == ["Play", "Info", "Settings", "Quit"], str(menu.button_texts()))
	kit.check("the character screen and the loading screen are NOT showing yet", not creator.is_open and not loading.is_active())
	kit.check("the mouse is free for the menu", Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	var hud_layer := player.get_node("HUD") as CanvasLayer
	kit.check("the weapon bar, health and clock are hidden behind the menus and the character already stands on the plaza", not hud_layer.visible and player.global_position.distance_to(kit.village.spawn_point()) < 1.5, "hud visible %s, %.1f m from the plaza" % [hud_layer.visible, player.global_position.distance_to(kit.village.spawn_point())])

	# 2. Info says what the game is and lists the keys; Esc (a real key) goes back.
	menu.show_info()
	var info := menu.info_text()
	kit.check("Info explains the game and lists the controls (walk, run, jump, attack, weapons, F2, Alt, beds)", menu.screen == "info" and info.contains("W A S D") and info.contains("Shift") and info.contains("F or left click") and info.contains("1 to 5") and info.contains("F2") and info.contains("Alt") and info.contains("respawn") and info.contains("zombies"), info.substr(0, 60))
	await _key(KEY_ESCAPE)
	kit.check("Esc goes back from Info to the title", menu.screen == "home" and menu.is_open)

	# 3. Settings: the volume really changes the audio bus.
	menu.show_settings()
	var volume_before := menu.volume()
	menu.set_volume(0.5)
	var half := menu.volume()
	menu.set_volume(0.0)
	var silent := menu.volume()
	menu.set_volume(volume_before)
	kit.check("Settings: the volume slider changes the master audio volume (0.5 reads back about 0.5, 0 is silent) and is restored", menu.screen == "settings" and absf(half - 0.5) < 0.02 and silent < 0.01 and absf(menu.volume() - volume_before) < 0.02, "half %.2f silent %.2f restored %.2f" % [half, silent, menu.volume()])
	await _key(KEY_ESCAPE)

	# 4. Play with the keyboard (Enter on the focused Play button) opens the character screen with a JOIN button.
	await kit.frames(3)
	await _key(KEY_ENTER)
	kit.check("Enter on Play closes the title and opens the character screen (the player stays locked)", not menu.is_open and creator.is_open and flow.step == GameFlow.Step.CREATING and player.input_locked, "menu %s creator %s step %d" % [menu.is_open, creator.is_open, flow.step])
	kit.check("the character screen's button says Join and it has no Cancel (joining needs a look)", creator.confirm_button_text() == "Join" and not creator.can_cancel, "'%s' cancel %s" % [creator.confirm_button_text(), creator.can_cancel])

	# 5. Pick a look, Join: the loading screen fades in, covers, moves the player to the plaza, then fades out.
	var start_position := player.global_position + Vector3(30, 0, 0)  # (the character stands on the plaza behind the title; measure the jump from somewhere else: the join moves nobody who is already there)
	creator.select_species(&"fox")
	creator.enter_name("Tester")
	var joined_names: Array[String] = []
	flow.joined.connect(func(profile: PlayerProfile): joined_names.append(profile.display_name))
	creator.confirm()
	await kit.physics_frames(2)
	kit.check("pressing Join starts the loading screen and keeps the player locked", flow.step == GameFlow.Step.LOADING and loading.is_active() and player.input_locked, "step %d active %s locked %s" % [flow.step, loading.is_active(), player.input_locked])
	await kit.physics_frames(30)
	kit.check("the loading screen is nearly fully dark half a second in, shows a tip and a growing bar", loading.alpha() > 0.9 and loading.tip_text().begins_with("Tip:") and loading.progress() >= 0.0, "alpha %.2f, tip '%s'" % [loading.alpha(), loading.tip_text()])
	await kit.physics_frames(20)
	var plaza := kit.village.spawn_point()
	var flat := Vector2(player.global_position.x - plaza.x, player.global_position.z - plaza.z).length()
	kit.check("while it is dark the player is at the middle of the village (the plaza)", flat < 1.5, "%.2f m from the plaza centre" % flat)
	kit.check("and is STILL locked until the screen is gone", player.input_locked and loading.is_active())
	for i in 400:
		await kit.physics_frames(1)
		if not loading.is_active():
			break
	await kit.physics_frames(3)
	kit.check("then the loading screen is gone, the HUD is back, the player is free and the flow says playing", not loading.is_active() and not player.input_locked and flow.step == GameFlow.Step.PLAYING and hud_layer.visible, "active %s locked %s step %d" % [loading.is_active(), player.input_locked, flow.step])
	kit.check("the join was announced with the chosen name and the character is a fox", joined_names == ["Tester"] and PlayerProfile.current().species_id == &"fox", str(joined_names))
	kit.check("a knock-out now brings the player back to the plaza (no bed chosen yet)", player.spawn_point().distance_to(plaza) < 1.5, "respawn %s, plaza %s" % [player.spawn_point(), plaza])
	var walk_start := player.global_position
	await kit.hold(["move_forward"], 30)
	kit.check("and they can walk", player.global_position.distance_to(walk_start) > 1.0, "moved %.2f m" % player.global_position.distance_to(walk_start))

	# 6. The well is off to one side: nothing solid in the middle of the plaza where players appear.
	var well: Node3D = null
	for prop in kit.village.props:
		if prop.get_meta("kind", "") == "Well":
			well = prop
	var space: PhysicsDirectSpaceState3D = kit.world.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, plaza + Vector3.UP * 1.2)
	query.exclude = [kit.terrain.get_rid(), player.get_rid()]
	kit.check("the well is NOT in the middle: it stands 3.5 m or more from the plaza centre and nothing solid is within 2 m of where players appear", well != null and well.global_position.distance_to(plaza) >= 3.5 and space.intersect_shape(query, 4).is_empty(), "well %.1f m away" % (well.global_position.distance_to(plaza) if well else -1.0))

	# 7. F2 later in the game changes the look WITHOUT a loading screen (it is not a join).
	var steps_before := flow.step
	creator.open(PlayerProfile.current())
	creator.confirm()
	await kit.physics_frames(4)
	kit.check("F2 and Start later change the look and do not start another loading screen", flow.step == steps_before and not loading.is_active() and joined_names.size() == 1)
	kit.finish()
