class_name MeadowMutatedPlant
extends MeadowPursuingPlant
## Green-seed mutation that adds a six-shot ring after landing.

signal projectile_requested(origin: Vector2, directions: Array[Vector2])

const RING_PROJECTILE_COUNT := 6
const MUTATED_PEA_SHEET := preload("res://image/Monster_pea_SP/ball-Sheet.png")
const MUTATED_PEA_WAIT_SHEET := preload("res://image/Monster_pea_SP/ball-wait-Sheet.png")

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
	var frame_index := clampi(
		int(progress * float(PEA_JUMP_FRAME_COUNT)),
		0,
		PEA_JUMP_FRAME_COUNT - 1
	)
	var frames: Array = PEA_RIGHT_FRAMES if jump_faces_right else PEA_LEFT_FRAMES
	var frame := int(frames[frame_index])
	var texture := MUTATED_PEA_SHEET
	var frame_size := PEA_FRAME_SIZE
	if not jumping:
		frame = int(Time.get_ticks_msec() / 420) % PEA_WAIT_FRAME_COUNT
		texture = MUTATED_PEA_WAIT_SHEET
		frame_size = PEA_WAIT_FRAME_SIZE
	var source := Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
	var display_size := Vector2(frame_size) * PEA_DISPLAY_SCALE
	var destination := Rect2(body_position - display_size * 0.5, display_size)
	if not jumping:
		destination.position += PEA_WAIT_CONTENT_OFFSET * PEA_DISPLAY_SCALE
	draw_texture_rect_region(texture, destination, source)
	for index in range(health):
		draw_circle(body_position + Vector2(-8 + index * 8, -22), 2.2, Color("#f0d070"))
