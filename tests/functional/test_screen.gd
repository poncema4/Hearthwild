extends SceneTree
## Functional test: the village's shared screen (where players will watch YouTube together): the link parser
## (accepted forms and hostile or malformed links), the place (flat ground, facing the plaza, solid, seating) and the
## paste-a-link box (open, bad link, good link, clear, Esc, the player locked while it is open).
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_screen.gd
## Exit code = number of failures (0 = all pass).

const ID := "dQw4w9WgXcQ"

var kit: PlaytestKit
var _emitted: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	_check_parser()
	var screen: SharedScreen = kit.village.screen
	kit.check("the village has a shared screen", screen != null)
	if screen == null:
		kit.finish()
		return
	await _check_place(screen)
	await _check_dialog(screen)
	kit.finish()


func _check_parser() -> void:
	var accepted := {
		"https://www.youtube.com/watch?v=" + ID: ID,
		"youtube.com/watch?v=" + ID: ID,
		"http://youtube.com/watch?v=%s&t=43s" % ID: ID,
		"https://youtube.com/watch?feature=share&v=" + ID: ID,
		"https://m.youtube.com/watch?v=" + ID: ID,
		"https://music.youtube.com/watch?v=" + ID: ID,
		"https://youtu.be/" + ID: ID,
		"https://youtu.be/%s?si=abc123" % ID: ID,
		"youtu.be/%s?t=10" % ID: ID,
		"https://youtu.be/%s#frag" % ID: ID,
		"https://www.youtube.com/shorts/aBcDeFgHiJk": "aBcDeFgHiJk",
		"https://www.youtube.com/embed/" + ID: ID,
		"https://www.youtube-nocookie.com/embed/" + ID: ID,
		"https://www.youtube.com/live/%s?feature=share" % ID: ID,
		"  https://youtu.be/%s  " % ID: ID,
		"HTTPS://YOUTU.BE/" + ID: ID,
		"https://www.youtube.com/watch?v=a-_B1c2D3e4": "a-_B1c2D3e4",
		"youtu.be/%s?u=http://example.com" % ID: ID,  # a scheme-less link with a URL in a parameter
		"https://www.youtube.com/watch?v=%s#t=30" % ID: ID,
	}
	var wrong := []
	for link in accepted:
		var got := SharedScreen.parse_youtube_id(link)
		if got != accepted[link]:
			wrong.append("'%s' -> '%s'" % [link, got])
	kit.check("every accepted link form gives its 11-character id (%d forms)" % accepted.size(), wrong.is_empty(), str(wrong))
	var rejected := [
		"", "   ", "hello", "https://example.com/watch?v=" + ID,
		"https://youtube.com.evil.com/watch?v=" + ID, "https://evil.com/youtube.com/watch?v=" + ID,
		"https://youtube.com@evil.com/watch?v=" + ID, "https://notyoutube.com/watch?v=" + ID,
		"https://youtu.be.evil.com/" + ID, "https://yοutube.com/watch?v=" + ID,  # a Greek omicron
		"javascript:alert(1)//youtu.be/" + ID, "ftp://youtu.be/" + ID, "file:///etc/passwd",
		"data:text/html,youtu.be/" + ID, "https://www.youtube.com:8080/watch?v=" + ID,
		"https://youtu.be/short", "https://youtu.be/%sextra" % ID, "https://youtu.be/dQw4w9WgXc!",
		"https://youtu.be/", "https://www.youtube.com/watch", "https://www.youtube.com/watch?v=",
		"https://www.youtube.com/watch?x=" + ID, "https://www.youtube.com/watch/" + ID,
		"https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxxxx", "https://youtu.be/dQw4 w9WgXcQ",
		"https://youtu.be/%s\nhttps://evil.com" % ID, "https://youtube.com\\@evil.com/watch?v=" + ID,
		"https://youtu.be/" + "a".repeat(400),
		"https://youtube.com/watch#x?v=" + ID, "https://youtube.com/embed/%s/../../x" % ID, "https://youtube.com/embed/%s%%2f" % ID,
		"https://youtube.com/embed\\%s" % ID,
	]
	var let_through := []
	for link in rejected:
		var got := SharedScreen.parse_youtube_id(link)
		if got != "":
			let_through.append("'%s' -> '%s'" % [link.substr(0, 40), got])
	kit.check("every hostile or malformed link is rejected (%d cases)" % rejected.size(), let_through.is_empty(), str(let_through))


func _check_place(screen: SharedScreen) -> void:  # a coroutine: the label rebuilds its mesh on the next frame
	var terrain: Terrain = kit.terrain
	var space: PhysicsDirectSpaceState3D = kit.world.get_world_3d().direct_space_state
	var plaza := kit.village.center()
	var flat_reach := Vector2(screen.global_position.x, screen.global_position.z).distance_to(terrain.village_center) + SharedScreen.WIDTH * 0.5 + 1.0
	kit.check("the screen stands inside the village's flat zone (reach %.1f m of %.1f)" % [flat_reach, terrain.village_flat_radius], flat_reach <= terrain.village_flat_radius, "%.1f" % flat_reach)
	var to_plaza := (plaza - screen.global_position)
	to_plaza.y = 0.0
	var facing := screen.global_transform.basis.z
	kit.check("the screen faces the plaza", facing.dot(to_plaza.normalized()) > 0.95, "dot %.2f" % facing.dot(to_plaza.normalized()))
	var ground_worst := 0.0
	for side in [-1.0, 0.0, 1.0]:
		var p: Vector3 = screen.global_position + Vector3(side * (SharedScreen.WIDTH * 0.5 + 0.3), 0, 0)
		ground_worst = maxf(ground_worst, absf(terrain.height_at(p.x, p.z)))
	kit.check("the ground under the screen is flat", ground_worst < 0.01, "%.3f" % ground_worst)
	var solid := 0
	for side in [-1.0, 1.0]:
		var post: Vector3 = screen.global_position + Vector3(side * (SharedScreen.WIDTH * 0.5 + 0.3), 0.4, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(post + Vector3(0, 0, 2.0), post))
		if not hit.is_empty() and screen.is_ancestor_of(hit["collider"]):
			solid += 1
	kit.check("both posts are solid at knee height", solid == 2, "%d of 2" % solid)
	var panel_top := screen.global_position + Vector3(0, SharedScreen.SCREEN_BOTTOM + SharedScreen.HEIGHT * 0.5, 0)
	var panel_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(panel_top + Vector3(0, 0, 2.0), panel_top))
	kit.check("the screen itself is solid (a ray at its middle hits the frame)", not panel_hit.is_empty() and screen.is_ancestor_of(panel_hit["collider"]))
	var facing_screen := 0
	for bench in screen.benches:
		if bench.global_transform.basis.z.dot(-screen.global_transform.basis.z) > 0.95:  # a bench's front is its +Z
			facing_screen += 1
	kit.check("there are 6 benches and every one faces the screen", screen.benches.size() == 6 and facing_screen == 6, "%d benches, %d facing" % [screen.benches.size(), facing_screen])
	var overlaps := 0
	# The footprint comes from the screen's own geometry (its width, its posts, its bench rows), not from literals.
	var half_x := SharedScreen.WIDTH * 0.5 + 0.7
	var front_z := 0.0
	for bench in screen.benches:
		front_z = maxf(front_z, bench.position.z + 0.8)
	for corner in [Vector3(-half_x, 0, -0.5), Vector3(half_x, 0, -0.5), Vector3(-half_x, 0, front_z), Vector3(half_x, 0, front_z)]:
		var world_corner := screen.to_global(corner)
		for house in kit.village.houses:
			var local := house.to_local(world_corner)
			if absf(local.x) < House.WIDTH * 0.5 + 1.0 and absf(local.z) < House.DEPTH * 0.5 + 1.0:
				overlaps += 1
	for prop in kit.village.props:
		var local := screen.to_local(prop.global_position)
		if absf(local.x) < half_x + 0.5 and local.z > -1.0 and local.z < front_z + 0.5:
			overlaps += 1
	kit.check("the screen and its seating overlap no house or village prop", overlaps == 0, "%d overlaps" % overlaps)
	await kit.physics_frames(4)
	var empty_size := screen.screen_text_size()
	screen.open_dialog(kit.player)
	screen.submit("https://youtu.be/" + ID)
	await kit.physics_frames(4)
	var showing_size := screen.screen_text_size()
	screen.clear()
	await kit.physics_frames(4)
	kit.check("the text fits on the screen's face in both states (empty %.1f x %.1f m, showing %.1f x %.1f m, face %.1f x %.1f m)" % [empty_size.x, empty_size.y, showing_size.x, showing_size.y, SharedScreen.WIDTH, SharedScreen.HEIGHT],
			empty_size != showing_size and empty_size.x > 1.0 and showing_size.x > 1.0 and maxf(empty_size.x, showing_size.x) <= SharedScreen.WIDTH * 0.92 and maxf(empty_size.y, showing_size.y) <= SharedScreen.HEIGHT * 0.92,
			"%s %s" % [empty_size, showing_size])
	kit.check("the screen starts empty and says how to use it", screen.video_id == "" and screen.screen_text().contains("HEARTHWILD THEATER") and screen.screen_text().contains("Press E"), screen.screen_text())


func _check_dialog(screen: SharedScreen) -> void:
	var player := kit.player
	var hud: InteractionPrompt = player.get_node("HUD")
	var interactor: Interactor = player.get_node("Interactor")
	screen.url_changed.connect(func(id): _emitted.append(id))
	var failures := []
	for stand_z in [0.7, 1.7, 2.2]:  # right under the screen, midway, and just before the first row of benches (their seats are the nearer target beyond that)
		var spot := screen.to_global(Vector3(0, 0, stand_z))
		await kit.teleport(Vector3(spot.x, NAN, spot.z), 20)
		kit.face(Vector3.FORWARD)
		(player.get_node("Body") as Node3D).rotation.y = 0.0
		await kit.physics_frames(8)
		if hud.prompt_text() != "Choose what to watch" or interactor.current_target != screen.interactable:
			failures.append("z=%.1f: '%s' target %s" % [stand_z, hud.prompt_text(), interactor.current_target])
	kit.check("standing anywhere in front of the screen, facing it, the prompt says Choose what to watch", failures.is_empty(), str(failures))
	await kit.tap("interact")
	await kit.physics_frames(4)
	kit.check("E opens the box and the player is locked (the mouse is checked in the rendered playtest)", screen.dialog_open and player.input_locked,
			"open=%s locked=%s" % [screen.dialog_open, player.input_locked])
	var start := player.global_position
	Input.action_press("move_forward")
	await kit.physics_frames(25)
	Input.action_release("move_forward")
	kit.check("W held while the box is open moves nothing", player.global_position.distance_to(start) < 0.05, "moved %.2f" % player.global_position.distance_to(start))
	screen.open_dialog(player)
	kit.check("opening it again does nothing (one box)", screen.get_children().filter(func(n): return n is CanvasLayer).size() == 1)
	var bad := screen.submit("https://evil.com/watch?v=" + ID)
	kit.check("a bad link is refused with a reason, the box stays open and the screen is unchanged", bad == SharedScreen.NOT_A_LINK and screen.dialog_open and screen.video_id == "" and _emitted.is_empty(), "'%s' open=%s id='%s'" % [bad, screen.dialog_open, screen.video_id])
	var good := screen.submit("  https://youtu.be/%s?si=xyz  " % ID)
	kit.check("a good link sets the video, closes the box and frees the player",
			good == "" and screen.video_id == ID and not screen.dialog_open and not player.input_locked,
			"'%s' id='%s' open=%s locked=%s" % [good, screen.video_id, screen.dialog_open, player.input_locked])
	kit.check("the screen's face now shows the video id and the HUD says so", screen.screen_text().contains(ID) and screen.screen_text().contains("NOW SHOWING") and hud.message_text().contains(ID), "'%s' / '%s'" % [screen.screen_text(), hud.message_text()])
	kit.check("url_changed fired exactly once, with the id", _emitted == [ID], str(_emitted))
	screen.submit("https://www.youtube.com/watch?v=" + ID)
	kit.check("choosing the same video again does not fire url_changed again", _emitted == [ID], str(_emitted))
	screen.open_dialog(player)
	screen.submit("javascript:alert(1)")
	kit.check("a hostile paste leaves the chosen video alone", screen.video_id == ID and _emitted == [ID])
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await kit.physics_frames(4)
	kit.check("Esc closes the box without changing the video and frees the player", not screen.dialog_open and screen.video_id == ID and not player.input_locked, "open=%s id=%s locked=%s" % [screen.dialog_open, screen.video_id, player.input_locked])
	var spare := SharedScreen.new()
	spare.name = "SpareScreen"
	kit.world.add_child(spare)
	spare.open_dialog(player)
	var locked_while_open := player.input_locked
	spare.free()  # the screen vanishes while its box is open (a rebuilt village, a closed scene)
	kit.check("freeing a screen whose box is open releases the player", locked_while_open and not player.input_locked, "locked while open=%s, after free=%s" % [locked_while_open, player.input_locked])
	screen.clear()
	kit.check("clearing takes the video off: the face says how to use it again and url_changed fires with an empty id", screen.video_id == "" and screen.screen_text().contains("Press E") and _emitted == [ID, ""], "'%s' %s" % [screen.screen_text(), str(_emitted)])
