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

@onready var _pitch: Node3D = $Pitch
@onready var _spring_arm: SpringArm3D = $Pitch/SpringArm3D

var _body_materials: Array[StandardMaterial3D] = []
var _last_fade := 0.0


func _ready() -> void:
	# The rig is a sibling of the player's Body mesh, so turning the
	# character never drags the camera. Don't let the arm hit the player.
	_spring_arm.add_excluded_object(get_parent().get_rid())
	var body := get_parent().get_node_or_null("Body")
	if body:
		for child in body.get_children():
			var mesh := child as MeshInstance3D
			var material := mesh.get_surface_override_material(0) as StandardMaterial3D if mesh else null
			if material:
				# A private copy, so fading never touches a shared resource.
				material = material.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(0, material)
				_body_materials.append(material)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var fade := 1.0 - smoothstep(fade_end_distance, fade_start_distance, _spring_arm.get_hit_length())
	if is_equal_approx(fade, _last_fade):
		return
	_last_fade = fade
	for material in _body_materials:
		material.albedo_color.a = 1.0 - fade
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if fade > 0.001 else BaseMaterial3D.TRANSPARENCY_DISABLED


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
