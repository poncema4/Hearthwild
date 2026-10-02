extends SceneTree
## Functional test: the village is built, flat, solid, walkable and reachable.
##
## Why this exists: a village that LOOKS right can still trap the player (a
## door narrower than the capsule), let them walk through a wall (missing
## collision), float over a slope, or sit on a tree. These checks walk the
## real player through every door and along the real path, and ray-cast the
## walls, roofs and props. Every check was proven by breaking the feature and
## watching it fail (AGENTS.md section 8).
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_village.gd
## Exit code = number of failures (0 = all pass).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var terrain := kit.terrain
	var village := kit.village
	var space: PhysicsDirectSpaceState3D = (kit.world as Node3D).get_world_3d().direct_space_state

	_check_layout(kit, terrain, village)
	_check_nature_keeps_out(kit, terrain)
	await _check_solid(kit, village, space)
	await _check_doors(kit, village)
	await _check_walls_block(kit, village)
	await _check_wall_slide(kit, village)
	await _check_path(kit, terrain)
	_check_door_links(kit, terrain, village)
	kit.finish()


## Built, flat, spaced, and sized for the player.
func _check_layout(kit: PlaytestKit, terrain: Terrain, village: Village) -> void:
	var tally := {"Well": 0, "LampPost": 0, "Bench": 0, "NoticeBoard": 0, "Fence": 0}
	for prop in village.props:
		var kind: String = prop.get_meta("kind", "?")
		tally[kind] = tally.get(kind, 0) + 1
	kit.check("village has 3 houses and exactly 1 well, 4 lamp posts, 2 benches, 1 notice board, 3 fences",
			village.houses.size() == 3 and tally == {"Well": 1, "LampPost": 4, "Bench": 2, "NoticeBoard": 1, "Fence": 3},
			"%d houses, props %s" % [village.houses.size(), tally])

	# Ground under every house corner and prop is flat (height 0): a slope here
	# would leave a gap under a wall or bury half of it.
	var worst := 0.0
	var worst_at := ""
	for house in village.houses:
		for corner in house.footprint_corners():
			var h := absf(terrain.height_at(corner.x, corner.z))
			if h > worst:
				worst = h
				worst_at = "%s corner (%.1f, %.1f)" % [house.name, corner.x, corner.z]
	kit.check("ground is flat under every house corner", worst < 0.01, "worst height %.3f m at %s" % [worst, worst_at])

	var off_ground := 0
	for prop in village.props:
		if absf(prop.global_position.y - terrain.height_at(prop.global_position.x, prop.global_position.z)) > 0.01:
			off_ground += 1
	kit.check("every prop stands on the ground", off_ground == 0, "%d of %d props off the ground" % [off_ground, village.props.size()])

	# Houses must not overlap each other or any prop.
	var closest := 1e9
	for i in village.houses.size():
		for j in range(i + 1, village.houses.size()):
			closest = minf(closest, village.houses[i].global_position.distance_to(village.houses[j].global_position))
	kit.check("houses are at least 9 m apart (real: 12 m)", closest >= 9.0, "closest pair %.1f m" % closest)

	var props_in_houses := 0
	for house in village.houses:
		for prop in village.props:
			var local := house.to_local(prop.global_position)
			if absf(local.x) < House.WIDTH * 0.5 + 0.7 and absf(local.z) < House.DEPTH * 0.5 + 0.7:
				props_in_houses += 1
	kit.check("no prop sits inside or against a house", props_in_houses == 0, "%d overlaps" % props_in_houses)

	# Everything stays inside the flat zone, so it never straddles a slope.
	var outside := 0
	for house in village.houses:
		for corner in house.footprint_corners():
			if not terrain.in_village(corner.x, corner.z, 0.0):
				outside += 1
	kit.check("every house corner is inside the flat zone", outside == 0, "%d corners outside radius %.0f m" % [outside, terrain.village_flat_radius])

	# Doors must be bigger than the player or the house is a trap.
	var capsule: CapsuleShape3D = kit.player.get_node("CollisionShape3D").shape
	kit.check("door is wider than the player with room to spare", House.DOOR_WIDTH >= capsule.radius * 2.0 + 0.4,
			"door %.2f m, player %.2f m wide" % [House.DOOR_WIDTH, capsule.radius * 2.0])
	kit.check("door is taller than the player with room to spare", House.DOOR_HEIGHT >= capsule.height + 0.3,
			"door %.2f m, player %.2f m tall" % [House.DOOR_HEIGHT, capsule.height])

	# Each door faces the plaza (the village centre), so the paths run the short way.
	var worst_angle := 0.0
	for house in village.houses:
		var front: Vector3 = house.global_transform.basis.z
		var to_centre := (village.center() - house.global_position).normalized()
		worst_angle = maxf(worst_angle, rad_to_deg(front.angle_to(to_centre)))
	kit.check("every door faces the plaza", worst_angle < 15.0, "worst door is %.0f degrees off" % worst_angle)


## No tree or rock in the village or on a path (lessons: nature must not grow through buildings).
func _check_nature_keeps_out(kit: PlaytestKit, terrain: Terrain) -> void:
	var in_village := 0
	var on_path := 0
	var total := 0
	for node in kit.nature.get_trees() + kit.nature.get_rocks():
		total += 1
		var p := node.global_position
		if terrain.in_village(p.x, p.z, 1.5):
			in_village += 1
		if terrain.path_distance(p.x, p.z) < 2.6:
			on_path += 1
	kit.check("no tree or rock inside the village", in_village == 0 and total > 50, "%d inside, of %d placed" % [in_village, total])
	kit.check("no tree or rock on a path", on_path == 0, "%d on a path" % on_path)


## Roofs and props are solid: rays from above and from the side hit them.
func _check_solid(kit: PlaytestKit, village: Village, space: PhysicsDirectSpaceState3D) -> void:  # coroutine
	for house in village.houses:
		# The roof is a gable: highest at the ridge (x = 0), lower toward the eaves. Two-sided
		# bounds (an inverted roof used to pass a one-sided check, lesson 39).
		# Sampled 0.15 m beside the ridge: exactly x = 0 is the seam between the two slabs.
		var ridge_y := _roof_y(space, house, 0.15)
		var left_y := _roof_y(space, house, -2.0)
		var right_y := _roof_y(space, house, 2.0)
		var top := House.WALL_HEIGHT + House.ROOF_RISE
		kit.check("%s: the roof peaks at the ridge and slopes down on both sides" % house.name,
				ridge_y > top - 0.1 and ridge_y < top + 0.5 and ridge_y - left_y > 0.6 and ridge_y - right_y > 0.6,
				"ridge y=%.2f (expect %.1f to %.1f), 2 m left y=%.2f, 2 m right y=%.2f" % [ridge_y, top - 0.1, top + 0.5, left_y, right_y])

		# Closed (the default) the leaf is solid: a ray through the doorway at waist height hits it.
		var closed_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				house.to_global(Vector3(0, 1.0, House.DEPTH * 0.5 + 1.0)), house.to_global(Vector3(0, 1.0, House.DEPTH * 0.5 - 1.5))))
		kit.check("%s: the closed door is solid" % house.name,
				not house.door.is_open and not closed_hit.is_empty() and house.door.is_ancestor_of(closed_hit["collider"]),
				"door open=%s, ray hit=%s" % [house.door.is_open, "the door" if not closed_hit.is_empty() and house.door.is_ancestor_of(closed_hit["collider"]) else str(closed_hit.get("collider"))])

		# Open, the doorway is clear at knee, waist and head-plus-slack height.
		house.door.open_instantly()
		await kit.physics_frames(2)  # the physics server picks up the moved leaf one step later
		var blocked := 0
		for y in [0.3, 1.0, 2.0]:
			var a := house.to_global(Vector3(0, y, House.DEPTH * 0.5 + 1.0))
			var b := house.to_global(Vector3(0, y, House.DEPTH * 0.5 - 1.5))
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b)).is_empty():
				blocked += 1
		kit.check("%s: the doorway is clear at knee, waist and 2 m height" % house.name, blocked == 0, "%d of 3 rays blocked" % blocked)

	var passable := 0
	for prop in village.props:
		var from := prop.global_position + prop.global_transform.basis.z * 3.0 + Vector3(0, 0.3, 0)
		var to := prop.global_position + Vector3(0, 0.3, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		if hit.is_empty() or not prop.is_ancestor_of(hit["collider"]):
			passable += 1
	kit.check("every prop is solid at knee height", passable == 0, "%d of %d props can be walked through" % [passable, village.props.size()])


## Walk the real player through each door: they must end up inside.
func _check_doors(kit: PlaytestKit, village: Village) -> void:
	for house in village.houses:
		var start := house.door_outside(2.5)
		var inward := (house.interior_center() - start)
		inward.y = 0.0

		# Closed: the player walks at the door and stays outside.
		house.door.close_instantly()
		await kit.teleport(Vector3(start.x, NAN, start.z), 20)
		kit.face(inward.normalized())
		await kit.hold(["move_forward"], 100)
		var closed_local := house.to_local(kit.player.global_position)
		kit.check("%s: a CLOSED door stops the player outside" % house.name,
				not house.is_inside(kit.player.global_position) and closed_local.z > House.DEPTH * 0.5,
				"ended at local z=%.2f (door line at %.2f)" % [closed_local.z, House.DEPTH * 0.5])

		# Open: the same walk ends inside.
		house.door.open_instantly()
		await kit.teleport(Vector3(start.x, NAN, start.z), 20)
		kit.face(inward.normalized())
		await kit.hold(["move_forward"], 100)
		await kit.physics_frames(10)
		var p := kit.player.global_position
		kit.check("%s: walking in through the OPEN door ends inside" % house.name, house.is_inside(p) and kit.player.is_on_floor(),
				"%s, inside=%s" % [kit.where(), house.is_inside(p)])


## Walk the real player straight at EVERY solid wall from outside: they must stay out.
## One wall at a time, because a collider lost on a single wall (a refactor of `_box`)
## must not hide behind the others (lesson 39). Entries: name, start (house-local), walk
## direction (house-local), axis walked along (0 = x, 1 = z... of the local vector), outer face.
func _check_walls_block(kit: PlaytestKit, village: Village) -> void:
	var half_w := House.WIDTH * 0.5
	var half_d := House.DEPTH * 0.5
	var side_x := (House.DOOR_WIDTH + (House.WIDTH - House.DOOR_WIDTH) * 0.5) * 0.5  # centre of a front wall piece
	var walls := [
		["left wall", Vector3(-half_w - 2.0, 0, 0), Vector3.RIGHT, 0, half_w],
		["right wall", Vector3(half_w + 2.0, 0, 0), Vector3.LEFT, 0, half_w],
		["back wall", Vector3(0, 0, -half_d - 2.0), Vector3.BACK, 2, half_d],
		["front wall, left of the door", Vector3(-side_x, 0, half_d + 2.0), Vector3.FORWARD, 2, half_d],
		["front wall, right of the door", Vector3(side_x, 0, half_d + 2.0), Vector3.FORWARD, 2, half_d],
	]
	for house in village.houses:
		for wall in walls:
			var start := house.to_global(wall[1])
			await kit.teleport(Vector3(start.x, NAN, start.z), 20)
			kit.face((house.global_transform.basis * wall[2]).normalized())
			await kit.hold(["move_forward"], 100)
			var local := house.to_local(kit.player.global_position)
			var depth := absf(local[wall[3]])
			kit.check("%s: walking at the %s does not get through" % [house.name, wall[0]],
					depth >= wall[4] and not house.is_inside(kit.player.global_position),
					"ended at local %s, distance from centre %.2f (outer face at %.2f)" % [local.snapped(Vector3(0.01, 0.01, 0.01)), depth, wall[4]])


## Walking into a wall at a shallow angle slides along it instead of sticking.
func _check_wall_slide(kit: PlaytestKit, village: Village) -> void:
	var house := village.houses[0]
	var half_w := House.WIDTH * 0.5
	var start := house.to_global(Vector3(-half_w - 2.0, 0, -1.0))
	await kit.teleport(Vector3(start.x, NAN, start.z), 20)
	# Almost straight into the wall (+X): only 5 degrees toward +Z along it. Godot's default
	# `wall_min_slide_angle` (15 degrees) makes such a near-head-on walk stick.
	var direction := (house.global_transform.basis * Vector3(cos(deg_to_rad(5.0)), 0, sin(deg_to_rad(5.0)))).normalized()
	kit.face(direction)
	await kit.hold(["move_forward"], 90)
	var local := house.to_local(kit.player.global_position)
	kit.check("walking almost head-on into a wall slides along it (at least 0.3 m) instead of sticking",
			local.z - (-1.0) > 0.3 and local.x < -half_w, "slid %.2f m along the wall, local x %.2f" % [local.z + 1.0, local.x])


## Y of the roof surface straight above a point `local_x` metres to the side of the house centre.
func _roof_y(space: PhysicsDirectSpaceState3D, house: House, local_x: float) -> float:
	var from := house.to_global(Vector3(local_x, 12.0, 0.0))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -12, 0)))
	if hit.is_empty() or not house.is_ancestor_of(hit["collider"]):
		return -1.0
	return hit["position"].y


## Every door has a dirt link: one end 0.9 m in front of the door (at the doorstep), the
## other at the plaza. Moving a house without its link now fails (lesson 39).
func _check_door_links(kit: PlaytestKit, terrain: Terrain, village: Village) -> void:
	for house in village.houses:
		var door_end := house.door_outside(0.9)
		var door_xz := Vector2(door_end.x, door_end.z)
		var found := false
		var best := 1e9
		for i in range(1, terrain.path_lines.size()):
			var line := terrain.path_lines[i]
			var d := minf(line[0].distance_to(door_xz), line[line.size() - 1].distance_to(door_xz))
			best = minf(best, d)
			var other: Vector2 = line[line.size() - 1] if line[0].distance_to(door_xz) <= line[line.size() - 1].distance_to(door_xz) else line[0]
			if d < 0.3 and other.distance_to(terrain.village_center) < 1.0:
				found = true
		kit.check("%s: a dirt path runs from its doorstep to the plaza" % house.name, found,
				"closest path end to the doorstep (%.1f, %.1f) is %.2f m away" % [door_xz.x, door_xz.y, best])


## Walk the path segment by segment from the spawn to the plaza.
func _check_path(kit: PlaytestKit, terrain: Terrain) -> void:
	var line := terrain.path_lines[0]
	kit.check("main path starts at the spawn and ends at the village centre",
			line[0].length() < 1.0 and line[line.size() - 1].distance_to(terrain.village_center) < 1.0,
			"starts %s, ends %s" % [line[0], line[line.size() - 1]])
	for i in range(line.size() - 1):
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		await kit.teleport(Vector3(a.x, NAN, a.y), 20)
		var heading := Vector3(b.x - a.x, 0, b.y - a.y)
		kit.face(heading.normalized())
		# Walk in short bursts until close to the end point (or out of time: a
		# blockage on the path shows up as running out of frames).
		var frame_cap := int(heading.length() / 4.0 * 60.0 * 1.5) + 30
		var spent := 0
		var left := 1e9
		while spent < frame_cap:
			left = Vector2(kit.player.global_position.x, kit.player.global_position.z).distance_to(b)
			if left < 1.8:
				break
			await kit.hold(["move_forward"], 3)
			spent += 3
		left = Vector2(kit.player.global_position.x, kit.player.global_position.z).distance_to(b)
		kit.check("path segment %d walks through (%.0f, %.0f) to (%.0f, %.0f)" % [i + 1, a.x, a.y, b.x, b.y],
				left < 1.8, "ended %.2f m from the end point after %d of %d frames" % [left, spent, frame_cap])
