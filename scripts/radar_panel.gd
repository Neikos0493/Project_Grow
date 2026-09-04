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

const RADAR_CENTER_Y := 205.0
const ORBIT_RADII := [50.0, 82.0, 112.0]
const ORBIT_COLOR := Color("#879396")
const POINT_RADII := [82.0, 50.0, 112.0]
const POINT_COLORS := [Color("#63bb78"), Color("#df655f"), Color("#5b8fdf")]
const POINT_ANGLES_DEGREES := [-140.0, 35.0, -25.0]
const POINT_SIZES := [24.0, 20.0, 20.0]

func _ready() -> void:
	close_button.pressed.connect(func(): close_pressed.emit())
	meadow_point.pressed.connect(func(): point_selected.emit(1))
	pond_point.pressed.connect(func(): point_selected.emit(2))
	tree_point.pressed.connect(func(): point_selected.emit(3))
	_configure_point(meadow_point, POINT_COLORS[0], POINT_SIZES[0])
	_configure_point(pond_point, POINT_COLORS[1], POINT_SIZES[1])
	_configure_point(tree_point, POINT_COLORS[2], POINT_SIZES[2])
	_layout_points()
	resized.connect(_layout_points)
	queue_redraw()

func _configure_point(point: Button, color: Color, point_size: float) -> void:
	point.text = ""
	point.custom_minimum_size = Vector2(point_size, point_size)
	point.size = Vector2(point_size, point_size)
	point.add_theme_color_override("font_color", Color.TRANSPARENT)
	point.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	point.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	point.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	var normal := _make_point_style(color.darkened(0.12), color.lightened(0.18), point_size)
	var hover := _make_point_style(color.lightened(0.1), Color("#f7e7af"), point_size)
	point.add_theme_stylebox_override("normal", normal)
	point.add_theme_stylebox_override("hover", hover)
	point.add_theme_stylebox_override("pressed", hover)
	point.add_theme_stylebox_override("focus", hover)

func _make_point_style(color: Color, border_color: Color, point_size: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = int(point_size * 0.5)
	style.corner_radius_top_right = int(point_size * 0.5)
	style.corner_radius_bottom_right = int(point_size * 0.5)
	style.corner_radius_bottom_left = int(point_size * 0.5)
	return style

func _layout_points() -> void:
	if not is_node_ready():
		return
	var points: Array[Button] = [meadow_point, pond_point, tree_point]
	for index in range(points.size()):
		var point_position := _get_point_position(index)
		points[index].position = point_position - Vector2.ONE * float(POINT_SIZES[index]) * 0.5
	queue_redraw()

func _get_radar_center() -> Vector2:
	return Vector2(size.x * 0.5, RADAR_CENTER_Y)

func _get_point_position(index: int) -> Vector2:
	var angle := deg_to_rad(float(POINT_ANGLES_DEGREES[index]))
	return _get_radar_center() + Vector2(cos(angle), sin(angle)) * float(POINT_RADII[index])

func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(panel, Color("#10262a"), true)
	draw_rect(panel, Color("#d2a466"), false, 3.0)
	draw_line(Vector2(20, 72), Vector2(size.x - 20, 72), Color(0.82, 0.64, 0.36, 0.7), 1.0)
	var center := _get_radar_center()
	for index in range(ORBIT_RADII.size()):
		var orbit_color := ORBIT_COLOR
		orbit_color.a = 0.62
		draw_arc(center, float(ORBIT_RADII[index]), 0.0, TAU, 64, orbit_color, 2.0, true)
	var crosshair_color := Color(0.48, 0.75, 0.65, 0.2)
	var crosshair_radius := float(ORBIT_RADII[ORBIT_RADII.size() - 1])
	draw_line(center + Vector2(-crosshair_radius, 0), center + Vector2(crosshair_radius, 0), crosshair_color, 1.0)
	draw_line(center + Vector2(0, -crosshair_radius), center + Vector2(0, crosshair_radius), crosshair_color, 1.0)
	draw_circle(center, 6.0, Color("#f3c969"))
	draw_circle(center, 2.0, Color("#26353b"))
	for index in range(ORBIT_RADII.size()):
		var marker_color: Color = POINT_COLORS[index]
		marker_color.a = 0.18
		draw_circle(_get_point_position(index), float(POINT_SIZES[index]) * 0.8, marker_color)
