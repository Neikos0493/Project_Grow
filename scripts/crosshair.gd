class_name MeadowCrosshair
extends Control
## Viewport-fixed mouse reticle, drawn without an external texture.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var cursor := get_local_mouse_position()
	var dark := Color(0.0, 0.0, 0.0, 0.95)
	var bright := Color.BLACK
	var arms := 8.0
	var gap := 3.0
	# Dark under-strokes preserve visibility on both light and dark tiles.
	draw_line(cursor + Vector2(-arms, 0), cursor + Vector2(-gap, 0), dark, 4.0)
	draw_line(cursor + Vector2(gap, 0), cursor + Vector2(arms, 0), dark, 4.0)
	draw_line(cursor + Vector2(0, -arms), cursor + Vector2(0, -gap), dark, 4.0)
	draw_line(cursor + Vector2(0, gap), cursor + Vector2(0, arms), dark, 4.0)
	draw_line(cursor + Vector2(-arms, 0), cursor + Vector2(-gap, 0), bright, 1.5)
	draw_line(cursor + Vector2(gap, 0), cursor + Vector2(arms, 0), bright, 1.5)
	draw_line(cursor + Vector2(0, -arms), cursor + Vector2(0, -gap), bright, 1.5)
	draw_line(cursor + Vector2(0, gap), cursor + Vector2(0, arms), bright, 1.5)
	draw_circle(cursor, 2.0, bright)
