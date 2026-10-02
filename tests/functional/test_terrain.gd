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
	for spot in [["hill", Vector2(-45, 10)], ["hill ring", Vector2(0, 44)],
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

	kit.finish()


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
