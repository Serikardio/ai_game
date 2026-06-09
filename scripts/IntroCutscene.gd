extends CanvasLayer

## Вступительная катсцена с диалогом тотемов.

signal cutscene_finished

const C_FIRE := Color(1, 0.5, 0.2)      # Огненный тотем
const C_WISE := Color(0.6, 0.4, 1)      # Тотем мудрости
const C_ALLY := Color(0.4, 0.9, 0.7)    # Помощник

var dialog = [
	{"speaker": "Огненный тотем", "color": C_FIRE, "text": "Ты очнулся, странник. Добро пожаловать в Мир Испытаний."},
	{"speaker": "Тотем мудрости", "color": C_WISE, "text": "Сюда попадают те, кому некуда возвращаться. И те, кто потерял себя."},
	{"speaker": "Огненный тотем", "color": C_FIRE, "text": "Чтобы уйти отсюда, нужно восстановить древний ритуал. Принеси нам дары этого мира."},
	{"speaker": "Тотем мудрости", "color": C_WISE, "text": "Три слитка золота, три блока камня и шесть брёвен. И разведи ритуальный костёр у наших ног."},
	{"speaker": "Огненный тотем", "color": C_FIRE, "text": "Ты здесь не один. Рядом с тобой — Помощник. Он служит этому месту дольше, чем ты можешь представить."},
	{"speaker": "Помощник", "color": C_ALLY, "text": "Я... не помню, как тут оказался. И не помню своего имени. Но я помогу тебе — почему-то это важно для меня."},
	{"speaker": "Тотем мудрости", "color": C_WISE, "text": "Когда ритуал свершится, врата откроются. Иди, странник. Время здесь течёт не для всех одинаково."},
]

var current_line: int = 0
var is_typing: bool = false
var panel: PanelContainer
var speaker_label: Label
var text_label: Label
var skip_label: Label

func _ready():
	layer = 10
	_build_ui()
	_show_line()

func _build_ui():
	# Затемнение
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	# Панель диалога внизу
	panel = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.7
	panel.anchor_bottom = 0.9
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
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

	# Подсказка "Нажми пробел"
	skip_label = Label.new()
	skip_label.text = "[ Пробел — продолжить ]"
	skip_label.add_theme_font_size_override("font_size", 10)
	skip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(skip_label)

	add_child(panel)

func _show_line():
	if current_line >= dialog.size():
		_end_cutscene()
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
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			if is_typing:
				# Скип печати — показать всё сразу
				text_label.visible_ratio = 1.0
				is_typing = false
			else:
				current_line += 1
				_show_line()
			get_viewport().set_input_as_handled()

func _end_cutscene():
	QuestManager.start_quest()
	cutscene_finished.emit()
	queue_free()
