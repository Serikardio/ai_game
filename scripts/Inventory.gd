extends Node

signal inventory_changed

const SLOT_COUNT = 10
const MAX_STACK = 10
var slots: Array = []  # Array of {item, quantity} or null

func _init():
	slots.resize(SLOT_COUNT)
	for i in range(SLOT_COUNT):
		slots[i] = null

func add_item(item, to_slot: int = -1):
	if not item:
		return
	# Try specific slot first
	if to_slot >= 0 and to_slot < SLOT_COUNT:
		if slots[to_slot] == null:
			slots[to_slot] = {"item": item, "quantity": 1}
			emit_signal("inventory_changed")
			return
		elif slots[to_slot].item.id == item.id and slots[to_slot].quantity < MAX_STACK:
			slots[to_slot].quantity += 1
			emit_signal("inventory_changed")
			return
	# Find existing stack with space
	for i in range(SLOT_COUNT):
		if slots[i] != null and slots[i].item.id == item.id and slots[i].quantity < MAX_STACK:
			slots[i].quantity += 1
			emit_signal("inventory_changed")
			return
	# Find empty slot
	for i in range(SLOT_COUNT):
		if slots[i] == null:
			slots[i] = {"item": item, "quantity": 1}
			emit_signal("inventory_changed")
			return

func remove_item(item_id: String, amount: int = 1):
	for i in range(SLOT_COUNT):
		if slots[i] != null and slots[i].item.id == item_id:
			slots[i].quantity -= amount
			if slots[i].quantity <= 0:
				slots[i] = null
			emit_signal("inventory_changed")
			return

func has_item(item_id: String) -> bool:
	for slot in slots:
		if slot != null and slot.item.id == item_id:
			return true
	return false

func get_item_count(item_id: String) -> int:
	var total = 0
	for slot in slots:
		if slot != null and slot.item.id == item_id:
			total += slot.quantity
	return total

func get_item(item_id: String) -> Item:
	for slot in slots:
		if slot != null and slot.item.id == item_id:
			return slot.item
	return null

func get_items() -> Array:
	var result = []
	for entry in slots:
		if entry != null:
			result.append(entry)
	return result

func get_slot(index: int):
	if index >= 0 and index < SLOT_COUNT:
		return slots[index]
	return null

func set_slot(index: int, data):
	if index >= 0 and index < SLOT_COUNT:
		slots[index] = data
		emit_signal("inventory_changed")

func swap_slots(from: int, to: int):
	if from >= 0 and from < SLOT_COUNT and to >= 0 and to < SLOT_COUNT:
		var temp = slots[from]
		slots[from] = slots[to]
		slots[to] = temp
		emit_signal("inventory_changed")
