class_name DamageNumbers
extends RefCounted
## The number that pops out of anything that takes damage or is healed: "-6" in yellow over a zombie, "-8" in red over the player, "-1" in orange for
## fire, "+30" in green for healing. It floats up and fades in 0.7 s. Health makes these itself (one place, so EVERY kind of damage and healing on every
## owner shows one), and a Label3D lives in the world, not on the owner (the owner may be freed by the very hit that made it).

const HIT := Color(1.0, 0.85, 0.3)
const PLAYER_HIT := Color(1.0, 0.32, 0.32)
const FIRE := Color(1.0, 0.5, 0.15)
const HEAL := Color(0.45, 0.95, 0.45)
const LIFETIME := 1.0
const HOLD := 0.45  ## the number stays fully visible this long, then fades


## Pops `text` over `entity` in `color`. Returns the label (tests read it), or null when the entity is not in the world.
static func pop(entity: Node3D, text: String, color: Color) -> Label3D:
	if entity == null or not entity.is_inside_tree() or entity.get_parent() == null:
		return null
	var label := Label3D.new()
	label.text = text
	label.font_size = 80
	label.outline_size = 22
	label.outline_modulate = Color(0.05, 0.03, 0.02, 1.0)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0075
	label.shaded = false
	label.double_sided = true
	label.add_to_group(&"damage_number")
	entity.get_parent().add_child(label)
	label.global_position = entity.global_position + Vector3(randf_range(-0.6, 0.6), 2.3 + randf_range(0.0, 0.5), randf_range(-0.1, 0.1))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.2, LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME - HOLD).set_delay(HOLD)
	tween.chain().tween_callback(label.queue_free)
	return label


## "-6" for damage, "+30" for healing (never "-0": a tiny amount shows as 1).
static func text_for(amount: float, healing: bool) -> String:
	return "%s%d" % ["+" if healing else "-", maxi(int(round(amount)), 1)]
