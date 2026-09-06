class_name MeadowTreeLaser
extends Node2D
## Persistent ray emitted by 神树 while the trigger remains held.

const TEXTURE := preload("res://assets/generated/weapons/tree_gun.png")
const SOURCE_RECT := Rect2(381, 243, 805, 30)
const MAX_LENGTH := 2200.0
const DISPLAY_HEIGHT := 14.0
# The beam texture's emission center is at source y=20.0. Draw the
# destination around that center so it coincides with the charge point.
const SOURCE_BEAM_CENTER_Y := 20.0
const EMISSION_OFFSET_Y := -3.0
const DAMAGE_INTERVAL := 0.08

var direction := Vector2.RIGHT
var collision_space: PhysicsDirectSpaceState2D
var collision_mask := 1
var damage := 4
var source: Node
var damage_remaining := 0.0
var tint := Color.WHITE

func setup(
	origin: Vector2,
	aim: Vector2,
	space: PhysicsDirectSpaceState2D,
	target_mask: int,
	hit_damage: int,
	hit_source: Node,
	color := Color.WHITE
) -> void:
	collision_space = space
	collision_mask = target_mask
	damage = hit_damage
	source = hit_source
	tint = color
	update_beam(origin, aim)
	queue_redraw()

func update_beam(origin: Vector2, aim: Vector2) -> void:
	direction = aim.normalized() if aim.length_squared() > 0.001 else Vector2.RIGHT
	rotation = direction.angle()
	global_position = origin + Vector2(0.0, EMISSION_OFFSET_Y).rotated(rotation)
	queue_redraw()

func _physics_process(delta: float) -> void:
	damage_remaining = maxf(0.0, damage_remaining - delta)
	if damage_remaining > 0.0 or collision_space == null:
		return
	var ray_start := global_position
	var ray_end := global_position + direction * MAX_LENGTH
	var excluded_rids: Array[RID] = []
	if is_instance_valid(source):
		excluded_rids.append(source.get_rid())
	var damaged_target := false
	var hit_targets: Array[Object] = []
	for _index in range(32):
		var query := PhysicsRayQueryParameters2D.create(ray_start, ray_end)
		query.collision_mask = collision_mask
		query.collide_with_areas = true
		query.exclude = excluded_rids
		var hit := collision_space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider")
		var hit_position: Vector2 = hit.get("position", ray_end)
		var hit_rid: RID = hit.get("rid", RID())
		if hit_rid.is_valid():
			excluded_rids.append(hit_rid)
		if damage > 0 and collider != null and collider.has_method("take_damage") and collider not in hit_targets:
			hit_targets.append(collider)
			damaged_target = true
			if collider.take_damage(damage) and collider.has_method("get_damage_number_position"):
				MeadowDamageNumber.spawn(get_parent(), collider.get_damage_number_position(), damage)
		ray_start = hit_position + direction * 1.0
		if ray_start.distance_squared_to(ray_end) < 1.0:
			break
	if damaged_target:
		damage_remaining = DAMAGE_INTERVAL

func _draw() -> void:
	draw_texture_rect_region(
		TEXTURE,
		# Align the beam's visible center with the white charge-glow center at
		# the node origin. The source frame's center is below its crop midpoint.
		Rect2(
			Vector2(0.0, -SOURCE_BEAM_CENTER_Y * DISPLAY_HEIGHT / SOURCE_RECT.size.y),
			Vector2(MAX_LENGTH, DISPLAY_HEIGHT)
		),
		SOURCE_RECT,
		tint,
		false
	)
