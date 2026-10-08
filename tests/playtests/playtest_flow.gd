extends SceneTree
## Playtest: how a player joins (topic `flow`), for visual review: the title screen, Info, Settings, the character screen with its Join button, the loading screen
## in the middle of its hold, and the player arriving on the plaza with the well off to one side.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_flow.gd -- <qa_output> <run stamp>

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world(60, true)
	var flow := kit.world.get_node("GameFlow") as GameFlow
	var menu := kit.world.get_node("MainMenu") as MainMenu
	var creator := kit.world.get_node("CharacterCreator") as CharacterCreator
	var loading := kit.world.get_node("LoadingScreen") as LoadingScreen
	flow.load_seconds = 3.0
	kit.day_night.set_time(10.0)
	await kit.frames(20)

	var image := await kit.shot("flow", "title", "The title screen over the live world: Hearthwild, a one-line description and the four buttons.",
			"A big gold 'Hearthwild' title, a pale tagline under it, four wide buttons Play, Info, Settings, Quit stacked in the middle over a dimmed view of the meadow; the Play button looks focused.")
	kit.check_rendered("flow/title", image)
	menu.show_info()
	await kit.frames(6)
	image = await kit.shot("flow", "info", "The Info screen: what the game is and every key.",
			"A heading 'About Hearthwild', a readable paragraph about the game, then the controls list (W A S D, Shift, Space, mouse, E, F or left click, 1 to 5, F2, F3), a Back button; all text inside the window.")
	kit.check_rendered("flow/info", image)
	menu.show_settings()
	await kit.frames(6)
	image = await kit.shot("flow", "settings", "The Settings screen: fullscreen and volume.",
			"A heading 'Settings', a Fullscreen checkbox, a Volume label and a slider, a Back button, centred.")
	kit.check_rendered("flow/settings", image)
	menu.show_home()
	await kit.frames(4)
	menu.press_play()
	await kit.frames(30)
	image = await kit.shot("flow", "character", "After Play: the character screen with a Join button and no Cancel.",
			"The character screen: the animal preview, pickers for the animal and the five wardrobe slots, the name box and a button that says Join (no Cancel button).")
	kit.check_rendered("flow/character", image)
	creator.enter_name("Marco")
	creator.confirm()
	await kit.frames(78)  # about 1.3 s: fully dark, the bar filling
	image = await kit.shot("flow", "loading", "The loading screen in the middle of its hold.",
			"A dark blue cover over everything with 'Loading Hearthwild...' in gold, a progress bar partly filled and a tip line under it.")
	kit.check_rendered("flow/loading", image)
	for i in 600:
		await kit.frames(1)
		if not loading.is_active():
			break
	await kit.frames(40)
	image = await kit.shot("flow", "arrival", "The player has arrived on the plaza: the cobbles, the well off to one side, cottages around.",
			"The dog (or chosen animal) standing in the open middle of a cobbled plaza with cottages and lamp posts around and the well to one side, not in front of the character; no menu or loading cover left.")
	kit.check_rendered("flow/arrival", image)
	print("SCREENSHOTS: %s/flow/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
