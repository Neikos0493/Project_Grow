class_name MeadowTravelTransition
extends Control
## Awaitable full-screen fade used while MapHost replaces the active map.

var overlay_alpha := 0.0
var _active_tween: Tween
signal cover_finished
signal reveal_finished

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func cover() -> void:
	_stop_active_tween()
	show()
	overlay_alpha = 0.0
	queue_redraw()
	_active_tween = create_tween()
	_active_tween.tween_interval(0.82)
	_active_tween.tween_method(_set_overlay_alpha, 0.0, 1.0, 0.32)
	await _active_tween.finished
	cover_finished.emit()

func reveal() -> void:
	_stop_active_tween()
	show()
	overlay_alpha = 1.0
	queue_redraw()
	_active_tween = create_tween()
	_active_tween.tween_method(_set_overlay_alpha, 1.0, 0.0, 0.7)
	await _active_tween.finished
	hide()
	reveal_finished.emit()

func _stop_active_tween() -> void:
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null

func _set_overlay_alpha(value: float) -> void:
	overlay_alpha = value
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.08, 0.09, overlay_alpha), true)
