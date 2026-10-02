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


## Taps an action (e.g. a jump): pressed for TWO physics frames, then released.
## One frame is not enough: `physics_frame` fires BEFORE nodes process that
## frame, so a press released after a single await can vanish before the
## player ever sees `is_action_just_pressed` (the jump strip never jumped).
func tap(action: String) -> void:
	Input.action_press(action)
	await physics_frames(2)
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
## The run stamp is ONLY a date and time, YYYY-MM-DD_HH-MM-SS (never a label),
## e.g. qa_output/environment/2026-10-01_23-15-02/01_spawn_north.png.
## Each run folder also gets a manifest.json saying, per image, WHAT it shows,
## what is EXPECTED, and how much it CHANGED versus the same image in the
## previous run, so a reviewer can skip unchanged images (saves tokens).
## Topics: camera, environment, nature, player, movement (add as needed).
## Screenshots are never deleted, so every run's shots stay available.
var shots_base := ""
var shots_stamp := ""
var _shot_counts := {}
var _manifest := {}
## The samples of the most recent filmstrip, so a playtest can assert on them.
var last_samples := []


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
## `what` = what the image shows; `expect` = what a correct frame looks like.
func shot(topic: String, name: String, what := "", expect := "") -> Image:
	if shots_base == "":
		setup_screenshots()
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	_store(topic, name, image, what, expect, {})
	return image


## Presses `actions`, grabs a frame every `every` physics frames, and saves ONE
## contact sheet: a grid of thumbnails read left to right, top to bottom = time.
## The first thumbnail is taken BEFORE any input (t = 0, standing still).
## The game is FROZEN (tree paused) while each frame is captured, so capturing
## costs no game time: thumbnails are exactly `every` physics frames apart on
## every machine, and `t` counts only the frames the game really ran. (Never
## derive `t` from a wall-clock or from Engine.get_physics_frames(): that keeps
## ticking while paused. Lesson 26.)
## Each sample records: index/row/col (which thumbnail), t (seconds), pos,
## speed (the player's ACTUAL horizontal velocity in m/s, not a target),
## on_floor, cam_dist (camera arm length in m) and body_yaw_deg.
func filmstrip(topic: String, name: String, actions: Array, total_frames: int, every: int,
		what := "", expect := "", columns := 4) -> Image:
	if shots_base == "":
		setup_screenshots()
	var thumbs: Array[Image] = []
	var samples := []
	var elapsed := 0  # game frames that really ran (the game is frozen during captures)
	await _add_sample(thumbs, samples, elapsed, columns)
	for action in actions:
		Input.action_press(action)
	for k in range(1, total_frames / every + 1):
		# `physics_frame` fires BEFORE nodes process that frame, and the game is
		# frozen right after the last await: so `every + 1` awaits let exactly
		# `every` frames run (the last frame would otherwise be skipped).
		for i in every + 1:
			await tree.physics_frame
		elapsed += every
		await _add_sample(thumbs, samples, elapsed, columns)
	for action in actions:
		Input.action_release(action)
	var rows := ceili(thumbs.size() / float(columns))
	# blit_rect needs identical pixel formats; frames are whatever the viewport
	# gives (RGB8 here), so build the sheet in the thumbnails' own format.
	var sheet := Image.create(columns * 320, rows * 180, false, thumbs[0].get_format())
	for i in thumbs.size():
		sheet.blit_rect(thumbs[i], Rect2i(0, 0, 320, 180), Vector2i((i % columns) * 320, (i / columns) * 180))
	last_samples = samples
	_check_time_axis(topic, name, samples)
	_store(topic, name, sheet, what, expect, {"samples": samples, "columns": columns})
	return sheet


## The harness checks itself: consecutive samples must never imply the player
## moved faster than sprint speed. A wrong time axis (lesson 26) would.
func _check_time_axis(topic: String, name: String, samples: Array) -> void:
	var worst := 0.0
	for i in range(1, samples.size()):
		var a: Dictionary = samples[i - 1]
		var b: Dictionary = samples[i]
		var dt: float = b["t"] - a["t"]
		if dt > 0.0:
			var d := Vector2(b["pos"][0] - a["pos"][0], b["pos"][2] - a["pos"][2]).length()
			worst = maxf(worst, d / dt)
	check("%s/%s time axis is consistent" % [topic, name], worst <= player.sprint_speed * 1.05,
		"fastest implied %.2f m/s, sprint cap %.1f" % [worst, player.sprint_speed])
	# The other direction: where the speed is steady across two samples, the
	# distance moved / dt must MATCH that speed. An overstated `t` lowers the
	# implied speed, which the cap above can never catch (Sage, lesson 26).
	var steady := 0
	var worst_error := 0.0
	for i in range(1, samples.size()):
		var a: Dictionary = samples[i - 1]
		var b: Dictionary = samples[i]
		var dt: float = b["t"] - a["t"]
		# Steady = same speed AND same heading (a reversal passes through equal speeds).
		var steady_heading: bool = absf(angle_difference(deg_to_rad(a["body_yaw_deg"]), deg_to_rad(b["body_yaw_deg"]))) <= deg_to_rad(20.0)
		if dt > 0.0 and a["speed"] >= 2.0 and steady_heading and absf(a["speed"] - b["speed"]) <= 0.02 * a["speed"]:
			var d := Vector2(b["pos"][0] - a["pos"][0], b["pos"][2] - a["pos"][2]).length()
			worst_error = maxf(worst_error, absf(d / dt - a["speed"]) / a["speed"])
			steady += 1
	if steady == 0:
		note("%s/%s time axis (steady-speed match)" % [topic, name], "no steady-speed sample pairs in this strip; only the cap was checked")
	else:
		# t is stored to 0.1 ms, so the only noise left is position rounding (~2%).
		# Correct code measures under 3%; the old off-by-one frame measured 11.8%.
		check("%s/%s time axis matches the reported speed" % [topic, name], worst_error <= 0.05,
			"%d steady pairs, worst mismatch %.1f%% (limit 5%%)" % [steady, worst_error * 100.0])


func _add_sample(thumbs: Array[Image], samples: Array, elapsed_frames: int, columns: int) -> void:
	tree.paused = true
	var thumb := (await capture()).duplicate() as Image
	thumb.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	var index := thumbs.size()
	thumbs.append(thumb)
	var p := player.global_position
	samples.append({"index": index + 1, "row": index / columns + 1, "col": index % columns + 1,
		"t": snappedf(elapsed_frames / 60.0, 0.0001),
		"pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"speed": snappedf(horizontal_speed(), 0.01), "on_floor": player.is_on_floor(),
		"cam_dist": snappedf(spring_arm.get_hit_length(), 0.01),
		"body_yaw_deg": int(rad_to_deg((player.get_node("Body") as Node3D).rotation.y))})
	tree.paused = false


func _store(topic: String, name: String, image: Image, what: String, expect: String, extra: Dictionary) -> void:
	var n: int = _shot_counts.get(topic, 0) + 1
	_shot_counts[topic] = n
	var file := "%02d_%s.png" % [n, name]
	var path := shots_base.path_join(topic).path_join(shots_stamp).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("SHOT " + path)
	var entry := {"file": file, "what": what, "expect": expect}
	entry.merge(extra)
	var previous := _previous_image(topic, name)
	if previous.is_empty():
		entry["previous_run"] = null
		entry["changed_vs_previous"] = null  # a new image: review it
	else:
		entry["previous_run"] = previous["stamp"]
		entry["changed_vs_previous"] = snappedf(fraction_different(image, previous["image"]), 0.001)
	if not _manifest.has(topic):
		_manifest[topic] = []
	_manifest[topic].append(entry)


## True if the earlier run in `stamp` used the SAME renderer as this run
## (Forward+ and Compatibility look different, so they are never compared).
## Runs from before manifests recorded a renderer are accepted.
func _same_renderer(topic_dir: String, stamp: String) -> bool:
	var path := topic_dir.path_join(stamp).path_join("manifest.json")
	if not FileAccess.file_exists(path):
		return true
	# JSON.new().parse() reports a problem as a return value; JSON.parse_string()
	# PRINTS an ERROR line, which the runner's log scan would count as a failure.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return true  # unreadable old manifest: compare anyway; the index step reports it
	var data = json.data
	if data is Dictionary and data.has("renderer"):
		return data["renderer"] == RenderingServer.get_current_rendering_method()
	return true


## True if the PNG file is complete: a PNG always ends with an IEND chunk. A
## truncated old screenshot would otherwise make Godot print ERROR lines when
## loaded, which the runner's log scan counts as a failed step (lesson 31).
func _png_complete(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 12:
		return false
	file.seek_end(-8)
	return file.get_buffer(4).get_string_from_ascii() == "IEND"


## The same-named image from the newest EARLIER run of this topic (same renderer), or {}.
func _previous_image(topic: String, name: String) -> Dictionary:
	var topic_dir := shots_base.path_join(topic)
	var stamps: Array = []
	for dir in DirAccess.get_directories_at(topic_dir):
		if dir < shots_stamp:
			stamps.append(dir)
	stamps.sort()
	stamps.reverse()
	for stamp in stamps:
		if not _same_renderer(topic_dir, stamp):
			continue
		for file in DirAccess.get_files_at(topic_dir.path_join(stamp)):
			if file.ends_with("_" + name + ".png") and _png_complete(topic_dir.path_join(stamp).path_join(file)):
				var image := Image.load_from_file(topic_dir.path_join(stamp).path_join(file))
				if image:
					return {"stamp": stamp, "image": image}
	return {}


## Writes manifest.json into every topic folder this run touched.
func write_manifests() -> void:
	for topic in _manifest:
		var path := shots_base.path_join(topic).path_join(shots_stamp).path_join("manifest.json")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"run": shots_stamp, "topic": topic, "renderer": RenderingServer.get_current_rendering_method(), "images": _manifest[topic]}, "  "))


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
	if not _manifest.is_empty():
		write_manifests()
	print("RESULT: %s (%d failures)" % ["ALL PASS" if failures == 0 else "FAILED", failures])
	tree.quit(failures)
