extends Node2D

const CAMPFIRE_SCENE = preload("res://camp_fire.tscn")
const WOOD_ICON = preload("res://assets/sprites/TestMap/Wood_v3.png")
const REQUIRED_ITEM_ID = "wood"
const REQUIRED_AMOUNT = 2

@onready var prompt_label: Label = $Prompt
@onready var campfire_spawned = false
var is_building = false # Защита от двойного нажатия/срабатывания

var overlapping_player = null

func _ready():
	add_to_group("campspot")
	print("CampfireSpot ready and added to group 'campspot': ", name)
	$Area2D.body_entered.connect(_on_body_entered)
	$Area2D.body_exited.connect(_on_body_exited)

func _process(_delta):
	if overlapping_player and Input.is_action_just_pressed("Use"):
		try_build(overlapping_player)

func _on_body_entered(body):
	if body.is_in_group("npc"):
		# NPCs still build automatically on proximity
		try_build(body)
	elif body.is_in_group("player"):
		overlapping_player = body
		# Show hint for player
		prompt_label.text = "Нажми E чтобы построить"
		prompt_label.visible = true

func try_build(body):
	if campfire_spawned or is_building:
		return
	
	is_building = true # Начинаем процесс
		
	var inv = null
	if body.is_in_group("player"):
		inv = Inventory
	elif body.is_in_group("npc"):
		inv = NPCInventory
		
	if inv:
		var count = inv.get_item_count(REQUIRED_ITEM_ID)
		print("CampfireSpot: ", body.name, " tried to build. Has ", count, "/", REQUIRED_AMOUNT, " wood.")
		if count >= REQUIRED_AMOUNT:
			print("CampfireSpot: Conditions met! Starting craft.")
			_craft_campfire(inv)
			return
		# Show a hint if not enough wood
		prompt_label.text = "Нужно 2 дерева"
		prompt_label.visible = true
		is_building = false # Разблокируем, чтобы можно было попробовать позже

func _on_body_exited(body):
	if body == overlapping_player:
		overlapping_player = null
		prompt_label.visible = false
	elif body.is_in_group("npc"):
		pass

func _craft_campfire(inv):
	print("CampfireSpot: _craft_campfire called. Removing resources.")
	campfire_spawned = true
	# Remove wood from inventory
	inv.remove_item(REQUIRED_ITEM_ID, REQUIRED_AMOUNT)
	
	# Spawn campfire at this position
	var campfire = CAMPFIRE_SCENE.instantiate()
	get_parent().add_child(campfire)
	campfire.global_position = global_position
	
	# Animate campfire appearing
	campfire.scale = Vector2.ZERO
	var tween = campfire.create_tween()
	tween.tween_property(campfire, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(campfire, "scale", Vector2.ONE, 0.1)
	
	# Remove this spot
	queue_free()
