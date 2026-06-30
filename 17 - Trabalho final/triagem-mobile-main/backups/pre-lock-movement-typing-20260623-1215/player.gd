extends CharacterBody2D

const SPEED: float = 170.0
const SPRINT_MULTIPLIER: float = 1.55
const FRAME_SIZE: Vector2 = Vector2(64, 88)
const WALK_FRAME_TIME: float = 0.14

@export var player_name: String = "Paciente"
@export var role: String = "patient"
@export var body_color: Color = Color(0.27, 0.46, 0.93, 1)

@onready var sprite = $Sprite
@onready var name_label = $NameLabel

var is_active: bool = false
var touch_vector: Vector2 = Vector2.ZERO
var last_direction: Vector2 = Vector2.DOWN
var walk_time: float = 0.0
var frame_index: int = 1
var direction_row: int = 0


func _ready() -> void:
	name_label.text = player_name
	_apply_active_style()


func configure(new_name: String, new_role: String, color: Color) -> void:
	player_name = new_name
	role = new_role
	body_color = color
	if is_node_ready():
		name_label.text = player_name
		_apply_active_style()


func set_sprite_texture(texture: Texture2D) -> void:
	if is_node_ready():
		sprite.texture = texture


func set_active(value: bool) -> void:
	is_active = value
	_apply_active_style()


func set_touch_vector(value: Vector2) -> void:
	touch_vector = value


func _physics_process(delta: float) -> void:
	if not is_active:
		velocity = Vector2.ZERO
		_set_animation_frame(false)
		return

	var direction: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if touch_vector != Vector2.ZERO:
		direction += touch_vector

	if direction.length() > 1.0:
		direction = direction.normalized()

	var current_speed: float = SPEED
	if Input.is_action_pressed("sprint"):
		current_speed *= SPRINT_MULTIPLIER

	velocity = direction * current_speed
	if direction != Vector2.ZERO:
		last_direction = direction
		_update_face_direction(direction)
		walk_time += delta
		if walk_time >= WALK_FRAME_TIME:
			walk_time = 0.0
			frame_index = (frame_index + 1) % 3
		_set_animation_frame(true)
	else:
		walk_time = 0.0
		frame_index = 1
		_set_animation_frame(false)

	move_and_slide()


func _apply_active_style() -> void:
	if not is_node_ready():
		return

	name_label.modulate = Color(1, 1, 1, 1) if is_active else Color(1, 1, 1, 0.55)
	sprite.modulate = Color(1.12, 1.12, 1.12, 1) if is_active else Color(0.82, 0.82, 0.82, 1)


func _update_face_direction(direction: Vector2) -> void:
	if abs(direction.y) >= abs(direction.x):
		direction_row = 0 if direction.y > 0 else 3
	else:
		direction_row = 1 if direction.x < 0 else 2


func _set_animation_frame(moving: bool) -> void:
	var col: int = frame_index if moving else 1
	sprite.region_rect = Rect2(col * FRAME_SIZE.x, direction_row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
