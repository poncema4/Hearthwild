class_name Zombie
extends CharacterBody3D
## The basic night zombie (step 12), Minecraft logic: it walks toward the nearest awake player, hits when close, ignores a
## sleeping player, and the sun burns it slowly (it has hit points) unless something blocks the light (shade, a roof, a hill).
## Built in code like the dog: green box people, no scene file. Nothing here wanders or paths around obstacles yet (step 13).
##
## Layout it builds: CollisionShape3D (capsule, same size as the player), Health (child node "Health"), Model (boxes).
## Burning is decided by a RAY from the head toward the sun (DayNight.toward_sun()); characters and the invisible world
## walls (group `boundary`) never count as shade, so only things with a collider do: terrain, tree TRUNKS (the leaves have no
## collider yet, so standing under a canopy still burns), rocks and roofs. Attacks need a clear line too (no hitting through a wall).

signal hit_player(who: Node3D, amount: float)

@export var max_health: float = 20.0
@export var walk_speed: float = 2.4  ## slower than the player's walk (4 m/s): a walking player can always outrun one
@export var acceleration: float = 12.0
@export var detect_range: float = 28.0
@export var attack_range: float = 1.5
@export var attack_damage: float = 8.0
@export var attack_interval: float = 1.2
@export var sun_damage_per_second: float = 2.0  ## 20 hp: about 10 s to burn up in open sunlight
@export var turn_speed: float = 8.0

const GRAVITY := 20.0
const HEAD_HEIGHT := 1.7  ## where the sun ray starts (the head actually reaches 1.93 m, 0.13 m above the 1.8 m capsule: a known Nit, INTENTIONAL.md)
const SUN_RAY_LENGTH := 80.0
const SUN_MIN_ELEVATION := 0.05  ## the sun must be this far above the horizon to burn (0 = exactly sunrise)
const SUN_TICK := 0.25  ## seconds between sunlight checks (one ray each)
const NIGHT_LIFT := 0.7  ## how strongly the body glows in its own colour when not burning
const BURN_TINT := Color(0.62, 0.26, 0.08)  ## a burning body is scorched toward this burnt orange-brown (Animator: orange alone read as pale pink)
const BURN_GLOW := Color(1.0, 0.4, 0.1)

var health: Health
var hits_landed := 0

var _attack_cooldown := 0.0
var _sun_timer := 0.0
var _in_sun := false
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _walk_phase := 0.0
var _glow_materials: Array[StandardMaterial3D] = []
var _flames: CPUParticles3D
var _smoke: CPUParticles3D
var _base_colors: Array[Color] = []  ## each body material's own colour, restored when the burning stops


func _ready() -> void:
	add_to_group(&"zombie")
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	health = Health.new()
	health.name = "Health"
	health.max_health = max_health
	add_child(health)
	health.died.connect(queue_free)
	_build_model()


func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var wanted := Vector3.ZERO
	var target := pick_target()
	if target != null:
		var to_target := target.global_position - global_position
		to_target.y = 0.0
		var distance := to_target.length()
		var direction := to_target / maxf(distance, 0.001)
		if distance > 0.05:
			_face(direction, delta)
		if distance > attack_range * 0.8:
			wanted = direction * walk_speed
		if distance <= attack_range and absf(target.global_position.y - global_position.y) < 1.6 and _attack_cooldown == 0.0 and has_line_of_sight(target):
			_attack(target)
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2(wanted.x, wanted.z), acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.y
	move_and_slide()
	_animate(Vector2(velocity.x, velocity.z).length(), delta)

	_sun_timer += delta
	if _sun_timer >= SUN_TICK:
		_sun_timer -= SUN_TICK
		_in_sun = is_in_sunlight()
		if _in_sun:
			health.damage(sun_damage_per_second * SUN_TICK)
		_set_glow(1.0 if _in_sun else 0.0)


## The nearest living player within detect_range, or null. A sleeping player is left alone (nobody is a target
## while the SleepSystem is running: there is one shared clock, so one sleeper skips the night for everyone).
func pick_target() -> Node3D:
	var sleep := get_tree().get_first_node_in_group(&"sleep_system") as SleepSystem
	if sleep != null and sleep.is_sleeping():
		return null
	var best: Node3D = null
	var best_distance := detect_range
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Node3D
		var their_health := player.get_node_or_null("Health") as Health
		if their_health != null and their_health.is_dead():
			continue
		var distance := player.global_position.distance_to(global_position)
		if distance <= best_distance:
			best = player
			best_distance = distance
	return best


## True when the sun is up AND a ray from the head toward it reaches the sky (no roof, tree, rock or hill in the way).
func is_in_sunlight() -> bool:
	var clock := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if clock == null or clock.sun_elevation() < SUN_MIN_ELEVATION:
		return false
	var from := global_position + Vector3.UP * HEAD_HEIGHT
	return _ray_clear(from, from + clock.toward_sun() * SUN_RAY_LENGTH)


## True when nothing solid is between the zombie's chest and the target's chest (a wall or a roof stops a hit).
func has_line_of_sight(target: Node3D) -> bool:
	return _ray_clear(global_position + Vector3.UP * 1.0, target.global_position + Vector3.UP * 1.0)


## True when a ray from `from` to `to` reaches its end. Characters and the invisible world walls (group `boundary`) are
## passed through, so only real scenery blocks it: terrain, tree trunks, rocks and buildings.
func _ray_clear(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	for attempt in 8:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider := hit["collider"] as CollisionObject3D
		if collider is CharacterBody3D or collider.is_in_group(&"boundary"):
			exclude.append(collider.get_rid())
			continue
		return false
	return true


func is_burning() -> bool:
	return _in_sun


func _attack(target: Node3D) -> void:
	_attack_cooldown = attack_interval
	var their_health := target.get_node_or_null("Health") as Health
	if their_health == null:
		return
	var taken := their_health.damage(attack_damage)
	if taken > 0.0:
		hits_landed += 1
		hit_player.emit(target, taken)


func _face(direction: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(turn_speed * delta, 1.0))


func _animate(speed: float, delta: float) -> void:
	_walk_phase += speed * delta * 3.0
	var swing := leg_swing(speed)
	if _legs.size() == 2:
		_legs[0].rotation.x = swing
		_legs[1].rotation.x = -swing


## How far the legs swing (radians) at `speed`: full swing at walk speed, none when standing. Always finite, even for a
## zombie whose walk_speed is 0 (a stationary one): dividing by 0 gave NaN and the engine rejected it with an ERROR flood (lesson 61).
func leg_swing(speed: float) -> float:
	return sin(_walk_phase) * 0.6 * clampf(speed / maxf(walk_speed, 0.01), 0.0, 1.0)


## Burning (amount 1) glows orange; otherwise the body gets a faint self-lit lift of its own colour, so a zombie stands out against a
## moonlit meadow instead of vanishing into it (Hawkeye, step 12). Emission is always on, so toggling never changes the look abruptly.
func _set_glow(amount: float) -> void:
	for i in _glow_materials.size():
		var material := _glow_materials[i]
		material.emission_enabled = true
		if amount > 0.0:
			# Burning: the colour itself moves toward orange, because an additive glow alone washes out to pale pink in the
			# bright Compatibility-renderer daylight (CI caught it, lesson 63).
			material.albedo_color = _base_colors[i].lerp(BURN_TINT, 0.4 * amount)  # a scorched look; the FIRE below carries the effect
			material.emission = BURN_GLOW
			material.emission_energy_multiplier = 0.3 * amount
		else:
			material.albedo_color = _base_colors[i]
			material.emission = _base_colors[i]
			material.emission_energy_multiplier = NIGHT_LIFT
	if _flames != null:
		_flames.emitting = amount > 0.0
		_smoke.emitting = amount > 0.0


func _build_model() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var skin := _material(Color(0.55, 0.76, 0.50))  # light enough to read against a moonlit meadow
	var cloth := _material(Color(0.34, 0.42, 0.66))
	var pants := _material(Color(0.34, 0.37, 0.54))
	_glow_materials = [skin, cloth, pants]
	for material in _glow_materials:
		_base_colors.append(material.albedo_color)
	_box(model, "Torso", Vector3(0.6, 0.8, 0.34), Vector3(0, 1.1, 0), cloth)
	_box(model, "Head", Vector3(0.42, 0.42, 0.42), Vector3(0, 1.72, 0), skin)
	for side in [-1.0, 1.0]:
		_box(model.get_node("Head") as Node3D, "Eye%s" % ("L" if side < 0 else "R"), Vector3(0.08, 0.06, 0.02),
				Vector3(0.1 * side, 0.04, -0.215), _eye_material())
		var arm := Node3D.new()
		arm.name = "Arm%s" % ("L" if side < 0 else "R")
		arm.position = Vector3(0.4 * side, 1.45, 0)
		arm.rotation.x = deg_to_rad(85.0)  # held straight out in FRONT (-Z, where the eyes face): +85 about X turns a downward limb forward; -85 pointed backward (lesson 63)
		model.add_child(arm)
		_box(arm, "Mesh", Vector3(0.16, 0.7, 0.16), Vector3(0, -0.3, 0), skin)
		_arms.append(arm)
		var leg := Node3D.new()
		leg.name = "Leg%s" % ("L" if side < 0 else "R")
		leg.position = Vector3(0.16 * side, 0.7, 0)
		model.add_child(leg)
		_box(leg, "Mesh", Vector3(0.22, 0.7, 0.22), Vector3(0, -0.35, 0), pants)
		_legs.append(leg)
	_build_fire(model)
	_set_glow(0.0)


## Flames (square, additive, yellow to red) and smoke (grey, growing) that rise off the body while the sun burns it. CPU particles, so they
## work in every renderer and headless; the squares match the blocky art. Off unless burning (`_set_glow`).
func _build_fire(model: Node3D) -> void:
	var flame_ramp := Gradient.new()
	flame_ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	flame_ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.2, 1.0), Color(1.0, 0.45, 0.05, 1.0), Color(0.8, 0.15, 0.02, 0.75), Color(0.2, 0.03, 0.0, 0.0)])
	# Normal alpha blending, not additive: additive flames bleach to pale yellow on a bright noon sky (CI's Compatibility renderer showed it).
	_flames = _particles("Flames", 40, 0.7, 0.3, flame_ramp, 0.9, 1.8, 0.8, false)
	model.add_child(_flames)
	var smoke_ramp := Gradient.new()
	smoke_ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	smoke_ramp.colors = PackedColorArray([Color(0.2, 0.2, 0.2, 0.0), Color(0.22, 0.22, 0.22, 0.85), Color(0.1, 0.1, 0.1, 0.0)])
	_smoke = _particles("Smoke", 14, 1.7, 0.36, smoke_ramp, 0.5, 1.0, 0.5, false)
	_smoke.position.y = 1.6
	_smoke.scale_amount_max = 2.4
	model.add_child(_smoke)


func _particles(node_name: String, amount: int, lifetime: float, size: float, ramp: Gradient, speed_min: float, speed_max: float, rise: float, additive: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emitting = false
	particles.local_coords = false  # embers stay where they were released when the zombie walks
	particles.position = Vector3(0.0, 0.97, 0.0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(0.3, 0.97, 0.2)  # covers the body from the feet (0) to the top of the head (1.94)
	particles.direction = Vector3.UP
	particles.spread = 22.0
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = Vector3(0.0, rise, 0.0)
	particles.color_ramp = ramp
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	material.no_depth_test = false
	mesh.material = material
	particles.mesh = mesh
	return particles


func _box(parent: Node3D, node_name: String, size: Vector3, offset: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	parent.add_child(instance)
	return instance


## Red eyes that glow a little, so a zombie is spotted in the dark by its eyes first.
func _eye_material() -> StandardMaterial3D:
	var material := _material(Color(0.85, 0.0, 0.0))
	material.emission_enabled = true
	material.emission = Color(1.0, 0.0, 0.0)
	material.emission_energy_multiplier = 1.3
	return material


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
