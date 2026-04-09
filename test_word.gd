extends Node2D

@onready var animP = $AnimationPlayer

func _ready():
	# Add world drop zone (catches items dragged outside any hotbar)
	var drop_layer = CanvasLayer.new()
	drop_layer.name = "WorldDropZoneLayer"
	drop_layer.layer = 0
	add_child(drop_layer)

	var drop_zone = Control.new()
	drop_zone.name = "WorldDropZone"
	drop_zone.set_script(preload("res://scripts/WorldDropZone.gd"))
	drop_layer.add_child(drop_zone)

	# Navigation setup — bake navmesh from static colliders
	_setup_navigation()

func _setup_navigation():
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	var nav_poly = NavigationPolygon.new()
	nav_poly.agent_radius = 12.0

	# Walkable boundary (whole map)
	var outer = PackedVector2Array([
		Vector2(5, 5), Vector2(3900, 5),
		Vector2(3900, 2380), Vector2(5, 2380)
	])

	# Fence obstacle (from CollisionPolygon2D2 in the scene)
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

	# Use source geometry API to bake navmesh with obstacle cutout
	var source_geo = NavigationMeshSourceGeometryData2D.new()
	source_geo.add_traversable_outline(outer)
	source_geo.add_obstruction_outline(fence)

	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geo)

	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)

	print("Navigation baked. Polygon count: ", nav_poly.get_polygon_count())

func _process(delta: float) -> void:
	animP.play("Day-Night")
