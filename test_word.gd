extends Node2D

@onready var animP = $AnimationPlayer

var _nav_region: NavigationRegion2D
var _nav_outer := PackedVector2Array([
	Vector2(5, 5), Vector2(3900, 5),
	Vector2(3900, 2380), Vector2(5, 2380)
])

func _ready():
	y_sort_enabled = true

	AudioManager.play_music(AudioManager.MUSIC_ARIA_MATH, -25.0, 1.5, 20.0)

	var drop_layer = CanvasLayer.new()
	drop_layer.name = "WorldDropZoneLayer"
	drop_layer.layer = 0
	add_child(drop_layer)

	var drop_zone = Control.new()
	drop_zone.name = "WorldDropZone"
	drop_zone.set_script(preload("res://scripts/WorldDropZone.gd"))
	drop_layer.add_child(drop_zone)

	var craft_layer = CanvasLayer.new()
	craft_layer.name = "CraftingLayer"
	craft_layer.layer = 1
	add_child(craft_layer)

	var craft_panel = Control.new()
	craft_panel.name = "CraftingPanel"
	craft_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	craft_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	craft_panel.set_script(preload("res://scripts/CraftingPanel.gd"))
	craft_layer.add_child(craft_panel)

	var quest_layer = CanvasLayer.new()
	quest_layer.name = "QuestLayer"
	quest_layer.layer = 1
	add_child(quest_layer)

	var tracker = Control.new()
	tracker.name = "QuestTracker"
	tracker.set_anchors_preset(Control.PRESET_FULL_RECT)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.set_script(preload("res://scripts/QuestTracker.gd"))
	quest_layer.add_child(tracker)

	if not SaveManager.cutscene_seen:
		var cutscene = CanvasLayer.new()
		cutscene.set_script(preload("res://scripts/IntroCutscene.gd"))
		add_child(cutscene)
		cutscene.cutscene_finished.connect(func(): SaveManager.cutscene_seen = true)
	else:
		QuestManager.start_quest()

	_setup_navigation()

	var pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_script(preload("res://scripts/PauseMenu.gd"))
	add_child(pause_menu)

	var autosave = Timer.new()
	autosave.name = "AutosaveTimer"
	autosave.wait_time = 300.0
	autosave.autostart = true
	autosave.timeout.connect(_on_autosave)
	add_child(autosave)

	QuestManager.quest_finished.connect(_on_quest_finished)

	_apply_save_and_rebake.call_deferred()


func _apply_save_and_rebake():
	if SaveManager.apply_pending_to_scene():
		await get_tree().process_frame
		rebake_navigation()


func _on_quest_finished():
	await get_tree().create_timer(2.0).timeout
	var ending = CanvasLayer.new()
	ending.name = "EndingCutscene"
	ending.set_script(preload("res://scripts/EndingCutscene.gd"))
	add_child(ending)


func _on_autosave():
	if SaveManager.save_game():
		_notify("Автосохранение...")


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			if SaveManager.save_game():
				_notify("Сохранено")
		elif event.keycode == KEY_F9:
			if SaveManager.load_game():
				get_tree().reload_current_scene()


func _notify(text: String):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_chat_message"):
		player.show_chat_message(text, 1.5)

func _setup_navigation():
	_nav_region = NavigationRegion2D.new()
	_nav_region.name = "NavRegion"

	var nav_poly = NavigationPolygon.new()
	nav_poly.agent_radius = 8.0

	_nav_region.navigation_polygon = nav_poly
	add_child(_nav_region)

	rebake_navigation()


func rebake_navigation():
	if not _nav_region:
		return
	var nav_poly = _nav_region.navigation_polygon

	var source_geo = NavigationMeshSourceGeometryData2D.new()
	source_geo.add_traversable_outline(_nav_outer)

	var map_area := 3895.0 * 2375.0

	for body in _find_all_static_bodies(self):
		for child in body.get_children():
			if child is CollisionPolygon2D and child.polygon.size() >= 3:
				var xform = child.global_transform
				var pts = PackedVector2Array()
				for p in child.polygon:
					pts.append(xform * p)
				if _bbox_area(pts) >= map_area * 0.8:
					continue
				source_geo.add_obstruction_outline(pts)
			elif child is CollisionShape2D and child.shape is RectangleShape2D:
				var half = (child.shape as RectangleShape2D).size * 0.5
				var c = child.global_position
				var m = 4.0
				source_geo.add_obstruction_outline(PackedVector2Array([
					c + Vector2(-half.x - m, -half.y - m),
					c + Vector2(half.x + m, -half.y - m),
					c + Vector2(half.x + m, half.y + m),
					c + Vector2(-half.x - m, half.y + m),
				]))

	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geo)
	_nav_region.navigation_polygon = nav_poly

	print("Navigation baked. Polygon count: ", nav_poly.get_polygon_count())


func _bbox_area(pts: PackedVector2Array) -> float:
	var min_x = pts[0].x
	var min_y = pts[0].y
	var max_x = pts[0].x
	var max_y = pts[0].y
	for p in pts:
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return (max_x - min_x) * (max_y - min_y)


func _find_all_static_bodies(node: Node) -> Array:
	var result = []
	for child in node.get_children():
		if child is StaticBody2D:
			result.append(child)
		result.append_array(_find_all_static_bodies(child))
	return result

func _process(delta: float) -> void:
	animP.play("Day-Night")
