class_name MeadowMeleeWeapon
extends Node2D
## Short-range melee swing with a procedural placeholder weapon.

const SWING_DURATION := 0.4
const HIT_TIME := 0.2
const REACH := 42.0
const WIDTH := 16.0
const HIT_DAMAGE := 1
const KNOCKBACK_STRENGTH := 52.0
const SWING_ARC := deg_to_rad(110.0)
const PLANT_MASK := 4
const WORLD_MASK := 1

@onready var player: MeadowPlayer = get_parent() as MeadowPlayer

var swinging := false
var swing_elapsed := 0.0
var swing_direction := Vector2.RIGHT
var hit_resolved := false
var hit_targets: Dictionary = {}
var hit_shape := RectangleShape2D.new()

func _ready() -> void:
	hit_shape.size = Vector2(REACH, WIDTH)
	visible = false
	queue_redraw()

func try_swing(direction: Vector2) -> bool:
	if swinging or not is_instance_valid(player) or player.dead or player.controls_locked:
		return false
	if direction.length_squared() < 0.01:
		return false
	swing_direction = direction.normalized()
	swing_elapsed = 0.0
	hit_resolved = false
	hit_targets.clear()
	swinging = true
	visible = true
	queue_redraw()
	return true

func cancel_swing() -> void:
	swinging = false
	swing_elapsed = 0.0
	hit_resolved = false
	hit_targets.clear()
	visible = false
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not swinging:
		return
	if not is_instance_valid(player) or player.dead or player.controls_locked:
		cancel_swing()
		return
	var previous_elapsed := swing_elapsed
	swing_elapsed = minf(swing_elapsed + delta, SWING_DURATION)
	if not hit_resolved and previous_elapsed < HIT_TIME and swing_elapsed >= HIT_TIME:
		hit_resolved = true
		_resolve_hits()
	queue_redraw()
	if swing_elapsed >= SWING_DURATION:
		cancel_swing()

func _resolve_hits() -> void:
	if not is_instance_valid(player):
		return
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hit_shape
	query.transform = Transform2D(swing_direction.angle(), player.global_position + swing_direction * REACH * 0.5)
	query.collision_mask = PLANT_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [player.get_rid()]
	for result in space.intersect_shape(query, 32):
		var collider: Object = result.get("collider")
		if collider == null or not is_instance_valid(collider) or not collider.has_method("take_damage"):
			continue
		var target_id := collider.get_instance_id()
		if hit_targets.has(target_id) or not _is_visible_target(collider):
			continue
		if not collider.take_damage(HIT_DAMAGE):
			continue
		hit_targets[target_id] = true
		if collider.has_method("apply_knockback"):
			collider.apply_knockback(swing_direction, KNOCKBACK_STRENGTH)

func _is_visible_target(target: Object) -> bool:
	if not target is Node2D:
		return false
	var target_position := (target as Node2D).global_position
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, target_position)
	ray.collision_mask = WORLD_MASK
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _draw() -> void:
	if not swinging:
		return
	var progress := swing_elapsed / SWING_DURATION
	var swing_angle := swing_direction.angle() - SWING_ARC * 0.5 + SWING_ARC * progress
	draw_set_transform(Vector2.ZERO, swing_angle, Vector2.ONE)
	var weapon_rect := Rect2(Vector2(7.0, -WIDTH * 0.5), Vector2(REACH, WIDTH))
	draw_rect(weapon_rect.grow(2.0), Color(0.05, 0.1, 0.1, 0.65), true)
	draw_rect(weapon_rect, Color("#f3c969"), true)
	draw_rect(weapon_rect, Color("#26353b"), false, 2.0)
	draw_rect(Rect2(weapon_rect.position + Vector2(4.0, 3.0), Vector2(REACH - 8.0, 3.0)), Color(1.0, 0.96, 0.72, 0.8), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
