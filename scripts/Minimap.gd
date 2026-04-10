extends SubViewportContainer

@onready var viewport = $SubViewport
@onready var camera = $SubViewport/Camera2D

var player: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
	viewport.world_2d = get_viewport().world_2d

func _process(_delta):
	if player and camera:
		camera.global_position = player.global_position
