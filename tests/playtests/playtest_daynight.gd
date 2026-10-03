extends SceneTree
## Playtest: the village at six times of day (topic `daynight`), for visual review.
## Run (windowed, so use Xvfb; tests/run_tests.sh does this for you):
##   godot --path . --script res://tests/playtests/playtest_daynight.gd -- <qa_output> <run stamp>

const TIMES := [
	["dawn", 6.3, "Just after sunrise (6:18 AM): low warm light from one side, long shadows, an orange-pink horizon; the village lamps are still fading out (they follow the darkness, so they are about 45% on).", "Warm orange low sun, long soft shadows across the plaza, pale orange horizon, nothing pitch black, the dog and cottages readable."],
	["noon", 12.0, "Midday (12:00 PM): the same view as the old fixed lighting.", "Bright neutral light, short shadows, blue sky, the brightest frame of the set."],
	["golden_hour", 17.4, "Late afternoon (5:24 PM): the sun is low on the other side.", "Golden warm light and long shadows pointing the other way from the dawn shot; still bright."],
	["dusk", 18.5, "Sunset (6:30 PM): the sun is on the horizon, the lamps begin to glow.", "Orange and purple sky, dim but readable ground, lamp lanterns beginning to glow warm."],
	["night", 21.5, "Night (9:30 PM): moonlight, village lamps lit.", "Dark blue scene lit by cool moonlight; the 4 lamp posts cast warm pools of light on the ground; windows and walls still readable; no black voids and no pure-white blowout."],
	["midnight", 1.0, "Deep night (1:00 AM) from the spawn clearing, no lamps in view.", "Very dark but not black: moonlit meadow, the dog visible, trees as dark silhouettes against a deep blue sky."],
]

var kit: PlaytestKit
var _pitch: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	kit = PlaytestKit.new(self)
	kit.setup_screenshots()
	await kit.load_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pitch = kit.camera_rig.get_node("Pitch")
	for entry in TIMES:
		kit.day_night.set_time(entry[1])
		var at_spawn: bool = entry[0] == "midnight"
		await kit.teleport(Vector3(0, NAN, 0) if at_spawn else Vector3(-9, NAN, 7.5), 30)
		kit.face(Vector3.FORWARD if at_spawn else Vector3(-11, 0, 6.5).normalized())
		(kit.player.get_node("Body") as Node3D).rotation.y = 0.0
		kit.spring_arm.spring_length = 4.0 if at_spawn else 6.0
		_pitch.rotation.x = deg_to_rad(-14.0)
		await kit.frames(5)
		kit.check_rendered("daynight/" + entry[0], await kit.shot("daynight", entry[0], entry[2], entry[3]))
	# The clock post in the plaza, at noon and at night (its hands must match the HUD clock).
	for entry in [["clock_noon", 12.0, "Standing near the plaza clock post at noon (12:00 PM).", "A wooden post with a cream round clock face; both hands point straight up at 12; four dark ticks at 12, 3, 6 and 9; no z-fighting between face, rim and hands."], ["clock_evening", 15.5, "The plaza clock post at 3:30 PM.", "The short hour hand between 3 and 4, the long minute hand pointing down at 6; the HUD clock top-left says 3:30 PM."]]:
		kit.day_night.set_time(entry[1])
		await kit.teleport(Vector3(-18.6, NAN, 16.2), 30)
		kit.face(Vector3(3.2, 0, 0.4).normalized())
		(kit.player.get_node("Body") as Node3D).rotation.y = 0.0
		kit.spring_arm.spring_length = 2.4
		_pitch.rotation.x = deg_to_rad(-4.0)
		await kit.frames(5)
		kit.check_rendered("daynight/" + entry[0], await kit.shot("daynight", entry[0], entry[2], entry[3]))

	# A whole day as one filmstrip: the clock runs at one game hour per real second; the camera
	# looks at the sky from the plaza, a thumbnail every 3 game hours (6 AM, 9 AM ... 6 AM).
	await kit.teleport(Vector3(-9, NAN, 7.5), 30)
	kit.face(Vector3.BACK)
	(kit.player.get_node("Body") as Node3D).rotation.y = 0.0
	kit.spring_arm.spring_length = 3.0
	_pitch.rotation.x = deg_to_rad(12.0)
	kit.day_night.day_length_seconds = 24.0
	kit.day_night.set_time(6.0)
	kit.day_night.paused = false
	await kit.filmstrip("daynight", "day_cycle", [], 1440, 180,
			"A whole day at one game hour per real second: 9 thumbnails 3 game hours apart (6 AM, 9 AM, 12 PM, 3 PM, 6 PM, 9 PM, 12 AM, 3 AM, 6 AM), the camera fixed on the sky and the plaza.",
			"The sun climbs from the horizon in the morning, is overhead at noon, sinks toward the other side by 6 PM with an orange sky; the sky turns dark blue with the moon's light by 9 PM and midnight, the lamps glow warm; the sky starts to brighten by 3 AM and 6 AM looks like the first thumbnail again. Brightness changes gradually between neighbours: no thumbnail pair that jumps from day to black.", 3)
	kit.day_night.paused = true
	kit.day_night.day_length_seconds = 720.0
	kit.day_night.set_time(10.0)
	print("SCREENSHOTS: %s/daynight/%s" % [kit.shots_base, kit.shots_stamp])
	kit.finish()
