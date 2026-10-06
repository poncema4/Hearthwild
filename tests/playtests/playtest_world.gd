extends SceneTree
## Playtest: the bigger, organised world (topic `world`), for visual review: the village from above (all 16 cottages, the streets, the plaza), a far-ring
## cottage with its fenced back yard and gate, the market and weapon rack beside the plaza, and grass growing between the cottages. A camera of our own is
## used so the shots are not limited by the player's camera distance.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_world.gd -- <qa_output> <run stamp>

var kit: PlaytestKit
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _aim(from: Vector3, to: Vector3) -> void:
	_camera.global_position = from
	_camera.look_at(to, Vector3.UP)


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	kit.day_night.set_time(11.0)
	await kit.teleport(Vector3(0, NAN, 0), 20)
	_camera = Camera3D.new()
	kit.world.add_child(_camera)
	_camera.current = true
	_camera.far = 600.0
	var centre := kit.village.center()

	_aim(centre + Vector3(0, 125, 40), centre + Vector3(0, 0, 4))
	await kit.frames(20)
	var image := await kit.shot("world", "village_from_above", "The whole village from 125 m up: 16 cottages in three rings around the plaza, dirt paths running between them, fenced back yards on the outer cottages, trees and the lake beyond.",
			"Green meadow with a round village in the middle: a cobbled plaza with a well, cottages with red, blue and brown roofs arranged in rings, tan dirt paths joining each door to the plaza, small fenced yards behind the outer cottages, grass all around (not bare patches), trees outside.")
	kit.check_rendered("world/village_from_above", image)

	var far_house := kit.village.houses[kit.village.houses.size() - 1]
	var yard_centre := far_house.to_global(Vector3(0, 0, -5.5))
	_aim(far_house.to_global(Vector3(11, 7, -10)), yard_centre)
	await kit.frames(20)
	image = await kit.shot("world", "yard_and_gate", "A far-ring cottage seen from beside and behind: its fenced back yard with a gate in the middle of the back fence, the front door side open.",
			"A cottage with a wooden fence making a U-shaped yard behind it, a gate (two taller posts with an open leaf) in the middle of the back fence, grass inside and outside the yard, the cottage's door side free of fences.")
	kit.check_rendered("world/yard_and_gate", image)

	var rack := kit.world.get_tree().get_first_node_in_group(&"weapon_rack") as Node3D
	var rack_spot := rack.global_position
	_aim(rack_spot + rack.global_transform.basis.x * 9.0 + rack.global_transform.basis.z * 2.0 + Vector3(0, 6.0, 0), rack_spot + Vector3(0, 0.8, 0))
	await kit.frames(20)
	image = await kit.shot("world", "rack_and_market", "The weapon rack near the plaza (sword, spear and axe on a wooden frame) with the market stalls around it.",
			"A wooden rack holding a sword, a spear and an axe; striped market stalls (red, blue, yellow) with goods on the counters nearby; open grass and a dirt path; nothing overlapping.")
	kit.check_rendered("world/rack_and_market", image)

	var cottage := kit.village.houses[kit.village.houses.size() - 3]
	var lawn := cottage.to_global(Vector3(-5.5, 0, 3.0))
	_aim(lawn + Vector3(0, 1.6, 6.0), lawn + Vector3(0, 0.3, 0))
	await kit.frames(20)
	image = await kit.shot("world", "village_lawn", "A low view over the lawn between two cottages: grass tufts growing in the village.",
			"Green grass tufts and some flowers on the village ground right beside a cottage wall, a dirt path nearby with no grass on it, no bare flat patches.")
	kit.check_rendered("world/village_lawn", image)
	print("SCREENSHOTS: %s/world/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
