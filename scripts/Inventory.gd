extends Node

# Inventory singleton to manage collected items
# Stores items in a dictionary: key = item id, value = quantity

signal inventory_changed

var items: Dictionary = {}

func _init():
	pass

func add_item(item):
	if not item:
		return
	var id = item.id
	if items.has(id):
		items[id].quantity += 1
	else:
		items[id] = {"item": item, "quantity": 1}
	emit_signal("inventory_changed")

func remove_item(item_id: String, amount: int = 1):
	if not items.has(item_id):
		return
	var entry = items[item_id]
	entry.quantity -= amount
	if entry.quantity <= 0:
		items.erase(item_id)
	emit_signal("inventory_changed")

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func get_item_count(item_id: String) -> int:
	if items.has(item_id):
		return items[item_id].quantity
	return 0

func get_item(item_id: String) -> Item:
	if items.has(item_id):
		return items[item_id].item
	return null

func get_items() -> Array:
	var result = []
	for entry in items.values():
		result.append(entry)
	return result
