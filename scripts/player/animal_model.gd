@tool
class_name AnimalModel
extends Node3D
## A cute, chunky, two-legged animal character built from simple shapes and
## animated in code (no imported art yet). Feet are at y = 0 and the character
## faces -Z, like the player body it lives in. About 1.65 m tall, so it fits
## the player's 0.4 m x 1.8 m collision capsule.
##
## Look: big round head, small body, stubby legs, floppy ears, a short snout,
## big shiny eyes, blush cheeks and a wagging tail. The species decides colours
## and ear / tail shape (`AnimalSpecies`).
##
## Outfits: five named sockets (head_top, face, neck, torso, back) are ready for
## clothes. `equip(slot, item)` attaches any Node3D, `unequip(slot)` removes it.
## Equipped items fade with the body when the camera gets close.
##
## The owner (the player controller) calls `set_motion()` every physics frame;
## the animation itself runs in `_physics_process` too (idle breathing, tail wag,
## blinking, walk cycle, jump pose), so it advances in lockstep with the movement
## it shows: the same speed whatever the frame rate, and exactly reproducible in
## tests and filmstrips (in `_process` a slow renderer froze the animation while
## the physics kept running: lesson 43). Everything is generated at runtime, never saved into
## the scene, and the node also runs in the editor.

signal rebuilt

const SLOTS: Array[StringName] = [&"head_top", &"face", &"neck", &"torso", &"back"]
const HEIGHT := 1.65
## Radians of walk cycle per metre travelled when walking, and when sprinting (a longer, slower
## stride): ties the stride to the ground speed so the feet don't skate (the backward swing
## speed of a planted foot, amplitude x cadence x leg length, is close to the body speed).
const STRIDE_RATE_WALK := 3.4
const STRIDE_RATE_SPRINT := 2.4
## No limb joint turns faster than this (radians per second): a landing and an instant
## take-off on a held jump, or any other sudden change, can never snap an arm across the body.
const MAX_JOINT_SPEED := 20.0
## Hip height and how far the swinging foot lifts off the ground each step.
const HIP_Y := 0.5

@export var species: AnimalSpecies:
	set(value):
		species = value
		if is_inside_tree():
			_build()

## Where each outfit slot is: slot name -> Node3D.
var sockets := {}

var _generated: Node3D
var _materials: Array[StandardMaterial3D] = []
var _material_cache := {}
var _equipped := {}
var _fade := 0.0

var _rig: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _tail: Node3D
var _ear_l: Node3D
var _ear_r: Node3D
var _eye_l: Node3D
var _eye_r: Node3D

var _speed := 0.0
var _grounded := true
var _vertical_velocity := 0.0
var _alignment := 1.0
var _phase := 0.0
var _time := 0.0
var _walk_amount := 0.0
var _air_amount := 0.0


func _ready() -> void:
	_build()


## Called every physics frame by the owner: horizontal speed (m/s), whether it
## stands on the ground, and vertical velocity (m/s).
## `alignment` is how well the movement matches the way the body faces (1 = forward,
## 0 = sideways, negative = sliding backwards, e.g. a sharp turn at speed): the stride
## freezes while the body slides instead of the legs running a forward cycle (no moonwalk).
func set_motion(horizontal_speed: float, grounded: bool, vertical_velocity: float, alignment: float = 1.0) -> void:
	_speed = horizontal_speed
	_grounded = grounded
	_vertical_velocity = vertical_velocity
	_alignment = alignment


## 0 = fully visible, 1 = fully transparent. Applies to the body and every outfit item.
func set_fade(amount: float) -> void:
	_fade = clampf(amount, 0.0, 1.0)
	for material in _materials:
		_apply_fade(material)


## Opacity of the body right now (1 = solid). The camera tests read this.
func get_alpha() -> float:
	return 1.0 - _fade


## Puts `item` on a socket, replacing what was there. The model owns the item from now on.
func equip(slot: StringName, item: Node3D) -> void:
	if not sockets.has(slot):
		push_warning("AnimalModel: no outfit slot called %s" % slot)
		item.queue_free()
		return
	unequip(slot)
	sockets[slot].add_child(item)
	_equipped[slot] = item
	_register_materials(item)


## Takes whatever is on `slot` off (and deletes it).
func unequip(slot: StringName) -> void:
	var item: Node3D = _equipped.get(slot)
	if item == null:
		return
	_equipped.erase(slot)
	for mesh in _meshes_under(item):
		_materials.erase(mesh.material_override)
	item.get_parent().remove_child(item)
	item.queue_free()


func get_equipped(slot: StringName) -> Node3D:
	return _equipped.get(slot)


## Every MeshInstance3D of the body and its outfits (for tests and the camera).
func all_meshes() -> Array[MeshInstance3D]:
	return _meshes_under(self)


## Where the feet and hands are, in this model's own space (x right, y up, -z forward).
## Keys: foot_l, foot_r, hand_l, hand_r. "L" is the +X side, as for the limb pivots.
func limb_positions() -> Dictionary:
	return {
		"foot_l": to_local(_leg_l.get_node("Paw").global_position),
		"foot_r": to_local(_leg_r.get_node("Paw").global_position),
		"hand_l": to_local(_arm_l.get_node("Paw").global_position),
		"hand_r": to_local(_arm_r.get_node("Paw").global_position),
	}


## Animation values for tests: leg angles (radians; positive = foot forward; opposite signs while walking).
func leg_angles() -> Vector2:
	return Vector2(_leg_l.rotation.x, _leg_r.rotation.x)


## Arm swing angles (positive = hand forward).
func arm_angles() -> Vector2:
	return Vector2(_arm_l.rotation.x, _arm_r.rotation.x)


## 0 = standing on the ground, 1 = fully in the jump pose.
func air_amount() -> float:
	return _air_amount


func is_blinking() -> bool:
	return _eye_l.scale.y < 0.5


## Rotation conventions (the model faces -Z, Y is up, +X is the character's right):
## - A limb hanging down from its pivot swings FORWARD (toward -Z) with a POSITIVE rotation.x.
## - An arm on the +X side swings OUTWARD (and up) with a POSITIVE rotation.z; the -X arm mirrors it.
## - The torso leans forward with a NEGATIVE rotation.x (its top moves toward -Z).
## Getting these signs wrong once made the jump pose kick the legs back and fold the
## arms across the body (lesson 42); tests/functional/test_animation.gd checks the geometry.
func _physics_process(delta: float) -> void:
	if _rig == null:
		return
	_time += delta
	var target_walk := clampf(_speed / 3.0, 0.0, 1.0) if _grounded else 0.0
	_walk_amount = move_toward(_walk_amount, target_walk, delta * 10.0)
	_air_amount = move_toward(_air_amount, 0.0 if _grounded else 1.0, delta * 10.0)
	var run := clampf((_speed - 3.0) / 4.0, 0.0, 1.0)
	_phase += _speed * maxf(_alignment, 0.0) * lerpf(STRIDE_RATE_WALK, STRIDE_RATE_SPRINT, run) * delta

	# Run cycle: legs swing in opposite directions, each arm swings opposite its same-side leg.
	var on_foot := _walk_amount * (1.0 - _air_amount)
	var leg_swing := sin(_phase) * lerpf(0.62, 0.95, run) * on_foot
	var arm_swing := sin(_phase) * lerpf(0.5, 0.85, run) * on_foot

	# Jump pose: knees up in front, arms thrown out and up (higher while rising, lower falling).
	var rising := clampf(_vertical_velocity / 5.0, -1.0, 1.0) * 0.5 + 0.5
	var arms_up := lerpf(1.5, 2.5, rising)
	_leg_l.rotation.x = _slew(_leg_l.rotation.x, lerpf(leg_swing, 0.7, _air_amount), delta)
	_leg_r.rotation.x = _slew(_leg_r.rotation.x, lerpf(-leg_swing, 0.3, _air_amount), delta)
	_arm_l.rotation.x = _slew(_arm_l.rotation.x, lerpf(-arm_swing, 0.15, _air_amount), delta)
	_arm_r.rotation.x = _slew(_arm_r.rotation.x, lerpf(arm_swing, 0.15, _air_amount), delta)
	_arm_l.rotation.z = _slew(_arm_l.rotation.z, lerpf(0.0, arms_up, _air_amount), delta)
	_arm_r.rotation.z = _slew(_arm_r.rotation.z, lerpf(0.0, -arms_up, _air_amount), delta)

	# The foot that is swinging forward lifts off the ground (so the other one is the planted one).
	var lift := lerpf(0.05, 0.1, run) * on_foot
	_leg_l.position.y = HIP_Y + lift * maxf(0.0, cos(_phase))
	_leg_r.position.y = HIP_Y + lift * maxf(0.0, -cos(_phase))

	var breathe := sin(_time * 2.2) * 0.012
	_rig.position.y = absf(sin(_phase)) * 0.04 * on_foot + breathe * (1.0 - _walk_amount)
	_rig.rotation.x = -0.12 * run * on_foot
	_rig.rotation.z = sin(_phase) * 0.04 * on_foot
	var stretch := 1.0 + clampf(_vertical_velocity, -6.0, 6.0) * 0.012 * _air_amount
	_rig.scale = Vector3(1.0 / sqrt(stretch), stretch, 1.0 / sqrt(stretch))
	_head.rotation.z = sin(_phase * 0.5) * 0.04 * on_foot + sin(_time * 0.8) * 0.02
	_head.rotation.x = 0.12 * _air_amount  # chin up, looking at the sky

	# Tail wags faster when standing still and happy.
	_tail.rotation.y = sin(_time * lerpf(9.0, 6.0, _walk_amount)) * lerpf(0.5, 0.35, _walk_amount)
	_ear_l.rotation.z = _ear_base(1.0) + sin(_phase * 2.0) * 0.12 * on_foot + sin(_time * 1.3) * 0.03
	_ear_r.rotation.z = _ear_base(-1.0) - sin(_phase * 2.0) * 0.12 * on_foot - sin(_time * 1.3 + 1.0) * 0.03

	var blink := fmod(_time, 3.4) < 0.12
	var eye_scale := 0.12 if blink else 1.0
	_eye_l.scale.y = eye_scale
	_eye_r.scale.y = eye_scale


func _slew(current: float, target: float, delta: float) -> float:
	return move_toward(current, target, MAX_JOINT_SPEED * delta)


func _ear_base(side: float) -> float:
	var s := species if species else AnimalSpecies.dog()
	match s.ear_style:
		AnimalSpecies.EarStyle.FLOPPY:
			return 0.28 * side
		AnimalSpecies.EarStyle.POINTY:
			return -0.18 * side
		_:
			return -0.1 * side


func _build() -> void:
	if _generated:
		remove_child(_generated)
		_generated.queue_free()
	_materials.clear()
	_material_cache.clear()
	sockets.clear()
	_equipped.clear()
	var s := species if species else AnimalSpecies.dog()

	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)
	_rig = _pivot(_generated, "Rig", Vector3.ZERO)

	# Legs and feet (the hip pivots swing).
	_leg_l = _build_leg(s, "LegL", 1.0)
	_leg_r = _build_leg(s, "LegR", -1.0)

	# Torso with a cream belly.
	_shape(_rig, "Torso", _capsule(0.26, 0.62), Vector3(0, 0.78, 0), s.fur_color)
	_shape(_rig, "Belly", _sphere(0.24), Vector3(0, 0.74, -0.17), s.belly_color, Vector3(0.85, 1.0, 0.5))

	# Arms (the shoulder pivots swing).
	_arm_l = _build_arm(s, "ArmL", 1.0)
	_arm_r = _build_arm(s, "ArmR", -1.0)

	# Head: big and round, with face, ears.
	_head = _pivot(_rig, "Head", Vector3(0, 1.06, 0))
	_shape(_head, "Skull", _sphere(0.36), Vector3(0, 0.27, 0), s.fur_color, Vector3(1.1, 0.9, 1.0))
	_shape(_head, "Snout", _sphere(0.16), Vector3(0, 0.17, -0.36 - (s.snout_length - 1.0) * 0.1), s.belly_color,
			Vector3(1.0, 0.72, 1.3 * s.snout_length))
	_shape(_head, "Nose", _sphere(0.065), Vector3(0, 0.235, -0.51 - (s.snout_length - 1.0) * 0.2), s.nose_color,
			Vector3(1.25, 0.8, 1.0), 0.35)
	_shape(_head, "Mouth", _sphere(0.03), Vector3(0, 0.12, -0.49 - (s.snout_length - 1.0) * 0.18), Color(0.92, 0.45, 0.5),
			Vector3(2.2, 0.5, 0.6))
	if s.eye_patch:
		_shape(_head, "EyePatch", _sphere(0.115), Vector3(0.15, 0.31, -0.31), s.accent_color, Vector3(1.0, 1.0, 0.5))
	_eye_l = _build_eye(s, "EyeL", -1.0)
	_eye_r = _build_eye(s, "EyeR", 1.0)
	_shape(_head, "CheekL", _sphere(0.07), Vector3(-0.255, 0.16, -0.27), s.cheek_color, Vector3(1.0, 0.6, 0.4))
	_shape(_head, "CheekR", _sphere(0.07), Vector3(0.255, 0.16, -0.27), s.cheek_color, Vector3(1.0, 0.6, 0.4))
	_ear_l = _build_ear(s, "EarL", 1.0)
	_ear_r = _build_ear(s, "EarR", -1.0)

	_tail = _build_tail(s)

	# Outfit sockets.
	sockets[&"head_top"] = _pivot(_head, "Socket_head_top", Vector3(0, 0.56, 0))
	sockets[&"face"] = _pivot(_head, "Socket_face", Vector3(0, 0.3, -0.36))
	sockets[&"neck"] = _pivot(_rig, "Socket_neck", Vector3(0, 1.05, 0))
	sockets[&"torso"] = _pivot(_rig, "Socket_torso", Vector3(0, 0.78, 0))
	sockets[&"back"] = _pivot(_rig, "Socket_back", Vector3(0, 0.8, 0.25))

	set_fade(_fade)
	rebuilt.emit()


func _build_leg(s: AnimalSpecies, leg_name: String, side: float) -> Node3D:
	var hip := _pivot(_rig, leg_name, Vector3(0.13 * side, HIP_Y, 0))
	_shape(hip, "Limb", _capsule(0.1, 0.46), Vector3(0, -0.23, 0), s.fur_color)
	_shape(hip, "Paw", _sphere(0.12), Vector3(0, -0.43, -0.05), s.belly_color, Vector3(1.0, 0.55, 1.35))
	return hip


func _build_arm(s: AnimalSpecies, arm_name: String, side: float) -> Node3D:
	var shoulder := _pivot(_rig, arm_name, Vector3(0.3 * side, 1.0, 0))
	_shape(shoulder, "Limb", _capsule(0.065, 0.34), Vector3(0.015 * side, -0.17, 0), s.fur_color)
	_shape(shoulder, "Paw", _sphere(0.085), Vector3(0.02 * side, -0.35, 0), s.belly_color)
	return shoulder


func _build_eye(s: AnimalSpecies, eye_name: String, side: float) -> Node3D:
	var eye := _pivot(_head, eye_name, Vector3(0.15 * side, 0.3, -0.345))
	_shape(eye, "Ball", _sphere(0.058), Vector3.ZERO, s.eye_color, Vector3(0.9, 1.1, 0.6), 0.15)
	_shape(eye, "Shine", _sphere(0.02), Vector3(0.016, 0.026, -0.03), Color.WHITE, Vector3.ONE, 0.1)
	return eye


func _build_ear(s: AnimalSpecies, ear_name: String, side: float) -> Node3D:
	var ear := _pivot(_head, ear_name, Vector3(0.3 * side, 0.5, -0.02))
	match s.ear_style:
		AnimalSpecies.EarStyle.FLOPPY:
			_shape(ear, "Flap", _sphere(0.17), Vector3(0.05 * side, -0.16, 0), s.accent_color, Vector3(0.42, 1.1, 0.8))
		AnimalSpecies.EarStyle.POINTY:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.11
			cone.height = 0.28
			_shape(ear, "Point", cone, Vector3(0.0, 0.12, 0), s.accent_color, Vector3(1.0, 1.0, 0.55))
		_:
			_shape(ear, "Round", _sphere(0.12), Vector3(0.0, 0.08, 0), s.accent_color, Vector3(1.0, 1.0, 0.5))
	return ear


func _build_tail(s: AnimalSpecies) -> Node3D:
	var tail := _pivot(_rig, "Tail", Vector3(0, 0.62, 0.22))
	match s.tail_style:
		AnimalSpecies.TailStyle.CURLED:
			_shape(tail, "Stem", _capsule(0.07, 0.36), Vector3(0, 0.14, 0.08), s.fur_color, Vector3.ONE, 0.85, Vector3(deg_to_rad(35), 0, 0))
			_shape(tail, "Tip", _sphere(0.105), Vector3(0, 0.31, 0.2), s.belly_color)
		AnimalSpecies.TailStyle.LONG:
			_shape(tail, "Stem", _capsule(0.05, 0.55), Vector3(0, 0.0, 0.2), s.fur_color, Vector3.ONE, 0.85, Vector3(deg_to_rad(80), 0, 0))
			_shape(tail, "Tip", _sphere(0.07), Vector3(0, 0.0, 0.46), s.belly_color)
		_:
			_shape(tail, "Stub", _sphere(0.1), Vector3(0, 0.02, 0.08), s.fur_color)
	return tail


func _pivot(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	parent.add_child(node)
	return node


func _shape(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, color: Color,
		mesh_scale := Vector3.ONE, roughness := 0.85, rot_rad := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _material(color, roughness)
	instance.position = pos
	instance.scale = mesh_scale
	instance.rotation = rot_rad
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 6
	return mesh


## One material per colour and roughness, shared by the parts that use it; the
## model keeps the list so it can fade them all.
func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "%s/%.2f" % [color.to_html(), roughness]
	if not _material_cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_material_cache[key] = material
		_materials.append(material)
	return _material_cache[key]


func _register_materials(item: Node3D) -> void:
	for mesh in _meshes_under(item):
		var material := mesh.material_override as StandardMaterial3D
		if material and not _materials.has(material):
			_materials.append(material)
			_apply_fade(material)


func _apply_fade(material: StandardMaterial3D) -> void:
	material.albedo_color.a = 1.0 - _fade
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _fade > 0.001 else BaseMaterial3D.TRANSPARENCY_DISABLED


func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		found.append(child)
	if node is MeshInstance3D:
		found.append(node)
	return found
