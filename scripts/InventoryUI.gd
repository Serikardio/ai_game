extends Control

@onready var container = $Panel/VBoxContainer
@onready var item_template = $Panel/VBoxContainer/ItemTemplate

func _ready():
	item_template.visible = false

	Inventory.inventory_changed.connect(refresh_ui)

	visible = false

	refresh_ui()

func _input(event):
	if event.is_action_pressed("ui_inventory"):
		visible = !visible
		if visible:
			refresh_ui()

func refresh_ui():
	for child in container.get_children():
		if child != item_template:
			child.queue_free()

	var items = Inventory.get_items()
	for entry in items:
		var item = entry.item
		var quantity = entry.quantity

		var slot = item_template.duplicate()
		slot.visible = true
		container.add_child(slot)

		var name_label = slot.get_node("NameLabel")
		var count_label = slot.get_node("CountLabel")
		var icon_rect = slot.get_node("Icon")

		name_label.text = item.name
		count_label.text = "x" + str(quantity)
		if item.icon:
			icon_rect.texture = item.icon
