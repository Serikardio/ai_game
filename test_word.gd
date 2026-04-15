extends Node2D

@onready var animP = $AnimationPlayer

func _ready():
	y_sort_enabled = true

	AudioManager.play_music(AudioManager.MUSIC_ARIA_MATH, -25.0)

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

	var cutscene = CanvasLayer.new()
	cutscene.set_script(preload("res://scripts/IntroCutscene.gd"))
	add_child(cutscene)

	_setup_navigation()

func _setup_navigation():
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	var nav_poly = NavigationPolygon.new()
	nav_poly.agent_radius = 12.0

	var outer = PackedVector2Array([
		Vector2(5, 5), Vector2(3900, 5),
		Vector2(3900, 2380), Vector2(5, 2380)
	])

	var fence = PackedVector2Array([
		Vector2(2686, 1692), Vector2(2686, 1636), Vector2(1992, 1637),
		Vector2(1988, 2377), Vector2(1988, 2383), Vector2(3901, 2382),
		Vector2(3898, 946), Vector2(2776, 948), Vector2(2771, 1561),
		Vector2(2777, 1566), Vector2(2840, 1567), Vector2(2846, 1563),
		Vector2(2847, 1551), Vector2(2785, 1551), Vector2(2785, 963),
		Vector2(2785, 960), Vector2(3889, 959), Vector2(3890, 2369),
		Vector2(2001, 2367), Vector2(2002, 1648), Vector2(2672, 1648),
		Vector2(2672, 1695)
	])

	var source_geo = NavigationMeshSourceGeometryData2D.new()
	source_geo.add_traversable_outline(outer)
	source_geo.add_obstruction_outline(fence)

	for body in _find_all_static_bodies(self):
		var shape_node = null
		for child in body.get_children():
			if child is CollisionShape2D and child.shape:
				shape_node = child
				break
		if not shape_node:
			continue

		var shape = shape_node.shape
		if shape is RectangleShape2D:
			var pos = body.global_position + shape_node.position
			var s = shape.size * 0.5
			var margin = 8.0
			var obstacle = PackedVector2Array([
				pos + Vector2(-s.x - margin, -s.y - margin),
				pos + Vector2(s.x + margin, -s.y - margin),
				pos + Vector2(s.x + margin, s.y + margin),
				pos + Vector2(-s.x - margin, s.y + margin),
			])
			source_geo.add_obstruction_outline(obstacle)

	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geo)

	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)

	print("Navigation baked. Polygon count: ", nav_poly.get_polygon_count())


func _find_all_static_bodies(node: Node) -> Array:
	var result = []
	for child in node.get_children():
		if child is StaticBody2D:
			result.append(child)
		result.append_array(_find_all_static_bodies(child))
	return result

func _process(delta: float) -> void:
	animP.play("Day-Night")
