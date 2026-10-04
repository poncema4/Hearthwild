extends SceneTree
## Functional test: the terrain's collision matches its visible mesh, things
## placed on the ground sit on it, and sand stays at the pond.
##
## Why this exists: the spawn is flat (height 0), so movement tests can't tell
## a correctly aligned heightmap from a transposed or offset one. These checks
## use points on hills, the hill ring and the pond bed.
##
## Run: godot --headless --path . --script res://tests/functional/test_terrain.gd
## Exit code = number of failures (0 = all pass).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var terrain := kit.terrain
	var space: PhysicsDirectSpaceState3D = (kit.world as Node3D).get_world_3d().direct_space_state

	# 1. Ray straight down at many points: the collision surface must be at
	#    the height the mesh was built from (height_at). Skips points where a
	#    tree or rock is in the way.
	var checked := 0
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for x in range(-50, 51, 10):
		for z in range(-50, 51, 10):
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -40, z))
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty() or hit["collider"] != terrain:
				continue
			var error := absf(hit["position"].y - terrain.height_at(x, z))
			checked += 1
			if error > worst:
				worst = error
				worst_at = Vector2(x, z)
	kit.check("collision surface matches height_at on a 11x11 grid", checked > 60 and worst < 0.05,
		"%d points, worst error %.3f m at %s" % [checked, worst, worst_at])

	# 2. End to end: drop the player on non-flat ground (hill, hill ring, pond
	#    bed, slope); it must come to rest on the visible ground. Two-sided
	#    bounds: a 0.15 m tolerance covers the capsule resting on a slope.
	for spot in [["hill", Vector2(-45, 10)], ["hill ring", Vector2(0, terrain.half_size() * 0.85)],  # derived: on the real rim (it was a literal from the 120 m world and ended up under a cottage roof)
			["pond bed", terrain.pond_center], ["slope", Vector2(30, -20)]]:
		var p: Vector2 = spot[1]
		await kit.teleport(Vector3(p.x, terrain.height_at(p.x, p.y) + 3.0, p.y), 90)
		var ground := terrain.height_at(p.x, p.y)
		# A capsule resting on a slope sits higher than the ground height under
		# its centre: radius * (sqrt(1 + gradient^2) - 1) (0.4 m radius).
		var gx := terrain.height_at(p.x + 0.5, p.y) - terrain.height_at(p.x - 0.5, p.y)
		var gz := terrain.height_at(p.x, p.y + 0.5) - terrain.height_at(p.x, p.y - 0.5)
		var expected := 0.4 * (sqrt(1.0 + gx * gx + gz * gz) - 1.0)
		var y := kit.player.global_position.y
		kit.check("player rests on the ground: " + spot[0], kit.player.is_on_floor() and absf(y - ground - expected) < 0.06,
			"y=%.2f ground=%.2f slope offset=%.2f" % [y, ground, expected])

	# 3. Trees and rocks sit on the ground they were placed on.
	var sunk := 0
	for tree in kit.nature.get_trees():
		var ground := terrain.height_at(tree.position.x, tree.position.z)
		if absf(tree.position.y - ground) > 0.01:
			sunk += 1
	kit.check("every tree sits on the ground", sunk == 0, "%d of %d off the ground" % [sunk, kit.nature.get_trees().size()])
	var overlapping := 0
	for rock in kit.nature.get_rocks():
		for tree in kit.nature.get_trees():
			if rock.position.distance_to(tree.position) < 1.5:
				overlapping += 1
	kit.check("no rock inside a tree", overlapping == 0, "%d overlaps" % overlapping)

	# 4. Nothing in the spawn clearing or the pond.
	var in_clearing := 0
	var in_pond := 0
	for node in kit.nature.get_trees() + kit.nature.get_rocks():
		if Vector2(node.position.x, node.position.z).length() < 6.0:
			in_clearing += 1
		if Vector2(node.position.x, node.position.z).distance_to(terrain.pond_center) < terrain.pond_radius:
			in_pond += 1
	kit.check("spawn clearing has no trees or rocks", in_clearing == 0, "%d inside 6 m" % in_clearing)
	kit.check("pond has no trees or rocks", in_pond == 0, "%d inside the pond" % in_pond)

	# 5. Sand and mud only near the pond (the grey-patch bug, lesson 12).
	var stray := 0
	var sandy := 0
	var far := terrain.pond_radius + 2.6
	for x in range(-58, 59, 2):
		for z in range(-58, 59, 2):
			var c := terrain.ground_color_at(x, z)
			var is_sandy := _distance(c, Terrain.SAND) < _distance(c, Terrain.GRASS_LOW) \
					and _distance(c, Terrain.SAND) < _distance(c, Terrain.GRASS_HIGH)
			if is_sandy:
				# Village cobble and path dirt are pale and warm too; they are not pond sand.
				if terrain.in_village(x, z, 0.0) or terrain.path_distance(x, z) < 2.0:
					continue
				if Vector2(x, z).distance_to(terrain.pond_center) > far:
					stray += 1
				else:
					sandy += 1
	kit.check("no sand away from the pond", stray == 0, "%d sandy points beyond %.1f m" % [stray, far])
	kit.check("there IS sand at the pond", sandy > 3, "%d sandy points near it" % sandy)

	# 6. Same seed, same world.
	var again := Terrain.new()
	again.world_seed = terrain.world_seed
	kit.check("height_at is deterministic", is_equal_approx(again.height_at(12.3, -7.7), terrain.height_at(12.3, -7.7)),
		"%.4f vs %.4f" % [again.height_at(12.3, -7.7), terrain.height_at(12.3, -7.7)])
	again.free()

	# 7. A world big enough for many players (Marco: multiplayer, other players join): 240 m square, walls
	# exactly at its edge, and real nature all the way out (not just in the old 120 m).
	var half := terrain.half_size()
	kit.check("the world is at least 240 m square (room for many players)", terrain.size >= 240, "size %d" % terrain.size)
	var wall_space: PhysicsDirectSpaceState3D = kit.world.get_world_3d().direct_space_state
	var walls_ok := true
	var wall_detail := ""
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var from: Vector3 = direction * (half - 6.0) + Vector3(0, 10, 0)
		var to: Vector3 = direction * (half + 6.0) + Vector3(0, 10, 0)
		var hit := wall_space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		var inner: float = (hit["position"] as Vector3).dot(direction) if not hit.is_empty() else -1.0
		if hit.is_empty() or not (hit["collider"] as Node).is_in_group(&"boundary") or absf(inner - (half - 2.0)) > 0.3:
			walls_ok = false
			wall_detail += " %s: %s;" % [direction, "no hit" if hit.is_empty() else "wall face at %.1f (want %.1f)" % [inner, half - 2.0]]
	kit.check("a wall stands at each edge of the terrain (its face 2 m inside it, so nobody walks off)", walls_ok, wall_detail)
	var outer_trees := 0
	var out_of_bounds := 0
	for tree in kit.nature.get_trees():
		var p: Vector3 = (tree as Node3D).global_position
		if maxf(absf(p.x), absf(p.z)) > 70.0:
			outer_trees += 1
		if maxf(absf(p.x), absf(p.z)) > half - 2.0:
			out_of_bounds += 1
	kit.check("trees reach beyond the old 120 m world (at least 80 trees past 70 m from the centre)", outer_trees >= 80, "%d trees" % outer_trees)
	kit.check("no tree stands outside or in the walls", out_of_bounds == 0, "%d trees" % out_of_bounds)
	kit.check("the village is where it always was", terrain.village_center == Vector2(-20, 14), str(terrain.village_center))

	# 8. The lake: clear of the village, inside the hill rim, an organic shoreline, open banks, real water shader.
	var lake_gap := terrain.pond_center.distance_to(terrain.village_center) - terrain.pond_radius - (terrain.village_flat_radius + terrain.village_blend)
	kit.check("the lake's bowl stays at least 10 m clear of the village's flat zone", lake_gap >= 10.0, "%.1f m" % lake_gap)
	var lake_far_edge := terrain.pond_center.length() + terrain.pond_radius
	kit.check("the lake sits inside the hill rim (far edge %.1f m, rim starts %.1f m)" % [lake_far_edge, terrain.rim_start * half], lake_far_edge <= terrain.rim_start * half, "%.1f vs %.1f" % [lake_far_edge, terrain.rim_start * half])
	var shore_min := 99.0
	var shore_max := 0.0
	for i in 64:
		var line := terrain.waterline_at(TAU * i / 64.0)
		shore_min = minf(shore_min, line)
		shore_max = maxf(shore_max, line)
	kit.check("the shoreline is a real lake: 9 m from the centre at the least, inside the water disc (radius %.1f) on all 64 bearings, and not a perfect circle (spread over 1 m)" % terrain.pond_radius,
			shore_min >= 9.0 and shore_max <= terrain.pond_radius and shore_max - shore_min > 1.0, "min %.2f max %.2f" % [shore_min, shore_max])
	var bank_things := 0
	for thing in kit.nature.get_trees() + kit.nature.get_rocks():
		if Vector2(thing.global_position.x, thing.global_position.z).distance_to(terrain.pond_center) < terrain.pond_radius + NatureScatter.SHORE_CLEAR - 0.01:
			bank_things += 1
	kit.check("no tree or rock stands on the banks (within %.0f m of the lake's radius)" % NatureScatter.SHORE_CLEAR, bank_things == 0, "%d things" % bank_things)
	var water: MeshInstance3D = terrain.get_node("PondWater")
	var material := water.material_override as ShaderMaterial
	var depth_map: ImageTexture = material.get_shader_parameter("depth_map") if material else null
	var map_image := depth_map.get_image() if depth_map else null
	var centre_depth := map_image.get_pixel(map_image.get_width() / 2, map_image.get_height() / 2).r if map_image else -1.0
	var corner_depth := map_image.get_pixel(1, 1).r if map_image else -1.0
	kit.check("the water is the water shader with a baked depth map: deep (over 0.6) in the middle, zero at the corner",
			material != null and material.shader.resource_path.ends_with("water.gdshader") and centre_depth > 0.6 and corner_depth == 0.0 and water.is_in_group(&"water"),
			"material %s, centre %.2f, corner %.2f" % [material, centre_depth, corner_depth])
	# The map must line up with the ground (not flipped, mirrored or transposed): at asymmetric points the shader's
	# own uv formula must find the depth the terrain really has there (a centre and a corner pixel cannot tell).
	var extent: float = material.get_shader_parameter("map_half_extent") if material else 1.0
	var deepest := terrain.pond_depth + 1.0
	var misaligned := []
	var distinct_values := 0
	for offset: Vector2 in [Vector2(10, 3), Vector2(-9, 6), Vector2(4, -12), Vector2(7, 9), Vector2(-5, -8)]:
		var uv: Vector2 = offset / (2.0 * extent) + Vector2(0.5, 0.5)
		var pixel := map_image.get_pixel(int(uv.x * map_image.get_width()), int(uv.y * map_image.get_height())).r if map_image else -1.0
		var expected := terrain.water_depth_at(terrain.pond_center.x + offset.x, terrain.pond_center.y + offset.y) / deepest
		if expected > 0.1:
			distinct_values += 1
		if absf(pixel - expected) > 0.05:
			misaligned.append("%s: map %.2f, ground %.2f" % [offset, pixel, expected])
	kit.check("the depth map lines up with the real ground at five asymmetric points (not flipped or mirrored)", misaligned.is_empty() and distinct_values >= 3, "%s (%d points with real depth)" % [str(misaligned), distinct_values])

	kit.finish()


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
