extends Control
## Minimal radar overlay used to travel between in-world destinations.

signal point_selected(point_id: int)
signal close_pressed

@onready var close_button: Button = $CloseButton
@onready var meadow_point: Button = $MeadowPoint
@onready var pond_point: Button = $PondPoint
@onready var tree_point: Button = $TreePoint
@onready var title_label: Label = $Title
@onready var subtitle_label: Label = $SubTitle
@onready var point_labels: Label = $PointLabels

var language := "en"

func set_language(value: String) -> void:
	language = "zh" if value == "zh" else "en"
	if not is_node_ready():
		return
	var chinese := language == "zh"
	title_label.text = "导航雷达" if chinese else "NAVIGATION RADAR"
	subtitle_label.text = "选择信号前往" if chinese else "Select a signal to travel"
	point_labels.text = "01 绿野     02 静语池塘     03 世界树" if chinese else "01 GREENMEADOW     02 WHISPER POND     03 WORLD TREE"

func _ready() -> void:
	close_button.pressed.connect(func(): close_pressed.emit())
	meadow_point.pressed.connect(func(): point_selected.emit(1))
	pond_point.pressed.connect(func(): point_selected.emit(2))
	tree_point.pressed.connect(func(): point_selected.emit(3))
	queue_redraw()

func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color("#10262a"), true)
	draw_rect(panel, Color("#d2a466"), false, 3.0)
	draw_line(Vector2(20, 72), Vector2(size.x - 20, 72), Color(0.82, 0.64, 0.36, 0.7), 1.0)
	var center := Vector2(size.x * 0.5, 205.0)
	for radius in [112.0, 82.0, 50.0]:
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.48, 0.75, 0.65, 0.35), 1.0, true)
	draw_line(center + Vector2(-120, 0), center + Vector2(120, 0), Color(0.48, 0.75, 0.65, 0.2), 1.0)
	draw_line(center + Vector2(0, -120), center + Vector2(0, 120), Color(0.48, 0.75, 0.65, 0.2), 1.0)
	draw_circle(center, 6.0, Color("#f3c969"))
	draw_circle(center, 2.0, Color("#26353b"))
	for point in [Vector2(155, 147), Vector2(282, 262), Vector2(345, 141)]:
		draw_circle(point, 16.0, Color(0.38, 0.75, 0.62, 0.14))
