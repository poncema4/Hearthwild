@tool
class_name Outfits
extends RefCounted
## Placeholder clothes for the wardrobe system: each `make()` returns a fresh
## Node3D to hand to `AnimalModel.equip(slot, item)`. Real outfits (and a
## closet screen) come later; these prove that the sockets work.
##
## Items are built in the socket's own space: `head_top` is the middle of the
## top of the head, `neck` is the top of the torso.

const ITEMS: Array[StringName] = [&"red_cap", &"blue_scarf"]


## The slot an item belongs on.
static func slot_of(item_id: StringName) -> StringName:
	match item_id:
		&"red_cap":
			return &"head_top"
		&"blue_scarf":
			return &"neck"
	return &""


static func make(item_id: StringName) -> Node3D:
	match item_id:
		&"red_cap":
			return _red_cap()
		&"blue_scarf":
			return _blue_scarf()
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
