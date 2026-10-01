class_name PlayerController
extends CharacterBody3D
## Third-person player movement: walk, sprint, jump, gravity.
##
## Movement is relative to the camera's yaw, so "forward" is always
## where the camera looks. The visible body turns to face the direction
## of travel.
##
## Multiplayer note: all player input is read in _read_move_input() and
## _wants_jump(). When networking arrives, only the authority should read
## local input there; everything else consumes the same values.

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 5.0
@export var acceleration: float = 30.0
@export var turn_speed: float = 12.0

@onready var _body: Node3D = $Body
@onready var _camera_rig: ThirdPersonCamera = $CameraRig

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _wants_jump():
		velocity.y = jump_velocity

	var input := _read_move_input()
	var direction := _camera_relative_direction(input)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target := direction * speed

	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()

	if direction.length_squared() > 0.0:
		_face_direction(direction, delta)


func _read_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _wants_jump() -> bool:
	return Input.is_action_just_pressed("jump")


func _camera_relative_direction(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var yaw := _camera_rig.get_yaw()
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw).normalized()


func _face_direction(direction: Vector3, delta: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, turn_speed * delta)
