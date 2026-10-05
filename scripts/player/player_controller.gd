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


## The seat being sat on (a `Seat`), or null. While seated: no collision, no movement; a fresh press of E, Space or a
## move key stands the player up in front of the bench.
var seat: Seat = null:
	set(value):
		seat = value
		velocity = Vector3.ZERO
		_seat_frame = Engine.get_physics_frames()
		var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape:
			shape.set_deferred("disabled", value != null)
var _seat_frame := -1  ## the physics frame the seat last changed: that frame's key press is not a second command
var _jump_blocked := false  ## Space was held to stand up: it is not also a jump until it is let go


func _ready() -> void:
	add_to_group(&"player")
	_spawn_position = global_position
	var health := get_node_or_null("Health") as Health
	if health:
		health.died.connect(_on_died)
	# Stay glued to the ground when running downhill or over bumps (a sprint at
	# 7 m/s otherwise hops off the ground for a frame) and keep speed on slopes.
	floor_snap_length = 0.5
	floor_constant_speed = true
	# Walking almost head-on into a wall (within 15 degrees of its normal, the default) stops dead instead of
	# sliding along it. Zero lets the player always slide (the village test walks 5 degrees off a wall; lesson 54).
	wall_min_slide_angle = 0.0


func _physics_process(delta: float) -> void:
	if sleeping:
		velocity = Vector3.ZERO
		_model.set_motion(0.0, true, 0.0)
		return
	if seat != null:
		velocity = Vector3.ZERO
		_model.set_motion(0.0, true, 0.0)
		if wants_stand_up():
			_jump_blocked = Input.is_action_pressed("jump")  # Space stood us up and may still be held: no hop off the bench
			_coyote = 0.0
			seat.stand_up(self)
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

	# Accelerate as a VECTOR toward the target velocity. Doing x and z separately made a diagonal heading
	# curve while speeding up, which left a sideways slide along any wall that is not axis-aligned (lesson 54).
	var flat_velocity := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), acceleration * delta)
	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.y
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	var forward := Vector2(-_body.global_transform.basis.z.x, -_body.global_transform.basis.z.z)
	# 1 = moving the way the body faces; below 0 = sliding backwards (a sharp turn at speed).
	var alignment := flat.normalized().dot(forward.normalized()) if flat.length() > 0.5 else 1.0
	_model.set_motion(flat.length(), is_on_floor(), velocity.y, alignment)

	if direction.length_squared() > 0.0:
		_face_direction(direction, delta)


## Dying (0 hp) is a knock-out, not a game over: back to the spawn point at full health, with a message.
func _on_died() -> void:
	respawn()
	(get_node("Health") as Health).revive()
	var hud := get_node_or_null("HUD") as InteractionPrompt
	if hud:
		hud.show_message("You were knocked out and woke up at the village spawn.", 4.0)


## Puts the player back at the spawn point, standing still.
func respawn() -> void:
	if seat != null:
		seat.stand_up(self)
	global_position = _spawn_position
	velocity = Vector3.ZERO


func _read_move_input() -> Vector2:
	if input_locked:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


## Held, not just pressed: keep holding Space and the character hops on every landing.
func wants_jump() -> bool:
	if _jump_blocked and not Input.is_action_pressed("jump"):
		_jump_blocked = false
	return not input_locked and not _jump_blocked and Input.is_action_pressed("jump")


func wants_sprint() -> bool:
	return not input_locked and Input.is_action_pressed("sprint")


func wants_interact() -> bool:
	# Not while seated (E stands up instead), and not on the frame a seat just changed: the press that sat or stood
	# the player must not also be read as a second command (that would sit them straight back down).
	return not input_locked and seat == null and Engine.get_physics_frames() != _seat_frame and Input.is_action_just_pressed("interact")


## A FRESH press of E, Space or a move key (a key still held from before sitting does not count). No frame stamp
## is needed here: the Interactor is a child node and ticks AFTER the player, so the press that sat the player is
## never seen again as "just pressed" on the next tick (a guard here would be dead code, untestable).
func wants_stand_up() -> bool:
	if input_locked:
		return false
	for action in ["interact", "jump", "move_forward", "move_back", "move_left", "move_right"]:
		if Input.is_action_just_pressed(action):
			return true
	return false


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
