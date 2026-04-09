extends Control

@export var slot_scene: PackedScene = preload("res://scenes/HotbarSlot.tscn")
@onready var container = $HBoxContainer
@onready var command_input = $CommandInput

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
	print("Command entered from Hotbar: ", text)
	
	# Send the command to the AI NPC
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.has_method("receive_command"):
			npc.receive_command(text)
	
	if command_input:
		command_input.text = ""
		command_input.visible = false
		command_input.release_focus()

func refresh_ui():
	# Clear existing slots
	for child in container.get_children():
		child.queue_free()
	
	var items = Inventory.get_items()
	
	# Create 10 slots (fixed size for hotbar)
	for i in range(10):
		var slot = slot_scene.instantiate()
		container.add_child(slot)
		
		var icon_rect = slot.get_node("Icon")
		var count_label = slot.get_node("CountLabel")
		
		if i < items.size():
			var entry = items[i]
			var item = entry.item
			var quantity = entry.quantity
			
			if item.icon:
				icon_rect.texture = item.icon
			count_label.text = str(quantity) if quantity > 1 else ""
		else:
			icon_rect.texture = null
			count_label.text = ""
