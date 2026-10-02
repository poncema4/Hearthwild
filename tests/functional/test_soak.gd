extends SceneTree
## Functional test: a bot plays a real route and must never get stuck.
##
## Why this exists: the player reported sprint "randomly stopping" by playing. A
## bot that drives the real player the way a person would (Shift held the whole
## way, Space held on a second lap, doors opened with the real E key) finds a
## stall, a blocked path, a door that does not open or a fall through the world
## for free, on every run, with no agent to pay. Any future change that makes the
## player snag somewhere on this route fails here before anyone has to notice.
##
## The route is built from the village's own positions, so it follows the village if it moves.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_soak.gd
## Exit code = number of failures (0 = all pass).

const STALL_FRAMES := 20  # speed under 1 m/s for this many frames in a row while driving = stuck

var kit: PlaytestKit
var worst_stall := 0
var worst_stall_at := ""
var fell := false
var takeoffs := 0
var _was_on_floor := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	var village := kit.village
	var house1 := village.houses[0]
	var house2 := village.houses[1]
	var path: PackedVector2Array = kit.terrain.path_lines[0]

	# Lap 1: Shift held the whole way. Spawn -> the path -> the plaza -> into house 1 -> into house 2 -> home.
	await kit.teleport(Vector3(0, NAN, 0), 30)
	var reached_all := true
	var waypoints: Array[Vector3] = []
	for i in range(1, path.size() - 1):  # the path, stopping short of the well at its end
		waypoints.append(Vector3(path[i].x, 0, path[i].y))
	waypoints[waypoints.size() - 1] = Vector3(-17, 0, 8)
	waypoints.append(Vector3(-22, 0, 9))
	for point in waypoints:
		reached_all = await _drive_to(point, 1.0, false, "path waypoint (%.0f, %.0f)" % [point.x, point.z]) and reached_all

	for house: House in [house1, house2]:
		var outside: Vector3 = house.door_outside(2.0)
		reached_all = await _drive_to(outside, 0.8, false, "%s door" % house.name) and reached_all
		await _stop()
		var door: Door = house.door
		var toward: Vector3 = -house.global_transform.basis.z
		(kit.player.get_node("Body") as Node3D).rotation.y = atan2(-toward.x, -toward.z)
		kit.face(toward)
		await kit.physics_frames(6)
		await kit.tap("interact")
		await kit.physics_frames(50)
		kit.check("%s: pressing E at the door opens it" % house.name, door.is_open and not door.is_moving(), "open=%s moving=%s" % [door.is_open, door.is_moving()])
		reached_all = await _drive_to(house.interior_center(), 0.9, false, "%s interior" % house.name) and reached_all
		kit.check("%s: the bot is inside" % house.name, house.is_inside(kit.player.global_position), kit.where())
		reached_all = await _drive_to(house.door_outside(1.5), 0.8, false, "%s exit" % house.name) and reached_all
		await _stop()
		if house == house1:
			reached_all = await _drive_to(Vector3(-22, 0, 9), 1.0, false, "back to the path") and reached_all
	for i in range(path.size() - 2, -1, -1):  # home along the path, backwards
		if i == path.size() - 2:
			continue
		reached_all = await _drive_to(Vector3(path[i].x, 0, path[i].y), 1.0, false, "home waypoint %d" % i) and reached_all
	await _stop()
	kit.check("lap 1 (Shift held): every waypoint reached", reached_all)
	kit.check("lap 1: never stalled (speed under 1 m/s for %d frames while driving)" % STALL_FRAMES, worst_stall < STALL_FRAMES,
			"longest stall %d frames %s" % [worst_stall, worst_stall_at])

	# Lap 2: Shift AND Space held outdoors: continuous sprint-hopping along the path and back.
	worst_stall = 0
	takeoffs = 0
	await kit.teleport(Vector3(0, NAN, 0), 30)
	var lap2 := true
	for point in waypoints:
		lap2 = await _drive_to(point, 1.2, true, "hop waypoint (%.0f, %.0f)" % [point.x, point.z]) and lap2
	for i in range(waypoints.size() - 2, -1, -1):
		lap2 = await _drive_to(waypoints[i], 1.2, true, "hop home %d" % i) and lap2
	lap2 = await _drive_to(Vector3(0, 0, 0), 1.5, true, "hop home") and lap2
	await _stop()
	kit.check("lap 2 (Shift + Space held): every waypoint reached", lap2)
	kit.check("lap 2: never stalled", worst_stall < STALL_FRAMES, "longest stall %d frames %s" % [worst_stall, worst_stall_at])
	kit.check("lap 2: it kept hopping the whole way (about 7 hops in 11 s; at least 5)", takeoffs >= 5, "%d takeoffs" % takeoffs)
	kit.check("the bot never fell through the world", not fell)
	kit.finish()


## Drives toward `target` with Shift (and Space if `jump`) held, steering every frame.
## False (and a FAIL line) if it does not arrive within a generous time, i.e. it is stuck.
func _drive_to(target: Vector3, tolerance: float, jump: bool, label: String) -> bool:
	Input.action_press("move_forward")
	Input.action_press("sprint")
	if jump:
		Input.action_press("jump")
	else:
		Input.action_release("jump")
	var cap := int(kit.player.global_position.distance_to(target) / 4.0 * 60.0 * 2.0) + 120
	var low := 0
	for i in cap:
		var offset := target - kit.player.global_position
		offset.y = 0.0
		if offset.length() < tolerance:
			return true
		kit.face(offset.normalized())
		await kit.physics_frames(1)
		var on_floor := kit.player.is_on_floor()
		if _was_on_floor and not on_floor:
			takeoffs += 1
		_was_on_floor = on_floor
		low = low + 1 if kit.horizontal_speed() < 1.0 else 0
		if low > worst_stall:
			worst_stall = low
			worst_stall_at = "on the way to %s at (%.1f, %.1f)" % [label, kit.player.global_position.x, kit.player.global_position.z]
		if kit.player.global_position.y < -1.0:
			fell = true
	kit.check("reached %s" % label, false, "stuck: %.1f m away after %d frames, %s" % [
			Vector2(target.x - kit.player.global_position.x, target.z - kit.player.global_position.z).length(), cap, kit.where()])
	return false


func _stop() -> void:
	for action in ["move_forward", "sprint", "jump"]:
		Input.action_release(action)
	await kit.physics_frames(20)
