extends SceneTree
## Playtest: the lake (topic `lake`), for visual review: wide view by day, dusk and night, the reeds, the lily pads
## and an aerial view of the whole shape.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_lake.gd -- <qa_output> <run stamp>

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
	var spot := kit.fishing.spots[0]
	var stand := spot.standing_spot()
	var toward := spot.toward_water

	await _frame(stand, toward, 6.0, -12.0)
	kit.check_rendered("lake/day_wide", await kit.shot("lake", "day_wide", "Standing at a fishing spot on the bank at 10 AM, looking out over the lake.", "Clear water that is pale turquoise in the shallows near the bank and deep blue further out, with gentle ripples and sky reflection; a thin white foam line at the water's edge; sand then grass on the bank; reeds along the shore; lily pads on the water; no hard circular edge to the water, no square corners, nothing floating in the air."))

	var reeds := _nearest(kit.world.get_node("LakeDecor").reed_positions(), stand + toward * 0.0, 3.0)
	await _frame(Vector3(reeds.x, NAN, reeds.z) + Vector3(0, 0, 0), (Vector3(kit.terrain.pond_center.x, 0, kit.terrain.pond_center.y) - reeds).normalized().rotated(Vector3.UP, deg_to_rad(70.0)), 3.2, -6.0)
	kit.check_rendered("lake/reeds", await kit.shot("lake", "reeds", "Low camera on the bank beside a clump of reeds, looking along the shore.", "Tall thin green reeds in clumps standing at the water's edge, leaning slightly, in two shades of green; sand and mud at their feet; water beyond; no reed floating or sunk."))

	var pad := _nearest(kit.world.get_node("LakeDecor").pad_positions(), stand, 99.0)
	var from_pad := Vector3(kit.terrain.pond_center.x, 0, kit.terrain.pond_center.y) + (Vector3(stand.x - kit.terrain.pond_center.x, 0, stand.z - kit.terrain.pond_center.y)).normalized() * 0.0
	await _frame(stand, (Vector3(pad.x, 0, pad.z) - stand).normalized(), 3.0, -10.0)
	kit.check_rendered("lake/pads", await kit.shot("lake", "pads", "Standing on the bank looking toward the nearest lily pad.", "Round flat green lily pads lying on the water surface, slightly different sizes and greens, lit by the sun with the water showing between them."))

	await _frame(stand, toward, 28.0, -58.0)
	kit.check_rendered("lake/aerial", await kit.shot("lake", "aerial", "Camera 28 m up looking down on the lake from the bank (a screenshot-only boom).", "An irregular blue lake with a pale foam outline, a sandy ring, reeds as a green fringe, lily pads, and the fishing signposts around it; grass and trees beyond a clear bank; no straight or circular cut-off edge."))

	for entry in [["dusk", 18.5, "Dusk (6:30 PM): the same view as the wide shot.", "The water reflects the orange-purple horizon, darker than by day but readable; foam still visible; no black water."], ["night", 22.0, "Night (10 PM): the same view as the wide shot.", "Dark blue water under the moon, much darker than by day but not pure black; the bank, reeds and signposts still readable; no bright white foam band."]]:
		kit.day_night.set_time(entry[1])
		await _frame(stand, toward, 6.0, -12.0)
		var image: Image = await kit.shot("lake", entry[0], entry[2], entry[3])
		kit.check_rendered("lake/" + entry[0], image)
		if entry[0] == "dusk":
			# Review finding (Hawkeye): sharp orange sky reflections through the ripples made the dusk water read as lava
			# (5.5% of the water's pixels were orange-tinted; the fixed shader has 0.2%).
			# The water on both sides of the character (the dog stands in the middle of the old box: its orange fur and glow are not water).
			var left := Rect2i(330, 315, 230, 90)
			var right := Rect2i(690, 315, 240, 90)
			var warm := (_warm_fraction(image, left) * left.size.x + _warm_fraction(image, right) * right.size.x) / float(left.size.x + right.size.x)
			kit.check("the dusk water is not a pattern of orange cells (under 1.5 percent of its pixels orange-tinted)", warm < 0.015, "%.3f of the pixels" % warm)
	kit.day_night.set_time(10.0)
	print("SCREENSHOTS: %s/lake/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


## Puts the player at `where`, points the camera along `facing`, sets zoom and pitch.
func _frame(where: Vector3, facing: Vector3, distance: float, pitch_degrees: float) -> void:
	await kit.teleport(Vector3(where.x, NAN, where.z), 20)
	kit.face(facing)
	kit.spring_arm.spring_length = distance
	_pitch.rotation.x = deg_to_rad(pitch_degrees)
	await kit.frames(4)


## The point from `points` nearest to `from` that is at least `min_distance` away from it.
func _nearest(points: Array[Vector3], from: Vector3, min_distance: float) -> Vector3:
	var best := points[0]
	var best_distance := 1e9
	for point in points:
		var d := Vector2(point.x, point.z).distance_to(Vector2(from.x, from.z))
		if d >= min_distance and d < best_distance:
			best = point
			best_distance = d
	return best


## Fraction of the pixels in `area` whose red exceeds blue by more than 30/255 (orange-tinted).
func _warm_fraction(image: Image, area: Rect2i) -> float:
	var warm := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := image.get_pixel(x, y)
			if (c.r - c.b) * 255.0 > 30.0:
				warm += 1
	return float(warm) / float(area.size.x * area.size.y)
