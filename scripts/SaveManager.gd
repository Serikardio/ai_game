extends Node


const SAVE_PATH = "user://savegame.cfg"

const ITEM_PATHS = {
	"wood": "res://Resources/Wood/wood_item.tres",
	"stone": "res://Resources/Stone/stone_item.tres",
	"stone_block": "res://Resources/Stone/stone_block_item.tres",
	"gold": "res://Resources/Gold/gold_item.tres",
	"gold_block": "res://Resources/Gold/gold_block_item.tres",
	"wheat": "res://Resources/Wheat/wheat_item.tres",
}

const WORLD_GROUPS = ["trees", "rocks", "gold_ores", "campspot"]

const CAMPFIRE_SCENE_PATH = "res://camp_fire.tscn"

var cutscene_seen: bool = false

var _pending: Dictionary = {}
var _has_pending: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var cfg = ConfigFile.new()

	cfg.set_value("inventory", "slots", _serialize_slots(Inventory.slots))
	cfg.set_value("npc_inventory", "slots", _serialize_slots(NPCInventory.slots))

	var quest = {}
	for obj_id in QuestManager.objectives:
		var o = QuestManager.objectives[obj_id]
		quest[obj_id] = {"current": o.current, "done": o.done}
	cfg.set_value("quest", "objectives", quest)
	cfg.set_value("quest", "active", QuestManager.quest_active)
	cfg.set_value("quest", "complete", QuestManager.quest_complete)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		cfg.set_value("player", "pos_x", player.global_position.x)
		cfg.set_value("player", "pos_y", player.global_position.y)
		cfg.set_value("player", "health", player.health)
		cfg.set_value("player", "stamina", player.stamina)

	var npc = get_tree().get_first_node_in_group("npc")
	if npc:
		cfg.set_value("npc", "pos_x", npc.global_position.x)
		cfg.set_value("npc", "pos_y", npc.global_position.y)

	cfg.set_value("world", "alive_objects", _collect_alive_objects())
	cfg.set_value("world", "campfires", _collect_campfires())
	cfg.set_value("world", "drops", _collect_drops())

	cfg.set_value("flags", "cutscene_seen", cutscene_seen)

	return cfg.save(SAVE_PATH) == OK


func _collect_alive_objects() -> Array:
	var keys = []
	var root = get_tree().current_scene
	if not root:
		return keys
	for g in WORLD_GROUPS:
		for node in get_tree().get_nodes_in_group(g):
			if is_instance_valid(node):
				keys.append(str(root.get_path_to(node)))
	return keys


func _collect_campfires() -> Array:
	var out = []
	for fire in get_tree().get_nodes_in_group("campfires"):
		if is_instance_valid(fire):
			out.append({"x": fire.global_position.x, "y": fire.global_position.y})
	return out


func _collect_drops() -> Array:
	var out = []
	for c in get_tree().get_nodes_in_group("collectibles"):
		if not is_instance_valid(c) or not c.item:
			continue
		var path = c.item.scene_path
		if path == "":
			continue
		var node = c.get_parent() if c.get_parent() else c
		out.append({"scene": path, "x": node.global_position.x, "y": node.global_position.y})
	return out


func load_game() -> bool:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false

	Inventory.slots = _deserialize_slots(cfg.get_value("inventory", "slots", null), Inventory.SLOT_COUNT)
	Inventory.inventory_changed.emit()
	NPCInventory.slots = _deserialize_slots(cfg.get_value("npc_inventory", "slots", null), NPCInventory.SLOT_COUNT)
	NPCInventory.inventory_changed.emit()

	var quest = cfg.get_value("quest", "objectives", {})
	for obj_id in quest:
		if QuestManager.objectives.has(obj_id):
			QuestManager.objectives[obj_id].current = int(quest[obj_id].current)
			QuestManager.objectives[obj_id].done = bool(quest[obj_id].done)
	QuestManager.quest_active = cfg.get_value("quest", "active", false)
	QuestManager.quest_complete = cfg.get_value("quest", "complete", false)
	QuestManager._finished_emitted = QuestManager.quest_complete
	QuestManager.quest_updated.emit()

	cutscene_seen = cfg.get_value("flags", "cutscene_seen", false)

	_pending = {
		"px": cfg.get_value("player", "pos_x", null),
		"py": cfg.get_value("player", "pos_y", null),
		"health": cfg.get_value("player", "health", null),
		"stamina": cfg.get_value("player", "stamina", null),
		"npx": cfg.get_value("npc", "pos_x", null),
		"npy": cfg.get_value("npc", "pos_y", null),
		"alive_objects": cfg.get_value("world", "alive_objects", null),
		"campfires": cfg.get_value("world", "campfires", []),
		"drops": cfg.get_value("world", "drops", []),
	}
	_has_pending = true
	return true


func apply_pending_to_scene() -> bool:
	if not _has_pending:
		return false
	_has_pending = false
	var d = _pending

	var player = get_tree().get_first_node_in_group("player")
	if player and d.px != null:
		player.global_position = Vector2(d.px, d.py)
		if d.health != null:
			player.health = int(d.health)
			player.health_changed.emit(player.health, player.max_health)
		if d.stamina != null:
			player.stamina = float(d.stamina)
			player.stamina_changed.emit(player.stamina, player.max_stamina)

	var npc = get_tree().get_first_node_in_group("npc")
	if npc and d.npx != null:
		npc.global_position = Vector2(d.npx, d.npy)

	_restore_world(d)
	return true


func _restore_world(d: Dictionary) -> void:
	var root = get_tree().current_scene
	if not root:
		return

	var alive = d.get("alive_objects", null)
	if alive != null:
		var alive_set = {}
		for key in alive:
			alive_set[key] = true
		for g in WORLD_GROUPS:
			for node in get_tree().get_nodes_in_group(g):
				if not is_instance_valid(node):
					continue
				var key = str(root.get_path_to(node))
				if not alive_set.has(key):
					node.queue_free()

	var fires = d.get("campfires", [])
	if fires and not fires.is_empty() and ResourceLoader.exists(CAMPFIRE_SCENE_PATH):
		var fire_scene = load(CAMPFIRE_SCENE_PATH)
		for f in fires:
			var fire = fire_scene.instantiate()
			root.add_child(fire)
			fire.global_position = Vector2(f.x, f.y)

	var drops = d.get("drops", [])
	for drop in drops:
		var scene_path = drop.get("scene", "")
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		var item = load(scene_path).instantiate()
		root.add_child(item)
		item.global_position = Vector2(drop.x, drop.y)


func reset_state() -> void:
	_has_pending = false
	_pending = {}
	cutscene_seen = false
	for i in range(Inventory.SLOT_COUNT):
		Inventory.slots[i] = null
	Inventory.inventory_changed.emit()
	for i in range(NPCInventory.SLOT_COUNT):
		NPCInventory.slots[i] = null
	NPCInventory.inventory_changed.emit()
	for obj_id in QuestManager.objectives:
		QuestManager.objectives[obj_id].current = 0
		QuestManager.objectives[obj_id].done = false
	QuestManager.quest_complete = false
	QuestManager._finished_emitted = false
	QuestManager.quest_updated.emit()


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)



func _serialize_slots(slots: Array) -> Array:
	var out = []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			out.append({"id": s.item.id, "quantity": s.quantity})
	return out


func _deserialize_slots(data, slot_count: int) -> Array:
	var result = []
	result.resize(slot_count)
	for i in range(slot_count):
		result[i] = null
	if data == null:
		return result
	for i in range(min(data.size(), slot_count)):
		var entry = data[i]
		if entry == null:
			continue
		var path = ITEM_PATHS.get(entry.id, "")
		if path == "" or not ResourceLoader.exists(path):
			continue
		result[i] = {"item": load(path), "quantity": int(entry.quantity)}
	return result
