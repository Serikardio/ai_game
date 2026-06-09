extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, RETREAT, DEAD }
enum { DOWN_RIGHT, UP_RIGHT, DOWN_LEFT, UP_LEFT }

@export var max_health: int = 50
@export var speed: float = 60.0
@export var chase_speed: float = 100.0
@export var detection_range: float = 150.0
@export var attack_range: float = 35.0
@export var damage: int = 15
@export var patrol_radius: float = 100.0

var health: int
var current_state = State.IDLE
var idle_dir = DOWN_RIGHT
var target: Node2D = null
var home_position: Vector2
var patrol_target: Vector2
var _idle_timer: float = 0.0
var _retreat_timer: float = 0.0
var is_dead: bool = false
var is_attacking: bool = false
var _aware: bool = false
var _aggro_cd: float = 0.0

const RETREAT_TIME = 0.7
const HURT_STUN_TIME = 0.25

const AGGRO_PHRASES = ["Агрх!", "Уааа!", "Уга-буга!", "Гррр!", "Чужак!", "Хрясь!", "Р-р-рав!"]

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_shape: CollisionShape2D = $"Hit-box/CollisionShape2D"
var chat_label: Label

func _ready():
	add_to_group("enemies")
	health = max_health
	home_position = global_position
	patrol_target = home_position
	hitbox_shape.disabled = true
	_idle_timer = randf_range(1.0, 3.0)
	_create_chat_label()

func _create_chat_label():
	chat_label = Label.new()
	chat_label.visible = false
	chat_label.position = Vector2(-40, -42)
	chat_label.scale = Vector2(0.5, 0.5)
	chat_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chat_label.custom_minimum_size = Vector2(160, 0)
	chat_label.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	chat_label.add_theme_color_override("font_outline_color", Color.BLACK)
	chat_label.add_theme_constant_override("outline_size", 6)
	add_child(chat_label)

func _bark():
	if _aggro_cd > 0:
		return
	_aggro_cd = 4.0
	_show_bark(AGGRO_PHRASES[randi() % AGGRO_PHRASES.size()])

func _show_bark(text: String):
	if not is_instance_valid(chat_label):
		return
	chat_label.text = text
	chat_label.visible = true
	await get_tree().create_timer(1.3).timeout
	if is_instance_valid(chat_label):
		chat_label.visible = false

func _physics_process(delta):
	if is_dead:
		return

	if _aggro_cd > 0:
		_aggro_cd -= delta

	_find_target()

	match current_state:
		State.IDLE:
			_handle_idle(delta)
		State.PATROL:
			_handle_patrol()
		State.CHASE:
			_handle_chase()
		State.RETREAT:
			_handle_retreat(delta)
		State.ATTACK:
			pass
		State.HURT:
			pass

	move_and_slide()

func _find_target():
	if is_attacking or current_state in [State.ATTACK, State.HURT, State.RETREAT, State.DEAD]:
		return
	var candidates = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("npc")
	var nearest: Node2D = null
	var nearest_dist := INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		if "is_dead" in c and c.is_dead:
			continue
		var d = global_position.distance_to(c.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = c

	if nearest and nearest_dist <= detection_range:
		if not _aware:
			_aware = true
			_bark()  # реплика в момент обнаружения цели
		target = nearest
		if nearest_dist <= attack_range:
			current_state = State.ATTACK
			_start_attack()
		else:
			current_state = State.CHASE
	else:
		target = null
		_aware = false
		if current_state == State.CHASE:
			current_state = State.IDLE
			_idle_timer = randf_range(1.0, 3.0)

func _handle_idle(delta):
	velocity = Vector2.ZERO
	_play_idle()
	_idle_timer -= delta
	if _idle_timer <= 0:
		patrol_target = home_position + Vector2(randf_range(-patrol_radius, patrol_radius), randf_range(-patrol_radius, patrol_radius))
		current_state = State.PATROL

func _handle_patrol():
	var dist = global_position.distance_to(patrol_target)
	if dist < 5.0:
		current_state = State.IDLE
		_idle_timer = randf_range(2.0, 4.0)
		velocity = Vector2.ZERO
		_play_idle()
		return
	var dir = global_position.direction_to(patrol_target)
	velocity = dir * speed
	_update_facing(dir)
	_play_walk()

func _handle_chase():
	if target == null or not is_instance_valid(target):
		current_state = State.IDLE
		return
	var dist = global_position.distance_to(target.global_position)
	if dist <= attack_range:
		velocity = Vector2.ZERO
		current_state = State.ATTACK
		_start_attack()
		return
	if dist > detection_range * 1.5:
		target = null
		current_state = State.IDLE
		_idle_timer = 1.0
		return
	var dir = global_position.direction_to(target.global_position)
	velocity = dir * chase_speed
	_update_facing(dir)
	_play_run()

func _start_attack():
	if is_attacking:
		return
	is_attacking = true
	velocity = Vector2.ZERO
	if target and is_instance_valid(target):
		var dir = global_position.direction_to(target.global_position)
		_update_facing(dir)
	hitbox_shape.disabled = true
	_position_hitbox()
	_play_attack()
	await get_tree().create_timer(0.25).timeout
	if is_dead:
		is_attacking = false
		return
	hitbox_shape.disabled = false
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		if not ("is_dead" in target and target.is_dead):
			if global_position.distance_to(target.global_position) <= attack_range + 12.0:
				target.take_damage(damage)
	await get_tree().create_timer(0.25).timeout
	hitbox_shape.disabled = true
	if is_dead:
		is_attacking = false
		return
	await anim.animation_finished
	is_attacking = false
	if is_dead:
		return
	if current_state == State.HURT:
		return
	_start_retreat()

func _start_retreat():
	_retreat_timer = RETREAT_TIME
	current_state = State.RETREAT

func _handle_retreat(delta):
	_retreat_timer -= delta
	if target == null or not is_instance_valid(target):
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return
	var away = target.global_position.direction_to(global_position)
	velocity = away * speed
	_update_facing(-away)
	_play_walk()
	if _retreat_timer <= 0:
		current_state = State.CHASE

func _position_hitbox():
	match idle_dir:
		DOWN_LEFT:  hitbox_shape.position = Vector2(12, 5)
		DOWN_RIGHT: hitbox_shape.position = Vector2(-12, 5)
		UP_LEFT:    hitbox_shape.position = Vector2(12, -10)
		UP_RIGHT:   hitbox_shape.position = Vector2(-12, -10)


func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	AudioManager.play_sfx(AudioManager.SFX_WOOD_HIT, 0.0, 0.2)
	_flash()
	if health <= 0:
		_die()
		return
	if current_state != State.HURT:
		is_attacking = false
		hitbox_shape.disabled = true
		current_state = State.HURT
		_play_hurt()
		await get_tree().create_timer(HURT_STUN_TIME).timeout
		if not is_dead and current_state == State.HURT:
			current_state = State.CHASE

func _die():
	is_dead = true
	current_state = State.DEAD
	hitbox_shape.disabled = true
	velocity = Vector2.ZERO
	_play_death()
	await anim.animation_finished
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	await tween.finished
	queue_free()

func _flash():
	var prev = anim.modulate
	anim.modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(anim):
		anim.modulate = prev

func _update_facing(dir: Vector2):
	if dir.x >= 0 and dir.y >= 0:
		idle_dir = DOWN_LEFT
	elif dir.x >= 0 and dir.y < 0:
		idle_dir = UP_LEFT
	elif dir.x < 0 and dir.y >= 0:
		idle_dir = DOWN_RIGHT
	else:
		idle_dir = UP_RIGHT

func _play_idle():
	match idle_dir:
		DOWN_RIGHT: anim.play("idle_down_right")
		UP_RIGHT:   anim.play("idle_up_right")
		DOWN_LEFT:  anim.play("idle_down_left")
		UP_LEFT:    anim.play("idle_up_left")

func _play_walk():
	match idle_dir:
		DOWN_RIGHT: anim.play("walk_down_right")
		UP_RIGHT:   anim.play("walk_up_right")
		DOWN_LEFT:  anim.play("walk_down_left")
		UP_LEFT:    anim.play("walk_up_left")

func _play_run():
	match idle_dir:
		DOWN_RIGHT: anim.play("run_down_right")
		UP_RIGHT:   anim.play("run_up_right")
		DOWN_LEFT:  anim.play("run_down_left")
		UP_LEFT:    anim.play("run_up_left")

func _play_attack():
	match idle_dir:
		DOWN_RIGHT: anim.play("attack_down_right")
		UP_RIGHT:   anim.play("attack_up_right")
		DOWN_LEFT:  anim.play("attack_down_left")
		UP_LEFT:    anim.play("attack_up_left")

func _play_hurt():
	match idle_dir:
		DOWN_RIGHT: anim.play("hurt_down_right")
		UP_RIGHT:   anim.play("hurt_up_right")
		DOWN_LEFT:  anim.play("hurt_down_left")
		UP_LEFT:    anim.play("hurt_up_left")

func _play_death():
	match idle_dir:
		DOWN_RIGHT: anim.play("death_down_right")
		UP_RIGHT:   anim.play("death_up_right")
		DOWN_LEFT:  anim.play("death_down_left")
		UP_LEFT:    anim.play("death_up_left")
