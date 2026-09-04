class_name MeadowShopPanel
extends Control
## Icon-driven wooden shop panel with hover details and signals.

signal buy_pressed
signal close_pressed

@onready var icon_hitbox: Control = $ItemIconHitbox
@onready var hover_details: Label = $HoverDetails
@onready var close_button: Button = $CloseButton

var icon_hovered := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	icon_hitbox.mouse_entered.connect(_on_icon_mouse_entered)
	icon_hitbox.mouse_exited.connect(_on_icon_mouse_exited)
	icon_hitbox.gui_input.connect(_on_icon_gui_input)
	close_button.pressed.connect(_on_close_button_pressed)
	hover_details.hide()
	queue_redraw()

func _draw() -> void:
	var panel := Rect2(0, 0, size.x, size.y)
	draw_rect(panel, Color("#5a392b"), true)
	draw_rect(panel, Color("#d2a466"), false, 4.0)
	for y in range(14, int(size.y), 18):
		draw_line(Vector2(10, y), Vector2(size.x - 10, y), Color(0.2, 0.1, 0.08, 0.22), 1.0)
	draw_circle(Vector2(18, 18), 2.0, Color("#e2b873"))
	draw_circle(Vector2(size.x - 18, size.y - 18), 2.0, Color("#e2b873"))
	_draw_yellow_ball(Vector2(size.x * 0.5, 72.0))
	if icon_hovered:
		draw_arc(Vector2(size.x * 0.5, 72.0), 27.0, 0.0, TAU, 32, Color("#f8df87"), 3.0, true)

func _draw_yellow_ball(center: Vector2) -> void:
	draw_circle(center + Vector2(0, 4), 25.0, Color(0.12, 0.06, 0.04, 0.5))
	draw_circle(center, 22.0, Color("#26353b"))
	draw_circle(center, 19.0, Color("#f3c969"))
	draw_circle(center + Vector2(-6, -7), 5.0, Color(1.0, 0.96, 0.72, 0.85))

func _on_icon_mouse_entered() -> void:
	icon_hovered = true
	hover_details.text = "Yellow Ball\nUse: launches a projectile through the meadow."
	hover_details.show()
	queue_redraw()

func _on_icon_mouse_exited() -> void:
	clear_hover()

func _on_icon_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		buy_pressed.emit()

func _on_close_button_pressed() -> void:
	close_pressed.emit()

func clear_hover() -> void:
	icon_hovered = false
	hover_details.hide()
	queue_redraw()
