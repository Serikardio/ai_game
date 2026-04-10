extends CanvasLayer

@onready var hp_bar = $Control/VBox/HPBar
@onready var stamina_bar = $Control/VBox/StaminaBar

func _ready():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)
	_on_health_changed(100, 100)
	_on_stamina_changed(100.0, 100.0)

func _on_health_changed(new_health: int, max_health_val: int):
	if hp_bar:
		hp_bar.value = float(new_health) / float(max_health_val) * 100.0

func _on_stamina_changed(new_stamina: float, max_stamina_val: float):
	if stamina_bar:
		stamina_bar.value = new_stamina / max_stamina_val * 100.0
