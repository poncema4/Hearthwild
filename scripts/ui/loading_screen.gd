class_name LoadingScreen
extends CanvasLayer
## The loading screen: the picture fades to a dark blue cover with "Loading Hearthwild", a progress bar and a tip, holds while the bar fills (the game
## moves the player into place while nobody can see), then fades away. Used when a player joins; the sleep fade is a separate thing. It is a small state
## machine driven by `_process` so it is the same on a slow or a fast computer and tests can step it.
##
##   IDLE -> FADE_IN (0.4 s) -> HOLD (`hold_seconds`, the bar fills) -> FADE_OUT (0.5 s) -> IDLE
##
## `covered` is emitted the moment the screen is fully dark (the right moment to teleport the player); `finished` when it is gone again.

signal covered
signal finished

enum State { IDLE, FADE_IN, HOLD, FADE_OUT }

const FADE_IN_SECONDS := 0.4
const FADE_OUT_SECONDS := 0.5
const TIPS := [
	"Tip: a bed sets your respawn point, day or night.",
	"Tip: zombies come out at night, and burn in the sun.",
	"Tip: press 1 to 5 to equip a weapon; the rack in the village has more.",
	"Tip: press F2 any time to change your look.",
	"Tip: fish bite at different times of day: try the lake at night.",
]

var state := State.IDLE
var hold_seconds := 2.0
var tip_index := 0

var _root: Control
var _cover: ColorRect
var _content: Control
var _bar: ProgressBar
var _tip: Label
var _clock := 0.0


func _ready() -> void:
	layer = 40
	add_to_group(&"loading_screen")
	_build_ui()
	_root.visible = false
	set_process(false)


## Starts the fade, hold and fade. `seconds` is how long the bar takes to fill.
func begin(seconds: float = 2.0) -> void:
	hold_seconds = maxf(seconds, 0.1)
	state = State.FADE_IN
	_clock = 0.0
	tip_index = (tip_index + 1) % TIPS.size()
	_tip.text = TIPS[tip_index]
	_bar.value = 0.0
	_root.visible = true
	_set_alpha(0.0)
	set_process(true)


func is_active() -> bool:
	return state != State.IDLE


## 0 when clear, 1 when fully dark.
func alpha() -> float:
	return _cover.color.a


## How full the bar is, 0 to 1.
func progress() -> float:
	return _bar.value


func tip_text() -> String:
	return _tip.text


func _process(delta: float) -> void:
	_clock += delta
	match state:
		State.FADE_IN:
			_set_alpha(clampf(_clock / FADE_IN_SECONDS, 0.0, 1.0))
			if _clock >= FADE_IN_SECONDS:
				state = State.HOLD
				_clock = 0.0
				_set_alpha(1.0)
				covered.emit()
		State.HOLD:
			_bar.value = clampf(_clock / hold_seconds, 0.0, 1.0)
			if _clock >= hold_seconds:
				_bar.value = 1.0
				state = State.FADE_OUT
				_clock = 0.0
		State.FADE_OUT:
			_set_alpha(1.0 - clampf(_clock / FADE_OUT_SECONDS, 0.0, 1.0))
			if _clock >= FADE_OUT_SECONDS:
				state = State.IDLE
				_root.visible = false
				_set_alpha(0.0)
				set_process(false)
				finished.emit()


func _set_alpha(a: float) -> void:
	_cover.color.a = a
	_content.modulate.a = a


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind it can be clicked while it covers the screen
	add_child(_root)
	_cover = ColorRect.new()
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.color = Color(0.05, 0.08, 0.16, 0.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cover)
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_content.grow_vertical = Control.GROW_DIRECTION_BOTH
	(_content as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_content as VBoxContainer).add_theme_constant_override("separation", 18)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_content)
	var title := Label.new()
	title.text = "Loading Hearthwild..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_content.add_child(title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(420, 22)
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_content.add_child(_bar)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_font_size_override("font_size", 20)
	_tip.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_content.add_child(_tip)
