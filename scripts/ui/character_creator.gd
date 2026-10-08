class_name CharacterCreator
extends CanvasLayer
## The character screen: pick your animal, dress it (a hat, glasses, neck, top and back
## item, each or none), type your name, press Start. A live 3D preview turns slowly.
##
## When the game starts: a saved profile is applied silently; with no save the screen opens
## with a fresh default profile (named after the Steam name once Steam is connected).
## F2 opens it again at any time. While it is open the player cannot move
## (`PlayerController.input_locked`) and the mouse is free.
##
## Everything the screen does is also a method (`next_species`, `next_item`, `enter_name`,
## `confirm`), which is how the tests drive it.

signal finished(profile: PlayerProfile)

## Tests switch this off before the first frame so the world starts playable.
@export var enabled: bool = true
## False: the screen does not open by itself when the game starts (the join flow opens it after the title screen).
@export var auto_start: bool = true
@export var player_path: NodePath = ^"../Player"
@export var preview_spin_speed: float = 0.7

var profile: PlayerProfile
var preview_model: AnimalModel
var is_open := false
var can_cancel := false

var _player: PlayerController
var _root: Control
var _species_label: Label
var _item_labels := {}
var _name_edit: LineEdit
var _viewport: SubViewport
var _cancel_button: Button
var _start_button: Button
var _choice := {}  # slot -> item index in the slot's list, -1 = nothing


func _ready() -> void:
	layer = 20
	add_to_group(&"character_creator")
	_player = get_node_or_null(player_path) as PlayerController
	_build_ui()
	_root.visible = false
	_begin.call_deferred()


func _begin() -> void:
	if not enabled or not auto_start:
		return
	var saved := PlayerProfile.load_saved()
	if saved != null:
		PlayerProfile.set_current(saved)
		_apply_to_player(saved)
	else:
		open(PlayerProfile.make_default(), false)  # the first launch must pick a look: no Cancel


func _physics_process(_delta: float) -> void:
	if enabled and not is_open and _player and _player.wants_customize():
		open(PlayerProfile.current())


func _process(delta: float) -> void:
	if is_open and preview_model and preview_spin_speed != 0.0:
		preview_model.rotation.y += delta * preview_spin_speed


## Shows the screen, starting from `start_profile` (it is copied; nothing changes until Start).
func open(start_profile: PlayerProfile, allow_cancel: bool = true, confirm_text: String = "Start") -> void:
	_start_button.text = confirm_text
	can_cancel = allow_cancel
	_cancel_button.visible = allow_cancel
	profile = PlayerProfile.from_dict(start_profile.to_dict())
	for slot in Outfits.SLOTS:
		var items := Outfits.items_for_slot(slot)
		_choice[slot] = items.find(profile.outfit.get(slot, &""))
	is_open = true
	_root.visible = true
	preview_model.rotation.y = PI
	if _player:
		_player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_name_edit.text = profile.display_name
	_refresh()


func next_species(direction: int) -> void:
	var all := AnimalSpecies.all()
	var index := 0
	for i in all.size():
		if all[i].id == profile.species_id:
			index = i
	profile.species_id = all[posmod(index + direction, all.size())].id
	_refresh()


func select_species(species_id: StringName) -> void:
	profile.species_id = AnimalSpecies.by_id(species_id).id
	_refresh()


## Cycles the item on `slot`: none, then each item in turn, wrapping.
func next_item(slot: StringName, direction: int) -> void:
	var items := Outfits.items_for_slot(slot)
	var index: int = _choice[slot] + direction
	if index >= items.size():
		index = -1
	elif index < -1:
		index = items.size() - 1
	_choice[slot] = index
	_refresh()


func enter_name(new_name: String) -> void:
	_name_edit.text = new_name
	_refresh()


## Start: saves the profile and dresses the player. Returns the profile.
func confirm() -> PlayerProfile:
	profile.display_name = _name_edit.text
	profile.outfit = _outfit_from_choices()
	profile.sanitize()
	profile.save()
	PlayerProfile.set_current(profile)
	_apply_to_player(profile)
	is_open = false
	_root.visible = false
	if _player:
		_player.input_locked = false
	_return_mouse()
	finished.emit(profile)
	var hud := _player.get_node_or_null("HUD") as InteractionPrompt if _player else null
	if hud:
		hud.show_message("Welcome, %s! Press F2 any time to change your look." % profile.display_name, 6.0)
	return profile


## The on-screen rectangle of the whole panel (for the fit-in-window check).
func confirm_button_text() -> String:
	return _start_button.text


## The on-screen rectangle of the whole panel (for the fit-in-window check).
func panel_rect() -> Rect2:
	var panel := _root.get_child(1) as Control
	return panel.get_global_rect()


## Closes the screen without changing anything (only when reopened with F2; also on Esc).
func cancel() -> bool:
	if not is_open or not can_cancel:
		return false
	is_open = false
	_root.visible = false
	if _player:
		_player.input_locked = false
	_return_mouse()
	return true


func _input(event: InputEvent) -> void:
	if is_open and can_cancel and event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func species_name() -> String:
	return AnimalSpecies.by_id(profile.species_id).species_name


func _apply_to_player(applied: PlayerProfile) -> void:
	if _player:
		applied.apply_to(_player.get_node("Body/Model") as AnimalModel)


func _outfit_from_choices() -> Dictionary:
	var worn := {}
	for slot in Outfits.SLOTS:
		var items := Outfits.items_for_slot(slot)
		if _choice[slot] >= 0:
			worn[slot] = items[_choice[slot]]
	return worn


## Redraws the labels and rebuilds the preview from the current choices.
func _refresh() -> void:
	profile.outfit = _outfit_from_choices()
	_species_label.text = species_name()
	for slot in Outfits.SLOTS:
		var items := Outfits.items_for_slot(slot)
		(_item_labels[slot] as Label).text = "None" if _choice[slot] < 0 else Outfits.label_of(items[_choice[slot]])
	if preview_model:
		profile.apply_to(preview_model)
		preview_model.set_display_name(_name_edit.text if _name_edit.text != "" else profile.display_name)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks never reach the game behind
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.06, 0.1, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.16, 0.22, 0.97)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	panel.add_child(row)

	# Live preview on the left.
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(400, 500)
	row.add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(400, 500)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.72, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.92, 1.0)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.1
	_viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 1.3, 5.9)
	_viewport.add_child(camera)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.06
	ground.mesh = disc
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.45, 0.68, 0.38)
	ground.material_override = ground_material
	ground.position = Vector3(0, -0.03, 0)
	_viewport.add_child(ground)
	preview_model = AnimalModel.new()
	preview_model.rotation.y = PI  # the model faces -Z; the camera is on +Z, so turn it round to face us
	_viewport.add_child(preview_model)

	# Controls on the right.
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(380, 0)
	column.add_theme_constant_override("separation", 9)
	row.add_child(column)
	column.add_child(_label("Create your character", 28))
	_species_label = _picker(column, "Animal", func(d): next_species(d))
	for slot in Outfits.SLOTS:
		_item_labels[slot] = _picker(column, Outfits.SLOT_LABELS[slot], func(d): next_item(slot, d))
	column.add_child(_label("Your name", 16, Color(0.7, 0.78, 0.9)))
	_name_edit = LineEdit.new()
	_name_edit.max_length = PlayerProfile.MAX_NAME_LENGTH
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_changed.connect(func(_t): _refresh())
	column.add_child(_name_edit)
	var start := Button.new()
	_start_button = start
	start.text = "Start"
	start.add_theme_font_size_override("font_size", 26)
	start.custom_minimum_size = Vector2(0, 50)
	start.pressed.connect(func(): confirm())
	column.add_child(start)
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel (Esc)"
	_cancel_button.pressed.connect(func(): cancel())
	column.add_child(_cancel_button)


## A "Title  < value >" row; returns the value label.
func _picker(parent: Control, title: String, on_step: Callable) -> Label:
	var line := HBoxContainer.new()
	var caption := _label(title, 17, Color(0.7, 0.78, 0.9))
	caption.custom_minimum_size = Vector2(86, 0)
	line.add_child(caption)
	var back := Button.new()
	back.text = "<"
	back.custom_minimum_size = Vector2(44, 0)
	back.pressed.connect(func(): on_step.call(-1))
	line.add_child(back)
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 22)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(value)
	var forward := Button.new()
	forward.text = ">"
	forward.custom_minimum_size = Vector2(44, 0)
	forward.pressed.connect(func(): on_step.call(1))
	line.add_child(forward)
	parent.add_child(line)
	return value


func _label(text: String, size: int, color := Color(1, 1, 1)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Hands the mouse back to the camera, which decides (free cursor, or captured for right-mouse look / shift lock).
func _return_mouse() -> void:
	var rig := get_tree().get_first_node_in_group(&"camera_rig") as ThirdPersonCamera
	if rig:
		rig.refresh_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
