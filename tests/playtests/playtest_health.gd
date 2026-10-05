extends SceneTree
## Playtest: the HP bar on the HUD at full, partly hurt, nearly dead and dead (topic `health`), for visual review.
## Besides the screenshots it reads the bar's REAL pixels back from each frame, so a bar that is drawn wrong
## (empty when it should be full, full when it should be empty) fails here, not only in a reviewer's eyes.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_health.gd -- <qa_output> <run stamp>

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


## True when the pixel at `fraction` of the bar's width (vertical middle) is the bar's red fill. Sample OUTSIDE the centred
## text (roughly 32% to 68% of the width): a letter there is white, not red (lesson 59).
func _is_fill_at(image: Image, bar: Control, fraction: float) -> bool:
	var rect := bar.get_global_rect()
	var view := kit.player.get_viewport().get_visible_rect().size
	var scale := Vector2(image.get_width() / view.x, image.get_height() / view.y)
	var p := (rect.position + Vector2(rect.size.x * fraction, rect.size.y * 0.5)) * scale
	var c := image.get_pixelv(Vector2i(p))
	return c.r > 0.6 and c.g < 0.4 and c.b < 0.45


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var health := kit.player.get_node("Health") as Health
	var hud := kit.player.get_node("HUD") as InteractionPrompt
	var bars := hud.find_children("*", "ProgressBar", true, false)
	var bar := bars.front() as Control
	await kit.frames(20)

	var image := await kit.shot("health", "full", "Standing in the meadow at 10 AM with full health; the HP bar sits under the clock in the top-left corner.",
			"The clock text on top, a red bar fully filled directly below it reading '100 / 100', nothing else on the HUD overlapping it; the dog and world unchanged.")
	kit.check_rendered("health/full", image)
	kit.check("full: the bar's red fill reaches both its left and right ends (pixels at 3% and 97%)", _is_fill_at(image, bar, 0.03) and _is_fill_at(image, bar, 0.97), "text '%s'" % hud.hp_text())

	health.damage(50.0)
	await kit.frames(10)
	image = await kit.shot("health", "half", "The player has taken 50 damage: 50 of 100 left, so the centred text sits ON the boundary between the red fill and the dark background.",
			"The red fill covers the left half of the bar exactly; '50 / 100' is readable even where its letters cross from red to dark (white text with a dark outline).")
	kit.check_rendered("health/half", image)
	kit.check("half: red fill at 25% of the width, none at 75% (sampled outside the centred text, which straddles the boundary)", _is_fill_at(image, bar, 0.25) and not _is_fill_at(image, bar, 0.75) and hud.hp_text() == "50 / 100", "text '%s'" % hud.hp_text())

	health.damage(15.0)
	await kit.frames(10)
	image = await kit.shot("health", "hurt", "The player has taken 65 damage in all: 35 of 100 left.",
			"The red fill covers only about the left third of the bar; the rest is the dark background; the text reads '35 / 100' and stays readable on both colours.")
	kit.check_rendered("health/hurt", image)
	kit.check("hurt: red fill at 15% of the width, none at 60% or 90% (35% left)", _is_fill_at(image, bar, 0.15) and not _is_fill_at(image, bar, 0.60) and not _is_fill_at(image, bar, 0.90), "text '%s'" % hud.hp_text())

	health.damage(34.0)
	await kit.frames(10)
	image = await kit.shot("health", "nearly_dead", "One hit point left.",
			"Only a thin red sliver at the far left of the bar (or the bar nearly empty); the text reads '1 / 100'.")
	kit.check_rendered("health/nearly_dead", image)
	kit.check("nearly dead: the thin red sliver IS drawn at the far left (0.5% of the width), no red at 25%, text '1 / 100'", _is_fill_at(image, bar, 0.005) and not _is_fill_at(image, bar, 0.25) and hud.hp_text() == "1 / 100", "text '%s'" % hud.hp_text())

	health.damage(5.0)
	await kit.frames(10)
	image = await kit.shot("health", "dead", "Zero hit points; the player is dead (nothing handles death yet, so the dog just stands there).",
			"An empty dark bar with no red at all; the text reads '0 / 100'.")
	kit.check_rendered("health/dead", image)
	kit.check("dead: no red fill anywhere along the bar (3%, 50%, 97%) and the text reads '0 / 100'", not _is_fill_at(image, bar, 0.03) and not _is_fill_at(image, bar, 0.50) and not _is_fill_at(image, bar, 0.97) and hud.hp_text() == "0 / 100", "text '%s'" % hud.hp_text())

	health.revive()
	print("SCREENSHOTS: %s/health/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
