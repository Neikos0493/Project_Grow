class_name MeadowMutatedPlant
extends MeadowPursuingPlant
## Green-seed mutation that adds a six-shot ring after landing.

signal projectile_requested(origin: Vector2, directions: Array[Vector2])

const RING_PROJECTILE_COUNT := 6

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
	_emit_ring_projectiles()
	queue_redraw()

func _emit_ring_projectiles() -> void:
	var directions: Array[Vector2] = []
	for index in range(RING_PROJECTILE_COUNT):
		directions.append(Vector2.RIGHT.rotated(TAU * float(index) / float(RING_PROJECTILE_COUNT)))
	projectile_requested.emit(global_position, directions)

func _draw_jumping_plant() -> void:
	var progress := minf(jump_elapsed / JUMP_DURATION, 1.0) if jumping else 0.0
	var lift := sin(progress * PI) * JUMP_HEIGHT
	var body_position := Vector2(0, -6 - lift)
	var outline := Color("#26353b")
	draw_shadow_ellipse(Vector2(0, 10), Vector2(15, 6), Color(0.05, 0.1, 0.1, 0.32))
	draw_circle(body_position, 17.0, outline)
	draw_circle(body_position, 14.0, Color("#f3c969"))
	draw_circle(body_position + Vector2(-5, -3), 2.8, Color("#fff1bd"))
	draw_circle(body_position + Vector2(5, -3), 2.8, Color("#fff1bd"))
	draw_circle(body_position + Vector2(-5, -3), 1.3, outline)
	draw_circle(body_position + Vector2(5, -3), 1.3, outline)
	draw_colored_polygon(PackedVector2Array([
		body_position + Vector2(-9, 5), body_position + Vector2(9, 5), body_position + Vector2(0, 11),
	]), Color("#592d37"))
	if jumping:
		draw_arc(body_position, 23.0, 0.0, TAU, 24, Color("#f3c969"), 2.0, true)
	else:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color(0.45, 0.77, 0.37, 0.16), 1.0, true)
	for index in range(health):
		draw_circle(body_position + Vector2(-8 + index * 8, -22), 2.2, Color("#f0d070"))
