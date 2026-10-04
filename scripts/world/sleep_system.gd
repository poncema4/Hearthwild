class_name SleepSystem
extends CanvasLayer
## Sleeping through the night: lie down in a bed (E, after 7 PM and before 6 AM), the screen
## fades to black, the clock fast-forwards to 6:30 AM, then it fades back in and you wake up
## beside the bed with a "Good morning". The player is locked while asleep.
##
## Phases (all on the physics tick): LYING_DOWN (0.9 s, the character slides onto the bed and lies
## down) -> FADE_OUT (1.0 s) -> SLEEPING (2.5 s, black, the clock runs to the morning) -> FADE_IN
## (1.0 s, already standing beside the bed: the move happens while the screen is black) -> AWAKE.
## The clock is paused from the moment you lie down until you are awake, then handed back as it was.
##
## Multiplayer note: world time is one shared clock, so a networked game must not let one
## player skip the night while others play (the vision's "sleep voting"); `try_sleep` is the
## single entry point that rule will hook into.

signal fell_asleep(player: Node3D)
signal woke_up(player: Node3D)

enum State { AWAKE, LYING_DOWN, FADE_OUT, SLEEPING, FADE_IN }

const EARLIEST_HOUR := 19.0  # beds work from 7 PM ...
const LATEST_HOUR := 6.0  # ... until 6 AM
const WAKE_HOUR := 6.5

@export var lying_seconds: float = 0.9
@export var fade_seconds: float = 1.0
@export var sleeping_seconds: float = 2.5

var state: State = State.AWAKE

var _overlay: ColorRect
var _timer := 0.0
var _player: PlayerController
var _bed: Bed
var _model: AnimalModel
var _clock: DayNight
var _start_hour := 0.0
var _target_hour := 0.0
var _clock_was_paused := false
var _from_position := Vector3.ZERO
var _from_yaw := 0.0


func _ready() -> void:
	layer = 15
	add_to_group(&"sleep_system")
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.03, 0.07, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func is_sleeping() -> bool:
	return state != State.AWAKE


## 0 = clear screen, 1 = black.
func overlay_alpha() -> float:
	return _overlay.color.a


func can_sleep_now() -> bool:
	var clock := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if clock == null:
		return false
	return clock.hour >= EARLIEST_HOUR or clock.hour < LATEST_HOUR


## Starts sleeping in `bed`. Returns "" on success, otherwise the reason (shown to the player).
func try_sleep(who: Node3D, bed: Bed) -> String:
	if is_sleeping():
		return ""
	var sitting := who as PlayerController
	if sitting != null and sitting.seat != null:
		return "Stand up first."
	if not can_sleep_now():
		return "You're not tired yet. Beds work after 7 PM."
	_player = who as PlayerController
	_model = who.get_node_or_null("Body/Model") as AnimalModel
	_clock = get_tree().get_first_node_in_group(&"day_night") as DayNight
	if _player == null or _model == null or _clock == null:
		return ""
	_bed = bed
	_player.input_locked = true
	_player.sleeping = true
	_from_position = _player.global_position
	_from_yaw = (_player.get_node("Body") as Node3D).rotation.y
	_model.set_sleeping(true)
	_start_hour = _clock.hour
	_target_hour = WAKE_HOUR + (24.0 if _start_hour >= EARLIEST_HOUR else 0.0)
	_clock_was_paused = _clock.paused
	_clock.paused = true  # from now on this system owns the clock (no drift while lying down, no rewind later)
	_timer = lying_seconds
	state = State.LYING_DOWN
	fell_asleep.emit(who)
	return ""


func _physics_process(delta: float) -> void:
	if state == State.AWAKE:
		return
	_timer -= delta
	match state:
		State.LYING_DOWN:
			# Slide onto the mattress and turn so the model's back (+Z) points along the bed.
			var slide := smoothstep(0.0, 1.0, 1.0 - maxf(_timer, 0.0) / lying_seconds)
			var head := _bed.head_direction()
			_player.global_position = _from_position.lerp(_bed.foot_point(), slide)
			(_player.get_node("Body") as Node3D).rotation.y = lerp_angle(_from_yaw, atan2(head.x, head.z), slide)
			if _timer <= 0.0:
				_timer = fade_seconds
				state = State.FADE_OUT
		State.FADE_OUT:
			_set_alpha(1.0 - maxf(_timer, 0.0) / fade_seconds)
			if _timer <= 0.0:
				_timer = sleeping_seconds
				state = State.SLEEPING
		State.SLEEPING:
			var progress := 1.0 - maxf(_timer, 0.0) / sleeping_seconds
			_clock.set_time(lerpf(_start_hour, _target_hour, smoothstep(0.0, 1.0, progress)))
			if _timer <= 0.0:
				_clock.set_time(WAKE_HOUR)
				# The screen is black: stand up beside the bed, facing away from it, before the fade-in.
				var away := _bed.getting_up_point() - _bed.global_position
				away.y = 0.0
				away = away.normalized()
				_player.global_position = _bed.getting_up_point()
				(_player.get_node("Body") as Node3D).rotation.y = atan2(-away.x, -away.z)
				_model.set_sleeping(false, true)
				_timer = fade_seconds
				state = State.FADE_IN
		State.FADE_IN:
			_set_alpha(maxf(_timer, 0.0) / fade_seconds)
			if _timer <= 0.0:
				_set_alpha(0.0)
				_clock.paused = _clock_was_paused
				_player.sleeping = false
				_player.input_locked = false
				state = State.AWAKE
				var hud := _player.get_node_or_null("HUD") as InteractionPrompt
				if hud:
					hud.show_message("Good morning, %s!" % PlayerProfile.current().display_name, 4.0)
				woke_up.emit(_player)


func _set_alpha(alpha: float) -> void:
	_overlay.color.a = clampf(alpha, 0.0, 1.0)
