extends CharacterBody2D

enum {
	DOWN,
	UP,
	LEFT,
	RIGHT,
	UP_LEFT,
	UP_RIGHT,
	DOWN_LEFT,
	DOWN_RIGHT
}

@onready var anim = $AnimatedSprite2D
@onready var animP = $AnimationPlayer
@onready var hitbox = $"Hit-box"
@onready var chat_label = $ChatLabel

var _chat_timer: SceneTreeTimer = null

const WALK_SPEED = 100
const RUN_SPEED = 200

var speed = WALK_SPEED
var idle_dir = DOWN
var is_attacking = false
var max_health: int = 100
var health: int = 100
var max_stamina: float = 100.0
var stamina: float = 100.0
var is_dead: bool = false

const DAMAGE = 10
const STAMINA_RUN_COST = 20.0
const STAMINA_ATTACK_COST = 15.0
const STAMINA_REGEN = 25.0
const STAMINA_REGEN_DELAY = 0.5
var _stamina_cooldown: float = 0.0

signal started_attacking(direction)
signal tree_hit(tree)
signal health_changed(new_health, max_health)
signal stamina_changed(new_stamina, max_stamina)

var _wants_attack: bool = false

func _unhandled_input(event):
	if event.is_action_pressed("Attack") and not is_attacking:
		_wants_attack = true

func _ready():
	add_to_group("player")
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if get_viewport().gui_get_focus_owner() != null:
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir = Vector2.ZERO
	run()

	if Input.is_action_pressed("Up"):
		dir.y -= 1
	if Input.is_action_pressed("Down"):
		dir.y += 1
	if Input.is_action_pressed("Left"):
		dir.x -= 1
	if Input.is_action_pressed("Right"):
		dir.x += 1

	if _wants_attack and !is_attacking:
		_wants_attack = false
		start_attack()
		return

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		velocity = dir * speed
		play_move_animation(dir)
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	if speed == RUN_SPEED and dir != Vector2.ZERO:
		stamina -= STAMINA_RUN_COST * delta
		_stamina_cooldown = STAMINA_REGEN_DELAY
		stamina = max(stamina, 0.0)
		stamina_changed.emit(stamina, max_stamina)
	else:
		_stamina_cooldown -= delta
		if _stamina_cooldown <= 0 and stamina < max_stamina:
			stamina += STAMINA_REGEN * delta
			stamina = min(stamina, max_stamina)
			stamina_changed.emit(stamina, max_stamina)

	move_and_slide()


const HEAL_AMOUNT = 20

func pick_up(item) -> bool:
	if item:
		Inventory.add_item(item)
		return true
	return false

func eat_item(item_id: String):
	if item_id == "wheat" and Inventory.get_item_count("wheat") > 0:
		Inventory.remove_item("wheat", 1)
		health = mini(health + HEAL_AMOUNT, max_health)
		health_changed.emit(health, max_health)
		show_chat_message("Ням! +" + str(HEAL_AMOUNT) + " HP")


func run():
	if Input.is_action_pressed("shift") and stamina > 0:
		speed = RUN_SPEED
	else:
		speed = WALK_SPEED


func start_attack():
	if stamina < STAMINA_ATTACK_COST:
		return
	stamina -= STAMINA_ATTACK_COST
	_stamina_cooldown = STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, max_stamina)
	is_attacking = true
	emit_signal("started_attacking", idle_dir)
	velocity = Vector2.ZERO

	match idle_dir:
		DOWN:
			animP.play("Attack_down")
		UP:
			animP.play("Attack_up")
		LEFT:
			animP.play("Attack_left")
		RIGHT:
			animP.play("Attack_right")
		UP_LEFT:
			animP.play("Attack_left_up")
		UP_RIGHT:
			animP.play("Attack_right_up")
		DOWN_LEFT:
			animP.play("Attack_left_down")
		DOWN_RIGHT:
			animP.play("Attack_right_down")

	await anim.animation_finished
	is_attacking = false


func play_move_animation(dir: Vector2):
	var is_running = Input.is_action_pressed("shift")

	if dir.y < 0 and dir.x == 0:
		anim.play("dash_up" if is_running else "up")
		idle_dir = UP

	elif dir.y > 0 and dir.x == 0:
		anim.play("dash_down" if is_running else "down")
		idle_dir = DOWN

	elif dir.x < 0 and dir.y == 0:
		anim.play("dash_left" if is_running else "left")
		idle_dir = LEFT

	elif dir.x > 0 and dir.y == 0:
		anim.play("dash_right" if is_running else "right")
		idle_dir = RIGHT

	elif dir.x < 0 and dir.y < 0:
		anim.play("dash_left_up" if is_running else "up_left")
		idle_dir = UP_LEFT

	elif dir.x > 0 and dir.y < 0:
		anim.play("dash_right_up" if is_running else "up_right")
		idle_dir = UP_RIGHT

	elif dir.x < 0 and dir.y > 0:
		anim.play("dash_left_down" if is_running else "down_left")
		idle_dir = DOWN_LEFT

	elif dir.x > 0 and dir.y > 0:
		anim.play("dash_right_down" if is_running else "down_right")
		idle_dir = DOWN_RIGHT


func play_idle_animation():
	match idle_dir:
		DOWN:
			anim.play("Idle_down")
		UP:
			anim.play("Idle_up")
		LEFT:
			anim.play("Idle_left")
		RIGHT:
			anim.play("Idle_right")
		UP_LEFT:
			anim.play("Idle_up_left")
		UP_RIGHT:
			anim.play("Idle_up_right")
		DOWN_LEFT:
			anim.play("Idle_down_left")
		DOWN_RIGHT:
			anim.play("Idle_down_right")


func show_chat_message(text: String, duration: float = 3.0):
	chat_label.add_theme_color_override("font_color", Color.WHITE)
	chat_label.scale = Vector2(0.25, 0.25)
	chat_label.visible = true
	chat_label.text = text
	chat_label.visible_ratio = 0.0
	var tween = create_tween()
	tween.tween_property(chat_label, "visible_ratio", 1.0, text.length() * 0.03)
	await tween.finished
	_chat_timer = get_tree().create_timer(duration)
	_chat_timer.timeout.connect(func(): chat_label.visible = false)


func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	health_changed.emit(health, max_health)
	_flash_damage()
	if health <= 0:
		health = 0
		is_dead = true
		_die()


func _die():
	velocity = Vector2.ZERO
	anim.modulate = Color(1, 1, 1, 0.5)
	show_chat_message("...")
	await get_tree().create_timer(2.0).timeout
	health = max_health
	is_dead = false
	anim.modulate = Color.WHITE
	health_changed.emit(health, max_health)


func _flash_damage():
	anim.modulate = Color(10, 0, 0)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(anim):
		anim.modulate = Color.WHITE


func _on_hitbox_area_entered(area):
	var obj = area.get_parent()
	if obj.has_method("mine"):
		obj.mine(DAMAGE)
		tree_hit.emit(obj)
	if obj.has_method("take_damage") and obj.is_in_group("enemies"):
		obj.take_damage(DAMAGE)
