class_name MeadowSaxaulBoss
extends StaticBody2D
## Stationary second-area boss grown from a saxaul seed.

signal matured(cell: Vector2i)
signal ring_attack_requested(origin: Vector2, directions: Array[Vector2])
signal vine_volley_requested(origins: Array[Vector2], directions: Array[Vector2])
signal health_changed(current: int, maximum: int)
signal died(cell: Vector2i, position: Vector2)

const GROW_TIME := 4.0
const MAX_HEALTH := 24
const ATTACK_RANGE := 360.0
const RING_COUNT := 12
const RING_COOLDOWN := 1.25
const RING_DURATION := 0.9
const RING_PULSE_INTERVAL := 0.15
const SKILL_WINDUP := 0.65
const VOLLEY_COUNT := 4
const VOLLEY_HALF_SPREAD := deg_to_rad(30.0)

var cell := Vector2i.ZERO
var target: MeadowPlayer
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

func setup(plant_cell: Vector2i, player_target: MeadowPlayer) -> void:
	cell = plant_cell
	target = player_target
	global_position = Vector2.ZERO
	queue_redraw()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	collision_layer = 4
	collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape_node.shape = circle
	shape_node.position = _root_position()
	add_child(shape_node)
	_growth_timer()
	queue_redraw()

func _growth_timer() -> void:
	await get_tree().create_timer(GROW_TIME).timeout
	if dead or mature:
		return
	mature = true
	matured.emit(cell)
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
		return
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
	if attack_timer > 0.0 or _root_position().distance_to(target.global_position) > ATTACK_RANGE:
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
		directions.append(Vector2.RIGHT.rotated(random_offset + TAU * float(index) / float(RING_COUNT)))
	ring_attack_requested.emit(_root_position(), directions)

func _start_vine_skill() -> void:
	skill_target_direction = (target.global_position - _root_position()).normalized()
	if skill_target_direction.length_squared() < 0.01:
		skill_target_direction = Vector2.RIGHT
	var side := skill_target_direction.rotated(PI * 0.5)
	small_vine_origins = [
		_root_position() + skill_target_direction * 64.0 + side * 46.0,
		_root_position() + skill_target_direction * 64.0 - side * 46.0,
	]
	skill_windup = SKILL_WINDUP
	queue_redraw()

func _fire_vine_skill() -> void:
	var directions: Array[Vector2] = []
	for index in range(VOLLEY_COUNT):
		var ratio := float(index) / float(VOLLEY_COUNT - 1)
		directions.append(skill_target_direction.rotated(lerpf(-VOLLEY_HALF_SPREAD, VOLLEY_HALF_SPREAD, ratio)))
	vine_volley_requested.emit(small_vine_origins, directions)
	small_vine_origins.clear()
	attacks_done = 0
	attack_timer = RING_COOLDOWN
	queue_redraw()

func take_damage(amount: int = 1) -> bool:
	if dead or not mature or amount <= 0:
		return false
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	if health > 0:
		return true
	dead = true
	collision_layer = 0
	died.emit(cell, _root_position())
	queue_redraw()
	return true

func _root_position() -> Vector2:
	return Vector2((cell.x + 0.5) * MeadowWorld.TILE_SIZE, (cell.y + 0.5) * MeadowWorld.TILE_SIZE)

func _draw() -> void:
	var root := _root_position()
	draw_shadow_ellipse(root + Vector2(0, 12), Vector2(28, 9), Color(0.05, 0.1, 0.1, 0.3))
	if dead:
		draw_line(root + Vector2(-18, 8), root + Vector2(18, -8), Color("#66513a"), 12.0)
		draw_circle(root + Vector2(20, -9), 10.0, Color("#7d6b43"))
		return
	if not mature:
		draw_line(root + Vector2(0, 8), root + Vector2(0, -10), Color("#705338"), 6.0)
		draw_circle(root + Vector2(-7, -11), 7.0, Color("#6e9f55"))
		draw_circle(root + Vector2(7, -9), 7.0, Color("#83b45e"))
		return
	draw_line(root + Vector2(0, 12), root + Vector2(0, -32), Color("#73513a"), 14.0)
	for branch in [Vector2(-28, -30), Vector2(28, -27), Vector2(-18, -48), Vector2(20, -50)]:
		draw_line(root + Vector2(0, -20), root + branch, Color("#73513a"), 7.0)
		draw_circle(root + branch, 13.0, Color("#658c4c"))
	draw_circle(root + Vector2(0, -42), 19.0, Color("#789e52"))
	if ring_duration_remaining > 0.0:
		var pulse_ratio := ring_duration_remaining / RING_DURATION
		draw_arc(root, 34.0 + (1.0 - pulse_ratio) * 12.0, 0.0, TAU, 32, Color("#b9f58a"), 3.0)
	if skill_windup > 0.0:
		for origin in small_vine_origins:
			draw_circle(origin, 9.0, Color("#a7d76e"))
			draw_arc(origin, 13.0, 0.0, TAU, 18, Color("#e8f5a6"), 2.0)
	for index in range(health):
		var angle := TAU * float(index) / float(MAX_HEALTH)
		draw_circle(root + Vector2.RIGHT.rotated(angle) * 31.0, 1.5, Color("#d8e98c"))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
