extends Control

## UI трекер активного квеста — показывается под HP/стаминой.

var labels: Dictionary = {}
var title_label: Label

func _ready():
	QuestManager.quest_updated.connect(_refresh)
	Inventory.inventory_changed.connect(_on_inventory_changed)
	_build_ui()
	visible = false

func _build_ui():
	var panel = PanelContainer.new()
	panel.position = Vector2(10, 120)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.7)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.text = "Задание"
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(title_label)

	for obj_id in QuestManager.objectives:
		var obj = QuestManager.objectives[obj_id]
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(lbl)
		labels[obj_id] = lbl

	add_child(panel)

func _on_inventory_changed():
	_refresh()

func _refresh():
	visible = QuestManager.quest_active and not QuestManager.quest_complete

	for obj_id in labels:
		var obj = QuestManager.objectives[obj_id]
		var lbl = labels[obj_id] as Label
		var prefix = "[V] " if obj.done else "[ ] "
		lbl.text = prefix + obj.name + "  " + str(obj.current) + "/" + str(obj.required)
		lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3) if obj.done else Color(0.8, 0.8, 0.8))
