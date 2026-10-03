class_name FishingPond
extends Node3D
## Four fishing spots round the pond, each with a little signpost. Where to stand was
## measured on the real terrain: the waterline is about 4.2 m from the pond centre, so
## the standing spots are 5.3 m out and the cast (3.2 m) lands in water about 2 m deep.
## Angles were picked where no tree or rock is within 5.5 m.
##
## Each spot is a `FishingSpot` (an Interactable) placed 1 m in front of where you stand.

@export var terrain_path: NodePath = ^"../Terrain"
@export var spot_angles_degrees: Array[float] = [60.0, 135.0, 240.0, 315.0]
@export var stand_radius: float = 5.3
@export var cast_distance: float = 3.2

var spots: Array[FishingSpot] = []
var _terrain: Terrain


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain
	if _terrain == null:
		push_warning("FishingPond: no Terrain at %s" % terrain_path)
		return
	for i in spot_angles_degrees.size():
		_build_spot(i, Vector2.from_angle(deg_to_rad(spot_angles_degrees[i])))


func _build_spot(index: int, outward: Vector2) -> void:
	var stand_xz := _terrain.pond_center + outward * stand_radius
	var ground := Vector3(stand_xz.x, _terrain.height_at(stand_xz.x, stand_xz.y), stand_xz.y)
	var toward_water := Vector3(-outward.x, 0.0, -outward.y)

	var spot := FishingSpot.new()
	spot.name = "FishingSpot%d" % (index + 1)
	spot.toward_water = toward_water
	spot.cast_distance = cast_distance
	spot.water_level = _terrain.water_level
	spot.position = ground + toward_water  # 1 m in front of the standing spot
	add_child(spot)
	spots.append(spot)

	# A signpost to the side so the spot is easy to find.
	var side := Vector3(-toward_water.z, 0.0, toward_water.x)
	var post_at := ground + side * 0.95
	post_at.y = _terrain.height_at(post_at.x, post_at.z)
	var body := StaticBody3D.new()
	body.name = "Sign%d" % (index + 1)
	body.position = post_at
	body.rotation.y = atan2(-toward_water.x, -toward_water.z)
	add_child(body)
	var wood := _material(Color(0.5, 0.36, 0.24))
	_box(body, "Post", Vector3(0.12, 1.2, 0.12), Vector3(0, 0.6, 0), wood, true)
	_box(body, "Plank", Vector3(0.62, 0.3, 0.05), Vector3(0, 1.1, 0.03), _material(Color(0.93, 0.85, 0.66)), false)
	var fish := MeshInstance3D.new()
	fish.name = "FishIcon"
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.1
	body_mesh.height = 0.2
	fish.mesh = body_mesh
	fish.material_override = _material(Color(0.25, 0.5, 0.85))
	fish.position = Vector3(-0.03, 1.1, 0.065)
	fish.scale = Vector3(1.5, 0.8, 0.3)
	body.add_child(fish)
	var fin := _box(body, "Tail", Vector3(0.09, 0.12, 0.02), Vector3(0.16, 1.1, 0.065), _material(Color(0.25, 0.5, 0.85)), false)
	fin.rotation = Vector3(0, 0, deg_to_rad(45))


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material, collide: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	if collide:
		var shape := CollisionShape3D.new()
		shape.name = node_name + "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = pos
		parent.add_child(shape)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
