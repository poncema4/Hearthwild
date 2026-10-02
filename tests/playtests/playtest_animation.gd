extends SceneTree
## Playtest: filmstrips of the character's animation for visual review (topic
## `animation`). Each image is one contact sheet, thumbnails left to right, top
## to bottom = time (the game is frozen while each frame is captured, so the
## spacing is exact; the manifest has t, speed and position per thumbnail).
## Walk, sprint and hop are filmed from the side while already moving.
##
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_animation.gd -- <qa_output> <run stamp>

const SHEETS := {
	"walk_cycle": ["Walking east at 4 m/s, filmed from the side (camera 2.8 m away), already mid-stride: 8 thumbnails 6 frames (0.1 s) apart, about one and a half steps each side.",
			"A readable walk cycle: the legs alternate (one foot forward while the other is back), the arm on the opposite side of the forward foot swings forward, the swinging foot lifts off the ground while the planted foot stays flat, the body bobs slightly, ears bounce, tail wags. Facing east the whole time. Nothing floating, folded or bending the wrong way."],
	"sprint_cycle": ["Sprinting east at 7 m/s, same side view: 8 thumbnails 4 frames (0.067 s) apart, already at full speed.",
			"Longer strides than the walk, the body leans forward (head ahead of the hips), arms pump opposite the legs, feet still land flat and do not skate backwards; no snapping between thumbnails."],
	"jump_hop": ["A hop from standing, filmed from the side: 8 thumbnails 8 frames (0.13 s) apart from take-off to landing (Space is held, so the next hop may begin at the end).",
			"Take-off: legs push off; in the air both knees are UP IN FRONT of the hips (feet ahead of the body, never kicked behind) and both arms are thrown OUT and UP to the sides like a cheer, never folded across the body or pointing backwards; the head tilts slightly up; landing returns to the standing pose."],
	"jump_front": ["A hop seen from the FRONT (camera 3 m in front of the dog, which faces it): 8 thumbnails 8 frames (0.13 s) apart, Space held.",
			"In the air both arms are thrown out to the SIDES and up (a cheer: a Y shape, hands well outside the shoulders, never crossed over the chest and never pointing backwards), both knees lifted, head tilted slightly up, the shadow shrinking and growing; on the ground the arms hang."],
	"idle": ["Standing still, seen from the front at 2.6 m: 8 thumbnails 15 frames (0.25 s) apart.",
			"Subtle life only: the tail wags side to side, the ears sway a little, the chest breathes, one thumbnail may show a blink (eyes thin); feet stay planted and the pose barely changes."],
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

	# Walk and sprint: start them first so the strip begins mid-stride.
	await _start(Vector3.FORWARD, 2.8, -5.0, -PI / 2.0)
	Input.action_press("move_right")
	await kit.physics_frames(40)
	await _sheet("walk_cycle", ["move_right"], 42, 6)

	await _start(Vector3.FORWARD, 3.4, -5.0, -PI / 2.0)
	Input.action_press("move_right")
	Input.action_press("sprint")
	await kit.physics_frames(40)
	await _sheet("sprint_cycle", ["move_right", "sprint"], 28, 4)

	await _start(Vector3.FORWARD, 3.0, -5.0, -PI / 2.0)
	await _sheet("jump_hop", ["jump"], 56, 8)

	await _start(Vector3.BACK, 3.0, -6.0, 0.0)
	await _sheet("jump_front", ["jump"], 56, 8)

	await _start(Vector3.BACK, 2.6, -6.0, 0.0)
	await _sheet("idle", [], 105, 15)

	print("SCREENSHOTS: %s/animation/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


## Fresh start on the clearing: all state reset (lesson 25): position, body yaw, camera yaw, pitch, arm length.
func _start(facing: Vector3, distance: float, pitch_degrees: float, body_yaw: float) -> void:
	for action in ["move_right", "move_forward", "sprint", "jump"]:
		Input.action_release(action)
	await kit.teleport(Vector3(0, NAN, 0), 40)
	(kit.player.get_node("Body") as Node3D).rotation.y = body_yaw
	kit.face(facing)
	kit.spring_arm.spring_length = distance
	_pitch.rotation.x = deg_to_rad(pitch_degrees)
	await kit.frames(3)


func _sheet(name: String, actions: Array, total_frames: int, every: int) -> void:
	var info: Array = SHEETS.get(name, ["", ""])
	var sheet := await kit.filmstrip("animation", name, actions, total_frames, every, info[0], info[1], 4)
	kit.check_rendered("animation/" + name, sheet)
	for action in ["move_right", "move_forward", "sprint", "jump"]:
		Input.action_release(action)
