extends PanelContainer


const EDIBLE_ITEMS = {
	"wheat": 20,
}

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		var item_id = get_meta("item_id", "")
		var source = get_meta("source", "")
		if item_id in EDIBLE_ITEMS and source == "player":
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("eat_item"):
				player.eat_item(item_id)

func _get_drag_data(_at_position):
	var item_id = get_meta("item_id", "")
	var source = get_meta("source", "")
	var slot_index = get_meta("slot_index", -1)
	if item_id == "":
		return null

	var inv = Inventory if source == "player" else NPCInventory
	var slot_data = inv.get_slot(slot_index)
	if not slot_data:
		return null

	var total = slot_data.quantity
	var quantity = total
	if Input.is_key_pressed(KEY_CTRL):
		quantity = ceili(total / 2.0)

	var preview = TextureRect.new()
	var icon_rect = get_node_or_null("Icon")
	if icon_rect and icon_rect.texture:
		preview.texture = icon_rect.texture
		preview.custom_minimum_size = Vector2(48, 48)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)

	var zones = get_tree().get_nodes_in_group("world_drop_zone")
	if zones.size() > 0:
		zones[0].activate()

	return {"item_id": item_id, "source": source, "quantity": quantity, "slot_index": slot_index}

func _can_drop_data(_at_position, data):
	if not (data is Dictionary and data.has("item_id")):
		return false
	return true

func _drop_data(_at_position, data):
	var item_id = data.get("item_id", "")
	var drag_source = data.get("source", "")
	var quantity = data.get("quantity", 1)
	var from_slot = data.get("slot_index", -1)
	var my_source = get_meta("source", "")
	var to_slot = get_meta("slot_index", -1)
	if item_id == "":
		return

	if drag_source == my_source:
		var inv = Inventory if my_source == "player" else NPCInventory
		inv.swap_slots(from_slot, to_slot)
		return

	var from_inv = Inventory if drag_source == "player" else NPCInventory
	var to_inv = NPCInventory if drag_source == "player" else Inventory
	var item = from_inv.get_item(item_id)
	if item:
		from_inv.remove_item(item_id, quantity)
		for i in range(quantity):
			to_inv.add_item(item, to_slot)

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		var zones = get_tree().get_nodes_in_group("world_drop_zone")
		if zones.size() > 0:
			zones[0].deactivate()
