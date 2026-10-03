extends SceneTree
## Functional test: the lake's decoration and fishing coverage (reeds on the banks, lily pads on the water,
## spots spread right round it). The lake's geometry and shader are checked in test_terrain.gd, the cast/bite
## cycle in test_fishing.gd.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_lake.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	var terrain: Terrain = kit.terrain
	var decor: LakeDecor = kit.world.get_node("LakeDecor")
	var spots := kit.fishing.spots

	# 1. Enough of it, in two draw calls.
	kit.check("there are at least 300 reed stalks and 30 lily pads", decor.reed_stalk_count() >= 300 and decor.pad_count() >= 30, "%d stalks, %d pads" % [decor.reed_stalk_count(), decor.pad_count()])
	kit.check("the decoration is two MultiMeshes (reeds, pads): two draw calls", decor.get_child_count() == 2 and decor.get_node("Reeds") is MultiMeshInstance3D and decor.get_node("LilyPads") is MultiMeshInstance3D, "%d children" % decor.get_child_count())

	# 2. Reeds stand on the bank (the shore band), at the water's edge, never on a spot's standing area.
	var off_band := 0
	var too_wet_or_high := 0
	var on_spot := 0
	var worst_band := 0.0
	for reed in decor.reed_positions():
		var from_centre := Vector2(reed.x, reed.z) - terrain.pond_center
		var band := from_centre.length() - terrain.waterline_at(from_centre.angle())
		worst_band = maxf(worst_band, absf(band))
		if band < -0.9 or band > 2.7:
			off_band += 1
		if reed.y < terrain.water_level - 0.3 or reed.y > terrain.water_level + 1.0:
			too_wet_or_high += 1
		for spot in spots:
			var stand := spot.standing_spot()
			if Vector2(stand.x, stand.z).distance_to(Vector2(reed.x, reed.z)) < 2.0:  # a literal on purpose: the decoration's own constant is 2.4 and a mutation of it must not move this limit

				on_spot += 1
	kit.check("every reed stands in the shore band (from 0.9 m inside the waterline to 2.7 m beyond it)", off_band == 0, "%d of %d outside it (worst %.2f m)" % [off_band, decor.reed_stalk_count(), worst_band])
	kit.check("no reed stalk is submerged or floating", too_wet_or_high == 0, "%d" % too_wet_or_high)
	kit.check("no reed stands where a player stands to fish (2 m clear of every spot)", on_spot == 0, "%d stalks" % on_spot)

	# 3. Pads float on water, away from every casting line.
	var dry_pads := 0
	var wrong_height := 0
	var on_line := 0
	for pad in decor.pad_positions():
		if terrain.water_depth_at(pad.x, pad.z) < 0.35:
			dry_pads += 1
		if absf(pad.y - (terrain.water_level + 0.02)) > 0.005:
			wrong_height += 1
		for spot in spots:
			var stand := spot.standing_spot()
			var bobber := spot.bobber_target()
			var closest := Geometry2D.get_closest_point_to_segment(Vector2(pad.x, pad.z), Vector2(stand.x, stand.z), Vector2(bobber.x, bobber.z))
			if Vector2(pad.x, pad.z).distance_to(closest) < 1.15:  # literal, see above (the constant is 1.2)
				on_line += 1
	kit.check("every lily pad floats on water at least 0.35 m deep", dry_pads == 0, "%d on dry or shallow ground" % dry_pads)
	kit.check("every pad sits just above the surface (2 cm)", wrong_height == 0, "%d" % wrong_height)
	kit.check("no pad lies across a casting line (1.2 m clear)", on_line == 0, "%d pads" % on_line)

	# 4. The same seed gives the same lake; another seed a different one.
	var twin := LakeDecor.new()
	twin.name = "LakeDecorTwin"
	twin.decor_seed = decor.decor_seed
	kit.world.add_child(twin)
	var other := LakeDecor.new()
	other.name = "LakeDecorOther"
	other.decor_seed = decor.decor_seed + 1
	kit.world.add_child(other)
	var same := twin.reed_positions() == decor.reed_positions() and twin.pad_positions() == decor.pad_positions()
	var different := other.reed_positions() != decor.reed_positions()
	twin.free()
	other.free()
	kit.check("the same seed gives exactly the same reeds and pads, another seed gives different ones", same and different, "same=%s different=%s" % [same, different])

	# 5. Anglers all round the lake: no empty stretch of shore wider than 150 degrees.
	var bearings: Array[float] = []
	for spot in spots:
		var stand := spot.standing_spot()
		bearings.append(rad_to_deg((Vector2(stand.x, stand.z) - terrain.pond_center).angle()))
	bearings.sort()
	var widest := 0.0
	for i in bearings.size():
		var next := bearings[(i + 1) % bearings.size()] + (360.0 if i == bearings.size() - 1 else 0.0)
		widest = maxf(widest, next - bearings[i])
	kit.check("fishing spots are spread round the lake (widest gap %.0f degrees, limit 150)" % widest, widest <= 150.0, "bearings %s" % str(bearings))
	kit.finish()
