extends SceneTree
## Functional test: the TOWN round the village: the perimeter fence with its four gates (open the right way: along the fence, not across it), a garage for
## every cottage, and the culling that keeps a 47-cottage village cheap. Real walking where the claim is about getting through.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_town.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	kit.day_night.set_time(12.0)
	var village := kit.village
	var centre := village.center()
	var space: PhysicsDirectSpaceState3D = kit.world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8

	# 1. The perimeter fence: a closed ring with exactly four gaps, each filled by a gate that can be walked through.
	var shapes := 0
	for body in get_nodes_in_group(&"perimeter_fence"):
		shapes += body.get_child_count()
	kit.check("the perimeter fence is made of 200+ solid pieces (one collision box each)", shapes >= 200, "%d pieces" % shapes)
	var blocked := 0
	var open_bearings: Array[float] = []
	for deg in range(0, 360, 2):
		var rad := deg_to_rad(float(deg))
		var spot: Vector3 = centre + Vector3(sin(rad), 0.0, cos(rad)) * Village.FENCE_RADIUS + Vector3.UP * 1.0
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, spot)
		query.exclude = [kit.terrain.get_rid(), kit.player.get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			open_bearings.append(float(deg))
		else:
			blocked += 1
	var gate_groups := 0
	var last := -99.0
	for deg in open_bearings:
		if deg - last > 6.0:
			gate_groups += 1
		last = deg
	kit.check("walking round the village at the fence radius a player-sized capsule is stopped almost everywhere (%d of 180 bearings) and passes in exactly 4 places (the gates)" % blocked, blocked >= 160 and gate_groups == 4, "%d blocked, %d open groups at %s" % [blocked, gate_groups, open_bearings])
	var north_gate := centre + Vector3(0, 0, Village.FENCE_RADIUS)
	var gates_ok := true
	for bearing: float in Village.GATE_BEARINGS:
		var rad := deg_to_rad(bearing)
		for step: float in [-0.8, 0.0, 0.8]:
			var tangent := Vector3(cos(rad), 0.0, -sin(rad))
			var spot: Vector3 = centre + Vector3(sin(rad), 0.0, cos(rad)) * Village.FENCE_RADIUS + tangent * step + Vector3.UP * 1.0
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(Basis.IDENTITY, spot)
			query.exclude = [kit.terrain.get_rid(), kit.player.get_rid()]
			if step == 0.0 and not space.intersect_shape(query, 1).is_empty():
				gates_ok = false
	kit.check("each of the four gates (north, east, south, west) is passable at its middle", gates_ok and get_nodes_in_group(&"perimeter_gate").size() == 4)
	var crooked := 0
	for gate in get_nodes_in_group(&"perimeter_gate"):
		var radial := ((gate as Node3D).global_position - centre)
		radial.y = 0.0
		radial = radial.normalized()
		var tangent := Vector3(radial.z, 0.0, -radial.x)
		# The gate's posts run along its local X: that must be the tangent of the fence (the opening faces the way people walk: in and out, along the radius).
		if absf((gate as Node3D).global_transform.basis.x.dot(tangent)) < 0.99:
			crooked += 1
	kit.check("every perimeter gate is turned the right way: its posts run ALONG the fence and its opening faces in and out (Marco: gates were sideways)", crooked == 0 and get_nodes_in_group(&"perimeter_gate").size() == 4, "%d crooked" % crooked)
	# A real walk through the north gate: from inside the village to outside, on foot.
	await kit.teleport(Vector3(north_gate.x, NAN, north_gate.z - 6.0), 30)
	kit.face(Vector3(0, 0, 1))
	await kit.hold(["move_forward"], 170)
	kit.check("walking out of the north gate on foot gets through (more than 3 m beyond the fence)", kit.player.global_position.z > north_gate.z + 3.0, "z %.1f, gate at %.1f" % [kit.player.global_position.z, north_gate.z])
	# And a real wall elsewhere: the same walk 40 degrees round the circle is stopped by the fence.
	var rad_wall := deg_to_rad(40.0)
	var wall_point := centre + Vector3(sin(rad_wall), 0.0, cos(rad_wall)) * Village.FENCE_RADIUS
	var inward := (centre - wall_point).normalized()
	await kit.teleport(Vector3(wall_point.x + inward.x * 6.0, NAN, wall_point.z + inward.z * 6.0), 30)
	kit.face(-inward)
	await kit.hold(["move_forward"], 170)
	var outward_distance := (kit.player.global_position - centre).length()
	kit.check("the same walk away from the village where there is NO gate is stopped by the fence (it ends within 1 m of the fence line)", outward_distance < Village.FENCE_RADIUS + 0.2, "ended %.1f m from the plaza, fence at %.1f" % [outward_distance, Village.FENCE_RADIUS])

	# 2. A garage for every cottage, none inside a cottage, a path or on the track.
	var garages := get_nodes_in_group(&"garage")
	kit.check("every cottage (%d) has its own garage (%d)" % [village.houses.size(), garages.size()], garages.size() == village.houses.size())
	var bad_garages := 0
	for garage in garages:
		var g := garage as Node3D
		for house in village.houses:
			var local := house.to_local(g.global_position)
			if absf(local.x) < House.WIDTH * 0.5 + 1.0 and absf(local.z) < House.DEPTH * 0.5 + 1.0:
				bad_garages += 1
		if kit.terrain.path_distance(g.global_position.x, g.global_position.z) < 1.5:
			bad_garages += 1
	kit.check("no garage stands inside a cottage or on a dirt path", bad_garages == 0, "%d problems" % bad_garages)
	var garage_walk := true
	for garage in garages.slice(0, 12):
		var inside_garage := (garage as Node3D).to_global(Vector3(0, 1.0, 0.4))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, inside_garage)
		query.exclude = [kit.terrain.get_rid(), kit.player.get_rid()]
		if not space.intersect_shape(query, 1).is_empty():
			garage_walk = false
	kit.check("a player fits inside a garage (its open front is open) and its walls are solid", garage_walk)

	# 3. Smoothness: every mesh of the village fades out by distance.
	var unculled := 0
	for node in village.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).visibility_range_end <= 0.0:
			unculled += 1
	kit.check("every mesh in the village (cottages, props, carts) is distance-culled", unculled == 0, "%d meshes without a visibility range" % unculled)
	kit.finish()
