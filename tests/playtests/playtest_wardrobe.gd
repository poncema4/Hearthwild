extends SceneTree
## Playtest: the animals and the wardrobe on display (topic `wardrobe`), for visual review: all 9 animals, the 7 hats, the faces and necks, the
## tops and dresses, the backs (seen from behind) and five complete looks. Animals stand in a row on the meadow facing a camera of our own, so
## nothing but the models is in the picture. Each shot also checks every model is on the screen and not blank.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_wardrobe.gd -- <qa_output> <run stamp>

var kit: PlaytestKit
var _camera: Camera3D
var _models: Array[AnimalModel] = []


func _initialize() -> void:
	_run.call_deferred()


## Puts one animal per entry in a row at z = 0, facing the camera (+z), each wearing its list of item ids.
func _row(species_ids: Array, looks: Array, spacing: float) -> void:
	for m in _models:
		m.queue_free()
	_models.clear()
	var count := species_ids.size()
	for i in count:
		var model := AnimalModel.new()
		kit.world.add_child(model)
		var x := (float(i) - float(count - 1) * 0.5) * spacing
		model.position = Vector3(x, kit.terrain.height_at(x, 0.0), 0.0)
		model.rotation.y = PI  # models face -z; the camera is at +z
		model.set_species(AnimalSpecies.by_id(species_ids[i]))
		for item in looks[i]:
			model.equip_item(item)
		_models.append(model)


func _aim(distance: float, height: float, look_height: float) -> void:
	_camera.global_position = Vector3(0.0, height, distance)
	_camera.look_at(Vector3(0.0, look_height, 0.0), Vector3.UP)


## True when the model's head top and feet both land inside the picture (40 px margin) and the box around it is not blank.
func _model_ok(model: AnimalModel, image: Image) -> String:
	var view := kit.player.get_viewport().get_visible_rect().size
	var scale := Vector2(image.get_width() / view.x, image.get_height() / view.y)
	if model.is_blinking():
		return "mid-blink (the eyes are shut in this picture)"
	var feet: Vector3 = model.global_position
	var top: Vector3 = model.global_position + Vector3.UP * 2.0
	if _camera.is_position_behind(feet) or _camera.is_position_behind(top):
		return "behind the camera"
	var a: Vector2 = _camera.unproject_position(feet) * scale
	var b: Vector2 = _camera.unproject_position(top) * scale
	for p in [a, b]:
		if p.x < 40.0 or p.y < 40.0 or p.x > image.get_width() - 40.0 or p.y > image.get_height() - 40.0:
			return "off screen at %s" % p
	var low := 1.0
	var high := 0.0
	for k in 12:
		var p := a.lerp(b, float(k) / 11.0)
		var lum := image.get_pixelv(Vector2i(p)).get_luminance()
		low = minf(low, lum)
		high = maxf(high, lum)
	return "" if high - low > 0.04 else "blank (luminance range %.3f)" % (high - low)


func _shot(name: String, what: String, expect: String) -> void:
	await kit.physics_frames(25)  # a fresh model blinks for its first 0.12 s (lesson 64: a blink ruined the first screenshots); 25 frames is 0.4 s
	await kit.frames(4)
	var image := await kit.shot("wardrobe", name, what, expect)
	kit.check_rendered("wardrobe/" + name, image)
	var problems := []
	for i in _models.size():
		var why := _model_ok(_models[i], image)
		if why != "":
			problems.append("%s: %s" % [_models[i].species.id, why])
	kit.check("%s: all %d models are on the screen and not blank" % [name, _models.size()], problems.is_empty(), str(problems))


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	kit.day_night.set_time(10.0)
	await kit.teleport(Vector3(80.0, NAN, 80.0), 20)  # the player stands far away; this playtest uses a camera of its own
	_camera = Camera3D.new()
	kit.world.add_child(_camera)
	_camera.current = true
	var animals := [&"dog", &"cat", &"bunny", &"fox", &"bear", &"panda", &"pig", &"mouse", &"raccoon"]
	var none: Array = []

	_row(animals, [none, none, none, none, none, none, none, none, none], 1.5)
	_aim(6.2, 1.5, 0.9)
	await _shot("animals", "All nine animals in a row, nothing worn: dog, cat, bunny, fox, bear, panda, pig, mouse, raccoon (left to right), facing the camera.",
			"Nine different cute animals: golden dog with floppy ears; grey cat with pointy ears; white bunny with tall pink-inside ears; orange fox with a white belly and a long tail; brown bear with round ears; white panda with black ears and eye patch; pink pig with a pink snout; grey mouse with big round pink-inside ears; grey raccoon with a dark mask. Every one clearly different, upright, feet on the grass, nothing overlapping.")

	var hat_species := [&"dog", &"cat", &"bunny", &"fox", &"bear", &"panda", &"pig"]
	_row(hat_species, [[&"red_cap"], [&"straw_hat"], [&"flower_crown"], [&"wizard_hat"], [&"party_hat"], [&"gold_crown"], [&"orange_beanie"]], 1.55)
	_aim(5.6, 1.7, 1.45)
	await _shot("hats", "Seven animals each in a different hat: red cap, straw hat, flower crown, wizard hat, party hat, gold crown, orange beanie.",
			"Each hat sits ON the head (not floating, not sunk in, not tilted off): the red cap with a brim, wide straw hat, ring of coloured flowers, tall purple pointed hat with a gold band and star, pink cone hat with a blue pompom, gold crown with spikes and a red gem, orange knitted beanie with a white pompom. Ears stay visible beside or through the hat where they should.")

	var face_species := [&"dog", &"cat", &"fox", &"bear", &"panda", &"pig", &"mouse", &"raccoon", &"bunny"]
	_row(face_species, [[&"round_glasses", &"blue_scarf"], [&"sunglasses", &"bow_tie"], [&"heart_glasses", &"flower_lei"], [&"curly_moustache", &"gold_necklace"], [&"sunglasses", &"red_bandana"], [&"heart_glasses", &"blue_scarf"], [&"round_glasses", &"gold_necklace"], [&"curly_moustache", &"red_bandana"], [&"sunglasses", &"flower_lei"]], 1.5)
	_aim(5.0, 1.45, 1.15)
	await _shot("faces_and_necks", "Nine animals in glasses or a moustache and a neck item: round glasses + blue scarf, sunglasses + bow tie, heart glasses + flower lei, moustache + gold necklace, sunglasses + red bandana, heart glasses + scarf, round glasses + necklace, moustache + bandana, sunglasses + lei.",
			"Glasses sit in front of the eyes (dark sunglasses, pink hearts, round frames), the curly moustache is under the nose, and each neck item wraps the neck between head and body (scarf, bow tie, ring of flowers, gold chain with a blue pendant, red bandana with a triangle). Nothing floats away from the face or neck.")

	var top_species := [&"dog", &"cat", &"fox", &"panda", &"pig"]
	_row(top_species, [[&"mint_sweater"], [&"sunny_dress"], [&"denim_overalls"], [&"red_hoodie"], [&"striped_tee"]], 1.8)
	_aim(5.2, 1.3, 0.85)
	await _shot("tops_and_dress", "Five animals in tops: mint sweater, sunny dress, denim overalls, red hoodie, striped tee.",
			"Each covers the torso (not the head or legs): a mint sweater with a cream stripe; a yellow dress with a flared skirt, white hem, orange belt and white collar, legs visible below; blue denim overalls with straps, bib and buttons; a red hoodie with a hood at the back, pocket and white cords; a white tee with navy stripes. No colour bleeding onto the arms, no body poking through.")

	var back_species := [&"dog", &"cat", &"bunny", &"fox"]
	_row(back_species, [[&"explorer_pack"], [&"angel_wings"], [&"red_cape"], [&"butterfly_wings"]], 2.2)
	_aim(5.2, 1.4, 0.95)
	for m in _models:
		m.rotation.y = 0.0  # seen from behind: the camera stays at +z, the models now face -z, away from it
	await _shot("backs", "Four animals seen from BEHIND: explorer pack, angel wings, red cape, butterfly wings.",
			"From behind: a brown backpack with a bedroll; two white feathered wings spreading from the back; a red cape hanging from the shoulders with a gold lining at the edge; pink and blue butterfly wings with white spots. Each attached at the back, not floating, symmetric left and right.")

	var look_species := [&"fox", &"bear", &"panda", &"pig", &"cat"]
	_row(look_species, [[&"flower_crown", &"sunny_dress", &"flower_lei", &"heart_glasses"], [&"wizard_hat", &"red_cape", &"gold_necklace", &"round_glasses"], [&"orange_beanie", &"red_hoodie", &"sunglasses"], [&"party_hat", &"denim_overalls", &"red_bandana", &"curly_moustache"], [&"gold_crown", &"striped_tee", &"bow_tie", &"angel_wings"]], 1.9)
	_aim(5.4, 1.5, 1.0)
	await _shot("full_looks", "Five complete looks: fox in flower crown + sunny dress + lei + heart glasses; bear as a wizard with cape + necklace + round glasses; panda in beanie + hoodie + sunglasses; pig in party hat + overalls + bandana + moustache; cat in crown + striped tee + bow tie + angel wings.",
			"Each animal reads as one cohesive costume, all pieces on their right place and layered without clipping into each other (hat over ears, glasses over eyes, neck item over the top, cape or wings behind). Colours distinct, characters cute and readable.")

	for m in _models:
		m.queue_free()
	_camera.queue_free()
	print("SCREENSHOTS: %s/wardrobe/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
