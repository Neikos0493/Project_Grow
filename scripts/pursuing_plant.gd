class_name MeadowPursuingPlant
extends CharacterBody2D
## Seed-grown enemy that attacks only by leaping at a nearby player position.

signal matured(cell: Vector2i)
signal died(cell: Vector2i, position: Vector2)

const GROW_TIME := 3.0
const MAX_HEALTH := 3
const ATTACK_RANGE := 210.0
const JUMP_DURATION := 0.55
const JUMP_HEIGHT := 34.0
const HIT_RANGE := 28.0
const JUMP_DAMAGE := 1
const JUMP_COOLDOWN := 1.1

var cell := Vector2i.ZERO
var target: MeadowPlayer
var health := MAX_HEALTH
var age := 0.0
var mature := false
var dead := false
var jumping := false
var jump_elapsed := 0.0
var jump_cooldown_remaining := 0.0
var jump_origin := Vector2.ZERO
var jump_target := Vector2.ZERO
var knockback_velocity := Vector2.ZERO

func setup(plant_cell: Vector2i, player_target: MeadowPlayer) -> void:
	cell = plant_cell
	target = player_target
	queue_redraw()

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape_node.shape = circle
	add_child(shape_node)
	queue_redraw()

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
	draw_shadow_ellipse(Vector2(0, 8), Vector2(12, 5), Color(0.05, 0.1, 0.1, 0.28))
	draw_line(Vector2(0, 7), Vector2(0, -8), Color("#24523a"), 4.0)
	draw_circle(Vector2(-5, -7), 7.0, Color("#4d9b55"))
	draw_circle(Vector2(5, -5), 7.0, Color("#5cb55e"))

func _draw_jumping_plant() -> void:
	var progress := minf(jump_elapsed / JUMP_DURATION, 1.0) if jumping else 0.0
	var lift := sin(progress * PI) * JUMP_HEIGHT
	var body_position := Vector2(0, -6 - lift)
	var outline := Color("#26353b")
	draw_shadow_ellipse(Vector2(0, 10), Vector2(15, 6), Color(0.05, 0.1, 0.1, 0.32))
	draw_circle(body_position, 17.0, outline)
	draw_circle(body_position, 14.0, Color("#4b9952"))
	draw_circle(body_position + Vector2(-5, -3), 2.8, Color("#fff1bd"))
	draw_circle(body_position + Vector2(5, -3), 2.8, Color("#fff1bd"))
	draw_circle(body_position + Vector2(-5, -3), 1.3, outline)
	draw_circle(body_position + Vector2(5, -3), 1.3, outline)
	draw_colored_polygon(PackedVector2Array([
		body_position + Vector2(-9, 5), body_position + Vector2(9, 5), body_position + Vector2(0, 11),
	]), Color("#4a2632"))
	if jumping:
		draw_arc(body_position, 23.0, 0.0, TAU, 24, Color("#f3c969"), 2.0, true)
	for index in range(health):
		draw_circle(body_position + Vector2(-8 + index * 8, -22), 2.2, Color("#f0d070"))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
