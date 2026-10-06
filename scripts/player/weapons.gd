class_name Weapons
extends RefCounted
## The weapons: their numbers and the blocky model each one is drawn with. Pure data plus a model builder, so the numbers can be tested without
## swinging anything. Zombies have 20 hp: the wooden sword takes 4 hits, the stone sword and the spear 3, the axe 2 (but it is slow).
##
## reach  = how far in front of the player (m) a hit can land, measured from the player's centre to the zombie's centre
## arc    = the width (degrees) of the cone in front that a swing covers
## swing  = how long the swing takes (s); the hit lands at HIT_FRACTION of it
## cooldown = the earliest next swing (s after the start of this one)

## The hit lands at this fraction of the swing: for a slash that is when the arm passes in front of the body on the way down (the angle curve in
## AnimalModel.swing_arm_angle crosses 'straight forward' at 0.7), for a punch the fist is still well out at 0.7.
const HIT_FRACTION := 0.7

## Bare hands: what you fight with when nothing is equipped (press F or click).
const FISTS := {"id": "fists", "hold": "none", "anim": "punch", "name": "Fists", "kind": "melee", "damage": 2.0, "reach": 1.7, "arc": 90.0, "swing": 0.22, "cooldown": 0.32, "knockback": 2.5}

const DEFS := [
	{"id": "wooden_sword", "hold": "blade", "anim": "slash", "kind": "melee", "name": "Wooden Sword", "damage": 6.0, "reach": 2.3, "arc": 110.0, "swing": 0.28, "cooldown": 0.45, "knockback": 4.0},
	{"id": "stone_sword", "hold": "blade", "anim": "slash", "kind": "melee", "name": "Stone Sword", "damage": 9.0, "reach": 2.5, "arc": 110.0, "swing": 0.30, "cooldown": 0.55, "knockback": 5.0},
	{"id": "spear", "hold": "point", "anim": "thrust", "kind": "melee", "name": "Spear", "damage": 7.0, "reach": 3.6, "arc": 36.0, "swing": 0.30, "cooldown": 0.70, "knockback": 6.0},
	{"id": "axe", "hold": "blade", "anim": "slash", "kind": "melee", "name": "Axe", "damage": 14.0, "reach": 2.2, "arc": 130.0, "swing": 0.40, "cooldown": 1.0, "knockback": 7.5},
	## The pistol: an instant shot along the aim line (`reach` is its range in metres, `swing` the recoil kick).
	{"id": "pistol", "hold": "point", "anim": "recoil", "kind": "gun", "name": "Pistol", "damage": 10.0, "reach": 45.0, "arc": 0.0, "swing": 0.14, "cooldown": 0.35, "knockback": 3.0},
]
## How many weapons a new player has unlocked (the first one); the weapon rack gives the rest.
const STARTING := 1


static func count() -> int:
	return DEFS.size()


## The weapon at hotbar slot `index` (0 based); -1 (nothing equipped) is the fists.
static func def(index: int) -> Dictionary:
	if index < 0:
		return FISTS
	return DEFS[clampi(index, 0, DEFS.size() - 1)]


static func is_gun(index: int) -> bool:
	return String(def(index)["kind"]) == "gun"


## The weapon's model. Its origin is the grip; the blade points along -Y of the node (down the arm when the arm hangs).
static func build(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon"
	var steel := Color(0.78, 0.80, 0.84)
	var wood := Color(0.55, 0.38, 0.24)
	var stone := Color(0.60, 0.60, 0.62)
	match String(def(index)["id"]):
		"wooden_sword":
			_part(root, Vector3(0.07, 0.62, 0.025), Vector3(0, -0.40, 0), wood)
			_part(root, Vector3(0.24, 0.05, 0.05), Vector3(0, -0.08, 0), Color(0.40, 0.28, 0.18))
		"stone_sword":
			_part(root, Vector3(0.08, 0.70, 0.025), Vector3(0, -0.45, 0), stone)
			_part(root, Vector3(0.26, 0.05, 0.05), Vector3(0, -0.08, 0), wood)
			_part(root, Vector3(0.05, 0.12, 0.04), Vector3(0, 0.05, 0), wood)
		"spear":
			_part(root, Vector3(0.04, 1.5, 0.04), Vector3(0, -0.55, 0), wood)
			_part(root, Vector3(0.10, 0.24, 0.03), Vector3(0, -1.40, 0), steel)
		"axe":
			_part(root, Vector3(0.05, 0.85, 0.05), Vector3(0, -0.38, 0), wood)
			_part(root, Vector3(0.30, 0.22, 0.05), Vector3(0.10, -0.72, 0), steel)
		"pistol":
			_part(root, Vector3(0.07, 0.30, 0.08), Vector3(0, -0.22, 0), Color(0.25, 0.26, 0.30))  # the barrel and slide, pointing along the blade axis
			_part(root, Vector3(0.06, 0.16, 0.07), Vector3(0, -0.04, 0.09), Color(0.35, 0.24, 0.16))  # the grip
			_part(root, Vector3(0.025, 0.04, 0.025), Vector3(0, -0.37, -0.03), Color(0.9, 0.9, 0.95))  # the front sight
	return root


static func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.emission_enabled = true  # weapons glow a little in their own colour so they are readable at night (a black sword was invisible)
	material.emission = color
	material.emission_energy_multiplier = 0.55
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
