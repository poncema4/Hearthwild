class_name DayNight
extends Node3D
## The world clock and the light that follows it: a sun that crosses the sky, a
## moon at night, sky/fog colours with orange dusk and dawn, dimmer ambient light,
## and lamps that switch on after dark.
##
## One in-game day lasts `day_length_seconds` of real time (20 minutes by default, like Minecraft: about 10 of them are night).
## Hour 0 is midnight, 12 is noon; the sun rises at 6 and sets at 18. The clock
## runs on the physics tick, so it is deterministic in tests.
##
## The lake joins the `water` group (MeshInstance3D with the water ShaderMaterial): its `daylight` and
## `sky_tint` shader parameters follow the clock.
##
## Zombies (a later step) listen to `night_started` / `day_started`. Anything that
## should glow at night joins the `night_light` group (Light3D nodes: the energy
## is set here, 0 by day).
##
## Tests and screenshot scripts set `paused = true` and `set_time(hour)` so the
## light never drifts under them (a running clock changes every pixel).

signal night_started
signal day_started

const DEFAULT_DAY_LENGTH := 1200.0

@export var day_length_seconds: float = DEFAULT_DAY_LENGTH
@export_range(0.0, 24.0) var start_hour: float = 10.0
@export var paused: bool = false
@export var sun_path: NodePath = ^"../Sun"
@export var environment_path: NodePath = ^"../WorldEnvironment"

const SKY_TOP_DAY := Color(0.30, 0.52, 0.85)
const SKY_TOP_NIGHT := Color(0.015, 0.025, 0.09)
const SKY_HORIZON_DAY := Color(0.84, 0.87, 0.90)
const SKY_HORIZON_NIGHT := Color(0.05, 0.07, 0.15)
const GROUND_DAY := Color(0.30, 0.40, 0.28)
const GROUND_NIGHT := Color(0.02, 0.03, 0.04)
const DUSK_ORANGE := Color(0.96, 0.52, 0.30)
const DUSK_TOP := Color(0.34, 0.26, 0.52)
const SUN_NOON := Color(1.0, 0.92, 0.78)
const SUN_LOW := Color(1.0, 0.52, 0.28)
const MOON_COLOR := Color(0.55, 0.66, 1.0)
const SUN_ENERGY := 1.2
const MOON_ENERGY := 0.28
const AMBIENT_DAY := 1.25
const AMBIENT_NIGHT := 1.1
## At night the ambient light is partly a fixed cool blue instead of the (nearly black) sky:
## without it a character with their back to the moon was pure black.
const NIGHT_AMBIENT_COLOR := Color(0.22, 0.30, 0.55)
const NIGHT_SKY_SHARE := 0.5
const LAMP_ENERGY := 2.6

var hour: float = 10.0

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _was_night := false
var _applied_hour := -1.0


func _ready() -> void:
	add_to_group(&"day_night")
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var world_environment := get_node_or_null(environment_path) as WorldEnvironment
	if world_environment:
		_environment = world_environment.environment
		_sky = _environment.sky.sky_material as ProceduralSkyMaterial
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.light_color = MOON_COLOR
	_moon.shadow_enabled = true
	_moon.shadow_blur = 2.0
	_moon.shadow_opacity = 0.5
	_moon.directional_shadow_max_distance = 80.0
	add_child(_moon)
	hour = start_hour
	_apply()
	_was_night = is_night()
	# The village builds its lamps AFTER this node is ready: light them once everything exists
	# (otherwise a world that starts at night, or paused, has dark lamps until the clock moves).
	_apply.call_deferred()


func _physics_process(delta: float) -> void:
	if not paused:
		# Re-light only when the clock has moved a visible amount (about every 4th tick): the sky
		# and environment are not free to rewrite 60 times a second.
		var next_hour := fposmod(hour + delta * 24.0 / day_length_seconds, 24.0)
		if absf(next_hour - _applied_hour) >= 0.002 or next_hour < _applied_hour:
			set_time(next_hour)
		else:
			hour = next_hour


## Jumps the clock to `new_hour` (0-24, wraps) and updates all the light.
func set_time(new_hour: float) -> void:
	hour = fposmod(new_hour, 24.0)
	_apply()
	var night := is_night()
	if night != _was_night:
		_was_night = night
		if night:
			night_started.emit()
		else:
			day_started.emit()


## How high the sun is: 1 at noon, 0 at sunrise and sunset, -1 at midnight.
func sun_elevation() -> float:
	return sin((hour - 6.0) / 24.0 * TAU)


## 1 in full daylight, 0 in the dead of night, smooth through dawn and dusk.
func daylight() -> float:
	return smoothstep(-0.12, 0.25, sun_elevation())


func night_amount() -> float:
	return 1.0 - daylight()


func is_night() -> bool:
	return night_amount() > 0.5


## "9:05 AM" style text for the HUD clock.
func clock_text() -> String:
	var total_minutes := int(hour * 60.0 + 0.0001)  # 7.1 h is 425.99999 minutes, not 7:05
	var h24 := total_minutes / 60
	var minutes := total_minutes % 60
	var h12 := h24 % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minutes, "AM" if h24 < 12 else "PM"]


func _apply() -> void:
	if _moon == null:
		return
	_applied_hour = hour
	var angle := (hour - 6.0) / 24.0 * TAU
	var toward_sun := Vector3(cos(angle) * 0.85, sin(angle), 0.5).normalized()
	var elevation := sun_elevation()
	var day := daylight()
	var night := 1.0 - day
	var low := 1.0 - clampf(elevation * 3.0, 0.0, 1.0)  # 1 near the horizon, 0 high up

	if _sun:
		_sun.global_transform.basis = Basis.looking_at(-toward_sun, Vector3.UP)
		_sun.light_energy = SUN_ENERGY * day * clampf(elevation * 4.0, 0.0, 1.0)
		_sun.light_color = SUN_NOON.lerp(SUN_LOW, low)
		_sun.visible = _sun.light_energy > 0.01
	_moon.global_transform.basis = Basis.looking_at(toward_sun, Vector3.UP)  # the moon sits opposite the sun
	_moon.light_energy = MOON_ENERGY * night * clampf(-elevation * 4.0, 0.0, 1.0)
	_moon.visible = _moon.light_energy > 0.01

	var dusk := exp(-pow(elevation / 0.2, 2.0))  # peaks when the sun is on the horizon
	var horizon := SKY_HORIZON_DAY.lerp(SKY_HORIZON_NIGHT, night).lerp(DUSK_ORANGE, dusk * 0.65)
	var top := SKY_TOP_DAY.lerp(SKY_TOP_NIGHT, night).lerp(DUSK_TOP, dusk * 0.35)
	if _sky:
		_sky.sky_top_color = top
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sky.ground_bottom_color = GROUND_DAY.lerp(GROUND_NIGHT, night)
	if _environment:
		_environment.ambient_light_energy = lerpf(AMBIENT_DAY, AMBIENT_NIGHT, night)
		_environment.ambient_light_color = NIGHT_AMBIENT_COLOR
		_environment.ambient_light_sky_contribution = lerpf(1.0, NIGHT_SKY_SHARE, night)
		_environment.fog_light_color = horizon
		_environment.glow_intensity = lerpf(0.45, 0.8, night)

	# The lake: dark at night, reflecting the horizon colour (the shader has no light of its own to dim).
	for water in get_tree().get_nodes_in_group(&"water") if is_inside_tree() else []:
		var water_material := (water as MeshInstance3D).material_override as ShaderMaterial
		if water_material:
			water_material.set_shader_parameter("daylight", day)
			water_material.set_shader_parameter("sky_tint", horizon)

	for lamp in get_tree().get_nodes_in_group(&"night_light") if is_inside_tree() else []:
		(lamp as Light3D).light_energy = LAMP_ENERGY * night
		(lamp as Light3D).visible = night > 0.02
