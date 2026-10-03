class_name WorldClock
extends Node3D
## A clock you can read in the world: the hour and minute hands turn with the
## game time (`DayNight`). Built by `VillageProps.clock_post()`; the hands are the
## children `HourHand` and `MinuteHand` (pivots at the centre of the face, the face
## looks toward local +Z, hands turn clockwise as seen from the front).


func _physics_process(_delta: float) -> void:
	var day_night := get_tree().get_first_node_in_group(&"day_night") as DayNight
	if day_night == null:
		return
	var hours := fmod(day_night.hour, 12.0)
	get_node("HourHand").rotation.z = -deg_to_rad(hours / 12.0 * 360.0)
	get_node("MinuteHand").rotation.z = -deg_to_rad(fmod(day_night.hour, 1.0) * 360.0)


## Where the hands point now, in degrees clockwise from 12 o'clock: (hour hand, minute hand).
func hand_angles_degrees() -> Vector2:
	return Vector2(fposmod(-rad_to_deg(get_node("HourHand").rotation.z), 360.0), fposmod(-rad_to_deg(get_node("MinuteHand").rotation.z), 360.0))
