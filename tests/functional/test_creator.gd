extends SceneTree
## Functional test: the character screen and the start-of-game flow.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_creator.gd
## Exit code = number of failures (0 = all pass).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var player := kit.player
	var model: AnimalModel = player.get_node("Body/Model")
	var creator := kit.creator
	var hud: InteractionPrompt = player.get_node("HUD")

	# 1. A first launch (no saved profile): the screen opens, the player is frozen, the mouse is free.
	creator.enabled = true
	creator._begin()
	await kit.physics_frames(3)
	kit.check("with no saved profile the character screen opens", creator.is_open and creator._root.visible)
	kit.check("while it is open the player is locked and the mouse is free", player.input_locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
			"locked=%s mouse=%s" % [player.input_locked, Input.mouse_mode])
	Input.action_press("move_forward")
	var before := player.global_position
	await kit.physics_frames(60)
	Input.action_release("move_forward")
	kit.check("the locked player does not walk when W is held", player.global_position.distance_to(before) < 0.1, "moved %.2f m" % player.global_position.distance_to(before))
	kit.check("it starts on the default profile: the dog, a usable name, nothing worn", creator.profile.species_id == &"dog" and creator.profile.display_name != "" and creator.profile.outfit.is_empty(),
			str(creator.profile.to_dict()))
	kit.check("the live preview shows the dog", creator.preview_model.species.id == &"dog")

	# 2. Choosing an animal: next/previous wrap around and the preview follows.
	creator.next_species(1)
	var after_next := creator.profile.species_id
	creator.next_species(1)
	var after_two := creator.profile.species_id
	var visited := [creator.profile.species_id]
	for i in 7:
		creator.next_species(1)
		visited.append(creator.profile.species_id)
	kit.check("next animal visits all 9 in order (dog, cat, bunny, fox, bear, panda, pig, mouse, raccoon) and wraps back to the dog",
			after_next == &"cat" and after_two == &"bunny" and visited == [&"bunny", &"fox", &"bear", &"panda", &"pig", &"mouse", &"raccoon", &"dog"] and creator.profile.species_id == &"dog",
			"%s, %s, %s, visited %s" % [after_next, after_two, creator.profile.species_id, visited])
	creator.next_species(-1)
	kit.check("previous animal wraps backwards (dog -> raccoon) and the preview and label follow", creator.profile.species_id == &"raccoon" and creator.preview_model.species.id == &"raccoon" and creator._species_label.text == "Raccoon",
			"%s / preview %s / label %s" % [creator.profile.species_id, creator.preview_model.species.id, creator._species_label.text])
	creator.select_species(&"bunny")  # the rest of this test carries on with the bunny

	# 3. Choosing clothes: each slot cycles none -> items -> none, and the preview wears them.
	var hats := Outfits.items_for_slot(&"head_top")
	var seen := []
	for i in hats.size() + 1:
		creator.next_item(&"head_top", 1)
		seen.append(creator._item_labels[&"head_top"].text)
	var expected_seen: Array = []
	for hat in hats:
		expected_seen.append(Outfits.label_of(hat))
	expected_seen.append("None")
	kit.check("a slot cycles through every hat in catalog order and back to None (7 hats + None)", seen == expected_seen and hats.size() >= 7, str(seen))
	var last_neck: StringName = Outfits.items_for_slot(&"neck").back()
	creator.next_item(&"head_top", 1)
	creator.next_item(&"neck", -1)  # backwards from None lands on the LAST neck item
	creator.next_item(&"back", 1)
	await kit.physics_frames(2)
	kit.check("the preview wears the chosen items", creator.preview_model.worn_items() == {&"head_top": &"red_cap", &"neck": last_neck, &"back": &"explorer_pack"}, str(creator.preview_model.worn_items()))

	# 4. The name.
	creator.enter_name("  Marco\u0001 the Great and Mighty  ")
	kit.check("the name box allows at most 16 characters", creator._name_edit.max_length == 16)

	# 5. Start: saved, applied to the real player (animal, outfit, name tag), player unlocked.
	var finished := [null]
	creator.finished.connect(func(p): finished[0] = p)
	var saved := creator.confirm()
	await kit.physics_frames(3)
	kit.check("Start closes the screen and unlocks the player", not creator.is_open and not creator._root.visible and not player.input_locked,
			"open=%s visible=%s locked=%s" % [creator.is_open, creator._root.visible, player.input_locked])
	kit.note("mouse mode after Start", "%d (a headless display cannot capture the mouse, so this is only checked on a real window in the creator playtest)" % Input.mouse_mode)
	kit.check("Start emits `finished` with the profile", finished[0] == saved)
	# The box keeps the first 16 typed characters ("  Marco" + control + " the Gre"), then the name is cleaned.
	kit.check("the profile name is exactly the cleaned first 16 characters typed", saved.display_name == "Marco the Gre", "'%s'" % saved.display_name)
	kit.check("the real player is now the bunny wearing the chosen items", model.species.id == &"bunny" and model.worn_items() == {&"head_top": &"red_cap", &"neck": last_neck, &"back": &"explorer_pack"},
			"%s %s" % [model.species.id, model.worn_items()])
	var tag := model.find_child("NameTag", true, false) as Label3D
	kit.check("the player's name floats over their head", tag != null and tag.text == saved.display_name and tag.visible, "tag '%s'" % (tag.text if tag else "none"))
	kit.check("a welcome message tells the player about F2", hud.message_text().contains("F2"), "'%s'" % hud.message_text())
	kit.check("the profile was saved to disk", FileAccess.file_exists(PlayerProfile.save_path))
	Input.action_press("move_forward")
	await kit.physics_frames(30)
	Input.action_release("move_forward")
	kit.check("after Start the player can walk again", player.global_position.distance_to(before) > 1.0, "moved %.2f m" % player.global_position.distance_to(before))

	# 6. Next launch: the saved profile is applied silently (no screen), and F2 reopens it.
	var second: Node = load("res://scenes/world/world.tscn").instantiate()
	kit.world.add_child(second)
	await kit.physics_frames(4)
	var second_creator := second.get_node("CharacterCreator") as CharacterCreator
	var second_model := second.get_node("Player/Body/Model") as AnimalModel
	kit.check("a saved profile is applied at the next start with no screen", not second_creator.is_open and second_model.species != null and second_model.species.id == &"bunny" and second_model.display_name == saved.display_name,
			"open=%s species=%s name='%s'" % [second_creator.is_open, second_model.species.id if second_model.species else "none", second_model.display_name])
	second.queue_free()
	await kit.physics_frames(2)
	creator.enabled = true
	await kit.tap("customize")
	kit.check("F2 reopens the character screen with the current look", creator.is_open and creator.profile.species_id == &"bunny" and creator._choice[&"head_top"] >= 0,
			"open=%s species=%s" % [creator.is_open, creator.profile.species_id])
	# Cancel: only on a reopened screen; it changes nothing; the first launch has no Cancel.
	creator.next_species(-1)
	creator.next_item(&"back", 1)
	kit.check("the reopened screen offers Cancel", creator.can_cancel and creator._cancel_button.visible)
	var cancelled := creator.cancel()
	await kit.physics_frames(2)
	kit.check("Cancel closes the screen, unlocks the player and changes nothing", cancelled and not creator.is_open and not player.input_locked and model.species.id == &"bunny"
			and model.worn_items() == {&"head_top": &"red_cap", &"neck": last_neck, &"back": &"explorer_pack"} and PlayerProfile.current().species_id == &"bunny",
			"%s %s" % [model.species.id, model.worn_items()])
	creator.open(PlayerProfile.make_default(), false)
	kit.check("a first launch (no Cancel) cannot be cancelled: the button is hidden and cancel() does nothing", not creator._cancel_button.visible and not creator.cancel() and creator.is_open)
	creator.confirm()
	if FileAccess.file_exists(PlayerProfile.save_path):
		DirAccess.remove_absolute(PlayerProfile.save_path)
	kit.finish()
