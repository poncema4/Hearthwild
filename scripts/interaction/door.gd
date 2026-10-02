@tool
class_name Door
extends Interactable
## A hinged door leaf with real collision. Closed it blocks the doorway; open
## it swings inward and lies against the inside wall. The leaf is only solid
## when it is at rest, so it never shoves the player mid-swing.
##
## A door will not close while a character stands in the doorway (otherwise
## the leaf would appear inside them and trap them).
##
## Frame: the node sits in the middle of the doorway on the wall line, +Z
## outward (like `House`), the hinge is on the left edge when seen from outside.

@export var width := 1.34  # the doorway is 1.36 clear: a 1 cm gap each side, not a visible sliver
@export var height := 2.15
@export var thickness := 0.06
@export var open_angle_degrees := 100.0
@export var open_seconds := 0.45
@export var leaf_color := Color(0.50, 0.35, 0.24)

var is_open := false

var _hinge: AnimatableBody3D
var _shape: CollisionShape3D
var _tween: Tween
var _moving := false


func _init() -> void:
	prompt_text = "Open door"
	interact_range = 2.6


func _ready() -> void:
	super._ready()
	_build()


func get_prompt() -> String:
	return "Close door" if is_open else "Open door"


func can_interact(_who: Node3D) -> bool:
	return not _moving and (not is_open or _doorway_is_clear())


func interact(who: Node3D) -> void:
	if is_open:
		close()
	else:
		open()
	super.interact(who)


func is_moving() -> bool:
	return _moving


func open() -> void:
	if _moving or is_open:
		return
	is_open = true
	_swing(open_angle_degrees)


func close() -> void:
	if _moving or not is_open or not _doorway_is_clear():
		return
	is_open = false
	_swing(0.0)


## Skips the animation (tests, scene setup).
func open_instantly() -> void:
	if _tween:
		_tween.kill()
	is_open = true
	_moving = false
	_hinge.rotation.y = deg_to_rad(open_angle_degrees)
	_shape.disabled = false


func close_instantly() -> void:
	if _tween:
		_tween.kill()
	is_open = false
	_moving = false
	_hinge.rotation.y = 0.0
	_shape.disabled = false


## Rotation of the leaf about the hinge, in degrees (0 = closed).
func leaf_angle_degrees() -> float:
	return rad_to_deg(_hinge.rotation.y)


func _swing(target_degrees: float) -> void:
	_moving = true
	_shape.disabled = true  # set directly (not deferred): a deferred write could land after open_instantly()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_hinge, "rotation:y", deg_to_rad(target_degrees), open_seconds)
	_tween.finished.connect(_on_swing_finished)


func _on_swing_finished() -> void:
	_moving = false
	# Someone stepped into the doorway while it was closing: swing back open rather than trap them.
	if not is_open and not _doorway_is_clear():
		is_open = true
		_swing(open_angle_degrees)
		return
	_shape.disabled = false


## True if no character is standing where the closed leaf would be.
func _doorway_is_clear() -> bool:
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness + 0.3)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = global_transform * Transform3D(Basis(), Vector3(0, height * 0.5, 0))
	query.exclude = [_hinge.get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit["collider"] is CharacterBody3D:
			return false
	return true


func _build() -> void:
	var old := get_node_or_null("Hinge")
	if old:
		remove_child(old)
		old.queue_free()
	_hinge = AnimatableBody3D.new()
	_hinge.name = "Hinge"
	_hinge.position = Vector3(-width * 0.5, 0, 0)
	add_child(_hinge)

	var material := StandardMaterial3D.new()
	material.albedo_color = leaf_color
	material.roughness = 0.9
	var leaf := MeshInstance3D.new()
	leaf.name = "Leaf"
	var box := BoxMesh.new()
	box.size = Vector3(width, height, thickness)
	leaf.mesh = box
	leaf.material_override = material
	leaf.position = Vector3(width * 0.5, height * 0.5, 0)
	_hinge.add_child(leaf)

	var knob_material := StandardMaterial3D.new()
	knob_material.albedo_color = Color(0.92, 0.75, 0.28)
	knob_material.metallic = 0.6
	knob_material.roughness = 0.35
	for side in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		knob.name = "Knob"
		var ball := SphereMesh.new()
		ball.radius = 0.045
		ball.height = 0.09
		knob.mesh = ball
		knob.material_override = knob_material
		knob.position = Vector3(width - 0.14, 1.0, side * (thickness * 0.5 + 0.03))
		_hinge.add_child(knob)

	_shape = CollisionShape3D.new()
	_shape.name = "LeafCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, thickness)
	_shape.shape = shape
	_shape.position = leaf.position
	_hinge.add_child(_shape)
