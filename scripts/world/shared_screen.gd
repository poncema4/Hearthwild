class_name SharedScreen
extends Node3D
## The village's big screen, where players will watch YouTube together: a wide screen on two posts with two rows of
## benches in front of it, facing the plaza. Pressing E at the screen opens a small box to paste a YouTube link.
##
## For now the screen only remembers WHICH video was chosen (`video_id`) and says so on its face: actually playing
## it for everyone belongs to multiplayer (one shared state; `url_changed` is the hook the network will send).
## Nothing is ever downloaded or opened: a pasted link is reduced to its 11-character video id and the rest is thrown
## away (`parse_youtube_id`), so a hostile link can do nothing.
##
## Everything the box does is also a method (`open_dialog`, `submit`, `clear`, `close_dialog`), which is how the
## tests drive it. While the box is open the player cannot move and the mouse is free (as in the character screen).

signal url_changed(video_id: String)

const WIDTH := 8.0
const HEIGHT := 4.5
const SCREEN_BOTTOM := 1.6
const NOT_A_LINK := "That is not a YouTube link. Try one like youtube.com/watch?v=... or youtu.be/..."

var video_id := ""
var dialog_open := false
var benches: Array[Node3D] = []
var interactable: Interactable

var _label: Label3D
var _layer: CanvasLayer
var _panel: PanelContainer
var _edit: LineEdit
var _message: Label
var _player: PlayerController


func _ready() -> void:
	_build_structure()
	_build_seating()
	interactable = Interactable.new()
	interactable.name = "ChooseVideo"
	interactable.prompt_text = "Choose what to watch"
	interactable.interact_range = 3.2
	interactable.position = Vector3(0, 0.9, 0.35)  # at the screen itself, so anyone standing in front of it (0.55 m to the benches) has it ahead
	interactable.interacted.connect(open_dialog)
	add_child(interactable)
	_refresh_label()


## The 11-character video id inside a YouTube link, or "" if this is not a YouTube link. Accepted:
## youtube.com/watch?v=ID (also www., m., music.), youtu.be/ID, youtube.com/shorts/ID, /embed/ID, /live/ID, with or
## without https://, with any extra parameters. Rejected: every other host (including look-alikes such as
## youtube.com.evil.com or youtube.com@evil.com), other schemes, ports, ids of the wrong shape.
static func parse_youtube_id(raw: String) -> String:
	var text := raw.strip_edges()
	if text.is_empty() or text.length() > 300:
		return ""
	var lower := text.to_lower()
	if lower.begins_with("https://"):
		text = text.substr(8)
	elif lower.begins_with("http://"):
		text = text.substr(7)
	var cut := text.length()
	for separator in ["/", "?", "#"]:
		var at := text.find(separator)
		if at != -1:
			cut = mini(cut, at)
	var host := text.substr(0, cut).to_lower()  # "ftp://x" / "file:///x" / "javascript:..." leave a ":" here and are refused below
	var rest := text.substr(cut)
	var fragment_at := rest.find("#")
	if fragment_at != -1:
		rest = rest.substr(0, fragment_at)  # a "?v=" inside the fragment is not a query: it is dropped with it
	if host.is_empty() or host.contains(":") or host.contains("@") or host.contains(" ") or host.contains("\\"):
		return ""  # a port, user info (youtube.com@evil.com), javascript:..., spaces
	for prefix in ["www.", "m.", "music."]:
		if host.begins_with(prefix):
			host = host.substr(prefix.length())
			break
	var candidate := ""
	var path := rest
	var query := ""
	var question := rest.find("?")
	if question != -1:
		path = rest.substr(0, question)
		query = rest.substr(question + 1)
	if path.contains("..") or path.contains("%") or path.contains("\\"):
		return ""  # path tricks: a browser would not open the link you think it is
	match host:
		"youtu.be":
			candidate = path.trim_prefix("/").get_slice("/", 0)
		"youtube.com", "youtube-nocookie.com":
			if path == "/watch":
				for pair in query.split("&"):
					if pair.begins_with("v="):
						candidate = pair.substr(2)
						break
			else:
				for kind in ["/shorts/", "/embed/", "/live/"]:
					if path.begins_with(kind):
						candidate = path.substr(kind.length()).get_slice("/", 0)
						break
	var valid := candidate.length() == 11
	for i in candidate.length():
		var c := candidate.unicode_at(i)
		var ok := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 45 or c == 95
		valid = valid and ok
	return candidate if valid else ""


func _exit_tree() -> void:
	if dialog_open:  # never leave a player locked behind a box that no longer exists
		close_dialog()


## Sets the video from a pasted link. Returns "" on success, otherwise the reason (also shown in the box).
func submit(text: String) -> String:
	var parsed := parse_youtube_id(text)
	if parsed.is_empty():
		if _message:
			_message.text = NOT_A_LINK
		return NOT_A_LINK
	_set_video(parsed)
	close_dialog()
	var hud := _player.get_node_or_null("HUD") as InteractionPrompt if _player else null
	if hud:
		hud.show_message("Now showing on the big screen: youtu.be/%s" % parsed, 5.0)
	return ""


## Takes the video off the screen.
func clear() -> void:
	_set_video("")


func open_dialog(who: Node3D) -> void:
	if dialog_open:
		return
	_player = who as PlayerController
	if _layer == null:
		_build_dialog()
	dialog_open = true
	_layer.visible = true
	_message.text = ""
	_edit.text = ""
	if _player:
		_player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_edit.grab_focus.call_deferred()


func close_dialog() -> void:
	if not dialog_open:
		return
	dialog_open = false
	_layer.visible = false
	if _player:
		_player.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The on-screen rectangle of the box (for the fit-in-window check).
func dialog_rect() -> Rect2:
	return _panel.get_global_rect() if _panel else Rect2()


func screen_text() -> String:
	return _label.text if _label else ""


## The measured size (m) of the text on the screen's face, so a test can check it fits (it once ran off both edges).
func screen_text_size() -> Vector2:
	if _label == null:
		return Vector2.ZERO
	var box := _label.get_aabb()
	return Vector2(box.size.x, box.size.y)


func _input(event: InputEvent) -> void:
	if dialog_open and event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()


func _set_video(new_id: String) -> void:
	if new_id == video_id:
		return
	video_id = new_id
	_refresh_label()
	url_changed.emit(video_id)


func _refresh_label() -> void:
	if _label == null:
		return
	if video_id.is_empty():
		_label.text = "HEARTHWILD THEATER\n\nPress E at the screen\nto choose what to watch"
	else:
		_label.text = "NOW SHOWING\n\nyoutu.be/%s\n\n(playing it together\ncomes with multiplayer)" % video_id


func _build_structure() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	var wood := _material(VillageProps.DARK_WOOD)
	for side in [-1.0, 1.0]:
		_box(body, "Post", Vector3(0.4, SCREEN_BOTTOM + HEIGHT + 0.5, 0.4), Vector3(side * (WIDTH * 0.5 + 0.3), (SCREEN_BOTTOM + HEIGHT + 0.5) * 0.5, 0), wood, true)
	_box(body, "Frame", Vector3(WIDTH + 0.5, HEIGHT + 0.5, 0.3), Vector3(0, SCREEN_BOTTOM + HEIGHT * 0.5, 0), wood, true)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.06, 0.09, 0.16)
	glass.emission_enabled = true
	glass.emission = Color(0.10, 0.17, 0.32)
	glass.emission_energy_multiplier = 0.7
	var face := MeshInstance3D.new()
	face.name = "Face"
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	face.mesh = quad
	face.material_override = glass
	face.position = Vector3(0, SCREEN_BOTTOM + HEIGHT * 0.5, 0.17)
	add_child(face)
	_label = Label3D.new()
	_label.name = "ScreenText"
	_label.font_size = 72
	_label.pixel_size = 0.0058
	_label.modulate = Color(1.0, 0.95, 0.8)
	_label.outline_size = 0
	_label.shaded = false
	_label.position = Vector3(0, SCREEN_BOTTOM + HEIGHT * 0.5, 0.19)
	add_child(_label)


func _build_seating() -> void:
	for row in 2:
		for column in 3:
			var bench := VillageProps.bench()
			bench.position = Vector3((column - 1) * 3.2, 0, 3.6 + row * 2.2)
			bench.rotation_degrees.y = 180.0  # benches face +Z; turn them to face the screen
			add_child(bench)
			benches.append(bench)


func _build_dialog() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 18
	_layer.visible = false
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.06, 0.1, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.22, 0.97)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 0)
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)
	column.add_child(_label_node("What shall we watch?", 26, Color(1, 1, 1)))
	column.add_child(_label_node("Paste a YouTube link and press Enter.", 16, Color(0.7, 0.78, 0.9)))
	_edit = LineEdit.new()
	_edit.placeholder_text = "https://www.youtube.com/watch?v=..."
	_edit.max_length = 300
	_edit.add_theme_font_size_override("font_size", 20)
	_edit.text_submitted.connect(func(text): submit(text))
	column.add_child(_edit)
	_message = _label_node("", 15, Color(1.0, 0.75, 0.6))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	for entry in [["Watch", func(): submit(_edit.text)], ["Clear the screen", func(): clear(); close_dialog()], ["Close (Esc)", func(): close_dialog()]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(entry[1])
		buttons.add_child(button)


func _label_node(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material, collide: bool) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	if collide:
		var shape := CollisionShape3D.new()
		shape.name = node_name + "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		shape.position = pos
		parent.add_child(shape)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
