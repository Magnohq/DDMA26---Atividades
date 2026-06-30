extends Node2D

@onready var label = $Label

var time: float = 0.0


func _process(delta: float) -> void:
	time += delta
	var pulse: float = (sin(time * 6.0) + 1.0) * 0.5
	label.modulate.a = 0.45 + pulse * 0.55
	label.position.y = -6.0 - pulse * 6.0
	label.scale = Vector2.ONE * (1.0 + pulse * 0.12)
