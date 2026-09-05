class_name MeadowShop
extends Node2D
## Imported shop sprite shared by both map scenes.

const SHOP_TEXTURE := preload("res://image/shop/shop2.png")
const SHOP_SIZE := Vector2(128.0, 96.0)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Keep the shadow in the bottom blocked footprint row, close to the sprite.
	# Move the visual down one tile while keeping the shadow attached to its base.
	draw_shop_shadow(Vector2(0, 32), Vector2(54, 5), Color(0.05, 0.1, 0.1, 0.38))
	# The node position and collision footprint remain unchanged.
	draw_texture_rect(SHOP_TEXTURE, Rect2(Vector2(-SHOP_SIZE.x * 0.5, -SHOP_SIZE.y + 32.0), SHOP_SIZE), false)

func draw_shop_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
