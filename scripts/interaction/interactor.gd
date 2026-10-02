class_name Interactor
extends Node3D
## Lives on the player. Every physics frame it picks the best `Interactable`
## (close enough, in front of the character, and willing), shows its prompt on
## the HUD, and uses it when the interact key (E) is pressed.
##
## "In front" means within `cone_degrees` of the direction the character body
## faces, so the player has to turn toward a door to open it, not just stand
## near it.

signal target_changed(target: Interactable)

@export var cone_degrees := 80.0

var current_target: Interactable

@onready var _player: Node3D = get_parent()
@onready var _body: Node3D = get_parent().get_node("Body")
@onready var _hud: InteractionPrompt = get_parent().get_node_or_null("HUD")


func _physics_process(_delta: float) -> void:
	var best := find_target()
	if best != current_target:
		current_target = best
		target_changed.emit(best)
	if _hud:
		_hud.set_prompt(current_target.get_prompt() if current_target else "")
	if (_player as PlayerController).wants_interact():
		try_interact()


## The nearest usable thing in front of the character, or null.
func find_target() -> Interactable:
	var forward := -_body.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Interactable = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var item := node as Interactable
		if item == null or not item.is_visible_in_tree() or not item.can_interact(_player):
			continue
		var offset := item.global_position - _player.global_position
		if absf(offset.y) > 2.5:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance > item.interact_range:
			continue
		if distance > 0.5 and rad_to_deg(forward.angle_to(offset.normalized())) > cone_degrees:
			continue
		if distance < best_distance:
			best = item
			best_distance = distance
	return best


## Uses the current target (what the E key does). False if there is none.
func try_interact() -> bool:
	if current_target == null:
		return false
	var target := current_target
	target.interact(_player)
	if target.message != "" and _hud:
		_hud.show_message(target.message)
	return true
