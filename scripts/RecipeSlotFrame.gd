extends Node2D

func _draw():
	var half = Vector2(10, 10)
	var color = Color(1, 1, 1, 0.5)
	# Background
	draw_rect(Rect2(-half, half * 2), Color(0, 0, 0, 0.4))
	# Border
	draw_rect(Rect2(-half, half * 2), color, false, 1.0)
