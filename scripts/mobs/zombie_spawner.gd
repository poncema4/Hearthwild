class_name ZombieSpawner
extends Node
## Spawns night zombies around the player (step 12): none by day, a small burst when the night starts, then one every
## `spawn_interval` seconds up to `max_zombies` alive at once. A spawn point is 25 to 40 m from the player, inside the world
## walls, outside the village (plus a margin) and on dry land. Zombies still alive at sunrise burn up by themselves.
## Tests and screenshot scripts set `enabled = false` (PlaytestKit does this on load) so a night-time test never gets visitors.
##
## Expects siblings "Terrain" and a node in group `day_night`; players are found through the group `player`.

@export var enabled := true
@export var max_zombies := 6
@export var initial_burst := 3
@export var spawn_interval := 15.0
@export var min_distance := 25.0
@export var max_distance := 40.0
@export var village_margin := 6.0
@export var edge_margin := 6.0
@export var seed_value := 0  ## 0 = a different night every run; tests set a fixed seed
@export var terrain_path: NodePath = ^"../Terrain"

var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _terrain: Terrain
var _clock: DayNight


func _ready() -> void:
	add_to_group(&"zombie_spawner")
	_terrain = get_node_or_null(terrain_path) as Terrain
	_clock = get_tree().get_first_node_in_group(&"day_night") as DayNight
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	if _clock:
		_clock.night_started.connect(_on_night_started)


func _physics_process(delta: float) -> void:
	if not enabled or _clock == null or not _clock.is_night():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		try_spawn()


func zombie_count() -> int:
	return get_tree().get_nodes_in_group(&"zombie").size()


## Spawns one zombie if the cap allows and a valid point exists. Returns it, or null.
func try_spawn() -> Zombie:
	if zombie_count() >= max_zombies:
		return null
	var player := _nearest_player()
	if player == null or _terrain == null:
		return null
	var point := pick_spawn_point(player.global_position)
	if not is_finite(point.x):
		return null
	var zombie := Zombie.new()
	zombie.position = point
	zombie.rotation.y = _rng.randf() * TAU
	get_parent().add_child(zombie)
	return zombie


## A valid spawn point near `around`, or Vector3(INF, INF, INF) when 16 tries found none.
func pick_spawn_point(around: Vector3) -> Vector3:
	var limit := _terrain.half_size() - edge_margin
	for attempt in 16:
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(min_distance, max_distance)
		var x := around.x + cos(angle) * distance
		var z := around.z + sin(angle) * distance
		if absf(x) > limit or absf(z) > limit:
			continue
		if _terrain.in_village(x, z, village_margin) or _terrain.water_depth_at(x, z) > 0.0:
			continue
		var point := Vector3(x, _terrain.height_at(x, z) + 0.3, z)
		if not _is_free(point):
			continue
		return point
	return Vector3.INF


## True when a zombie-sized capsule standing at `point` touches no tree, rock, building or steep ground (Ghoul found about 1% of spawns inside a trunk).
func _is_free(point: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.95)
	query.collide_with_areas = false
	var space: PhysicsDirectSpaceState3D = (get_parent() as Node3D).get_world_3d().direct_space_state
	return space.intersect_shape(query, 1).is_empty()


func _on_night_started() -> void:
	_timer = spawn_interval
	if not enabled:
		return
	for i in initial_burst:
		try_spawn()


## A random player: with several players the zombies come for each in turn (the first-in-group player would get every spawn).
func _nearest_player() -> Node3D:
	var nodes := get_tree().get_nodes_in_group(&"player")
	return nodes[_rng.randi() % nodes.size()] as Node3D if not nodes.is_empty() else null
