class_name PlaytestKit
extends RefCounted
## Shared helpers for playtest scripts, so each scenario is a few lines
## instead of rebuilding the same setup. Used by agents' throwaway
## playtests (see .claude/agents/scout.md).
##
## Usage, in a script that extends SceneTree:
##
##   func _initialize() -> void:
##       _run.call_deferred()
##
##   func _run() -> void:
##       var kit := PlaytestKit.new(self)
##       await kit.load_world()
##       await kit.hold(["move_forward", "sprint"], 60)
##       kit.check("sprinted forward", kit.player.global_position.z < -5.0, kit.where())
##
##       kit.finish()
##
## Landmarks (fixed by seed): flat spawn clearing around (0, 0), pond at
## kit.terrain.pond_center, boundary wall inner faces at x/z = +-58,
## trees from kit.nature.get_trees().

const WORLD_SCENE := "res://scenes/world/world.tscn"

var tree: SceneTree
var world: Node
var player: PlayerController
var camera_rig: ThirdPersonCamera
var spring_arm: SpringArm3D
var terrain: Terrain
var nature: NatureScatter
var failures := 0


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree


## Loads the world and waits for the player to land.
func load_world(settle_frames: int = 60) -> void:
	world = load(WORLD_SCENE).instantiate()
	tree.root.add_child(world)
	player = world.get_node("Player")
	camera_rig = player.get_node("CameraRig")
	spring_arm = camera_rig.get_node("Pitch/SpringArm3D")
	terrain = world.get_node("Terrain")
	nature = world.get_node("Nature")
	await physics_frames(settle_frames)


## Puts the player at a position, standing still, and waits a moment.
## Pass y = NAN to drop the player onto the ground at (x, z).
func teleport(position: Vector3, settle_frames: int = 10) -> void:
	if is_nan(position.y):
		position.y = terrain.height_at(position.x, position.z) + 0.5
	player.global_position = position
	player.velocity = Vector3.ZERO
	await physics_frames(settle_frames)


## Holds one or more input actions for a number of physics frames, then releases them.
func hold(actions: Array, frame_count: int) -> void:
	for action in actions:
		Input.action_press(action)
	await physics_frames(frame_count)
	for action in actions:
		Input.action_release(action)


## Taps an action for exactly one physics frame (e.g. a jump).
func tap(action: String) -> void:
	Input.action_press(action)
	await physics_frames(1)
	Input.action_release(action)


## Waits rendered (idle) frames. Use this after Input.parse_input_event():
## injected events are delivered on the next idle frame, and on a slow
## renderer several physics frames can pass inside one idle frame.
func frames(count: int) -> void:
	for i in count:
		await tree.process_frame


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


## Points the camera so "forward" (W) walks in a world direction.
func face(direction: Vector3) -> void:
	camera_rig.rotation.y = atan2(-direction.x, -direction.z)


func horizontal_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


## Player position and state as text, for check details.
func where() -> String:
	var p := player.global_position
	return "pos=(%.2f, %.2f, %.2f) speed=%.2f on_floor=%s" % [
		p.x, p.y, p.z, horizontal_speed(), player.is_on_floor()]


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + detail + ")" if detail else ""))
	if not ok:
		failures += 1


## Prints a measurement without judging it (for exploration).
func note(name: String, detail: String) -> void:
	print("NOTE " + name + "  (" + detail + ")")


## Screenshot layout: <base>/<topic>/<run stamp>/<nn>_<name>.png
## e.g. qa_output/environment/2026-10-01_23-15-02/01_spawn_north.png.
## Topics: camera, environment, nature, player (add new ones as needed).
## Screenshots are never deleted, so every run's shots stay available.
var shots_base := ""
var shots_stamp := ""
var _shot_counts := {}


## Reads `-- <base> <stamp>` from the command line (both optional; the
## runner passes them so all playtests in one run share a stamp).
func setup_screenshots() -> void:
	var args := OS.get_cmdline_user_args()
	shots_base = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://qa_output")
	shots_stamp = args[1] if args.size() > 1 else Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	DirAccess.make_dir_recursive_absolute(shots_base)
	# Keep Godot from importing screenshots saved inside the project.
	FileAccess.open(shots_base.path_join(".gdignore"), FileAccess.WRITE)


## Saves a numbered screenshot under a topic and returns the image.
func shot(topic: String, name: String) -> Image:
	if shots_base == "":
		setup_screenshots()
	var n: int = _shot_counts.get(topic, 0) + 1
	_shot_counts[topic] = n
	return await screenshot(shots_base.path_join(topic).path_join(shots_stamp).path_join("%02d_%s.png" % [n, name]))


## Saves a screenshot at an exact path and returns it. Only works with
## rendering (not --headless). Creates the folder if needed.
func screenshot(path: String) -> Image:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image := tree.root.get_texture().get_image()
	image.save_png(path)
	print("SHOT " + path)
	return image


## Grabs the current frame without saving it. Rendered runs only.
func capture() -> Image:
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()


## Fraction (0..1) of pixels whose brightness differs by more than `threshold`
## between two same-size images (compared on a small copy). Used to prove two
## frames look the same, or that something visibly changed.
func fraction_different(a: Image, b: Image, threshold: float = 0.06) -> float:
	var small_a := a.duplicate() as Image
	var small_b := b.duplicate() as Image
	small_a.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	small_b.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var different := 0
	for y in 90:
		for x in 160:
			if absf(small_a.get_pixel(x, y).get_luminance() - small_b.get_pixel(x, y).get_luminance()) > threshold:
				different += 1
	return different / 14400.0


## Checks that a screenshot actually shows a rendered scene: not black,
## not blown out, and not a single flat colour (which is what a failed
## render, a camera inside geometry or an empty scene look like).
func check_rendered(name: String, image: Image) -> void:
	var small := image.duplicate() as Image
	small.resize(64, 36, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	var total_sq := 0.0
	var count := small.get_width() * small.get_height()
	for y in small.get_height():
		for x in small.get_width():
			var l := small.get_pixel(x, y).get_luminance()
			total += l
			total_sq += l * l
	var mean := total / count
	var spread := sqrt(maxf(total_sq / count - mean * mean, 0.0))
	check(name + " rendered", mean > 0.08 and mean < 0.92 and spread > 0.03,
		"brightness=%.2f contrast=%.3f" % [mean, spread])


func finish() -> void:
	print("RESULT: %s (%d failures)" % ["ALL PASS" if failures == 0 else "FAILED", failures])
	tree.quit(failures)
