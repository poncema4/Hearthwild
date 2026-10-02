extends SceneTree
## Playtest: screenshots of the player character (the dog) for visual review
## (topic `character`): from every side, a face close-up, mid-walk, mid-jump,
## and wearing outfit items.
##
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_character.gd -- <qa_output> <run stamp>

const SHOTS := {
	"character/front": ["The dog from the front at 3 m, standing still on the spawn clearing.", "A cute, chunky golden dog: big round head, two big shiny dark eyes with white highlights, brown patch round the right eye, cream muzzle, dark nose, pink cheeks, floppy brown ears, cream belly, short legs and paws. Friendly, not creepy; nothing floating or clipping."],
	"character/side": ["The dog in profile at 3 m.", "Muzzle sticking out in front of the face, floppy ear hanging at the side, the curled tail up at the back, feet flat on the ground, arms at the sides."],
	"character/back": ["The dog from behind at 3 m.", "The curled tail with a cream tip behind the body, two ears, rounded back of the head, no gaps between head and body."],
	"character/face_closeup": ["Close-up of the face, body turned about 30 degrees, camera at its minimum zoom (1.5 m).", "Eyes, snout, nose and cheeks clearly readable and cute; ears attached to the head; no holes or z-fighting patches on the face."],
	"character/walking": ["Mid-stride while walking to the right (side view, camera 3.5 m away).", "One leg forward and one back, arms swinging opposite, body slightly raised, tail wagging, feet near the ground."],
	"character/jumping": ["Near the top of a jump, moving right.", "Legs tucked up, arms raised out to the sides, the body clearly off the ground with a shadow below."],
	"character/outfit": ["The dog wearing a red cap and a blue scarf, front view at 2.6 m.", "Cap sits on top of the head between the ears (not floating, not sunk into the skull), scarf wraps the neck under the head; both fully opaque."],
}

var kit: PlaytestKit
var _pitch: Node3D
var _model: AnimalModel


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pitch = kit.camera_rig.get_node("Pitch")
	_model = kit.player.get_node("Body/Model")

	await _frame(Vector3.BACK, 3.0, -8.0, 0.0)
	await _take("front")
	await _frame(Vector3.RIGHT, 3.0, -8.0, 0.0)
	await _take("side")
	await _frame(Vector3.FORWARD, 3.0, -8.0, 0.0)
	await _take("back")
	await _frame(Vector3.BACK, kit.camera_rig.min_distance, -4.0, 30.0)
	await _take("face_closeup")

	# Walking right: the camera faces north, so the dog crosses the view and shows its side.
	await _frame(Vector3.FORWARD, 3.5, -8.0, 0.0)
	Input.action_press("move_right")
	await kit.physics_frames(22)
	await _take("walking")
	Input.action_release("move_right")

	await _frame(Vector3.FORWARD, 3.5, -8.0, 0.0)
	Input.action_press("move_right")
	await kit.physics_frames(10)
	await kit.tap("jump")
	await kit.physics_frames(16)
	await _take("jumping")
	Input.action_release("move_right")

	await _frame(Vector3.BACK, 2.6, -8.0, 0.0)
	_model.equip(&"head_top", Outfits.make(&"red_cap"))
	_model.equip(&"neck", Outfits.make(&"blue_scarf"))
	await kit.frames(3)
	await _take("outfit")

	print("SCREENSHOTS: %s/character/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


## Puts the player on the spawn clearing, resets the pose, points the camera.
func _frame(facing: Vector3, distance: float, pitch_degrees: float, body_yaw_degrees: float) -> void:
	await kit.teleport(Vector3(0, NAN, 0), 30)
	(kit.player.get_node("Body") as Node3D).rotation.y = deg_to_rad(body_yaw_degrees)
	kit.face(facing)
	kit.spring_arm.spring_length = distance
	_pitch.rotation.x = deg_to_rad(pitch_degrees)
	await kit.frames(3)


func _take(name: String) -> void:
	var info: Array = SHOTS.get("character/" + name, ["", ""])
	kit.check_rendered("character/" + name, await kit.shot("character", name, info[0], info[1]))
