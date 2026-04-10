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

const DAMAGE = 10

signal started_attacking(direction)
signal tree_hit(tree)

var _wants_attack: bool = false

func _unhandled_input(event):
	if event.is_action_pressed("Attack") and not is_attacking:
		_wants_attack = true

func _ready():
	add_to_group("player")
	hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta):
	# Проверяем, не открыта ли командная строка или любой другой UI с фокусом
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

	# собираем направление
	if Input.is_action_pressed("Up"):
		dir.y -= 1
	if Input.is_action_pressed("Down"):
		dir.y += 1
	if Input.is_action_pressed("Left"):
		dir.x -= 1
	if Input.is_action_pressed("Right"):
		dir.x += 1

	# атака (обрабатывается в _unhandled_input)
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

	move_and_slide()


func pick_up(item) -> bool:
	if item:
		Inventory.add_item(item)
		return true
	return false


func run():
	speed = RUN_SPEED if Input.is_action_pressed("shift") else WALK_SPEED


func start_attack():
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


func _on_hitbox_area_entered(area):
	var obj = area.get_parent()
	if obj.has_method("mine"):
		obj.mine(DAMAGE)
		tree_hit.emit(obj)
