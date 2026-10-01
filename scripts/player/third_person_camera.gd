class_name ThirdPersonCamera
extends Node3D
## Over-the-shoulder orbit camera.
##
## Node layout (see scenes/player/player.tscn):
##   CameraRig (this, yaw)  ->  Pitch (pitch)  ->  SpringArm3D  ->  Camera3D
##
## The SpringArm3D pulls the camera in when something is between it and the
## player, which stops the camera clipping through walls. The mouse wheel
## changes the arm length (zoom). Esc frees the mouse, a click captures it.

@export var mouse_sensitivity: float = 0.003
@export var min_pitch_degrees: float = -60.0
@export var max_pitch_degrees: float = 35.0
@export var min_distance: float = 1.5
@export var max_distance: float = 8.0
@export var zoom_step: float = 0.5

@onready var _pitch: Node3D = $Pitch
@onready var _spring_arm: SpringArm3D = $Pitch/SpringArm3D


func _ready() -> void:
	# The rig is a sibling of the player's Body mesh, so turning the
	# character never drags the camera. Don't let the arm hit the player.
	_spring_arm.add_excluded_object(get_parent().get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative is raw pixels; `relative` is scaled by the window's
		# stretch factor, which would make sensitivity depend on window size.
		apply_look(event.screen_relative)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_set_distance(_spring_arm.spring_length - zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_distance(_spring_arm.spring_length + zoom_step)
			MOUSE_BUTTON_LEFT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Turns the camera by a mouse movement in pixels (right = turn right,
## up = look up). All look input goes through here, so tests and future
## input sources (gamepad, network) share one code path.
func apply_look(relative: Vector2) -> void:
	rotation.y -= relative.x * mouse_sensitivity
	_pitch.rotation.x = clampf(
		_pitch.rotation.x - relative.y * mouse_sensitivity,
		deg_to_rad(min_pitch_degrees),
		deg_to_rad(max_pitch_degrees)
	)


## World-space yaw of the camera, used to make movement camera-relative.
func get_yaw() -> float:
	return global_rotation.y


func _set_distance(distance: float) -> void:
	_spring_arm.spring_length = clampf(distance, min_distance, max_distance)
