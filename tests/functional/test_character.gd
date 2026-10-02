extends SceneTree
## Functional test: the player character (the cute dog) is built, sized to fit
## the player, grounded, animated by what the player does, species-driven, and
## can wear outfits that fade with the body.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_character.gd
## Exit code = number of failures (0 = all pass).

const PARTS: Array[String] = ["Rig", "Torso", "Belly", "Head", "Skull", "Snout", "Nose", "Mouth", "EyeL", "EyeR", "CheekL", "CheekR",
		"EarL", "EarR", "Tail", "ArmL", "ArmR", "LegL", "LegR"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var model: AnimalModel = kit.player.get_node("Body/Model")
	var capsule: CapsuleShape3D = kit.player.get_node("CollisionShape3D").shape

	# 1. Built from named parts, with the five outfit sockets.
	var missing: Array[String] = []
	for part in PARTS:
		if model.find_child(part, true, false) == null:
			missing.append(part)
	kit.check("the dog has every body part", missing.is_empty(), "missing: %s" % [missing])
	var missing_slots: Array[String] = []
	for slot in AnimalModel.SLOTS:
		if not model.sockets.has(slot):
			missing_slots.append(String(slot))
	kit.check("the five outfit sockets exist", missing_slots.is_empty(), "missing: %s" % [missing_slots])

	# 2. Size: fits the capsule, stands on the ground, and is chibi (big head).
	var box := _bounds(model)
	kit.check("height is between 1.4 and 1.8 m", box.size.y > 1.4 and box.size.y < 1.8, "%.2f m tall" % box.size.y)
	kit.check("the feet stand on the ground (lowest point within -3 cm to +6 cm)", box.position.y > -0.03 and box.position.y < 0.06,
			"lowest point y=%.3f" % box.position.y)
	kit.check("it fits inside the collision capsule footprint (x within 0.55, z within 0.6)",
			maxf(absf(box.position.x), absf(box.end.x)) < 0.55 and maxf(absf(box.position.z), absf(box.end.z)) < 0.6,
			"x %.2f..%.2f, z %.2f..%.2f (capsule radius %.1f)" % [box.position.x, box.end.x, box.position.z, box.end.z, capsule.radius])
	var head_box := _mesh_bounds(model.find_child("Skull", true, false))
	var torso_box := _mesh_bounds(model.find_child("Torso", true, false))
	kit.check("big-headed and cute: the head is at least 1.4 times as wide as the torso", head_box.size.x >= torso_box.size.x * 1.4,
			"head %.2f m, torso %.2f m wide" % [head_box.size.x, torso_box.size.x])

	# 3. Every mesh has a fadeable material (otherwise a part stays solid when the camera is close).
	var unfadeable := 0
	for mesh in model.all_meshes():
		if not (mesh.material_override is StandardMaterial3D):
			unfadeable += 1
	kit.check("every mesh has a StandardMaterial3D to fade", unfadeable == 0, "%d meshes without one" % unfadeable)

	# 4. Animation follows what the player does.
	await kit.physics_frames(30)
	var idle := model.leg_angles()
	kit.check("standing still: legs are straight", absf(idle.x) < 0.05 and absf(idle.y) < 0.05, "leg angles %s" % idle)
	kit.face(Vector3.FORWARD)
	Input.action_press("move_forward")
	var biggest := 0.0
	var opposite_ok := true
	var arms_ok := true
	for i in 60:
		await kit.physics_frames(1)
		var legs := model.leg_angles()
		var arms := model.arm_angles()
		biggest = maxf(biggest, maxf(absf(legs.x), absf(legs.y)))
		if absf(legs.x) > 0.25 and legs.x * legs.y >= 0.0:
			opposite_ok = false
		if absf(legs.x) > 0.3 and legs.x * arms.x >= 0.0:
			arms_ok = false
	Input.action_release("move_forward")
	kit.check("walking swings the legs (peak over 0.45 rad)", biggest > 0.45, "peak %.2f rad" % biggest)
	kit.check("the legs swing in opposite directions", opposite_ok)
	kit.check("each arm swings opposite its same-side leg", arms_ok)

	await kit.physics_frames(60)
	await kit.tap("jump")
	await kit.physics_frames(14)
	# (Which way the limbs point is checked by GEOMETRY in test_animation.gd; an angle sign here
	# once enshrined the backward-kicking jump pose as correct: lesson 42.)
	kit.check("in the air: the model switches to the jump pose (air amount over 0.8)", model.air_amount() > 0.8, "air %.2f" % model.air_amount())
	await kit.physics_frames(120)
	kit.check("after landing the pose relaxes (air amount under 0.05)", model.air_amount() < 0.05, "air %.2f" % model.air_amount())

	var blinks := 0
	for i in 300:
		await kit.physics_frames(1)
		if model.is_blinking():
			blinks += 1
	kit.check("it blinks now and then, but is not always shut", blinks > 5 and blinks < 60, "%d of 300 frames blinking" % blinks)

	# 5. Species drive the look: a cat-like animal builds differently from the dog.
	var cat_species := AnimalSpecies.new()
	cat_species.species_name = "Cat"
	cat_species.fur_color = Color(0.92, 0.92, 0.95)
	cat_species.ear_style = AnimalSpecies.EarStyle.POINTY
	cat_species.tail_style = AnimalSpecies.TailStyle.LONG
	cat_species.snout_length = 0.8
	cat_species.eye_patch = false
	var cat := AnimalModel.new()
	cat.species = cat_species
	kit.world.add_child(cat)
	await kit.physics_frames(2)
	var cat_ear := cat.find_child("EarL", true, false)
	var dog_ear := model.find_child("EarL", true, false)
	kit.check("a pointy-eared species builds cone ears, the dog builds floppy ones",
			cat_ear.find_child("Point", true, false) != null and dog_ear.find_child("Flap", true, false) != null)
	kit.check("a species with no eye patch has none; the dog does", cat.find_child("EyePatch", true, false) == null and model.find_child("EyePatch", true, false) != null)
	var cat_fur := (cat.find_child("Torso", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	var dog_fur := (model.find_child("Torso", true, false) as MeshInstance3D).material_override as StandardMaterial3D
	kit.check("species colours apply (cat fur is not the dog's)", cat_fur.albedo_color.is_equal_approx(cat_species.fur_color) and not dog_fur.albedo_color.is_equal_approx(cat_species.fur_color),
			"cat %s dog %s" % [cat_fur.albedo_color, dog_fur.albedo_color])
	cat.queue_free()

	# 6. Outfits sit on their sockets and fade with the body.
	var skull_top := _mesh_bounds(model.find_child("Skull", true, false)).end.y
	model.equip(&"head_top", Outfits.make(&"red_cap"))
	model.equip(&"neck", Outfits.make(&"blue_scarf"))
	await kit.physics_frames(2)
	var cap := model.get_equipped(&"head_top")
	var cap_box := _bounds(cap)
	kit.check("the cap sits on the head: its bottom is inside the skull, its top is above it",
			cap != null and cap_box.position.y < skull_top - 0.02 and cap_box.end.y > skull_top + 0.04,
			"cap y %.2f..%.2f, skull top %.2f" % [cap_box.position.y, cap_box.end.y, skull_top])
	var scarf_box := _bounds(model.get_equipped(&"neck"))
	var torso_top := torso_box.end.y
	kit.check("the scarf is round the neck, between the torso top and the chin",
			scarf_box.position.y < torso_top and scarf_box.end.y > torso_top - 0.05 and scarf_box.end.y < skull_top,
			"scarf y %.2f..%.2f, torso top %.2f" % [scarf_box.position.y, scarf_box.end.y, torso_top])
	model.set_fade(1.0)
	var still_visible := 0
	for mesh in model.all_meshes():
		if (mesh.material_override as StandardMaterial3D).albedo_color.a > 0.01:
			still_visible += 1
	kit.check("fading the body also fades the outfit (every mesh alpha 0)", still_visible == 0, "%d meshes still visible" % still_visible)
	model.set_fade(0.0)
	# An item put on while the body is already faded (camera squeezed, indoors) must be faded too.
	model.set_fade(1.0)
	model.equip(&"face", Outfits.make(&"red_cap"))
	var late_alpha := 1.0
	for mesh in (model.get_equipped(&"face") as Node3D).find_children("*", "MeshInstance3D", true, false):
		late_alpha = minf(late_alpha, ((mesh as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a)
	kit.check("an item equipped while the body is faded is faded too (alpha 0)", late_alpha < 0.01, "alpha %.2f" % late_alpha)
	model.unequip(&"face")
	model.set_fade(0.0)
	var head_c := _mesh_bounds(model.find_child("Skull", true, false)).get_center()
	var face_p: Vector3 = model.sockets[&"face"].global_position
	var torso_now := _mesh_bounds(model.find_child("Torso", true, false))  # fresh: the player has moved since the first measurement
	var torso_c := torso_now.get_center()
	var torso_p: Vector3 = model.sockets[&"torso"].global_position
	var back_p: Vector3 = model.sockets[&"back"].global_position
	kit.check("the face socket is on the front of the head, the torso socket inside the torso, the back socket behind it",
			face_p.z < head_c.z - 0.25 and absf(face_p.x - head_c.x) < 0.1 and torso_now.has_point(torso_p) and back_p.z > torso_c.z + 0.2,
			"face z %.2f (head centre %.2f), torso socket %s, back z %.2f (torso centre %.2f)" % [face_p.z, head_c.z, torso_p, back_p.z, torso_c.z])
	model.equip(&"head_top", Outfits.make(&"red_cap"))  # replaces the first cap
	var caps := 0
	for child in model.sockets[&"head_top"].get_children():
		if not child.is_queued_for_deletion():
			caps += 1
	kit.check("equipping into an occupied slot replaces the old item", caps == 1, "%d items on head_top" % caps)
	model.unequip(&"head_top")
	model.unequip(&"neck")
	await kit.physics_frames(2)
	kit.check("unequipping removes the items", model.get_equipped(&"head_top") == null and model.get_equipped(&"neck") == null)
	model.set_fade(0.0)
	kit.finish()


## World-space bounds of every mesh under `node` (or the node itself).
func _bounds(node: Node) -> AABB:
	var first := true
	var box := AABB()
	var meshes: Array[MeshInstance3D] = []
	for found in node.find_children("*", "MeshInstance3D", true, false):
		meshes.append(found)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh in meshes:
		var world_box := mesh.global_transform * mesh.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box


func _mesh_bounds(mesh: Node) -> AABB:
	return (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
