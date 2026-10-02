class_name InteractionPrompt
extends CanvasLayer
## The player's on-screen text: a "[E] Open door" prompt at the bottom of the
## screen and a message box near the top (notice boards etc.). Built in code so
## the player scene stays small. Lives on the player, so a networked game shows
## each player only their own prompt (the HUD is created per local player).

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _message_panel: PanelContainer
var _message_label: Label
var _message_timer: Timer


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_prompt_panel = _panel(root, Control.PRESET_CENTER_BOTTOM, -120)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_prompt_panel.add_child(row)
	var key := Label.new()
	key.text = " E "
	key.add_theme_font_size_override("font_size", 24)
	key.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(1.0, 0.92, 0.7)
	key_style.set_corner_radius_all(8)
	key.add_theme_stylebox_override("normal", key_style)
	row.add_child(key)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 24)
	row.add_child(_prompt_label)
	_prompt_panel.visible = false

	_message_panel = _panel(root, Control.PRESET_CENTER_TOP, 80)
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", 22)
	_message_label.custom_minimum_size.x = 520
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message_label)
	_message_panel.visible = false

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func(): _message_panel.visible = false)
	add_child(_message_timer)


## Shows "[E] <text>" at the bottom of the screen; empty text hides it.
func set_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_panel.visible = text != ""


func prompt_text() -> String:
	return _prompt_label.text if _prompt_panel.visible else ""


func show_message(text: String, seconds: float = 5.0) -> void:
	_message_label.text = text
	_message_panel.visible = true
	_message_timer.start(seconds)


func message_text() -> String:
	return _message_label.text if _message_panel.visible else ""


func _panel(root: Control, preset: Control.LayoutPreset, offset_y: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(preset)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = offset_y
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.78)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	return panel
