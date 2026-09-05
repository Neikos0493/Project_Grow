class_name GreenmeadowMap
extends MeadowWorld
## Independently owned Greenmeadow terrain, props, scenery, and encounter area.

const MAP_ID := &"greenmeadow"
const PLAYER_START_CELL := Vector2i(20, 2)
const SHOP_CELL := Vector2i(15, 9)
const LOOKOUT_CELL := Vector2i(20, 0)
const SHIP_CELL := Vector2i(20, 1)
const CLIFF_X_MIN := 14
const CLIFF_X_MAX := 26
const SCENIC_SKY := Color("#293d4a")
const SCENIC_MOUNTAIN_FAR := Color("#3c5360")
const SCENIC_MOUNTAIN_NEAR := Color("#4b5960")
const DEAD_LEAF_DARK := Color("#625d35")
const DEAD_LEAF_MID := Color("#978343")
const DEAD_LEAF_LIGHT := Color("#b39a4c")
const DEAD_TRUNK := Color("#493f32")
const TREE_OUTLINE := Color("#302d27")

func get_map_id() -> StringName:
	return MAP_ID

func get_level_title() -> String:
	return "世界树之森" if language == "zh" else "WORLD TREE FOREST"

func get_level_subtitle() -> String:
	return "伊始之地" if language == "zh" else "The place where it begins"

func get_arrival_message() -> String:
	return "旅途的开始…世界的新生…" if language == "zh" else "The journey begins... a new world is born..."

func get_respawn_message() -> String:
	return "你回到了绿野。" if language == "zh" else "You returned to Greenmeadow."

func get_initial_spawn_cell() -> Vector2i:
	return PLAYER_START_CELL

func get_respawn_cell() -> Vector2i:
	return PLAYER_START_CELL

func get_ship_cell() -> Vector2i:
	return SHIP_CELL

func get_shop_node() -> MeadowShop:
	return get_node("Shop") as MeadowShop

func _build_map() -> void:
	_initialize_grid(GRASS)
	for x in range(MAP_SIZE.x):
		cells[0][x] = WATER
		cells[MAP_SIZE.y - 1][x] = ROCK
	for y in range(MAP_SIZE.y):
		cells[y][0] = ROCK
		cells[y][MAP_SIZE.x - 1] = ROCK
	for x in range(1, MAP_SIZE.x - 1):
		cells[12][x] = PATH
	for y in range(1, MAP_SIZE.y - 1):
		cells[y][20] = PATH
	for x in range(8, 14):
		cells[7][x] = DIRT
	for y in range(4, 9):
		for x in range(28, 35):
			cells[y][x] = WATER
	for x in range(CLIFF_X_MIN, CLIFF_X_MAX + 1):
		cells[0][x] = CLIFF
	_set_rock_cluster([Vector2i(12, 4), Vector2i(13, 4), Vector2i(12, 5)])
	_set_rock_cluster([Vector2i(16, 18), Vector2i(17, 18), Vector2i(18, 18)])
	_set_rock_cluster([Vector2i(6, 15), Vector2i(7, 15), Vector2i(8, 15)])
	_set_rock_cluster([Vector2i(34, 15), Vector2i(35, 15), Vector2i(35, 16)])
	water_anchor_min = Vector2i(28, 4)
	water_anchor_max = Vector2i(33, 7)
	props = [
		_prop("greenmeadow.mailbox", Vector2i(10, 7), "mailbox", "Read mailbox", "阅读邮箱", "Mailbox: A quiet day. Maybe tomorrow.", "也许永远都不会有消息…"),
		_prop("greenmeadow.notice_board", Vector2i(20, 12), "notice", "Read notice board", "阅读告示牌", "Notice board: Welcome to the meadow.", "…树…守护…世界…"),
		{
			"id": "greenmeadow.seed_crate", "cell": Vector2i(25, 17), "kind": "crate", "used": false,
			"label_en": "Open crate", "label_zh": "打开木箱", "message_en": "You found a seed packet.", "message_zh": "你找到了一包种子。",
			"empty_en": "The crate is empty.", "empty_zh": "木箱已经空了。",
		},
		_prop("greenmeadow.lake_keeper", Vector2i(27, 6), "lake_npc", "Talk to the lake keeper", "与湖之守望者交谈", "", ""),
		{
			"id": "greenmeadow.shop", "cell": SHOP_CELL, "kind": "shop", "used": false,
			"label_en": "Visit shop", "label_zh": "进入商店", "message_en": "Shop: Welcome! Take a look around.", "message_zh": "商店：欢迎！随便看看吧。",
			"footprint": [
				Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9), Vector2i(17, 9),
				Vector2i(14, 10), Vector2i(15, 10), Vector2i(16, 10), Vector2i(17, 10),
			],
		},
		{
			"id": "greenmeadow.lookout", "cell": LOOKOUT_CELL, "kind": "lookout", "used": false, "no_collision": true,
			"label_en": "Look toward the world tree", "label_zh": "眺望世界树",
			"message_en": "Beyond the cliff, the ancient world tree holds the dead sky in its branches.",
			"message_zh": "越过悬崖，古老的世界树让沉寂的天空停留在枝头。",
		},
		{
			"id": "greenmeadow.ship", "cell": SHIP_CELL, "kind": "spaceship", "used": false, "collision_size": Vector2(48.0, 24.0),
			"label_en": "Open navigation radar", "label_zh": "打开导航雷达", "message_en": "Navigation radar ready.", "message_zh": "导航雷达已准备就绪。",
		},
	]

func _prop(id: String, cell: Vector2i, kind: String, label_en: String, label_zh: String, message_en: String, message_zh: String) -> Dictionary:
	return {"id": id, "cell": cell, "kind": kind, "used": false, "label_en": label_en, "label_zh": label_zh, "message_en": message_en, "message_zh": message_zh}

func _after_map_ready() -> void:
	# Center the four-column building over its four-cell footprint.
	get_shop_node().position = cell_to_world(SHOP_CELL) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

func _add_map_collisions(map_collisions: StaticBody2D) -> void:
	_add_rectangle_collision(map_collisions, Vector2(cell_to_world(LOOKOUT_CELL).x, 0.0), Vector2(float((CLIFF_X_MAX - CLIFF_X_MIN + 1) * TILE_SIZE), 8.0))

func _draw_background() -> void:
	draw_rect(Rect2(0, -SCENIC_TOP_PIXELS, MAP_SIZE.x * TILE_SIZE, SCENIC_TOP_PIXELS), SCENIC_SKY)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -35), Vector2(150, -120), Vector2(310, -70), Vector2(480, -155),
		Vector2(660, -92), Vector2(850, -145), Vector2(1050, -64), Vector2(1280, -118),
		Vector2(1280, 0), Vector2(0, 0),
	]), SCENIC_MOUNTAIN_FAR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -4), Vector2(190, -72), Vector2(370, -36), Vector2(520, -110),
		Vector2(660, -54), Vector2(820, -105), Vector2(1010, -42), Vector2(1280, -82),
		Vector2(1280, 0), Vector2(0, 0),
	]), SCENIC_MOUNTAIN_NEAR)
	for index in range(3):
		var mist_y := -42.0 - float(index) * 47.0
		draw_line(Vector2(18, mist_y), Vector2(1262, mist_y - 8.0), Color(0.75, 0.82, 0.78, 0.12), 11.0)

func _draw_scenery_before_tiles() -> void:
	_draw_distant_tree_line()
	_draw_world_tree()

func _draw_scenery_after_tiles() -> void:
	var left := float(CLIFF_X_MIN * TILE_SIZE)
	var right := float((CLIFF_X_MAX + 1) * TILE_SIZE)
	draw_line(Vector2(left, 1), Vector2(right, 1), Color("#d2b47a"), 4.0)
	draw_line(Vector2(left, 6), Vector2(right, 6), Color("#4b4035"), 2.0)
	for x in range(CLIFF_X_MIN + 1, CLIFF_X_MAX, 2):
		var post := Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, 0)
		draw_line(post, post + Vector2(0, -15), Color("#5a4938"), 3.0)
		draw_line(post + Vector2(0, -15), post + Vector2(32, -15), Color("#5a4938"), 2.0)

func _draw_distant_tree_line() -> void:
	var base := cell_to_world(LOOKOUT_CELL) + Vector2(0, -8)
	for spec in [[-1.0, 300.0, 0.34], [-1.0, 220.0, 0.48], [-1.0, 125.0, 0.68], [1.0, 300.0, 0.34], [1.0, 220.0, 0.48], [1.0, 125.0, 0.68]]:
		_draw_small_dead_tree(base + Vector2(float(spec[0]) * float(spec[1]), 0), float(spec[2]), float(spec[0]))

func _draw_small_dead_tree(base: Vector2, scale: float, lean: float) -> void:
	var trunk_height := 115.0 * scale
	var trunk_width := 12.0 * scale
	var top := base + Vector2(lean * 14.0 * scale, -trunk_height)
	draw_line(base, top, Color(DEAD_TRUNK, 0.62), trunk_width)
	draw_line(top, top + Vector2(-lean * 25.0 * scale, -19.0 * scale), Color(DEAD_TRUNK, 0.58), maxf(1.0, trunk_width * 0.45))
	var leaf_color := Color(DEAD_LEAF_MID, 0.42 + scale * 0.25)
	for offset in [Vector2(-14, -8), Vector2(9, -18), Vector2(-2, 7)]:
		draw_circle(top + offset * scale, 20.0 * scale, leaf_color)

func _draw_world_tree() -> void:
	var base := cell_to_world(LOOKOUT_CELL) + Vector2(0, 8)
	var trunk_top := base + Vector2(8, -238)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-52, 0), base + Vector2(-29, -120), base + Vector2(-17, -226),
		trunk_top + Vector2(18, 0), base + Vector2(38, -150), base + Vector2(58, 0),
	]), DEAD_TRUNK)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(4, 0), base + Vector2(4, -215), trunk_top + Vector2(18, 0),
		base + Vector2(38, -150), base + Vector2(58, 0),
	]), Color("#66513a"))
	draw_polyline(PackedVector2Array([base + Vector2(-52, 0), base + Vector2(-29, -120), base + Vector2(-17, -226), trunk_top + Vector2(18, 0), base + Vector2(58, 0)]), TREE_OUTLINE, 4.0, true)
	for root in [Vector2(-64, 0), Vector2(-34, 4), Vector2(42, 3), Vector2(70, 0)]:
		draw_line(base + Vector2(0, -4), base + root, TREE_OUTLINE, 5.0)
	for branch in [[Vector2(-12, -164), Vector2(-118, -213)], [Vector2(-2, -188), Vector2(-178, -246)], [Vector2(18, -155), Vector2(124, -211)], [Vector2(16, -198), Vector2(184, -253)]]:
		draw_line(base + branch[0], base + branch[1], DEAD_TRUNK, 10.0)
		draw_line(base + branch[0], base + branch[1], TREE_OUTLINE, 2.0)
	var centers := [Vector2(-160, -238), Vector2(-92, -263), Vector2(-20, -250), Vector2(58, -263), Vector2(135, -242), Vector2(-116, -196), Vector2(26, -195), Vector2(112, -192)]
	var colors := [DEAD_LEAF_DARK, DEAD_LEAF_MID, DEAD_LEAF_LIGHT, DEAD_LEAF_MID]
	for index in range(centers.size()):
		var center: Vector2 = base + centers[index]
		var radius := 48.0 + float((index * 13) % 24)
		draw_circle(center, radius, Color(colors[index % colors.size()], 0.88))
		draw_circle(center + Vector2(-10, -8), radius * 0.62, Color(DEAD_LEAF_LIGHT, 0.36))
		draw_arc(center, radius, 0.0, TAU, 18, TREE_OUTLINE, 2.0, true)
