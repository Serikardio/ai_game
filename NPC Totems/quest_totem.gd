extends Node2D


@export var totem_name: String = "Тотем"
@export var quest_item_id: String = "gold"
@export var quest_amount: int = 3
@export var quest_description: String = "Принеси мне 3 золота"
@export var quest_reward_text: String = "Спасибо! Вот твоя награда."

var quest_active: bool = false
var quest_completed: bool = false
var overlapping_player = null

var prompt_label: Control
var chat_label: Label

func _ready():
	add_to_group("quest_totems")
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)
	_create_ui()

func _create_ui():
	var prompt_panel = PanelContainer.new()
	prompt_panel.visible = false
	prompt_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt_panel.z_index = 2
	prompt_panel.position = Vector2(-6, -24)
	prompt_panel.custom_minimum_size = Vector2(12, 12)
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(1, 1, 1, 0.25)
	pstyle.border_color = Color.WHITE
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(2)
	pstyle.content_margin_left = 2
	pstyle.content_margin_right = 2
	pstyle.content_margin_top = 1
	pstyle.content_margin_bottom = 1
	prompt_panel.add_theme_stylebox_override("panel", pstyle)

	var plabel = Label.new()
	plabel.text = "E"
	plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plabel.add_theme_font_size_override("font_size", 8)
	plabel.add_theme_color_override("font_color", Color.WHITE)
	plabel.add_theme_color_override("font_outline_color", Color(0.3, 0.3, 0.3))
	plabel.add_theme_constant_override("outline_size", 2)
	prompt_panel.add_child(plabel)

	add_child(prompt_panel)
	prompt_label = prompt_panel

	var name_label = Label.new()
	name_label.text = totem_name
	name_label.position = Vector2(-50, -26)
	name_label.scale = Vector2(0.5, 0.5)
	name_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(200, 0)
	add_child(name_label)

	chat_label = Label.new()
	chat_label.visible = false
	chat_label.position = Vector2(-50, -40)
	chat_label.scale = Vector2(0.5, 0.5)
	chat_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	chat_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(chat_label)

func _input(event):
	if overlapping_player and event.is_action_pressed("Use"):
		_interact()

func _on_body_entered(body):
	if body.is_in_group("player"):
		overlapping_player = body
		prompt_label.visible = true

func _on_body_exited(body):
	if body == overlapping_player:
		overlapping_player = null
		prompt_label.visible = false

func _interact():
	if not QuestManager.quest_active:
		_show_message("...")
		return

	if QuestManager.quest_complete:
		_show_message("Вы свободны! Отличная работа!")
		return

	var delivered = QuestManager.deliver_items()
	if delivered.size() > 0:
		_show_message("Принято: " + ", ".join(delivered))
	else:
		_show_message(QuestManager.get_remaining_text())

func _show_message(text: String, duration: float = 4.0):
	chat_label.add_theme_color_override("font_color", Color.WHITE)
	chat_label.scale = Vector2(0.5, 0.5)
	chat_label.visible = true
	chat_label.text = text
	chat_label.visible_ratio = 0.0
	var tween = create_tween()
	tween.tween_property(chat_label, "visible_ratio", 1.0, text.length() * 0.03)
	await tween.finished
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(chat_label):
		chat_label.visible = false
