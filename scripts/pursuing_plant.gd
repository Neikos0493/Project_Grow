class_name MeadowPursuingPlant
extends CharacterBody2D
## Seed-grown enemy that attacks only by leaping at a nearby player position.

signal matured(cell: Vector2i)
signal died(cell: Vector2i, position: Vector2)

const GROW_TIME := 3.0
const MAX_HEALTH := 3
const PEA_SHEET := preload("res://image/Monster_pea/ball-Sheet.png")
const PEA_WAIT_SHEET := preload("res://image/Monster_pea/ball-wait-Sheet.png")
const PEA_FRAME_SIZE := Vector2i(24, 31)
const PEA_JUMP_FRAME_COUNT := 7
# Source frame numbers: left-to-right 1-6-5-4-5-6-1, right-to-left 1-2-3-4-3-2-1.
const PEA_LEFT_FRAMES := [0, 1, 2, 3, 2, 1, 0]
const PEA_RIGHT_FRAMES := [0, 5, 4, 3, 4, 5, 0]
const PEA_WAIT_FRAME_SIZE := Vector2i(67, 49)
const PEA_WAIT_FRAME_COUNT := 2
const PEA_DISPLAY_SCALE := 2.0
const PEA_COLLISION_RADIUS := 14.0
const PEA_WAIT_CONTENT_OFFSET := Vector2(22.0, 3.0)
const ATTACK_RANGE := 210.0
const JUMP_DURATION := 0.55
const JUMP_HEIGHT := 34.0
const HIT_RANGE := 28.0
const JUMP_DAMAGE := 1
const JUMP_COOLDOWN := 1.1

var entity_id := ""
var cell := Vector2i.ZERO
var target: MeadowPlayer
var world: MeadowWorld
var health := MAX_HEALTH
var age := 0.0
var mature := false
var dead := false
var jumping := false
var jump_elapsed := 0.0
var jump_cooldown_remaining := 0.0
var jump_origin := Vector2.ZERO
var jump_target := Vector2.ZERO
var jump_faces_right := false
var knockback_velocity := Vector2.ZERO

func setup(plant_cell: Vector2i, player_target: MeadowPlayer, map_world: MeadowWorld) -> void:
	cell = plant_cell
	target = player_target
	world = map_world
	queue_redraw()

func capture_state() -> Dictionary:
	var map_position := world.to_local(global_position) if is_instance_valid(world) else global_position
	return {
		"kind": "pursuing_plant",
		"mutated": self is MeadowMutatedPlant,
		"entity_id": entity_id,
		"cell": [cell.x, cell.y],
		"position": [map_position.x, map_position.y],
		"health": clampi(health, 1, MAX_HEALTH),
		"age": clampf(age, 0.0, GROW_TIME),
		"mature": mature,
		"jump_cooldown_remaining": maxf(0.0, jump_cooldown_remaining),
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
	jump_cooldown_remaining = clampf(float(data.get("jump_cooldown_remaining", 0.0)), 0.0, JUMP_COOLDOWN)
	dead = false
	jumping = false
	jump_elapsed = 0.0
	jump_origin = global_position
	jump_target = global_position
	knockback_velocity = Vector2.ZERO
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

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _get_collision_radius()
	shape_node.shape = circle
	add_child(shape_node)
	queue_redraw()

func _get_collision_radius() -> float:
	return PEA_COLLISION_RADIUS

func _physics_process(delta: float) -> void:
	if dead:
		return
	if knockback_velocity.length_squared() > 0.01 and not jumping:
		global_position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 220.0 * delta)
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
	if jumping:
		_update_jump(delta)
		return
	jump_cooldown_remaining = maxf(0.0, jump_cooldown_remaining - delta)
	if jump_cooldown_remaining <= 0.0 and global_position.distance_to(target.global_position) <= ATTACK_RANGE:
		_start_jump(target.global_position)
	queue_redraw()

func _start_jump(destination: Vector2) -> void:
	jumping = true
	jump_elapsed = 0.0
	jump_origin = global_position
	jump_target = destination
	var horizontal_delta := destination.x - global_position.x
	if absf(horizontal_delta) > 0.01:
		jump_faces_right = horizontal_delta > 0.0
	velocity = Vector2.ZERO
	queue_redraw()

func _update_jump(delta: float) -> void:
	jump_elapsed += delta
	var progress := minf(jump_elapsed / JUMP_DURATION, 1.0)
	global_position = jump_origin.lerp(jump_target, progress)
	if progress < 1.0:
		queue_redraw()
		return
	jumping = false
	jump_cooldown_remaining = JUMP_COOLDOWN
	if is_instance_valid(target) and not target.dead and global_position.distance_to(target.global_position) <= HIT_RANGE:
		target.take_damage(JUMP_DAMAGE)
	queue_redraw()

func apply_knockback(direction: Vector2, strength: float = 52.0) -> void:
	if dead or jumping or direction.length_squared() < 0.01:
		return
	knockback_velocity = direction.normalized() * maxf(0.0, strength)

func get_damage_number_position() -> Vector2:
	return global_position + Vector2(0, -34)

func take_damage(amount: int = 1) -> bool:
	if dead or not mature or amount <= 0:
		return false
	health = maxi(0, health - amount)
	queue_redraw()
	if health > 0:
		return true
	dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	died.emit(cell, global_position)
	queue_free()
	return true

func _draw() -> void:
	if not mature:
		_draw_sprout()
		return
	_draw_jumping_plant()

func _draw_sprout() -> void:
	draw_line(Vector2(0, 7), Vector2(0, -8), Color("#24523a"), 4.0)
	draw_circle(Vector2(-5, -7), 7.0, Color("#4d9b55"))
	draw_circle(Vector2(5, -5), 7.0, Color("#5cb55e"))

func _draw_jumping_plant() -> void:
	var progress := minf(jump_elapsed / JUMP_DURATION, 1.0) if jumping else 0.0
	var lift := sin(progress * PI) * JUMP_HEIGHT
	var body_position := Vector2(0, -6 - lift)
	var frame := 0
	var texture := PEA_SHEET
	var frame_size := PEA_FRAME_SIZE
	if jumping:
		var frame_index := clampi(
			int(progress * float(PEA_JUMP_FRAME_COUNT)),
			0,
			PEA_JUMP_FRAME_COUNT - 1
		)
		var frames: Array = PEA_RIGHT_FRAMES if jump_faces_right else PEA_LEFT_FRAMES
		frame = int(frames[frame_index])
	else:
		frame = int(Time.get_ticks_msec() / 420) % PEA_WAIT_FRAME_COUNT
		texture = PEA_WAIT_SHEET
		frame_size = PEA_WAIT_FRAME_SIZE
	var source := Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
	var display_size := Vector2(frame_size) * PEA_DISPLAY_SCALE
	var destination := Rect2(body_position - display_size * 0.5, display_size)
	if not jumping:
		destination.position += PEA_WAIT_CONTENT_OFFSET * PEA_DISPLAY_SCALE
	draw_texture_rect_region(texture, destination, source)
	for index in range(health):
		draw_circle(body_position + Vector2(-8 + index * 8, -22), 2.2, Color("#f0d070"))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
