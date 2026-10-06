class_name WeaponIcon
extends Control
## A small drawn picture of one weapon for the weapon bar (a sword, a stone sword, a spear, an axe, a pistol), so a slot says what it holds at a glance
## without text. Drawn with plain polygons so it needs no image files and stays sharp at any UI scale.

var weapon_index := 0
var dim := false


func _init(index: int = 0) -> void:
	weapon_index = index
	custom_minimum_size = Vector2(52, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var alpha := 0.35 if dim else 1.0
	var steel := Color(0.85, 0.87, 0.92, alpha)
	var stone := Color(0.62, 0.62, 0.66, alpha)
	var wood := Color(0.60, 0.42, 0.26, alpha)
	var grip := Color(0.38, 0.26, 0.17, alpha)
	var dark := Color(0.16, 0.17, 0.20, alpha)
	match Weapons.def(weapon_index)["id"]:
		"wooden_sword":
			_blade(c, wood, grip)
		"stone_sword":
			_blade(c, stone, grip)
		"spear":
			draw_line(c + Vector2(-20, 9), c + Vector2(14, -7), wood, 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(12, -5), c + Vector2(22, -11), c + Vector2(17, -1)]), steel)
		"axe":
			draw_line(c + Vector2(-14, 11), c + Vector2(8, -9), wood, 3.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -13), c + Vector2(16, -9), c + Vector2(14, 3), c + Vector2(6, -3)]), steel)
		"pistol":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -7), c + Vector2(14, -7), c + Vector2(14, -1), c + Vector2(-2, -1), c + Vector2(-2, 2), c + Vector2(-16, 2)]), dark)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, 2), c + Vector2(-5, 2), c + Vector2(-8, 12), c + Vector2(-16, 12)]), grip)
			draw_rect(Rect2(c + Vector2(12, -9), Vector2(3, 2)), steel)


func _blade(c: Vector2, blade_color: Color, grip_color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 3), c + Vector2(17, -14), c + Vector2(20, -11), c + Vector2(2, 6)]), blade_color)
	draw_line(c + Vector2(-9, 4), c + Vector2(3, 10), grip_color, 3.0)  # the guard
	draw_line(c + Vector2(-8, 11), c + Vector2(-1, 5), grip_color, 3.5)  # the handle
