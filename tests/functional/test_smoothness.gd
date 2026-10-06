extends SceneTree
## Functional test: movement and the camera are SMOOTH. Physics runs at a lower rate than the picture (here 30 physics ticks against 60 drawn frames; on
## a real 144 Hz monitor it is 60 against 144), so without interpolation the player and camera move in jerks: still on one frame, double speed on
## the next. This sprints for two seconds and measures how even the camera's motion is from one drawn frame to the next.
##
## Run: godot --headless --path . --fixed-fps 60 --script res://tests/functional/test_smoothness.gd
## Exit code = number of failures (0 = all pass).

var kit: PlaytestKit


func _initialize() -> void:
	_run.call_deferred()


## Runs `frames` drawn frames while `keys` are held and returns the per-frame distances moved by the camera and by the character model.
func _sprint(frames: int) -> Dictionary:
	var camera := kit.spring_arm.get_node("Camera3D") as Camera3D
	var model := kit.player.get_node("Body/Model") as Node3D
	var camera_steps: Array[float] = []
	var model_steps: Array[float] = []
	var last_camera := camera.global_position
	var last_model := model.get_global_transform_interpolated().origin
	for i in frames:
		await kit.frames(1)
		var now_camera := camera.global_position
		# What is DRAWN: `global_position` always reports the raw physics transform; the engine interpolates only the rendered one.
		var now_model := model.get_global_transform_interpolated().origin
		if i >= 40:  # after the start-up
			camera_steps.append(now_camera.distance_to(last_camera))
			model_steps.append(now_model.distance_to(last_model))
		last_camera = now_camera
		last_model = now_model
	return {"camera": camera_steps, "model": model_steps}


## (largest step - smallest step) / average step: 0 is perfectly even; a jerky 30-on-60 gives about 2.
func _unevenness(steps: Array[float]) -> float:
	var smallest := 1e9
	var largest := 0.0
	var total := 0.0
	for step in steps:
		smallest = minf(smallest, step)
		largest = maxf(largest, step)
		total += step
	var average := total / float(steps.size())
	return (largest - smallest) / maxf(average, 0.0001)


func _run() -> void:
	kit = PlaytestKit.new(self)
	await kit.load_world()
	kit.check("physics interpolation is switched on for the project", ProjectSettings.get_setting("physics/common/physics_interpolation", false) == true)
	kit.check("the camera rig is not interpolated itself (it turns with the mouse between ticks) and follows the player every drawn frame", kit.camera_rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF and kit.camera_rig.top_level)
	Engine.physics_ticks_per_second = 30  # half the drawn rate: every other drawn frame has no new physics step
	var arena := kit.find_open_arena(50.0, 0.2)  # a two-second sprint needs 14 m of open meadow, and the village now fills the spawn area
	await kit.teleport(Vector3(arena.x, NAN, arena.y), 20)
	kit.face(Vector3(0, 0, -1))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var run := await _sprint(150)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	Engine.physics_ticks_per_second = 60
	var camera_steps: Array[float] = run["camera"]
	var model_steps: Array[float] = run["model"]
	var camera_uneven := _unevenness(camera_steps)
	var model_uneven := _unevenness(model_steps)
	var mean_step := 0.0
	for step in camera_steps:
		mean_step += step
	mean_step /= float(camera_steps.size())
	kit.check("the sprint really moved the camera (about 7 m/s = 0.117 m per drawn frame)", mean_step > 0.09 and mean_step < 0.14, "mean %.3f m per frame" % mean_step)
	kit.check("the camera glides: its motion is even from one drawn frame to the next even with physics at half the frame rate (unevenness under 0.3; without interpolation it is about 2)", camera_uneven < 0.3, "unevenness %.2f" % camera_uneven)
	kit.check("and so does the character model (unevenness under 0.3)", model_uneven < 0.3, "unevenness %.2f" % model_uneven)
	kit.finish()
