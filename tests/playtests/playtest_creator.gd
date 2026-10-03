extends SceneTree
## Playtest: the character screen and the result in the world (topic `creator`).
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_creator.gd -- <qa_output> <run stamp>

const SHOTS := {
	"creator/dog_default": ["The character screen on a first launch: the default golden dog, nothing worn, the name box filled in.", "A dark panel over the dimmed game; on the left a lit preview of the golden dog on a small grass disc with its name floating above; on the right: 'Create your character', Your animal (< Dog >), Hat/Glasses/Neck/Top/Back all None, Your name, a big Start button. Text readable, nothing cut off."],
	"creator/cat_outfit": ["The cat wearing a straw hat and round glasses, named Whiskers.", "The grey-blue cat with pointy ears and a long upright tail; a straw hat on its head with the brim over the ears; round glasses over the eyes; the name 'Whiskers' floats above; the right panel shows Cat, Straw hat, Round glasses."],
	"creator/bunny_full": ["The bunny wearing a red cap, bow tie, mint sweater and explorer pack, named Clover.", "A white bunny with tall ears; red cap, pink bow tie, mint sweater with a cream stripe, a brown pack visible from the side as it turns; the name 'Clover' floats above the tall ears (not inside them)."],
	"creator/in_world": ["After Start: the chosen bunny in the village, seen from the front, with the welcome message.", "The bunny with its outfit standing in the plaza in daylight, the name Clover floating over its ears, a message box at the top saying Welcome, Clover! Press F2 any time to change your look."],
}

var kit: PlaytestKit
var _pitch: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pitch = kit.camera_rig.get_node("Pitch")
	var creator := kit.creator
	creator.preview_spin_speed = 0.0
	await kit.teleport(Vector3(-9, NAN, 7.5), 20)
	kit.face(Vector3(-11, 0, 6.5).normalized())

	creator.enabled = true
	creator.open(PlayerProfile.make_default())
	creator.preview_model.rotation.y = PI + 0.3
	await kit.frames(6)
	var window := Rect2(Vector2.ZERO, Vector2(kit.tree.root.size))
	var panel := creator.panel_rect()
	kit.check("creator: the whole panel (including the Start button) fits inside the window", window.encloses(panel) and panel.size.y > 300.0,
			"panel %s in window %s" % [panel, window])
	await _take("dog_default")

	creator.select_species(&"cat")
	creator.next_item(&"head_top", 1)
	creator.next_item(&"head_top", 1)  # straw hat
	creator.next_item(&"face", 1)
	creator.enter_name("Whiskers")
	creator.preview_model.rotation.y = PI - 0.35
	await kit.frames(6)
	await _take("cat_outfit")

	creator.select_species(&"bunny")
	for slot in [&"head_top", &"neck", &"torso", &"back"]:
		creator._choice[slot] = -1
	creator.next_item(&"head_top", 1)  # red cap
	creator.next_item(&"face", 1)  # glasses off the cat -> none (cycle)
	creator.next_item(&"face", 1)
	creator.next_item(&"neck", 1)
	creator.next_item(&"neck", 1)  # bow tie
	creator.next_item(&"torso", 1)
	creator.next_item(&"back", 1)
	creator.enter_name("Clover")
	creator.preview_model.rotation.y = PI + 0.7
	await kit.frames(6)
	await _take("bunny_full")

	creator.confirm()
	kit.check("creator: after Start the real mouse is captured again (needs a real window; Xvfb has one)", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse mode %d" % Input.mouse_mode)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await kit.teleport(Vector3(-10, NAN, 8), 20)
	kit.face(Vector3.BACK)
	(kit.player.get_node("Body") as Node3D).rotation.y = 0.0
	kit.spring_arm.spring_length = 3.2
	_pitch.rotation.x = deg_to_rad(-8.0)
	await kit.frames(6)
	await _take("in_world")
	if FileAccess.file_exists(PlayerProfile.save_path):
		DirAccess.remove_absolute(PlayerProfile.save_path)
	print("SCREENSHOTS: %s/creator/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


func _take(name: String) -> void:
	var info: Array = SHOTS.get("creator/" + name, ["", ""])
	kit.check_rendered("creator/" + name, await kit.shot("creator", name, info[0], info[1]))
