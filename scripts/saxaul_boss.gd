class_name MeadowSaxaulBoss
extends StaticBody2D
## Persistent stationary Sunset Shore boss grown from a saxaul seed.

signal matured(cell: Vector2i)
signal ring_attack_requested(origin: Vector2, directions: Array[Vector2])
signal vine_volley_requested(origins: Array[Vector2], directions: Array[Vector2])
signal vines_requested(origins: Array[Vector2])
signal health_changed(current: int, maximum: int)
signal died(cell: Vector2i, global_position: Vector2)

const GROW_TIME := 4.0
const MAX_HEALTH := 24
const SPAWN_GRACE_DURATION := 1.0
const ATTACK_RANGE := 420.0
const RING_COUNT := 12
const RING_COOLDOWN := 1.25
const RING_DURATION := 0.9
const RING_PULSE_INTERVAL := 0.15
const SKILL_WINDUP := 0.65
const VOLLEY_COUNT := 4
const VOLLEY_HALF_SPREAD := deg_to_rad(30.0)

var entity_id := ""
var cell := Vector2i.ZERO
var target: MeadowPlayer
var world: MeadowWorld
var health := MAX_HEALTH
var age := 0.0
var mature := false
var dead := false
var attacks_done := 0
var attack_timer := 0.8
var ring_duration_remaining := 0.0
var ring_pulse_remaining := 0.0
var skill_windup := 0.0
var skill_target_direction := Vector2.RIGHT
var small_vine_origins: Array[Vector2] = []
var spawn_grace_remaining := 0.0
var small_vines_spawned := false

func setup(plant_cell: Vector2i, player_target: MeadowPlayer, map: MeadowWorld) -> void:
	cell = plant_cell
	target = player_target
	world = map
	queue_redraw()

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape_node.shape = circle
	add_child(shape_node)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not mature:
		age += delta
		if age >= GROW_TIME:
			mature = true
			spawn_grace_remaining = SPAWN_GRACE_DURATION
			ring_duration_remaining = 0.0
			skill_windup = 0.0
			matured.emit(cell)
			queue_redraw()
		return
	if spawn_grace_remaining > 0.0:
		spawn_grace_remaining = maxf(0.0, spawn_grace_remaining - delta)
		ring_duration_remaining = 0.0
		skill_windup = 0.0
		return
	if not is_instance_valid(target) or target.dead:
		return
	age = GROW_TIME
	if ring_duration_remaining > 0.0:
		ring_duration_remaining = maxf(0.0, ring_duration_remaining - delta)
		ring_pulse_remaining -= delta
		while ring_pulse_remaining <= 0.0 and ring_duration_remaining > 0.0:
			_emit_ring_pulse()
			ring_pulse_remaining += RING_PULSE_INTERVAL
		if ring_duration_remaining <= 0.0:
			attacks_done += 1
			attack_timer = RING_COOLDOWN
		queue_redraw()
		return
	if skill_windup > 0.0:
		skill_windup -= delta
		if skill_windup <= 0.0:
			_fire_vine_skill()
		queue_redraw()
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	if attack_timer > 0.0 or global_position.distance_to(target.global_position) > ATTACK_RANGE:
		return
	if attacks_done >= 2:
		_start_vine_skill()
	else:
		_start_ring_attack()

func _start_ring_attack() -> void:
	ring_duration_remaining = RING_DURATION
	ring_pulse_remaining = RING_PULSE_INTERVAL
	_emit_ring_pulse()
	queue_redraw()

func _emit_ring_pulse() -> void:
	var directions: Array[Vector2] = []
	var random_offset := randf_range(0.0, TAU / float(RING_COUNT))
	for index in range(RING_COUNT):
		var map_direction := Vector2.RIGHT.rotated(
			random_offset + TAU * float(index) / float(RING_COUNT)
		)
		directions.append(world.map_direction_to_global(map_direction).normalized())
	ring_attack_requested.emit(global_position, directions)

func _start_vine_skill() -> void:
	skill_target_direction = (target.global_position - global_position).normalized()
	if skill_target_direction.length_squared() < 0.01:
		skill_target_direction = world.map_direction_to_global(Vector2.RIGHT).normalized()
	var side := skill_target_direction.rotated(PI * 0.5)
	small_vine_origins = [
		global_position + skill_target_direction * 64.0 + side * 46.0,
		global_position + skill_target_direction * 64.0 - side * 46.0,
	]
	if health * 2 < MAX_HEALTH and not small_vines_spawned:
		small_vines_spawned = true
		vines_requested.emit(small_vine_origins)
	skill_windup = SKILL_WINDUP
	queue_redraw()

func _fire_vine_skill() -> void:
	var aim := target.global_position - global_position
	if aim.length_squared() < 0.01:
		aim = skill_target_direction
	var center_angle := aim.angle()
	var directions: Array[Vector2] = []
	for index in range(VOLLEY_COUNT):
		var ratio := float(index) / float(VOLLEY_COUNT - 1)
		var angle := center_angle + lerpf(-VOLLEY_HALF_SPREAD, VOLLEY_HALF_SPREAD, ratio)
		directions.append(Vector2.RIGHT.rotated(angle))
	vine_volley_requested.emit(small_vine_origins, directions)
	small_vine_origins.clear()
	attacks_done = 0
	attack_timer = RING_COOLDOWN
	queue_redraw()

func get_damage_number_position() -> Vector2:
	return global_position + Vector2(0, -76)

func take_damage(amount: int = 1) -> bool:
	if dead or not mature or spawn_grace_remaining > 0.0 or amount <= 0:
		return false
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	if health > 0:
		return true
	dead = true
	collision_layer = 0
	died.emit(cell, global_position)
	queue_redraw()
	return true

func capture_state() -> Dictionary:
	var map_direction := world.global_direction_to_map(skill_target_direction)
	var origin_data: Array[Array] = []
	for origin in small_vine_origins:
		var map_origin := world.to_local(origin)
		origin_data.append([map_origin.x, map_origin.y])
	return {
		"kind": "saxaul_boss",
		"entity_id": entity_id,
		"cell": [cell.x, cell.y],
		"position": _position_to_data(world.to_local(global_position)),
		"health": health,
		"age": age,
		"mature": mature,
		"dead": dead,
		"attacks_done": attacks_done,
		"attack_timer": attack_timer,
		"ring_duration_remaining": ring_duration_remaining,
		"ring_pulse_remaining": ring_pulse_remaining,
		"skill_windup": skill_windup,
		"spawn_grace_remaining": clampf(spawn_grace_remaining, 0.0, SPAWN_GRACE_DURATION),
		"skill_target_direction": _position_to_data(map_direction),
		"small_vine_origins": origin_data,
	}

func restore_state(state: Dictionary) -> void:
	entity_id = str(state.get("entity_id", entity_id))
	cell = _data_to_cell(state.get("cell", [cell.x, cell.y]), cell)
	var map_position := _data_to_position(
		state.get("position", []),
		world.cell_to_world(cell)
	)
	global_position = world.to_global(map_position)
	health = clampi(int(state.get("health", MAX_HEALTH)), 0, MAX_HEALTH)
	age = clampf(float(state.get("age", 0.0)), 0.0, GROW_TIME)
	mature = bool(state.get("mature", false))
	dead = bool(state.get("dead", false)) or health <= 0
	attacks_done = clampi(int(state.get("attacks_done", 0)), 0, 2)
	attack_timer = clampf(float(state.get("attack_timer", 0.8)), 0.0, RING_COOLDOWN)
	ring_duration_remaining = clampf(
		float(state.get("ring_duration_remaining", 0.0)),
		0.0,
		RING_DURATION
	)
	ring_pulse_remaining = clampf(
		float(state.get("ring_pulse_remaining", 0.0)),
		0.0,
		RING_PULSE_INTERVAL
	)
	skill_windup = clampf(float(state.get("skill_windup", 0.0)), 0.0, SKILL_WINDUP)
	spawn_grace_remaining = clampf(float(state.get("spawn_grace_remaining", 0.0)), 0.0, SPAWN_GRACE_DURATION)
	small_vines_spawned = health * 2 < MAX_HEALTH
	var map_direction := _data_to_position(
		state.get("skill_target_direction", []),
		Vector2.RIGHT
	)
	skill_target_direction = world.map_direction_to_global(map_direction).normalized()
	small_vine_origins.clear()
	for value in state.get("small_vine_origins", []):
		var origin := _data_to_position(value, Vector2(-INF, -INF))
		if is_finite(origin.x) and is_finite(origin.y):
			small_vine_origins.append(world.to_global(origin))
	if dead:
		health = 0
		collision_layer = 0
	queue_redraw()

func _draw() -> void:
	draw_shadow_ellipse(Vector2(0, 12), Vector2(28, 9), Color(0.05, 0.1, 0.1, 0.3))
	if dead:
		draw_line(Vector2(-18, 8), Vector2(18, -8), Color("#66513a"), 12.0)
		draw_circle(Vector2(20, -9), 10.0, Color("#7d6b43"))
		return
	if not mature:
		draw_line(Vector2(0, 8), Vector2(0, -10), Color("#705338"), 6.0)
		draw_circle(Vector2(-7, -11), 7.0, Color("#6e9f55"))
		draw_circle(Vector2(7, -9), 7.0, Color("#83b45e"))
		return
	draw_line(Vector2(0, 12), Vector2(0, -32), Color("#73513a"), 14.0)
	for branch in [Vector2(-28, -30), Vector2(28, -27), Vector2(-18, -48), Vector2(20, -50)]:
		draw_line(Vector2(0, -20), branch, Color("#73513a"), 7.0)
		draw_circle(branch, 13.0, Color("#658c4c"))
	draw_circle(Vector2(0, -42), 19.0, Color("#b78f3e") if health * 2 < MAX_HEALTH else Color("#789e52"))
	if health * 2 < MAX_HEALTH:
		for index in range(6):
			var form_angle := TAU * float(index) / 6.0 + age * 1.5
			draw_circle(Vector2.RIGHT.rotated(form_angle) * 39.0, 3.0, Color("#f3c969"))
	if ring_duration_remaining > 0.0:
		var pulse_ratio := ring_duration_remaining / RING_DURATION
		draw_arc(
			Vector2.ZERO,
			34.0 + (1.0 - pulse_ratio) * 12.0,
			0.0,
			TAU,
			32,
			Color("#b9f58a"),
			3.0
		)
	if skill_windup > 0.0:
		for global_origin in small_vine_origins:
			var origin := to_local(global_origin)
			draw_circle(origin, 9.0, Color("#a7d76e"))
			draw_arc(origin, 13.0, 0.0, TAU, 18, Color("#e8f5a6"), 2.0)
	for index in range(health):
		var angle := TAU * float(index) / float(MAX_HEALTH)
		draw_circle(Vector2.RIGHT.rotated(angle) * 31.0, 1.5, Color("#d8e98c"))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(
			center + Vector2(
				cos(angle) * radii.x,
				sin(angle) * radii.y
			)
		)
	draw_colored_polygon(points, color)

func _position_to_data(position: Vector2) -> Array[float]:
	return [position.x, position.y]

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
