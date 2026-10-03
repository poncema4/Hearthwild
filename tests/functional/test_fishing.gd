extends SceneTree
## Functional test: fishing (the spots round the pond, the cast/wait/bite/reel cycle, every way
## it can end, what you see, the day/night fish rules, and the saved journal).
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_fishing.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var _caught_log: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	var terrain := kit.terrain
	var spots := kit.fishing.spots
	var player := kit.player
	var hud: InteractionPrompt = player.get_node("HUD")
	var model: AnimalModel = player.get_node("Body/Model")
	var interactor: Interactor = player.get_node("Interactor")

	# 1. The spots: on dry shore, cast lands in deep water, no tree or rock close, all reachable.
	var pond: FishingPond = kit.fishing
	var feasible := 0
	for degrees in pond.candidate_angles_degrees:
		if not pond.plan_spot(deg_to_rad(degrees)).is_empty():
			feasible += 1
	kit.check("every bearing where a cast can reach 1 m of water has a spot, and the lake has at least 6", spots.size() == feasible and spots.size() >= 6, "%d spots, %d feasible bearings" % [spots.size(), feasible])
	var trees: Array = kit.nature.get_trees() + kit.nature.get_rocks()
	var problems := []
	for spot in spots:
		var stand := spot.standing_spot()
		var ground := terrain.height_at(stand.x, stand.z)
		var bobber := spot.bobber_target()
		var depth := terrain.water_level - terrain.height_at(bobber.x, bobber.z)
		var nearest := 99.0
		for thing in trees:
			nearest = minf(nearest, Vector2(thing.global_position.x, thing.global_position.z).distance_to(Vector2(stand.x, stand.z)))
		if ground < terrain.water_level + 0.3:
			problems.append("%s stands at %.2f (water %.2f)" % [spot.name, ground, terrain.water_level])
		if depth < 0.8:
			problems.append("%s bobber lands in only %.2f m of water" % [spot.name, depth])
		if nearest < 4.0:
			problems.append("%s has a tree or rock %.1f m away" % [spot.name, nearest])
	kit.check("every spot stands on dry ground, the cast lands in water at least 0.8 m deep, nothing within 4 m", problems.is_empty(), str(problems))
	var unreachable := []
	for spot in spots:
		await kit.teleport(Vector3(0, NAN, 0), 20)
		var ok := await kit.drive_to(spot.standing_spot(), 0.8, false, "fishing %s" % spot.name)
		await kit.stop_driving()
		if not ok:
			unreachable.append(spot.name)
	kit.check("the player can walk from the spawn to every spot", unreachable.is_empty(), str(unreachable))

	# 2. Standing at a spot facing the water: the prompt appears.
	var spot: FishingSpot = spots[1]
	await _stand_at(spot)
	kit.check("at the spot, facing the water, the target is the spot and the prompt says Cast your line", interactor.current_target == spot and hud.prompt_text() == "Cast your line",
			"target=%s prompt='%s'" % [interactor.current_target, hud.prompt_text()])

	# 3. A full catch, with timings: cast 0.6 s, wait 2-6 s, bite window 1.4 s.
	spot.rng.seed = 11
	_caught_log.clear()
	spot.caught.connect(func(r): _caught_log.append(r))
	var journal_before := PlayerProfile.current().fish.duplicate(true)
	await kit.tap("interact")
	await kit.physics_frames(2)
	kit.check("pressing E casts the line: casting, bobber and line visible, rod in hand", spot.state == FishingSpot.State.CASTING and spot._bobber.visible and spot._line.visible and model.is_fishing(),
			"state %d" % spot.state)
	kit.check("while waiting the prompt says to wait", hud.prompt_text().begins_with("Waiting for a bite"), "'%s'" % hud.prompt_text())
	await kit.physics_frames(40)
	kit.check("after the cast the line is waiting for a bite, bobber floating at the water level", spot.state == FishingSpot.State.WAITING and absf(spot._bobber.global_position.y - spot.water_level) < 0.05,
			"state %d bobber y %.3f" % [spot.state, spot._bobber.global_position.y])
	kit.check("the bobber is over deep water", terrain.height_at(spot._bobber.global_position.x, spot._bobber.global_position.z) < spot.water_level - 0.8)
	var arm_pose := model.arm_angles()
	kit.check("while fishing the arms are raised forward (right arm over 0.9 rad) and the body stays still", arm_pose.y > 0.9 and kit.horizontal_speed() < 0.1, "arms %s" % arm_pose)
	var waited := 0
	while spot.state == FishingSpot.State.WAITING and waited < 600:
		await kit.physics_frames(1)
		waited += 1
	var wait_seconds := (waited + 40) / 60.0 - 0.6
	kit.check("the fish bites after 2 to 6 seconds of waiting", spot.state == FishingSpot.State.BITE and wait_seconds >= 1.9 and wait_seconds <= 6.2, "waited %.2f s" % wait_seconds)
	await kit.physics_frames(3)
	kit.check("at the bite: a red ! shows, the bobber dips under, the prompt says Reel in!", spot._bang.visible and spot._bobber.global_position.y < spot.water_level - 0.05 and hud.prompt_text() == "Reel in!",
			"bang=%s bobber y %.3f prompt '%s'" % [spot._bang.visible, spot._bobber.global_position.y, hud.prompt_text()])
	await kit.tap("interact")
	await kit.physics_frames(3)
	kit.check("reeling in at the bite catches something", _caught_log.size() == 1 and _caught_log[0].has("name") and _caught_log[0]["length_cm"] > 0.0, str(_caught_log))
	kit.check("the catch is announced on screen with its name and size", hud.message_text() != "" and hud.message_text().contains(_caught_log[0]["name"]) and hud.message_text().contains("cm"), "'%s'" % hud.message_text())
	var result: Dictionary = _caught_log[0]
	if not result["junk"]:
		var after: Dictionary = PlayerProfile.current().fish
		kit.check("the fish is in the journal and saved to disk", int(after.get(result["id"], {}).get("count", 0)) == int(journal_before.get(result["id"], {}).get("count", 0)) + 1
				and int(PlayerProfile.load_saved().fish.get(result["id"], {}).get("count", 0)) == int(after[result["id"]]["count"]), str(after))
	kit.check("afterwards the bobber, line and rod are gone and the arms relax", not spot._bobber.visible and not spot._line.visible and not model.is_fishing() and not spot._bang.visible)
	await kit.physics_frames(60)
	kit.check("after a short pause the spot is ready to cast again", spot.state == FishingSpot.State.IDLE and model.arm_angles().y < 0.5, "state %d arm %.2f" % [spot.state, model.arm_angles().y])

	# 4. Reeling in too early scares the fish away: no catch.
	var count_before := _total_fish()
	await kit.tap("interact")
	await kit.physics_frames(50)
	await kit.tap("interact")
	await kit.physics_frames(3)
	kit.check("pressing E before the bite scares the fish away: no catch", _total_fish() == count_before and hud.message_text().contains("too early") and spot.state == FishingSpot.State.RESULT,
			"message '%s' state %d" % [hud.message_text(), spot.state])
	await kit.physics_frames(60)

	# 5. Waiting too long lets it get away.
	spot.rng.seed = 5
	await kit.tap("interact")
	await kit.physics_frames(60 * 9)  # longer than the longest wait plus the bite window
	kit.check("ignoring the bite lets the fish get away", _total_fish() == count_before and spot.state != FishingSpot.State.BITE and spot.state != FishingSpot.State.WAITING and hud.message_text().contains("got away"),
			"state %d message '%s'" % [spot.state, hud.message_text()])
	await kit.physics_frames(60)

	# 6. Walking away, or jumping, pulls the line in.
	await kit.tap("interact")
	await kit.physics_frames(60)
	await _walk_away(1.0)
	kit.check("walking away pulls the line in", spot.state == FishingSpot.State.RESULT or spot.state == FishingSpot.State.IDLE and not model.is_fishing(), "state %d" % spot.state)
	kit.check("and says so", hud.message_text().contains("walked away"), "'%s'" % hud.message_text())
	await kit.physics_frames(60)
	await _stand_at(spot)
	await kit.tap("interact")
	await kit.physics_frames(60)
	await kit.tap("jump")
	await kit.physics_frames(4)
	kit.check("jumping pulls the line in too", spot.state == FishingSpot.State.RESULT and not model.is_fishing(), "state %d" % spot.state)
	await kit.physics_frames(120)

	# 7. The catalog: day fish by day, night fish by night, sensible sizes, rare things rarer.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var day_counts := {}
	var night_counts := {}
	var sizes_ok := true
	for i in 3000:
		for night in [false, true]:
			var roll := FishCatalog.roll(rng, night)
			var counts: Dictionary = night_counts if night else day_counts
			counts[roll["id"]] = int(counts.get(roll["id"], 0)) + 1
			for row in FishCatalog.FISH:
				if row[0] == roll["id"] and (roll["length_cm"] < row[2] - 0.05 or roll["length_cm"] > row[3] + 0.05):
					sizes_ok = false
	kit.check("by day: no night fish (catfish, moon eel) are ever caught", not day_counts.has("catfish") and not day_counts.has("moon_eel"), str(day_counts))
	kit.check("by night: no day fish (bluegill, golden koi) are ever caught", not night_counts.has("bluegill") and not night_counts.has("golden_koi"), str(night_counts))
	kit.check("by day there is a good variety (at least 6 kinds) and so by night", day_counts.size() >= 6 and night_counts.size() >= 6, "%d day kinds, %d night kinds" % [day_counts.size(), night_counts.size()])
	kit.check("the rare golden koi is far rarer than the minnow (under 1/5 as often)", day_counts.get("golden_koi", 0) * 5 < day_counts.get("minnow", 1) and day_counts.get("golden_koi", 0) > 0, "koi %d minnow %d" % [day_counts.get("golden_koi", 0), day_counts.get("minnow", 0)])
	kit.check("junk (an old boot, a rusty can) turns up now and then", day_counts.get("old_boot", 0) > 20 and day_counts.get("rusty_can", 0) > 10, "boots %d cans %d" % [day_counts.get("old_boot", 0), day_counts.get("rusty_can", 0)])
	kit.check("every catch is within its kind's size range", sizes_ok)

	# 8. The numbers behind the cycle, measured over many seeds: the cast takes 0.6 s, the wait is a random
	# 2 to 6 s (and really spreads across that range), the bite window is 1.4 s.
	var cast_frames := []
	var wait_seconds_list := []
	var bite_frames := []
	for seed_value in range(1, 11):
		await _stand_at(spot)
		spot.rng.seed = seed_value * 7919 + 13  # widely spread seeds (consecutive ones give similar first rolls)
		await kit.tap("interact")
		var counts := {FishingSpot.State.CASTING: 2, FishingSpot.State.WAITING: 0, FishingSpot.State.BITE: 0}  # the tap's 2 frames were spent casting
		var guard_frames := 0
		while counts.has(spot.state) and guard_frames < 1200:
			counts[spot.state] += 1
			await kit.physics_frames(1)
			guard_frames += 1
		cast_frames.append(counts[FishingSpot.State.CASTING])
		wait_seconds_list.append(counts[FishingSpot.State.WAITING] / 60.0)
		bite_frames.append(counts[FishingSpot.State.BITE])
		await kit.physics_frames(60)
	var min_wait: float = wait_seconds_list.min()
	var max_wait: float = wait_seconds_list.max()
	kit.check("the cast takes 0.6 s (34 to 40 frames) every time", cast_frames.min() >= 34 and cast_frames.max() <= 40, str(cast_frames))
	kit.check("every wait is between 2 and 6 seconds", min_wait >= 1.95 and max_wait <= 6.05, "waits %s" % str(wait_seconds_list))
	kit.check("the waits really spread over the range (shortest under 3.2 s, longest over 4.8 s)", min_wait < 3.2 and max_wait > 4.8, "min %.2f max %.2f" % [min_wait, max_wait])
	kit.check("the bite window is 1.4 s (80 to 90 frames)", bite_frames.min() >= 80 and bite_frames.max() <= 90, str(bite_frames))

	# Reeling in 1.2 s into the bite works; 1.6 s into it is too late.
	for entry in [[70, true], [96, false]]:
		await _stand_at(spot)
		spot.rng.seed = 12
		_caught_log.clear()
		await kit.tap("interact")
		var guard_edge := 0
		while spot.state != FishingSpot.State.BITE and guard_edge < 700:
			await kit.physics_frames(1)
			guard_edge += 1
		await kit.physics_frames(entry[0])
		await kit.tap("interact")
		await kit.physics_frames(3)
		kit.check("reeling in %.1f s after the bite starts %s" % [entry[0] / 60.0, "catches the fish" if entry[1] else "is too late: it got away"], (_caught_log.size() == 1) == entry[1],
				"caught %d, message '%s'" % [_caught_log.size(), hud.message_text()])
		await kit.physics_frames(90)

	# Walking away: 1.2 m keeps the line, 2.1 m pulls it in.
	var side := Vector3(-spot.toward_water.z, 0.0, spot.toward_water.x)
	await _stand_at(spot)
	await kit.tap("interact")
	await kit.physics_frames(60)
	player.global_position += side * 1.2
	await kit.physics_frames(6)
	kit.check("moving 1.2 m (inside the 1.6 m limit) keeps the line out", spot.state == FishingSpot.State.WAITING, "state %d" % spot.state)
	player.global_position += side * 0.9
	await kit.physics_frames(6)
	kit.check("moving 2.1 m (past the limit) pulls the line in", spot.state == FishingSpot.State.RESULT or spot.state == FishingSpot.State.IDLE, "state %d" % spot.state)
	await kit.physics_frames(90)

	# Junk is not kept in the journal; a real fish is.
	for entry in [[{"id": "old_boot", "name": "Old boot", "length_cm": 30.0, "junk": true}, false], [{"id": "carp", "name": "Carp", "length_cm": 50.0, "junk": false}, true]]:
		await _stand_at(spot)
		var before := _total_fish()
		spot.next_catch_override = entry[0]
		await kit.tap("interact")
		var guard_junk := 0
		while spot.state != FishingSpot.State.BITE and guard_junk < 700:
			await kit.physics_frames(1)
			guard_junk += 1
		await kit.tap("interact")
		await kit.physics_frames(3)
		kit.check("a forced %s %s the journal" % [entry[0]["name"], "goes into" if entry[1] else "stays out of"], (_total_fish() == before + 1) == entry[1] and hud.message_text().contains(entry[0]["name"]),
				"journal %d -> %d, message '%s'" % [before, _total_fish(), hud.message_text()])
		await kit.physics_frames(90)

	# A menu opening mid-cast (F2 -> the character screen) puts the rod away; Cancel gives control back.
	await _stand_at(spot)
	await kit.tap("interact")
	await kit.physics_frames(50)
	kit.creator.enabled = true
	kit.creator.open(PlayerProfile.current())
	await kit.physics_frames(4)
	kit.check("opening the character screen mid-cast puts the rod away", spot.state == FishingSpot.State.RESULT and not model.is_fishing() and hud.message_text().contains("rod away"), "state %d, message '%s'" % [spot.state, hud.message_text()])
	kit.creator.cancel()
	kit.creator.enabled = false
	await kit.physics_frames(90)

	# Changing animal mid-cast keeps the rod (the model is rebuilt) and the line starts at the rod.
	await _stand_at(spot)
	await kit.tap("interact")
	await kit.physics_frames(50)
	model.set_species(AnimalSpecies.cat())
	await kit.physics_frames(4)
	var tip := model.rod_tip_global()
	kit.check("changing animal mid-cast: still fishing, rod in hand, the line starts at the rod tip (not the chest)", model.is_fishing() and model.get_node("Generated").find_child("FishingRod", true, false) != null
			and tip.distance_to(model.global_position + Vector3(0, 1.2, 0)) > 0.3, "tip %s" % tip)
	spot._end("")
	model.set_species(AnimalSpecies.dog())
	await kit.physics_frames(90)

	# 9. At night the real spot only gives night/any fish (the clock really drives it).
	kit.day_night.set_time(0.0)
	_caught_log.clear()
	for i in 6:
		await _stand_at(spot)
		spot.rng.seed = 100 + i
		await kit.tap("interact")
		var guard := 0
		while spot.state != FishingSpot.State.BITE and guard < 700:
			await kit.physics_frames(1)
			guard += 1
		await kit.tap("interact")
		await kit.physics_frames(80)
	var night_catches := []
	for entry in _caught_log:
		night_catches.append(entry["id"])
	var wrong_night := night_catches.filter(func(id): return id == "bluegill" or id == "golden_koi")
	kit.check("exactly six night-time casts, none a day fish", _caught_log.size() == 6 and wrong_night.is_empty(), str(night_catches))
	kit.day_night.set_time(10.0)
	if FileAccess.file_exists(PlayerProfile.save_path):
		DirAccess.remove_absolute(PlayerProfile.save_path)
	kit.finish()


func _total_fish() -> int:
	var total := 0
	for id in PlayerProfile.current().fish:
		total += int(PlayerProfile.current().fish[id]["count"])
	return total


func _stand_at(spot: FishingSpot) -> void:
	var stand := spot.standing_spot()
	await kit.teleport(Vector3(stand.x, NAN, stand.z), 20)
	kit.face(spot.toward_water)
	(kit.player.get_node("Body") as Node3D).rotation.y = atan2(-spot.toward_water.x, -spot.toward_water.z)
	await kit.physics_frames(5)


func _walk_away(seconds: float) -> void:
	kit.face(Vector3.BACK)
	Input.action_press("move_forward")
	await kit.physics_frames(int(seconds * 60.0))
	Input.action_release("move_forward")
	await kit.physics_frames(3)
