extends SceneTree
## Functional test: the player profile (name, animal, outfit, fishing journal) and the wardrobe catalog.
## It saves to a temporary file, never the player's real profile.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_profile.gd
## Exit code = number of failures (0 = all pass).

var TEST_PATH := "user://hw_test_profile_%d.json" % OS.get_process_id()  # per process: parallel runs must not share a file (lesson 52)
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + detail + ")" if detail else ""))
	if not ok:
		failures += 1


func _write(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _run() -> void:
	PlayerProfile.save_path = TEST_PATH
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)

	# 1. Names.
	var default_name := PlayerProfile.default_name()
	check("the default name is usable (1 to 16 characters, no control characters)", default_name.length() >= 1 and default_name.length() <= 16 and default_name == PlayerProfile.clean_name(default_name), "'%s'" % default_name)
	check("clean_name drops control characters and trims", PlayerProfile.clean_name("  Hello\u0001Wor\nld  ") == "HelloWorld", "'%s'" % PlayerProfile.clean_name("  Hello\u0001Wor\nld  "))
	check("clean_name caps the length at 16", PlayerProfile.clean_name("abcdefghijklmnopqrstuvwxyz").length() == 16, "'%s'" % PlayerProfile.clean_name("abcdefghijklmnopqrstuvwxyz"))
	check("a name of only whitespace and control characters is empty", PlayerProfile.clean_name(" \n\t\u0002 ") == "")
	check("Steam is not connected here, so steam_name() is empty (the hook for later)", PlayerProfile.steam_name() == "")

	# 2. Round trip.
	var profile := PlayerProfile.new()
	profile.display_name = "Marco"
	profile.species_id = &"cat"
	profile.outfit = {&"head_top": &"red_cap", &"back": &"explorer_pack"}
	profile.record_catch("carp", 55.0)
	profile.record_catch("carp", 41.5)  # the smaller one comes second: the biggest must stay 55
	profile.record_catch("minnow", 7.0)
	check("saving works", profile.save() and FileAccess.file_exists(TEST_PATH))
	var loaded := PlayerProfile.load_saved()
	check("a saved profile loads back exactly (name, animal, outfit, journal)",
			loaded != null and loaded.display_name == "Marco" and loaded.species_id == &"cat"
			and loaded.outfit == {&"head_top": &"red_cap", &"back": &"explorer_pack"}
			and int(loaded.fish["carp"]["count"]) == 2 and is_equal_approx(loaded.fish["carp"]["biggest_cm"], 55.0) and int(loaded.fish["minnow"]["count"]) == 1,
			str(loaded.to_dict()) if loaded else "null")

	# 3. Damaged or odd files never crash and never print an engine ERROR (the runner scans for them).
	for case in [["not json at all {", "broken JSON"], ["", "an empty file"], ["[1, 2, 3]", "JSON that is not an object"], ["\"just a string\"", "a bare string"]]:
		_write(case[0])
		check("%s loads as no profile (null)" % case[1], PlayerProfile.load_saved() == null)
	DirAccess.remove_absolute(TEST_PATH)
	check("a missing file loads as no profile (null)", PlayerProfile.load_saved() == null)

	# 4. A hand-edited save is sanitised, never trusted.
	_write(JSON.stringify({"name": "   ", "species": "dragon", "outfit": {"head_top": "red_cap", "back": "red_cap", "face": "laser_eyes", "neck": 5},
			"fish": {"carp": {"count": 3, "biggest_cm": 40}, "ghost": {"count": 0}, "bad": {"count": -4}}}))
	var odd := PlayerProfile.load_saved()
	check("a hostile save is repaired: usable name, unknown animal becomes the dog",
			odd != null and odd.display_name != "" and odd.display_name.length() <= 16 and odd.species_id == &"dog", "%s / %s" % [odd.display_name if odd else "null", odd.species_id if odd else "null"])
	check("only real items on their own slots survive (red cap stays, red cap on the back / unknown / number are dropped)",
			odd != null and odd.outfit == {&"head_top": &"red_cap"}, str(odd.outfit) if odd else "null")
	check("fish entries with no catches are dropped, real ones kept", odd != null and odd.fish.has("carp") and not odd.fish.has("ghost") and not odd.fish.has("bad"), str(odd.fish) if odd else "null")
	_write(JSON.stringify({"name": "x".repeat(1000), "outfit": [1, 2], "fish": "oops"}))
	var wild := PlayerProfile.load_saved()
	check("wrong types (a 1000-letter name, an outfit that is a list, fish that is a string) still give a valid profile",
			wild != null and wild.display_name.length() == 16 and wild.outfit.is_empty() and wild.fish.is_empty(), str(wild.to_dict()) if wild else "null")
	DirAccess.remove_absolute(TEST_PATH)

	# 4b. Nulls, lists and text in the wrong places never raise an engine error (the runner would fail
	# every later run) and never lose the whole profile.
	for case in [
			{"fish": {"x": {"count": null}}}, {"fish": {"x": {"count": [1]}}}, {"fish": {"x": {"biggest_cm": null, "count": 2}}},
			{"name": null}, {"name": 42}, {"species": 7}, {"species": null}, {"outfit": {"head_top": null, "back": ["a"]}}, {"outfit": {"1": "red_cap"}}]:
		var from := PlayerProfile.from_dict(case)
		check("a save with %s loads as a valid profile" % str(case), from != null and from.display_name != "" and from.display_name != "<null>" and from.display_name.length() <= 16
				and AnimalSpecies.by_id(from.species_id).id == from.species_id, str(from.to_dict()) if from else "null")
	var partly := PlayerProfile.from_dict({"name": "Mo", "fish": {"x": {"count": null}, "carp": {"count": 2, "biggest_cm": 40}}})
	check("one bad fish entry does not lose the good ones or the name", partly.display_name == "Mo" and partly.fish.has("carp") and not partly.fish.has("x"), str(partly.fish))

	# 4c. Names keep their spaces and lose DEL; saving is atomic (no temporary file left behind).
	check("clean_name keeps interior spaces", PlayerProfile.clean_name("Marco the Great") == "Marco the Great", "'%s'" % PlayerProfile.clean_name("Marco the Great"))
	check("clean_name drops DEL (127)", PlayerProfile.clean_name("a\u007fb") == "ab", "'%s'" % PlayerProfile.clean_name("a\u007fb"))
	var atomic := PlayerProfile.new()
	atomic.display_name = "Atom"
	check("saving writes the file and leaves no .tmp behind", atomic.save() and FileAccess.file_exists(TEST_PATH) and not FileAccess.file_exists(TEST_PATH + ".tmp"))
	check("a save over an existing (even damaged) file works", (func():
		_write("{ broken")
		return atomic.save() and PlayerProfile.load_saved() != null and PlayerProfile.load_saved().display_name == "Atom").call())
	# A save that cannot complete leaves the old save intact (it writes a temporary file first): block the
	# temporary file's path with a folder, and the old profile must survive and save() must say it failed.
	var old := PlayerProfile.new()
	old.display_name = "Old"
	old.save()
	var blocker := ProjectSettings.globalize_path(TEST_PATH + ".tmp")
	DirAccess.make_dir_absolute(blocker)
	var replacement := PlayerProfile.new()
	replacement.display_name = "New"
	var result := replacement.save()
	DirAccess.remove_absolute(blocker)
	check("a save that cannot be completed fails and leaves the old save untouched", not result and PlayerProfile.load_saved() != null and PlayerProfile.load_saved().display_name == "Old",
			"save returned %s, file now says '%s'" % [result, PlayerProfile.load_saved().display_name if PlayerProfile.load_saved() else "null"])
	DirAccess.remove_absolute(TEST_PATH)

	# 5. The catalog is consistent.
	var ids := {}
	var all_ok := true
	var problems := []
	for row in Outfits.CATALOG:
		var id: StringName = row[0]
		if ids.has(id):
			problems.append("duplicate %s" % id)
		ids[id] = true
		if not Outfits.SLOTS.has(row[1]) or String(row[2]) == "":
			problems.append("bad row %s" % id)
		var item := Outfits.make(id)
		if item.find_children("*", "MeshInstance3D", true, false).is_empty():
			problems.append("%s has no meshes" % id)
		item.free()
	check("every catalog item has a unique id, a real slot, a label and a mesh", problems.is_empty(), str(problems))
	var covered := true
	for slot in Outfits.SLOTS:
		covered = covered and not Outfits.items_for_slot(slot).is_empty()
	check("every outfit slot has at least one item to choose", covered)
	var species_ids := {}
	for species in AnimalSpecies.all():
		species_ids[species.id] = true
	var animals := AnimalSpecies.all()
	check("there are 9 animals with unique ids, the first three still dog, cat, bunny (saves and tests rely on it); an unknown id gives the dog",
			species_ids.size() == 9 and animals.size() == 9 and animals[0].id == &"dog" and animals[1].id == &"cat" and animals[2].id == &"bunny"
			and AnimalSpecies.by_id(&"nope").id == &"dog" and AnimalSpecies.by_id(&"raccoon").id == &"raccoon" and AnimalSpecies.by_id(&"panda").id == &"panda",
			str(species_ids.keys()))
	# Every animal must LOOK different from every other: at least two of fur colour, ears, tail, snout, accent colour must differ clearly.
	var look_problems := []
	for i in animals.size():
		for j in range(i + 1, animals.size()):
			var a: AnimalSpecies = animals[i]
			var b: AnimalSpecies = animals[j]
			var differences := 0
			differences += 1 if Vector3(a.fur_color.r - b.fur_color.r, a.fur_color.g - b.fur_color.g, a.fur_color.b - b.fur_color.b).length() >= 0.12 else 0
			differences += 1 if a.ear_style != b.ear_style else 0
			differences += 1 if a.tail_style != b.tail_style else 0
			differences += 1 if absf(a.snout_length - b.snout_length) >= 0.1 else 0
			differences += 1 if Vector3(a.accent_color.r - b.accent_color.r, a.accent_color.g - b.accent_color.g, a.accent_color.b - b.accent_color.b).length() >= 0.15 else 0
			differences += 1 if a.eye_patch != b.eye_patch else 0
			if differences < 2:
				look_problems.append("%s and %s differ in only %d way(s)" % [a.id, b.id, differences])
	check("every pair of animals differs in at least 2 clear ways (fur, ears, tail, snout, accent, eye patch): no two look alike", look_problems.is_empty(), str(look_problems))
	var bad_names := []
	for species in animals:
		if species.species_name.strip_edges() == "" or species.species_name.length() > 12 or String(species.id) != String(species.id).to_lower():
			bad_names.append(species.id)
	check("every animal has a short readable name (1 to 12 letters) and a lower-case id", bad_names.is_empty(), str(bad_names))

	print("RESULT: %s" % ("ALL PASS (0 failures)" if failures == 0 else "FAILED (%d failures)" % failures))
	quit(failures)
