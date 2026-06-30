extends CharacterBody2D

# ─── Constantes ───────────────────────────────────────
const SPEED := 150.0   # pixels por segundo

# ─── Referências ──────────────────────────────────────
@onready var animated_sprite := $AnimatedSprite2D

# Guarda a última direção para o idle
var last_direction := "down"

# ─── Loop de Física ───────────────────────────────────
func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO

	# Lê as entradas e monta o vetor de direção
	direction.x = Input.get_axis("move_left", "move_right")
	direction.y = Input.get_axis("move_up", "move_down")

	# Normaliza para movimento diagonal consistente
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		velocity = direction * SPEED
		_update_animation(direction, true)
	else:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO, false)

	move_and_slide()

# ─── Animações ────────────────────────────────────────
func _update_animation(dir: Vector2, moving: bool) -> void:

	if moving:
		# Determina a direção dominante
		if abs(dir.y) >= abs(dir.x):
			if dir.y > 0:
				last_direction = "down"
			else:
				last_direction = "up"
		else:
			if dir.x > 0:
				last_direction = "right"
			else:
				last_direction = "left"

		animated_sprite.play("walk_" + last_direction)
	else:
		animated_sprite.play("idle_" + last_direction)
