extends Control
## Full-screen fade used while the real in-world spaceship travels.

var overlay_alpha := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func play_departure(target_scene: String) -> void:
	show()
	overlay_alpha = 0.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_interval(0.82)
	tween.tween_method(_set_overlay_alpha, 0.0, 1.0, 0.32)
	tween.tween_callback(func(): get_tree().change_scene_to_file(target_scene))

func play_arrival() -> void:
	show()
	overlay_alpha = 1.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_overlay_alpha, 1.0, 0.0, 0.7)
	tween.tween_callback(hide)

func _set_overlay_alpha(value: float) -> void:
	overlay_alpha = value
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.08, 0.09, overlay_alpha), true)
