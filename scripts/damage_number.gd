class_name MeadowDamageNumber
extends Label
## Floating red damage indicator shared by hostile plants.

const RISE_DISTANCE := 28.0
const DISPLAY_TIME := 0.65

static func spawn(parent: Node, world_position: Vector2, amount: int) -> void:
	_spawn_colored(parent, world_position, amount, "-%d", Color("#f04f4f"))

static func spawn_heal(parent: Node, world_position: Vector2, amount: int) -> void:
	_spawn_colored(parent, world_position, amount, "+%d", Color("#69e58a"))

static func _spawn_colored(parent: Node, world_position: Vector2, amount: int, format_string: String, color: Color) -> void:
	if parent == null or amount <= 0:
		return
	var number := MeadowDamageNumber.new()
	number.text = format_string % amount
	number.z_index = 100
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.position = Vector2(-24, -10)
	number.size = Vector2(48, 28)
	number.add_theme_color_override("font_color", color)
	number.add_theme_color_override("font_outline_color", Color("#3a151b"))
	number.add_theme_constant_override("outline_size", 4)
	number.add_theme_font_size_override("font_size", 18)
	parent.add_child(number)
	number.global_position = world_position
	var tween := number.create_tween().set_parallel(true)
	tween.tween_property(number, "position", number.position + Vector2(0, -RISE_DISTANCE), DISPLAY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, DISPLAY_TIME).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(number.queue_free)
