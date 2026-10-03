extends SceneTree
## Visual tour: walks the world and screenshots every area by topic, for
## visual QA (Hawkeye). Every shot is also checked automatically: a black,
## blown-out or flat single-colour image (failed render, camera inside
## geometry, empty scene) fails the test.
##
## Run: godot --path . --script res://tests/playtests/playtest_visual_tour.gd -- [<qa_output dir> [<run stamp>]]
## Shots: <qa_output>/{environment,nature,player}/<run stamp>/ (never deleted).
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var _pitch: Node3D

## What each screenshot shows and what a correct frame looks like (goes into manifest.json).
const SHOTS := {
	"environment/spawn_north": ["Spawn clearing looking north (-Z), player from behind.", "Meadow, trees on hills, bright and soft, soft shadows."],
	"environment/spawn_east": ["Spawn clearing looking east.", "Hills and trees; the dog's side or face visible; no dark bands."],
	"environment/spawn_south": ["Spawn clearing looking south, player seen from the front.", "The dog's face visible; long soft shadow; hills lit, not murky."],
	"environment/spawn_west": ["Spawn clearing looking west.", "Trees at hill base, rocks, pleasant meadow."],
	"environment/pond_shore": ["Standing at the pond shore looking at the water.", "Round pond with a smooth sandy ring, no square corners, no hard sand edge."],
	"environment/hill_rim_view": ["On the hill rim (0, 88) looking back over the meadow.", "Wide valley below, grass in the foreground, rocks, big soft tree shadows."],
	"environment/overview": ["Camera at max zoom and -60 deg pitch, standing at (-8, 6) and looking toward the village.", "Grass and flowers, the dirt path from the spawn running toward the village, and the first cottage roof or wall at the top of the frame."],
	"nature/tree_round_close": ["Close-up of the nearest round tree; player body hidden.", "The tree is the subject: brown trunk, layered green canopy, grass and rocks around."],
	"nature/tree_pine_close": ["Close-up of the nearest pine; player body hidden.", "Pine is the subject: warm brown trunk, rich green tiers, shaded underside is fine."],
	"nature/rock_close": ["Close-up of the nearest rock; player body hidden.", "Grey rock sits on the ground (no floating), flowers nearby."],
	"nature/grass_and_flowers_low": ["Very low camera in the grass near (6, 6).", "Deep green blades, pink/blue/yellow flowers, not dark, not pale or ghostly."],
	"player/behind": ["The dog from behind at (-3, 4), default camera.", "Dog grounded with a shadow, curled tail with a cream tip, two ears; trees and hills behind."],
	"player/front": ["The dog seen from the front.", "Face with two shiny eyes, cream muzzle and dark nose; shadow; nothing clipping."],
	"player/side": ["The dog in profile.", "Muzzle in front of the face, floppy ear at the side, grounded, shadow."],
	"player/zoomed_in": ["Camera at minimum zoom (1.5 m).", "The dog large in frame, soft shading, no clipping into the camera."],
}


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

	print("RENDER COST (worst frame of the tour): %s" % str(_worst))
	var method := RenderingServer.get_current_rendering_method()
	var draw_budget: int = BUDGET_DRAW_CALLS.get(method, 0)
	kit.check("the busiest frame stays inside the render budget on %s (%d triangles, %d objects, %d draw calls)" % [method, BUDGET_PRIMITIVES, BUDGET_OBJECTS, draw_budget],
			draw_budget > 0 and _worst["primitives"] > 100_000 and _worst["primitives"] <= BUDGET_PRIMITIVES and _worst["objects"] <= BUDGET_OBJECTS and _worst["draw_calls"] <= draw_budget, "%s %s" % [method, str(_worst)])
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
	await _frame(Vector3(0, NAN, 88), Vector3.FORWARD, 5.0, -18.0)
	await _take("environment", "hill_rim_view")

	# Looks toward the village (centre about (-20, 14)); the dirt path leads the eye there.
	await _frame(Vector3(-8, NAN, 6), Vector3(-12, 0, 8).normalized(), kit.camera_rig.max_distance, kit.camera_rig.min_pitch_degrees)
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


## Per-frame cost ceilings, measured as the WORST frame of this tour (1.58 M triangles, 2,469 objects, 1,363 draw calls
## on Forward+ / 2,457 on Compatibility, with the 8-cottage village; the first 240 m world measured 1.48 M / 2,084 / 833,
## and the spawn view alone is much lighter, so measure the tour, not one view) plus about 35%. They catch "someone scattered 10x the trees" without an agent. Raise them
## on purpose, in a PR that says why (the world is meant to grow, step by step).
const BUDGET_PRIMITIVES := 2_150_000
const BUDGET_OBJECTS := 3_350
## Draw calls differ by renderer (Compatibility has no batching and more passes): Forward+ 1,363, Compatibility 2,457 measured.
const BUDGET_DRAW_CALLS := {"forward_plus": 1_850, "gl_compatibility": 3_300}
var _worst := {"primitives": 0, "objects": 0, "draw_calls": 0}


func _take(topic: String, name: String) -> void:
	var info: Array = SHOTS.get(topic + "/" + name, ["", ""])
	kit.check_rendered(topic + "/" + name, await kit.shot(topic, name, info[0], info[1]))
	_worst["primitives"] = maxi(_worst["primitives"], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	_worst["objects"] = maxi(_worst["objects"], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	_worst["draw_calls"] = maxi(_worst["draw_calls"], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


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
