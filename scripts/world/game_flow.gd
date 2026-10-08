class_name GameFlow
extends Node
## How a player joins: the title screen (Play / Info / Settings / Quit) -> the character screen (pick your animal, dress it, name it, press JOIN) -> the
## loading screen -> you appear in the middle of the village, on the plaza, free to move. Every launch goes through it, so the first thing anyone sees is the
## menu, then their character, never the world already running with a stranger standing in the meadow.
##
## While the flow runs the player is locked (`input_locked`); the world is already loaded behind the menu, so Play is instant and the loading screen is
## about showing the player their new home, not about waiting. Tests switch the flow off (`enabled = false`) before the first frame, like the character screen.

signal joined(profile: PlayerProfile)

enum Step { MENU, CREATING, LOADING, PLAYING }

@export var enabled := true
@export var load_seconds := 2.2
@export var player_path: NodePath = ^"../Player"
@export var menu_path: NodePath = ^"../MainMenu"
@export var creator_path: NodePath = ^"../CharacterCreator"
@export var loading_path: NodePath = ^"../LoadingScreen"
@export var village_path: NodePath = ^"../Village"

var step := Step.PLAYING

var _player: PlayerController
var _menu: MainMenu
var _creator: CharacterCreator
var _loading: LoadingScreen
var _village: Village


func _ready() -> void:
	add_to_group(&"game_flow")
	_player = get_node_or_null(player_path) as PlayerController
	_menu = get_node_or_null(menu_path) as MainMenu
	_creator = get_node_or_null(creator_path) as CharacterCreator
	_loading = get_node_or_null(loading_path) as LoadingScreen
	_village = get_node_or_null(village_path) as Village
	if not enabled or _player == null or _menu == null or _creator == null or _loading == null:
		return
	_creator.auto_start = false  # the flow opens it, after Play
	_menu.enabled = false  # the flow opens the menu itself (below), once everything is in place
	_menu.play_pressed.connect(_on_play)
	_creator.finished.connect(_on_created)
	_loading.covered.connect(_on_covered)
	_loading.finished.connect(_on_loaded)
	_begin.call_deferred()


func _begin() -> void:
	step = Step.MENU
	_set_hud(false)  # the weapon bar, health and clock stay hidden behind the menus
	var plaza := _village.spawn_point() if _village != null else Vector3.ZERO
	_player.global_position = plaza  # the character already stands in the middle of the village behind the title screen
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	# A saved look is already on the character behind the menu.
	var saved := PlayerProfile.load_saved()
	if saved != null:
		PlayerProfile.set_current(saved)
		saved.apply_to(_player.get_node("Body/Model") as AnimalModel)
	_menu.open()


func _on_play() -> void:
	step = Step.CREATING
	var profile := PlayerProfile.load_saved()
	if profile == null:
		profile = PlayerProfile.make_default()
	_creator.open(profile, false, "Join")  # no Cancel: joining needs a look; a returning player just presses Join again


func _on_created(_profile: PlayerProfile) -> void:
	if step != Step.CREATING:
		return  # F2 later in the game finishes the same screen: that is not a join
	step = Step.LOADING
	_player.input_locked = true  # the character screen just unlocked the player: stay locked until the loading screen is gone
	_loading.begin(load_seconds)


## The screen is fully dark: move the player to the plaza where nobody can see the jump.
func _on_covered() -> void:
	var spot := spawn_position()
	_player.global_position = spot
	_player.velocity = Vector3.ZERO
	_player.set_default_spawn(spot)
	_player.reset_physics_interpolation()


func _on_loaded() -> void:
	step = Step.PLAYING
	_player.input_locked = false
	_set_hud(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	joined.emit(PlayerProfile.current())


func _set_hud(shown: bool) -> void:
	var hud := _player.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = shown


## Where a joining player appears: the middle of the village (the plaza), or where their bed is when they have chosen one.
func spawn_position() -> Vector3:
	var saved := PlayerProfile.current().spawn_position()
	if saved != Vector3.INF:
		return saved
	return _village.spawn_point() if _village != null else Vector3.ZERO
