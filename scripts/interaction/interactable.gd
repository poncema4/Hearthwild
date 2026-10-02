@tool
class_name Interactable
extends Node3D
## Anything the player can use with the interact key (E): a door, a notice
## board, later a chest, an NPC, a bed.
##
## The node's own position is the spot the player must be near (`interact_range`
## metres, measured on the ground plane) and facing. Subclasses override
## `get_prompt()`, `can_interact()` and `interact()`. A non-empty `message` is
## shown on screen after the interaction (the notice board uses that).

signal interacted(who: Node3D)

@export var prompt_text := "Use"
@export var interact_range := 2.2
@export_multiline var message := ""


func _ready() -> void:
	add_to_group(&"interactable")


## What the on-screen prompt says right now, e.g. "Open door".
func get_prompt() -> String:
	return prompt_text


## False hides the prompt and ignores the key (e.g. a door that is mid-swing).
func can_interact(_who: Node3D) -> bool:
	return true


func interact(who: Node3D) -> void:
	interacted.emit(who)
