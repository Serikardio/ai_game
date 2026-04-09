extends Area2D

@export var item: Item

var overlapping_player = null
var prompt_label: Label

func _ready():
	add_to_group("collectibles")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_create_prompt_label()
	
	if item and item.icon:
		var sprite_node = get_node_or_null("Sprite2D")
		if sprite_node:
			sprite_node.texture = item.icon
			
	# Проверяем, нет ли уже кого-то в зоне (для моментального подбора при спавне)
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _input(event):
	if overlapping_player and event.is_action_pressed("Use"):
		# Принудительно заставляем только ОДИН предмет откликнуться на нажатие
		if not get_viewport().is_input_handled():
			_do_pickup(overlapping_player)
			get_viewport().set_input_as_handled()

func _on_body_entered(body):
	if body.is_in_group("npc"):
		# NPCs pick up automatically regardless of state
		_do_pickup(body)
	elif body.is_in_group("player"):
		overlapping_player = body
		if prompt_label:
			prompt_label.visible = true

func _on_body_exited(body):
	if body == overlapping_player:
		overlapping_player = null
		if prompt_label:
			prompt_label.visible = false

func _do_pickup(body):
	if body.has_method("pick_up"):
		if body.pick_up(item):
			print("Item ", item.name, " successfully picked up by ", body.name)
			get_parent().queue_free()

func _create_prompt_label():
	prompt_label = Label.new()
	prompt_label.text = "E"
	prompt_label.visible = false
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Позиционируем над предметом
	prompt_label.position = Vector2(-20, -35)
	prompt_label.size = Vector2(40, 20)
	
	# Небольшая стилизация для видимости
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.add_theme_font_size_override("font_size", 14)
	
	add_child(prompt_label)
