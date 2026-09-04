class_name MeadowPlayer
extends CharacterBody2D
## Responsive movement, mouse-facing primary actions, and player health.

signal interaction_requested
signal fire_requested(origin: Vector2, direction: Vector2)
signal health_changed(current: int, maximum: int)
signal died

const MOVE_SPEED := 150.0
const MAX_HEALTH := 5

var controls_locked := false
var facing := Vector2.DOWN
var health := MAX_HEALTH
var dead := false

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	queue_redraw()
	health_changed.emit(health, MAX_HEALTH)

func _physics_process(_delta: float) -> void:
	if controls_locked or dead:
		velocity = Vector2.ZERO
		_update_mouse_facing()
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * MOVE_SPEED
	move_and_slide()
	_update_mouse_facing()

func _update_mouse_facing() -> void:
	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() < 0.01:
		return
	var next_facing := aim.normalized()
	if not facing.is_equal_approx(next_facing):
		facing = next_facing
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	var key_event := event as InputEventKey
	if event.is_action_pressed("interact") and (key_event == null or not key_event.echo):
		interaction_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if not controls_locked and not dead and event.is_action_pressed("fire") and (key_event == null or not key_event.echo):
		var aim := get_global_mouse_position() - global_position
		if aim.length_squared() > 0.01:
			fire_requested.emit(global_position, aim.normalized())

func take_damage(amount: int = 1) -> bool:
	if dead or amount <= 0:
		return false
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	if health == 0:
		dead = true
		controls_locked = true
		died.emit()
	return true

func respawn_at(spawn_global_position: Vector2) -> bool:
	if not dead:
		return false
	global_position = spawn_global_position
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	dead = false
	controls_locked = false
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	return true

func _draw() -> void:
	draw_shadow_ellipse(Vector2(0, 8), Vector2(10, 4), Color(0.05, 0.1, 0.1, 0.3))
	var triangle := PackedVector2Array([
		Vector2(0, -12),
		Vector2(9, 9),
		Vector2(0, 6),
		Vector2(-9, 9),
	])
	var rotation := facing.angle() + PI / 2.0
	var rotated := PackedVector2Array()
	for point in triangle:
		rotated.append(point.rotated(rotation))
	draw_colored_polygon(rotated, Color("#f3c969"))
	draw_polyline(PackedVector2Array([rotated[0], rotated[1], rotated[2], rotated[3], rotated[0]]), Color("#26353b"), 2.0, true)

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
