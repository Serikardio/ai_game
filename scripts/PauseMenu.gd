extends CanvasLayer

## Меню паузы. Открывается/закрывается по Escape (ui_cancel).
## Ставит игру на паузу и даёт кнопки: продолжить, сохранить, выйти в меню.

var is_open: bool = false
var _panel: Control
var _status_label: Label


func _ready():
	# Меню должно работать даже когда дерево на паузе
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	_panel.visible = false


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		var focus = get_viewport().gui_get_focus_owner()
		# Если игрок печатает команду — пусть Escape сначала уберёт фокус
		if not is_open and focus is LineEdit:
			focus.release_focus()
			get_viewport().set_input_as_handled()
			return
		toggle()
		get_viewport().set_input_as_handled()


func toggle():
	if is_open:
		close()
	else:
		open()


func open():
	is_open = true
	_status_label.text = ""
	_panel.visible = true
	get_tree().paused = true


func close():
	is_open = false
	_panel.visible = false
	get_tree().paused = false


# --- кнопки ---

func _on_resume():
	close()


func _on_save():
	if SaveManager.save_game():
		_status_label.text = "Игра сохранена"
	else:
		_status_label.text = "Не удалось сохранить"


func _on_quit_to_menu():
	SaveManager.save_game()  # автосохранение перед выходом
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# --- построение интерфейса ---

func _build_ui():
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	# Затемнение фона
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(dimmer)

	# Контейнер кнопок по центру
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.position = Vector2(-90, -120)
	vbox.custom_minimum_size = Vector2(180, 0)
	_panel.add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	vbox.add_child(_make_button("Продолжить", _on_resume))
	vbox.add_child(_make_button("Сохранить", _on_save))
	vbox.add_child(_make_button("Выйти в меню", _on_quit_to_menu))

	# Статус сохранения
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	vbox.add_child(_status_label)


func _make_button(text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 40)
	btn.pressed.connect(callback)
	return btn
