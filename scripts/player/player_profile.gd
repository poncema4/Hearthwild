class_name PlayerProfile
extends RefCounted
## Who the player is: their name (shown over their head), which animal they chose,
## what they wear, and their fishing journal. Saved as JSON in the user folder, so it
## survives restarts and is ignored by git.
##
## The name comes from Steam once the game is on Steam: `steam_name()` is the one place
## to connect (GodotSteam's `Steam.getPersonaName()`); until then it falls back to the
## computer's user name, then to "Hearthling". Anything loaded from disk is sanitised, so a
## hand-edited or damaged save can never break the game.

const DEFAULT_PATH := "user://profile.json"
const MAX_NAME_LENGTH := 16

## Where profiles are read from and written to (tests point this at a temporary file).
static var save_path: String = DEFAULT_PATH

static var _current: PlayerProfile

var display_name: String = ""
var species_id: StringName = &"dog"
## slot -> item id, e.g. {head_top: red_cap}
var outfit: Dictionary = {}
## fish id -> {count, biggest_cm}
var fish: Dictionary = {}


## The profile in use right now (loaded from disk, or a fresh default). Fishing records catches here.
static func current() -> PlayerProfile:
	if _current == null:
		_current = PlayerProfile.load_saved()
		if _current == null:
			_current = PlayerProfile.make_default()
	return _current


static func set_current(profile: PlayerProfile) -> void:
	_current = profile


## Forgets the in-memory profile (tests; the next `current()` loads or makes one).
static func reset_current() -> void:
	_current = null


## Dresses a character model to match: animal, outfit and name tag.
func apply_to(model: AnimalModel) -> void:
	model.set_species(AnimalSpecies.by_id(species_id))
	for slot in Outfits.SLOTS:
		model.unequip_slot(slot)
	for slot in outfit:
		model.equip_item(outfit[slot])
	model.set_display_name(display_name)


## The Steam persona name, or "" when Steam is not connected (yet).
static func steam_name() -> String:
	if Engine.has_singleton("Steam"):
		var steam: Object = Engine.get_singleton("Steam")
		if steam.has_method("getPersonaName"):
			return String(steam.call("getPersonaName"))
	return ""


## The name a brand-new player gets: Steam name, else the computer's user name, else "Hearthling".
static func default_name() -> String:
	for candidate in [steam_name(), OS.get_environment("USER"), OS.get_environment("USERNAME")]:
		var cleaned := clean_name(candidate)
		if cleaned != "":
			return cleaned
	return "Hearthling"


## Trims, drops control characters, caps the length ("" if nothing usable is left).
static func clean_name(raw: String) -> String:
	var kept := ""
	for i in raw.length():
		var code := raw.unicode_at(i)
		if code >= 32 and code != 127:
			kept += raw[i]
	return kept.strip_edges().left(MAX_NAME_LENGTH).strip_edges()


static func make_default() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.display_name = default_name()
	return profile


## The saved profile, or null if there is none or it is unreadable (never prints an engine ERROR).
static func load_saved() -> PlayerProfile:
	if not FileAccess.file_exists(save_path):
		return null
	var text := FileAccess.get_file_as_string(save_path)
	var parser := JSON.new()
	if parser.parse(text) != OK or not (parser.data is Dictionary):
		return null
	var profile := PlayerProfile.from_dict(parser.data)
	return profile


func save() -> bool:
	sanitize()
	# Write a temporary file and rename it over the real one: a crash half way through writing can
	# never leave a truncated save behind (which would load as "no profile" and reset the player).
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return DirAccess.rename_absolute(temporary, save_path) == OK


func to_dict() -> Dictionary:
	var worn := {}
	for slot in outfit:
		worn[String(slot)] = String(outfit[slot])
	return {"version": 1, "name": display_name, "species": String(species_id), "outfit": worn, "fish": fish}


static func from_dict(data: Dictionary) -> PlayerProfile:
	# Every value is type-checked: a hand-edited save with null, lists or text in the wrong place
	# must never raise an engine error (the runner treats any as a failure) or lose the whole profile.
	var profile := PlayerProfile.new()
	var raw_name = data.get("name", "")
	profile.display_name = raw_name if raw_name is String else ""
	var raw_species = data.get("species", "dog")
	profile.species_id = StringName(raw_species) if raw_species is String else &"dog"
	var worn = data.get("outfit", {})
	if worn is Dictionary:
		for slot in worn:
			if slot is String and worn[slot] is String:
				profile.outfit[StringName(slot)] = StringName(worn[slot])
	var journal = data.get("fish", {})
	if journal is Dictionary:
		for id in journal:
			var entry = journal[id]
			if id is String and entry is Dictionary:
				profile.fish[id] = {"count": int(_number(entry.get("count", 0))), "biggest_cm": _number(entry.get("biggest_cm", 0.0))}
	profile.sanitize()
	return profile


static func _number(value) -> float:
	return float(value) if (value is int or value is float) else 0.0


## Makes any profile valid: a usable name, a known animal, only real items on their right slots.
func sanitize() -> void:
	display_name = PlayerProfile.clean_name(display_name)
	if display_name == "":
		display_name = PlayerProfile.default_name()
	var known := false
	for species in AnimalSpecies.all():
		known = known or species.id == species_id
	if not known:
		species_id = &"dog"
	var valid := {}
	for slot in outfit:
		var item: StringName = outfit[slot]
		if Outfits.slot_of(item) == slot:
			valid[slot] = item
	outfit = valid
	for id in fish.keys():
		if int(fish[id].get("count", 0)) <= 0:
			fish.erase(id)


## Records a caught fish in the journal (count and biggest size).
func record_catch(fish_id: String, length_cm: float) -> void:
	var entry: Dictionary = fish.get(fish_id, {"count": 0, "biggest_cm": 0.0})
	entry["count"] = int(entry["count"]) + 1
	entry["biggest_cm"] = maxf(float(entry["biggest_cm"]), length_cm)
	fish[fish_id] = entry
