extends SceneTree
## Playtest: screenshots of the village for visual review (topic `village`).
##
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_village.gd -- <qa_output> <run stamp>
## Images go to qa_output/village/<date_time>/ with a manifest.json that says
## what each shows and what a correct frame looks like. Rendered-ness is
## checked here; whether it LOOKS right is for Hawkeye / a human.

const SHOTS := {
	"village/path_from_spawn": ["Standing near the spawn (-3, 1.5) looking along the dirt path toward the village.", "A soft brown dirt path through the grass leading away to the north-west; no trees ON the path; roofs may show in the distance."],
	"village/plaza_wide": ["Standing at (-9, 7.5) looking at the plaza from the south-east.", "Three cottages around a plaza with a well in the middle, lamp posts, a bench and dirt paths to each door; pale cobble patches blend into the dirt (intentional)."],
	"village/house1_front": ["In front of the first cottage (cream walls, red roof), looking at its door.", "A closed brown door leaf with a gold knob fills the doorway, clearly wider than the player; two windows; gabled roof with a ridge; chimney; doorstep."],
	"village/house1_prompt": ["Standing 1.6 m from the first cottage's CLOSED door, facing it.", "The brown door leaf fills the doorway; a dark panel at the bottom of the screen reads [E] Open door with a cream E key badge. The dog stands in front of the door."],
	"village/house1_door_open": ["The same spot after pressing E: the door has swung open.", "The door leaf is swung inward (it no longer fills the doorway); the doorway is clear; the prompt reads Close door."],
	"village/house1_interior": ["Player standing inside the first cottage facing the back wall; the camera is 3 m behind, just outside the door.", "Seen through the doorway: a plain room with a wooden floor, plain walls and the player facing the back wall. The room is dim because the roof shades it (intentional)."],
	"village/house3_back": ["Behind the third cottage (pink walls, brown roof), looking at its back wall.", "Solid back wall with a roof overhang and the chimney; the ground is flat and grass reaches the wall."],
	"village/well_and_lamps": ["Standing at (-12, 20) looking at the well in the plaza.", "Stone well with a small red roof, lamp posts with a warm glowing lantern, a bench, cobble ground that blends into grass."],
	"village/notice_board": ["Standing south-west of the notice board at (-18.5, 10.8), camera aimed so the board is right of the player.", "The board is fully visible beside the capsule: two wooden posts and three pale notes; flat ground; nothing floating."],
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
	var houses := kit.village.houses

	await _frame(Vector3(-3, NAN, 1.5), Vector3(-14, 0, 11.5).normalized(), 5.0, -15.0)
	await _take("path_from_spawn")

	await _frame(Vector3(-9, NAN, 7.5), Vector3(-11, 0, 6.5).normalized(), 6.0, -18.0)
	await _take("plaza_wide")

	var house1 := houses[0]
	var toward_door := -house1.global_transform.basis.z
	var outside := house1.door_outside(5.0)
	await _frame(Vector3(outside.x, NAN, outside.z), toward_door, 4.0, -10.0)
	await _take("house1_front")

	# A closed door, the prompt, then the door opened with the real key.
	var near := house1.door_outside(1.6)
	await _frame(Vector3(near.x, NAN, near.z), toward_door, 3.0, -8.0)
	(kit.player.get_node("Body") as Node3D).rotation.y = atan2(-toward_door.x, -toward_door.z)
	await kit.physics_frames(6)
	await _take("house1_prompt")
	await kit.tap("interact")
	await kit.physics_frames(50)
	await _take("house1_door_open")

	var inside := house1.to_global(Vector3(0, 0, 0.5))
	await _frame(Vector3(inside.x, NAN, inside.z), toward_door, 3.0, -8.0)
	await _take("house1_interior")

	var house3 := houses[2]
	var behind := house3.to_global(Vector3(0, 0, -House.DEPTH * 0.5 - 1.5))
	await _frame(Vector3(behind.x, NAN, behind.z), house3.global_transform.basis.z, 4.5, -12.0)
	await _take("house3_back")

	await _frame(Vector3(-12, NAN, 20), Vector3(-8, 0, -6).normalized(), 5.0, -15.0)
	await _take("well_and_lamps")

	# Stand to the board's south-west and aim 23 degrees to its left: the capsule fills the
	# centre, the board sits to the right, and the lamp post (north-east of the board) is out of view.
	await _frame(Vector3(-18.5, NAN, 10.8), Vector3(4, 0, -3.3).normalized(), 3.5, -10.0)
	await _take("notice_board")

	print("SCREENSHOTS: %s/village/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


## Places the player, points the camera along `facing`, sets zoom and pitch.
func _frame(where: Vector3, facing: Vector3, distance: float, pitch_degrees: float) -> void:
	await kit.teleport(where, 20)
	kit.face(facing)
	kit.spring_arm.spring_length = distance
	_pitch.rotation.x = deg_to_rad(pitch_degrees)
	await kit.frames(3)


func _take(name: String) -> void:
	var info: Array = SHOTS.get("village/" + name, ["", ""])
	kit.check_rendered("village/" + name, await kit.shot("village", name, info[0], info[1]))
