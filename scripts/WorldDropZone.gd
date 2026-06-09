extends Control


var collectible_scene: PackedScene = preload("res://scenes/CollectibleItem.tscn")

func _ready():
	add_to_group("world_drop_zone")
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func activate():
	mouse_filter = Control.MOUSE_FILTER_STOP

func deactivate():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.has("item_id") and data.get("item_id") != ""

func _drop_data(_at_position, data):
	var item_id = data.get("item_id", "")
	var source = data.get("source", "")
	if item_id == "":
		return

	var quantity = data.get("quantity", 1)

	var item: Item = null
	if source == "player":
		item = Inventory.get_item(item_id)
		if item:
			Inventory.remove_item(item_id, quantity)
	elif source == "npc":
		item = NPCInventory.get_item(item_id)
		if item:
			NPCInventory.remove_item(item_id, quantity)

	if item == null:
		return

	for i in range(quantity):
		_spawn_collectible(item, source)

func _spawn_collectible(item: Item, source: String = "player"):
	var origin_node = _find_npc() if source == "npc" else _find_player()
	if origin_node == null:
		origin_node = _find_player()
	if origin_node == null:
		return

	var wrapper: Node2D
	if item.scene_path != "":
		wrapper = load(item.scene_path).instantiate()
	else:
		wrapper = Node2D.new()
		var collectible = collectible_scene.instantiate()
		collectible.item = item
		wrapper.add_child(collectible)
	origin_node.get_parent().add_child(wrapper)

	var spawn_pos = origin_node.global_position
	var land_offset = Vector2(randf_range(-50, 50), randf_range(-10, 30))
	var land_pos = spawn_pos + land_offset
	var jump_height = randf_range(20, 35)

	wrapper.global_position = spawn_pos
	wrapper.scale = Vector2.ONE

	var tween = wrapper.create_tween()
	tween.tween_method(func(t: float):
		var pos = spawn_pos.lerp(land_pos, t)
		pos.y -= sin(t * PI) * jump_height
		wrapper.global_position = pos
	, 0.0, 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	var bounce_offset = Vector2(randf_range(-10, 10), randf_range(-5, 5))
	var bounce_pos = land_pos + bounce_offset
	tween.tween_method(func(t: float):
		var pos = land_pos.lerp(bounce_pos, t)
		pos.y -= sin(t * PI) * jump_height * 0.3
		wrapper.global_position = pos
	, 0.0, 1.0, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _find_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null

func _find_npc() -> Node:
	var npcs = get_tree().get_nodes_in_group("npc")
	if npcs.size() > 0:
		return npcs[0]
	return null
