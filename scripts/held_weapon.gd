class_name MeadowHeldWeapon
extends Node2D
## Displays the selected ranged weapon in the player's hands.

const BOW_TEXTURE := preload("res://assets/generated/weapons/forest_bow.png")
const GUN_TEXTURE := preload("res://assets/generated/weapons/tree_gun.png")
const BOW_SOURCE_RECT := Rect2(377, 8, 286, 821)
const GUN_SOURCE_RECT := Rect2(40, 311, 330, 245)
# The bow source art is left-facing. Keep this separate from the logical aim
# direction so its string and the arrow share the same forward direction.
const BOW_SOURCE_FORWARD := Vector2.LEFT
const BOW_DRAW_ROTATION := deg_to_rad(-40.0)
const BOW_DRAW_SCALE := 0.06
const BOW_DRAW_OFFSET := Vector2(6, -2)
const BOW_HAND_FORWARD_OFFSET := 12.0
const GUN_SOURCE_FORWARD := Vector2.RIGHT
# The muzzle is measured in the same local space as the displayed gun art.
# Keep this as the single source for both the charge glow and the laser origin.
const GUN_MUZZLE_POSITION := Vector2(57.0, -7.0)

var weapon_id := ""
var aim_direction := Vector2.RIGHT
var charge_elapsed := 0.0

func set_weapon(value: String, direction: Vector2, charge: float = 0.0) -> void:
	weapon_id = value
	aim_direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	charge_elapsed = maxf(0.0, charge)
	position = aim_direction * BOW_HAND_FORWARD_OFFSET if value == "bow" else Vector2.ZERO
	# Node2D rotation is applied around the source art. Compensate for each
	# source's forward axis instead of assuming every weapon points +X.
	rotation = aim_direction.angle() - _source_forward_angle(value)
	queue_redraw()

func _source_forward_angle(value: String) -> float:
	if value == "bow":
		return BOW_SOURCE_FORWARD.rotated(BOW_DRAW_ROTATION).angle()
	return GUN_SOURCE_FORWARD.angle()

func set_charge(value: float) -> void:
	charge_elapsed = maxf(0.0, value)
	queue_redraw()

func _process(_delta: float) -> void:
	if visible and weapon_id == "tree_gun" and charge_elapsed > 0.0:
		queue_redraw()

func get_muzzle_global_position() -> Vector2:
	return to_global(GUN_MUZZLE_POSITION)

func _draw() -> void:
	if weapon_id == "bow":
		# The source bow points diagonally; rotate its cropped art into the aim direction.
		draw_set_transform(
				BOW_DRAW_OFFSET,
				BOW_DRAW_ROTATION,
				Vector2(BOW_DRAW_SCALE, BOW_DRAW_SCALE)
			)
		draw_texture_rect_region(BOW_TEXTURE, Rect2(-143, -410.5, 286, 821), BOW_SOURCE_RECT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif weapon_id == "tree_gun":
		draw_set_transform(Vector2(8, -4), 0.0, Vector2(0.15, 0.15))
		draw_texture_rect_region(GUN_TEXTURE, Rect2(0, -135, 370, 270), GUN_SOURCE_RECT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if charge_elapsed > 0.0:
			var pulse := 0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.02)
			var muzzle := GUN_MUZZLE_POSITION
			draw_circle(muzzle, 7.0 + charge_elapsed * 4.0, Color(0.3, 1.0, 0.2, pulse))
			draw_circle(muzzle, 3.0, Color(0.85, 1.0, 0.72, 0.95))
