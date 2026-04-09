extends Node2D

@export var size: Vector2 = Vector2(44, 44)
@export var corner_length: float = 10.0
@export var line_width: float = 2.5
@export var color: Color = Color(1, 1, 1, 0.9)

func _draw():
	var half = size / 2
	var cl = corner_length

	# Верхний левый
	draw_line(Vector2(-half.x, -half.y), Vector2(-half.x + cl, -half.y), color, line_width)
	draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, -half.y + cl), color, line_width)

	# Верхний правый
	draw_line(Vector2(half.x, -half.y), Vector2(half.x - cl, -half.y), color, line_width)
	draw_line(Vector2(half.x, -half.y), Vector2(half.x, -half.y + cl), color, line_width)

	# Нижний левый
	draw_line(Vector2(-half.x, half.y), Vector2(-half.x + cl, half.y), color, line_width)
	draw_line(Vector2(-half.x, half.y), Vector2(-half.x, half.y - cl), color, line_width)

	# Нижний правый
	draw_line(Vector2(half.x, half.y), Vector2(half.x - cl, half.y), color, line_width)
	draw_line(Vector2(half.x, half.y), Vector2(half.x, half.y - cl), color, line_width)
