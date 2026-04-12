@tool
extends Node2D

## Добываемый объект со стадиями разрушения (камень, золото).
## Каждая стадия — отдельный спрайт из тайлсета.
## При переходе на следующую стадию выбрасывает ресурс.
## Когда стадии заканчиваются — объект уничтожен.

@export var stage_hp: int = 10           # HP на каждую стадию
@export var drop_scene: PackedScene
@export var drop_per_stage_min: int = 1
@export var drop_per_stage_max: int = 1
@export var group_name: String = "rocks"

# Координаты стадий в тайлсете (заполняются в наследниках или из сцены)
@export var stage_regions: Array[Rect2] = []

var current_stage: int = 0
var stage_health: int = 0
var is_mined: bool = false
var hit_tween: Tween
var atlas_texture: Texture2D

@onready var sprite = $Sprite2D
@onready var collision = $Area2D/CollisionShape2D

func _ready():
	atlas_texture = load("res://assets/sprites/TestMap/Outdoor_Decor_Free.png")
	_update_sprite()
	if Engine.is_editor_hint():
		return
	add_to_group(group_name)
	stage_health = stage_hp


func mine(damage):
	if Engine.is_editor_hint() or is_mined:
		return

	stage_health -= damage
	print("Удар по ", group_name, " стадия ", current_stage + 1, "/", stage_regions.size(), " HP: ", stage_health)
	AudioManager.play_sfx(AudioManager.SFX_WOOD_HIT, 0.0, 0.2)
	flash()

	if stage_health <= 0:
		_next_stage()


func _next_stage():
	# Выбрасываем ресурс за эту стадию
	_drop_items(global_position)

	current_stage += 1

	if current_stage >= stage_regions.size():
		# Все стадии пройдены — уничтожаем
		is_mined = true
		collision.set_deferred("disabled", true)
		queue_free()
		return

	# Переходим на следующую стадию
	stage_health = stage_hp
	_update_sprite()


func _update_sprite():
	if current_stage >= stage_regions.size():
		return
	var tex = AtlasTexture.new()
	tex.atlas = atlas_texture
	tex.region = stage_regions[current_stage]
	sprite.texture = tex


func flash():
	if hit_tween:
		hit_tween.kill()
	hit_tween = create_tween()
	sprite.modulate = Color(10, 10, 10)
	hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func _drop_items(spawn_pos: Vector2):
	var parent = get_parent()
	if not parent or not drop_scene:
		return

	# Собираем позиции персонажей для отталкивания
	var bodies: Array[Vector2] = []
	for g in ["player", "npc"]:
		for b in get_tree().get_nodes_in_group(g):
			bodies.append(b.global_position)

	var count = randi_range(drop_per_stage_min, drop_per_stage_max)
	for i in range(count):
		var item = drop_scene.instantiate()
		parent.add_child(item)
		item.global_position = spawn_pos
		item.scale = Vector2.ONE

		var land_offset = Vector2(randf_range(-30, 30), randf_range(-10, 20))
		var land_pos = spawn_pos + land_offset

		# Отталкиваем точку приземления от персонажей
		for body_pos in bodies:
			var dist = land_pos.distance_to(body_pos)
			if dist < 30.0 and dist > 0.1:
				var push = (land_pos - body_pos).normalized() * (30.0 - dist)
				land_pos += push

		var jump_height = randf_range(15, 25)

		var tween = item.create_tween()
		tween.tween_method(func(t: float):
			var pos = spawn_pos.lerp(land_pos, t)
			pos.y -= sin(t * PI) * jump_height
			item.global_position = pos
		, 0.0, 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

		var bounce_offset = Vector2(randf_range(-6, 6), randf_range(-3, 3))
		var bounce_pos = land_pos + bounce_offset
		tween.tween_method(func(t: float):
			var pos = land_pos.lerp(bounce_pos, t)
			pos.y -= sin(t * PI) * jump_height * 0.2
			item.global_position = pos
		, 0.0, 1.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
