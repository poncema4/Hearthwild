@tool
class_name Outfits
extends RefCounted
## The wardrobe: every wearable item, its slot and label, and a builder for each. `make()`
## returns a fresh Node3D to give to `AnimalModel.equip(slot, item)`, or just call
## `AnimalModel.equip_item(id)`. Items are simple shapes in the socket's own space:
## `head_top` = top of the head, `face` = front of the face, `neck` = top of the torso,
## `torso` = middle of the torso, `back` = behind the torso.
##
## Adding an item = one row in `CATALOG` and one builder here (the tests loop over the
## catalog, so a new item is checked automatically). Real art comes later.

## [id, slot, label]
const CATALOG: Array = [
	[&"red_cap", &"head_top", "Red cap"],
	[&"straw_hat", &"head_top", "Straw hat"],
	[&"round_glasses", &"face", "Round glasses"],
	[&"blue_scarf", &"neck", "Blue scarf"],
	[&"bow_tie", &"neck", "Bow tie"],
	[&"mint_sweater", &"torso", "Mint sweater"],
	[&"explorer_pack", &"back", "Explorer pack"],
	# Added with the wardrobe update: new items always go AFTER the originals in each slot (saves use ids; the picker and tests use the order).
	[&"flower_crown", &"head_top", "Flower crown"],
	[&"wizard_hat", &"head_top", "Wizard hat"],
	[&"party_hat", &"head_top", "Party hat"],
	[&"gold_crown", &"head_top", "Gold crown"],
	[&"orange_beanie", &"head_top", "Orange beanie"],
	[&"sunglasses", &"face", "Sunglasses"],
	[&"heart_glasses", &"face", "Heart glasses"],
	[&"curly_moustache", &"face", "Curly moustache"],
	[&"flower_lei", &"neck", "Flower lei"],
	[&"gold_necklace", &"neck", "Gold necklace"],
	[&"red_bandana", &"neck", "Red bandana"],
	[&"sunny_dress", &"torso", "Sunny dress"],
	[&"denim_overalls", &"torso", "Denim overalls"],
	[&"red_hoodie", &"torso", "Red hoodie"],
	[&"striped_tee", &"torso", "Striped tee"],
	[&"angel_wings", &"back", "Angel wings"],
	[&"red_cape", &"back", "Red cape"],
	[&"butterfly_wings", &"back", "Butterfly wings"],
]

const SLOTS: Array[StringName] = [&"head_top", &"face", &"neck", &"torso", &"back"]
const SLOT_LABELS := {&"head_top": "Hat", &"face": "Glasses", &"neck": "Neck", &"torso": "Top", &"back": "Back"}


## The slot an item belongs on ("" if unknown).
static func slot_of(item_id: StringName) -> StringName:
	for row in CATALOG:
		if row[0] == item_id:
			return row[1]
	return &""


static func label_of(item_id: StringName) -> String:
	for row in CATALOG:
		if row[0] == item_id:
			return row[2]
	return ""


## All item ids for a slot, in catalog order.
static func items_for_slot(slot: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for row in CATALOG:
		if row[1] == slot:
			found.append(row[0])
	return found


static func make(item_id: StringName) -> Node3D:
	match item_id:
		&"red_cap":
			return _red_cap()
		&"straw_hat":
			return _straw_hat()
		&"round_glasses":
			return _round_glasses()
		&"blue_scarf":
			return _blue_scarf()
		&"bow_tie":
			return _bow_tie()
		&"mint_sweater":
			return _mint_sweater()
		&"explorer_pack":
			return _explorer_pack()
		&"flower_crown":
			return _flower_crown()
		&"wizard_hat":
			return _wizard_hat()
		&"party_hat":
			return _party_hat()
		&"gold_crown":
			return _gold_crown()
		&"orange_beanie":
			return _orange_beanie()
		&"sunglasses":
			return _sunglasses()
		&"heart_glasses":
			return _heart_glasses()
		&"curly_moustache":
			return _curly_moustache()
		&"flower_lei":
			return _flower_lei()
		&"gold_necklace":
			return _gold_necklace()
		&"red_bandana":
			return _red_bandana()
		&"sunny_dress":
			return _sunny_dress()
		&"denim_overalls":
			return _denim_overalls()
		&"red_hoodie":
			return _red_hoodie()
		&"striped_tee":
			return _striped_tee()
		&"angel_wings":
			return _angel_wings()
		&"red_cape":
			return _red_cape()
		&"butterfly_wings":
			return _butterfly_wings()
	push_warning("Outfits: unknown item %s" % item_id)
	return Node3D.new()


static func _red_cap() -> Node3D:
	var root := Node3D.new()
	root.name = "RedCap"
	var red := Color(0.86, 0.18, 0.2)
	var dome := SphereMesh.new()
	dome.radius = 0.33
	dome.height = 0.33  # a hemisphere's height must equal its radius (twice that stretches it into a gnome hat)
	dome.is_hemisphere = true
	_mesh(root, "Dome", dome, Vector3(0, -0.1, 0.0), red, Vector3(1.05, 0.7, 1.05))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.2
	brim.bottom_radius = 0.2
	brim.height = 0.025
	_mesh(root, "Brim", brim, Vector3(0, -0.07, -0.33), red.darkened(0.15), Vector3(1.0, 1.0, 0.8), Vector3(deg_to_rad(-10), 0, 0))
	var button := SphereMesh.new()
	button.radius = 0.035
	button.height = 0.07
	_mesh(root, "Button", button, Vector3(0, 0.15, 0), Color(1.0, 0.9, 0.7))
	return root


static func _straw_hat() -> Node3D:
	var root := Node3D.new()
	root.name = "StrawHat"
	var straw := Color(0.92, 0.80, 0.47)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.48
	brim.bottom_radius = 0.48
	brim.height = 0.03
	_mesh(root, "Brim", brim, Vector3(0, -0.04, 0), straw)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.24
	crown.bottom_radius = 0.28
	crown.height = 0.2
	_mesh(root, "Crown", crown, Vector3(0, 0.06, 0), straw.darkened(0.05))
	var band := CylinderMesh.new()
	band.top_radius = 0.285
	band.bottom_radius = 0.285
	band.height = 0.05
	_mesh(root, "Band", band, Vector3(0, 0.0, 0), Color(0.78, 0.2, 0.22))
	return root


static func _round_glasses() -> Node3D:
	var root := Node3D.new()
	root.name = "RoundGlasses"
	var frame := Color(0.18, 0.14, 0.12)
	for side in [-1.0, 1.0]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.065
		ring.outer_radius = 0.095
		_mesh(root, "Rim", ring, Vector3(side * 0.15, 0.0, -0.045), frame, Vector3.ONE, Vector3(deg_to_rad(90), 0, 0))
		var lens := CylinderMesh.new()
		lens.top_radius = 0.07
		lens.bottom_radius = 0.07
		lens.height = 0.01
		_mesh(root, "Lens", lens, Vector3(side * 0.15, 0.0, -0.045), Color(0.8, 0.92, 1.0), Vector3.ONE, Vector3(deg_to_rad(90), 0, 0))
	var bridge := BoxMesh.new()
	bridge.size = Vector3(0.09, 0.018, 0.018)
	_mesh(root, "Bridge", bridge, Vector3(0, 0.02, -0.045), frame)
	return root


static func _blue_scarf() -> Node3D:
	var root := Node3D.new()
	root.name = "BlueScarf"
	var blue := Color(0.22, 0.42, 0.85)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.32
	_mesh(root, "Wrap", ring, Vector3(0, -0.02, 0), blue, Vector3(1.0, 1.4, 1.0))
	var tail := BoxMesh.new()
	tail.size = Vector3(0.14, 0.34, 0.05)
	_mesh(root, "Tail", tail, Vector3(0.1, -0.2, -0.27), blue.lightened(0.15), Vector3.ONE, Vector3(0, 0, deg_to_rad(8)))
	return root


static func _bow_tie() -> Node3D:
	var root := Node3D.new()
	root.name = "BowTie"
	var pink := Color(0.92, 0.28, 0.45)
	for side in [-1.0, 1.0]:
		var wing := BoxMesh.new()
		wing.size = Vector3(0.14, 0.12, 0.05)
		_mesh(root, "Wing", wing, Vector3(side * 0.09, -0.03, -0.27), pink, Vector3.ONE, Vector3(0, 0, side * deg_to_rad(-10)))
	var knot := SphereMesh.new()
	knot.radius = 0.04
	knot.height = 0.08
	_mesh(root, "Knot", knot, Vector3(0, -0.03, -0.27), pink.darkened(0.2))
	return root


static func _mint_sweater() -> Node3D:
	var root := Node3D.new()
	root.name = "MintSweater"
	var shell := CapsuleMesh.new()
	shell.radius = 0.30
	shell.height = 0.62
	_mesh(root, "Shell", shell, Vector3(0, 0.0, 0.0), Color(0.45, 0.78, 0.66))
	var stripe := TorusMesh.new()
	stripe.inner_radius = 0.285
	stripe.outer_radius = 0.315
	_mesh(root, "Stripe", stripe, Vector3(0, 0.04, 0.0), Color(0.97, 0.97, 0.9))
	return root


static func _explorer_pack() -> Node3D:
	var root := Node3D.new()
	root.name = "ExplorerPack"
	var brown := Color(0.55, 0.36, 0.22)
	var body := BoxMesh.new()
	body.size = Vector3(0.36, 0.42, 0.17)
	_mesh(root, "Body", body, Vector3(0, 0.0, 0.08), brown)
	var flap := BoxMesh.new()
	flap.size = Vector3(0.37, 0.14, 0.19)
	_mesh(root, "Flap", flap, Vector3(0, 0.15, 0.08), brown.darkened(0.15))
	var roll := CylinderMesh.new()
	roll.top_radius = 0.06
	roll.bottom_radius = 0.06
	roll.height = 0.4
	_mesh(root, "Bedroll", roll, Vector3(0, -0.22, 0.1), Color(0.35, 0.5, 0.7), Vector3.ONE, Vector3(0, 0, deg_to_rad(90)))
	return root


# ---- Wardrobe update: hats (socket head_top: y = 0 is the top of the head, the head is about 0.32 m wide there at y = -0.1) ----

static func _flower_crown() -> Node3D:
	var root := Node3D.new()
	root.name = "FlowerCrown"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.30
	ring.outer_radius = 0.36
	_mesh(root, "Vine", ring, Vector3(0, -0.1, 0), Color(0.33, 0.62, 0.30))
	var colors := [Color(0.97, 0.55, 0.72), Color(1.0, 0.86, 0.3), Color(0.98, 0.98, 0.95), Color(0.72, 0.6, 0.95), Color(1.0, 0.65, 0.35), Color(0.97, 0.55, 0.72), Color(1.0, 0.86, 0.3)]
	for i in colors.size():
		var angle := TAU * float(i) / float(colors.size())
		var flower := SphereMesh.new()
		flower.radius = 0.055
		flower.height = 0.11
		_mesh(root, "Flower%d" % i, flower, Vector3(cos(angle) * 0.33, -0.07, sin(angle) * 0.33), colors[i])
		var heart := SphereMesh.new()
		heart.radius = 0.02
		heart.height = 0.04
		_mesh(root, "Heart%d" % i, heart, Vector3(cos(angle) * 0.33, -0.03, sin(angle) * 0.33), Color(1.0, 0.9, 0.4))
	return root


static func _wizard_hat() -> Node3D:
	var root := Node3D.new()
	root.name = "WizardHat"
	var purple := Color(0.30, 0.18, 0.55)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.46
	brim.bottom_radius = 0.46
	brim.height = 0.03
	_mesh(root, "Brim", brim, Vector3(0, -0.06, 0), purple.darkened(0.1))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.27
	cone.height = 0.62
	_mesh(root, "Cone", cone, Vector3(0.02, 0.25, 0), purple, Vector3.ONE, Vector3(0, 0, deg_to_rad(-6)))
	var band := CylinderMesh.new()
	band.top_radius = 0.285
	band.bottom_radius = 0.29
	band.height = 0.06
	_mesh(root, "Band", band, Vector3(0, -0.02, 0), Color(0.95, 0.8, 0.25))
	var star := SphereMesh.new()
	star.radius = 0.05
	star.height = 0.1
	_mesh(root, "Star", star, Vector3(0, 0.12, -0.2), Color(1.0, 0.9, 0.3))
	return root


static func _party_hat() -> Node3D:
	var root := Node3D.new()
	root.name = "PartyHat"
	var pink := Color(0.95, 0.4, 0.62)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.5
	_mesh(root, "Cone", cone, Vector3(0, 0.17, 0), pink)
	for k in 2:
		var stripe := TorusMesh.new()
		stripe.inner_radius = 0.13 - 0.06 * k
		stripe.outer_radius = 0.16 - 0.06 * k
		_mesh(root, "Stripe%d" % k, stripe, Vector3(0, 0.0 + 0.16 * k, 0), Color(0.98, 0.9, 0.35))
	var pompom := SphereMesh.new()
	pompom.radius = 0.06
	pompom.height = 0.12
	_mesh(root, "Pompom", pompom, Vector3(0, 0.44, 0), Color(0.45, 0.8, 0.95))
	return root


static func _gold_crown() -> Node3D:
	var root := Node3D.new()
	root.name = "GoldCrown"
	var gold := Color(0.97, 0.78, 0.22)
	var band := TorusMesh.new()
	band.inner_radius = 0.28
	band.outer_radius = 0.36
	_mesh(root, "Band", band, Vector3(0, -0.04, 0), gold, Vector3(1.0, 2.4, 1.0))
	for i in 5:
		var angle := TAU * float(i) / 5.0
		var spike := CylinderMesh.new()
		spike.top_radius = 0.0
		spike.bottom_radius = 0.055
		spike.height = 0.17
		_mesh(root, "Spike%d" % i, spike, Vector3(cos(angle) * 0.32, 0.1, sin(angle) * 0.32), gold.lightened(0.1))
		var tip := SphereMesh.new()
		tip.radius = 0.025
		tip.height = 0.05
		_mesh(root, "Pearl%d" % i, tip, Vector3(cos(angle) * 0.32, 0.2, sin(angle) * 0.32), Color(0.98, 0.98, 0.95))
	var gem := SphereMesh.new()
	gem.radius = 0.045
	gem.height = 0.09
	_mesh(root, "Gem", gem, Vector3(0, -0.02, -0.34), Color(0.85, 0.12, 0.2))
	return root


static func _orange_beanie() -> Node3D:
	var root := Node3D.new()
	root.name = "OrangeBeanie"
	var orange := Color(0.95, 0.55, 0.2)
	var dome := SphereMesh.new()
	dome.radius = 0.34
	dome.height = 0.34
	dome.is_hemisphere = true
	_mesh(root, "Dome", dome, Vector3(0, -0.13, 0), orange, Vector3(1.04, 0.85, 1.04))
	var fold := TorusMesh.new()
	fold.inner_radius = 0.29
	fold.outer_radius = 0.37
	_mesh(root, "Fold", fold, Vector3(0, -0.12, 0), orange.darkened(0.2), Vector3(1.0, 1.6, 1.0))
	var pompom := SphereMesh.new()
	pompom.radius = 0.07
	pompom.height = 0.14
	_mesh(root, "Pompom", pompom, Vector3(0, 0.17, 0), Color(0.98, 0.97, 0.94))
	return root


# ---- faces (socket face: the front of the face, z = -0.045 is just in front of the eyes) ----

static func _sunglasses() -> Node3D:
	var root := Node3D.new()
	root.name = "Sunglasses"
	var dark := Color(0.07, 0.07, 0.09)
	for side in [-1.0, 1.0]:
		var lens := BoxMesh.new()
		lens.size = Vector3(0.17, 0.11, 0.025)
		_mesh(root, "Lens", lens, Vector3(side * 0.15, 0.0, -0.045), dark)
		var shine := BoxMesh.new()
		shine.size = Vector3(0.05, 0.015, 0.005)
		_mesh(root, "Shine", shine, Vector3(side * 0.15 - 0.03, 0.03, -0.06), Color(0.7, 0.8, 0.95))
	var bridge := BoxMesh.new()
	bridge.size = Vector3(0.1, 0.02, 0.02)
	_mesh(root, "Bridge", bridge, Vector3(0, 0.03, -0.045), dark)
	return root


static func _heart_glasses() -> Node3D:
	var root := Node3D.new()
	root.name = "HeartGlasses"
	var pink := Color(0.96, 0.3, 0.5)
	for side in [-1.0, 1.0]:
		for lobe in [-1.0, 1.0]:
			var ball := SphereMesh.new()
			ball.radius = 0.052
			ball.height = 0.104
			_mesh(root, "Lobe", ball, Vector3(side * 0.15 + lobe * 0.036, 0.035, -0.045), pink)
		var point := BoxMesh.new()
		point.size = Vector3(0.075, 0.075, 0.03)
		_mesh(root, "Point", point, Vector3(side * 0.15, -0.0, -0.045), pink, Vector3.ONE, Vector3(0, 0, deg_to_rad(45)))
	var bridge := BoxMesh.new()
	bridge.size = Vector3(0.08, 0.016, 0.016)
	_mesh(root, "Bridge", bridge, Vector3(0, 0.035, -0.045), pink.darkened(0.2))
	return root


static func _curly_moustache() -> Node3D:
	var root := Node3D.new()
	root.name = "CurlyMoustache"
	var brown := Color(0.28, 0.17, 0.1)
	for side in [-1.0, 1.0]:
		var wing := SphereMesh.new()
		wing.radius = 0.07
		wing.height = 0.14
		_mesh(root, "Wing", wing, Vector3(side * 0.08, -0.13, -0.045), brown, Vector3(1.5, 0.55, 0.7))
		var curl := TorusMesh.new()
		curl.inner_radius = 0.018
		curl.outer_radius = 0.045
		_mesh(root, "Curl", curl, Vector3(side * 0.19, -0.1, -0.045), brown, Vector3.ONE, Vector3(deg_to_rad(90), 0, 0))
	return root


# ---- necks (socket neck: the top of the torso) ----

static func _flower_lei() -> Node3D:
	var root := Node3D.new()
	root.name = "FlowerLei"
	var colors := [Color(0.97, 0.45, 0.65), Color(1.0, 0.65, 0.25), Color(1.0, 0.88, 0.3), Color(0.98, 0.98, 0.95)]
	var vine := TorusMesh.new()
	vine.inner_radius = 0.255
	vine.outer_radius = 0.285
	_mesh(root, "Vine", vine, Vector3(0, -0.06, 0), Color(0.3, 0.6, 0.28), Vector3(1.0, 1.4, 1.0))
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var bloom := SphereMesh.new()
		bloom.radius = 0.06
		bloom.height = 0.12
		_mesh(root, "Bloom%d" % i, bloom, Vector3(cos(angle) * 0.285, -0.06, sin(angle) * 0.285), colors[i % colors.size()])
	return root


static func _gold_necklace() -> Node3D:
	var root := Node3D.new()
	root.name = "GoldNecklace"
	var gold := Color(0.97, 0.78, 0.22)
	var chain := TorusMesh.new()
	chain.inner_radius = 0.255
	chain.outer_radius = 0.275
	_mesh(root, "Chain", chain, Vector3(0, -0.05, 0), gold, Vector3(1.0, 1.5, 1.0))
	var pendant := SphereMesh.new()
	pendant.radius = 0.05
	pendant.height = 0.1
	_mesh(root, "Pendant", pendant, Vector3(0, -0.15, -0.27), Color(0.25, 0.55, 0.95))
	var setting := TorusMesh.new()
	setting.inner_radius = 0.045
	setting.outer_radius = 0.065
	_mesh(root, "Setting", setting, Vector3(0, -0.15, -0.265), gold, Vector3.ONE, Vector3(deg_to_rad(90), 0, 0))
	return root


static func _red_bandana() -> Node3D:
	var root := Node3D.new()
	root.name = "RedBandana"
	var red := Color(0.85, 0.15, 0.18)
	var wrap := TorusMesh.new()
	wrap.inner_radius = 0.22
	wrap.outer_radius = 0.31
	_mesh(root, "Wrap", wrap, Vector3(0, -0.03, 0), red, Vector3(1.0, 1.3, 1.0))
	var flap := BoxMesh.new()
	flap.size = Vector3(0.24, 0.24, 0.03)
	_mesh(root, "Flap", flap, Vector3(0, -0.17, -0.27), red.lightened(0.05), Vector3.ONE, Vector3(0, 0, deg_to_rad(45)))
	for dot in [Vector3(-0.04, -0.15, -0.29), Vector3(0.04, -0.2, -0.29), Vector3(0.0, -0.11, -0.29)]:
		var spot := SphereMesh.new()
		spot.radius = 0.018
		spot.height = 0.036
		_mesh(root, "Spot", spot, dot, Color(0.98, 0.97, 0.94))
	return root


# ---- tops and dresses (socket torso: the middle of the torso; the body is a capsule about 0.3 m in radius) ----

static func _sunny_dress() -> Node3D:
	var root := Node3D.new()
	root.name = "SunnyDress"
	var yellow := Color(1.0, 0.84, 0.35)
	var bodice := CapsuleMesh.new()
	bodice.radius = 0.31
	bodice.height = 0.66
	_mesh(root, "Bodice", bodice, Vector3(0, 0.03, 0), yellow)
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.31
	skirt.bottom_radius = 0.58
	skirt.height = 0.46
	_mesh(root, "Skirt", skirt, Vector3(0, -0.3, 0), yellow.darkened(0.04))
	var hem := TorusMesh.new()
	hem.inner_radius = 0.55
	hem.outer_radius = 0.6
	_mesh(root, "Hem", hem, Vector3(0, -0.52, 0), Color(0.98, 0.97, 0.92))
	var belt := TorusMesh.new()
	belt.inner_radius = 0.29
	belt.outer_radius = 0.34
	_mesh(root, "Belt", belt, Vector3(0, -0.08, 0), Color(0.95, 0.5, 0.25))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.2
	collar.outer_radius = 0.3
	_mesh(root, "Collar", collar, Vector3(0, 0.3, 0), Color(0.98, 0.97, 0.92), Vector3(1.0, 1.2, 1.0))
	return root


static func _denim_overalls() -> Node3D:
	var root := Node3D.new()
	root.name = "DenimOveralls"
	var denim := Color(0.25, 0.42, 0.72)
	var pants := CapsuleMesh.new()
	pants.radius = 0.31
	pants.height = 0.5
	_mesh(root, "Pants", pants, Vector3(0, -0.12, 0), denim)
	var bib := BoxMesh.new()
	bib.size = Vector3(0.34, 0.34, 0.05)
	_mesh(root, "Bib", bib, Vector3(0, 0.12, -0.285), denim.lightened(0.05))
	for side in [-1.0, 1.0]:
		var strap := BoxMesh.new()
		strap.size = Vector3(0.07, 0.42, 0.05)
		_mesh(root, "Strap", strap, Vector3(side * 0.15, 0.26, -0.22), denim, Vector3.ONE, Vector3(deg_to_rad(-20), 0, 0))
		var button := SphereMesh.new()
		button.radius = 0.028
		button.height = 0.056
		_mesh(root, "Button", button, Vector3(side * 0.15, 0.2, -0.31), Color(0.97, 0.8, 0.25))
	var pocket := BoxMesh.new()
	pocket.size = Vector3(0.16, 0.12, 0.02)
	_mesh(root, "Pocket", pocket, Vector3(0, 0.08, -0.315), denim.darkened(0.2))
	return root


static func _red_hoodie() -> Node3D:
	var root := Node3D.new()
	root.name = "RedHoodie"
	var red := Color(0.82, 0.2, 0.22)
	var shell := CapsuleMesh.new()
	shell.radius = 0.31
	shell.height = 0.66
	_mesh(root, "Shell", shell, Vector3(0, 0.02, 0), red)
	var hood := TorusMesh.new()
	hood.inner_radius = 0.1
	hood.outer_radius = 0.27
	_mesh(root, "Hood", hood, Vector3(0, 0.3, 0.2), red.darkened(0.15), Vector3(1.0, 1.0, 1.0), Vector3(deg_to_rad(90), 0, 0))
	var pocket := BoxMesh.new()
	pocket.size = Vector3(0.3, 0.14, 0.04)
	_mesh(root, "Pocket", pocket, Vector3(0, -0.12, -0.3), red.darkened(0.2))
	for side in [-1.0, 1.0]:
		var cord := CylinderMesh.new()
		cord.top_radius = 0.012
		cord.bottom_radius = 0.012
		cord.height = 0.2
		_mesh(root, "Cord", cord, Vector3(side * 0.07, 0.2, -0.3), Color(0.97, 0.97, 0.94))
	return root


static func _striped_tee() -> Node3D:
	var root := Node3D.new()
	root.name = "StripedTee"
	var shell := CapsuleMesh.new()
	shell.radius = 0.305
	shell.height = 0.64
	_mesh(root, "Shell", shell, Vector3(0, 0.02, 0), Color(0.97, 0.97, 0.94))
	for k in 4:
		var stripe := TorusMesh.new()
		stripe.inner_radius = 0.285
		stripe.outer_radius = 0.325
		_mesh(root, "Stripe%d" % k, stripe, Vector3(0, -0.2 + 0.15 * k, 0), Color(0.15, 0.25, 0.5))
	return root


# ---- backs (socket back: just behind the torso) ----

static func _angel_wings() -> Node3D:
	var root := Node3D.new()
	root.name = "AngelWings"
	var white := Color(0.98, 0.98, 1.0)
	# Three fanned feathers per side, sweeping up and out from the shoulder blades (long to short, steep to flat).
	var tilts := [20.0, 50.0, 80.0]
	var lengths := [0.7, 0.62, 0.46]
	for side in [-1.0, 1.0]:
		var attach := Vector3(side * 0.1, 0.1, 0.12)
		for k in 3:
			var tilt: float = deg_to_rad(tilts[k])
			var length: float = lengths[k]
			var direction := Vector2(side * sin(tilt), cos(tilt))
			var feather := SphereMesh.new()
			feather.radius = 0.3
			feather.height = 0.6
			var center := attach + Vector3(direction.x, direction.y, 0.0) * (length * 0.5)
			_mesh(root, "Feather%d" % k, feather, center, white.darkened(0.03 * k), Vector3(0.36, length / 0.6, 0.12), Vector3(0, 0, -side * tilt))
	return root


static func _red_cape() -> Node3D:
	var root := Node3D.new()
	root.name = "RedCape"
	var red := Color(0.78, 0.12, 0.2)
	var gold := Color(0.97, 0.85, 0.3)
	# A short shoulder panel plus a wider flared hem panel below it, hanging a little away from the back: reads as a cloak, not a board.
	var upper := BoxMesh.new()
	upper.size = Vector3(0.6, 0.5, 0.035)
	_mesh(root, "Shoulders", upper, Vector3(0, 0.12, 0.1), red, Vector3.ONE, Vector3(deg_to_rad(4), 0, 0))
	var lower := BoxMesh.new()
	lower.size = Vector3(0.8, 0.42, 0.035)
	_mesh(root, "Hem", lower, Vector3(0, -0.3, 0.17), red.darkened(0.08), Vector3.ONE, Vector3(deg_to_rad(12), 0, 0))
	var lining_upper := BoxMesh.new()
	lining_upper.size = Vector3(0.56, 0.46, 0.03)
	_mesh(root, "LiningUpper", lining_upper, Vector3(0, 0.12, 0.078), gold, Vector3.ONE, Vector3(deg_to_rad(4), 0, 0))
	var lining_lower := BoxMesh.new()
	lining_lower.size = Vector3(0.76, 0.38, 0.03)
	_mesh(root, "LiningLower", lining_lower, Vector3(0, -0.3, 0.145), gold.darkened(0.1), Vector3.ONE, Vector3(deg_to_rad(12), 0, 0))
	for side in [-1.0, 1.0]:
		var clasp := SphereMesh.new()
		clasp.radius = 0.04
		clasp.height = 0.08
		_mesh(root, "Clasp", clasp, Vector3(side * 0.2, 0.36, -0.2), gold)
	return root


static func _butterfly_wings() -> Node3D:
	var root := Node3D.new()
	root.name = "ButterflyWings"
	for side in [-1.0, 1.0]:
		var upper := SphereMesh.new()
		upper.radius = 0.26
		upper.height = 0.52
		_mesh(root, "Upper", upper, Vector3(side * 0.3, 0.2, 0.1), Color(0.96, 0.5, 0.76), Vector3(1.0, 0.85, 0.12), Vector3(0, 0, side * deg_to_rad(-24)))
		var lower := SphereMesh.new()
		lower.radius = 0.19
		lower.height = 0.38
		_mesh(root, "Lower", lower, Vector3(side * 0.24, -0.13, 0.1), Color(0.45, 0.7, 0.97), Vector3(1.0, 0.85, 0.12), Vector3(0, 0, side * deg_to_rad(18)))
		var dot := SphereMesh.new()
		dot.radius = 0.04
		dot.height = 0.08
		_mesh(root, "Dot", dot, Vector3(side * 0.36, 0.22, 0.14), Color(0.98, 0.97, 0.94))
	return root


static func _mesh(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, color: Color,
		mesh_scale := Vector3.ONE, rot_rad := Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	instance.position = pos
	instance.scale = mesh_scale
	instance.rotation = rot_rad
	parent.add_child(instance)
