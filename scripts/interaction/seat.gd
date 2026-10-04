@tool
class_name Seat
extends Interactable
## Somewhere to sit: every bench has one. Press E facing it to sit (the character settles onto the seat, legs
## forward, hands in the lap); press E, Space or any movement key (a fresh press, not a held key) to stand up
## in front of the bench. One sitter per seat. While seated the player has no collision and does not move.
##
## The seat node itself is the interact point (in front of the bench); `sit_point()` and `stand_point()` are
## measured from the bench it belongs to (this node's parent: origin on the ground, front facing local +Z).

signal sat_down(who: Node3D)
signal stood_up(who: Node3D)

## Where the sitter's origin goes, in the bench's own space (on the ground; the character's hips are at seat height).
const SIT_OFFSET := Vector3(0.0, 0.0, 0.16)
## Where the sitter stands when they get up: in front of the bench, clear of its legs.
const STAND_OFFSET := Vector3(0.0, 0.0, 1.15)

var occupant: PlayerController


func _init() -> void:
	prompt_text = "Sit down"
	interact_range = 1.9


func get_prompt() -> String:
	return "Sit down"


func can_interact(who: Node3D) -> bool:
	var player := who as PlayerController
	return occupant == null and player != null and player.seat == null


func interact(who: Node3D) -> void:
	var player := who as PlayerController
	if player == null or not can_interact(who):
		return
	occupant = player
	player.seat = self
	player.global_position = sit_point()
	(player.get_node("Body") as Node3D).rotation.y = atan2(-front().x, -front().z)  # face the way the bench faces
	var model := player.get_node_or_null("Body/Model") as AnimalModel
	if model:
		model.set_seated(true)
	var hud := player.get_node_or_null("HUD") as InteractionPrompt
	if hud:
		hud.show_message("Press E, Space or a move key to stand up", 3.5)
	sat_down.emit(player)
	super.interact(who)


## Gets the sitter up and puts them in front of the bench.
func stand_up(who: PlayerController) -> void:
	if occupant != who:
		return
	occupant = null
	who.seat = null
	who.global_position = stand_point()
	var model := who.get_node_or_null("Body/Model") as AnimalModel
	if model:
		model.set_seated(false, true)
	stood_up.emit(who)


func sit_point() -> Vector3:
	return get_parent().to_global(SIT_OFFSET)


func stand_point() -> Vector3:
	return get_parent().to_global(STAND_OFFSET)


## The world direction the bench faces (the way the sitter looks).
func front() -> Vector3:
	var forward: Vector3 = get_parent().global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


func _exit_tree() -> void:
	# A bench that disappears must not leave anyone stuck in the air with no collision.
	if occupant != null and is_instance_valid(occupant):
		occupant.seat = null
		var model := occupant.get_node_or_null("Body/Model") as AnimalModel
		if model:
			model.set_seated(false)
		occupant = null
