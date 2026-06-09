extends Control

@export var slot_scene: PackedScene = preload("res://scenes/ui/HotbarSlot.tscn")
@onready var container = $HBoxContainer
@onready var command_input = $CommandInput

var drag_script = preload("res://scripts/DraggableSlot.gd")

func _ready():
	Inventory.inventory_changed.connect(refresh_ui)

	if command_input:
		command_input.visible = false
		command_input.text_submitted.connect(_on_command_submitted)

	refresh_ui()

func _unhandled_input(event):
	if event.is_action_pressed("Enter"):
		if command_input:
			if not command_input.visible:
				command_input.visible = true
				command_input.grab_focus()
				get_viewport().set_input_as_handled()
			else:
				if not command_input.has_focus():
					command_input.grab_focus()
					get_viewport().set_input_as_handled()

func _on_command_submitted(text: String):
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.has_method("receive_command"):
			npc.receive_command(text)

	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_method("show_chat_message"):
			player.show_chat_message(text)

	if command_input:
		command_input.text = ""
		command_input.visible = false
		command_input.release_focus()


func refresh_ui():
	for child in container.get_children():
		child.queue_free()

	for i in range(Inventory.SLOT_COUNT):
		var slot = slot_scene.instantiate()
		slot.set_script(drag_script)
		slot.set_meta("source", "player")
		slot.set_meta("slot_index", i)

		var entry = Inventory.get_slot(i)

		if entry:
			slot.set_meta("item_id", entry.item.id)
		else:
			slot.set_meta("item_id", "")

		container.add_child(slot)

		var icon_rect = slot.get_node("Icon")
		var count_label = slot.get_node("CountLabel")

		if entry:
			if entry.item.icon:
				icon_rect.texture = entry.item.icon
			count_label.text = str(entry.quantity) if entry.quantity > 1 else ""
		else:
			icon_rect.texture = null
			count_label.text = ""
