@tool
extends Node2D


@export var grow_time: float = 30.0

var current_stage: int = 0
var is_harvested: bool = false
var grow_timer: float = 0.0

const STAGE_REGIONS = [
	Rect2(80, 16, 16, 16),
	Rect2(96, 16, 16, 16),
	Rect2(80, 32, 16, 16),
	Rect2(96, 32, 16, 16),
]

const WHEAT_DROP = preload("res://scenes/drops/Wheat.tscn")
var atlas_texture: Texture2D

@onready var sprite = $Sprite2D
@onready var collision = $Area2D/CollisionShape2D

func _ready():
	atlas_texture = load("res://assets/sprites/TestMap/Outdoor_Decor_Free.png")
	if Engine.is_editor_hint():
		current_stage = 3
		_update_sprite()
		return
	add_to_group("wheat")
	current_stage = randi_range(0, 3)
	grow_timer = randf_range(0, grow_time)
	_update_sprite()

func _process(delta):
	if Engine.is_editor_hint():
		return
	if is_harvested or current_stage >= 3:
		return
	grow_timer += delta
	if grow_timer >= grow_time:
		grow_timer = 0.0
		current_stage += 1
		_update_sprite()

func _update_sprite():
	if not sprite or not atlas_texture:
		return
	var tex = AtlasTexture.new()
	tex.atlas = atlas_texture
	tex.region = STAGE_REGIONS[current_stage]
	sprite.texture = tex

func can_harvest() -> bool:
	return not is_harvested and current_stage >= 3

func mine(damage):
	if Engine.is_editor_hint() or is_harvested:
		return
	if current_stage < 3:
		return

	is_harvested = true
	collision.set_deferred("disabled", true)

	var spawn_pos = global_position
	call_deferred("_drop_and_reset", spawn_pos)

func _drop_and_reset(spawn_pos):
	var parent = get_parent()
	if parent:
		var count = randi_range(1, 2)
		for i in range(count):
			var item = WHEAT_DROP.instantiate()
			parent.add_child(item)
			item.global_position = spawn_pos + Vector2(randf_range(-20, 20), randf_range(-5, 15))

	current_stage = 0
	grow_timer = 0.0
	is_harvested = false
	collision.set_deferred("disabled", false)
	_update_sprite()
