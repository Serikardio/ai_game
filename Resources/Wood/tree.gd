extends Node2D

var health = 30
var is_cut = false
var hit_tween: Tween

@onready var sprite = $OakTree
@onready var collision = $Area2D/CollisionShape2D

const WOOD_SCENE = preload("res://scenes/drops/Wood.tscn")

func _ready():
	add_to_group("trees")

func mine(damage):
	if is_cut:
		return

	health -= damage
	print("Удар по дереву. Осталось HP: ", health)
	AudioManager.play_sfx(AudioManager.SFX_WOOD_HIT, 0.0, 0.15)
	flash()

	if health <= 0:
		cut_tree()


func flash():
	if hit_tween:
		hit_tween.kill() # Останавливаем предыдущую анимацию если она была
	
	hit_tween = create_tween()
	sprite.modulate = Color(10, 10, 10) # Белое свечение (Raw Color)
	hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func cut_tree():
	if is_cut:
		return
	is_cut = true
	
	# СРАЗУ отключаем коллизию, чтобы избежать лишних сигналов и зависаний
	collision.set_deferred("disabled", true)
	print("Дерево уничтожено, спавню лут")
	
	# Запоминаем позицию ДО удаления дерева
	var spawn_pos = global_position
	# Передаем позицию в отложенный вызов
	call_deferred("_drop_items_deferred", spawn_pos)
	queue_free()


func _drop_items_deferred(spawn_pos):
	var parent = get_parent()
	if not parent:
		return

	# Позиции персонажей для отталкивания
	var bodies: Array[Vector2] = []
	for g in ["player", "npc"]:
		for b in get_tree().get_nodes_in_group(g):
			bodies.append(b.global_position)

	var count = randi_range(1, 3)
	for i in range(count):
		var wood = WOOD_SCENE.instantiate()
		parent.add_child(wood)

		wood.global_position = spawn_pos
		wood.scale = Vector2.ONE

		var land_offset = Vector2(randf_range(-50, 50), randf_range(-10, 30))
		var land_pos = spawn_pos + land_offset

		# Отталкиваем от персонажей
		for body_pos in bodies:
			var dist = land_pos.distance_to(body_pos)
			if dist < 30.0 and dist > 0.1:
				var push = (land_pos - body_pos).normalized() * (30.0 - dist)
				land_pos += push

		var jump_height = randf_range(20, 35)

		var tween = wood.create_tween()
		tween.tween_method(func(t: float):
			var pos = spawn_pos.lerp(land_pos, t)
			pos.y -= sin(t * PI) * jump_height
			wood.global_position = pos
		, 0.0, 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

		var bounce_offset = Vector2(randf_range(-10, 10), randf_range(-5, 5))
		var bounce_pos = land_pos + bounce_offset
		tween.tween_method(func(t: float):
			var pos = land_pos.lerp(bounce_pos, t)
			pos.y -= sin(t * PI) * jump_height * 0.3
			wood.global_position = pos
		, 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
