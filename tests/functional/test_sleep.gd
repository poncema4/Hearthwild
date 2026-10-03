extends SceneTree
## Functional test: beds and sleeping through the night.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_sleep.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit
var _night_signals := 0
var _day_signals := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	var player := kit.player
	var model: AnimalModel = player.get_node("Body/Model")
	var hud: InteractionPrompt = player.get_node("HUD")
	var interactor: Interactor = player.get_node("Interactor")
	var sleep := kit.sleep_system
	var clock := kit.day_night
	var houses := kit.village.houses
	var bed: Bed = houses[0].bed
	var house_floor_y: float = houses[0].global_position.y

	# 1. Beds: one per cottage, indoors, on the floor, with a free side to get up on.
	var problems := []
	for house in houses:
		var b: Bed = house.bed
		if b == null or not house.is_inside(b.global_position):
			problems.append("%s has no bed inside" % house.name)
			continue
		var up := b.getting_up_point()
		if not house.is_inside(up) or up.distance_to(b.global_position) < 0.9:
			problems.append("%s: getting-up point %s is not a free spot inside" % [house.name, up])
		if absf(b.foot_point().y - (house.global_position.y + Bed.TOP)) > 0.01:
			problems.append("%s: feet not on the mattress" % house.name)
	kit.check("every cottage has a bed inside, with a free spot to get up on", problems.is_empty(), str(problems))
	var space: PhysicsDirectSpaceState3D = kit.world.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(bed.global_position + Vector3(2.0, 0.3, 0.0).rotated(Vector3.UP, bed.global_rotation.y), bed.global_position + Vector3(0, 0.3, 0)))
	kit.check("the bed is solid (a ray at knee height hits its frame)", not hit.is_empty() and bed.is_ancestor_of(hit["collider"]))

	# 2. The sleeping window: 7 PM to 6 AM, tight on both sides.
	var edges := {}
	for h in [18.9, 19.0, 5.9, 6.0]:
		clock.set_time(h)
		edges[h] = sleep.can_sleep_now()
	kit.check("beds work from 7 PM until 6 AM (18.9 no, 19.0 yes, 5.9 yes, 6.0 no)", not edges[18.9] and edges[19.0] and edges[5.9] and not edges[6.0], str(edges))

	# 3. By day: not tired, nothing happens.
	clock.set_time(12.0)
	await _stand_beside(bed)
	kit.check("by day the bed's prompt says it is too early", hud.prompt_text() == "Too early to sleep (after 7 PM)" and interactor.current_target == bed, "'%s' target=%s" % [hud.prompt_text(), interactor.current_target])
	await kit.tap("interact")
	await kit.physics_frames(4)
	kit.check("by day pressing E on the bed only says you are not tired: no sleep, clock unchanged, player free",
			sleep.state == SleepSystem.State.AWAKE and clock.hour == 12.0 and not player.input_locked and hud.message_text().contains("not tired"), "state %d hour %.2f message '%s'" % [sleep.state, clock.hour, hud.message_text()])

	# 4. At 9 PM: the full night. Record every frame.
	clock.set_time(21.0)
	await _stand_beside(bed)
	kit.check("at night the prompt says Sleep until morning", hud.prompt_text() == "Sleep until morning", "'%s'" % hud.prompt_text())
	clock.night_started.connect(func(): _night_signals += 1)
	clock.day_started.connect(func(): _day_signals += 1)
	clock.set_time(21.0)
	clock.paused = false  # the kit pauses the clock; a running one is what a real player has (lesson 51)
	var shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var clock_before := clock.hour
	var start_position := player.global_position
	await kit.tap("interact")
	await kit.physics_frames(2)
	kit.check("pressing E starts the night: locked, sleeping, collision off, clock paused at once",
			sleep.state == SleepSystem.State.LYING_DOWN and player.input_locked and player.sleeping and model.is_sleeping() and shape.disabled and clock.paused,
			"state %d locked=%s sleeping=%s disabled=%s paused=%s" % [sleep.state, player.input_locked, player.sleeping, shape.disabled, clock.paused])
	var states: Array = []
	var hours: Array[float] = []
	var peak_alpha := 0.0
	var lying_checked := false
	var paused_while_asleep := true
	var woke_standing_checked := false
	var frames := 2
	var biggest_step := player.global_position.distance_to(start_position)
	var last_position := start_position  # from BEFORE pressing E, so a teleport in the first frames counts (a control escaped when this started late)
	var at_fade_start := Vector3.INF
	Input.action_press("move_forward")
	while sleep.state != SleepSystem.State.AWAKE and frames < 800:
		await kit.physics_frames(1)
		frames += 1
		if states.is_empty() or states[-1] != sleep.state:
			states.append(sleep.state)
		peak_alpha = maxf(peak_alpha, sleep.overlay_alpha())
		if sleep.state != SleepSystem.State.AWAKE:  # on the final frame the clock has just been handed back
			paused_while_asleep = paused_while_asleep and clock.paused
		if sleep.state == SleepSystem.State.LYING_DOWN:  # the wake-up move happens later, under the black screen, on purpose
			biggest_step = maxf(biggest_step, player.global_position.distance_to(last_position))
		last_position = player.global_position
		if sleep.state == SleepSystem.State.FADE_OUT and at_fade_start == Vector3.INF:
			at_fade_start = player.global_position
		if sleep.state == SleepSystem.State.FADE_IN and not woke_standing_checked:
			woke_standing_checked = true
			var away := (bed.getting_up_point() - bed.global_position)
			away.y = 0.0
			var facing := -(player.get_node("Body") as Node3D).global_transform.basis.z
			kit.check("the move to the wake-up spot happens while the screen is black: when the fade-in starts the character already stands there, facing away from the bed",
					not model.is_sleeping() and model.sleep_amount() < 0.01 and player.global_position.distance_to(bed.getting_up_point()) < 0.05 and facing.dot(away.normalized()) > 0.95 and sleep.overlay_alpha() > 0.95,
					"sleep_amount %.2f, %.2f m from the spot, facing dot %.2f, alpha %.2f" % [model.sleep_amount(), player.global_position.distance_to(bed.getting_up_point()), facing.dot(away.normalized()), sleep.overlay_alpha()])
		if sleep.state == SleepSystem.State.SLEEPING:
			hours.append(clock.hour + (24.0 if clock.hour < 12.0 else 0.0))
			if not lying_checked and model.sleep_amount() > 0.95:
				lying_checked = true
				var body_box := _bounds(model)
				var above_feet := body_box.end.y - player.global_position.y
				var below_floor := house_floor_y - body_box.position.y
				kit.check("while asleep the character lies flat (0.5 to 1.0 m above the mattress, standing is 1.67; nothing below the floor; eyes shut; Zzz showing)",
						above_feet > 0.5 and above_feet < 1.0 and below_floor < 0.01 and model.is_blinking() and model.find_child("Zzz", true, false).visible,
						"%.2f m above the feet, %.2f m below the floor, blinking=%s" % [above_feet, below_floor, model.is_blinking()])
				kit.check("W held while asleep moves nothing (stays on the bed) and the screen is black", player.global_position.distance_to(bed.foot_point()) < 0.05 and sleep.overlay_alpha() > 0.99,
						"%.2f m from the bed's foot spot, alpha %.2f" % [player.global_position.distance_to(bed.foot_point()), sleep.overlay_alpha()])
	Input.action_release("move_forward")
	kit.check("the phases run in order: lying down, fade out, sleeping, fade in, awake", states == [SleepSystem.State.LYING_DOWN, SleepSystem.State.FADE_OUT, SleepSystem.State.SLEEPING, SleepSystem.State.FADE_IN, SleepSystem.State.AWAKE], str(states))
	kit.check("the whole night takes about 5.4 seconds (315 to 335 frames)", frames >= 315 and frames <= 335, "%d frames" % frames)
	kit.check("the character slides onto the bed instead of teleporting (biggest step under 0.1 m; it started %.1f m away) and lies on the foot spot when the fade starts" % start_position.distance_to(bed.foot_point()),
			biggest_step < 0.1 and start_position.distance_to(bed.foot_point()) > 0.6 and at_fade_start.distance_to(bed.foot_point()) < 0.05, "biggest step %.3f, at fade start %.3f m from the spot" % [biggest_step, at_fade_start.distance_to(bed.foot_point())])
	kit.check("the screen goes fully black and comes back", peak_alpha > 0.99 and sleep.overlay_alpha() == 0.0, "peak %.2f, now %.2f" % [peak_alpha, sleep.overlay_alpha()])
	hours.push_front(clock_before + (24.0 if clock_before < 12.0 else 0.0))  # the hour BEFORE pressing E: the first sample must not be earlier (no rewind)
	var monotonic := true
	for i in range(1, hours.size()):
		monotonic = monotonic and hours[i] >= hours[i - 1] - 0.0001
	kit.check("the clock runs smoothly forward from 9 PM through midnight, never back (%d samples)" % hours.size(), monotonic and hours.size() > 100 and hours[1] < 21.3 and hours[-1] > 29.5, "before %.3f, first %.3f, last %.3f" % [hours[0], hours[1], hours[-1]])
	kit.check("the sleep system owns the clock while asleep: it is paused for the whole sleep", paused_while_asleep)
	kit.check("it is 6:30 AM afterwards and the clock is running again (restored to how the player had it)", absf(clock.hour - 6.5) < 0.005 and not clock.paused, "hour %.3f paused=%s" % [clock.hour, clock.paused])
	kit.check("day_started fires exactly once while sleeping and night_started never", _day_signals == 1 and _night_signals == 0, "day %d night %d" % [_day_signals, _night_signals])

	# 5. Waking: standing beside the bed, free, with a greeting.
	var hour_awake := clock.hour
	await kit.physics_frames(60)
	kit.check("after waking the clock keeps running (0.02 h per second of a 20-minute day)", clock.hour > hour_awake + 0.012 and clock.hour < hour_awake + 0.03, "%.3f -> %.3f" % [hour_awake, clock.hour])
	clock.paused = true  # back to the kit's frozen clock for the rest of the test
	var up_box := _bounds(model)
	kit.check("after waking: free to move, collision back, standing beside the bed (not inside it), on the floor",
			not player.input_locked and not player.sleeping and not shape.disabled and player.is_on_floor() and player.global_position.distance_to(bed.getting_up_point()) < 0.4
			and player.global_position.distance_to(bed.global_position) > 0.9, "locked=%s sleeping=%s disabled=%s floor=%s at %.2f from the spot" % [player.input_locked, player.sleeping, shape.disabled, player.is_on_floor(), player.global_position.distance_to(bed.getting_up_point())])
	kit.check("after waking the character stands up again (1.4 to 1.8 m tall, not sleeping)", up_box.size.y > 1.4 and up_box.size.y < 1.8 and not model.is_sleeping() and model.sleep_amount() < 0.01, "height %.2f amount %.2f" % [up_box.size.y, model.sleep_amount()])
	var limbs := model.limb_positions()
	var hands_down := true
	for key in ["hand_l", "hand_r"]:
		var hand: Vector3 = limbs[key]
		hands_down = hands_down and hand.y < 0.8 and absf(hand.x) < 0.5
	kit.check("after waking both hands hang by the hips (below 0.8 m, within 0.5 m of the body line) and both feet are on the ground", hands_down and (limbs["foot_l"] as Vector3).y < 0.2 and (limbs["foot_r"] as Vector3).y < 0.2, str(limbs))
	kit.check("a good-morning message greets the player by name", hud.message_text() == "Good morning, %s!" % PlayerProfile.current().display_name, "'%s'" % hud.message_text())
	Input.action_press("move_back")
	await kit.physics_frames(20)
	Input.action_release("move_back")
	kit.check("and the player can walk again", player.global_position.distance_to(bed.getting_up_point()) > 0.5)

	# 6. Sleeping at 3 AM goes straight to 6:30 (no wrap) and a second E while asleep does nothing.
	clock.set_time(3.0)
	await _stand_beside(bed)
	await kit.tap("interact")
	await kit.physics_frames(30)
	var during := sleep.state
	kit.check("a second sleep cannot start while already asleep", sleep.try_sleep(player, bed) == "" and sleep.state == during)
	var last_hour := clock.hour
	var forward := true
	var guard := 0
	while sleep.state != SleepSystem.State.AWAKE and guard < 600:
		await kit.physics_frames(1)
		guard += 1
		if sleep.state == SleepSystem.State.SLEEPING:
			forward = forward and clock.hour >= last_hour - 0.0001
			last_hour = clock.hour
	kit.check("sleeping at 3 AM runs the clock forward to 6:30 AM without wrapping", forward and absf(clock.hour - 6.5) < 0.02, "hour %.3f forward=%s" % [clock.hour, forward])
	kit.day_night.set_time(10.0)
	kit.finish()


func _stand_beside(bed: Bed) -> void:
	var spot := bed.getting_up_point()
	await kit.teleport(Vector3(spot.x, NAN, spot.z), 15)
	var toward := (bed.global_position - spot)
	toward.y = 0.0
	kit.face(toward.normalized())
	(kit.player.get_node("Body") as Node3D).rotation.y = atan2(-toward.x, -toward.z)
	await kit.physics_frames(5)


func _bounds(node: Node) -> AABB:
	var first := true
	var box := AABB()
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var world_box := (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		box = world_box if first else box.merge(world_box)
		first = false
	return box
