class_name MainMenu
extends CanvasLayer
## The title screen shown over the world when the game starts: Hearthwild, a short line about the game, and four buttons: Play (on to the character
## screen), Info (what the game is about and every key), Settings (fullscreen and volume) and Quit. The world is already loaded behind a dim cover, so
## pressing Play never waits; the loading screen comes after the character screen (`GameFlow`).
##
## Keyboard works too: the first button has the focus (Enter plays), Tab and the arrows move, Esc goes back from Info or Settings. Everything the screen does
## is also a method (`press_play`, `show_info`, `show_settings`, `show_home`, `set_volume`, `set_fullscreen`), which is how the tests drive it.

signal play_pressed

## Tests switch this off before the first frame so the world starts playable.
@export var enabled := true
@export var player_path: NodePath = ^"../Player"

const TITLE := "Hearthwild"
const TAGLINE := "A cozy village for friends. Zombies come out after dark."
const INFO_TEXT := """Hearthwild is a cozy third-person village game: by day you explore the meadow, fish in the lake, dress your animal, sit with friends and watch the big screen; when night falls the zombies come, so you sleep in a bed (or fight them: they burn in the sun).

Controls
W A S D  walk      Shift  run      Space  jump (hold to keep hopping)
Mouse wheel  zoom      Hold right mouse button  look around      Alt  shift lock
E  use doors, beds, benches, the rack and the notice board
F or left click  attack (fists with nothing equipped)      1 to 5  equip a weapon (again = put away)
F2  change your character      F3  show the keys the game receives
A bed sets your respawn point, day or night, and lets you sleep from 7 PM."""

var is_open := false
var screen := "home"  ## "home", "info" or "settings"

var _player: PlayerController
var _root: Control
var _home: Control
var _info: Control
var _settings: Control
var _play_button: Button
var _fullscreen_box: CheckBox
var _volume_slider: HSlider


func _ready() -> void:
	layer = 30
	add_to_group(&"main_menu")
	_player = get_node_or_null(player_path) as PlayerController
	_build_ui()
	_root.visible = false
	if enabled:
		open()


## Shows the title screen: the player cannot move and the mouse is free.
func open() -> void:
	is_open = true
	_root.visible = true
	show_home()
	if _player:
		_player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Hides it (Play does this); it does not touch the player lock: the flow decides what comes next.
func close() -> void:
	is_open = false
	_root.visible = false


func press_play() -> void:
	if not is_open:
		return
	close()
	play_pressed.emit()


func show_home() -> void:
	screen = "home"
	_home.visible = true
	_info.visible = false
	_settings.visible = false
	if is_open and is_inside_tree():
		_play_button.grab_focus.call_deferred()


func show_info() -> void:
	screen = "info"
	_home.visible = false
	_info.visible = true
	_settings.visible = false


func show_settings() -> void:
	screen = "settings"
	_home.visible = false
	_info.visible = false
	_settings.visible = true


## The master volume, 0 (silent) to 1 (full); applied to the audio bus at once.
func set_volume(linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(0, linear <= 0.0001)
	_volume_slider.set_value_no_signal(linear)


func volume() -> float:
	return 0.0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0))


func set_fullscreen(on: bool) -> void:
	_fullscreen_box.set_pressed_no_signal(on)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## What the Info screen says (tests check that the controls are listed).
func info_text() -> String:
	return INFO_TEXT


func button_texts() -> Array[String]:
	var texts: Array[String] = []
	for child in (_home.get_node("Buttons") as Control).get_children():
		texts.append((child as Button).text)
	return texts


func _input(event: InputEvent) -> void:
	if is_open and screen != "home" and event.is_action_pressed("ui_cancel"):
		show_home()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var cover := ColorRect.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.color = Color(0.05, 0.08, 0.14, 0.62)  # the live world shows through
	_root.add_child(cover)

	_home = _centered(_root)
	var title := _label(_home, TITLE, 84, Color(1.0, 0.92, 0.7))
	title.name = "Title"
	_label(_home, TAGLINE, 22, Color(0.9, 0.94, 1.0)).name = "Tagline"
	_spacer(_home, 28)
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 12)
	_home.add_child(buttons)
	_play_button = _button(buttons, "Play", press_play)
	_button(buttons, "Info", show_info)
	_button(buttons, "Settings", show_settings)
	_button(buttons, "Quit", func(): get_tree().quit())

	_info = _centered(_root)
	_label(_info, "About Hearthwild", 40, Color(1.0, 0.92, 0.7))
	var info_label := _label(_info, INFO_TEXT, 19, Color(1, 1, 1))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(760, 0)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spacer(_info, 12)
	_button(_info, "Back", show_home)

	_settings = _centered(_root)
	_label(_settings, "Settings", 40, Color(1.0, 0.92, 0.7))
	_fullscreen_box = CheckBox.new()
	_fullscreen_box.text = "Fullscreen"
	_fullscreen_box.add_theme_font_size_override("font_size", 24)
	_fullscreen_box.toggled.connect(func(on: bool): set_fullscreen(on))
	_settings.add_child(_fullscreen_box)
	_label(_settings, "Volume", 24, Color(1, 1, 1))
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.value = 1.0
	_volume_slider.custom_minimum_size = Vector2(320, 28)
	_volume_slider.value_changed.connect(func(v: float): set_volume(v))
	_settings.add_child(_volume_slider)
	_spacer(_settings, 12)
	_button(_settings, "Back", show_home)


func _centered(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	return box


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)
	return label


func _spacer(parent: Control, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 56)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
