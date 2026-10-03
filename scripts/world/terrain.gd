@tool
class_name Terrain
extends StaticBody3D
## Procedural meadow terrain: gentle hills, a ring of taller hills around
## the edge (a natural border), a flat spawn area and a pond.
##
## Everything comes from one function, height_at(x, z), so the visible mesh,
## the collision shape, the pond water and anything placed on the ground
## (see nature_scatter.gd) always agree. Same seed = same world.
##
## Runs in the editor too (@tool), so the terrain is visible while editing.
## Generated nodes are not saved into the scene; they rebuild on load.
## Changing an export in the editor rebuilds the terrain (once per frame, even
## during a slider drag) and emits `rebuilt`, so the nature on top regenerates
## and never floats or sinks.

## Emitted after the terrain has been rebuilt because an export changed.
signal rebuilt

@export var world_seed: int = 7:
	set(value):
		world_seed = value
		_rebuild()
## Width and depth of the terrain in metres (square, centred on the origin).
@export var size: int = 240:
	set(value):
		size = value
		_rebuild()
## Height of the rolling meadow hills.
@export var hill_height: float = 1.6:
	set(value):
		hill_height = value
		_rebuild()
## Height of the hill ring around the edge.
@export var rim_height: float = 14.0:
	set(value):
		rim_height = value
		_rebuild()
## Where the rim starts rising, as a fraction of the distance to the edge.
@export_range(0.3, 0.95) var rim_start: float = 0.65:
	set(value):
		rim_start = value
		_rebuild()
## Radius of the flat area around the spawn point.
@export var spawn_flat_radius: float = 9.0:
	set(value):
		spawn_flat_radius = value
		_rebuild()
## Centre of the village (the plaza). The village node places itself here.
@export var village_center: Vector2 = Vector2(-20, 14):
	set(value):
		village_center = value
		_rebuild()
## Inside this radius the ground is perfectly flat (height 0) so buildings sit true.
@export var village_flat_radius: float = 14.0:
	set(value):
		village_flat_radius = value
		_rebuild()
## Over this many metres beyond the flat radius the ground blends back into the hills.
@export var village_blend: float = 8.0:
	set(value):
		village_blend = value
		_rebuild()
## The cobbled plaza at the village centre.
@export var plaza_radius: float = 4.5:
	set(value):
		plaza_radius = value
		_rebuild()
## Dirt paths, each a polyline of world (x, z) points. Paths are coloured into the
## ground (not flattened) and kept clear of trees and rocks.
@export var path_lines: Array[PackedVector2Array] = []:
	set(value):
		path_lines = value
		_rebuild()
@export var pond_center: Vector2 = Vector2(16, -12):
	set(value):
		pond_center = value
		_rebuild()
@export var pond_radius: float = 8.0:
	set(value):
		pond_radius = value
		_rebuild()
@export var pond_depth: float = 2.2:
	set(value):
		pond_depth = value
		_rebuild()
## World-space height of the pond's water surface.
@export var water_level: float = -0.6:
	set(value):
		water_level = value
		_rebuild()

const GRASS_LOW := Color(0.40, 0.62, 0.27)
const GRASS_HIGH := Color(0.55, 0.70, 0.30)
const DIRT := Color(0.52, 0.42, 0.30)
const SAND := Color(0.80, 0.74, 0.55)
const COBBLE := Color(0.72, 0.70, 0.66)
const PATH_DIRT := Color(0.63, 0.51, 0.37)

var _rebuild_queued := false
var _noise: FastNoiseLite
var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _water: MeshInstance3D


func _ready() -> void:
	_build()


## Ground height at a world position (x, z). Pure and deterministic.
func height_at(x: float, z: float) -> float:
	if _noise == null or _noise.seed != world_seed:
		_setup_noise()
	var half := size * 0.5
	var edge := clampf(Vector2(x, z).length() / half, 0.0, 1.5)

	# Rolling hills, faded out near the spawn point so it stays flat.
	var spawn_fade := smoothstep(spawn_flat_radius * 0.5, spawn_flat_radius, Vector2(x, z).length())
	var h := _noise.get_noise_2d(x, z) * hill_height * spawn_fade

	# Hill ring around the edge.
	h += smoothstep(rim_start, 1.0, edge) * rim_height

	# Pond: a smooth bowl, with the hills flattened around it.
	var pond_t := 1.0 - smoothstep(0.0, pond_radius, Vector2(x, z).distance_to(pond_center))
	h = lerpf(h, -pond_depth, pond_t * pond_t * (3.0 - 2.0 * pond_t))

	# Village: perfectly flat inside the flat radius, blending out into the hills.
	var village_t := 1.0 - smoothstep(village_flat_radius, village_flat_radius + village_blend,
			Vector2(x, z).distance_to(village_center))
	h = lerpf(h, 0.0, village_t)
	return h


## Distance (m) from (x, z) to the nearest path line, or 1e9 if there are none.
func path_distance(x: float, z: float) -> float:
	var best := 1e9
	var p := Vector2(x, z)
	for line in path_lines:
		for i in range(line.size() - 1):
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best


## True if (x, z) is inside the village's flat zone grown by `margin` metres.
func in_village(x: float, z: float, margin: float = 0.0) -> bool:
	return Vector2(x, z).distance_to(village_center) < village_flat_radius + margin


## The ground colour at a world position (grass, sand, mud), for tests and
## anything that wants to match the ground.
func ground_color_at(x: float, z: float) -> Color:
	return _ground_color(x, z, height_at(x, z))


## Half the side length: positions with |x| or |z| above this are off the terrain.
func half_size() -> float:
	return size * 0.5


func _setup_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.035
	_noise.fractal_octaves = 3


func _rebuild() -> void:
	# Many setters can fire in one frame (a slider drag): rebuild once.
	if is_node_ready() and not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_now.call_deferred()


func _rebuild_now() -> void:
	_rebuild_queued = false
	_build()
	rebuilt.emit()


func _build() -> void:
	_setup_noise()
	var half := size * 0.5
	var verts := size + 1  # one vertex per metre

	# Heights on a 1 m grid, shared by the mesh and the collision shape.
	var heights := PackedFloat32Array()
	heights.resize(verts * verts)
	for zi in verts:
		for xi in verts:
			heights[zi * verts + xi] = height_at(xi - half, zi - half)

	_build_mesh(heights, verts, half)
	_build_collision(heights, verts)
	_build_water()


func _build_mesh(heights: PackedFloat32Array, verts: int, half: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in verts:
		for xi in verts:
			var h := heights[zi * verts + xi]
			st.set_color(_ground_color(xi - half, zi - half, h))
			st.set_uv(Vector2(xi, zi) / float(verts - 1))
			st.add_vertex(Vector3(xi - half, h, zi - half))
	for zi in verts - 1:
		for xi in verts - 1:
			var a := zi * verts + xi
			var b := a + 1
			var c := a + verts
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)
	st.generate_normals()

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	# Our colours are picked in sRGB; without this they render washed out.
	material.vertex_color_is_srgb = true
	material.roughness = 0.95

	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "TerrainMesh"
		add_child(_mesh_instance)
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = material


func _build_collision(heights: PackedFloat32Array, verts: int) -> void:
	# HeightMapShape3D is centred on its node with 1 m between samples,
	# which matches the mesh grid exactly.
	var shape := HeightMapShape3D.new()
	shape.map_width = verts
	shape.map_depth = verts
	shape.map_data = heights
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "TerrainCollision"
		add_child(_collision)
	_collision.shape = shape


func _build_water() -> void:
	# A round disc, slightly wider than the bowl: a square plane's corners
	# would poke out of the meadow wherever the ground dips below the water.
	var disc := CylinderMesh.new()
	disc.top_radius = pond_radius + 0.5
	disc.bottom_radius = pond_radius + 0.5
	disc.height = 0.02
	disc.radial_segments = 48
	disc.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.30, 0.55, 0.70, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic = 0.2
	if _water == null:
		_water = MeshInstance3D.new()
		_water.name = "PondWater"
		_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_water)
	_water.mesh = disc
	_water.material_override = material
	_water.position = Vector3(pond_center.x, water_level, pond_center.y)


func _ground_color(x: float, z: float, h: float) -> Color:
	# Lighter grass higher up, with a little noise so it isn't flat colour.
	var t := clampf(h / maxf(rim_height, 0.01), 0.0, 1.0)
	var variation := _noise.get_noise_2d(x * 3.1, z * 3.1) * 0.08
	var color := GRASS_LOW.lerp(GRASS_HIGH, t).lightened(variation)

	# Sand and mud only around the pond (dips elsewhere in the meadow stay
	# grass), blended with smooth gradients so the shoreline has no hard edge.
	var shore := Vector2(x, z).distance_to(pond_center)
	var near_pond := 1.0 - smoothstep(pond_radius, pond_radius + 2.5, shore)
	var sand := (1.0 - smoothstep(water_level + 0.1, water_level + 1.0, h)) * near_pond
	var mud := (1.0 - smoothstep(water_level - 1.2, water_level + 0.1, h)) * near_pond
	color = color.lerp(SAND, sand)
	color = color.lerp(DIRT, mud * 0.6)

	# Cobbled plaza and dirt paths, with soft edges.
	var plaza := 1.0 - smoothstep(plaza_radius - 0.6, plaza_radius + 0.2, Vector2(x, z).distance_to(village_center))
	color = color.lerp(COBBLE.lightened(variation * 0.5), plaza)
	var path := 1.0 - smoothstep(1.1, 1.9, path_distance(x, z))
	return color.lerp(PATH_DIRT.lightened(variation), path * 0.9)
