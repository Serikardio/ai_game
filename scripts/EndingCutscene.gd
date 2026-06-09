extends CanvasLayer


const C_FIRE := Color(1, 0.5, 0.2)
const C_WISE := Color(0.6, 0.4, 1)
const C_ALLY := Color(0.4, 0.9, 0.7)

var dialog = [
	{"speaker": "Огненный тотем", "color": C_FIRE, "text": "Ритуал свершён. Врата открыты, странник."},
	{"speaker": "Тотем мудрости", "color": C_WISE, "text": "Перед тобой — путь домой. Ты прошёл то, что ломало многих."},
	{"speaker": "Помощник", "color": C_ALLY, "text": "Иди. А я... останусь. Я наконец вспомнил всё."},
	{"speaker": "Помощник", "color": C_ALLY, "text": "Однажды я стоял здесь, как ты. Но я не дошёл. И остался — помогать тем, кто придёт после."},
	{"speaker": "Огненный тотем", "color": C_FIRE, "text": "Сквозь врата пройдёт лишь одна живая душа. А он давно не из живых."},
	{"speaker": "Помощник", "color": C_ALLY, "text": "Не печалься. Впервые за сотни лет кто-то дошёл до конца. Мы дошли — вместе."},
	{"speaker": "Помощник", "color": C_ALLY, "text": "Иди домой, друг. И помни: здесь ты был не один. Этого достаточно, чтобы я был свободен."},
	{"speaker": "Тотем мудрости", "color": C_WISE, "text": "Прощай, странник. Свет да хранит твой путь."},
]

var current_line: int = 0
var is_typing: bool = false
var panel: PanelContainer
var speaker_label: Label
var text_label: Label
var skip_label: Label
var _ended: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	get_tree().paused = true
	_build_ui()
	_show_line()


func _build_ui():
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	panel = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.7
	panel.anchor_bottom = 0.9

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(speaker_label)

	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 14)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(text_label)

	skip_label = Label.new()
	skip_label.text = "[ Пробел — продолжить ]"
	skip_label.add_theme_font_size_override("font_size", 10)
	skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(skip_label)

	add_child(panel)


func _show_line():
	if current_line >= dialog.size():
		_show_ending_screen()
		return

	var line = dialog[current_line]
	speaker_label.text = line.speaker
	speaker_label.add_theme_color_override("font_color", line.color)
	text_label.text = line.text
	text_label.visible_ratio = 0.0

	is_typing = true
	var tween = create_tween()
	tween.tween_property(text_label, "visible_ratio", 1.0, line.text.length() * 0.03)
	await tween.finished
	is_typing = false


func _unhandled_input(event):
	if _ended:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if is_typing:
				text_label.visible_ratio = 1.0
				is_typing = false
			else:
				current_line += 1
				_show_line()
			get_viewport().set_input_as_handled()


func _show_ending_screen():
	_ended = true
	panel.visible = false

	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.position = Vector2(-150, -80)
	center.custom_minimum_size = Vector2(300, 0)
	center.add_theme_constant_override("separation", 16)
	add_child(center)

	var title = Label.new()
	title.text = "Странник вернулся домой."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.custom_minimum_size = Vector2(300, 0)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	center.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "А его спутник наконец обрёл покой."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.custom_minimum_size = Vector2(300, 0)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.8, 0.8))
	center.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer)

	var the_end = Label.new()
	the_end.text = "КОНЕЦ"
	the_end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	the_end.add_theme_font_size_override("font_size", 28)
	center.add_child(the_end)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	center.add_child(spacer2)

	var btn = Button.new()
	btn.text = "В главное меню"
	btn.custom_minimum_size = Vector2(200, 40)
	btn.pressed.connect(_on_return_to_menu)
	center.add_child(btn)

	center.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(center, "modulate", Color.WHITE, 1.0)


func _on_return_to_menu():
	SaveManager.delete_save()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
