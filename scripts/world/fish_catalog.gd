class_name FishCatalog
extends RefCounted
## What can be pulled out of the water, and how likely. Some fish only bite by day, some
## only at night (so the day/night cycle matters to fishing), a couple are rare, and there
## is a bit of junk for fun. `roll()` takes the random generator so tests are repeatable.

enum When { ANY, DAY, NIGHT }

## [id, name, min_cm, max_cm, weight, when, junk]
const FISH: Array = [
	["minnow", "Minnow", 4.0, 9.0, 30, When.ANY, false],
	["perch", "Perch", 15.0, 30.0, 18, When.ANY, false],
	["carp", "Carp", 35.0, 70.0, 15, When.ANY, false],
	["bluegill", "Bluegill", 12.0, 22.0, 25, When.DAY, false],
	["golden_koi", "Golden koi", 40.0, 80.0, 3, When.DAY, false],
	["catfish", "Catfish", 40.0, 90.0, 12, When.NIGHT, false],
	["moon_eel", "Moon eel", 60.0, 110.0, 3, When.NIGHT, false],
	["old_boot", "Old boot", 28.0, 32.0, 6, When.ANY, true],
	["rusty_can", "Rusty can", 10.0, 12.0, 4, When.ANY, true],
]


## The catch rows that can appear now.
static func available(is_night: bool) -> Array:
	var rows := []
	for row in FISH:
		if row[5] == When.ANY or (row[5] == When.NIGHT) == is_night:
			rows.append(row)
	return rows


## One random catch: {id, name, length_cm, junk}.
static func roll(rng: RandomNumberGenerator, is_night: bool) -> Dictionary:
	var rows := available(is_night)
	var total := 0
	for row in rows:
		total += int(row[4])
	var pick := rng.randi_range(1, total)
	var chosen: Array = rows[0]
	for row in rows:
		pick -= int(row[4])
		if pick <= 0:
			chosen = row
			break
	var length := snappedf(rng.randf_range(chosen[2], chosen[3]), 0.1)
	return {"id": chosen[0], "name": chosen[1], "length_cm": length, "junk": chosen[6]}


static func name_of(fish_id: String) -> String:
	for row in FISH:
		if row[0] == fish_id:
			return row[1]
	return fish_id
