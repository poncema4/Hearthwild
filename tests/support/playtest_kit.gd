class_name PlaytestKit
extends RefCounted
## Shared helpers for playtest scripts, so each scenario is a few lines
## instead of rebuilding the same setup. Used by agents' throwaway
## playtests (see .claude/agents/scout.md).
##
## Usage, in a script that extends SceneTree:
##
##   func _initialize() -> void:
##       _run.call_deferred()
##
##   func _run() -> void:
##       var kit := PlaytestKit.new(self)
##       await kit.load_world()
##       await kit.hold(["move_forward", "sprint"], 60)
##       kit.check("sprinted forward", kit.player.global_position.z < -5.0, kit.where())
##       kit.finish()

var tree: SceneTree
var world: Node
var player: PlayerController
var camera_rig: ThirdPersonCamera
var spring_arm: SpringArm3D
var failures := 0


func _init(scene_tree: SceneTree) -> void:
	tree = scene_tree


## Loads the main world scene and waits for the player to land.
func load_world(settle_frames: int = 60) -> void:
	world = load("res://scenes/world/world.tscn").instantiate()
	tree.root.add_child(world)
	player = world.get_node("Player")
	camera_rig = player.get_node("CameraRig")
	spring_arm = camera_rig.get_node("Pitch/SpringArm3D")
	await physics_frames(settle_frames)


## Puts the player at a position, standing still, and waits a moment.
func teleport(position: Vector3, settle_frames: int = 10) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	await physics_frames(settle_frames)


## Holds one or more input actions for a number of physics frames, then releases them.
func hold(actions: Array, frame_count: int) -> void:
	for action in actions:
		Input.action_press(action)
	await physics_frames(frame_count)
	for action in actions:
		Input.action_release(action)


## Taps an action for exactly one physics frame (e.g. a jump).
func tap(action: String) -> void:
	Input.action_press(action)
	await physics_frames(1)
	Input.action_release(action)


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func horizontal_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


## Player position and state as text, for check details.
func where() -> String:
	var p := player.global_position
	return "pos=(%.2f, %.2f, %.2f) speed=%.2f on_floor=%s" % [
		p.x, p.y, p.z, horizontal_speed(), player.is_on_floor()]


func check(name: String, ok: bool, detail := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + ("  (" + detail + ")" if detail else ""))
	if not ok:
		failures += 1


## Prints a measurement without judging it (for exploration).
func note(name: String, detail: String) -> void:
	print("NOTE " + name + "  (" + detail + ")")


## Saves a screenshot. Only works in a windowed run (not --headless).
func screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png(path)
	print("SHOT " + path)


func finish() -> void:
	print("RESULT: %s (%d failures)" % ["ALL PASS" if failures == 0 else "FAILED", failures])
	tree.quit(failures)
