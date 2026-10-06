class_name InteractionPrompt
extends CanvasLayer
## The player's on-screen text: a "[E] Open door" prompt at the bottom of the
## screen, a message box near the top (notice boards etc.), the clock and the
## HP bar (under the clock, following the sibling node "Health"), the shift-lock reticle (a dot in the middle of the screen while Alt shift lock is on) and
## the F3 input overlay (which keys and mouse buttons the game is receiving right now, so a keyboard that drops a key shows up). Built in code so
## the player scene stays small. Lives on the player, so a networked game shows
## each player only their own prompt (the HUD is created per local player).

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _hotbar: HBoxContainer
var _hotbar_hint: Label
var _hotbar_selected := -1
var _message_panel: PanelContainer
var _message_label: Label
var _message_timer: Timer
var _clock: Label
var _hp_bar: ProgressBar
var _reticle: Panel
var _input_label: Label
var _held_keys := {}
var _hp_label: Label


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

	_clock = Label.new()
	_clock.position = Vector2(20, 14)
	_clock.add_theme_font_size_override("font_size", 24)
	_clock.add_theme_color_override("font_color", Color(1, 1, 1))
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_clock.add_theme_constant_override("outline_size", 6)
	root.add_child(_clock)

	_build_hp_bar(root)
	_build_hotbar(root)
	_build_reticle(root)
	_input_label = Label.new()
	_input_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_input_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_input_label.position = Vector2(-20, 14)
	_input_label.add_theme_font_size_override("font_size", 18)
	_input_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_input_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_input_label.add_theme_constant_override("outline_size", 6)
	_input_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_input_label.visible = false
	root.add_child(_input_label)
	var rig := get_parent().get_node_or_null("CameraRig") as ThirdPersonCamera
	if rig:
		rig.shift_lock_changed.connect(_on_shift_lock_changed)

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func(): _message_panel.visible = false)
	add_child(_message_timer)


## The Minecraft-style weapon bar along the bottom: one square slot per weapon with its key number, a little coloured icon and its name. The slot in
## hand is bright with a gold border; a locked one is dim. With nothing in hand a hint line above the bar says the fists are ready (F or click).
## Every weapon slot is exactly this wide and tall (a slot used to grow to fit the name of the weapon in it).
const HOTBAR_SLOT := 90
const ICON_COLORS := [Color(0.62, 0.45, 0.28), Color(0.62, 0.62, 0.64), Color(0.80, 0.70, 0.45), Color(0.72, 0.74, 0.80), Color(0.30, 0.31, 0.36)]

func _build_hotbar(root: Control) -> void:
	var column := VBoxContainer.new()
	column.name = "HotbarColumn"
	column.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_top = -112
	column.offset_bottom = -14
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	_hotbar_hint = Label.new()
	_hotbar_hint.name = "Hint"
	_hotbar_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_hint.add_theme_font_size_override("font_size", 15)
	_hotbar_hint.add_theme_color_override("font_color", Color(1, 1, 1))
	_hotbar_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hotbar_hint.add_theme_constant_override("outline_size", 4)
	_hotbar_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hotbar_hint)
	_hotbar = HBoxContainer.new()
	_hotbar.name = "Hotbar"
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar.add_theme_constant_override("separation", 6)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hotbar)
	for i in Weapons.count():
		var slot := PanelContainer.new()
		slot.name = "Slot%d" % (i + 1)
		slot.custom_minimum_size = Vector2(HOTBAR_SLOT, HOTBAR_SLOT)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.clip_contents = true
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(box)
		var number := Label.new()
		number.name = "Number"
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", 13)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(number)
		var icon := WeaponIcon.new(i)
		icon.name = "Icon"
		box.add_child(icon)
		var label := Label.new()
		label.name = "Name"
		label.add_theme_font_size_override("font_size", 11)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true  # a long name ("Wooden Sword") must not make its slot wider than the others
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size = Vector2(HOTBAR_SLOT - 12, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		_hotbar.add_child(slot)
	set_hotbar(-1, [true, false, false, false, false])


## Refreshes the weapon bar: `selected` is the slot in hand (-1 = nothing, the fists), `unlocked` says which weapons the player has.
func set_hotbar(selected: int, unlocked: Array) -> void:
	if _hotbar == null:
		return
	_hotbar_selected = selected
	for i in Weapons.count():
		var slot := _hotbar.get_child(i) as PanelContainer
		var box := slot.get_child(0) as VBoxContainer
		var have: bool = unlocked[i]
		(box.get_node("Name") as Label).text = String(Weapons.def(i)["name"]) if have else "locked"
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.set_content_margin_all(5)
		var chosen := i == selected
		style.bg_color = Color(1.0, 0.92, 0.7, 0.95) if chosen else Color(0.1, 0.12, 0.16, 0.72 if have else 0.4)
		style.set_border_width_all(3 if chosen else 1)
		style.border_color = Color(1.0, 0.78, 0.2) if chosen else Color(1, 1, 1, 0.25)
		slot.add_theme_stylebox_override("panel", style)
		var ink := Color(0.15, 0.1, 0.05) if chosen else (Color(1, 1, 1) if have else Color(0.6, 0.62, 0.66))
		(box.get_node("Number") as Label).add_theme_color_override("font_color", ink)
		(box.get_node("Name") as Label).add_theme_color_override("font_color", ink)
		var icon := box.get_node("Icon") as WeaponIcon
		icon.dim = not have
		icon.queue_redraw()
	var def := Weapons.def(selected)
	var stats := "damage %d, reach %.1f m" % [int(def["damage"]), float(def["reach"])]
	if selected < 0:
		_hotbar_hint.text = "Fists ready: F or left click to punch (%s). Press 1 to 5 to equip a weapon" % stats
	elif Weapons.is_gun(selected):
		_hotbar_hint.text = "%s: left click or F to shoot (%s, range %d m)" % [String(def["name"]), stats, int(def["reach"])]
	else:
		_hotbar_hint.text = "%s: left click or F to swing (%s). Press %d again to put it away" % [String(def["name"]), stats, selected + 1]


## The sweep on the weapon in hand: a dark cover over its slot that shrinks as the weapon becomes ready again (`fraction` 1 = just used, 0 = ready).
func set_cooldown(fraction: float) -> void:
	if _hotbar == null or _hotbar_selected < 0:
		for i in _hotbar.get_child_count():
			_cooldown_cover(i).visible = false
		return
	for i in _hotbar.get_child_count():
		var cover := _cooldown_cover(i)
		cover.visible = i == _hotbar_selected and fraction > 0.01
		if cover.visible:
			var slot := _hotbar.get_child(i) as Control
			cover.size = Vector2(slot.size.x, slot.size.y * clampf(fraction, 0.0, 1.0))
			cover.position = Vector2(0, slot.size.y - cover.size.y)


func _cooldown_cover(slot_index: int) -> ColorRect:
	var slot := _hotbar.get_child(slot_index) as Control
	var cover := slot.get_node_or_null("Cooldown") as ColorRect
	if cover == null:
		cover = ColorRect.new()
		cover.name = "Cooldown"
		cover.color = Color(0.0, 0.0, 0.0, 0.5)
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.top_level = false
		cover.set_anchors_preset(Control.PRESET_TOP_LEFT)
		slot.add_child(cover)
		cover.visible = false
	return cover


## The bar as text, one entry per slot ("1 Wooden Sword", "2 locked"), for tests.
func hotbar_text() -> String:
	var parts: Array[String] = []
	for i in _hotbar.get_child_count():
		var box := (_hotbar.get_child(i) as PanelContainer).get_child(0) as VBoxContainer
		parts.append("%d %s" % [i + 1, (box.get_node("Name") as Label).text])
	return " | ".join(parts)


## The size of every slot, for tests (they must all be the same).
func hotbar_slot_sizes() -> Array[Vector2]:
	var sizes: Array[Vector2] = []
	for slot in _hotbar.get_children():
		sizes.append((slot as Control).size)  # the real laid-out size: only meaningful in a rendered run (the dummy renderer measures no text)
	return sizes


func hotbar_selected() -> int:
	return _hotbar_selected


func hotbar_hint() -> String:
	return _hotbar_hint.text


func _build_hp_bar(root: Control) -> void:
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(20, 54)
	_hp_bar.custom_minimum_size = Vector2(220, 24)
	_hp_bar.size = _hp_bar.custom_minimum_size
	_hp_bar.show_percentage = false
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.12, 0.16, 0.78)
	back.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.22, 0.27)
	fill.set_corner_radius_all(8)
	_hp_bar.add_theme_stylebox_override("background", back)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(_hp_bar)
	_hp_label = Label.new()
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 16)
	_hp_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hp_label.add_theme_constant_override("outline_size", 4)
	_hp_bar.add_child(_hp_label)
	var health := get_parent().get_node_or_null("Health") as Health
	if health:
		health.changed.connect(_on_health_changed)
		_on_health_changed(health.current, health.max_health)
	else:
		_hp_bar.visible = false


func _on_health_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "%d / %d" % [ceili(current), ceili(maximum)]


func _process(_delta: float) -> void:
	var clock := get_tree().get_first_node_in_group(&"day_night") as DayNight
	_clock.text = clock.clock_text() if clock else ""
	if _input_label.visible:
		_input_label.text = input_debug_text()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.pressed:
			_held_keys[code] = true
		else:
			_held_keys.erase(code)
	if event.is_action_pressed("toggle_input_debug"):
		_input_label.visible = not _input_label.visible
		if _input_label.visible:
			_input_label.text = input_debug_text()


## What the game is receiving right now: held keys (from the key events themselves, so a key the keyboard stops reporting disappears from this
## list), held mouse buttons, mouse mode, speed and frame rate. F3 shows it. If W vanishes from "Keys" when you press E, the keyboard or the
## operating system dropped it (many keyboards cannot report three particular keys at once); if W stays, the game has the key.
func input_debug_text() -> String:
	var names := []
	for code in _held_keys:
		names.append(OS.get_keycode_string(code))
	names.sort()
	var buttons := []
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(button):
			buttons.append({MOUSE_BUTTON_LEFT: "Left", MOUSE_BUTTON_RIGHT: "Right", MOUSE_BUTTON_MIDDLE: "Middle"}[button])
	var mode: String = {Input.MOUSE_MODE_VISIBLE: "free", Input.MOUSE_MODE_CAPTURED: "captured", Input.MOUSE_MODE_HIDDEN: "hidden"}.get(Input.mouse_mode, "other")
	var body := get_parent() as CharacterBody3D
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0
	return "INPUT (F3 hides)\nKeys: %s\nMouse buttons: %s   cursor: %s\nSpeed %.1f m/s   %d fps" % [
			"  ".join(names) if not names.is_empty() else "none", "  ".join(buttons) if not buttons.is_empty() else "none", mode, speed, Engine.get_frames_per_second()]


func input_debug_visible() -> bool:
	return _input_label.visible


func reticle_visible() -> bool:
	return _reticle.visible


func _on_shift_lock_changed(enabled: bool) -> void:
	_reticle.visible = enabled
	show_message("Shift Lock ON: the mouse steers the camera (Alt turns it off)" if enabled else "Shift Lock OFF: hold the right mouse button to look around", 2.5)


func _build_reticle(root: Control) -> void:
	_reticle = Panel.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.offset_left = -5.0
	_reticle.offset_right = 5.0
	_reticle.offset_top = -5.0
	_reticle.offset_bottom = 5.0
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.9)
	style.set_corner_radius_all(5)
	style.set_border_width_all(2)
	style.border_color = Color(0, 0, 0, 0.7)
	_reticle.add_theme_stylebox_override("panel", style)
	_reticle.visible = false
	root.add_child(_reticle)


func clock_text() -> String:
	return _clock.text


## "37 / 100" while the HP bar shows; empty when the player has no Health node.
func hp_text() -> String:
	return _hp_label.text if _hp_bar.visible else ""


## How full the bar is drawn, 0.0 to 1.0 (what the player sees, not the Health value).
func hp_fraction() -> float:
	return _hp_bar.ratio


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
