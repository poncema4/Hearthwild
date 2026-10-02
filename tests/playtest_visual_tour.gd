extends SceneTree
## Visual tour: walks the world and screenshots every area by topic, for
## visual QA (Hawkeye). Every shot is also checked automatically: a black,
## blown-out or flat single-colour image (failed render, camera inside
## geometry, empty scene) fails the test.
##
## Run: godot --path . --script res://tests/playtest_visual_tour.gd -- [<qa_output dir> [<run stamp>]]
## Shots: <qa_output>/{environment,nature,player}/<run stamp>/ (never deleted).
## Exit code = number of failures (0 = all pass).

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

	await _environment()
	await _nature()
	await _player()

	print("SCREENSHOTS: %s/{environment,nature,player}/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()


## The meadow from the spawn in all four directions, the pond, the hill
## ring, and an overview from above.
func _environment() -> void:
	for view in [["north", Vector3.FORWARD], ["east", Vector3.RIGHT], ["south", Vector3.BACK], ["west", Vector3.LEFT]]:
		await _frame(Vector3(0, NAN, 0), view[1], 4.0, -12.0)
		await _take("environment", "spawn_" + view[0])

	var pond := Vector3(kit.terrain.pond_center.x, 0, kit.terrain.pond_center.y)
	var shore := pond + Vector3(-1, 0, 1).normalized() * (kit.terrain.pond_radius + 3.0)
	await _frame(Vector3(shore.x, NAN, shore.z), (pond - shore).normalized(), 5.0, -22.0)
	await _take("environment", "pond_shore")

	# Up on the hill ring, looking back over the meadow.
	await _frame(Vector3(0, NAN, 44), Vector3.FORWARD, 5.0, -18.0)
	await _take("environment", "hill_rim_view")

	await _frame(Vector3(0, NAN, 0), Vector3(1, 0, -1).normalized(), kit.camera_rig.max_distance, kit.camera_rig.min_pitch_degrees)
	await _take("environment", "overview")


## Close-ups of each kind of tree, a rock, and the grass and flowers.
func _nature() -> void:
	var trees := kit.nature.get_trees()
	# The player's body is hidden for close-ups so the subject isn't blocked.
	var body := kit.player.get_node("Body") as Node3D
	body.visible = false
	for kind in ["tree_round", "tree_pine"]:
		var tree := _nearest_of_kind(trees, kind)
		if tree == null:
			kit.check("found a " + kind, false, "none placed")
			continue
		await _look_at_from(tree.position, 3.5, 1.5, -6.0)
		await _take("nature", kind + "_close")

	var rocks := kit.nature.get_rocks()
	kit.check("rocks were placed", rocks.size() > 10, "%d rocks" % rocks.size())
	if rocks.size() > 0:
		await _look_at_from(_nearest(rocks, Vector3.ZERO).position, 2.5, 1.5, -14.0)
		await _take("nature", "rock_close")

	# Low and close to see grass tufts and flowers.
	await _frame(Vector3(6, NAN, 6), Vector3(1, 0, 1).normalized(), kit.camera_rig.min_distance, -5.0)
	await _take("nature", "grass_and_flowers_low")
	body.visible = true


## The character from behind, the front, the side, and zoomed in.
func _player() -> void:
	var spot := Vector3(-3, NAN, 4)
	await _frame(spot, Vector3.FORWARD, 4.0, -15.0)
	await _take("player", "behind")
	await _frame(spot, Vector3.BACK, 4.0, -15.0)
	kit.player.get_node("Body").rotation.y = 0.0
	await _take("player", "front")
	await _frame(spot, Vector3.RIGHT, 4.0, -10.0)
	kit.player.get_node("Body").rotation.y = 0.0
	await _take("player", "side")
	await _frame(spot, Vector3.FORWARD, kit.camera_rig.min_distance, -10.0)
	await _take("player", "zoomed_in")


## Places the player, points the camera along `facing`, sets zoom and pitch.
## The camera looks the way `facing` points, from behind the player.
func _frame(where: Vector3, facing: Vector3, distance: float, pitch_degrees: float) -> void:
	await kit.teleport(where, 20)
	kit.face(facing)
	kit.spring_arm.spring_length = distance
	_pitch.rotation.x = deg_to_rad(pitch_degrees)
	await kit.frames(3)


## Stands `back` metres from a point on the world-centre side and looks at it.
func _look_at_from(target: Vector3, back: float, distance: float, pitch_degrees: float) -> void:
	var toward_centre := Vector3(-target.x, 0, -target.z).normalized()
	var spot := target + toward_centre * back
	await _frame(Vector3(spot.x, NAN, spot.z), -toward_centre, distance, pitch_degrees)


func _take(topic: String, name: String) -> void:
	kit.check_rendered(topic + "/" + name, await kit.shot(topic, name))


func _nearest_of_kind(nodes: Array[Node3D], kind: String) -> Node3D:
	var matching: Array[Node3D] = []
	for node in nodes:
		if node.scene_file_path.get_file().begins_with(kind):
			matching.append(node)
	return _nearest(matching, Vector3.ZERO) if matching.size() > 0 else null


func _nearest(nodes: Array[Node3D], point: Vector3) -> Node3D:
	var best: Node3D = nodes[0]
	for node in nodes:
		if node.position.distance_to(point) < best.position.distance_to(point):
			best = node
	return best
