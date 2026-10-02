@tool
class_name Village
extends Node3D
## The small village: three cottages around a plaza with a well, lamp posts,
## benches, a notice board and a bit of fence.
##
## Everything is placed relative to `Terrain.village_center`, on the flat
## village ground (y = 0). Houses face the plaza. The dirt paths that link the
## doors to the plaza and the plaza to the spawn are drawn by the terrain from
## `Terrain.path_lines` (set in world.tscn), so changing a house position here
## means updating those lines too (tests/functional/test_village.gd checks it).
##
## Runs in the editor too. Generated nodes are not saved into the scene.

@export var terrain_path: NodePath = ^"../Terrain"

## [offset from the village centre (x, z), yaw in degrees, wall, roof]
## Yaw turns the door: 0 faces +Z, 90 faces +X, -90 faces -X.
const HOUSES := [
	[Vector2(-9, -2), 90.0, Color(0.96, 0.89, 0.76), Color(0.78, 0.38, 0.30)],
	[Vector2(9, -1), -90.0, Color(0.88, 0.93, 0.85), Color(0.35, 0.50, 0.62)],
	[Vector2(0, -10), 0.0, Color(0.95, 0.86, 0.80), Color(0.55, 0.35, 0.28)],
]

var _terrain: Terrain
var _generated: Node3D
var houses: Array[House] = []
var props: Array[Node3D] = []


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain
	if _terrain == null:
		push_warning("Village: no Terrain at %s" % terrain_path)
		return
	_build()


## World position of the village centre (the plaza middle) on the ground.
func center() -> Vector3:
	return Vector3(_terrain.village_center.x, 0.0, _terrain.village_center.y)


func _build() -> void:
	if _generated:
		remove_child(_generated)
		_generated.queue_free()
	houses.clear()
	props.clear()
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)

	for entry in HOUSES:
		var house := House.new()
		house.name = "House%d" % (houses.size() + 1)
		house.wall_color = entry[2]
		house.roof_color = entry[3]
		house.rotation_degrees.y = entry[1]
		house.position = _at(entry[0])
		_generated.add_child(house)
		houses.append(house)

	_place(VillageProps.well(), Vector2(0, 0), 0.0)
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			_place(VillageProps.lamp_post(), Vector2(sign_x * 3.9, sign_z * 3.9), 0.0)
	_place(VillageProps.bench(), Vector2(0, 6), 180.0)
	_place(VillageProps.bench(), Vector2(-6, 5), 90.0)
	_place(VillageProps.notice_board(), Vector2(3.2, -6.5), 0.0)
	for x in [4.0, 6.0, 8.0]:
		_place(VillageProps.fence(), Vector2(x, 9), 0.0)


func _at(offset: Vector2) -> Vector3:
	return center() + Vector3(offset.x, 0.0, offset.y)


func _place(prop: Node3D, offset: Vector2, yaw_degrees: float) -> void:
	prop.set_meta("kind", String(prop.name))  # Godot renames duplicate siblings; tests count by this
	prop.position = _at(offset)
	prop.rotation_degrees.y = yaw_degrees
	_generated.add_child(prop)
	props.append(prop)
