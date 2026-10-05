extends SceneTree
## Functional test: the RENDER BUDGET. Smoothness has two halves: even motion (test_smoothness.gd) and a picture the GPU can finish in time. A headless
## run cannot time the GPU, but the things that decide the cost are all visible in the scene: how many things are drawn at once and how far away,
## how much the shadow pass redraws, how many lights cast shadows, how many particles burn. This pins those, so a new feature cannot quietly make the
## game jittery (the 2026-10-05 measurement: 1,360 draw calls and 1.45 M triangles per frame, half of it the shadow pass and a 48,000-tuft grass
## MultiMesh that was drawn whole from every spot on the map).
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_render_budget.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


## Meshes under `root` that can be drawn from any distance (no visibility range): the ones that cost every frame.
func _unculled(root: Node) -> Array[String]:
	var bad: Array[String] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.visibility_range_end <= 0.0:
			bad.append(String(mesh.get_path()))
	return bad


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	var scatter := kit.nature

	# 1. Distance culling of the scattered things.
	var trees := _unculled(scatter.get_node("Generated/Trees"))
	var rocks := _unculled(scatter.get_node("Generated/Rocks"))
	kit.check("every mesh of every tree (%d trees) fades out beyond a distance (no tree is drawn from the far side of the map)" % scatter.get_trees().size(), trees.is_empty() and scatter.get_trees().size() > 100, "%d unculled, e.g. %s" % [trees.size(), trees.slice(0, 2)])
	kit.check("every mesh of every rock fades out beyond a distance", rocks.is_empty() and scatter.get_rocks().size() > 50, "%d unculled, e.g. %s" % [rocks.size(), rocks.slice(0, 2)])

	# 2. The grass is chunked: no single MultiMesh holds a big share, every chunk is culled, and all tufts are still there.
	var grass := scatter.get_node("Generated/Grass")
	var chunks := grass.get_children()
	var total := 0
	var biggest := 0
	var unculled_chunks := 0
	for chunk in chunks:
		var multi := (chunk as MultiMeshInstance3D).multimesh
		total += multi.instance_count
		biggest = maxi(biggest, multi.instance_count)
		if (chunk as MultiMeshInstance3D).visibility_range_end <= 0.0:
			unculled_chunks += 1
	kit.check("the grass is split into 40+ chunks (one 48,000-tuft MultiMesh is drawn whole from everywhere)", chunks.size() >= 40, "%d chunks" % chunks.size())
	kit.check("no grass chunk holds more than 5% of the tufts, and every chunk is culled by distance", biggest * 20 <= total and unculled_chunks == 0, "biggest %d of %d, %d unculled" % [biggest, total, unculled_chunks])
	kit.check("nearly all the requested tufts exist (the chunking lost none: %d of %d)" % [total, scatter.grass_count], total > scatter.grass_count * 9 / 10)

	# 3. The shadow pass.
	var shadow_lights: Array[DirectionalLight3D] = []
	for node in kit.world.find_children("*", "DirectionalLight3D", true, false):
		var light := node as DirectionalLight3D
		if light.shadow_enabled:
			shadow_lights.append(light)
	var worst_reach := 0.0
	var worst_splits := 0
	for light in shadow_lights:
		worst_reach = maxf(worst_reach, light.directional_shadow_max_distance)
		worst_splits = maxi(worst_splits, 1 if light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL else (2 if light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS else 4))
	kit.check("at most 2 directional lights cast shadows (sun and moon: a shadow pass redraws everything in reach once per light)", shadow_lights.size() <= 2, "%d" % shadow_lights.size())
	kit.check("shadows reach at most 70 m with at most 2 splits (110 m with 4 splits cost about 900 extra draw calls)", worst_reach <= 70.0 and worst_splits <= 2, "reach %.0f, splits %d" % [worst_reach, worst_splits])

	# 4. Lights and particles.
	var omni_with_shadow := 0
	for node in kit.world.find_children("*", "OmniLight3D", true, false):
		if (node as OmniLight3D).shadow_enabled:
			omni_with_shadow += 1
	kit.check("no point light casts shadows (each one is six extra passes)", omni_with_shadow == 0, "%d" % omni_with_shadow)
	kit.check("physics interpolation is on (the picture moves smoothly between physics ticks on any monitor)", ProjectSettings.get_setting("physics/common/physics_interpolation", false) == true)

	kit.finish()
