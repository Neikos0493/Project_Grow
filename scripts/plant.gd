class_name MeadowPlant
extends CharacterBody2D
## A seed-grown pursuer that wakes when the player enters its alert radius.

signal matured(cell: Vector2i)
signal died(cell: Vector2i, position: Vector2)

const GROW_TIME := 3.0
const MAX_HEALTH := 3
const ALERT_RANGE := 210.0
const MOVE_SPEED := 74.0
const BITE_RANGE := 27.0
const BITE_DAMAGE := 1
const BITE_WINDUP := 0.28
const BITE_COOLDOWN := 1.05

var cell := Vector2i.ZERO
var target: MeadowPlayer
var health := MAX_HEALTH
var age := 0.0
var mature := false
var alerted := false
var dead := false
var bite_windup_remaining := 0.0
var bite_cooldown_remaining := 0.0
var walk_time := 0.0
var knockback_velocity := Vector2.ZERO

func setup(plant_cell: Vector2i, plant_target: MeadowPlayer) -> void:
	cell = plant_cell
	target = plant_target
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
	if knockback_velocity.length_squared() > 0.01:
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
	walk_time += delta
	bite_cooldown_remaining = maxf(0.0, bite_cooldown_remaining - delta)
	if not alerted and global_position.distance_to(target.global_position) <= ALERT_RANGE:
		alerted = true
		queue_redraw()
	if not alerted:
		velocity = Vector2.ZERO
		return
	var target_offset := target.global_position - global_position
	var target_distance := target_offset.length()
	if bite_windup_remaining > 0.0:
		bite_windup_remaining -= delta
		velocity = Vector2.ZERO
		if bite_windup_remaining <= 0.0 and target_distance <= BITE_RANGE + 8.0:
			target.take_damage(BITE_DAMAGE)
			bite_cooldown_remaining = BITE_COOLDOWN
		queue_redraw()
		return
	if target_distance <= BITE_RANGE and bite_cooldown_remaining <= 0.0:
		bite_windup_remaining = BITE_WINDUP
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if target_distance > BITE_RANGE:
		velocity = target_offset.normalized() * MOVE_SPEED
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	queue_redraw()

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
	velocity = Vector2.ZERO
	collision_layer = 0
	died.emit(cell, global_position)
	queue_free()
	return true

func _draw() -> void:
	if not mature:
		_draw_sprout()
		return
	_draw_pursuer()

func _draw_sprout() -> void:
	draw_shadow_ellipse(Vector2(0, 8), Vector2(12, 5), Color(0.05, 0.1, 0.1, 0.28))
	draw_line(Vector2(0, 7), Vector2(0, -8), Color("#24523a"), 4.0)
	draw_circle(Vector2(-5, -7), 7.0, Color("#4d9b55"))
	draw_circle(Vector2(5, -5), 7.0, Color("#5cb55e"))

func _draw_pursuer() -> void:
	var bob := sin(walk_time * 11.0) * 1.5 if velocity.length_squared() > 1.0 else 0.0
	var body_position := Vector2(0, -6 + bob)
	var outline := Color("#26353b")
	var body_color := Color("#4b9952") if alerted else Color("#5caa5d")
	var mouth_color := Color("#4a2632")
	var windup_ratio := bite_windup_remaining / BITE_WINDUP if BITE_WINDUP > 0.0 else 0.0
	draw_shadow_ellipse(Vector2(0, 10), Vector2(15, 6), Color(0.05, 0.1, 0.1, 0.32))
	for x_offset in [-8.0, 8.0]:
		draw_line(Vector2(x_offset * 0.5, 7), Vector2(x_offset, 14 + bob), Color("#24523a"), 3.0)
	draw_circle(body_position, 17.0, outline)
	draw_circle(body_position, 14.0, body_color)
	draw_circle(body_position + Vector2(-5, -3), 2.8, Color("#fff1bd"))
	draw_circle(body_position + Vector2(5, -3), 2.8, Color("#fff1bd"))
	draw_circle(body_position + Vector2(-5, -3), 1.3, outline)
	draw_circle(body_position + Vector2(5, -3), 1.3, outline)
	var mouth_height := 5.0 + windup_ratio * 7.0
	draw_colored_polygon(PackedVector2Array([
		body_position + Vector2(-9, 5), body_position + Vector2(9, 5), body_position + Vector2(0, 5 + mouth_height),
	]), mouth_color)
	if alerted:
		draw_arc(Vector2.ZERO, ALERT_RANGE, 0.0, TAU, 48, Color(0.91, 0.42, 0.33, 0.12), 1.0, true)
	if bite_windup_remaining > 0.0:
		draw_arc(body_position, 23.0, 0.0, TAU, 24, Color("#f3c969"), 2.0, true)
	for index in range(health):
		draw_circle(Vector2(-8 + index * 8, -28), 2.2, Color("#f0d070"))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
