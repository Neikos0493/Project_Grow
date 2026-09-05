class_name SunsetShoreMap
extends MeadowWorld
## Independently owned Sunset Shore terrain, props, and beach scenery.

const MAP_ID := &"sunset_shore"
const PLAYER_START_CELL := Vector2i(14, 13)
const SHOP_CELL := Vector2i(15, 9)
const SHIP_CELL := Vector2i(20, 1)
const BEACH_BACKDROP_TEXTURE := preload("res://assets/beach_backdrop.png")

func get_map_id() -> StringName:
	return MAP_ID

func supports_orange_farming() -> bool:
	return true

func supports_saxaul_encounter() -> bool:
	return true

func get_level_title() -> String:
	return "日落海岸" if language == "zh" else "SUNSET SHORE"

func get_level_subtitle() -> String:
	return "海风吹过沙丘与栈道" if language == "zh" else "Sea wind moves across dunes and boardwalks"

func get_arrival_message() -> String:
	return "日落海岸已抵达。" if language == "zh" else "Sunset Shore reached."

func get_respawn_message() -> String:
	return "你回到了日落海岸。" if language == "zh" else "You returned to Sunset Shore."

func get_initial_spawn_cell() -> Vector2i:
	return PLAYER_START_CELL

func get_respawn_cell() -> Vector2i:
	return PLAYER_START_CELL

func get_ship_cell() -> Vector2i:
	return SHIP_CELL

func get_shop_node() -> MeadowShop:
	return get_node("Shop") as MeadowShop

func _build_map() -> void:
	_initialize_grid(SAND)
	for x in range(MAP_SIZE.x):
		cells[0][x] = ROCK
		cells[MAP_SIZE.y - 1][x] = ROCK
	for y in range(MAP_SIZE.y):
		cells[y][0] = ROCK
		cells[y][MAP_SIZE.x - 1] = ROCK
	for y in range(1, MAP_SIZE.y - 1):
		for x in range(26, MAP_SIZE.x - 1):
			cells[y][x] = WATER
	for x in range(2, 27):
		cells[14][x] = PATH
	for y in range(1, 15):
		cells[y][10] = PATH
	for y in range(14, MAP_SIZE.y - 2):
		cells[y][21] = PATH
	for y in range(5, 11):
		for x in range(3, 9):
			cells[y][x] = GRASS
	for y in range(17, 21):
		for x in range(12, 19):
			cells[y][x] = GRASS
	for cell in [Vector2i(25, 12), Vector2i(25, 13), Vector2i(25, 14), Vector2i(25, 15)]:
		cells[cell.y][cell.x] = PATH
	_set_rock_cluster([Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)])
	_set_rock_cluster([Vector2i(15, 6), Vector2i(16, 6), Vector2i(17, 6)])
	_set_rock_cluster([Vector2i(18, 19), Vector2i(19, 19), Vector2i(20, 19)])
	props = [
		{
			"id": "sunset_shore.shop",
			"cell": SHOP_CELL,
			"kind": "shop",
			"used": false,
			"label_en": "Visit beach shop",
			"label_zh": "进入海滨商店",
			"message_en": "Beach shop: Orange seeds are in stock.",
			"message_zh": "海滨商店：橙色种子已经到货。",
			"footprint": [
				Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9),
				Vector2i(14, 10), Vector2i(15, 10), Vector2i(16, 10), Vector2i(17, 10),
			],
		},
		{
			"id": "sunset_shore.ranger",
			"cell": Vector2i(8, 8),
			"kind": "ranger",
			"used": false,
			"label_en": "Talk to the ranger",
			"label_zh": "与护林员交谈",
			"message_en": "Ranger: Welcome to Sunset Shore.",
			"message_zh": "护林员：欢迎来到日落海岸。",
		},
		{
			"id": "sunset_shore.ship",
			"cell": SHIP_CELL,
			"kind": "spaceship",
			"used": false,
			"collision_size": Vector2(48.0, 24.0),
			"label_en": "Open navigation radar",
			"label_zh": "打开导航雷达",
			"message_en": "Navigation radar ready.",
			"message_zh": "导航雷达已准备就绪。",
		},
	]

func _after_map_ready() -> void:
	# Center the four-column building over its four-cell footprint.
	get_shop_node().position = cell_to_world(SHOP_CELL) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

func _validate_map() -> void:
	super._validate_map()
	assert(get_node_or_null("Shop") != null)
	for prop in props:
		assert(not str(prop.get("id", "")).begins_with("greenmeadow."))

func _draw_background() -> void:
	draw_texture_rect_region(BEACH_BACKDROP_TEXTURE, Rect2(0, -SCENIC_TOP_PIXELS, MAP_SIZE.x * TILE_SIZE, SCENIC_TOP_PIXELS), Rect2(0, 0, 1536, 300))
	draw_rect(Rect2(0, -SCENIC_TOP_PIXELS, MAP_SIZE.x * TILE_SIZE, SCENIC_TOP_PIXELS), Color(1.0, 0.72, 0.4, 0.12), true)

func _draw_scenery_after_tiles() -> void:
	for point in [Vector2(118, 142), Vector2(420, 318), Vector2(690, 594), Vector2(248, 670), Vector2(565, 438)]:
		draw_circle(point, 3.0, Color("#f6e1a3"))
		draw_arc(point + Vector2(7, 0), 6.0, 0.2, 2.6, 14, Color("#b87c59"), 1.5)
	for base in [Vector2(82, 470), Vector2(610, 188)]:
		draw_line(base, base + Vector2(5, -58), Color("#75503b"), 7.0)
		draw_line(base + Vector2(5, -52), base + Vector2(-26, -76), Color("#356d51"), 5.0)
		draw_line(base + Vector2(5, -48), base + Vector2(28, -79), Color("#3f8056"), 5.0)
		draw_line(base + Vector2(5, -48), base + Vector2(8, -88), Color("#4c8e5b"), 5.0)
