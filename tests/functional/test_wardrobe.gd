extends SceneTree
## Functional test: the wardrobe and the animals. Every item is checked on EVERY animal: it equips, it sits on the body (not floating),
## it stays off the ground, it fades with the body, and it replaces what was in its slot. Plus catalog sanity and a profile round trip.
## Measures the real bounding boxes of the drawn meshes, never assumptions about where an item "should" be.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_wardrobe.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit

const EXPECTED_COUNTS := {&"head_top": 7, &"face": 4, &"neck": 5, &"torso": 5, &"back": 4}
const ORIGINAL_FIRST := {&"head_top": &"red_cap", &"face": &"round_glasses", &"neck": &"blue_scarf", &"torso": &"mint_sweater", &"back": &"explorer_pack"}


func _initialize() -> void:
	_run.call_deferred()


## The bounding box, in world space, of every mesh under `root` that passes `keep`.
func _bounds(root: Node, keep: Callable = Callable()) -> AABB:
	var box := AABB()
	var first := true
	var nodes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.append(root)  # find_children never returns the node itself: a lone mesh would measure as an empty box
	for node in nodes:
		var mesh := node as MeshInstance3D
		if keep.is_valid() and not keep.call(mesh):
			continue
		var world_box: AABB = mesh.global_transform * mesh.get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box


func _is_under_socket(node: Node, model: AnimalModel) -> bool:
	for socket in model.sockets.values():
		if socket.is_ancestor_of(node):
			return true
	return false


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()

	# 1. Catalog sanity.
	var slot_counts := {}
	var labels := {}
	var bad_ids := []
	var dup_labels := []
	for row in Outfits.CATALOG:
		slot_counts[row[1]] = int(slot_counts.get(row[1], 0)) + 1
		var id := String(row[0])
		if id != id.to_lower() or id.contains(" ") or id.is_empty():
			bad_ids.append(id)
		if labels.has(row[2]):
			dup_labels.append(row[2])
		labels[row[2]] = true
		if String(row[2]).length() > 18:
			bad_ids.append("label too long: %s" % row[2])
	kit.check("the wardrobe has 25 items in the expected counts per slot (hat 7, glasses 4, neck 5, top 5, back 4)", Outfits.CATALOG.size() == 25 and slot_counts == EXPECTED_COUNTS, str(slot_counts))
	kit.check("ids are lower-case snake_case and labels are unique and fit the picker (18 letters)", bad_ids.is_empty() and dup_labels.is_empty(), "%s %s" % [bad_ids, dup_labels])
	var first_ok := true
	for slot in ORIGINAL_FIRST:
		first_ok = first_ok and Outfits.items_for_slot(slot)[0] == ORIGINAL_FIRST[slot]
	kit.check("the original item is still FIRST in every slot (the picker order and old saves/tests rely on it)", first_ok)

	# 2. Each item on its own.
	var item_problems := []
	var node_names := {}
	for row in Outfits.CATALOG:
		var item := Outfits.make(row[0])
		kit.world.add_child(item)
		item.global_position = Vector3(0, 40, 0)
		var meshes := item.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() < 2:
			item_problems.append("%s has only %d meshes" % [row[0], meshes.size()])
		for mesh_node in meshes:
			var mesh := mesh_node as MeshInstance3D
			if not (mesh.material_override is StandardMaterial3D):
				item_problems.append("%s/%s has no StandardMaterial3D" % [row[0], mesh.name])
			var size := mesh.get_aabb().size * mesh.scale
			if not size.is_finite() or maxf(size.x, maxf(size.y, size.z)) > 1.4:
				item_problems.append("%s/%s size %s" % [row[0], mesh.name, size])
			if not mesh.position.is_finite():
				item_problems.append("%s/%s position %s" % [row[0], mesh.name, mesh.position])
		if node_names.has(item.name):
			item_problems.append("two items are both named %s" % item.name)
		node_names[item.name] = true
		item.free()
	kit.check("every item is made of 2+ meshes with a fadeable material, finite positions, nothing over 1.4 m, and a unique node name", item_problems.is_empty(), str(item_problems.slice(0, 6)))

	# 3. Every item on every animal.
	var fit_problems := []
	var combos := 0
	var lowest_gap := 9.0
	var widest := 0.0
	for species in AnimalSpecies.all():
		var model := AnimalModel.new()
		kit.world.add_child(model)
		model.global_position = Vector3(60.0, 30.0, 60.0)  # high in the air, far from everything: nothing but the model is measured
		model.set_species(species)
		await kit.physics_frames(2)
		var body := _bounds(model, func(mesh): return not _is_under_socket(mesh, model))
		for row in Outfits.CATALOG:
			var id: StringName = row[0]
			var slot: StringName = row[1]
			model.equip_item(id)
			combos += 1
			var item := model.get_equipped(slot)
			if item == null or item.get_parent() != model.sockets[slot] or model.sockets[slot].get_child_count() != 1 or model.worn_items().get(slot) != id:
				fit_problems.append("%s/%s did not equip cleanly" % [species.id, id])
				continue
			var item_box := _bounds(item)
			var gap := _box_gap(item_box, body)
			lowest_gap = minf(lowest_gap, 0.0) if gap <= 0.0 else minf(lowest_gap, gap)
			if gap > 0.06:
				fit_problems.append("%s/%s floats %.2f m from the body" % [species.id, id, gap])
			var feet_y := model.global_position.y
			if item_box.position.y < feet_y + 0.12:
				fit_problems.append("%s/%s reaches %.2f m above the feet only" % [species.id, id, item_box.position.y - feet_y])
			widest = maxf(widest, maxf(item_box.size.x, item_box.size.z))
			if item_box.size.x > 1.4 or item_box.size.y > 1.2 or item_box.size.z > 1.4:
				fit_problems.append("%s/%s is %s big" % [species.id, id, item_box.size])
		# A full outfit: one item per slot, then replace and remove.
		for slot in Outfits.SLOTS:
			model.equip_item(Outfits.items_for_slot(slot).back())
		var full := model.worn_items()
		model.set_species(AnimalSpecies.by_id(&"dog"))
		var kept := model.worn_items() == full
		model.unequip_slot(&"torso")
		if not kept or full.size() != 5 or model.worn_items().has(&"torso") or model.worn_items().size() != 4:
			fit_problems.append("%s: full outfit / species switch / unequip misbehaved (%s)" % [species.id, str(model.worn_items())])
		model.free()
	kit.check("all %d animal x item combinations equip cleanly into their own socket (one item per socket, the right id worn)" % combos, combos == 225 and fit_problems.is_empty(), str(fit_problems.slice(0, 5)))
	kit.check("and every item touches the body (within 6 cm, none floats), reaches at least 12 cm above the feet, and none is over 1.4 m wide", fit_problems.is_empty() and widest <= 1.4, "widest %.2f m, %s" % [widest, str(fit_problems.slice(0, 5))])

	# 4. Fading: every item on the model fades with the body (camera too close / indoors) and comes back.
	var fade_problems := []
	var fade_model := AnimalModel.new()
	kit.world.add_child(fade_model)
	fade_model.global_position = Vector3(60.0, 30.0, 60.0)
	fade_model.set_species(AnimalSpecies.by_id(&"fox"))
	for row in Outfits.CATALOG:
		fade_model.equip_item(row[0])
		var item := fade_model.get_equipped(row[1])
		fade_model.set_fade(1.0)
		for mesh_node in item.find_children("*", "MeshInstance3D", true, false):
			var alpha := _alpha(mesh_node)
			if alpha < 0.0 or alpha > 0.01:
				fade_problems.append("%s/%s stays visible or has no material (alpha %.2f)" % [row[0], mesh_node.name, alpha])
		fade_model.set_fade(0.0)
		for mesh_node in item.find_children("*", "MeshInstance3D", true, false):
			var alpha_back := _alpha(mesh_node)
			if alpha_back < 0.99:
				fade_problems.append("%s/%s does not come back (alpha %.2f)" % [row[0], mesh_node.name, alpha_back])
	fade_model.free()
	kit.check("every one of the 25 items fades fully out with the body and fully back in", fade_problems.is_empty(), str(fade_problems.slice(0, 5)))

	# 5. Shapes that matter: the dress is a real dress, the wings are real wings.
	var shape_model := AnimalModel.new()
	kit.world.add_child(shape_model)
	shape_model.global_position = Vector3(60.0, 30.0, 60.0)
	shape_model.set_species(AnimalSpecies.by_id(&"dog"))
	await kit.physics_frames(2)
	var torso_box := _bounds(shape_model.find_child("Torso", true, false))
	var skull_box := _bounds(shape_model.find_child("Skull", true, false))
	kit.check("the measuring works: the torso and skull boxes are real (not empty), the torso 0.4 to 0.8 m wide, the skull 0.5 to 1.3 m wide", torso_box.size.x > 0.4 and torso_box.size.x < 0.8 and skull_box.size.x > 0.5 and skull_box.size.x < 1.3,
			"torso %s, skull %s" % [torso_box.size, skull_box.size])
	shape_model.equip_item(&"sunny_dress")
	var dress_box := _bounds(shape_model.get_equipped(&"torso"))
	kit.check("the sunny dress flares into a skirt: wider than the torso by 40%+ and hanging 20+ cm lower than the torso's bottom",
			dress_box.size.x > torso_box.size.x * 1.4 and dress_box.position.y < torso_box.position.y - 0.2 and dress_box.position.y > shape_model.global_position.y + 0.15,
			"dress %.2f wide from y %.2f, torso %.2f wide from y %.2f" % [dress_box.size.x, dress_box.position.y, torso_box.size.x, torso_box.position.y])
	var skirt := shape_model.get_equipped(&"torso").get_node_or_null("Skirt") as MeshInstance3D
	kit.check("and the skirt itself is a real flare: its mesh is 35+ cm tall and 1.0+ m across (the whole-dress box alone could be fooled by the hem ring)", skirt != null and skirt.get_aabb().size.y * skirt.scale.y >= 0.35 and skirt.get_aabb().size.x * skirt.scale.x >= 1.0,
			"skirt %s" % (skirt.get_aabb().size * skirt.scale if skirt else "missing"))
	shape_model.equip_item(&"angel_wings")
	var wing_box := _bounds(shape_model.get_equipped(&"back"))
	var wing_center_z := wing_box.get_center().z - shape_model.global_position.z
	var torso_center_z := torso_box.get_center().z - shape_model.global_position.z
	kit.check("the angel wings spread wider than the body (+40%) and sit BEHIND the torso (toward +z, the dog faces -z)", wing_box.size.x > torso_box.size.x * 2.0 and wing_center_z > torso_center_z + 0.05,
			"wings %.2f wide, centre z %.2f; torso %.2f wide, centre z %.2f" % [wing_box.size.x, wing_center_z, torso_box.size.x, torso_center_z])
	shape_model.equip_item(&"wizard_hat")
	var hat_box := _bounds(shape_model.get_equipped(&"head_top"))
	var skull_top := _bounds(shape_model.find_child("Skull", true, false)).end.y
	kit.check("the wizard hat towers over the head (its tip 35+ cm above the skull) and its brim is wider than the head", hat_box.end.y > skull_top + 0.35 and hat_box.size.x > _bounds(shape_model.find_child("Skull", true, false)).size.x,
			"hat top %.2f, skull top %.2f, hat %.2f wide" % [hat_box.end.y, skull_top, hat_box.size.x])
	shape_model.free()

	# 6. Saves: every item survives a profile round trip on its own slot, and is dropped on a wrong one.
	var profile_problems := []
	for row in Outfits.CATALOG:
		var restored := PlayerProfile.from_dict({"name": "Test", "species": "panda", "outfit": {String(row[1]): String(row[0])}})
		if restored.species_id != &"panda" or restored.outfit.get(row[1]) != row[0]:
			profile_problems.append("%s lost in a round trip" % row[0])
		var wrong_slot: StringName = &"face" if row[1] != &"face" else &"back"
		var rejected := PlayerProfile.from_dict({"name": "Test", "outfit": {String(wrong_slot): String(row[0])}})
		if not rejected.outfit.is_empty():
			profile_problems.append("%s was accepted on the wrong slot %s" % [row[0], wrong_slot])
	kit.check("all 25 items survive a saved profile on their own slot and are rejected on any other slot (hand-edited saves cannot cheat)", profile_problems.is_empty(), str(profile_problems.slice(0, 5)))

	kit.finish()


## The alpha of a mesh's material, or -1 when it has no StandardMaterial3D (never index a missing material: a crashed test hangs until the step timeout).
func _alpha(mesh_node: Node) -> float:
	var material := (mesh_node as MeshInstance3D).material_override as StandardMaterial3D
	return material.albedo_color.a if material != null else -1.0


## The smallest distance between two boxes (0 when they touch or overlap).
func _box_gap(a: AABB, b: AABB) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	var dz := maxf(0.0, maxf(a.position.z - b.end.z, b.position.z - a.end.z))
	return Vector3(dx, dy, dz).length()
