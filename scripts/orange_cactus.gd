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

var entity_id := ""
var cell := Vector2i.ZERO
var target: MeadowPlayer
var world: MeadowWorld
var health := MAX_HEALTH
var age := 0.0
var mature := false
var dead := false
var wander_timer := 0.0
var volley_timer := 0.8
var facing := Vector2.RIGHT
var wander_direction := Vector2.ZERO
var leaf_wave := 0.0

func setup(plant_cell: Vector2i, player_target: MeadowPlayer, map_world: MeadowWorld) -> void:
	cell = plant_cell
	target = player_target
	world = map_world
	wander_timer = randf_range(0.5, WANDER_INTERVAL)
	queue_redraw()

func capture_state() -> Dictionary:
	var map_position := world.to_local(global_position) if is_instance_valid(world) else global_position
	var map_facing := world.global_direction_to_map(facing) if is_instance_valid(world) else facing
	map_facing = map_facing.normalized() if map_facing.length_squared() > 0.01 else Vector2.RIGHT
	var map_wander_direction := world.global_direction_to_map(wander_direction) if is_instance_valid(world) else wander_direction
	map_wander_direction = map_wander_direction.normalized() if map_wander_direction.length_squared() > 0.01 else Vector2.ZERO
	return {
		"kind": "orange_cactus",
		"entity_id": entity_id,
		"cell": [cell.x, cell.y],
		"position": [map_position.x, map_position.y],
		"health": clampi(health, 1, MAX_HEALTH),
		"age": clampf(age, 0.0, GROW_TIME),
		"mature": mature,
		"wander_timer": clampf(wander_timer, 0.0, WANDER_INTERVAL),
		"volley_timer": clampf(volley_timer, 0.0, VOLLEY_COOLDOWN),
		"facing": [map_facing.x, map_facing.y],
		"wander_direction": [map_wander_direction.x, map_wander_direction.y],
	}

func restore_state(data: Dictionary) -> void:
	entity_id = str(data.get("entity_id", ""))
	cell = _data_to_cell(data.get("cell", []), cell)
	var fallback := world.to_local(global_position) if is_instance_valid(world) else global_position
	var map_position := _data_to_position(data.get("position", []), fallback)
	global_position = world.to_global(map_position) if is_instance_valid(world) else map_position
	health = clampi(int(data.get("health", MAX_HEALTH)), 1, MAX_HEALTH)
	age = clampf(float(data.get("age", 0.0)), 0.0, GROW_TIME)
	mature = bool(data.get("mature", age >= GROW_TIME))
	if mature:
		age = GROW_TIME
	wander_timer = clampf(float(data.get("wander_timer", WANDER_INTERVAL)), 0.0, WANDER_INTERVAL)
	volley_timer = clampf(float(data.get("volley_timer", VOLLEY_COOLDOWN)), 0.0, VOLLEY_COOLDOWN)
	var map_facing := _data_to_direction(data.get("facing", []), Vector2.RIGHT, false)
	facing = world.map_direction_to_global(map_facing).normalized() if is_instance_valid(world) else map_facing
	var map_wander_direction := _data_to_direction(data.get("wander_direction", []), Vector2.ZERO, true)
	wander_direction = world.map_direction_to_global(map_wander_direction).normalized() if is_instance_valid(world) and map_wander_direction.length_squared() > 0.01 else map_wander_direction
	dead = false
	leaf_wave = 0.0
	velocity = Vector2.ZERO
	collision_layer = 4
	queue_redraw()

func _data_to_cell(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return fallback

func _data_to_position(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() == 2:
		var position := Vector2(float(value[0]), float(value[1]))
		if is_finite(position.x) and is_finite(position.y):
			return position
	return fallback

func _data_to_direction(value: Variant, fallback: Vector2, allow_zero: bool) -> Vector2:
	var direction := _data_to_position(value, fallback)
	if direction.length_squared() < 0.01:
		return Vector2.ZERO if allow_zero else fallback
	return direction.normalized()

func _ready() -> void:
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
