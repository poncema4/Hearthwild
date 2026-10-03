@tool
class_name Outfits
extends RefCounted
## The wardrobe: every wearable item, its slot and label, and a builder for each. `make()`
## returns a fresh Node3D to give to `AnimalModel.equip(slot, item)`, or just call
## `AnimalModel.equip_item(id)`. Items are simple shapes in the socket's own space:
## `head_top` = top of the head, `face` = front of the face, `neck` = top of the torso,
## `torso` = middle of the torso, `back` = behind the torso.
##
## Adding an item = one row in `CATALOG` and one builder here (the tests loop over the
## catalog, so a new item is checked automatically). Real art comes later.

## [id, slot, label]
const CATALOG: Array = [
	[&"red_cap", &"head_top", "Red cap"],
	[&"straw_hat", &"head_top", "Straw hat"],
	[&"round_glasses", &"face", "Round glasses"],
	[&"blue_scarf", &"neck", "Blue scarf"],
	[&"bow_tie", &"neck", "Bow tie"],
	[&"mint_sweater", &"torso", "Mint sweater"],
	[&"explorer_pack", &"back", "Explorer pack"],
]

const SLOTS: Array[StringName] = [&"head_top", &"face", &"neck", &"torso", &"back"]
const SLOT_LABELS := {&"head_top": "Hat", &"face": "Glasses", &"neck": "Neck", &"torso": "Top", &"back": "Back"}


## The slot an item belongs on ("" if unknown).
static func slot_of(item_id: StringName) -> StringName:
	for row in CATALOG:
		if row[0] == item_id:
			return row[1]
	return &""


static func label_of(item_id: StringName) -> String:
	for row in CATALOG:
		if row[0] == item_id:
			return row[2]
	return ""


## All item ids for a slot, in catalog order.
static func items_for_slot(slot: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for row in CATALOG:
		if row[1] == slot:
			found.append(row[0])
	return found


static func make(item_id: StringName) -> Node3D:
	match item_id:
		&"red_cap":
			return _red_cap()
		&"straw_hat":
			return _straw_hat()
		&"round_glasses":
			return _round_glasses()
		&"blue_scarf":
			return _blue_scarf()
		&"bow_tie":
			return _bow_tie()
		&"mint_sweater":
			return _mint_sweater()
		&"explorer_pack":
			return _explorer_pack()
	push_warning("Outfits: unknown item %s" % item_id)
	return Node3D.new()


static func _red_cap() -> Node3D:
	var root := Node3D.new()
	root.name = "RedCap"
	var red := Color(0.86, 0.18, 0.2)
	var dome := SphereMesh.new()
	dome.radius = 0.33
	dome.height = 0.33  # a hemisphere's height must equal its radius (twice that stretches it into a gnome hat)
	dome.is_hemisphere = true
	_mesh(root, "Dome", dome, Vector3(0, -0.1, 0.0), red, Vector3(1.05, 0.7, 1.05))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.2
	brim.bottom_radius = 0.2
	brim.height = 0.025
	_mesh(root, "Brim", brim, Vector3(0, -0.07, -0.33), red.darkened(0.15), Vector3(1.0, 1.0, 0.8), Vector3(deg_to_rad(-10), 0, 0))
	var button := SphereMesh.new()
	button.radius = 0.035
	button.height = 0.07
	_mesh(root, "Button", button, Vector3(0, 0.15, 0), Color(1.0, 0.9, 0.7))
	return root


static func _straw_hat() -> Node3D:
	var root := Node3D.new()
	root.name = "StrawHat"
	var straw := Color(0.92, 0.80, 0.47)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.48
	brim.bottom_radius = 0.48
	brim.height = 0.03
	_mesh(root, "Brim", brim, Vector3(0, -0.04, 0), straw)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.24
	crown.bottom_radius = 0.28
	crown.height = 0.2
	_mesh(root, "Crown", crown, Vector3(0, 0.06, 0), straw.darkened(0.05))
	var band := CylinderMesh.new()
	band.top_radius = 0.285
	band.bottom_radius = 0.285
	band.height = 0.05
	_mesh(root, "Band", band, Vector3(0, 0.0, 0), Color(0.78, 0.2, 0.22))
	return root


static func _round_glasses() -> Node3D:
	var root := Node3D.new()
	root.name = "RoundGlasses"
	var frame := Color(0.18, 0.14, 0.12)
	for side in [-1.0, 1.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.065
		ring.outer_radius = 0.095
		_mesh(root, "Rim", ring, Vector3(side * 0.15, 0.0, -0.045), frame, Vector3.ONE, Vector3(deg_to_rad(90), 0, 0))
		var lens := CylinderMesh.new()
		lens.top_radius = 0.07
		lens.bottom_radius = 0.07
		lens.height = 0.01
		_mesh(root, "Lens", lens, Vector3(side * 0.15, 0.0, -0.045), Color(0.8, 0.92, 1.0), Vector3.ONE, Vector3(deg_to_rad(90), 0, 0))
	var bridge := BoxMesh.new()
	bridge.size = Vector3(0.09, 0.018, 0.018)
	_mesh(root, "Bridge", bridge, Vector3(0, 0.02, -0.045), frame)
	return root


static func _blue_scarf() -> Node3D:
	var root := Node3D.new()
	root.name = "BlueScarf"
	var blue := Color(0.22, 0.42, 0.85)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.32
	_mesh(root, "Wrap", ring, Vector3(0, -0.02, 0), blue, Vector3(1.0, 1.4, 1.0))
	var tail := BoxMesh.new()
	tail.size = Vector3(0.14, 0.34, 0.05)
	_mesh(root, "Tail", tail, Vector3(0.1, -0.2, -0.27), blue.lightened(0.15), Vector3.ONE, Vector3(0, 0, deg_to_rad(8)))
	return root


static func _bow_tie() -> Node3D:
	var root := Node3D.new()
	root.name = "BowTie"
	var pink := Color(0.92, 0.28, 0.45)
	for side in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(0.14, 0.12, 0.05)
		_mesh(root, "Wing", wing, Vector3(side * 0.09, -0.03, -0.27), pink, Vector3.ONE, Vector3(0, 0, side * deg_to_rad(-10)))
	var knot := SphereMesh.new()
	knot.radius = 0.04
	knot.height = 0.08
	_mesh(root, "Knot", knot, Vector3(0, -0.03, -0.27), pink.darkened(0.2))
	return root


static func _mint_sweater() -> Node3D:
	var root := Node3D.new()
	root.name = "MintSweater"
	var shell := CapsuleMesh.new()
	shell.radius = 0.30
	shell.height = 0.62
	_mesh(root, "Shell", shell, Vector3(0, 0.0, 0.0), Color(0.45, 0.78, 0.66))
	var stripe := TorusMesh.new()
	stripe.inner_radius = 0.285
	stripe.outer_radius = 0.315
	_mesh(root, "Stripe", stripe, Vector3(0, 0.04, 0.0), Color(0.97, 0.97, 0.9))
	return root


static func _explorer_pack() -> Node3D:
	var root := Node3D.new()
	root.name = "ExplorerPack"
	var brown := Color(0.55, 0.36, 0.22)
	var body := BoxMesh.new()
	body.size = Vector3(0.36, 0.42, 0.17)
	_mesh(root, "Body", body, Vector3(0, 0.0, 0.08), brown)
	var flap := BoxMesh.new()
	flap.size = Vector3(0.37, 0.14, 0.19)
	_mesh(root, "Flap", flap, Vector3(0, 0.15, 0.08), brown.darkened(0.15))
	var roll := CylinderMesh.new()
	roll.top_radius = 0.06
	roll.bottom_radius = 0.06
	roll.height = 0.4
	_mesh(root, "Bedroll", roll, Vector3(0, -0.22, 0.1), Color(0.35, 0.5, 0.7), Vector3.ONE, Vector3(0, 0, deg_to_rad(90)))
	return root


static func _mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, color: Color,
		mesh_scale := Vector3.ONE, rot_rad := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	instance.position = pos
	instance.scale = mesh_scale
	instance.rotation = rot_rad
	parent.add_child(instance)
