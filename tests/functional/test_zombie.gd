extends SceneTree
## Functional test: the basic zombie (step 12) and its spawner, in the REAL world.
## Chase and melee, a sleeping player left alone (with a positive control), sunlight burn, shade (a real roof), characters
## and invisible walls casting no shade, the dawn/dusk edges, the spawner's rules (night only, cap, distance, village,
## water, edges), and the player being knocked out and respawned.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_zombie.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var _hits := 0
var _hit_frames: Array[int] = []
var _died := 0  # members, not locals: a lambda copies a captured int, so counting inside one needs a member (lesson 61)


func _initialize() -> void:
	_run.call_deferred()


func _zombie(x: float, z: float) -> Zombie:
	var z_node := Zombie.new()
	z_node.wander = false  # the older checks assume a zombie with no target stands still; the AI checks switch wandering on themselves
	z_node.position = Vector3(x, kit.terrain.height_at(x, z) + 0.2, z)
	kit.world.add_child(z_node)
	return z_node


func _clear_zombies() -> void:
	for node in get_nodes_in_group(&"zombie"):
		node.free()


func _player_to(x: float, z: float) -> void:
	await kit.teleport(Vector3(x, NAN, z), 20)


## Independent of the spawner's own check: does a player-sized capsule standing at `p` touch any tree, rock or building?
func _touches_scenery(p: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.95)
	return not kit.world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _flat_distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	var player := kit.player
	var health := player.get_node("Health") as Health
	var clock := kit.day_night
	var spawner := kit.zombie_spawner
	var sleep := kit.sleep_system
	var far := Vector2(80.0, 80.0)  # a spot more than 28 m from the spawn clearing, for zombies that must not chase

	# 1. Basics.
	kit.check("the player is in group `player` (exactly one)", get_nodes_in_group(&"player").size() == 1 and get_nodes_in_group(&"player")[0] == player)
	kit.check("the test kit turned the spawner off, so no other test gets visitors", not spawner.enabled)
	clock.set_time(23.0)
	await _player_to(0.0, 0.0)
	var z := _zombie(12.0, 0.0)
	await kit.physics_frames(30)
	var zh := z.get_node_or_null("Health") as Health
	var model := z.get_node_or_null("Model")
	var parts_ok := model != null and model.get_node_or_null("Torso") != null and model.get_node_or_null("Head") != null and model.get_node_or_null("Head/EyeL") != null \
			and model.get_node_or_null("ArmL") != null and model.get_node_or_null("ArmR") != null and model.get_node_or_null("LegL") != null and model.get_node_or_null("LegR") != null
	var capsule := (z.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	kit.check("a zombie has 20 hp, a player-sized capsule, and a model of torso, head, eyes, two arms and two legs",
			zh != null and zh.max_health == 20.0 and capsule != null and is_equal_approx(capsule.height, 1.8) and parts_ok and z.is_in_group(&"zombie"),
			"health %s, capsule %s, parts %s" % [zh.max_health if zh else "none", capsule.height if capsule else "none", parts_ok])
	kit.check("it stands on the ground (y within 0.15 m of the terrain)", absf(z.global_position.y - kit.terrain.height_at(z.global_position.x, z.global_position.z)) < 0.15,
			"y %.2f vs ground %.2f" % [z.global_position.y, kit.terrain.height_at(z.global_position.x, z.global_position.z)])
	z.walk_speed = 0.0
	z._walk_phase = 1.0
	kit.check("a stationary zombie (walk_speed 0) still has finite leg swings (0/0 gave NaN and an engine ERROR flood)", is_finite(z.leg_swing(0.0)) and is_finite(z.leg_swing(3.0)) and z.leg_swing(0.0) == 0.0,
			"swing(0) %s, swing(3) %s" % [z.leg_swing(0.0), z.leg_swing(3.0)])
	# Pose geometry (what an image alone cannot show): both arms reach FORWARD (the way the eyes face), level; legs hang down.
	var facing := -z.global_transform.basis.z
	var pose_problems := []
	# Measure the MESHES that are drawn (their centres), not an imaginary point on the pivot: a flipped mesh offset must fail too.
	for arm_name in ["ArmL", "ArmR"]:
		var arm := z.get_node("Model/" + arm_name) as Node3D
		var arm_mesh := arm.get_node("Mesh") as Node3D
		var reach: Vector3 = arm_mesh.global_position - arm.global_position  # shoulder to the middle of the arm
		if reach.dot(facing) < 0.2 or absf(reach.y) > 0.1 or reach.length() < 0.25:
			pose_problems.append("%s middle is %s from the shoulder (dot facing %.2f)" % [arm_name, reach, reach.dot(facing)])
	for leg_name in ["LegL", "LegR"]:
		var leg := z.get_node("Model/" + leg_name) as Node3D
		var leg_mesh := leg.get_node("Mesh") as Node3D
		var drop: Vector3 = leg_mesh.global_position - leg.global_position  # hip to the middle of the leg
		if drop.y > -0.25 or absf(drop.x) > 0.1 or absf(drop.z) > 0.1:
			pose_problems.append("%s middle is %s from the hip" % [leg_name, drop])
	var eye_side := (z.get_node("Model/Head/EyeL") as Node3D).global_position - (z.get_node("Model/Head") as Node3D).global_position
	if eye_side.dot(facing) < 0.1:
		pose_problems.append("eyes are not on the facing side")
	kit.check("pose (the drawn meshes): both arms extend FORWARD from the shoulders (middle 0.2+ m along the facing direction, level), both legs hang straight down from the hips, the eyes are on the front", pose_problems.is_empty(), str(pose_problems))
	var calm_fire := z.get_node("Model/Flames") as CPUParticles3D
	kit.check("a calm zombie is not on fire: flames, smoke and the fire light are off", not calm_fire.emitting and not (z.get_node("Model/Smoke") as CPUParticles3D).emitting and not (z.get_node("Model/FireLight") as OmniLight3D).visible)
	var calm := (z.get_node("Model/Torso") as MeshInstance3D).material_override as StandardMaterial3D
	kit.check("a calm zombie at night has a faint self-lit lift in its own colour (so it reads in the dark): emission on, equal to its albedo, energy 0.5 to 0.9",
			calm.emission_enabled and calm.emission == calm.albedo_color and calm.emission_energy_multiplier >= 0.5 and calm.emission_energy_multiplier <= 0.9, "emission %s x%.2f" % [calm.emission, calm.emission_energy_multiplier])
	_clear_zombies()

	# 2. Chase: at night it walks toward the player at about 2.4 m/s, facing them.
	await _player_to(0.0, 0.0)
	z = _zombie(12.0, 0.0)
	await kit.physics_frames(5)
	var d0 := _flat_distance(z, player)
	await kit.physics_frames(120)
	var closed := d0 - _flat_distance(z, player)
	var forward := -z.global_transform.basis.z
	var to_player := (player.global_position - z.global_position)
	to_player.y = 0.0
	kit.check("in 2 s a zombie 12 m away closes 3.8 to 5.0 m (walk speed 2.4 m/s with a short start-up)", closed > 3.8 and closed < 5.0, "closed %.2f m" % closed)
	kit.check("and it faces the player (forward dot direction > 0.95)", forward.dot(to_player.normalized()) > 0.95, "dot %.3f" % forward.dot(to_player.normalized()))
	var zombie_speed := Vector2(z.velocity.x, z.velocity.z).length()
	kit.check("its speed is slower than the player's walk (2.4 vs 4 m/s), so a walking player can outrun it", zombie_speed > 2.0 and zombie_speed < 2.6 and zombie_speed < player.walk_speed, "speed %.2f, player walk %.1f" % [zombie_speed, player.walk_speed])
	_clear_zombies()

	# 3. Out of range: it stays put.
	await _player_to(0.0, 0.0)
	z = _zombie(40.0, 0.0)
	await kit.physics_frames(5)
	var start := z.global_position
	await kit.physics_frames(120)
	kit.check("a player 40 m away (range 28 m) is not noticed: moved under 0.3 m in 2 s", z.global_position.distance_to(start) < 0.3, "moved %.2f m" % z.global_position.distance_to(start))
	_clear_zombies()
	z = _zombie(33.0, 0.0)
	await kit.physics_frames(5)
	start = z.global_position
	await kit.physics_frames(90)
	kit.check("33 m is also outside the 28 m range: moved under 0.3 m in 1.5 s (pins the range from above)", z.global_position.distance_to(start) < 0.3, "moved %.2f m" % z.global_position.distance_to(start))
	_clear_zombies()
	z = _zombie(24.0, 0.0)
	await kit.physics_frames(5)
	start = z.global_position
	await kit.physics_frames(90)
	kit.check("24 m is inside the range: it comes (over 2.5 m closer in 1.5 s; pins the range from below)", start.distance_to(z.global_position) > 2.5, "moved %.2f m" % start.distance_to(z.global_position))
	_clear_zombies()

	# 4. Melee: first hit at contact, then every 1.2 s, 8 damage each.
	health.heal(100.0)
	await _player_to(0.0, 0.0)
	z = _zombie(1.2, 0.0)
	_hits = 0
	_hit_frames.clear()
	z.hit_player.connect(func(_who, _amount):
		_hits += 1
		_hit_frames.append(Engine.get_physics_frames()))
	await kit.physics_frames(240)
	var gaps_ok := _hit_frames.size() >= 3
	for i in range(1, _hit_frames.size()):
		gaps_ok = gaps_ok and _hit_frames[i] - _hit_frames[i - 1] >= 70 and _hit_frames[i] - _hit_frames[i - 1] <= 75
	kit.check("4 s next to the player: 3 or 4 hits, each 8 damage, the player's hp matches, and the hits are 1.2 s apart (70 to 75 frames; pins the interval)",
			z.hits_landed >= 3 and z.hits_landed <= 4 and _hits == z.hits_landed and health.current == 100.0 - 8.0 * z.hits_landed and gaps_ok,
			"hits %d (signal %d), hp %.0f, at frames %s" % [z.hits_landed, _hits, health.current, _hit_frames])
	var gap := _flat_distance(z, player)
	kit.check("it stops at arm's length instead of walking into the player (0.9 to 1.6 m)", gap > 0.9 and gap < 1.6, "gap %.2f m" % gap)
	_clear_zombies()
	health.heal(100.0)

	# 4a. The reach, pinned from both sides: a zombie that cannot walk closer (walk_speed 0) hits at 1.3 m and not at 2.0 m (reach 1.5 m).
	health.heal(100.0)
	await _player_to(0.0, 0.0)
	var near_zombie := _zombie(1.3, 0.0)
	near_zombie.walk_speed = 0.0
	var far_zombie := _zombie(-2.0, 0.0)
	far_zombie.walk_speed = 0.0
	await kit.physics_frames(150)
	kit.check("melee reach is 1.5 m: a still zombie 1.3 m away hits (1 to 3 times in 2.5 s), one 2.0 m away never does, both with a clear line (pins the reach from both sides)",
			near_zombie.hits_landed >= 1 and near_zombie.hits_landed <= 3 and far_zombie.hits_landed == 0 and near_zombie.has_line_of_sight(player) and far_zombie.has_line_of_sight(player)
			and _flat_distance(near_zombie, player) < 1.5 and _flat_distance(far_zombie, player) > 1.9,
			"1.3 m zombie hits %d, 2.0 m zombie hits %d, distances %.2f / %.2f" % [near_zombie.hits_landed, far_zombie.hits_landed, _flat_distance(near_zombie, player), _flat_distance(far_zombie, player)])
	_clear_zombies()
	health.heal(100.0)

	# 4b. No hits through a wall: a zombie against a cottage wall, the player just inside (about 1.2 m apart). Then the height gate.
	var wall_house := kit.village.houses[0]
	var inner := wall_house.to_global(Vector3(House.WIDTH * 0.5 - House.WALL_THICKNESS - 0.45, 0.0, 0.0))
	var outer := wall_house.to_global(Vector3(House.WIDTH * 0.5 + 0.45, 0.0, 0.0))
	await kit.teleport(Vector3(inner.x, NAN, inner.z), 30)
	health.heal(100.0)
	z = _zombie(outer.x, outer.z)
	await kit.physics_frames(240)
	kit.check("a zombie pressed against the cottage wall cannot hit the player 1.2 m away just inside: 0 hits in 4 s, no line of sight, full hp",
			wall_house.is_inside(player.global_position) and _flat_distance(z, player) < 1.5 and z.hits_landed == 0 and not z.has_line_of_sight(player) and health.current == 100.0,
			"inside %s, distance %.2f, hits %d, line %s, hp %.0f" % [wall_house.is_inside(player.global_position), _flat_distance(z, player), z.hits_landed, z.has_line_of_sight(player), health.current])
	_clear_zombies()
	var ground_y := kit.terrain.height_at(0.0, 0.0)
	var platform := StaticBody3D.new()
	var platform_shape := CollisionShape3D.new()
	var platform_box := BoxShape3D.new()
	platform_box.size = Vector3(6.0, 0.4, 6.0)
	platform_shape.shape = platform_box
	platform.add_child(platform_shape)
	platform.position = Vector3(3.0, ground_y + 2.4, 0.0)  # top at +2.6 m, its edge at x = 0
	kit.world.add_child(platform)
	await kit.teleport(Vector3(0.2, ground_y + 2.7, 0.0), 30)
	z = _zombie(-1.1, 0.0)
	await kit.physics_frames(180)
	kit.check("a player standing 2.6 m up on a ledge 1.3 m away (clear line, but above the 1.6 m melee height) is not hit in 3 s",
			player.global_position.y - ground_y > 2.3 and z.has_line_of_sight(player) and _flat_distance(z, player) < 1.5 and z.hits_landed == 0,
			"player %.2f m up, line %s, distance %.2f, hits %d" % [player.global_position.y - ground_y, z.has_line_of_sight(player), _flat_distance(z, player), z.hits_landed])
	_clear_zombies()
	platform.free()
	await _player_to(0.0, 0.0)
	health.heal(100.0)

	# 5. A sleeping player is left alone. First the positive control: the same setup, player awake, zombie comes.
	var house := kit.village.houses[0]
	var bed: Bed = house.bed
	clock.set_time(21.0)
	var spot := bed.getting_up_point()
	await kit.teleport(Vector3(spot.x, NAN, spot.z), 30)
	var outside := house.door_outside(10.0)
	z = _zombie(outside.x, outside.z)
	await kit.physics_frames(5)
	var awake_start := _flat_distance(z, player)
	await kit.physics_frames(120)
	var awake_closed := awake_start - _flat_distance(z, player)
	kit.check("control: with the player awake beside the bed the zombie DOES come closer (over 2.5 m in 2 s)", awake_closed > 2.5, "closed %.2f m" % awake_closed)
	_clear_zombies()
	await kit.teleport(Vector3(spot.x, NAN, spot.z), 30)
	var toward_bed := bed.global_position - spot
	toward_bed.y = 0.0
	kit.face(toward_bed.normalized())
	(player.get_node("Body") as Node3D).rotation.y = atan2(-toward_bed.x, -toward_bed.z)
	await kit.physics_frames(10)
	z = _zombie(outside.x, outside.z)
	await kit.tap("interact")
	await kit.physics_frames(3)
	# Measure the ZOMBIE's own travel, not its distance to the player: the sleeper slides onto the bed, which changes that distance.
	var zombie_start := z.global_position
	var travelled := 0.0
	var frames_asleep := 0
	while sleep.is_sleeping() and frames_asleep < 900 and is_instance_valid(z):
		await kit.physics_frames(1)
		frames_asleep += 1
		if is_instance_valid(z):
			travelled = maxf(travelled, z.global_position.distance_to(zombie_start))
	kit.check("while the player sleeps the zombie stays where it is (never moves 0.3 m from its start; the sleep lasts over 60 frames)",
			frames_asleep > 60 and travelled < 0.3, "slept %d frames, zombie moved at most %.2f m" % [frames_asleep, travelled])
	_clear_zombies()
	clock.set_time(23.0)
	await kit.physics_frames(10)
	z = _zombie(outside.x, outside.z)
	await kit.physics_frames(5)
	var after_start := _flat_distance(z, player)
	await kit.physics_frames(120)
	kit.check("and once the player is awake again the zombie comes back for them (over 2.5 m in 2 s)", after_start - _flat_distance(z, player) > 2.5, "closed %.2f m" % (after_start - _flat_distance(z, player)))
	_clear_zombies()

	# 6. Sunlight burns: open ground at noon, the player far away.
	await _player_to(far.x, far.y)
	clock.set_time(12.0)
	z = _zombie(0.0, 0.0)
	await kit.physics_frames(5)
	var hp_start := (z.get_node("Health") as Health).current
	await kit.physics_frames(120)
	var hp_2s := (z.get_node("Health") as Health).current
	kit.check("at noon in the open a zombie loses about 2 hp per second (15.4 to 16.6 of 20 after 2 s: 8 ticks of 0.5) and is burning", hp_start == 20.0 and hp_2s >= 15.4 and hp_2s <= 16.6 and z.is_burning(), "hp %.1f -> %.1f, burning %s" % [hp_start, hp_2s, z.is_burning()])
	var torso_material := (z.get_node("Model/Torso") as MeshInstance3D).material_override as StandardMaterial3D
	var glow := torso_material
	kit.check("a burning zombie is scorched, not painted orange: its torso colour moves toward burnt brown (red up 0.05 to 0.5, blue down 0.1 to 0.5 from the base, and darker overall) with a faint orange glow",
			glow.emission_enabled and glow.emission_energy_multiplier > 0.2 and glow.albedo_color.r > 0.34 + 0.05 and glow.albedo_color.r < 0.34 + 0.5 and glow.albedo_color.b < 0.66 - 0.1 and glow.albedo_color.b > 0.66 - 0.5
			and glow.albedo_color.get_luminance() < Color(0.34, 0.42, 0.66).get_luminance(),
			"emission %s x%.2f, albedo %s" % [glow.emission_enabled, glow.emission_energy_multiplier, glow.albedo_color])
	var flames := z.get_node("Model/Flames") as CPUParticles3D
	var smoke := z.get_node("Model/Smoke") as CPUParticles3D
	kit.check("and it really burns: flames (40 squares, additive) and smoke (14, grey) are emitting and rise (gravity up), and they sit on the body",
			flames.emitting and smoke.emitting and flames.amount == 40 and smoke.amount == 14 and flames.gravity.y > 0.0 and smoke.gravity.y > 0.0,
			"flames %s x%d, smoke %s x%d" % [flames.emitting, flames.amount, smoke.emitting, smoke.amount])
	var eye_material := (z.get_node("Model/Head/EyeL") as MeshInstance3D).material_override as StandardMaterial3D
	kit.check("its eyes are a deep red that glows (emission pure red, energy 1.0 to 2.0), not an overbright pink", eye_material.emission_enabled and eye_material.emission.r > 0.9 and eye_material.emission.g < 0.1 and eye_material.emission.b < 0.1
			and eye_material.emission_energy_multiplier >= 1.0 and eye_material.emission_energy_multiplier <= 2.0, "emission %s x%.1f" % [eye_material.emission, eye_material.emission_energy_multiplier])
	var light := z.get_node("Model/FireLight") as OmniLight3D
	var light_lo := 99.0
	var light_hi := 0.0
	for i in 45:
		await kit.physics_frames(1)
		light_lo = minf(light_lo, light.light_energy)
		light_hi = maxf(light_hi, light.light_energy)
	kit.check("a burning zombie casts a flickering orange light (visible, red above green above blue, energy swinging by 0.6+ between 0.7 and 2.4 in 0.75 s)",
			light.visible and light.light_color.r > light.light_color.g and light.light_color.g > light.light_color.b and light_hi - light_lo >= 0.6 and light_lo >= 0.7 and light_hi <= 2.4,
			"visible %s, energy %.2f to %.2f" % [light.visible, light_lo, light_hi])
	var burned_up := false
	for i in 720:
		await kit.physics_frames(1)
		if not is_instance_valid(z):
			burned_up = true
			break
	kit.check("and it burns up completely within about 12 s of open sunlight (gone, not just hurt)", burned_up, "burned up: %s" % burned_up)
	_clear_zombies()

	# 7. Night, dusk and dawn: no burn when the sun is down; burn when it is up on either side.
	var burn_table := {}
	for hour in [1.0, 5.5, 6.1, 18.5, 6.4, 7.0, 17.0]:
		clock.set_time(hour)
		z = _zombie(0.0, 0.0)
		await kit.physics_frames(90)
		burn_table[hour] = (z.get_node("Health") as Health).current
		z.free()
	kit.check("no burn at 1:00, 5:30, 6:06 (sun only 1.5 degrees up, ray unobstructed: the 0.05 elevation rule) or 6:30 PM; burns at 6:24 AM, 7:00 AM and 5:00 PM",
			burn_table[1.0] == 20.0 and burn_table[5.5] == 20.0 and burn_table[6.1] == 20.0 and burn_table[18.5] == 20.0
			and burn_table[6.4] < 19.0 and burn_table[7.0] < 19.0 and burn_table[17.0] < 19.0, str(burn_table))

	# 8. Shade: inside a cottage at noon the roof protects it; the same zombie outside burns; people cast no shade.
	clock.set_time(12.0)
	var inside := bed.getting_up_point()
	z = _zombie(inside.x, inside.z)
	z.global_position.y = house.global_position.y + 0.3
	await kit.physics_frames(120)
	kit.check("inside a cottage at noon (under its roof) a zombie takes no damage and is not burning", house.is_inside(z.global_position) and (z.get_node("Health") as Health).current == 20.0 and not z.is_burning(),
			"inside %s, hp %.1f, burning %s" % [house.is_inside(z.global_position), (z.get_node("Health") as Health).current, z.is_burning()])
	z.free()
	# Steady fire: in the open the burning never drops out for a single frame over 3 s (no flicker), and the fire goes out after shade.
	z = _zombie(0.0, 0.0)
	await kit.physics_frames(30)
	var dropouts := 0
	var flames_off := 0
	for i in 180:
		await kit.physics_frames(1)
		if not z.is_burning():
			dropouts += 1
		if not z.flames_active():
			flames_off += 1
	kit.check("in open sunlight the burning is CONSTANT: 180 frames in a row burning and flaming, no gaps", dropouts == 0 and flames_off == 0, "%d frames not burning, %d without flames" % [dropouts, flames_off])
	z = _zombie(0.0, 0.0)
	await kit.physics_frames(60)
	var open_air_sun := z.is_in_sunlight()
	kit.check("control: outside in the open at the same moment the same check says sunlight", open_air_sun)
	var head := z.global_position + Vector3.UP * Zombie.HEAD_HEIGHT
	var to_sun := clock.toward_sun()
	var blocker := StaticBody3D.new()
	var blocker_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	blocker_shape.shape = box
	blocker.add_child(blocker_shape)
	blocker.position = head + to_sun * 3.0
	kit.world.add_child(blocker)
	await kit.physics_frames(3)
	kit.check("a 1.5 m block 3 m toward the sun puts the zombie in shade (the ray really hits things)", not z.is_in_sunlight())
	blocker.free()
	await kit.physics_frames(3)
	player.global_position = head + to_sun * 3.0
	await kit.physics_frames(1)
	kit.check("a player standing in the light's path casts no shade", z.is_in_sunlight(), "player at %s" % player.global_position)
	z.free()
	await _player_to(far.x, far.y)

	# 9. The spawner.
	spawner.seed_value = 4242
	spawner._rng.seed = 4242
	spawner.max_zombies = 6
	spawner.spawn_interval = 1.0
	await _player_to(0.0, 0.0)
	clock.set_time(10.0)
	spawner._timer = 0.0  # a leftover countdown from an earlier night would hide a missing day gate (lesson 61): with 0 it spawns on frame 1
	spawner.enabled = true
	await kit.physics_frames(300)
	kit.check("by day an enabled spawner spawns nothing (5 s)", spawner.zombie_count() == 0, "count %d" % spawner.zombie_count())
	clock.set_time(23.0)
	await kit.physics_frames(2)
	var after_burst := spawner.zombie_count()
	kit.check("when the night starts a burst of 3 zombies appears at once", after_burst == 3, "count %d" % after_burst)
	await kit.physics_frames(88)
	kit.check("and the next one comes after the 1 s interval, not before: 4 zombies at 1.5 s (pins the first interval)", spawner.zombie_count() == 4, "count %d" % spawner.zombie_count())
	await kit.physics_frames(60)
	kit.check("and the repeating interval holds too (a different line of code): 5 zombies at 2.5 s", spawner.zombie_count() == 5, "count %d" % spawner.zombie_count())
	await kit.physics_frames(60 * 10)
	kit.check("then one more per second up to the cap of 6, and not beyond", spawner.zombie_count() == 6, "count %d after 10 s" % spawner.zombie_count())
	_clear_zombies()
	await kit.physics_frames(2)
	spawner.enabled = false
	await kit.physics_frames(240)
	kit.check("a disabled spawner spawns nothing at night", spawner.zombie_count() == 0)
	spawner.enabled = true
	spawner.max_zombies = 2
	var spawned: Array[Zombie] = []
	var positions_ok := true
	var bad := ""
	for i in 5:
		var s := spawner.try_spawn()
		if s != null:
			spawned.append(s)
			var d := _flat_distance(s, player)
			var p := s.global_position
			var limit := kit.terrain.half_size() - 6.0  # literal: the test must not read the setting from the thing under test
			if d < 24.99 or d > 150.01 or absf(p.x) > limit or absf(p.z) > limit or kit.terrain.in_village(p.x, p.z, 6.0) or kit.terrain.water_depth_at(p.x, p.z) > 0.0 \
					or absf(p.y - kit.terrain.height_at(p.x, p.z)) > 0.5:
				positions_ok = false
				bad = "%s (distance %.1f)" % [p, d]
	kit.check("the cap of 2 holds: only 2 of 5 try_spawn calls produce a zombie", spawned.size() == 2 and spawner.zombie_count() == 2, "spawned %d" % spawned.size())
	kit.check("their spawn points are 25 to 150 m from the player, inside the walls, outside the village, on dry ground, on the terrain", positions_ok, bad)
	if not spawned.is_empty():  # never index an empty list: a crashed coroutine leaves Godot running until the step timeout
		spawned[0].free()
	kit.check("a free slot appears when a zombie is gone: the next try_spawn works", not spawned.is_empty() and spawner.try_spawn() != null)
	_clear_zombies()
	var many_ok := true
	var many_bad := ""
	for i in 300:
		var point := spawner.pick_spawn_point(Vector3(0, 0, 0))
		if not is_finite(point.x):
			continue
		var dd := Vector2(point.x, point.z).length()
		if dd < 24.99 or dd > 150.01 or kit.terrain.in_village(point.x, point.z, 6.0) or kit.terrain.water_depth_at(point.x, point.z) > 0.0:
			many_ok = false
			many_bad = str(point)
	kit.check("300 random spawn points around the spawn clearing all obey the rules", many_ok, many_bad)
	var corner := spawner.pick_spawn_point(Vector3(kit.terrain.half_size() - 8.0, 0.0, kit.terrain.half_size() - 8.0))
	kit.check("near the world's corner a spawn point stays inside the walls (or is refused)", not is_finite(corner.x) or (absf(corner.x) <= kit.terrain.half_size() - 6.0 and absf(corner.z) <= kit.terrain.half_size() - 6.0), str(corner))
	# Margins and clearance, with literals (6 m) and an independent overlap query, not the spawner's own settings.
	var edge_bad := 0
	var band_bad := 0
	var half := kit.terrain.half_size()
	for i in 300:
		var c := spawner.pick_spawn_point(Vector3(half - 8.0, 0.0, half - 8.0))
		if is_finite(c.x) and (absf(c.x) > half - 6.0 or absf(c.z) > half - 6.0):
			edge_bad += 1
	var village_origin := kit.village.center() + Vector3(0.0, 0.0, 50.0)  # the 25 to 40 m ring around it crosses the village edge band
	for i in 400:
		var b := spawner.pick_spawn_point(village_origin)
		if is_finite(b.x) and kit.terrain.in_village(b.x, b.z, 6.0):
			band_bad += 1
	kit.check("300 spawn points near the world corner never go past the 6 m edge margin, and 400 near the village never enter its 6 m margin band (literal margins)", edge_bad == 0 and band_bad == 0, "past edge %d, in village band %d" % [edge_bad, band_bad])
	var touching := 0
	var checked := 0
	for centre in [Vector3(0, 0, 0), Vector3(kit.terrain.pond_center.x, 0, kit.terrain.pond_center.y), kit.village.center(), Vector3(half - 8.0, 0.0, half - 8.0), Vector3(-half + 8.0, 0.0, half - 8.0)]:
		for i in 400:
			var q := spawner.pick_spawn_point(centre)
			if is_finite(q.x):
				checked += 1
				if _touches_scenery(q):
					touching += 1
	kit.check("2000 spawn points around the spawn, lake, village and two corners: none puts a zombie inside a tree, rock or cottage (independent capsule query)", checked > 1500 and touching == 0, "checked %d, touching %d" % [checked, touching])
	var blocker_area := StaticBody3D.new()
	var blocker_area_shape := CollisionShape3D.new()
	var blocker_area_box := BoxShape3D.new()
	blocker_area_box.size = Vector3(40.0, 30.0, 40.0)
	blocker_area_shape.shape = blocker_area_box
	blocker_area.add_child(blocker_area_shape)
	blocker_area.position = Vector3(30.0, 0.0, 0.0)  # solid from x 10 to 50, z -20 to 20, around the ground
	kit.world.add_child(blocker_area)
	await kit.physics_frames(3)
	var inside_box := 0
	for i in 400:
		var r := spawner.pick_spawn_point(Vector3(0.0, 0.0, 0.0))
		if is_finite(r.x) and r.x > 10.0 and r.x < 50.0 and absf(r.z) < 20.0:
			inside_box += 1
	blocker_area.free()
	kit.check("a solid block across part of the spawn ring is never chosen as a spawn point (0 of 400 inside it)", inside_box == 0, "inside the block: %d" % inside_box)
	spawner.enabled = false
	spawner.max_zombies = 6

	# 10. Being hit to 0 knocks the player out: back at the spawn at full health, with a message.
	clock.set_time(23.0)
	await _player_to(15.0, 15.0)
	health.heal(100.0)
	health.damage(95.0)  # 5 hp left: one zombie hit (8) is enough
	var hud := player.get_node("HUD") as InteractionPrompt
	z = _zombie(16.2, 15.0)
	_died = 0
	health.died.connect(func(): _died += 1)
	await kit.physics_frames(30)
	kit.check("a zombie hit at 5 hp knocks the player out once: back at the respawn point (within 1.5 m: the world spawn, or the bed an earlier section slept in), full hp, alive, free to move",
			_died == 1 and player.global_position.distance_to(player.spawn_point()) < 1.5 and health.current == 100.0 and not health.is_dead() and not player.input_locked,
			"died x%d, at %s, hp %.0f" % [_died, player.global_position, health.current])
	kit.check("and the HUD says what happened", hud.message_text().contains("knocked out"), "'%s'" % hud.message_text())
	_clear_zombies()

	# 11. The brain: strolling, going around things, getting unstuck.
	clock.set_time(23.0)
	await _player_to(80.0, 80.0)  # far away: nobody to chase
	var stroll_end := Vector3.ZERO
	var stroll := {}
	for run in 2:
		z = _zombie(0.0, 0.0)
		z.wander = true
		z._rng.seed = 11
		await kit.physics_frames(5)
		var home := z.global_position
		var last := z.global_position
		var path := 0.0
		var farthest := 0.0
		var top_speed := 0.0
		var rest := 0
		var longest_rest := 0
		var rests := 0
		var has_moved := false
		var end_10s := Vector3.ZERO
		for i in 1500:
			await kit.physics_frames(1)
			var step := Vector2(z.global_position.x - last.x, z.global_position.z - last.z).length()
			last = z.global_position
			path += step
			top_speed = maxf(top_speed, step * 60.0)
			farthest = maxf(farthest, Vector2(z.global_position.x - home.x, z.global_position.z - home.z).length())
			if step * 60.0 < 0.05:
				rest += 1
				longest_rest = maxi(longest_rest, rest) if has_moved else longest_rest
			else:
				if rest >= 60 and has_moved:
					rests += 1
				rest = 0
				has_moved = true
			if i == 599:
				end_10s = z.global_position
		if run == 0:
			stroll = {"path": path, "farthest": farthest, "top": top_speed, "rest": longest_rest, "rests": rests, "end": end_10s}
			stroll_end = end_10s
		else:
			kit.check("with the same seed a second zombie strolls to the same place (within 0.3 m after 10 s): the stroll is random but repeatable",
					end_10s.distance_to(stroll_end) < 0.3, "%s vs %s" % [end_10s, stroll_end])
		z.free()
	kit.check("with nobody to chase a zombie strolls: 6 to 30 m of walking in 25 s, never farther than 10.5 m from where it spawned, never faster than 1.2 m/s (40% of walk speed), and it stops to rest for 1.7 to 5.5 s at least twice",
			stroll["path"] > 6.0 and stroll["path"] < 30.0 and stroll["farthest"] <= 10.5 and stroll["top"] <= 1.2 and stroll["rest"] >= 100 and stroll["rest"] <= 330 and stroll["rests"] >= 2,
			str(stroll))

	await _player_to(0.0, 0.0)
	var wall_y := kit.terrain.height_at(6.0, 0.0)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.5, 4.0, 24.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(6.0, wall_y + 1.5, 0.0)  # a wall 24 m long between the zombie (x 12) and the player (x 0): the way round is long, so it only works if the zombie picks a side and sticks to it
	kit.world.add_child(wall)
	await kit.physics_frames(3)
	var around := {}
	for variant in ["avoids", "no_avoidance", "neither"]:
		z = _zombie(12.0, 0.0)
		z.avoid_obstacles = variant == "avoids"
		z.unstick = variant == "avoids"
		var widest := 0.0
		var closest := 99.0
		for i in (1500 if variant == "avoids" else 480):
			await kit.physics_frames(1)
			widest = maxf(widest, absf(z.global_position.z))
			closest = minf(closest, _flat_distance(z, player))
		around[variant] = {"widest": widest, "closest": closest}
		z.free()
		health.heal(100.0)
		await _player_to(0.0, 0.0)
	kit.check("a zombie chasing round a 24 m wall walks AROUND it: within 25 s it swings out past the wall's end (12.5 m+ to the side) and reaches the player (under 2.2 m)",
			around["avoids"]["widest"] > 12.5 and around["avoids"]["closest"] < 2.2, str(around["avoids"]))
	kit.check("control: with avoidance and unsticking both off the same zombie stays pressed against the wall for 8 s (never reaches 5 m of the player, never goes wide)",
			around["neither"]["closest"] > 5.0 and around["neither"]["widest"] < 2.0, str(around["neither"]))
	wall.free()

	var long_wall := StaticBody3D.new()
	var long_shape := CollisionShape3D.new()
	var long_box := BoxShape3D.new()
	long_box.size = Vector3(0.5, 4.0, 60.0)
	long_shape.shape = long_box
	long_wall.add_child(long_shape)
	long_wall.position = Vector3(6.0, wall_y + 1.5, 0.0)
	kit.world.add_child(long_wall)
	await kit.physics_frames(3)
	var wiggle := {}
	for variant in ["unstick", "off"]:
		z = _zombie(8.0, 0.0)
		z.avoid_obstacles = false
		z.unstick = variant == "unstick"
		z._rng.seed = 5
		var excursion := 0.0
		for i in 6 * 60:
			await kit.physics_frames(1)
			excursion = maxf(excursion, absf(z.global_position.z))  # the LARGEST sideways distance: the random side of each sidestep can cancel out in the end
		wiggle[variant] = excursion
		z.free()
		health.heal(100.0)
	kit.check("pressed against a 60 m wall with no way round, a zombie sidesteps loose: at some point 1.4 m+ to the side within 6 s", wiggle["unstick"] > 1.4, str(wiggle))
	kit.check("control: with unsticking off it stays where it hit the wall (under 0.5 m sideways)", wiggle["off"] < 0.5, str(wiggle))
	long_wall.free()
	_clear_zombies()

	# 12. Doors: a zombie that meets a closed cottage door opens it and comes in (a night indoors is not safe).
	kit.day_night.set_time(22.0)
	var cottage := kit.village.houses[0]
	cottage.door.close()
	await kit.physics_frames(40)
	var spot_in := cottage.to_global(Vector3(0, 0, -0.5))
	await kit.teleport(Vector3(spot_in.x, NAN, spot_in.z), 20)
	var spot_out := cottage.door_outside(3.0)
	z = _zombie(spot_out.x, spot_out.z)
	z.walk_speed = 2.4
	await kit.physics_frames(60 * 6)
	kit.check("a zombie chasing a player inside a cottage opens the closed door (it opened %d time) and enters" % z.doors_opened, z.doors_opened >= 1 and cottage.door.is_open and cottage.is_inside(z.global_position), "opened %d, door open %s, zombie inside %s at %s" % [z.doors_opened, cottage.door.is_open, cottage.is_inside(z.global_position), z.global_position])
	_clear_zombies()
	cottage.door.close()
	await kit.physics_frames(40)

	# 13. Burning looks orange, not mauve: the scorched body is warmer than the unburnt one, in red against blue.
	kit.day_night.set_time(12.0)
	await _player_to(0.0, 0.0)
	z = _zombie(30.0, 30.0)
	var calm_colour := z.get_node("Model/Torso").get("material_override").albedo_color as Color
	await kit.physics_frames(60)
	var burnt_colour := z.get_node("Model/Torso").get("material_override").albedo_color as Color
	kit.check("a burning torso is scorched toward orange: more red than blue (it is blue-ish cloth when calm)", burnt_colour.r > burnt_colour.b + 0.1 and calm_colour.r < calm_colour.b, "calm %s, burning %s" % [calm_colour, burnt_colour])
	kit.check("the fire light is red-orange (red 1.0, green under 0.4) so it does not turn grass olive", (z.get_node("Model/FireLight") as OmniLight3D).light_color.g < 0.4)
	_clear_zombies()

	kit.finish()
