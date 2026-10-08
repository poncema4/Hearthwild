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
	[Vector2(46.0, 9.8), -63.3, Color(0.97, 0.90, 0.80), Color(0.62, 0.34, 0.30)],
	[Vector2(46.9, -3.3), -71.1, Color(0.88, 0.94, 0.86), Color(0.32, 0.46, 0.58)],
	[Vector2(-39.9, -24.9), 36.5, Color(0.93, 0.95, 0.84), Color(0.40, 0.52, 0.30)],
	[Vector2(-46.5, -6.5), 42.4, Color(0.96, 0.92, 0.78), Color(0.30, 0.50, 0.52)],
	[Vector2(-46.7, 4.9), 58.8, Color(0.90, 0.88, 0.96), Color(0.55, 0.32, 0.28)],
	[Vector2(0.0, 62.0), 156.0, Color(0.97, 0.90, 0.80), Color(0.62, 0.34, 0.30)],
	[Vector2(16.0, 59.9), -113.8, Color(0.88, 0.94, 0.86), Color(0.32, 0.46, 0.58)],
	[Vector2(31.0, 53.7), -114.3, Color(0.95, 0.88, 0.90), Color(0.50, 0.30, 0.40)],
	[Vector2(43.8, 43.8), -74.1, Color(0.93, 0.95, 0.84), Color(0.40, 0.52, 0.30)],
	[Vector2(53.7, 31.0), -142.7, Color(0.96, 0.92, 0.78), Color(0.30, 0.50, 0.52)],
	[Vector2(59.9, 16.0), -55.0, Color(0.90, 0.88, 0.96), Color(0.55, 0.32, 0.28)],
	[Vector2(62.0, 0.0), -39.4, Color(0.98, 0.93, 0.85), Color(0.45, 0.35, 0.55)],
	[Vector2(59.9, -16.0), -14.9, Color(0.86, 0.92, 0.95), Color(0.62, 0.40, 0.22)],
	[Vector2(53.7, -31.0), 2.0, Color(0.97, 0.90, 0.80), Color(0.62, 0.34, 0.30)],
	[Vector2(43.8, -43.8), 17.5, Color(0.88, 0.94, 0.86), Color(0.32, 0.46, 0.58)],
	[Vector2(31.0, -53.7), 32.2, Color(0.95, 0.88, 0.90), Color(0.50, 0.30, 0.40)],
	[Vector2(16.0, -59.9), 47.0, Color(0.93, 0.95, 0.84), Color(0.40, 0.52, 0.30)],
	[Vector2(0.0, -62.0), 61.7, Color(0.96, 0.92, 0.78), Color(0.30, 0.50, 0.52)],
	[Vector2(-16.0, -59.9), 76.5, Color(0.90, 0.88, 0.96), Color(0.55, 0.32, 0.28)],
	[Vector2(-31.0, -53.7), 92.4, Color(0.98, 0.93, 0.85), Color(0.45, 0.35, 0.55)],
	[Vector2(-43.8, -43.8), 107.6, Color(0.86, 0.92, 0.95), Color(0.62, 0.40, 0.22)],
	[Vector2(-53.7, -31.0), 122.2, Color(0.97, 0.90, 0.80), Color(0.62, 0.34, 0.30)],
	[Vector2(-59.9, -16.0), 96.1, Color(0.88, 0.94, 0.86), Color(0.32, 0.46, 0.58)],
	[Vector2(-62.0, -0.0), 149.9, Color(0.95, 0.88, 0.90), Color(0.50, 0.30, 0.40)],
	[Vector2(-59.9, 16.0), 108.6, Color(0.93, 0.95, 0.84), Color(0.40, 0.52, 0.30)],
	[Vector2(-53.7, 31.0), -177.1, Color(0.96, 0.92, 0.78), Color(0.30, 0.50, 0.52)],
	[Vector2(-43.8, 43.8), -162.5, Color(0.90, 0.88, 0.96), Color(0.55, 0.32, 0.28)],
	[Vector2(-31.0, 53.7), 88.9, Color(0.98, 0.93, 0.85), Color(0.45, 0.35, 0.55)],
	[Vector2(-16.0, 59.9), 146.3, Color(0.86, 0.92, 0.95), Color(0.62, 0.40, 0.22)],
	[Vector2(9.3, 75.4), 176.9, Color(0.97, 0.90, 0.80), Color(0.62, 0.34, 0.30)],
	[Vector2(59.9, 46.8), -140.7, Color(0.88, 0.94, 0.86), Color(0.32, 0.46, 0.58)],
	[Vector2(75.4, -9.3), -91.3, Color(0.95, 0.88, 0.90), Color(0.50, 0.30, 0.40)],
	[Vector2(46.8, -59.9), -51.4, Color(0.93, 0.95, 0.84), Color(0.40, 0.52, 0.30)],
	[Vector2(-9.3, -75.4), -6.0, Color(0.96, 0.92, 0.78), Color(0.30, 0.50, 0.52)],
	[Vector2(-59.9, -46.8), 38.6, Color(0.90, 0.88, 0.96), Color(0.55, 0.32, 0.28)],
	[Vector2(-75.4, 9.3), 86.4, Color(0.98, 0.93, 0.85), Color(0.45, 0.35, 0.55)],
]

## Every cottage as [position (world x, z), yaw degrees] for a village centred at `center`. Static so that anything that must know where the houses
## stand BEFORE the Village node has built them (the grass, which has to leave room for walls and doorsteps) can ask.
static func house_footprints(center: Vector2) -> Array:
	var out: Array = []
	for entry in HOUSES:
		out.append([center + (entry[0] as Vector2), entry[1]])
	return out


## The first CORE_HOUSES entries stand right at the plaza (their props are placed by hand below); the next five
## form the ring 24 m out, the next three an outer ring 36 m out the next five a far ring 47 m out and the last 31 two more rings 62 m and 76 m out (their paths BRANCH off an existing path instead of running straight to the plaza: the inner rings leave no clear straight corridor) (bearings 52, 98 and 140 degrees: the windows whose
## straight path to the plaza clears every other cottage; a fourth, at 310 degrees, was dropped because its path ran
## along the spawn path for 12 m). Each ring cottage's lamp
## post and bench are placed from its door.
const CORE_HOUSES := 3
## Cottages before this index get a bench as well as a lamp post (the outer rings get a lamp only).
const BENCHES_UNTIL := 16
## Cottages from this index outward (the 36 m and 47 m rings) have a fenced back yard.
const YARD_FROM := 8
const YARD_TO := 16  ## only the 36 m and 47 m rings get fenced yards (the outer rings are bigger and cheaper without them)
## The perimeter fence round the village, with a gate in the middle of each side (north, east, south, west).
const FENCE_RADIUS := 88.0
const GATE_BEARINGS := [0.0, 90.0, 180.0, 270.0]
const CULL_DISTANCE := 90.0  ## village meshes fade out beyond this (smoothness: a big village must not cost the same from everywhere)

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

	_place_well()
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			_place(VillageProps.lamp_post(), Vector2(sign_x * 3.9, sign_z * 3.9), 0.0)
	_place_clock()
	_place(VillageProps.bench(), Vector2(0, 6), 180.0)
	_place(VillageProps.bench(), Vector2(-6, 5), 90.0)
	var board := _place(VillageProps.notice_board(), Vector2(3.2, -6.5), 0.0)
	var reader := Interactable.new()
	reader.name = "ReadBoard"
	reader.prompt_text = "Read the notice board"
	reader.message = "Welcome to Hearthwild!\nDoors open with E. More coming: animals, outfits, night time..."
	reader.position = Vector3(0, 0.9, 0.7)
	board.add_child(reader)

	# Last: the ring's props look for free spots among everything placed above.
	for ring_house in houses.slice(CORE_HOUSES):
		_place_ring_props(ring_house, houses.find(ring_house) < BENCHES_UNTIL)

	_place_market()
	_place_weapon_rack()
	for house in houses.slice(YARD_FROM, YARD_TO):
		_place_yard(house)
	for house in houses:
		_place_garage(house)
	_place_perimeter()

	screen = SharedScreen.new()
	screen.name = "SharedScreen"
	screen.position = _at(SCREEN_OFFSET)
	_generated.add_child(screen)
	_cull_far()  # last: it must see every mesh (the shared screen is added after everything else)


## A lamp post and a bench beside the dirt path from this cottage's door to the plaza. Each takes the first
## free spot found walking along the path (clear of every house and prop), so the ring never collides with the
## core props or a neighbour.
func _place_ring_props(house: House, with_bench := true) -> void:
	var door := house.door_outside(0.9)
	var toward := center() - door
	# A cottage whose path BRANCHES off another leaves its door along its own first segment, not straight at the plaza: place the props along that.
	for line in _terrain.path_lines:
		if line.size() >= 2 and Vector2(door.x, door.z).distance_to(line[0]) < 0.3:
			toward = Vector3(line[1].x - door.x, 0.0, line[1].y - door.z)
			break
	toward.y = 0.0
	var length := minf(toward.length(), 24.0)
	var along := toward.normalized()
	var side := Vector3(-along.z, 0.0, along.x)
	var lamp_at := _free_spot(door, along, side, length, [0.55, 0.5, 0.6, 0.45, 0.65, 0.4, 0.75, 0.3, 0.85, 0.2, 0.92], [2.0, 1.4, -2.0, -1.4, 2.6, -2.6, 3.2, -3.2])
	var bench_at := Vector3.INF if not with_bench else _free_spot(door, along, side, length, [0.3, 0.35, 0.25, 0.4, 0.2, 0.7, 0.8, 0.15], [-2.2, -2.8, 2.2, 2.8, -3.4, 3.4])
	if lamp_at != Vector3.INF:
		_place(VillageProps.lamp_post(), Vector2(lamp_at.x, lamp_at.z) - _terrain.village_center, 0.0)
	else:
		push_warning("Village: no free spot for the lamp post of %s" % house.name)
	if not with_bench:
		pass
	elif bench_at != Vector3.INF:
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
			if free and _terrain.path_distance(point.x, point.z) < PROP_PATH_CLEAR:
				free = false
			if free:
				for prop in props:
					if prop.global_position.distance_to(point) < 3.2:
						free = false
						break
			if free:
				return point
	return Vector3.INF


## The middle of the plaza, where players appear when they join (nothing solid stands there: the well is off to one side).
func spawn_point() -> Vector3:
	return center() + Vector3.UP * 0.1


## The well stands on the plaza but NOT in the middle (Marco: the player spawns in the middle): the first spot, trying the plaza's corners, that is clear of the dirt
## paths and of the lamp posts and benches placed by hand below.
func _place_well() -> void:
	for spot in [Vector2(5.4, -3.0), Vector2(-5.4, -3.0), Vector2(5.8, 3.4), Vector2(-5.8, 3.4), Vector2(0, -5.6), Vector2(6.4, 0)]:
		var world := _at(spot)
		if _terrain.path_distance(world.x, world.z) >= 2.4:
			_place(VillageProps.well(), spot, 0.0)
			return
	_place(VillageProps.well(), Vector2(5.4, -3.0), 0.0)


## The plaza clock faces the well from the first spot (searching outward from its first choice) that is off every dirt path.
func _place_clock() -> void:
	for spot in [Vector2(4.6, 2.6), Vector2(4.8, 1.0), Vector2(2.2, 4.8), Vector2(-4.8, -1.0), Vector2(4.6, -3.0), Vector2(-3.0, 4.6)]:
		var world := _at(spot)
		if _terrain.path_distance(world.x, world.z) >= PROP_PATH_CLEAR:
			_place(VillageProps.clock_post(), spot, rad_to_deg(atan2(spot.x, spot.y)) + 180.0)  # faces the well
			return
	_place(VillageProps.clock_post(), Vector2(4.6, 2.6), -119.5)


## A row of market stalls beside the plaza, on the first open ground found walking out along a few bearings (clear of cottages, props and
## paths), all facing the plaza.
func _place_market() -> void:
	var colors := [Color(0.85, 0.35, 0.30), Color(0.35, 0.60, 0.80), Color(0.90, 0.70, 0.25)]
	var placed := 0
	for bearing: float in [100.0, 130.0, 160.0, 70.0, 40.0, 190.0, 220.0, 250.0, 10.0, 340.0, 310.0, 280.0]:
		if placed >= colors.size():
			break
		for radius: float in [13.0, 14.5, 16.0, 18.0, 20.0, 23.0, 26.0, 30.0]:
			var rad := deg_to_rad(bearing)
			var spot: Vector3 = center() + Vector3(sin(rad), 0.0, cos(rad)) * radius
			if _is_clear(spot, 3.4, 2.2):
				var stall := VillageProps.market_stall(colors[placed])
				var toward: Vector3 = center() - spot
				_place(stall, Vector2(spot.x, spot.z) - _terrain.village_center, rad_to_deg(atan2(toward.x, toward.z)) + 180.0)
				placed += 1
				break


## The weapon rack where the market meets the plaza: E takes the weapons (the combat system hands them over).
func _place_weapon_rack() -> void:
	for radius: float in [10.5, 12.0, 13.5, 9.0]:
		for bearing: float in [20.0, 340.0, 60.0, 300.0, 0.0, 90.0, 270.0, 160.0, 200.0]:
			var rad := deg_to_rad(bearing)
			var spot: Vector3 = center() + Vector3(sin(rad), 0.0, cos(rad)) * radius
			if not _is_clear(spot, 3.2, 2.4):
				continue
			var rack := _place(VillageProps.weapon_rack(), Vector2(spot.x, spot.z) - _terrain.village_center, rad_to_deg(rad) + 180.0)
			rack.add_to_group(&"weapon_rack")
			var pick := Interactable.new()
			pick.name = "TakeWeapons"
			pick.prompt_text = "Take the weapons"
			pick.message = "You took the stone sword, the spear, the axe and a pistol. Keys 1 to 5 equip them; left click or F attacks."
			pick.position = Vector3(0, 0.9, 0.8)
			pick.interacted.connect(func(who: Node3D) -> void: _hand_over_weapons(who))
			rack.add_child(pick)
			return
	push_warning("Village: no free spot for the weapon rack")


func _hand_over_weapons(who: Node3D) -> void:
	var arsenal := who.get_node_or_null("Arsenal") as Arsenal
	if arsenal != null:
		arsenal.unlock_all()


## A back yard fenced on three sides (behind the cottage, never in front of the door) with a gate in the middle of the back side. A fence
## segment never stands within FENCE_PATH_CLEAR of a dirt path or in front of anything: where it would, the segment is simply left out (a gap).
func _place_yard(house: House) -> void:
	var half_width := 4.6
	var near := -House.DEPTH * 0.5 - 0.4
	var far := -House.DEPTH * 0.5 - 6.0
	var corners := [Vector3(-half_width, 0, near), Vector3(-half_width, 0, far), Vector3(half_width, 0, far), Vector3(half_width, 0, near)]
	for i in 3:
		_fence_run(house, corners[i], corners[i + 1], i == 1)


func _fence_run(house: House, from_local: Vector3, to_local: Vector3, with_gate: bool) -> void:
	var length := from_local.distance_to(to_local)
	var count := maxi(int(round(length / 2.0)), 1)
	var gate_index := count / 2 if with_gate else -1
	for k in count:
		var centre_local := from_local.lerp(to_local, (k + 0.5) / count)
		var world := house.to_global(centre_local)
		if not _is_clear(world, 1.3, FENCE_PATH_CLEAR, true):
			continue
		var along := to_local - from_local
		var yaw := house.rotation_degrees.y + rad_to_deg(atan2(-along.z, along.x))
		var piece := VillageProps.gate() if k == gate_index else VillageProps.fence()
		_place(piece, Vector2(world.x, world.z) - _terrain.village_center, yaw)


const FENCE_PATH_CLEAR := 1.8
## A lamp post or bench keeps this far from the middle of any dirt path (the path is about 2.4 m wide).
const PROP_PATH_CLEAR := 1.6

## True when `point` is at least `radius` from every house footprint and prop (fences ignore other fences) and `path_margin` from every path.
func _is_clear(point: Vector3, radius: float, path_margin: float, allow_fences := false) -> bool:
	if _terrain.path_distance(point.x, point.z) < path_margin:
		return false
	for house in houses:
		var local := house.to_local(point)
		if absf(local.x) < House.WIDTH * 0.5 + radius * 0.5 and absf(local.z) < House.DEPTH * 0.5 + radius * 0.5:
			return false
	for prop in props:
		if allow_fences and (prop.get_meta("kind", "") == "Fence" or prop.get_meta("kind", "") == "Gate"):
			continue
		if prop.global_position.distance_to(point) < radius:
			return false
	return true


func _at(offset: Vector2) -> Vector3:
	return center() + Vector3(offset.x, 0.0, offset.y)


func _place(prop: Node3D, offset: Vector2, yaw_degrees: float) -> Node3D:
	prop.set_meta("kind", String(prop.name))  # Godot renames duplicate siblings; tests count by this
	prop.position = _at(offset)
	prop.position.y = _terrain.height_at(prop.position.x, prop.position.z)
	prop.rotation_degrees.y = yaw_degrees
	_generated.add_child(prop)
	props.append(prop)
	return prop


## A garage beside every cottage, on the first spot with room: right, left, twice as far right and left, then behind it (turned round so it opens away from
## the cottage). A spot must be clear of cottages, props and paths; if none is, the clearances are relaxed once.
func _place_garage(house: House) -> void:
	var half := House.WIDTH * 0.5 + VillageProps.GARAGE_WIDTH * 0.5 + 0.9
	var back := -(House.DEPTH * 0.5 + VillageProps.GARAGE_DEPTH * 0.5 + 0.9)
	var candidates := [[half, 0.2, 0.0], [-half, 0.2, 0.0], [half + 4.6, 0.2, 0.0], [-half - 4.6, 0.2, 0.0], [0.0, back, 180.0], [half, back, 180.0], [-half, back, 180.0]]
	for clearances: Array in [[3.0, 2.6], [2.4, 1.9]]:
		for candidate: Array in candidates:
			var spot := house.to_global(Vector3(candidate[0], 0.0, candidate[1]))
			var from_centre := Vector2(spot.x, spot.z).distance_to(Vector2(center().x, center().z))
			if _is_clear(spot, clearances[0], clearances[1]) and from_centre < FENCE_RADIUS - 4.0:
				var garage := VillageProps.garage()
				garage.set_meta("house", house.name)
				var placed := _place(garage, Vector2(spot.x, spot.z) - _terrain.village_center, house.rotation_degrees.y + candidate[2])
				placed.add_to_group(&"garage")
				return
	# The plaza cottages are hemmed in by paths and props: their garage goes on the nearest open ground within 14 m.
	for radius: float in [8.0, 10.0, 12.0, 14.0]:
		for bearing: float in [0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0]:
			var rad := deg_to_rad(bearing)
			var spot: Vector3 = house.global_position + Vector3(sin(rad), 0.0, cos(rad)) * radius
			var from_centre := Vector2(spot.x, spot.z).distance_to(Vector2(center().x, center().z))
			if from_centre > 7.5 and _is_clear(spot, 2.6, 2.0) and from_centre < FENCE_RADIUS - 4.0:
				var garage := VillageProps.garage()
				garage.set_meta("house", house.name)
				var placed := _place(garage, Vector2(spot.x, spot.z) - _terrain.village_center, house.rotation_degrees.y)
				placed.add_to_group(&"garage")
				return
	push_warning("Village: no room for a garage beside %s" % house.name)


## The perimeter fence: a ring of 2.2 m pieces at FENCE_RADIUS drawn as two MultiMeshes (posts and rails) with one collision box per piece, and a gate gap at
## each of GATE_BEARINGS (the gate prop stands in the gap). Cheap to draw however long it is.
func _place_perimeter() -> void:
	var circumference := TAU * FENCE_RADIUS
	var pieces := int(circumference / 2.2)
	var step := TAU / pieces
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 1.1, 0.14)
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(0.07, 0.09, 2.3)
	var material := VillageProps._material(VillageProps.WOOD)
	var body := StaticBody3D.new()
	body.name = "PerimeterBody"
	body.add_to_group(&"perimeter_fence")
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	for i in pieces:
		var angle := (i + 0.5) * step
		var near_gate := false
		for gate_bearing: float in GATE_BEARINGS:
			if absf(angle_difference(angle, deg_to_rad(gate_bearing))) * FENCE_RADIUS < 2.2:
				near_gate = true
		if near_gate:
			continue
		var radial := Vector3(sin(angle), 0.0, cos(angle))
		var origin := center() + radial * FENCE_RADIUS
		origin.y = 0.0
		var basis := Basis(Vector3.UP, atan2(-cos(angle), sin(angle)))  # the piece's long axis (local Z) runs along the tangent
		posts.append(Transform3D(basis, origin + Vector3.UP * 0.55 + Vector3(cos(angle), 0, -sin(angle)) * 1.1))
		for height: float in [0.38, 0.8]:
			rails.append(Transform3D(basis, origin + Vector3.UP * height))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.2, 1.1, 2.3)
		shape.shape = box
		shape.transform = Transform3D(basis, origin + Vector3.UP * 0.55)
		body.add_child(shape)
	_generated.add_child(body)
	_instances("PerimeterPosts", post_mesh, material, posts)
	_instances("PerimeterRails", rail_mesh, material, rails)
	for gate_bearing: float in GATE_BEARINGS:
		var rad := deg_to_rad(gate_bearing)
		var gate := VillageProps.gate()
		gate.set_meta("kind", "Gate")
		gate.position = center() + Vector3(sin(rad), 0.0, cos(rad)) * FENCE_RADIUS
		gate.rotation.y = atan2(-cos(rad), sin(rad)) + PI * 0.5  # a gate's posts run along its local X; a fence piece's long side along local Z: one quarter turn more, or the gate stands sideways across the opening it should leave
		_generated.add_child(gate)
		props.append(gate)
		gate.add_to_group(&"perimeter_gate")


func _instances(node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_generated.add_child(node)


## Smoothness: every mesh of every cottage, prop and cart fades out beyond CULL_DISTANCE (a village this big must not cost the same from everywhere).
func _cull_far() -> void:
	for node in _generated.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.visibility_range_end <= 0.0:
			mesh.visibility_range_end = CULL_DISTANCE
			mesh.visibility_range_end_margin = 12.0
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
