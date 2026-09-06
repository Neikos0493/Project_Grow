class_name MeadowProjectile
extends Node2D
## Fast swept projectile that can damage a selected target layer.

const SPEED := 420.0
const LIFETIME := 1.5
const BEAM_LIFETIME := 0.22
const RADIUS := 6.0
const DAMAGE_NUMBER := preload("res://scripts/damage_number.gd")
const MUTATED_PEA_TEXTURE := preload("res://image/Monster_pea_SP/ball.png")
const MUTATED_PEA_SOURCE_RECT := Rect2(9, 7, 5, 5)
const MUTATED_PEA_DISPLAY_SIZE := Vector2(12.0, 12.0)

var direction := Vector2.RIGHT
var age := 0.0
var collision_space: PhysicsDirectSpaceState2D
var collision_mask := 1
var damage := 0
var source: Node
var tint := Color("#f3c969")
var speed := SPEED
var trail_length := 0.0
var projectile_texture: Texture2D
var projectile_source_rect := Rect2(0, 0, 0, 0)
var projectile_display_size := Vector2.ZERO
var projectile_rotation_offset := 0.0
var beam_texture: Texture2D
var beam_source_rects: Array[Rect2] = []
var beam_display_length := 0.0
var beam_display_height := 0.0
var beam_frame := 0
var beam_frame_elapsed := 0.0
var beam_animated := false
var beam_collision_checked := false
var homing_target: Node2D
var homing_remaining := 0.0
var max_range := 0.0
var traveled_distance := 0.0

func setup(origin: Vector2, aim: Vector2, space: PhysicsDirectSpaceState2D, target_mask: int = 1, hit_damage: int = 0, hit_source: Node = null, color := Color("#f3c969"), projectile_speed: float = SPEED, beam_length: float = 0.0, visual_texture: Texture2D = null, visual_source_rect := Rect2(0, 0, 0, 0), visual_display_size := Vector2.ZERO, rotation_offset := 0.0, animated_beam := false) -> void:
	global_position = origin
	direction = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	collision_space = space
	collision_mask = target_mask
	damage = hit_damage
	source = hit_source
	tint = color
	speed = projectile_speed
	trail_length = maxf(0.0, beam_length)
	projectile_texture = visual_texture
	projectile_source_rect = visual_source_rect
	projectile_display_size = visual_display_size
	projectile_rotation_offset = rotation_offset
	beam_animated = animated_beam
	beam_frame = 0
	beam_frame_elapsed = 0.0
	rotation = direction.angle() + projectile_rotation_offset
	queue_redraw()

func enable_homing(target: Node2D, duration: float) -> void:
	homing_target = target
	homing_remaining = maxf(0.0, duration)

func set_max_range(value: float) -> void:
	max_range = maxf(0.0, value)

func _physics_process(delta: float) -> void:
	age += delta
	if beam_animated and trail_length > 0.0:
		beam_frame_elapsed += delta
		if beam_frame_elapsed >= 0.08:
			beam_frame_elapsed = 0.0
			beam_frame = (beam_frame + 1) % 5
			queue_redraw()
	if age >= (BEAM_LIFETIME if beam_animated else LIFETIME):
		queue_free()
		return
	var from := global_position
	if homing_remaining > 0.0 and is_instance_valid(homing_target):
		homing_remaining = maxf(0.0, homing_remaining - delta)
		var target_direction := homing_target.global_position - global_position
		if target_direction.length_squared() > 0.01:
			direction = direction.slerp(target_direction.normalized(), minf(1.0, delta * 4.0)).normalized()
		rotation = direction.angle() + projectile_rotation_offset
	var to := from + direction * speed * delta
	if max_range > 0.0:
		var step_distance := from.distance_to(to)
		traveled_distance += step_distance
		if traveled_distance >= max_range:
			queue_free()
			return
	if beam_animated:
		to = from + direction * trail_length
	if collision_space != null:
		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		if is_instance_valid(source):
			query.exclude = [source.get_rid()]
		var hit := collision_space.intersect_ray(query)
		if not hit.is_empty():
			var collider: Object = hit.get("collider")
			if damage > 0 and collider != null and collider.has_method("take_damage"):
				if collider.take_damage(damage) and collider.has_method("get_damage_number_position"):
					DAMAGE_NUMBER.spawn(get_parent(), collider.get_damage_number_position(), damage)
			global_position = hit["position"]
			queue_free()
			return
	global_position = to
	queue_redraw()

func _draw() -> void:
	if trail_length > 0.0:
		var local_direction := direction.rotated(-rotation)
		var local_trail := local_direction * trail_length
		var local_tip := local_direction * 4.0
		if beam_animated and beam_texture != null and beam_source_rects.size() == 5:
			var frame_rect: Rect2 = beam_source_rects[beam_frame]
			var beam_rect := Rect2(Vector2(0.0, -7.0), Vector2(trail_length, 14.0))
			draw_texture_rect_region(beam_texture, beam_rect, frame_rect, tint, false)
		else:
			draw_line(-local_trail, local_tip, Color(0.05, 0.1, 0.1, 0.55), 7.0)
			draw_line(-local_trail, local_tip, tint, 3.0)
	if projectile_texture != null and projectile_display_size.x > 0.0 and projectile_display_size.y > 0.0 and projectile_source_rect.size.x > 0.0 and projectile_source_rect.size.y > 0.0:
		var destination := Rect2(-projectile_display_size * 0.5, projectile_display_size)
		draw_texture_rect_region(projectile_texture, destination, projectile_source_rect)
		return
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.05, 0.1, 0.1, 0.5))
	draw_circle(Vector2.ZERO, RADIUS, tint)
	draw_circle(Vector2(-2, -2), 1.8, Color(1, 0.97, 0.75, 0.9))
