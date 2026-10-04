@tool
class_name Village
extends Node3D
## The village: three cottages around a plaza with a well, lamp posts, benches,
## a notice board and a bit of fence, and a ring of five more cottages about 24 m out
## and three more 36 m out, each with its own dirt path to the plaza, a lamp post and a bench.
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
	[Vector2(20.8, 12.0), -120.0, Color(0.97, 0.92, 0.72), Color(0.30, 0.55, 0.55)],
	[Vector2(6.2, 23.2), -165.0, Color(0.96, 0.84, 0.84), Color(0.50, 0.32, 0.26)],
	[Vector2(-12.0, 20.8), 150.0, Color(0.85, 0.93, 0.82), Color(0.82, 0.45, 0.25)],
	[Vector2(-22.6, 8.2), 109.9, Color(0.95, 0.93, 0.88), Color(0.28, 0.34, 0.55)],
	[Vector2(-15.4, -18.4), 39.9, Color(0.90, 0.86, 0.95), Color(0.55, 0.25, 0.32)],
	[Vector2(22.2, 28.4), -142.0, Color(0.98, 0.90, 0.78), Color(0.62, 0.30, 0.30)],
	[Vector2(-5.0, 35.6), 172.0, Color(0.86, 0.92, 0.95), Color(0.30, 0.42, 0.58)],
	[Vector2(-27.6, 23.1), 129.9, Color(0.93, 0.95, 0.84), Color(0.45, 0.52, 0.28)],
]

## The first CORE_HOUSES entries stand right at the plaza (their props are placed by hand below); the next five
## form the ring 24 m out and the last three an outer ring 36 m out (bearings 52, 98 and 140 degrees: the windows whose
## straight path to the plaza clears every other cottage; a fourth, at 310 degrees, was dropped because its path ran
## along the spawn path for 12 m). Each ring cottage's lamp
## post and bench are placed from its door.
const CORE_HOUSES := 3

## Where the shared screen stands, relative to the plaza (the open north side), facing the plaza.
const SCREEN_OFFSET := Vector2(6, -24)

var _terrain: Terrain
var _generated: Node3D
var houses: Array[House] = []
## The big screen on the north side (not in `props`: it is a place, with its own tests).
var screen: SharedScreen
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
	screen = null
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
	_place(VillageProps.clock_post(), Vector2(4.6, 2.6), -119.5)  # faces the well
	_place(VillageProps.bench(), Vector2(0, 6), 180.0)
	_place(VillageProps.bench(), Vector2(-6, 5), 90.0)
	var board := _place(VillageProps.notice_board(), Vector2(3.2, -6.5), 0.0)
	var reader := Interactable.new()
	reader.name = "ReadBoard"
	reader.prompt_text = "Read the notice board"
	reader.message = "Welcome to Hearthwild!\nDoors open with E. More coming: animals, outfits, night time..."
	reader.position = Vector3(0, 0.9, 0.7)
	board.add_child(reader)
	for x in [4.0, 6.0, 8.0]:
		_place(VillageProps.fence(), Vector2(x, 9), 0.0)

	# Last: the ring's props look for free spots among everything placed above.
	for ring_house in houses.slice(CORE_HOUSES):
		_place_ring_props(ring_house)

	screen = SharedScreen.new()
	screen.name = "SharedScreen"
	screen.position = _at(SCREEN_OFFSET)
	_generated.add_child(screen)


## A lamp post and a bench beside the dirt path from this cottage's door to the plaza. Each takes the first
## free spot found walking along the path (clear of every house and prop), so the ring never collides with the
## core props or a neighbour.
func _place_ring_props(house: House) -> void:
	var door := house.door_outside(0.9)
	var toward := center() - door
	toward.y = 0.0
	var length := toward.length()
	var along := toward / length
	var side := Vector3(-along.z, 0.0, along.x)
	var lamp_at := _free_spot(door, along, side, length, [0.55, 0.5, 0.6, 0.45, 0.65, 0.4], [2.0, 1.4, -2.0, -1.4])
	var bench_at := _free_spot(door, along, side, length, [0.3, 0.35, 0.25, 0.4, 0.2], [-2.2, -2.8, 2.2, 2.8])
	if lamp_at != Vector3.INF:
		_place(VillageProps.lamp_post(), Vector2(lamp_at.x, lamp_at.z) - _terrain.village_center, 0.0)
	else:
		push_warning("Village: no free spot for the lamp post of %s" % house.name)
	if bench_at != Vector3.INF:
		_place(VillageProps.bench(), Vector2(bench_at.x, bench_at.z) - _terrain.village_center, house.rotation_degrees.y)
	else:
		push_warning("Village: no free spot for the bench of %s" % house.name)


## First point `fraction` of the way from `door` to the plaza (then `offset` to the side) that is at least 3.2 m
## from every house footprint and 3.2 m from every placed prop (the village test needs 3 m of clear air in front of a prop); Vector3.INF if none.
func _free_spot(door: Vector3, along: Vector3, side: Vector3, length: float, fractions: Array, offsets: Array) -> Vector3:
	for fraction in fractions:
		for offset in offsets:
			var point: Vector3 = door + along * length * fraction + side * offset
			var free := true
			for house in houses:
				var local := house.to_local(point)
				if absf(local.x) < House.WIDTH * 0.5 + 3.2 and absf(local.z) < House.DEPTH * 0.5 + 3.2:
					free = false
					break
			if free:
				for prop in props:
					if prop.global_position.distance_to(point) < 3.2:
						free = false
						break
			if free:
				return point
	return Vector3.INF


func _at(offset: Vector2) -> Vector3:
	return center() + Vector3(offset.x, 0.0, offset.y)


func _place(prop: Node3D, offset: Vector2, yaw_degrees: float) -> Node3D:
	prop.set_meta("kind", String(prop.name))  # Godot renames duplicate siblings; tests count by this
	prop.position = _at(offset)
	prop.rotation_degrees.y = yaw_degrees
	_generated.add_child(prop)
	props.append(prop)
	return prop
