class_name FishingSpot
extends Interactable
## A place to fish. Stand at the post, face the water and press E: the line is cast, you
## wait for a bite, and when the bobber dips (and a red "!" appears) press E again to reel
## it in. Press E too early and the fish is scared off; wait too long and it gets away;
## walk away and the line is pulled in.
##
## The node sits 1 m in FRONT of the standing spot (toward the water), so a player who
## faces the water has it ahead of them. Everything runs on the physics tick, with a
## random generator the tests can seed. Catches go into the player's journal
## (`PlayerProfile.current()`), which is saved.

signal caught(result: Dictionary)
signal state_changed(new_state: int)

enum State { IDLE, CASTING, WAITING, BITE, RESULT }

@export var wait_min: float = 2.0
@export var wait_max: float = 6.0
@export var bite_window: float = 1.4
@export var cast_seconds: float = 0.6
@export var cast_distance: float = 4.0
@export var walk_away_distance: float = 1.6
## Direction from the standing spot toward the water (set by whoever places the spot).
var toward_water := Vector3.FORWARD
var water_level := -0.6
var rng := RandomNumberGenerator.new()
var state: State = State.IDLE

## Tests and events can force the next catch (e.g. junk); cleared once used.
var next_catch_override: Dictionary = {}
var _air_frames := 0
var _timer := 0.0
var _angler: Node3D
var _origin := Vector3.ZERO
var _bobber: Node3D
var _line: MeshInstance3D
var _bang: Label3D
var _hud: InteractionPrompt
var _model: AnimalModel


func _init() -> void:
	prompt_text = "Cast your line"
	interact_range = 2.4
	rng.randomize()


func _ready() -> void:
	super._ready()
	_bobber = Node3D.new()
	_bobber.name = "Bobber"
	var top := _ball("Top", 0.13, Color(0.92, 0.12, 0.12), Vector3(0, 0.06, 0))
	var bottom := _ball("Bottom", 0.11, Color(0.98, 0.98, 0.98), Vector3(0, -0.06, 0))
	_bobber.add_child(top)
	_bobber.add_child(bottom)
	_bang = Label3D.new()
	_bang.text = "!"
	_bang.font_size = 200
	_bang.pixel_size = 0.008
	_bang.modulate = Color(1.0, 0.2, 0.2)
	_bang.outline_size = 24
	_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bang.position = Vector3(0, 0.8, 0)
	_bang.visible = false
	_bobber.add_child(_bang)
	_bobber.visible = false
	add_child(_bobber)
	_bobber.top_level = true
	_line = MeshInstance3D.new()
	_line.name = "Line"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.014
	cylinder.bottom_radius = 0.014
	cylinder.height = 1.0
	_line.mesh = cylinder
	var line_material := StandardMaterial3D.new()
	line_material.albedo_color = Color(0.95, 0.95, 0.9)
	_line.material_override = line_material
	_line.visible = false
	add_child(_line)
	_line.top_level = true


func get_prompt() -> String:
	match state:
		State.IDLE:
			return "Cast your line"
		State.CASTING, State.WAITING:
			return "Waiting for a bite... (E to pull in)"
		State.BITE:
			return "Reel in!"
	return ""


func can_interact(_who: Node3D) -> bool:
	return state != State.RESULT


func interact(who: Node3D) -> void:
	message = ""
	match state:
		State.IDLE:
			_cast(who)
		State.CASTING, State.WAITING:
			_end("You pulled in too early and scared the fish away.")
		State.BITE:
			_reel_in()
	super.interact(who)


## Where the standing spot is (1 m behind this node, away from the water).
func standing_spot() -> Vector3:
	return global_position - toward_water.normalized()


## Where the bobber lands.
func bobber_target() -> Vector3:
	return Vector3(standing_spot().x, water_level, standing_spot().z) + toward_water.normalized() * cast_distance


func is_night() -> bool:
	var clock := get_tree().get_first_node_in_group(&"day_night") as DayNight
	return clock != null and clock.is_night()


func _cast(who: Node3D) -> void:
	_angler = who
	_air_frames = 0
	_origin = who.global_position
	_hud = who.get_node_or_null("HUD") as InteractionPrompt
	_model = who.get_node_or_null("Body/Model") as AnimalModel
	if _model:
		_model.start_fishing()
	var body := who.get_node_or_null("Body") as Node3D
	if body:  # face the water
		body.rotation.y = atan2(-toward_water.x, -toward_water.z)
	_bobber.global_position = bobber_target()
	_bobber.visible = true
	_line.visible = true
	_timer = cast_seconds
	_set_state(State.CASTING)


func _reel_in() -> void:
	var result: Dictionary = next_catch_override if not next_catch_override.is_empty() else FishCatalog.roll(rng, is_night())
	next_catch_override = {}
	var profile := PlayerProfile.current()
	if not result["junk"]:
		profile.record_catch(result["id"], result["length_cm"])
		profile.save()
	var total: int = int(profile.fish.get(result["id"], {}).get("count", 0))
	if result["junk"]:
		message = "You reeled in an %s... (%.0f cm of nothing useful)" % [result["name"], result["length_cm"]]
	else:
		message = "You caught a %s! %.1f cm (you have caught %d)" % [result["name"], result["length_cm"], total]
	caught.emit(result)
	_finish(message)


func _end(text: String) -> void:
	message = text
	_finish(text)


func _finish(text: String) -> void:
	if _hud:
		_hud.show_message(text, 4.5)
	_stop_fishing()
	_timer = 0.6  # a short pause before the next cast
	_set_state(State.RESULT)


func _stop_fishing() -> void:
	_bobber.visible = false
	_line.visible = false
	_bang.visible = false
	if _model:
		_model.stop_fishing()


func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	if state == State.RESULT:
		_timer -= delta
		if _timer <= 0.0:
			_set_state(State.IDLE)
		return
	if _angler == null or not is_instance_valid(_angler):
		_end("")
		return
	if _angler is PlayerController and (_angler as PlayerController).input_locked:
		_end("You put your rod away.")  # a menu (the character screen) opened
		return
	# Off the ground for a few frames in a row (a jump), not one stray frame on a shore slope.
	_air_frames = _air_frames + 1 if not (_angler as CharacterBody3D).is_on_floor() else 0
	if _angler.global_position.distance_to(_origin) > walk_away_distance or _air_frames >= 4:
		_end("You walked away and pulled in your line.")
		return
	_timer -= delta
	var time := Time.get_ticks_msec() / 1000.0
	match state:
		State.CASTING:
			if _timer <= 0.0:
				_timer = rng.randf_range(wait_min, wait_max)
				_set_state(State.WAITING)
		State.WAITING:
			_bobber.global_position.y = water_level + sin(time * 2.0) * 0.015
			if _timer <= 0.0:
				_timer = bite_window
				_bang.visible = true
				_set_state(State.BITE)
		State.BITE:
			_bobber.global_position.y = water_level - 0.1 + sin(time * 20.0) * 0.02  # the bobber jerks under
			if _timer <= 0.0:
				_end("It got away...")
	_update_line()


func _update_line() -> void:
	var tip := _model.rod_tip_global() if _model else _angler.global_position + Vector3(0, 1.2, 0)
	var end := _bobber.global_position
	var middle := (tip + end) * 0.5
	var length := tip.distance_to(end)
	if length < 0.01:
		return
	var y_axis := (end - tip).normalized()
	var x_axis := y_axis.cross(Vector3.UP if absf(y_axis.y) < 0.99 else Vector3.RIGHT).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	_line.global_transform = Transform3D(Basis(x_axis, y_axis * length, z_axis), middle)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(int(new_state))


func _ball(node_name: String, radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	mesh.position = pos
	return mesh
