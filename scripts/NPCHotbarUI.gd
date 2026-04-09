extends CanvasLayer

@export var slot_scene: PackedScene = preload("res://scenes/HotbarSlot.tscn")
@export var show_distance: float = 150.0
@onready var container = $NPCInventoryUI/VBoxContainer
@onready var npc_ui = $NPCInventoryUI

var drag_script = preload("res://scripts/DraggableSlot.gd")

func _ready():
	NPCInventory.inventory_changed.connect(refresh_ui)
	npc_ui.visible = false
	refresh_ui()

func _process(_delta):
	var player = _find_player()
	var npc = _find_npc()
	if player and npc:
		var dist = player.global_position.distance_to(npc.global_position)
		npc_ui.visible = dist <= show_distance
	else:
		npc_ui.visible = false

func _find_player() -> Node:
	var nodes = get_tree().get_nodes_in_group("player")
	return nodes[0] if nodes.size() > 0 else null

func _find_npc() -> Node:
	var nodes = get_tree().get_nodes_in_group("npc")
	return nodes[0] if nodes.size() > 0 else null

func refresh_ui():
	for child in container.get_children():
		child.queue_free()

	var items = NPCInventory.get_items()

	for i in range(6):
		var slot = slot_scene.instantiate()
		# All slots get the drag script (so they can accept drops too)
		slot.set_script(drag_script)
		slot.set_meta("source", "npc")

		if i < items.size():
			var entry = items[i]
			slot.set_meta("item_id", entry.item.id)
		else:
			slot.set_meta("item_id", "")

		container.add_child(slot)

		var icon_rect = slot.get_node("Icon")
		var count_label = slot.get_node("CountLabel")

		if i < items.size():
			var entry = items[i]
			if entry.item.icon:
				icon_rect.texture = entry.item.icon
			count_label.text = str(entry.quantity) if entry.quantity > 1 else ""
		else:
			icon_rect.texture = null
			count_label.text = ""
