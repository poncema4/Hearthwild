extends SceneTree
## Playtest: the basic zombie as the player sees it (topic `zombies`), for visual review: a zombie closing in at night, a close-up of
## its model, one burning in the noon sun, and one in the lamp-lit village. Besides the screenshots it checks from the camera's point of
## view that each zombie is ON the screen and not hidden behind scenery, and that the burn glow is really visible in the pixels.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_zombie.gd -- <qa_output> <run stamp>

var kit: PlaytestKit
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _zombie(x: float, z: float) -> Zombie:
	var zombie := Zombie.new()
	zombie.position = Vector3(x, kit.terrain.height_at(x, z) + 0.2, z)
	kit.world.add_child(zombie)
	return zombie


## Where a point on the zombie lands on the 1280x720 image, or (-1, -1) when it is behind the camera.
func _screen_point(world_point: Vector3, image: Image) -> Vector2:
	if _camera.is_position_behind(world_point):
		return Vector2(-1, -1)
	var view := kit.player.get_viewport().get_visible_rect().size
	var p := _camera.unproject_position(world_point)
	return Vector2(p.x * image.get_width() / view.x, p.y * image.get_height() / view.y)


func _on_screen(point: Vector2, image: Image) -> bool:
	return point.x > 40.0 and point.y > 40.0 and point.x < image.get_width() - 40.0 and point.y < image.get_height() - 40.0


## True when nothing but the zombie is between the camera and its chest. The player counts as an occluder too: a zombie hidden
## behind the dog's head is not a usable screenshot (found by looking at it, not by a check; lesson 61).
func _in_view(zombie: Zombie) -> bool:
	var chest := zombie.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(_camera.global_position, chest)
	var hit: Dictionary = kit.world.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == zombie


## How many flame-coloured pixels (bright, warm: red high, green mid, blue low) lie in a box around the zombie, from its feet to well above its head.
func _flame_pixels(image: Image, zombie: Zombie) -> int:
	var feet := _screen_point(zombie.global_position, image)
	var above := _screen_point(zombie.global_position + Vector3.UP * 2.6, image)
	var count := 0
	for y in range(maxi(int(above.y), 0), mini(int(feet.y), image.get_height())):
		for x in range(maxi(int(feet.x) - 70, 0), mini(int(feet.x) + 70, image.get_width())):
			var c := image.get_pixel(x, y)
			if c.r > 0.88 and c.g > 0.4 and c.g < 0.92 and c.b < 0.55 and c.r - c.b > 0.4:
				count += 1
	return count


## Average colour of a small square of the image around a point.
func _average(image: Image, center: Vector2, half: int = 6) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for dx in range(-half, half + 1):
		for dy in range(-half, half + 1):
			var x := clampi(int(center.x) + dx, 0, image.get_width() - 1)
			var y := clampi(int(center.y) + dy, 0, image.get_height() - 1)
			sum += image.get_pixel(x, y)
			count += 1
	return sum / float(count)


## Aim the camera `degrees` to the right of `toward`, so the target appears on the left of the screen, clear of the player's body.
func _aim_past(toward: Vector3, degrees: float = 18.0) -> void:
	kit.face(toward.rotated(Vector3.UP, deg_to_rad(-degrees)))


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camera = kit.spring_arm.get_node("Camera3D") as Camera3D
	var health := kit.player.get_node("Health") as Health
	var pitch: Node3D = kit.camera_rig.get_node("Pitch")
	pitch.rotation.x = deg_to_rad(-12.0)

	# 1. Night, the spawn clearing: a zombie 8 m ahead is walking toward the player.
	kit.day_night.set_time(21.5)
	await kit.teleport(Vector3(0.0, NAN, 0.0), 20)
	_aim_past(Vector3(0, 0, -1))
	var z := _zombie(0.0, -8.0)
	await kit.frames(8)
	var image := await kit.shot("zombies", "night_approach", "Night (9:30 PM) in the meadow: a zombie 8 m ahead walks toward the player with its arms out.",
			"A dark blue-ish meadow under moonlight; a small green-skinned figure with blue clothes and outstretched arms in the middle of the frame, upright, on the ground, facing the camera; the HUD clock reads 9:30 PM.")
	kit.check_rendered("zombies/night_approach", image)
	var chest := _screen_point(z.global_position + Vector3.UP * 1.2, image)
	kit.check("night approach: the zombie is on the screen (40 px inside every edge) and nothing hides it from the camera", _on_screen(chest, image) and _in_view(z), "chest at %s" % chest)
	var night_flames := _flame_pixels(image, z)
	var night_color := _average(image, chest)
	kit.check("night approach: it is not glowing (no sun at night): the chest is not more red than blue", night_color.r <= night_color.b + 0.03, "chest colour %s" % night_color)
	# Compare with what is directly BEHIND and BESIDE the zombie (same height, 34 px to each side, past its arms), not the ground below it:
	# at 8 m it is seen against the distant hillside (lesson 63: the first version compared with the near ground and could not fail).
	var ground := (_average(image, chest + Vector2(-34, 0), 4) + _average(image, chest + Vector2(34, 0), 4)) * 0.5
	var separation := Vector3(night_color.r - ground.r, night_color.g - ground.g, night_color.b - ground.b).length()
	kit.check("night approach: it is readable, the chest is clearly apart from what is beside it (colour distance at least 0.25) AND lighter than it (luminance at least 0.04 higher): a dark hole is not 'readable', and Compatibility draws a lighter background than Forward+",
			separation >= 0.25 and night_color.get_luminance() >= ground.get_luminance() + 0.04, "chest %s vs ground %s: distance %.3f, luminance %.3f vs %.3f" % [night_color, ground, separation, night_color.get_luminance(), ground.get_luminance()])
	z.free()

	# 2. Close-up of the model.
	await kit.teleport(Vector3(0.0, NAN, 0.0), 20)
	_aim_past(Vector3(0, 0, -1), 36.0)  # a close subject needs a wider angle to clear the dog's head
	kit.spring_arm.spring_length = 2.6
	z = _zombie(0.0, -2.8)
	z.walk_speed = 0.0  # hold it still for the portrait
	await kit.frames(10)
	image = await kit.shot("zombies", "close_up", "A zombie 2.8 m from the player, seen from just behind the player's shoulder.",
			"A blocky green-skinned figure: square head with two red eyes facing the camera, blue torso, both arms stretched straight out toward the player, two dark legs; standing on the grass, nothing clipping into the ground.")
	kit.check_rendered("zombies/close_up", image)
	chest = _screen_point(z.global_position + Vector3.UP * 1.2, image)
	var eyes := _screen_point(z.global_position + Vector3(0.0, 1.76, -0.215).rotated(Vector3.UP, z.rotation.y), image)
	kit.check("close-up: the zombie fills a good part of the picture (head and chest well inside the screen) and nothing hides it", _on_screen(chest, image) and _on_screen(eyes, image) and _in_view(z), "chest %s, eyes %s" % [chest, eyes])
	var left_eye := _screen_point(z.global_position + Vector3(-0.1, 1.76, -0.215).rotated(Vector3.UP, z.rotation.y), image)
	var eye_color := _average(image, left_eye, 1)
	kit.check("close-up: the eyes are RED in the picture (red above 0.7, green and blue under 0.5), not pink or white", eye_color.r > 0.7 and eye_color.g < 0.5 and eye_color.b < 0.5, "left eye colour %s at %s" % [eye_color, left_eye])
	z.free()
	kit.spring_arm.spring_length = 4.0

	# 3. Noon, the open meadow: a zombie standing in the sun glows orange as it burns.
	kit.day_night.set_time(12.0)
	await kit.teleport(Vector3(0.0, NAN, 0.0), 20)
	_aim_past(Vector3(0, 0, -1), 30.0)
	z = _zombie(0.0, -4.5)
	z.walk_speed = 0.0
	await kit.physics_frames(90)  # about 1.5 s of sun: it is burning and has lost some hp
	await kit.frames(6)
	image = await kit.shot("zombies", "burning", "Noon: a zombie 4.5 m ahead stands in full sunlight and is burning (it has lost hit points): flames and smoke rise off it.",
			"The same figure in bright daylight, scorched a little toward orange, with square orange-red flames and grey smoke rising from its body; arms still stretched forward, upright and intact.")
	kit.check_rendered("zombies/burning", image)
	chest = _screen_point(z.global_position + Vector3.UP * 1.2, image)
	var burn_flames := _flame_pixels(image, z)
	kit.check("burning: it is on the screen, really burning (hp under 20, is_burning), and FLAMES are visible around it: at least 25 flame-coloured pixels and more than 3 times the night control (the glowing eyes alone give about 10; flames give 43 in Forward+, up to 867 in Compatibility)",
			_on_screen(chest, image) and _in_view(z) and z.is_burning() and (z.get_node("Health") as Health).current < 20.0 and burn_flames >= 25 and burn_flames > night_flames * 3,
			"flame pixels %d (night control %d), hp %.1f" % [burn_flames, night_flames, (z.get_node("Health") as Health).current])
	z.free()

	# 4. Evening in the village: lit lamps, a zombie coming down the path.
	kit.day_night.set_time(21.0)
	var plaza := kit.village.center()
	var from := plaza + Vector3(0.0, 0.0, 8.0)
	await kit.teleport(Vector3(from.x, NAN, from.z), 20)
	_aim_past(Vector3(0, 0, -1))
	z = _zombie(from.x - 2.0, from.z - 8.0)
	z.walk_speed = 0.0
	await kit.frames(10)
	image = await kit.shot("zombies", "village_night", "Night (9 PM) at the village plaza: lamp posts lit, a zombie 9 m ahead near the plaza centre.",
			"The plaza with warm lit lamps and cottages in moonlight; a small green figure with outstretched arms standing among them; the figure and the buildings are all clearly readable, nothing is pitch black.")
	kit.check_rendered("zombies/village_night", image)
	chest = _screen_point(z.global_position + Vector3.UP * 1.2, image)
	kit.check("village night: the zombie is on the screen and nothing hides it", _on_screen(chest, image) and _in_view(z), "chest at %s" % chest)
	z.free()
	health.heal(100.0)
	kit.day_night.set_time(10.0)
	print("SCREENSHOTS: %s/zombies/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
