extends Node2D

@onready var animP = $AnimationPlayer

func _process(delta: float) -> void:
	animP.play("Day-Night")
