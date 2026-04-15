extends CanvasLayer

@onready var container = $NPCInventoryUI/Panel/VBoxContainer
@onready var item_template = $NPCInventoryUI/Panel/VBoxContainer/ItemTemplate

func _ready():
	print("NPCInventoryUI ready")
	item_template.visible = false

	NPCInventory.inventory_changed.connect(refresh_ui)

	visible = false
	$NPCInventoryUI.visible = true

	refresh_ui()

func _input(event):
	if event.is_action_pressed("ui_inventory"):
		visible = !visible
		print("NPCInventoryUI layer toggle: ", visible)
		if visible:
			refresh_ui()

func refresh_ui():
	print("NPCInventoryUI: Refreshing UI...")
	for child in container.get_children():
		if child != item_template:
			child.queue_free()

	var items = NPCInventory.get_items()
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
