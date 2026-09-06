class_name MeadowStoryAnimation
extends Control
## Full-screen ending frame animation.

signal finished

const END_TEXTURE := preload("res://assets/End.png")
const FRAME_COUNT := 31
const FRAME_DURATION := 0.5
const FINAL_HOLD_DURATION := 3.0

var frame_index := 0
var frame_elapsed := 0.0
var final_hold_elapsed := 0.0

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 200
	queue_redraw()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	if frame_index == FRAME_COUNT - 1:
		final_hold_elapsed += delta
		if final_hold_elapsed >= FINAL_HOLD_DURATION:
			finished.emit()
			queue_free()
		return
	frame_elapsed += delta
	if frame_elapsed >= FRAME_DURATION:
		frame_elapsed -= FRAME_DURATION
		frame_index += 1
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK, true)
	var texture_width := END_TEXTURE.get_width()
	var texture_height := END_TEXTURE.get_height()
	var source_left := floorf(float(frame_index * texture_width) / float(FRAME_COUNT))
	var source_right := floorf(float((frame_index + 1) * texture_width) / float(FRAME_COUNT))
	var source := Rect2(source_left, 0.0, source_right - source_left, texture_height)
	var scale_factor := floorf(minf(size.x / source.size.x, size.y / float(texture_height)))
	scale_factor = maxf(1.0, scale_factor)
	var destination_size := source.size * scale_factor
	var destination := Rect2((size - destination_size) * 0.5, destination_size)
	draw_texture_rect_region(END_TEXTURE, destination, source)
