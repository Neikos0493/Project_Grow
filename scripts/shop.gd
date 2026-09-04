class_name MeadowShop
extends Node2D
## A tall, three-cell-wide procedural shop placeholder.

const WIDTH := 96.0
const HEIGHT := 76.0
const OUTLINE := Color("#26353b")

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# Ground shadow makes the three-cell footprint easy to read.
	draw_shop_shadow(Vector2(0, 11), Vector2(55, 9), Color(0.05, 0.1, 0.1, 0.28))
	# Tall wall: its top is lifted above the ground anchor to show height.
	draw_rect(Rect2(-WIDTH * 0.5, -58, WIDTH, 74), Color("#d3915e"), true)
	draw_rect(Rect2(-WIDTH * 0.5, -58, WIDTH, 74), OUTLINE, false, 3.0)
	# Side plane adds a simple top-down perspective cue.
	draw_colored_polygon(PackedVector2Array([
		Vector2(WIDTH * 0.5, -58), Vector2(WIDTH * 0.5 + 10, -48),
		Vector2(WIDTH * 0.5 + 10, 16), Vector2(WIDTH * 0.5, 16),
	]), Color("#9e684b"))
	draw_polyline(PackedVector2Array([
		Vector2(WIDTH * 0.5, -58), Vector2(WIDTH * 0.5 + 10, -48),
		Vector2(WIDTH * 0.5 + 10, 16),
	]), OUTLINE, 2.0, true)
	# Roof projects outward and sits above the tall wall.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-56, -63), Vector2(0, -84), Vector2(56, -63),
		Vector2(48, -48), Vector2(0, -64), Vector2(-48, -48),
	]), Color("#557f68"))
	draw_polyline(PackedVector2Array([
		Vector2(-56, -63), Vector2(0, -84), Vector2(56, -63),
		Vector2(48, -48), Vector2(0, -64), Vector2(-48, -48), Vector2(-56, -63),
	]), OUTLINE, 3.0, true)
	# Three facade bays align with the three ground cells.
	for x in [-32.0, 0.0, 32.0]:
		draw_line(Vector2(x, -45), Vector2(x, 13), Color("#a9694a"), 2.0)
	# Bright awning and sign.
	draw_rect(Rect2(-47, -34, 94, 13), Color("#e9c56b"), true)
	draw_line(Vector2(-47, -21), Vector2(47, -21), OUTLINE, 2.0)
	draw_rect(Rect2(-21, -13, 42, 29), Color("#5c82a0"), true)
	draw_rect(Rect2(-21, -13, 42, 29), OUTLINE, false, 2.0)
	draw_rect(Rect2(-29, -57, 58, 17), Color("#f1d67f"), true)
	draw_rect(Rect2(-29, -57, 58, 17), OUTLINE, false, 2.0)
	# Letter-like sign marks, keeping the placeholder self-contained.
	draw_line(Vector2(-20, -53), Vector2(-20, -44), Color("#704d3b"), 2.0)
	draw_line(Vector2(-25, -53), Vector2(-15, -53), Color("#704d3b"), 2.0)
	draw_line(Vector2(-11, -44), Vector2(-11, -53), Color("#704d3b"), 2.0)
	draw_line(Vector2(-11, -53), Vector2(-4, -48), Color("#704d3b"), 2.0)
	draw_line(Vector2(-4, -48), Vector2(-11, -44), Color("#704d3b"), 2.0)
	draw_line(Vector2(2, -53), Vector2(2, -44), Color("#704d3b"), 2.0)
	draw_line(Vector2(2, -53), Vector2(10, -53), Color("#704d3b"), 2.0)
	draw_line(Vector2(2, -48), Vector2(8, -48), Color("#704d3b"), 2.0)
	draw_line(Vector2(2, -44), Vector2(10, -44), Color("#704d3b"), 2.0)

func draw_shop_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
