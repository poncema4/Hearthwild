class_name LakeDecor
extends Node3D
## Reeds along the banks and lily pads on the water. Both are placed by sampling the real terrain (the
## waterline is irregular), never on a fishing spot's standing area or across a casting line, and the same seed
## always gives the same lake. One MultiMesh each, so they cost two draw calls.

const REED_CLUMPS := 90
const STALKS_PER_CLUMP := 4
const PAD_COUNT := 36
## Reeds keep this far (m) from where a player stands to fish, and pads this far from the cast line.
const REED_CLEAR_OF_SPOT := 2.4
const PAD_CLEAR_OF_LINE := 1.2

@export var terrain_path: NodePath = ^"../Terrain"
@export var fishing_path: NodePath = ^"../Fishing"
@export var decor_seed: int = 5

var reeds: MultiMeshInstance3D
var pads: MultiMeshInstance3D
var _terrain: Terrain
var _fishing: FishingPond
var _rng := RandomNumberGenerator.new()
# The positions are kept here as well as in the MultiMeshes: a headless run (the tests) cannot read a
# MultiMesh back (the dummy renderer returns zeros), and these are the source of truth anyway.
var _reed_positions: Array[Vector3] = []
var _pad_positions: Array[Vector3] = []


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain
	_fishing = get_node_or_null(fishing_path) as FishingPond
	if _terrain == null or _fishing == null:
		push_warning("LakeDecor: needs the Terrain and the Fishing pond")
		return
	_rng.seed = decor_seed
	reeds = _make_reeds()
	pads = _make_pads()
	add_child(reeds)
	add_child(pads)


func reed_stalk_count() -> int:
	return reeds.multimesh.instance_count if reeds else 0


func pad_count() -> int:
	return pads.multimesh.instance_count if pads else 0


## World positions of every reed stalk base and every pad, for tests.
func reed_positions() -> Array[Vector3]:
	return _reed_positions


func pad_positions() -> Array[Vector3]:
	return _pad_positions


func _make_reeds() -> MultiMeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.035
	mesh.height = 1.2
	mesh.radial_segments = 4
	mesh.rings = 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts := 0
	var clumps := 0
	while clumps < REED_CLUMPS and attempts < REED_CLUMPS * 60:
		attempts += 1
		var angle := _rng.randf() * TAU
		var radius := _terrain.waterline_at(angle) + _rng.randf_range(-0.4, 2.2)
		var centre := _terrain.pond_center + Vector2.from_angle(angle) * radius
		if _near_standing_spot(centre, REED_CLEAR_OF_SPOT):
			continue
		var ground := _terrain.height_at(centre.x, centre.y)
		if ground < _terrain.water_level - 0.25 or ground > _terrain.water_level + 0.9:
			continue
		clumps += 1
		for s in STALKS_PER_CLUMP:
			var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.05, 0.28)
			var base_xz := centre + offset
			var base := Vector3(base_xz.x, maxf(_terrain.height_at(base_xz.x, base_xz.y), _terrain.water_level - 0.25), base_xz.y)
			var tall := _rng.randf_range(0.8, 1.45)
			var tilt := Basis.from_euler(Vector3(_rng.randf_range(-0.22, 0.22), _rng.randf() * TAU, _rng.randf_range(-0.22, 0.22)))
			var stalk := tilt.scaled(Vector3(1.0, tall, 1.0))
			# The cylinder is centred, so lift it by half its (tilted, scaled) height to stand on the base.
			transforms.append(Transform3D(stalk, base + tilt.y * (0.6 * tall)))
			_reed_positions.append(base)
			colors.append(Color(0.28, 0.46, 0.2).lerp(Color(0.52, 0.6, 0.25), _rng.randf()))
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	return _instance("Reeds", multimesh, true)


func _make_pads() -> MultiMeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.4
	mesh.height = 0.02
	mesh.radial_segments = 9
	mesh.rings = 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts := 0
	while transforms.size() < PAD_COUNT and attempts < PAD_COUNT * 80:
		attempts += 1
		var angle := _rng.randf() * TAU
		var radius := _rng.randf_range(2.0, _terrain.waterline_at(angle) - 1.2)
		var at := _terrain.pond_center + Vector2.from_angle(angle) * radius
		var depth := _terrain.water_depth_at(at.x, at.y)
		if depth < 0.4 or depth > 2.6 or _near_cast_line(at, PAD_CLEAR_OF_LINE):
			continue
		var size := _rng.randf_range(0.7, 1.25)
		var pad_basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(size, 1.0, size))
		transforms.append(Transform3D(pad_basis, Vector3(at.x, _terrain.water_level + 0.02, at.y)))
		_pad_positions.append(Vector3(at.x, _terrain.water_level + 0.02, at.y))
		colors.append(Color(0.22, 0.5, 0.2).lerp(Color(0.38, 0.62, 0.26), _rng.randf()))
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
	return _instance("LilyPads", multimesh, false)


func _instance(node_name: String, multimesh: MultiMesh, double_sided: bool) -> MultiMeshInstance3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _near_standing_spot(point: Vector2, distance: float) -> bool:
	for spot in _fishing.spots:
		var stand := spot.standing_spot()
		if Vector2(stand.x, stand.z).distance_to(point) < distance:
			return true
	return false


func _near_cast_line(point: Vector2, distance: float) -> bool:
	for spot in _fishing.spots:
		var stand := spot.standing_spot()
		var bobber := spot.bobber_target()
		var from := Vector2(stand.x, stand.z)
		var to := Vector2(bobber.x, bobber.z)
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to)) < distance:
			return true
	return false
