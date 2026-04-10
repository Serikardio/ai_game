extends Area2D

@export var item: Item

var overlapping_player = null
var prompt_label: Control
var _bob_time: float = 0.0
var _sprite: Node2D = null
var _sprite_base_y: float = 0.0

func _ready():
	add_to_group("collectibles")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_bob_time = randf() * TAU

	# Ищем спрайт: сначала соседа в родителе (Wood.tscn), потом дочерний (CollectibleItem.tscn)
	if get_parent():
		for child in get_parent().get_children():
			if child is Sprite2D and child.name != "shadow":
				_sprite = child
				_sprite_base_y = child.position.y
				break
	if not _sprite:
		var child_sprite = get_node_or_null("Sprite2D")
		if child_sprite:
			_sprite = child_sprite
			_sprite_base_y = child_sprite.position.y

	_create_prompt_label()

	if item and item.icon:
		var sprite_node = get_node_or_null("Sprite2D")
		if sprite_node:
			sprite_node.texture = item.icon

	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _process(delta):
	if _sprite:
		_bob_time += delta * 2.5
		_sprite.position.y = _sprite_base_y + sin(_bob_time) * 1.5

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
	var panel = PanelContainer.new()
	panel.visible = false
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.z_index = 2
	panel.position = Vector2(-6, -24)
	panel.custom_minimum_size = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.25)
	style.border_color = Color.WHITE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = "E"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.3, 0.3))
	label.add_theme_constant_override("outline_size", 2)
	panel.add_child(label)

	add_child(panel)
	prompt_label = panel
