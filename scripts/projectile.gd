class_name MeadowProjectile
extends Node2D
## Fast swept projectile that can damage a selected target layer.

const SPEED := 420.0
const LIFETIME := 1.5
const RADIUS := 6.0
const DAMAGE_NUMBER := preload("res://scripts/damage_number.gd")

var direction := Vector2.RIGHT
var age := 0.0
var collision_space: PhysicsDirectSpaceState2D
var collision_mask := 1
var damage := 0
var source: Node
var tint := Color("#f3c969")
var speed := SPEED
var trail_length := 0.0

func setup(origin: Vector2, aim: Vector2, space: PhysicsDirectSpaceState2D, target_mask: int = 1, hit_damage: int = 0, hit_source: Node = null, color := Color("#f3c969"), projectile_speed: float = SPEED, beam_length: float = 0.0) -> void:
	global_position = origin
	direction = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	collision_space = space
	collision_mask = target_mask
	damage = hit_damage
	source = hit_source
	tint = color
	speed = projectile_speed
	trail_length = maxf(0.0, beam_length)
	queue_redraw()

func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	var from := global_position
	var to := from + direction * speed * delta
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
		var local_direction := global_transform.affine_inverse().basis_xform(direction)
		var local_trail := global_transform.affine_inverse().basis_xform(
			direction * trail_length
		)
		var local_tip := global_transform.affine_inverse().basis_xform(
			direction * 4.0
		)
		if local_direction.length_squared() > 0.0001:
			local_direction = local_direction.normalized()
		draw_line(-local_trail, local_tip, Color(0.05, 0.1, 0.1, 0.55), 7.0)
		draw_line(-local_trail, local_tip, tint, 3.0)
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0.05, 0.1, 0.1, 0.5))
	draw_circle(Vector2.ZERO, RADIUS, tint)
	draw_circle(Vector2(-2, -2), 1.8, Color(1, 0.97, 0.75, 0.9))
