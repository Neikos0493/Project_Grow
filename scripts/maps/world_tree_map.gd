class_name WorldTreeMap
extends MeadowWorld
## Inner realm unlocked after feeding the World Tree 100 energy.

const MAP_ID := &"world_tree"
const PLAYER_START_CELL := Vector2i(20, 20)
const SHIP_CELL := Vector2i(20, 2)
const TREE_CENTER_CELL := Vector2i(20, 12)
const TREE_HALF_SIZE := 2

func get_map_id() -> StringName:
	return MAP_ID

func get_level_title() -> String:
	return "世界树内境" if language == "zh" else "WORLD TREE REALM"

func get_level_subtitle() -> String:
	return "能量汇聚之地" if language == "zh" else "Where the gathered energy converges"

func get_arrival_message() -> String:
	return "你抵达了世界树内境。" if language == "zh" else "You reached the World Tree realm."

func get_respawn_message() -> String:
	return "你回到了世界树内境。" if language == "zh" else "You returned to the World Tree realm."

func get_initial_spawn_cell() -> Vector2i:
	return PLAYER_START_CELL

func get_respawn_cell() -> Vector2i:
	return PLAYER_START_CELL

func get_ship_cell() -> Vector2i:
	return SHIP_CELL

func get_shop_node() -> MeadowShop:
	return null

func _build_map() -> void:
	_initialize_grid(GRASS)
	for x in range(MAP_SIZE.x):
		cells[0][x] = ROCK
		cells[MAP_SIZE.y - 1][x] = ROCK
	for y in range(MAP_SIZE.y):
		cells[y][0] = ROCK
		cells[y][MAP_SIZE.x - 1] = ROCK
	for x in range(1, MAP_SIZE.x - 1):
		cells[12][x] = PATH
	for y in range(1, MAP_SIZE.y - 1):
		cells[y][20] = PATH
	for y in range(TREE_CENTER_CELL.y - TREE_HALF_SIZE, TREE_CENTER_CELL.y + TREE_HALF_SIZE + 1):
		for x in range(TREE_CENTER_CELL.x - TREE_HALF_SIZE, TREE_CENTER_CELL.x + TREE_HALF_SIZE + 1):
			cells[y][x] = PATH
	props = [
		{
			"id": "world_tree.ship",
			"cell": SHIP_CELL,
			"kind": "spaceship",
			"used": false,
			"no_collision": true,
			"label_en": "Open navigation radar",
			"label_zh": "打开导航雷达",
			"message_en": "Navigation radar ready.",
			"message_zh": "导航雷达已准备就绪。",
		}
	]

func _add_map_collisions(map_collisions: StaticBody2D) -> void:
	_add_rectangle_collision(
		map_collisions,
		cell_to_world(TREE_CENTER_CELL),
		Vector2(float(TILE_SIZE * 5), float(TILE_SIZE * 5))
	)

func _draw_background() -> void:
	draw_rect(Rect2(0, -SCENIC_TOP_PIXELS, MAP_SIZE.x * TILE_SIZE, SCENIC_TOP_PIXELS), Color("#182f38"))
	draw_circle(cell_to_world(TREE_CENTER_CELL) + Vector2(0, -210), 190.0, Color(0.28, 0.62, 0.52, 0.15))
	draw_circle(cell_to_world(TREE_CENTER_CELL) + Vector2(0, -210), 125.0, Color(0.42, 0.86, 0.66, 0.12))

func _draw_scenery_after_tiles() -> void:
	var center := cell_to_world(TREE_CENTER_CELL)
	var outline := Color("#26353b")
	var trunk := Color("#6d5237")
	_draw_flat_ellipse(center + Vector2(0, 72), Vector2(78, 16), Color(0.04, 0.1, 0.1, 0.34))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-42, 70), center + Vector2(-30, -62), center + Vector2(-15, -164),
		center + Vector2(18, -164), center + Vector2(34, -70), center + Vector2(46, 70),
	]), trunk)
	draw_polyline(PackedVector2Array([
		center + Vector2(-42, 70), center + Vector2(-30, -62), center + Vector2(-15, -164),
		center + Vector2(18, -164), center + Vector2(34, -70), center + Vector2(46, 70),
	]), outline, 4.0, true)
	for branch in [
		[Vector2(-8, -118), Vector2(-126, -190)],
		[Vector2(-2, -148), Vector2(-180, -224)],
		[Vector2(12, -110), Vector2(130, -184)],
		[Vector2(16, -145), Vector2(184, -218)],
	]:
		draw_line(center + branch[0], center + branch[1], trunk, 12.0)
		draw_line(center + branch[0], center + branch[1], outline, 2.0)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var crown_center := center + Vector2.RIGHT.rotated(angle) * (112.0 + float((index * 17) % 42)) + Vector2(0, -198)
		var radius := 42.0 + float((index * 11) % 22)
		draw_circle(crown_center, radius, Color("#4d9b68" if index % 2 == 0 else "#72bf72", 0.92))
		draw_circle(crown_center + Vector2(-10, -8), radius * 0.55, Color("#a3e28a", 0.3))
		draw_arc(crown_center, radius, 0.0, TAU, 20, outline, 2.0, true)

func _draw_flat_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
