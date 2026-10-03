extends SceneTree
## Playtest: fishing at the pond (topic `fishing`).
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_fishing.gd -- <qa_output> <run stamp>

const SHOTS := {
	"fishing/ready": ["Standing at a fishing spot on the shore, facing the pond, with the prompt on screen.", "The dog (or chosen animal) at the edge of the water with a small wooden signpost showing a blue fish beside it; the pond ahead; the prompt [E] Cast your line at the bottom."],
	"fishing/cast": ["Just after casting: the rod in hand, arms raised, the line running to a red and white bobber on the water.", "A fishing rod held out over the water, a thin pale line to a small red/white bobber floating on the pond; the prompt says to wait for a bite."],
	"fishing/bite": ["The moment of the bite: the bobber has dipped and a red ! floats above it.", "A red exclamation mark above the bobber, the bobber lower in the water; the prompt reads [E] Reel in!"],
	"fishing/caught": ["After reeling in: the catch message.", "The message box at the top says what was caught with its size in cm; the rod and line are gone; the dog stands relaxed."],
	"fishing/night": ["Fishing at night (11 PM): the bobber on dark moonlit water.", "A dark blue scene, moonlit pond; the bobber and the ! still visible; the HUD clock says 11:00 PM."],
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
	var spot: FishingSpot = kit.fishing.spots[1]
	spot.rng.seed = 21
	await _stand(spot)
	await kit.frames(6)
	await _take("ready")
	await kit.tap("interact")
	await kit.physics_frames(50)
	await kit.frames(4)
	_check_on_screen("cast", spot._bobber.global_position, "bobber")
	_check_on_screen("cast", (spot._line.global_position), "line")
	await _take("cast")
	var guard := 0
	while spot.state != FishingSpot.State.BITE and guard < 700:
		await kit.physics_frames(1)
		guard += 1
	await kit.physics_frames(8)
	await kit.frames(3)
	_check_on_screen("bite", spot._bang.global_position, "red !")
	await _take("bite")
	await kit.tap("interact")
	await kit.physics_frames(30)
	await kit.frames(3)
	await _take("caught")
	await kit.physics_frames(60)

	kit.day_night.set_time(23.0)
	spot.rng.seed = 33
	await _stand(spot)
	await kit.tap("interact")
	guard = 0
	while spot.state != FishingSpot.State.BITE and guard < 700:
		await kit.physics_frames(1)
		guard += 1
	await kit.physics_frames(8)
	await kit.frames(3)
	var night_image := await _take("night")
	var player_light := _brightness_around(night_image, kit.player.global_position + Vector3(0, 0.9, 0))
	kit.check("fishing/night: the player is not a black silhouette (mean brightness around them over 0.07; it was 0.035 before the ambient floor)", player_light > 0.07,
			"mean luminance %.3f" % player_light)
	kit.day_night.set_time(10.0)
	if FileAccess.file_exists(PlayerProfile.save_path):
		DirAccess.remove_absolute(PlayerProfile.save_path)
	print("SCREENSHOTS: %s/fishing/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


func _stand(spot: FishingSpot) -> void:
	var stand := spot.standing_spot()
	await kit.teleport(Vector3(stand.x, NAN, stand.z), 20)
	# Camera behind and to the side, looking over the shoulder at the water.
	var side := Vector3(-spot.toward_water.z, 0.0, spot.toward_water.x)
	kit.face((spot.toward_water + side * 0.6).normalized())  # camera swung round to the side, so the cast is seen beside the angler
	(kit.player.get_node("Body") as Node3D).rotation.y = atan2(-spot.toward_water.x, -spot.toward_water.z)
	kit.spring_arm.spring_length = 4.4
	_pitch.rotation.x = deg_to_rad(-20.0)
	await kit.physics_frames(5)


## The thing must project onto the screen, in front of the camera, and be big enough to see
## (lesson 47: the tests proved the bobber existed while it was invisible in the picture).
func _check_on_screen(moment: String, world_point: Vector3, what: String) -> void:
	var camera := kit.tree.root.get_viewport().get_camera_3d()
	var screen := camera.unproject_position(world_point)
	var size := Vector2(kit.tree.root.size)
	kit.check("fishing/%s: the %s is on screen, in front of the camera" % [moment, what],
			not camera.is_position_behind(world_point) and Rect2(Vector2.ZERO, size).has_point(screen), "screen %s of %s, behind=%s" % [screen, size, camera.is_position_behind(world_point)])


func _take(name: String) -> Image:
	var info: Array = SHOTS.get("fishing/" + name, ["", ""])
	var image: Image = await kit.shot("fishing", name, info[0], info[1])
	kit.check_rendered("fishing/" + name, image)
	return image


## Mean luminance (0..1) of a 110 x 170 px window around a world point, sampled every 3 px.
func _brightness_around(image: Image, world_point: Vector3) -> float:
	var camera := kit.tree.root.get_viewport().get_camera_3d()
	var screen := camera.unproject_position(world_point)
	var scale := Vector2(image.get_size()) / Vector2(kit.tree.root.size)
	var center := Vector2i(screen * scale)
	var total := 0.0
	var count := 0
	for y in range(center.y - 85, center.y + 85, 3):
		for x in range(center.x - 55, center.x + 55, 3):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				total += image.get_pixel(x, y).get_luminance()
				count += 1
	return total / maxf(count, 1)
