class_name Arsenal
extends Node
## The player's weapons: which are unlocked, which is in hand, the swing, and who gets hit. A child of the Player named "Arsenal".
##
## Left click or F swings the weapon in hand (keys 1 to 4 switch). The swing turns the character toward where the camera looks, raises the arm and
## brings it down; at HIT_FRACTION of the swing every zombie inside the weapon's reach and arc (and not behind a wall) takes the damage and is knocked
## back. Nothing happens while the player is locked (menus, the character screen), asleep, seated, knocked out or in the middle of a swing.

signal swung(weapon_index: int)
signal shot(hit: Node, point: Vector3)
signal selected_changed(weapon_index: int)
signal unlocked_changed()

var selected := -1  ## the hotbar slot in hand; -1 = nothing equipped (fists)
var unlocked: Array[bool] = []
var swing_time := -1.0  ## seconds since the swing began, -1 when not swinging
var cooldown_left := 0.0
var swings_started := 0
var hits_landed := 0

var _player: PlayerController
var _model: AnimalModel
var _weapon_node: Node3D
var _hit_done := false
var _swing_index := 0
var last_shot: Dictionary = {}


func _ready() -> void:
	add_to_group(&"arsenal")
	_player = get_parent() as PlayerController
	for i in Weapons.count():
		unlocked.append(i < Weapons.STARTING)  # only the wooden sword; the village rack gives the rest
	_model = _player.get_node_or_null("Body/Model") as AnimalModel
	_equip_model()
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		try_swing()
	for i in Weapons.count():
		if event.is_action_pressed(StringName("weapon_%d" % (i + 1))):
			select(i)


## Selects hotbar slot `index` if it is unlocked; pressing the slot already in hand puts the weapon away (fists). Returns true when the selection changed.
func select(index: int) -> bool:
	if index < -1 or index >= Weapons.count() or swing_time >= 0.0 or _blocked():
		return false
	if index >= 0 and not unlocked[index]:
		return false
	selected = -1 if index == selected else index
	_equip_model()
	_refresh_hud()
	selected_changed.emit(selected)
	return true


## Gives every weapon (the village weapon rack).
func unlock_all() -> void:
	for i in unlocked.size():
		unlocked[i] = true
	_refresh_hud()
	unlocked_changed.emit()


func weapon() -> Dictionary:
	return Weapons.def(selected)


func is_swinging() -> bool:
	return swing_time >= 0.0


## Starts a swing. Returns true when one started.
func try_swing() -> bool:
	if _blocked() or swing_time >= 0.0 or cooldown_left > 0.0:
		return false
	_swing_index = selected
	swing_time = 0.0
	cooldown_left = float(weapon()["cooldown"])
	_hit_done = false
	swings_started += 1
	if _model != null:
		_model.set_swing_style(["slash", "punch", "recoil", "thrust"].find(String(weapon()["anim"])))
	if Weapons.is_gun(selected):
		_hit_done = true
		_shoot()
	swung.emit(selected)
	return true


func _blocked() -> bool:
	if _player == null:
		return true
	if _player.input_locked or _player.sleeping or _player.seat != null:
		return true
	var health := _player.get_node_or_null("Health") as Health
	return health != null and health.is_dead()


func _physics_process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_update_cooldown_sweep()
	if swing_time < 0.0:
		return
	swing_time += delta
	var duration := float(Weapons.def(_swing_index)["swing"])
	if not _hit_done and swing_time >= duration * Weapons.HIT_FRACTION:
		_hit_done = true
		_land_hits()
	if swing_time >= duration:
		swing_time = -1.0
		if _model != null:
			_model.set_swing(-1.0)
	elif _model != null:
		_model.set_swing(swing_time / duration)


## The flat direction an attack goes right now: THE WAY THE CHARACTER ALREADY FACES (Marco: "if im standing still or holding a direction of wasd then i should keep
## facing that direction when i use any of the weapons"). Standing still it is the way it last faced, holding W, A, S or D it is the way it walks, in shift lock it
## is where the camera looks (the body already faces there). An attack never turns the character, toward the camera or anywhere else.
func facing() -> Vector3:
	var body := _player.get_node("Body") as Node3D
	var forward := -body.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


## The way the camera looks, flat (not used for aiming: kept for tests that place things "where the camera looks").
func camera_direction() -> Vector3:
	var rig := get_tree().get_first_node_in_group(&"camera_rig") as Node3D
	if rig == null:
		return -(_player.get_node("Body") as Node3D).global_transform.basis.z
	return Vector3(-sin(rig.rotation.y), 0.0, -cos(rig.rotation.y))


## Every zombie the swing in progress reaches: inside the reach, inside the cone, within a body's height, and not behind a wall.
func targets_in_reach(weapon_index: int) -> Array[Zombie]:
	var found: Array[Zombie] = []
	var def := Weapons.def(weapon_index)
	var reach: float = def["reach"]
	var half_arc := deg_to_rad(float(def["arc"]) * 0.5)
	var origin := _player.global_position
	var forward := facing()
	for node in get_tree().get_nodes_in_group(&"zombie"):
		var zombie := node as Zombie
		if zombie == null or zombie.health == null or zombie.health.is_dead():
			continue
		var offset := zombie.global_position - origin
		var flat := Vector3(offset.x, 0.0, offset.z)
		if absf(offset.y) > 1.6 or flat.length() > reach:
			continue
		if flat.length() > 0.05 and forward.angle_to(flat.normalized()) > half_arc:
			continue
		if not zombie.has_line_of_sight(_player):
			continue
		found.append(zombie)
	return found


## The pistol: an instant shot along the flat aim line at chest height (the way the camera looks). A zombie within 4 degrees of the line and in the clear
## counts as hit (a little aim help: shooting up or down a slope would otherwise miss). The shot stops at the first wall. Leaves a tracer, a muzzle flash and a
## spark where it ended. `last_shot` holds what the shot did, for tests.
func _shoot() -> void:
	var def := Weapons.def(_swing_index)
	var range_m: float = def["reach"]
	var forward := facing()
	var origin := _player.global_position + Vector3.UP * 1.15 + forward * 0.5
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * range_m)
	query.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(query)
	var wall_distance := range_m
	var target: Zombie = null
	if not hit.is_empty():
		wall_distance = origin.distance_to(hit["position"])
		target = _zombie_of(hit["collider"])
	if target == null:
		var best := 4.0
		for node in get_tree().get_nodes_in_group(&"zombie"):
			var zombie := node as Zombie
			if zombie == null or zombie.health == null or zombie.health.is_dead():
				continue
			var offset := zombie.global_position + Vector3.UP * 1.0 - origin
			var flat := Vector3(offset.x, 0.0, offset.z)
			if flat.length() > wall_distance or flat.length() < 0.2:
				continue
			var angle := rad_to_deg(forward.angle_to(flat.normalized()))
			if angle < best:
				var aim_query := PhysicsRayQueryParameters3D.create(origin, zombie.global_position + Vector3.UP * 1.0)
				aim_query.exclude = [_player.get_rid()]
				var aim_hit := space.intersect_ray(aim_query)
				if aim_hit.is_empty() or _zombie_of(aim_hit["collider"]) == zombie:
					best = angle
					target = zombie
	var end := origin + forward * wall_distance
	if target != null:
		end = target.global_position + Vector3.UP * 1.1
		hits_landed += 1
		target.take_hit(float(def["damage"]), _player.global_position, float(def["knockback"]))
	last_shot = {"target": target, "end": end, "distance": origin.distance_to(end), "wall_distance": wall_distance}
	_show_shot(origin, end, target != null)
	shot.emit(target, end)


func _zombie_of(node: Object) -> Zombie:
	var current := node as Node
	while current != null:
		if current is Zombie:
			return current as Zombie
		current = current.get_parent()
	return null


## The tracer (a thin bright bar from the muzzle to where the shot ended), the muzzle flash and a spark, all gone in 0.08 s. No lights: smoothness first.
func _show_shot(from: Vector3, to: Vector3, hit_something: bool) -> void:
	var world := _player.get_parent()
	if world == null:
		return
	var holder := Node3D.new()
	holder.name = "ShotEffect"
	holder.add_to_group(&"shot_effect")
	world.add_child(holder)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.92, 0.55)
	var tracer := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.025, 0.025, from.distance_to(to))
	tracer.mesh = bar
	tracer.material_override = material
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	if from.distance_to(to) > 0.01:
		tracer.look_at(to, Vector3.UP)
	var flash := MeshInstance3D.new()
	var burst := SphereMesh.new()
	burst.radius = 0.11
	burst.height = 0.22
	flash.mesh = burst
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(flash)
	flash.global_position = from
	var spark := MeshInstance3D.new()
	var chip := BoxMesh.new()
	chip.size = Vector3.ONE * (0.2 if hit_something else 0.12)
	spark.mesh = chip
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color(1.0, 0.4, 0.25) if hit_something else Color(0.8, 0.8, 0.8)
	spark.material_override = spark_material
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(spark)
	spark.global_position = to
	get_tree().create_timer(0.08).timeout.connect(holder.queue_free)


func _land_hits() -> void:
	var def := Weapons.def(_swing_index)
	for zombie in targets_in_reach(_swing_index):
		hits_landed += 1
		zombie.take_hit(float(def["damage"]), _player.global_position, float(def["knockback"]))


func _update_cooldown_sweep() -> void:
	var hud := _player.get_node_or_null("HUD") as InteractionPrompt if _player != null else null
	if hud != null:
		var total := float(weapon()["cooldown"])
		hud.set_cooldown(cooldown_left / total if total > 0.0 else 0.0)


func _equip_model() -> void:
	if _model == null:
		return
	if _weapon_node != null and is_instance_valid(_weapon_node):
		_weapon_node.queue_free()
	_weapon_node = null
	_weapon_node = Weapons.build(selected) if selected >= 0 else null
	_model.hold_weapon(_weapon_node, String(Weapons.def(selected)["hold"]))
	_model.set_aim(Weapons.is_gun(selected))


func _refresh_hud() -> void:
	var hud := _player.get_node_or_null("HUD") as InteractionPrompt if _player != null else null
	if hud != null:
		hud.set_hotbar(selected, unlocked)
