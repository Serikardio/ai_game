extends Control


const RECIPES = [
	{
		"name": "Костёр",
		"result_id": "campfire",
		"icon": preload("res://assets/sprites/someStaff/Sprite-sheet-campfire.png"),
		"icon_region": Rect2(160, 200, 320, 320),
		"ingredients": {"wood": 2},
	},
	{
		"name": "Блок камня",
		"result_id": "stone_block",
		"result_item": preload("res://Resources/Stone/stone_block_item.tres"),
		"icon": preload("res://Resources/Stone/stone_icon.tres"),
		"ingredients": {"stone": 3},
	},
	{
		"name": "Слиток золота",
		"result_id": "gold_block",
		"result_item": preload("res://Resources/Gold/gold_block_item.tres"),
		"icon": preload("res://Resources/Gold/gold_icon.tres"),
		"ingredients": {"gold": 3},
	},
]

var recipe_buttons: Array = []

func _ready():
	_build_ui()
	Inventory.inventory_changed.connect(_update_availability)
	_update_availability()

func _build_ui():
	var panel = PanelContainer.new()
	panel.anchor_left = 0
	panel.anchor_top = 0.45
	panel.anchor_right = 0
	panel.anchor_bottom = 0.45
	panel.offset_left = 8
	panel.offset_right = 60
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Крафт"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(title)

	for recipe in RECIPES:
		var btn = _create_recipe_button(recipe)
		vbox.add_child(btn)
		recipe_buttons.append({"button": btn, "recipe": recipe})

	add_child(panel)

func _create_recipe_button(recipe: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(52, 52)
	btn.tooltip_text = recipe.name + "\n" + _ingredients_text(recipe.ingredients)
	btn.focus_mode = Control.FOCUS_NONE

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.25, 0.25, 0.3, 0.9)
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 0.3, 0.4, 0.9)
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("hover", style_hover)

	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(40, 40)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if recipe.has("icon_region"):
		var atlas = AtlasTexture.new()
		atlas.atlas = recipe.icon
		atlas.region = recipe.icon_region
		tex_rect.texture = atlas
	else:
		tex_rect.texture = recipe.icon

	btn.add_child(tex_rect)

	tex_rect.anchor_left = 0.5
	tex_rect.anchor_top = 0.5
	tex_rect.offset_left = -20
	tex_rect.offset_top = -20
	tex_rect.offset_right = 20
	tex_rect.offset_bottom = 20
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	btn.pressed.connect(_on_craft_pressed.bind(recipe))
	return btn

func _ingredients_text(ingredients: Dictionary) -> String:
	var parts = []
	for item_id in ingredients:
		var names = {"wood": "дерево", "stone": "камень", "gold": "золото"}
		var name = names.get(item_id, item_id)
		parts.append(str(ingredients[item_id]) + " " + name)
	return " + ".join(parts)

func _on_craft_pressed(recipe: Dictionary):
	for item_id in recipe.ingredients:
		if Inventory.get_item_count(item_id) < recipe.ingredients[item_id]:
			return

	for item_id in recipe.ingredients:
		Inventory.remove_item(item_id, recipe.ingredients[item_id])

	if recipe.result_id == "campfire":
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var campfire = load("res://camp_fire.tscn").instantiate()
			player.get_parent().add_child(campfire)
			campfire.global_position = player.global_position + Vector2(40, 0)
			_check_campfire_near_totems(campfire.global_position)
	elif recipe.has("result_item") and recipe.result_item != null:
		Inventory.add_item(recipe.result_item)

	_update_availability()

func _check_campfire_near_totems(pos: Vector2):
	var totems = get_tree().get_nodes_in_group("quest_totems")
	for totem in totems:
		if pos.distance_to(totem.global_position) < 150.0:
			QuestManager.complete_campfire()
			return

func _update_availability():
	for entry in recipe_buttons:
		var recipe = entry.recipe
		var btn = entry.button as Button
		var can_craft = true
		for item_id in recipe.ingredients:
			if Inventory.get_item_count(item_id) < recipe.ingredients[item_id]:
				can_craft = false
				break
		btn.modulate = Color.WHITE if can_craft else Color(0.5, 0.5, 0.5, 0.7)
