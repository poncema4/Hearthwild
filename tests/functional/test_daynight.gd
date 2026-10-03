extends SceneTree
## Functional test: the day/night cycle (clock, sun, moon, sky, lamps, signals, HUD clock).
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_daynight.gd
## Exit code = number of failures (0 = all pass).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := PlaytestKit.new(self)
	await kit.load_world()
	var dn := kit.day_night
	var sun := kit.world.get_node("Sun") as DirectionalLight3D
	var moon := dn.get_node("Moon") as DirectionalLight3D
	var environment := (kit.world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	var hud: InteractionPrompt = kit.player.get_node("HUD")

	# 1. The clock reads right.
	var expected := {0.0: "12:00 AM", 9.5: "9:30 AM", 12.0: "12:00 PM", 15.25: "3:15 PM", 23.99: "11:59 PM"}
	var wrong := []
	for h in expected:
		dn.set_time(h)
		if dn.clock_text() != expected[h]:
			wrong.append("%s -> '%s' (expected '%s')" % [h, dn.clock_text(), expected[h]])
	kit.check("the clock text is right (12-hour, AM/PM)", wrong.is_empty(), str(wrong))

	# 2. Noon is bright, midnight is dark, with sun and moon taking turns.
	dn.set_time(12.0)
	var noon_top := sky.sky_top_color.get_luminance()
	var noon_ambient := environment.ambient_light_energy
	kit.check("noon: the sun is strong and the moon is off", sun.light_energy > 1.0 and sun.visible and moon.light_energy == 0.0 and not dn.is_night(),
			"sun %.2f moon %.2f night=%s" % [sun.light_energy, moon.light_energy, dn.is_night()])
	dn.set_time(0.0)
	kit.check("midnight: the sun is off and the moon gives a dim light", sun.light_energy == 0.0 and not sun.visible and moon.light_energy > 0.2 and moon.light_energy < 0.4 and dn.is_night(),
			"sun %.2f moon %.2f night=%s" % [sun.light_energy, moon.light_energy, dn.is_night()])
	kit.check("midnight sky is at least 8 times darker than noon sky", sky.sky_top_color.get_luminance() * 8.0 < noon_top,
			"noon %.3f midnight %.3f" % [noon_top, sky.sky_top_color.get_luminance()])
	kit.check("ambient light is dimmer at midnight than at noon", environment.ambient_light_energy < noon_ambient,
			"noon %.2f midnight %.2f" % [noon_ambient, environment.ambient_light_energy])

	# 2b. WHEN night begins and ends (zombies will key off these moments). The real edges are at about
	# 5:45 PM and 6:15 AM, so the probe points sit tightly on each side: 5:30 PM is day, 6:00 PM
	# is night, 6:00 AM is night, 6:30 AM is day (wide probes let a badly shifted threshold pass).
	var edges := {}
	for h in [17.5, 18.0, 6.0, 6.5]:
		dn.set_time(h)
		edges[h] = dn.is_night()
	kit.check("night starts between 5:30 PM and 6:00 PM and ends between 6:00 AM and 6:30 AM", not edges[17.5] and edges[18.0] and edges[6.0] and not edges[6.5], str(edges))
	var start_elevation := sin((dn.start_hour - 6.0) / 24.0 * TAU)
	kit.check("a new game starts in daylight", start_elevation > 0.5, "start hour %.1f, sun elevation %.2f" % [dn.start_hour, start_elevation])

	# 2c. Night is dark BLUE, not black: a cool ambient floor keeps a character facing away from the moon
	# readable (their back was pure black at 11 PM).
	dn.set_time(0.0)
	var floor_share := environment.ambient_light_sky_contribution
	var floor_color := environment.ambient_light_color
	dn.set_time(12.0)
	kit.check("at midnight part of the ambient light is a fixed cool blue (sky share under 0.8, colour not dark), by day it is all sky",
			floor_share < 0.8 and floor_color.get_luminance() > 0.15 and floor_color.b > floor_color.r and environment.ambient_light_sky_contribution == 1.0,
			"midnight share %.2f colour %s, noon share %.2f" % [floor_share, floor_color, environment.ambient_light_sky_contribution])

	# 3. The sun crosses the sky: straight down at noon, level at 6 and 18, and moves east to west.
	var travel := {}
	for h in [6.0, 8.0, 12.0, 16.0, 18.0]:
		dn.set_time(h)
		travel[h] = -sun.global_transform.basis.z
	kit.check("noon: the light points almost straight down", travel[12.0].y < -0.85, "y component %.2f" % travel[12.0].y)
	kit.check("sunrise and sunset: the light is level with the horizon (|y| under 0.15)", absf(travel[6.0].y) < 0.15 and absf(travel[18.0].y) < 0.15,
			"6:00 y %.2f, 18:00 y %.2f" % [travel[6.0].y, travel[18.0].y])
	kit.check("the sun rises in the east (+X) and sets in the west: in the morning the light travels toward -X, in the afternoon toward +X", travel[8.0].x < -0.3 and travel[16.0].x > 0.3,
			"8:00 x %.2f, 16:00 x %.2f" % [travel[8.0].x, travel[16.0].x])
	dn.set_time(0.0)
	var moon_travel := -moon.global_transform.basis.z
	kit.check("at midnight the moonlight comes from above (points down) and casts soft shadows", moon_travel.y < -0.5 and moon.shadow_enabled and moon.shadow_opacity > 0.3 and moon.shadow_opacity < 0.8,
			"moon light y %.2f, shadows %s, opacity %.2f" % [moon_travel.y, moon.shadow_enabled, moon.shadow_opacity])

	# 4. Dusk is warm: orange horizon at sunset, neutral at noon.
	dn.set_time(18.0)
	var dusk := sky.sky_horizon_color
	dn.set_time(12.0)
	var day := sky.sky_horizon_color
	kit.check("dusk horizon is orange (red well above blue), noon horizon is not", dusk.r - dusk.b > 0.15 and day.r - day.b < 0.1,
			"dusk r-b %.2f, noon r-b %.2f" % [dusk.r - dusk.b, day.r - day.b])

	# 5. Smooth: stepping through the whole day (and across midnight), nothing jumps.
	var worst_sun := 0.0
	var worst_sky := 0.0
	var worst_night := 0.0
	dn.set_time(0.0)
	var previous_sun := sun.light_energy
	var previous_sky := sky.sky_top_color.get_luminance()
	var previous_night := dn.night_amount()
	for step in range(1, 241):  # 0.1 hour steps over 24 hours
		dn.set_time(step * 0.1)
		worst_sun = maxf(worst_sun, absf(sun.light_energy - previous_sun))
		worst_sky = maxf(worst_sky, absf(sky.sky_top_color.get_luminance() - previous_sky))
		worst_night = maxf(worst_night, absf(dn.night_amount() - previous_night))
		previous_sun = sun.light_energy
		previous_sky = sky.sky_top_color.get_luminance()
		previous_night = dn.night_amount()
	kit.check("lighting is smooth over the day (per 6 game minutes: sun under 0.25, sky under 0.05, night amount under 0.2)",
			worst_sun < 0.25 and worst_sky < 0.05 and worst_night < 0.2, "worst sun %.3f sky %.3f night %.3f" % [worst_sun, worst_sky, worst_night])

	# 6. The clock runs on the physics tick: 6 s of the default day (DayNight.DEFAULT_DAY_LENGTH, 20 minutes) = 0.12 hours, and it wraps at midnight.
	dn.set_time(10.0)
	dn.paused = false
	await kit.physics_frames(360)
	kit.check("a running clock advances 0.12 game hours in 6 real seconds (a 20-minute day)", dn.day_length_seconds == DayNight.DEFAULT_DAY_LENGTH and DayNight.DEFAULT_DAY_LENGTH == 1200.0 and absf(dn.hour - 10.12) < 0.005, "hour %.3f, day %.0f s" % [dn.hour, dn.day_length_seconds])
	dn.set_time(23.95)
	await kit.physics_frames(240)
	kit.check("the clock wraps past midnight", dn.hour < 0.1 and dn.hour > 0.0, "hour %.3f" % dn.hour)
	dn.paused = true
	var frozen := dn.hour
	await kit.physics_frames(120)
	kit.check("a paused clock does not move", dn.hour == frozen, "%.3f vs %.3f" % [dn.hour, frozen])

	# 7. Signals: night_started when dusk passes, day_started at dawn, each exactly once.
	dn.set_time(12.0)  # settle into daytime BEFORE counting (this itself may fire day_started)
	var counts := {"night": 0, "day": 0}
	dn.night_started.connect(func(): counts["night"] += 1)
	dn.day_started.connect(func(): counts["day"] += 1)
	dn.day_length_seconds = 24.0  # one game hour per real second
	dn.set_time(17.0)
	dn.paused = false
	await kit.physics_frames(150)
	dn.paused = true
	kit.check("night_started fires exactly once as the evening passes", counts["night"] == 1 and counts["day"] == 0, "night %d day %d at hour %.2f" % [counts["night"], counts["day"], dn.hour])
	dn.set_time(5.0)
	dn.paused = false
	await kit.physics_frames(150)
	dn.paused = true
	kit.check("day_started fires exactly once as the morning comes", counts["day"] == 1 and counts["night"] == 1, "night %d day %d at hour %.2f" % [counts["night"], counts["day"], dn.hour])
	dn.day_length_seconds = DayNight.DEFAULT_DAY_LENGTH

	# 8. The village lamps light up at night and are dark by day.
	var lamps: Array[Node] = kit.tree.get_nodes_in_group(&"night_light")
	dn.set_time(0.0)
	var lit := 0
	for lamp in lamps:
		if (lamp as Light3D).light_energy > 2.0 and (lamp as Light3D).visible:
			lit += 1
	var village_lamps := kit.village.props.filter(func(p): return p.get_meta("kind") == "LampPost").size()  # not a literal: the village grew from 4 to 9 (lesson 53)
	kit.check("all %d village lamps are lit at midnight" % village_lamps, village_lamps >= 9 and lamps.size() == village_lamps and lit == village_lamps, "%d lamps in the group, %d placed by the village, %d lit" % [lamps.size(), village_lamps, lit])
	dn.set_time(12.0)
	var dark := 0
	for lamp in lamps:
		if (lamp as Light3D).light_energy == 0.0 and not (lamp as Light3D).visible:
			dark += 1
	kit.check("all village lamps are off at noon", dark == lamps.size(), "%d of %d off" % [dark, lamps.size()])

	# 8d. The lake follows the clock: bright by day, dark at night, tinted by the horizon.
	var lake: MeshInstance3D = kit.terrain.get_node("PondWater")
	var lake_material := lake.material_override as ShaderMaterial
	dn.set_time(12.0)
	var day_level: float = lake_material.get_shader_parameter("daylight")
	var day_tint: Color = lake_material.get_shader_parameter("sky_tint")
	dn.set_time(0.0)
	var night_level: float = lake_material.get_shader_parameter("daylight")
	var night_tint: Color = lake_material.get_shader_parameter("sky_tint")
	dn.set_time(18.5)
	var dusk_tint: Color = lake_material.get_shader_parameter("sky_tint")
	dn.set_time(10.0)
	kit.check("the lake is bright at noon and dark at midnight (daylight %.2f -> %.2f)" % [day_level, night_level], day_level > 0.95 and night_level < 0.05, "%.3f / %.3f" % [day_level, night_level])
	kit.check("the lake's reflection tint changes with the sky (noon, dusk and midnight all different)", _colour_gap(day_tint, night_tint) > 0.2 and _colour_gap(day_tint, dusk_tint) > 0.1 and _colour_gap(night_tint, dusk_tint) > 0.1,
			"%s %s %s" % [day_tint, dusk_tint, night_tint])

	# 8b. The clock post in the plaza shows the game time with its hands.
	var clock: WorldClock = null
	for prop in kit.village.props:
		if prop is WorldClock:
			clock = prop
	var hands_ok := clock != null
	var hands_detail := ""
	for entry in [[3.0, 90.0, 0.0], [15.5, 105.0, 180.0], [12.0, 0.0, 0.0], [9.25, 277.5, 90.0]]:
		dn.set_time(entry[0])
		await kit.physics_frames(2)
		var angles := clock.hand_angles_degrees() if clock else Vector2(-1, -1)
		var ok := absf(angle_difference(deg_to_rad(angles.x), deg_to_rad(entry[1]))) < deg_to_rad(1.0) and absf(angle_difference(deg_to_rad(angles.y), deg_to_rad(entry[2]))) < deg_to_rad(1.0)
		hands_ok = hands_ok and ok
		hands_detail += " [%.2f h: hour %.0f (want %.0f), minute %.0f (want %.0f)]" % [entry[0], angles.x, entry[1], angles.y, entry[2]]
	kit.check("the plaza clock's hands show the game time (3:00, 3:30 PM, 12:00, 9:15)", hands_ok, hands_detail)

	# 8c. A world that starts (or loads) at night while the clock is paused still has its lamps lit.
	var night_world: Node = load("res://scenes/world/world.tscn").instantiate()
	(night_world.get_node("DayNight") as DayNight).start_hour = 0.0
	(night_world.get_node("DayNight") as DayNight).paused = true
	kit.world.add_child(night_world)
	await kit.physics_frames(3)
	var night_lamps := night_world.find_children("NightLight", "OmniLight3D", true, false)
	var night_lit := 0
	for lamp in night_lamps:
		if (lamp as Light3D).light_energy > 2.0:
			night_lit += 1
	kit.check("a world that starts at midnight paused has all %d lamps lit" % village_lamps, night_lamps.size() == village_lamps and night_lit == village_lamps, "%d lamps, %d lit" % [night_lamps.size(), night_lit])
	night_world.queue_free()
	await kit.physics_frames(2)

	# 9. The HUD clock shows the time.
	dn.set_time(15.25)
	await kit.frames(3)
	kit.check("the HUD clock reads the game time", hud.clock_text() == "3:15 PM", "HUD says '%s'" % hud.clock_text())
	dn.set_time(10.0)
	kit.finish()


func _colour_gap(a: Color, b: Color) -> float:
	return Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b))
