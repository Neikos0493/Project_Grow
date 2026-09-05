class_name MeadowOrangeCactus
extends CharacterBody2D
## Slow sand cactus that wanders and fires a leaf-fan volley at nearby players.

signal matured(cell: Vector2i)
signal projectile_requested(origin: Vector2, directions: Array[Vector2])
signal died(cell: Vector2i, position: Vector2)

const GROW_TIME := 3.0
const MAX_HEALTH := 5
const ATTACK_RANGE := 230.0
const MOVE_SPEED := 28.0
const WANDER_INTERVAL := 2.4
const VOLLEY_COOLDOWN := 1.6
const VOLLEY_COUNT := 3
const LEAF_FAN_SPREAD := deg_to_rad(30.0)
const LEAF_FAN_OFFSET := deg_to_rad(35.0)

var cell := Vector2i.ZERO
var target: MeadowPlayer
var health := MAX_HEALTH
var age := 0.0
var mature := false
var dead := false
var wander_timer := 0.0
var volley_timer := 0.8
var facing := Vector2.RIGHT
var wander_direction := Vector2.ZERO
var leaf_wave := 0.0

func setup(plant_cell: Vector2i, player_target: MeadowPlayer) -> void:
	cell = plant_cell
	target = player_target
	wander_timer = randf_range(0.5, WANDER_INTERVAL)
	queue_redraw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)
	collision_layer = 4
	collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape_node.shape = circle
	add_child(shape_node)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	if not mature:
		if age >= GROW_TIME:
			mature = true
			matured.emit(cell)
			queue_redraw()
		return
	if not is_instance_valid(target) or target.dead:
		velocity = Vector2.ZERO
		return
	leaf_wave += delta * 10.0
	wander_timer -= delta
	volley_timer = maxf(0.0, volley_timer - delta)
	if wander_timer <= 0.0:
		wander_timer = WANDER_INTERVAL
		wander_direction = Vector2.from_angle(randf_range(0.0, TAU))
	if wander_direction.length_squared() > 0.01:
		velocity = wander_direction * MOVE_SPEED
		facing = wander_direction
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	var target_offset := target.global_position - global_position
	if volley_timer <= 0.0 and target_offset.length() <= ATTACK_RANGE:
		volley_timer = VOLLEY_COOLDOWN
		_fire_leaf_fan(target_offset.normalized())
	queue_redraw()

func _fire_leaf_fan(direction: Vector2) -> void:
	var directions: Array[Vector2] = []
	for leaf_sign in [-1.0, 1.0]:
		var leaf_direction := direction.rotated(LEAF_FAN_OFFSET * leaf_sign)
		for index in range(VOLLEY_COUNT):
			var ratio := float(index) / float(VOLLEY_COUNT - 1)
			directions.append(leaf_direction.rotated(lerpf(-LEAF_FAN_SPREAD, LEAF_FAN_SPREAD, ratio)))
	projectile_requested.emit(global_position, directions)

func apply_knockback(direction: Vector2, strength: float = 52.0) -> void:
	if dead or direction.length_squared() < 0.01:
		return
	global_position += direction.normalized() * strength * 0.15

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
	if not mature:
		draw_shadow_ellipse(Vector2(0, 8), Vector2(13, 5), Color(0.05, 0.1, 0.1, 0.28))
		draw_circle(Vector2(-5, -5), 8.0, Color("#e77a32"))
		draw_circle(Vector2(5, -6), 8.0, Color("#f29a3d"))
		return
	var leaf_bob := sin(leaf_wave) * 2.0
	draw_shadow_ellipse(Vector2(0, 10), Vector2(17, 6), Color(0.05, 0.1, 0.1, 0.34))
	draw_line(Vector2(0, 10), Vector2(0, -11), Color("#6f3d2b"), 6.0)
	draw_circle(Vector2(0, -13), 14.0, Color("#e77a32"))
	draw_circle(Vector2(-14, -14 + leaf_bob), 11.0, Color("#f29a3d"))
	draw_circle(Vector2(14, -14 - leaf_bob), 11.0, Color("#f29a3d"))
	draw_arc(Vector2(-14, -14 + leaf_bob), 11.0, -PI * 0.8, PI * 0.8, 16, Color("#8f4b2e"), 2.0)
	draw_arc(Vector2(14, -14 - leaf_bob), 11.0, PI * 0.2, PI * 1.8, 16, Color("#8f4b2e"), 2.0)
	if target != null and target.global_position.distance_to(global_position) <= ATTACK_RANGE:
		var target_angle := (target.global_position - global_position).angle()
		for leaf_sign in [-1.0, 1.0]:
			var fan_center: float = target_angle + LEAF_FAN_OFFSET * float(leaf_sign)
			draw_arc(Vector2(0, -13), ATTACK_RANGE, fan_center - LEAF_FAN_SPREAD, fan_center + LEAF_FAN_SPREAD, 16, Color(0.95, 0.55, 0.2, 0.14), 1.0, true)
	for index in range(health):
		draw_circle(Vector2(-8 + index * 4, -34), 1.8, Color("#f6c15a"))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
