@tool
class_name VillageProps
extends RefCounted
## Builders for the small village furniture: lamp post, bench, well, notice
## board, fence. Each returns a Node3D whose origin is on the ground, with the
## front facing local +Z, and a StaticBody3D child so the player cannot walk
## through it. Placeholder art: boxes and cylinders.

const WOOD := Color(0.52, 0.37, 0.25)
const DARK_WOOD := Color(0.36, 0.25, 0.17)
const STONE := Color(0.66, 0.64, 0.60)
const IRON := Color(0.22, 0.23, 0.26)

static var _materials := {}


static func lamp_post() -> Node3D:
	var root := Node3D.new()
	root.name = "LampPost"
	var body := _body(root)
	_cylinder(body, "Post", 0.07, 3.0, Vector3(0, 1.5, 0), IRON)
	_box(body, "Base", Vector3(0.3, 0.2, 0.3), Vector3(0, 0.1, 0), STONE)
	_box(body, "Arm", Vector3(0.5, 0.06, 0.06), Vector3(0.2, 2.95, 0), IRON)
	var lantern := _box(body, "Lantern", Vector3(0.3, 0.4, 0.3), Vector3(0.4, 2.75, 0), Color(1.0, 0.85, 0.5))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.85, 0.5)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.75, 0.35)
	glow.emission_energy_multiplier = 1.6
	lantern.material_override = glow
	_collider(body, "PostCollision", Vector3(0.3, 3.0, 0.3), Vector3(0, 1.5, 0))
	# The lantern really lights up after dark: DayNight sets the energy of every `night_light`.
	var night_light := OmniLight3D.new()
	night_light.name = "NightLight"
	night_light.position = Vector3(0.4, 2.7, 0)
	night_light.omni_range = 8.0
	night_light.light_color = Color(1.0, 0.78, 0.45)
	night_light.light_energy = 0.0
	night_light.shadow_enabled = false
	night_light.visible = false
	night_light.add_to_group(&"night_light")
	root.add_child(night_light)
	return root


## A clock post: the hands are driven by WorldClock from the game time.
static func clock_post() -> Node3D:
	var root := WorldClock.new()
	root.name = "Clock"
	var body := _body(root)
	# The post ENDS below the clock (the rim starts at y 2.03) and a bracket carries the clock: before, the post ran up inside the face and its front
	# surface lay in the same plane as the glass (z-fighting: "wood through the clock").
	_box(body, "Post", Vector3(0.28, 1.95, 0.28), Vector3(0, 0.975, 0), DARK_WOOD)
	_box(body, "Base", Vector3(0.6, 0.25, 0.6), Vector3(0, 0.125, 0), STONE)
	_box(body, "Bracket", Vector3(0.2, 0.14, 0.2), Vector3(0, 2.0, -0.02), DARK_WOOD)
	var rim := _cylinder(body, "Rim", 0.62, 0.14, Vector3(0, 2.65, 0.05), DARK_WOOD, false)
	rim.rotation = Vector3(deg_to_rad(90), 0, 0)
	var face := _cylinder(body, "Face", 0.54, 0.16, Vector3(0, 2.65, 0.06), Color(0.97, 0.94, 0.85), false)
	face.rotation = Vector3(deg_to_rad(90), 0, 0)
	for i in 4:  # ticks at 12, 3, 6 and 9
		var angle := deg_to_rad(i * 90.0)
		_box(body, "Tick", Vector3(0.06, 0.12, 0.03), Vector3(sin(angle) * 0.44, 2.65 + cos(angle) * 0.44, 0.15), IRON)
	for hand in [["HourHand", 0.3, 0.07], ["MinuteHand", 0.44, 0.05]]:
		var pivot := Node3D.new()
		pivot.name = hand[0]
		pivot.position = Vector3(0, 2.65, 0.17)
		root.add_child(pivot)
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(hand[2], hand[1], 0.03)
		blade.mesh = mesh
		blade.material_override = _material(IRON)
		blade.position = Vector3(0, hand[1] * 0.5, 0)
		pivot.add_child(blade)
	_collider(body, "ClockCollision", Vector3(0.4, 2.1, 0.4), Vector3(0, 1.05, 0))
	return root


static func bench() -> Node3D:
	var root := Node3D.new()
	root.name = "Bench"
	var body := _body(root)
	_box(body, "Seat", Vector3(1.6, 0.08, 0.5), Vector3(0, 0.46, 0), WOOD)
	_box(body, "Back", Vector3(1.6, 0.4, 0.06), Vector3(0, 0.78, -0.22), WOOD)
	for sign_x in [-1.0, 1.0]:
		_box(body, "Leg", Vector3(0.08, 0.46, 0.46), Vector3(sign_x * 0.7, 0.23, 0), DARK_WOOD)
	_collider(body, "BenchCollision", Vector3(1.6, 0.5, 0.5), Vector3(0, 0.25, 0))
	var seat := Seat.new()  # E at the bench sits down
	seat.name = "Seat"
	seat.position = Vector3(0, 0.5, 0.55)
	root.add_child(seat)
	return root


static func well() -> Node3D:
	var root := Node3D.new()
	root.name = "Well"
	var body := _body(root)
	_cylinder(body, "Ring", 0.9, 0.8, Vector3(0, 0.4, 0), STONE)
	var water := _cylinder(body, "Water", 0.72, 0.02, Vector3(0, 0.62, 0), Color(0.30, 0.55, 0.75), false)
	water.material_override = _material(Color(0.30, 0.55, 0.75))
	for sign_x in [-1.0, 1.0]:
		_box(body, "Post", Vector3(0.12, 1.6, 0.12), Vector3(sign_x * 0.75, 1.6, 0), DARK_WOOD)
	_box(body, "Beam", Vector3(1.8, 0.12, 0.12), Vector3(0, 2.4, 0), DARK_WOOD)
	for sign_x in [-1.0, 1.0]:
		_box(body, "RoofHalf", Vector3(1.1, 0.06, 1.3), Vector3(sign_x * 0.5, 2.6, 0), Color(0.78, 0.38, 0.30), Vector3(0, 0, -sign_x * 0.4))
	return root


static func notice_board() -> Node3D:
	var root := Node3D.new()
	root.name = "NoticeBoard"
	var body := _body(root)
	for sign_x in [-1.0, 1.0]:
		_box(body, "Post", Vector3(0.12, 1.9, 0.12), Vector3(sign_x * 0.7, 0.95, 0), DARK_WOOD)
	_box(body, "Board", Vector3(1.7, 1.0, 0.08), Vector3(0, 1.4, 0), WOOD)
	for i in 3:
		_box(body, "Note", Vector3(0.3, 0.4, 0.01), Vector3(-0.5 + i * 0.5, 1.4, 0.05), Color(0.97, 0.94, 0.85))
	_collider(body, "BoardCollision", Vector3(1.7, 1.9, 0.2), Vector3(0, 0.95, 0))
	return root


## One 2 m fence segment (posts and two rails), long side along local X.
static func fence() -> Node3D:
	var root := Node3D.new()
	root.name = "Fence"
	var body := _body(root)
	for sign_x in [-1.0, 1.0]:
		_box(body, "Post", Vector3(0.1, 1.0, 0.1), Vector3(sign_x * 0.95, 0.5, 0), WOOD)
	for rail_y in [0.35, 0.75]:
		_box(body, "Rail", Vector3(2.0, 0.08, 0.06), Vector3(0, rail_y, 0), WOOD)
	_collider(body, "FenceCollision", Vector3(2.0, 1.0, 0.2), Vector3(0, 0.5, 0))
	return root


## A gate in a fence line: two tall posts 2.4 m apart (centre to centre) and the gate leaf swung open flat against one post. Only the POSTS
## collide, so the 2.0 m opening between them can never block anyone (the village test walks a capsule through every gate).
static func gate() -> Node3D:
	var root := Node3D.new()
	root.name = "Gate"
	var body := _body(root)
	for sign_x in [-1.0, 1.0]:
		_box(body, "GatePost", Vector3(0.18, 1.7, 0.18), Vector3(sign_x * GATE_HALF_SPAN, 0.85, 0), WOOD)
		_box(body, "GateCap", Vector3(0.26, 0.08, 0.26), Vector3(sign_x * GATE_HALF_SPAN, 1.74, 0), Color(0.45, 0.32, 0.22))
		_collider(body, "GatePostCollision", Vector3(0.2, 1.7, 0.2), Vector3(sign_x * GATE_HALF_SPAN, 0.85, 0))
	# The open leaf: flat against the right post, swung 90 degrees (decorative, no collision).
	_box(root, "GateLeaf", Vector3(0.06, 0.9, 1.0), Vector3(GATE_HALF_SPAN + 0.12, 0.7, 0.55), Color(0.62, 0.45, 0.30))
	return root


const GATE_HALF_SPAN := 1.2  ## post centre to the gate's middle (the clear opening is 2 * this minus the post width)


## A market stall: a counter with goods and a striped awning on four posts. The counter and posts collide.
static func market_stall(awning: Color = Color(0.85, 0.35, 0.30)) -> Node3D:
	var root := Node3D.new()
	root.name = "MarketStall"
	var body := _body(root)
	_box(body, "Counter", Vector3(2.4, 0.9, 0.8), Vector3(0, 0.45, 0), Color(0.66, 0.50, 0.34))
	_collider(body, "CounterCollision", Vector3(2.4, 0.9, 0.8), Vector3(0, 0.45, 0))
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			_box(body, "StallPost", Vector3(0.1, 2.3, 0.1), Vector3(sign_x * 1.15, 1.15, sign_z * 0.45), WOOD)
	_collider(body, "StallPostsCollision", Vector3(2.4, 2.3, 0.1), Vector3(0, 1.15, -0.45))
	for i in 6:  # the awning: alternating coloured and cream stripes, sloping down at the front
		var stripe := awning if i % 2 == 0 else Color(0.96, 0.92, 0.82)
		_box(root, "Awning", Vector3(0.42, 0.06, 1.3), Vector3(-1.05 + i * 0.42, 2.35, 0.05), stripe, Vector3(deg_to_rad(8.0), 0, 0))
	var goods := [Color(0.85, 0.25, 0.22), Color(0.95, 0.75, 0.20), Color(0.40, 0.70, 0.30), Color(0.90, 0.50, 0.15)]
	for i in goods.size():
		_box(root, "Goods", Vector3(0.34, 0.2, 0.34), Vector3(-0.8 + i * 0.52, 1.0, 0.0), goods[i])
	return root


## The weapon rack: a wooden frame holding a sword, a spear and an axe. The `weapon_rack` group lets the combat system find it; the Interactable
## on it (added by the village) hands the weapons over.
static func weapon_rack() -> Node3D:
	var root := Node3D.new()
	root.name = "WeaponRack"
	var body := _body(root)
	for sign_x in [-1.0, 1.0]:
		_box(body, "RackPost", Vector3(0.12, 1.8, 0.12), Vector3(sign_x * 0.9, 0.9, 0), WOOD)
	_box(body, "RackBeamTop", Vector3(2.0, 0.1, 0.14), Vector3(0, 1.55, 0), WOOD)
	_box(body, "RackBeamLow", Vector3(2.0, 0.1, 0.14), Vector3(0, 0.75, 0), WOOD)
	_collider(body, "RackCollision", Vector3(2.0, 1.8, 0.3), Vector3(0, 0.9, 0))
	var steel := Color(0.75, 0.78, 0.82)
	var grip := Color(0.45, 0.30, 0.20)
	_box(root, "SwordBlade", Vector3(0.09, 0.8, 0.03), Vector3(-0.5, 1.15, 0.12), steel)
	_box(root, "SwordGuard", Vector3(0.3, 0.05, 0.05), Vector3(-0.5, 0.72, 0.12), grip)
	_box(root, "SpearShaft", Vector3(0.05, 1.7, 0.05), Vector3(0.0, 0.95, 0.12), grip)
	_box(root, "SpearHead", Vector3(0.12, 0.22, 0.03), Vector3(0.0, 1.9, 0.12), steel)
	_box(root, "AxeHandle", Vector3(0.05, 0.9, 0.05), Vector3(0.5, 1.1, 0.12), grip)
	_box(root, "AxeHead", Vector3(0.3, 0.22, 0.04), Vector3(0.62, 1.45, 0.12), steel)
	return root


## A garage: a lean-to shed 3.4 m wide and 4.2 m deep with the whole front open (walk in to park a cart or just shelter), a flat roof sloping down at the back,
## a roll-up door drawn rolled up above the opening. Open side = local +Z. Solid: the two side walls, the back wall and the roof beam; the floor slab is walkable.
static func garage(wall_color: Color = Color(0.82, 0.78, 0.70), roof_color: Color = Color(0.40, 0.42, 0.46)) -> Node3D:
	var root := Node3D.new()
	root.name = "Garage"
	var body := _body(root)
	var w := GARAGE_WIDTH
	var d := GARAGE_DEPTH
	_box(body, "Slab", Vector3(w, 0.08, d), Vector3(0, 0.04, 0), STONE)
	_box(body, "WallLeft", Vector3(0.2, 2.6, d), Vector3(-(w * 0.5 - 0.1), 1.3, 0), wall_color)
	_box(body, "WallRight", Vector3(0.2, 2.6, d), Vector3(w * 0.5 - 0.1, 1.3, 0), wall_color)
	_box(body, "WallBack", Vector3(w, 2.6, 0.2), Vector3(0, 1.3, -(d * 0.5 - 0.1)), wall_color)
	_box(body, "Roof", Vector3(w + 0.4, 0.14, d + 0.4), Vector3(0, 2.72, 0), roof_color, Vector3(deg_to_rad(-4.0), 0, 0))
	_box(body, "Lintel", Vector3(w, 0.35, 0.22), Vector3(0, 2.4, d * 0.5 - 0.1), DARK_WOOD)
	_box(root, "RolledDoor", Vector3(w - 0.5, 0.22, 0.26), Vector3(0, 2.18, d * 0.5 - 0.12), IRON)  # the roll-up door, rolled up
	_box(root, "Crate", Vector3(0.6, 0.5, 0.6), Vector3(-(w * 0.5 - 0.7), 0.33, -(d * 0.5 - 0.7)), WOOD)
	_collider(body, "LeftCollision", Vector3(0.2, 2.6, d), Vector3(-(w * 0.5 - 0.1), 1.3, 0))
	_collider(body, "RightCollision", Vector3(0.2, 2.6, d), Vector3(w * 0.5 - 0.1, 1.3, 0))
	_collider(body, "BackCollision", Vector3(w, 2.6, 0.2), Vector3(0, 1.3, -(d * 0.5 - 0.1)))
	_collider(body, "LintelCollision", Vector3(w, 0.35, 0.22), Vector3(0, 2.4, d * 0.5 - 0.1))
	return root


const GARAGE_WIDTH := 3.4
const GARAGE_DEPTH := 4.2


static func _body(root: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	root.add_child(body)
	return body


static func _box(parent: Node, node_name: String, size: Vector3, pos: Vector3, color: Color,
		rot_rad := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = pos
	mesh.rotation = rot_rad
	parent.add_child(mesh)
	return mesh


static func _cylinder(parent: Node, node_name: String, radius: float, height: float, pos: Vector3,
		color: Color, collide := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mesh.mesh = cyl
	mesh.material_override = _material(color)
	mesh.position = pos
	parent.add_child(mesh)
	if collide:
		var shape := CollisionShape3D.new()
		shape.name = node_name + "Collision"
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = radius
		cyl_shape.height = height
		shape.shape = cyl_shape
		shape.position = pos
		parent.add_child(shape)
	return mesh


static func _collider(parent: Node, node_name: String, size: Vector3, pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = node_name
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = pos
	parent.add_child(shape)


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_materials[key] = material
	return _materials[key]
