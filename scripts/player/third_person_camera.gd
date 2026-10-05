class_name ThirdPersonCamera
extends Node3D
## Over-the-shoulder orbit camera.
##
## Node layout (see scenes/player/player.tscn):
##   CameraRig (this, yaw)  ->  Pitch (pitch)  ->  SpringArm3D  ->  Camera3D
##
## The SpringArm3D pulls the camera in when something is between it and the
## player, which stops the camera clipping through walls. The mouse wheel
## changes the arm length (zoom).
##
## Mouse, Roblox-style: the cursor is FREE by default (so menus and the paste box just work). HOLD the right mouse button to look around (the
## cursor is hidden while you do and comes back where it was). Press Alt for SHIFT LOCK: the mouse stays captured and always steers the camera,
## the character faces where the camera looks, and the camera moves over the right shoulder. Alt again (or Esc) turns it off. Shift is run.
##
## When the arm is squeezed short (backed into a wall or tree), the camera
## ends up almost inside the player. The player's body then fades out so it
## never fills the screen. The fade uses each body material's alpha:
## GeometryInstance3D.transparency is ignored by the Compatibility renderer
## (which CI and weak GPUs use), so the body would stay fully visible there.

@export var mouse_sensitivity: float = 0.003
@export var min_pitch_degrees: float = -60.0
@export var max_pitch_degrees: float = 35.0
@export var min_distance: float = 1.5
@export var max_distance: float = 8.0
@export var zoom_step: float = 0.5
## Camera pulled in closer than this (metres along the arm): the body starts to fade.
@export var fade_start_distance: float = 1.2
## At or closer than this the body is fully invisible.
@export var fade_end_distance: float = 0.5

## How far to the right of the player the camera sits, normally and with shift lock (the arm starts at the scene's value).
@export var shift_lock_shoulder: float = 0.95
@export var shoulder_speed: float = 6.0
## Zoomed in this close (or closer) the character is dead centre; the over-the-shoulder offset fades in as you zoom out to this distance.
@export var shoulder_full_distance: float = 4.0

signal shift_lock_changed(enabled: bool)

@onready var _pitch: Node3D = $Pitch
@onready var _spring_arm: SpringArm3D = $Pitch/SpringArm3D

## True while Alt-toggled shift lock is on.
var shift_lock := false
## True while the right mouse button is held to look around.
var look_held := false

var _model: AnimalModel
var _player: PlayerController
var _height := 1.5
var _last_fade := 0.0
var _base_shoulder := 0.5
var _saved_mouse := Vector2.ZERO


func _ready() -> void:
	# The rig is a sibling of the player's Body, so turning the
	# character never drags the camera. Don't let the arm hit the player.
	_spring_arm.add_excluded_object(get_parent().get_rid())
	# The model owns the body and outfit materials and fades them all together.
	_model = get_parent().get_node_or_null("Body/Model") as AnimalModel
	_base_shoulder = _spring_arm.position.x
	add_to_group(&"camera_rig")
	# Smoothness: physics runs at 60 ticks a second but a monitor may draw 144 frames. The player is interpolated between ticks by the engine; the
	# camera rig is NOT interpolated (it turns with the mouse between ticks) but follows the player's interpolated position every drawn frame.
	_player = get_parent() as PlayerController
	_height = position.y
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	top_level = true
	_follow_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # a free cursor; the right mouse button or shift lock takes it for looking


func _process(delta: float) -> void:
	_follow_player()
	# The camera glides over the shoulder when shift lock turns on and back when it turns off.
	_spring_arm.position.x = move_toward(_spring_arm.position.x, (shift_lock_shoulder if shift_lock else _base_shoulder) * smoothstep(min_distance, shoulder_full_distance, _spring_arm.spring_length), shoulder_speed * delta)
	var fade := 1.0 - smoothstep(fade_end_distance, fade_start_distance, _spring_arm.get_hit_length())
	if is_equal_approx(fade, _last_fade):
		return
	_last_fade = fade
	if _model:
		_model.set_fade(fade)


func _unhandled_input(event: InputEvent) -> void:
	if (get_parent() as PlayerController).input_locked:
		return
	if event.is_action_pressed("shift_lock"):
		set_shift_lock(not shift_lock)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative is raw pixels; `relative` is scaled by the window's
		# stretch factor, which would make sensitivity depend on window size.
		apply_look(event.screen_relative)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					begin_look()
				else:
					end_look()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_distance(_spring_arm.spring_length - zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_distance(_spring_arm.spring_length + zoom_step)
	elif event.is_action_pressed("ui_cancel"):
		set_shift_lock(false)
		end_look()


## Puts the rig at the player's position as it is DRAWN this frame (interpolated between physics ticks), at shoulder height.
func _follow_player() -> void:
	if _player != null and is_inside_tree():
		global_position = _player.get_global_transform_interpolated().origin + Vector3.UP * _height


## Right mouse button down: hide the cursor and let the mouse steer the camera.
func begin_look() -> void:
	if not look_held:
		_saved_mouse = get_viewport().get_mouse_position()
	look_held = true
	_apply_mouse_mode()


## Right mouse button up: the cursor comes back where it was (unless shift lock keeps the mouse).
func end_look() -> void:
	if not look_held:
		return
	look_held = false
	if not shift_lock:
		_apply_mouse_mode()
		Input.warp_mouse(_saved_mouse)


func set_shift_lock(enabled: bool) -> void:
	if shift_lock == enabled:
		return
	shift_lock = enabled
	_apply_mouse_mode()
	shift_lock_changed.emit(enabled)


## Where UI that freed the mouse (the character screen, the paste box) hands it back: free normally, taken only while the right button is held or
## shift lock is on. Also forgets a right-button state that ended while the UI was open.
func refresh_mouse() -> void:
	look_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and look_held
	_apply_mouse_mode()


func _apply_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if (shift_lock or look_held) else Input.MOUSE_MODE_VISIBLE


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
