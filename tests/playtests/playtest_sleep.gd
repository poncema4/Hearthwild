extends SceneTree
## Playtest: going to bed in a cottage at night (topic `sleep`), for visual review.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_sleep.gd -- <qa_output> <run stamp>

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bed: Bed = kit.village.houses[0].bed
	var pitch: Node3D = kit.camera_rig.get_node("Pitch")
	var model: AnimalModel = kit.player.get_node("Body/Model")
	kit.day_night.set_time(21.0)
	var spot := bed.getting_up_point()
	await kit.teleport(Vector3(spot.x, NAN, spot.z), 30)
	var toward := bed.global_position - spot
	toward.y = 0.0
	kit.face(toward.normalized())
	(kit.player.get_node("Body") as Node3D).rotation.y = atan2(-toward.x, -toward.z)
	kit.spring_arm.spring_length = 2.2
	pitch.rotation.x = deg_to_rad(-28.0)
	await kit.frames(10)
	kit.check_rendered("sleep/bed_prompt", await kit.shot("sleep", "bed_prompt", "Standing beside the cottage bed at 9 PM; the prompt over the bed says Sleep until morning.", "A bed (frame, mattress, pillow, blanket) beside the dog; the prompt text 'Sleep until morning' readable at the bottom; the dog fully visible, nothing clipping through the bed."))
	kit.spring_arm.spring_length = 3.4  # frame the whole bed: the camera follows the character onto it
	pitch.rotation.x = deg_to_rad(-38.0)
	await kit.frames(10)
	await kit.tap("interact")
	while model.sleep_amount() < 0.97:
		await kit.frames(1)
	kit.check_rendered("sleep/lying", await kit.shot("sleep", "lying", "The dog has lain down on the bed and is asleep (the screen is about to fade to black).", "The dog lies on its back along the bed with its head on the pillow, eyes shut, a floating Z z z above it; the whole animal rests ON the mattress, not sunk into it and not floating above it."))
	while kit.sleep_system.state != SleepSystem.State.FADE_IN:
		await kit.frames(1)
	while kit.sleep_system.overlay_alpha() > 0.5:
		await kit.frames(1)
	kit.check("the waking shot is taken half faded (overlay alpha 0.3 to 0.7)", kit.sleep_system.overlay_alpha() > 0.3 and kit.sleep_system.overlay_alpha() < 0.7, "alpha %.2f" % kit.sleep_system.overlay_alpha())
	kit.check_rendered("sleep/waking", await kit.shot("sleep", "waking", "The screen fading back in at 6:30 AM; the dog is already standing beside the bed.", "A partly dark screen fading back to the bedroom; the clock text reads 6:30 AM; the dog stands upright beside the bed, not on it and not lying; the bed is empty."))
	while kit.sleep_system.state != SleepSystem.State.AWAKE:
		await kit.frames(1)
	await kit.frames(20)
	kit.check_rendered("sleep/morning", await kit.shot("sleep", "morning", "Awake and standing beside the bed at 6:30 AM; the HUD greets the player.", "The dog standing upright next to the bed, turned away from it (not inside it); a 'Good morning' message; the HUD clock reads 6:30 AM; the window light is the soft early-morning light."))
	kit.day_night.set_time(10.0)
	print("SCREENSHOTS: %s/sleep/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
