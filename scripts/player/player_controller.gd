class_name PlayerController
extends CharacterBody3D
## Third-person player movement: walk, sprint, jump, gravity.
##
## Smoothness rules (the player asked for these):
## - Holding Shift keeps sprinting for as long as it is held; jumping or
##   running over bumps never drops it.
## - Holding Space jumps again every time the character lands (no tapping).
## - A short "coyote" window after leaving the ground still allows a jump, and
##   the character is glued to the ground when running downhill, so a jump is
##   never eaten by a one-frame hop off a bump.
## - Walls are slid along (guarded by test_village.gd; Godot already does this).
##
## Movement is relative to the camera's yaw, so "forward" is always
## where the camera looks. The visible body turns to face the direction
## of travel.
##
## Multiplayer note: all player input is read in this script (_read_move_input(),
## wants_jump(), wants_sprint(), wants_interact()); other nodes (the Interactor)
## ask the controller instead of calling Input. When networking arrives, only the
## authority should read local input here, and the HUD should exist only for the
## local player (step 16).

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 5.0
@export var acceleration: float = 30.0
@export var turn_speed: float = 12.0
## Seconds after leaving the ground in which a jump still works.
@export var coyote_time: float = 0.12
## Falling below this height returns the player to where they spawned.
@export var fall_limit_y: float = -25.0

@onready var _body: Node3D = $Body
@onready var _model: AnimalModel = $Body/Model
@onready var _camera_rig: ThirdPersonCamera = $CameraRig

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_position: Vector3
var _coyote := 0.0
## True while a full-screen menu (the character screen) is open: no movement, jumping or interacting.
var input_locked := false
## True while lying in a bed (SleepSystem): no physics, no collision, the model is lying down.
var sleeping := false:
	set(value):
		sleeping = value
		velocity = Vector3.ZERO
		var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape:
			shape.set_deferred("disabled", value)


func _ready() -> void:
	_spawn_position = global_position
	# Stay glued to the ground when running downhill or over bumps (a sprint at
	# 7 m/s otherwise hops off the ground for a frame) and keep speed on slopes.
	floor_snap_length = 0.5
	floor_constant_speed = true


func _physics_process(delta: float) -> void:
	if sleeping:
		velocity = Vector3.ZERO
		_model.set_motion(0.0, true, 0.0)
		return
	if global_position.y < fall_limit_y:
		respawn()
		return
	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		velocity.y -= _gravity * delta
	if wants_jump() and _coyote > 0.0:
		velocity.y = jump_velocity
		_coyote = 0.0

	var input := _read_move_input()
	var direction := _camera_relative_direction(input)
	var speed := sprint_speed if wants_sprint() else walk_speed
	var target := direction * speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	var forward := Vector2(-_body.global_transform.basis.z.x, -_body.global_transform.basis.z.z)
	# 1 = moving the way the body faces; below 0 = sliding backwards (a sharp turn at speed).
	var alignment := flat.normalized().dot(forward.normalized()) if flat.length() > 0.5 else 1.0
	_model.set_motion(flat.length(), is_on_floor(), velocity.y, alignment)

	if direction.length_squared() > 0.0:
		_face_direction(direction, delta)


## Puts the player back at the spawn point, standing still.
func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO


func _read_move_input() -> Vector2:
	if input_locked:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


## Held, not just pressed: keep holding Space and the character hops on every landing.
func wants_jump() -> bool:
	return not input_locked and Input.is_action_pressed("jump")


func wants_sprint() -> bool:
	return not input_locked and Input.is_action_pressed("sprint")


func wants_interact() -> bool:
	return not input_locked and Input.is_action_just_pressed("interact")


func wants_customize() -> bool:
	return not input_locked and Input.is_action_just_pressed("customize")


func _camera_relative_direction(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var yaw := _camera_rig.get_yaw()
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw).normalized()


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, turn_speed * delta)
