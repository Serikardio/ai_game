extends Node2D

var health = 30
var is_cut = false
var hit_tween: Tween

@onready var sprite = $OakTree
@onready var collision = $Area2D/CollisionShape2D

const WOOD_SCENE = preload("res://scenes/Wood.tscn")

func _ready():
	add_to_group("trees")

func mine(damage):
	if is_cut:
		return
		
	health -= damage
	print("Удар по дереву. Осталось HP: ", health)
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
		
	var count = randi_range(1, 3)
	for i in range(count):
		var wood = WOOD_SCENE.instantiate()
		parent.add_child(wood)
		
		# Начальная позиция — в центре дерева, масштаб 0
		wood.global_position = spawn_pos
		wood.scale = Vector2.ZERO
		
		# Конечная позиция с разлётом
		var offset = Vector2(randf_range(-30, 30), randf_range(-20, 20))
		var target_pos = spawn_pos + offset
		
		# Анимация разлёта через Tween
		var tween = wood.create_tween()
		tween.set_parallel(true)
		
		# Масштаб: 0 -> 1.3 -> 1.0 (эффект резкого появления с отпружиниванием)
		tween.tween_property(wood, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(wood, "scale", Vector2.ONE, 0.15).set_delay(0.2)
		
		# Позиция: летит в сторону
		tween.tween_property(wood, "global_position", target_pos, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
