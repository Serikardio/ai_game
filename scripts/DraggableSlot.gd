extends PanelContainer

## Hotbar slot that supports drag-and-drop.
## Drag = whole stack. Ctrl+Drag = half stack.

func _get_drag_data(_at_position):
	var item_id = get_meta("item_id", "")
	var source = get_meta("source", "")
	if item_id == "":
		return null

	# Get full stack quantity
	var total = 0
	if source == "player":
		total = Inventory.get_item_count(item_id)
	elif source == "npc":
		total = NPCInventory.get_item_count(item_id)

	# Ctrl = half stack
	var quantity = total
	if Input.is_key_pressed(KEY_CTRL):
		quantity = ceili(total / 2.0)

	# Build drag preview
	var preview = TextureRect.new()
	var icon_rect = get_node_or_null("Icon")
	if icon_rect and icon_rect.texture:
		preview.texture = icon_rect.texture
		preview.custom_minimum_size = Vector2(48, 48)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)

	# Activate world drop zone
	var zones = get_tree().get_nodes_in_group("world_drop_zone")
	if zones.size() > 0:
		zones[0].activate()

	return {"item_id": item_id, "source": source, "quantity": quantity}

# Accept drops from the OPPOSITE inventory
func _can_drop_data(_at_position, data):
	if not (data is Dictionary and data.has("item_id")):
		return false
	var my_source = get_meta("source", "")
	var drag_source = data.get("source", "")
	return my_source != "" and drag_source != "" and my_source != drag_source

func _drop_data(_at_position, data):
	var item_id = data.get("item_id", "")
	var drag_source = data.get("source", "")
	var quantity = data.get("quantity", 1)
	if item_id == "":
		return

	if drag_source == "npc":
		var item = NPCInventory.get_item(item_id)
		if item:
			NPCInventory.remove_item(item_id, quantity)
			for i in range(quantity):
				Inventory.add_item(item)
	elif drag_source == "player":
		var item = Inventory.get_item(item_id)
		if item:
			Inventory.remove_item(item_id, quantity)
			for i in range(quantity):
				NPCInventory.add_item(item)

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		var zones = get_tree().get_nodes_in_group("world_drop_zone")
		if zones.size() > 0:
			zones[0].deactivate()
