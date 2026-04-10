extends Node2D

const CAMPFIRE_SCENE = preload("res://camp_fire.tscn")
const WOOD_ICON = preload("res://assets/sprites/TestMap/Wood_v3.png")
const CAMPFIRE_SHEET = preload("res://assets/sprites/someStaff/Sprite-sheet-campfire.png")
const REQUIRED_ITEM_ID = "wood"
const REQUIRED_AMOUNT = 2

@onready var prompt_label: Label = $Prompt
@onready var campfire_spawned = false
var is_building = false

var overlapping_player = null
var ghost_campfire: Sprite2D
var recipe_ui: Node2D
var slot_icons: Array[Sprite2D] = []

func _ready():
	add_to_group("campspot")
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)

	# Hide ALL old child visuals
	for child in get_children():
		if child.name in ["WoodIcon", "CountLabel", "Frame"]:
			child.visible = false

	# Ghost campfire — first frame, centered
	ghost_campfire = Sprite2D.new()
	var atlas = AtlasTexture.new()
	atlas.atlas = CAMPFIRE_SHEET
	atlas.region = Rect2(0, 0, 640, 640)
	ghost_campfire.texture = atlas
	ghost_campfire.scale = Vector2(0.08, 0.07)
	ghost_campfire.modulate = Color(1, 1, 1, 0.25)
	add_child(ghost_campfire)

	# Recipe slots — one on each side of the campfire
	_create_recipe_ui()

func _create_recipe_ui():
	recipe_ui = Node2D.new()
	recipe_ui.visible = false
	add_child(recipe_ui)

	var positions = [Vector2(-24, -8), Vector2(20, -8)]
	for i in range(REQUIRED_AMOUNT):
		# Slot background
		var bg = Sprite2D.new()
		bg.position = positions[i]
		recipe_ui.add_child(bg)

		# Draw slot frame via a small Node2D with _draw
		var frame = _create_slot_frame()
		frame.position = positions[i]
		recipe_ui.add_child(frame)

		# Wood icon inside
		var icon = Sprite2D.new()
		icon.texture = WOOD_ICON
		icon.scale = Vector2(0.6, 0.6)
		icon.position = positions[i]
		icon.modulate = Color(1, 1, 1, 0.3)
		recipe_ui.add_child(icon)
		slot_icons.append(icon)

func _create_slot_frame() -> Node2D:
	var frame = Node2D.new()
	frame.set_script(_SlotFrameScript)
	return frame

var _SlotFrameScript = preload("res://scripts/RecipeSlotFrame.gd")

func _process(_delta):
	if overlapping_player and Input.is_action_just_pressed("Use"):
		try_build(overlapping_player)

	if overlapping_player and recipe_ui.visible:
		var count = Inventory.get_item_count(REQUIRED_ITEM_ID)
		for i in range(slot_icons.size()):
			if i < count:
				slot_icons[i].modulate = Color(1, 1, 1, 0.9)
			else:
				slot_icons[i].modulate = Color(1, 1, 1, 0.3)

func _on_body_entered(body):
	if body.is_in_group("player"):
		overlapping_player = body
		recipe_ui.visible = true
		prompt_label.text = "E — построить"
		prompt_label.visible = true
		var tween = create_tween()
		recipe_ui.modulate = Color(1, 1, 1, 0)
		tween.tween_property(recipe_ui, "modulate", Color.WHITE, 0.25)

func try_build(body):
	if campfire_spawned or is_building:
		return
	is_building = true

	var inv = null
	if body.is_in_group("player"):
		inv = Inventory
	elif body.is_in_group("npc"):
		inv = NPCInventory

	if inv:
		var count = inv.get_item_count(REQUIRED_ITEM_ID)
		if count >= REQUIRED_AMOUNT:
			_craft_campfire(inv)
			return
		prompt_label.text = "Нужно " + str(REQUIRED_AMOUNT) + " дерева"
		is_building = false

func _on_body_exited(body):
	if body == overlapping_player:
		overlapping_player = null
		prompt_label.visible = false
		var tween = create_tween()
		tween.tween_property(recipe_ui, "modulate", Color(1, 1, 1, 0), 0.2)
		tween.tween_callback(func(): recipe_ui.visible = false)

func _craft_campfire(inv):
	campfire_spawned = true
	inv.remove_item(REQUIRED_ITEM_ID, REQUIRED_AMOUNT)

	var campfire = CAMPFIRE_SCENE.instantiate()
	get_parent().add_child(campfire)
	campfire.global_position = global_position

	campfire.scale = Vector2.ZERO
	var tween = campfire.create_tween()
	tween.tween_property(campfire, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(campfire, "scale", Vector2.ONE, 0.1)

	queue_free()
