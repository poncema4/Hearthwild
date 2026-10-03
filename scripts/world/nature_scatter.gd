@tool
class_name NatureScatter
extends Node3D
## Places trees, rocks, grass and flowers on the terrain.
##
## Deterministic: the same seed and terrain always give the same layout.
## Trees get denser toward the hill ring, so the meadow is framed by forest.
## Nothing spawns in the spawn clearing or in the pond.
## Grass and flowers are MultiMeshes (thousands of copies, one draw call).
##
## Runs in the editor too. Generated nodes are not saved into the scene.
## Regenerates whenever the terrain rebuilds. Changing the counts or seeds
## here takes effect when the scene is reloaded.

@export var terrain_path: NodePath = ^"../Terrain"
@export var scatter_seed: int = 11
@export var tree_count: int = 280
@export var rock_count: int = 130
@export var grass_count: int = 48000
@export var flower_count: int = 1400
## No trees or rocks closer than this to the spawn point.
@export var clear_radius: float = 11.0

const TREE_SCENES: Array[PackedScene] = [
	preload("res://scenes/world/nature/tree_round.tscn"),
	preload("res://scenes/world/nature/tree_pine.tscn"),
]
const ROCK_SCENE: PackedScene = preload("res://scenes/world/nature/rock.tscn")
const FLOWER_COLORS: Array[Color] = [
	Color(1.0, 0.95, 0.85), Color(1.0, 0.85, 0.3), Color(0.95, 0.55, 0.7), Color(0.7, 0.6, 1.0),
]

var _terrain: Terrain
var _rng := RandomNumberGenerator.new()
var _generated: Node3D


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain
	if _terrain == null:
		push_error("NatureScatter: no Terrain at %s" % terrain_path)
		return
	if Engine.is_editor_hint() and not _terrain.rebuilt.is_connected(_generate):
		_terrain.rebuilt.connect(_generate)
	_generate()


## Every placed tree, for tests and future systems (e.g. gathering wood).
func get_trees() -> Array[Node3D]:
	return _children_of("Trees")


## Every placed rock.
func get_rocks() -> Array[Node3D]:
	return _children_of("Rocks")


func _children_of(group_name: String) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if _generated:
		for child in _generated.get_node(group_name).get_children():
			nodes.append(child as Node3D)
	return nodes


func _generate() -> void:
	if _generated:
		# Detach first: a node queued for freeing still holds its name, and the
		# replacement would be auto-renamed.
		remove_child(_generated)
		_generated.queue_free()
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)
	_rng.seed = scatter_seed

	_place_trees()
	_place_rocks()
	_generated.add_child(_make_grass())
	_generated.add_child(_make_flowers())


func _place_trees() -> void:
	var parent := Node3D.new()
	parent.name = "Trees"
	_generated.add_child(parent)
	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < tree_count * 40:
		attempts += 1
		var spot := _random_spot(0.92)
		if not _is_open_ground(spot, clear_radius):
			continue
		# Denser toward the edge: accept with a probability that grows outward.
		var edge := Vector2(spot.x, spot.z).length() / _terrain.half_size()
		if _rng.randf() > smoothstep(0.25, 0.75, edge) * 0.9 + 0.1:
			continue
		if _too_close(parent, spot, 3.2):
			continue
		var tree := TREE_SCENES[_rng.randi() % TREE_SCENES.size()].instantiate() as Node3D
		tree.position = spot
		tree.rotation.y = _rng.randf() * TAU
		tree.scale = Vector3.ONE * _rng.randf_range(0.8, 1.35)
		parent.add_child(tree)
		placed += 1


func _place_rocks() -> void:
	var parent := Node3D.new()
	parent.name = "Rocks"
	_generated.add_child(parent)
	var placed := 0
	var attempts := 0
	while placed < rock_count and attempts < rock_count * 40:
		attempts += 1
		var spot := _random_spot(0.9)
		if not _is_open_ground(spot, clear_radius * 0.6):
			continue
		if _too_close(_generated.get_node("Trees"), spot, 1.8):
			continue
		var rock := ROCK_SCENE.instantiate() as Node3D
		rock.position = spot + Vector3.DOWN * 0.1
		rock.rotation = Vector3(_rng.randf() * 0.4, _rng.randf() * TAU, _rng.randf() * 0.4)
		# Uniform scale on the body (Jolt can't stretch a sphere collider);
		# the squash for variety goes on the mesh only.
		rock.scale = Vector3.ONE * _rng.randf_range(0.6, 1.6)
		var mesh := rock.get_node("RockMesh") as Node3D
		mesh.scale = Vector3(_rng.randf_range(0.9, 1.4), _rng.randf_range(0.6, 1.0), 1.0)
		parent.add_child(rock)
		placed += 1


func _make_grass() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _grass_tuft_mesh()
	mm.instance_count = grass_count
	var i := 0
	var attempts := 0
	while i < grass_count and attempts < grass_count * 4:
		attempts += 1
		# Up to the boundary walls (58 of 60 m), so the hill rim gets grass too.
		var spot := _random_spot(0.96)
		# Grass is allowed on steeper slopes than trees, so the hills aren't bare.
		if not _is_open_ground(spot, 0.0, 1.6):
			continue
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.7, 1.3))
		mm.set_instance_transform(i, Transform3D(basis, spot))
		# A little deeper and more saturated than the ground, so tufts read
		# as blades against it instead of ghostly pale patches.
		mm.set_instance_color(i, Color(0.27, 0.55, 0.18).lerp(Color(0.46, 0.70, 0.24), _rng.randf()))
		i += 1
	mm.visible_instance_count = i

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	var node := MultiMeshInstance3D.new()
	node.name = "Grass"
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _make_flowers() -> MultiMeshInstance3D:
	var head := SphereMesh.new()
	head.radius = 0.09
	head.height = 0.14
	head.radial_segments = 6
	head.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = head
	mm.instance_count = flower_count
	var i := 0
	var attempts := 0
	while i < flower_count and attempts < flower_count * 6:
		attempts += 1
		var spot := _random_spot(0.7)
		if not _is_open_ground(spot, 2.0):
			continue
		mm.set_instance_transform(i, Transform3D(Basis(), spot + Vector3.UP * 0.32))
		mm.set_instance_color(i, FLOWER_COLORS[_rng.randi() % FLOWER_COLORS.size()])
		i += 1
	mm.visible_instance_count = i

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.7
	var node := MultiMeshInstance3D.new()
	node.name = "Flowers"
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## A tuft of five crossed grass blades, darker at the root.
## Normals point straight up so both sides of a blade are lit like the
## ground it grows from. Each side is its own one-sided triangle: with
## CULL_DISABLED, Godot flips the normal on back faces and they render dark.
func _grass_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for blade in 5:
		var angle := blade * TAU / 5.0 + (0.3 if blade % 2 else 0.0)
		var offset := Vector3(cos(angle * 1.7), 0, sin(angle * 1.7)) * 0.06
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.06
		var lean := Vector3(-sin(angle), 0, cos(angle)) * 0.1
		var tip := offset + Vector3(0, 0.26 + 0.05 * (blade % 3), 0) + lean
		# Front and back as two one-sided triangles, both lit from above.
		for flip in [false, true]:
			var a := offset - side if not flip else offset + side
			var b := offset + side if not flip else offset - side
			st.set_color(Color(0.82, 0.82, 0.82))
			st.add_vertex(a)
			st.add_vertex(b)
			st.set_color(Color.WHITE)
			st.add_vertex(tip)
	return st.commit()


## A random point on the terrain surface, within `extent` of the half size.
func _random_spot(extent: float) -> Vector3:
	var half := _terrain.half_size() * extent
	var x := _rng.randf_range(-half, half)
	var z := _rng.randf_range(-half, half)
	return Vector3(x, _terrain.height_at(x, z), z)


## True if the spot is dry land outside the clearing and not too steep.
func _is_open_ground(spot: Vector3, clearing: float, max_slope: float = 0.8) -> bool:
	if Vector2(spot.x, spot.z).length() < clearing:
		return false
	# Keep the village and the paths to it clear of everything.
	if _terrain.in_village(spot.x, spot.z, 1.5) or _terrain.path_distance(spot.x, spot.z) < 2.6:
		return false
	if spot.y < _terrain.water_level + 0.25:
		return false
	var pond_distance := Vector2(spot.x, spot.z).distance_to(_terrain.pond_center)
	if pond_distance < _terrain.pond_radius + 0.5:
		return false
	# Skip steep slopes: compare heights a metre apart.
	var dx := _terrain.height_at(spot.x + 1.0, spot.z) - spot.y
	var dz := _terrain.height_at(spot.x, spot.z + 1.0) - spot.y
	return Vector2(dx, dz).length() < max_slope


func _too_close(parent: Node3D, spot: Vector3, distance: float) -> bool:
	for child in parent.get_children():
		if (child as Node3D).position.distance_to(spot) < distance:
			return true
	return false
