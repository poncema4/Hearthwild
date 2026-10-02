@tool
class_name House
extends Node3D
## A small cottage built from boxes: four walls with a door opening, a gabled
## roof, windows, a doorstep and a chimney. Walls and roof have collision; the
## floor, windows, trim and chimney are visual only (the terrain is perfectly
## flat under a house, so the ground itself is the floor).
##
## The front (the door) faces local +Z. Rotate the node to face a direction.
## Set the colours BEFORE adding the node to the tree: it builds in _ready().
##
## Sizes are constants because tests and the village layout depend on them:
## the door (1.4 x 2.2 m) must stay bigger than the player (0.8 x 1.8 m).

const WIDTH := 6.0  # x
const DEPTH := 5.0  # z
const WALL_HEIGHT := 2.8
const WALL_THICKNESS := 0.3
const DOOR_WIDTH := 1.4
const DOOR_HEIGHT := 2.2
const ROOF_RISE := 1.4
const ROOF_OVERHANG := 0.4

@export var wall_color := Color(0.96, 0.89, 0.76)
@export var roof_color := Color(0.78, 0.38, 0.30)
@export var trim_color := Color(0.50, 0.35, 0.24)

var _body: StaticBody3D
var _materials := {}


func _ready() -> void:
	_build()


## World position `distance` metres in front of the door, on the ground.
func door_outside(distance: float = 2.5) -> Vector3:
	return to_global(Vector3(0, 0, DEPTH * 0.5 + distance))


## World position in the middle of the doorway.
func door_center() -> Vector3:
	return to_global(Vector3(0, 0, DEPTH * 0.5))


## World position at the middle of the room.
func interior_center() -> Vector3:
	return to_global(Vector3.ZERO)


## True if a world point is inside the walls (horizontally).
func is_inside(world_point: Vector3) -> bool:
	var local := to_local(world_point)
	return absf(local.x) < WIDTH * 0.5 - WALL_THICKNESS and absf(local.z) < DEPTH * 0.5 - WALL_THICKNESS


## The four outer corners on the ground, in world space.
func footprint_corners() -> Array[Vector3]:
	var half_w := WIDTH * 0.5
	var half_d := DEPTH * 0.5
	return [to_global(Vector3(-half_w, 0, -half_d)), to_global(Vector3(half_w, 0, -half_d)),
		to_global(Vector3(half_w, 0, half_d)), to_global(Vector3(-half_w, 0, half_d))]


func _build() -> void:
	var old := get_node_or_null("Generated")
	if old:
		remove_child(old)
		old.queue_free()
	_body = StaticBody3D.new()
	_body.name = "Generated"
	add_child(_body)

	var half_w := WIDTH * 0.5
	var half_d := DEPTH * 0.5
	var t := WALL_THICKNESS
	var h := WALL_HEIGHT

	# Walls (collision). The front is split around the door and capped by a lintel.
	_box("BackWall", Vector3(WIDTH, h, t), Vector3(0, h * 0.5, -half_d + t * 0.5), wall_color)
	_box("LeftWall", Vector3(t, h, DEPTH), Vector3(-half_w + t * 0.5, h * 0.5, 0), wall_color)
	_box("RightWall", Vector3(t, h, DEPTH), Vector3(half_w - t * 0.5, h * 0.5, 0), wall_color)
	var side := (WIDTH - DOOR_WIDTH) * 0.5
	var side_x := DOOR_WIDTH * 0.5 + side * 0.5
	_box("FrontLeft", Vector3(side, h, t), Vector3(-side_x, h * 0.5, half_d - t * 0.5), wall_color)
	_box("FrontRight", Vector3(side, h, t), Vector3(side_x, h * 0.5, half_d - t * 0.5), wall_color)
	_box("Lintel", Vector3(DOOR_WIDTH, h - DOOR_HEIGHT, t),
		Vector3(0, DOOR_HEIGHT + (h - DOOR_HEIGHT) * 0.5, half_d - t * 0.5), wall_color)

	# Roof (collision): two sloped slabs, a ridge cap, and gable triangles front and back.
	# Each slab's centre line runs from the ridge (y = h + ROOF_RISE) down THROUGH the
	# wall top at x = half_w (y = h) and on to the eave, so the roof rests on the walls
	# (it used to float 0.18 m above them). The slab is lifted half its thickness along
	# its normal so the walls poke into it, never through it.
	var tilt := atan2(ROOF_RISE, half_w)
	var run := half_w + ROOF_OVERHANG
	var eave_drop := tan(tilt) * run
	var slab_length := run / cos(tilt)
	var slab_depth := DEPTH + 0.7
	for sign_x in [-1.0, 1.0]:
		var mid := Vector3(sign_x * run * 0.5, h + ROOF_RISE - eave_drop * 0.5, 0.0)
		var lift := Vector3(sign_x * sin(tilt), cos(tilt), 0.0) * 0.1
		_box("RoofSlab", Vector3(slab_length, 0.2, slab_depth), mid + lift, roof_color,
			Vector3(0, 0, -sign_x * tilt))
	# The ridge cap covers the V where the two slab tops meet. Its bottom is sunk 2 cm below
	# the lowest slab top it spans, so no face is coplanar with a slab (banding, lesson 40).
	_box("RoofRidge", Vector3(0.5, 0.2, slab_depth), Vector3(0, h + ROOF_RISE + 0.08, 0), roof_color.darkened(0.2), Vector3.ZERO, false)
	for sign_z in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		gable.name = "Gable"
		var prism := PrismMesh.new()
		prism.size = Vector3(WIDTH, ROOF_RISE, t)
		gable.mesh = prism
		gable.material_override = _material(wall_color)
		gable.position = Vector3(0, h + ROOF_RISE * 0.5, sign_z * (half_d - t * 0.5))
		_body.add_child(gable)

	# Visual only: floor, doorstep, door frame, windows, chimney.
	_box("Floor", Vector3(WIDTH - 2.0 * t, 0.04, DEPTH - 2.0 * t), Vector3(0, 0.02, 0), Color(0.72, 0.55, 0.38), Vector3.ZERO, false)
	_box("Doorstep", Vector3(DOOR_WIDTH + 0.5, 0.06, 0.8), Vector3(0, 0.03, half_d + 0.4), trim_color, Vector3.ZERO, false)
	for sign_x in [-1.0, 1.0]:
		# Trim is inset 2 cm into the opening (and the header 2 cm below the lintel) so no
		# trim face shares a plane with a wall face: coplanar faces z-fight (lesson 40).
		_box("DoorPost", Vector3(0.14, DOOR_HEIGHT, t + 0.08), Vector3(sign_x * (DOOR_WIDTH * 0.5 + 0.05), DOOR_HEIGHT * 0.5, half_d - t * 0.5), trim_color, Vector3.ZERO, false)
	_box("DoorHeader", Vector3(DOOR_WIDTH + 0.4, 0.14, t + 0.08), Vector3(0, DOOR_HEIGHT + 0.05, half_d - t * 0.5), trim_color, Vector3.ZERO, false)
	var glass := Color(0.55, 0.75, 0.90)
	for sign_x in [-1.0, 1.0]:
		_window(Vector3(sign_x * side_x, 1.55, half_d + 0.01), 0, glass)       # front
		_window(Vector3(sign_x * (half_w + 0.01), 1.55, 0), 90.0 * sign_x, glass)  # sides, glass facing OUT
	_box("Chimney", Vector3(0.6, 1.5, 0.6), Vector3(1.6, h + ROOF_RISE * 0.45 + 0.5, -0.9), Color(0.62, 0.58, 0.54), Vector3.ZERO, false)


## A box mesh (and, if `collide`, a matching collision box) under the body.
func _box(box_name: String, size: Vector3, pos: Vector3, color: Color, rot_rad := Vector3.ZERO, collide := true) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = pos
	mesh.rotation = rot_rad
	_body.add_child(mesh)
	if collide:
		var shape := CollisionShape3D.new()
		shape.name = box_name + "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = pos
		shape.rotation = rot_rad
		_body.add_child(shape)


## A window: a trim frame with a glass pane in front. `yaw_degrees` 90 faces sideways.
func _window(pos: Vector3, yaw_degrees: float, glass: Color) -> void:
	var yaw := deg_to_rad(yaw_degrees)
	var out := Vector3(sin(yaw), 0, cos(yaw))
	_box("WindowFrame", Vector3(1.05, 1.05, 0.05), pos, trim_color, Vector3(0, yaw, 0), false)
	_box("WindowGlass", Vector3(0.85, 0.85, 0.05), pos + out * 0.03, glass, Vector3(0, yaw, 0), false)


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_materials[key] = material
	return _materials[key]
