class_name Bed
extends Interactable
## A bed in a cottage. Press E next to it after 7 PM (and before 6 AM) to sleep until morning;
## at other times it tells you you are not tired. The bed runs along its local Z axis with the
## pillow at the -Z end; the free side (where you stand) is +X.
##
## The bed itself only answers E; `SleepSystem` does the sleeping.

const LENGTH := 2.0
const WIDTH := 1.1
const TOP := 0.46  # height of the mattress surface

@export var blanket_color := Color(0.45, 0.6, 0.85)

var _built := false


func _init() -> void:
	prompt_text = "Sleep until morning"
	interact_range = 2.6


func _ready() -> void:
	super._ready()
	_build()


func get_prompt() -> String:
	var sleep := get_tree().get_first_node_in_group(&"sleep_system") as SleepSystem
	return "Sleep until morning" if sleep == null or sleep.can_sleep_now() else "Too early to sleep (after 7 PM)"


func interact(who: Node3D) -> void:
	message = ""
	var sleep := get_tree().get_first_node_in_group(&"sleep_system") as SleepSystem
	if sleep:
		message = sleep.try_sleep(who, self)
	super.interact(who)


## Where the sleeper's feet go (world), on the mattress at the foot end.
func foot_point() -> Vector3:
	return to_global(Vector3(0, TOP, LENGTH * 0.5 - 0.15))


## The direction from the feet toward the pillow (world, flat).
func head_direction() -> Vector3:
	return (global_transform.basis * Vector3(0, 0, -1)).normalized()


## Where the player stands when they get up: beside the bed on its free side.
func getting_up_point() -> Vector3:
	return to_global(Vector3(WIDTH * 0.5 + 0.55, 0.0, 0.0))


func _build() -> void:
	if _built:
		return
	_built = true
	var body := StaticBody3D.new()
	body.name = "Frame"
	add_child(body)
	_box(body, "Base", Vector3(WIDTH, 0.3, LENGTH), Vector3(0, 0.15, 0), Color(0.5, 0.35, 0.24))
	_box(body, "Mattress", Vector3(WIDTH - 0.1, 0.16, LENGTH - 0.1), Vector3(0, 0.38, 0), Color(0.96, 0.93, 0.86))
	_box(body, "Pillow", Vector3(0.7, 0.12, 0.4), Vector3(0, 0.52, -LENGTH * 0.5 + 0.35), Color(1.0, 0.99, 0.96))
	_box(body, "Blanket", Vector3(WIDTH - 0.08, 0.1, 1.15), Vector3(0, 0.5, 0.3), blanket_color)
	_box(body, "Headboard", Vector3(WIDTH, 0.7, 0.08), Vector3(0, 0.55, -LENGTH * 0.5 - 0.04), Color(0.42, 0.3, 0.2))
	var shape := CollisionShape3D.new()
	shape.name = "FrameCollision"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(WIDTH, 0.46, LENGTH)
	shape.shape = box_shape
	shape.position = Vector3(0, 0.23, 0)
	body.add_child(shape)


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
