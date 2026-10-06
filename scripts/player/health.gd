class_name Health
extends Node
## Hit points for anything that can be hurt: the player now, zombies and animals later. Add it as a child
## node named "Health" and listen to its signals; nothing here knows what hurt the owner or what dying
## means (that is the owner's job: the zombie despawns, the player wakes at a bed).
##
## All changes go through damage(), heal(), revive() and set_max(), so a bad number (negative, NaN, infinite) can
## never corrupt the value, and `died` fires exactly once per life. Change the maximum AFTER the node is ready
## (armor, level-ups) with set_max(), never by assigning max_health: set_max() keeps `current` inside the new
## maximum and emits `changed`, so the HP bar follows.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

## Every damage and heal pops a number over the owner (see DamageNumbers). Fire comes in many tiny ticks, so it is added up and shown twice a second.
@export var show_numbers := true
const FIRE_NUMBER_INTERVAL := 0.5
var _fire_pending := 0.0
var _fire_age := 0.0

@export var max_health: float = 100.0

var current: float = 0.0
var _dead := false


func _ready() -> void:
	set_physics_process(false)
	if not is_finite(max_health):
		max_health = 100.0
	max_health = maxf(max_health, 1.0)
	current = max_health


## Takes hit points away. Returns how much was really taken (0 for a dead owner or a bad number).
func damage(amount: float, kind: StringName = &"hit") -> float:
	if _dead or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var taken := minf(amount, current)
	current -= taken
	damaged.emit(taken)
	_show_number(taken, kind)
	changed.emit(current, max_health)
	if current <= 0.0:
		_dead = true
		died.emit()
	return taken


## Gives hit points back, never above the maximum. Returns how much was really given (0 when dead).
func heal(amount: float) -> float:
	if _dead or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var given := minf(amount, max_health - current)
	if given <= 0.0:
		return 0.0
	current += given
	healed.emit(given)
	_show_number(given, &"heal")
	changed.emit(current, max_health)
	return given


## Changes the maximum (at least 1; NaN and infinity are ignored). A living owner's hit points are cut down to
## the new maximum when it is lower, and `changed` is emitted either way.
func set_max(value: float) -> void:
	if not is_finite(value):
		return
	max_health = maxf(value, 1.0)
	if not _dead:
		current = minf(current, max_health)
	changed.emit(current, max_health)


## Brings a dead owner back with full hit points (a respawn). Does nothing to a living one.
func revive() -> void:
	if not _dead:
		return
	_dead = false
	current = max_health
	changed.emit(current, max_health)


func is_dead() -> bool:
	return _dead


## 0.0 (dead) to 1.0 (full).
func fraction() -> float:
	return clampf(current / max_health, 0.0, 1.0)


func _show_number(amount: float, kind: StringName) -> void:
	if not show_numbers or amount <= 0.0:
		return
	if kind == &"fire":
		_fire_pending += amount
		set_physics_process(true)
		return
	var owner_node := get_parent() as Node3D
	if owner_node == null:
		return
	if kind == &"heal":
		DamageNumbers.pop(owner_node, DamageNumbers.text_for(amount, true), DamageNumbers.HEAL)
	else:
		DamageNumbers.pop(owner_node, DamageNumbers.text_for(amount, false), DamageNumbers.PLAYER_HIT if owner_node.is_in_group(&"player") else DamageNumbers.HIT)


func _physics_process(delta: float) -> void:
	if _fire_pending <= 0.0:
		set_physics_process(false)
		return
	_fire_age += delta
	if _fire_age >= FIRE_NUMBER_INTERVAL or _dead:
		var owner_node := get_parent() as Node3D
		if owner_node != null:
			DamageNumbers.pop(owner_node, DamageNumbers.text_for(_fire_pending, false), DamageNumbers.FIRE)
		_fire_pending = 0.0
		_fire_age = 0.0
