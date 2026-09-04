class_name MeadowPlant
extends Area2D
## A planted enemy that detaches when mature and fires at the player.

signal projectile_requested(origin: Vector2, direction: Vector2)
signal matured(cell: Vector2i)
signal died(cell: Vector2i, position: Vector2)

const GROW_TIME := 3.0
const FIRE_INTERVAL := 1.0
const MAX_HEALTH := 3

var cell := Vector2i.ZERO
var target: MeadowPlayer
var health := MAX_HEALTH
var age := 0.0
var fire_timer := 0.0
var mature := false
var dead := false
var ground_position := Vector2.ZERO
var knockback_velocity := Vector2.ZERO

func setup(plant_cell: Vector2i, plant_target: MeadowPlayer) -> void:
	cell = plant_cell
	target = plant_target
	ground_position = global_position
	queue_redraw()

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape_node.shape = circle
	add_child(shape_node)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	if knockback_velocity.length_squared() > 0.01:
		global_position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 220.0 * delta)
	age += delta
	if not mature:
		if age >= GROW_TIME:
			mature = true
			fire_timer = FIRE_INTERVAL
			matured.emit(cell)
			queue_redraw()
		return
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = FIRE_INTERVAL
		_fire_volley()
	queue_redraw()

func _fire_volley() -> void:
	if not is_instance_valid(target):
		return
	var direction := target.global_position - global_position
	if direction.length_squared() < 0.01:
		return
	direction = direction.normalized()
	for angle in [-0.18, 0.0, 0.18]:
		projectile_requested.emit(global_position, direction.rotated(float(angle)))

func apply_knockback(direction: Vector2, strength: float = 52.0) -> void:
	if dead or not mature or direction.length_squared() < 0.01:
		return
	knockback_velocity = direction.normalized() * maxf(0.0, strength)

func take_damage(amount: int = 1) -> bool:
	if dead or not mature or amount <= 0:
		return false
	health = maxi(0, health - amount)
	queue_redraw()
	if health > 0:
		return true
	dead = true
	collision_layer = 0
	died.emit(cell, global_position)
	queue_free()
	return true

func _draw() -> void:
	var offset := Vector2(0, -10) if mature else Vector2.ZERO
	draw_shadow_ellipse(Vector2(0, 10) - offset, Vector2(15, 6), Color(0.05, 0.1, 0.1, 0.28))
	var stem_color := Color("#31734b") if mature else Color("#5e9b55")
	draw_line(Vector2(0, 8) - offset, Vector2(0, -10) - offset, Color("#24523a"), 4.0)
	draw_circle(Vector2(0, -12) - offset, 13.0, stem_color)
	draw_circle(Vector2(-8, -7) - offset, 8.0, Color("#4d9b55"))
	draw_circle(Vector2(8, -5) - offset, 8.0, Color("#5cb55e"))
	if mature:
		draw_circle(Vector2(0, -15) - offset, 16.0, Color("#2f8249"))
		draw_circle(Vector2(-5, -19) - offset, 5.0, Color("#87d263"))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
