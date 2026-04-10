extends Node2D

const HEAL_RATE = 2.0  # HP в секунду
const HEAL_RANGE = 50.0

var player: Node2D = null
var _heal_accumulator: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	if not player or not is_instance_valid(player):
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= HEAL_RANGE and player.health < player.max_health:
		_heal_accumulator += HEAL_RATE * delta
		if _heal_accumulator >= 1.0:
			var heal = int(_heal_accumulator)
			_heal_accumulator -= heal
			player.health = min(player.health + heal, player.max_health)
			player.health_changed.emit(player.health, player.max_health)
	else:
		_heal_accumulator = 0.0
