extends CharacterBody2D

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
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
var is_dead: bool = false
var is_attacking: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_shape: CollisionShape2D = $"Hit-box/CollisionShape2D"

func _ready():
	add_to_group("enemies")
	health = max_health
	home_position = global_position
	patrol_target = home_position
	hitbox_shape.disabled = true
	_idle_timer = randf_range(1.0, 3.0)
	$"Hit-box".area_entered.connect(_on_hitbox_area_entered)
	$"Hit-box".body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta):
	if is_dead:
		return

	_find_target()

	match current_state:
		State.IDLE:
			_handle_idle(delta)
		State.PATROL:
			_handle_patrol()
		State.CHASE:
			_handle_chase()
		State.ATTACK:
			pass
		State.HURT:
			pass

	move_and_slide()

func _find_target():
	if is_attacking or current_state == State.ATTACK or current_state == State.HURT or current_state == State.DEAD:
		return
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_range:
			target = player
			if dist <= attack_range:
				current_state = State.ATTACK
				_start_attack()
			else:
				current_state = State.CHASE
		else:
			target = null
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
	await get_tree().create_timer(0.25).timeout
	hitbox_shape.disabled = true
	if is_dead:
		is_attacking = false
		return
	await anim.animation_finished
	is_attacking = false
	if is_dead:
		return
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
	is_attacking = false
	hitbox_shape.disabled = true
	_flash()
	if health <= 0:
		_die()
	else:
		current_state = State.HURT
		_play_hurt()
		await anim.animation_finished
		if not is_dead:
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

func _on_hitbox_area_entered(area):
	var body = area.get_parent()
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
