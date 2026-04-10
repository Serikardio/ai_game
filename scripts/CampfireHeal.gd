extends Node2D

const HEAL_RATE = 2.0  # HP в секунду
const HEAL_RANGE = 50.0

var player: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if not player or not is_instance_valid(player):
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= HEAL_RANGE:
		if player.health < player.max_health:
			player.health += int(ceil(HEAL_RATE * delta))
			player.health = min(player.health, player.max_health)
			player.health_changed.emit(player.health, player.max_health)
