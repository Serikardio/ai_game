extends CanvasLayer

@export var slot_scene: PackedScene = preload("res://scenes/HotbarSlot.tscn")
@onready var container = $NPCInventoryUI/VBoxContainer

func _ready():
	print("NPCHotbarUI ready")
	# Connect to NPC inventory signal
	NPCInventory.inventory_changed.connect(refresh_ui)
	
	refresh_ui()

func refresh_ui():
	print("NPCHotbarUI: Refreshing...")
	# Clear existing slots
	for child in container.get_children():
		child.queue_free()
	
	var items = NPCInventory.get_items()
	
	# Create 6 slots (more compact)
	for i in range(6):
		var slot = slot_scene.instantiate()
		container.add_child(slot)
		
		# Align slot internal elements if needed, but HotbarSlot is usually horizontal
		# We'll use the same slot scene for consistency
		
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
