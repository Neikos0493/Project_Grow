class_name MeadowWorld
extends Node2D
## Procedural grid world, collision generation, and lightweight interactables.

const TILE_SIZE := 32
const MAP_SIZE := Vector2i(40, 24)
const PLAYER_START_CELL := Vector2i(7, 7)
const SHOP_CELL := Vector2i(15, 9)
const LOOKOUT_CELL := Vector2i(20, 0)
const SCENIC_TOP_PIXELS := 288
const CLIFF_X_MIN := 14
const CLIFF_X_MAX := 26
const INTERACTION_RANGE := 52.0
const HOE_RANGE_CELLS := 3
const SEED_RANGE_CELLS := 1
const FARM_TILLED := 0
const FARM_SEEDED := 1
const FARM_MATURE := 2

const GRASS := 0
const DIRT := 1
const PATH := 2
const WATER := 3
const ROCK := 4
const CLIFF := 5

const GRASS_A := Color("#5a9c62")
const GRASS_B := Color("#66a868")
const DIRT_COLOR := Color("#b68a5b")
const PATH_COLOR := Color("#d0ad68")
const WATER_COLOR := Color("#3e86a5")
const ROCK_COLOR := Color("#596168")
const CLIFF_COLOR := Color("#90775b")
const GRID_COLOR := Color(0.86, 0.96, 0.78, 0.13)
const SCENIC_SKY := Color("#293d4a")
const SCENIC_MOUNTAIN_FAR := Color("#3c5360")
const SCENIC_MOUNTAIN_NEAR := Color("#4b5960")
const DEAD_LEAF_DARK := Color("#625d35")
const DEAD_LEAF_MID := Color("#978343")
const DEAD_LEAF_LIGHT := Color("#b39a4c")
const DEAD_TRUNK := Color("#493f32")
const TREE_OUTLINE := Color("#302d27")

var cells: Array[Array] = []
var farm_tiles: Dictionary = {}
var drops: Array[Dictionary] = []
var props: Array[Dictionary] = [
	{"cell": Vector2i(10, 7), "kind": "mailbox", "label": "Read mailbox", "used": false},
	{"cell": Vector2i(20, 12), "kind": "notice", "label": "Read notice board", "used": false},
	{"cell": Vector2i(25, 17), "kind": "crate", "label": "Open crate", "used": false},
	{
		"cell": SHOP_CELL,
		"kind": "shop",
		"label": "Visit shop",
		"used": false,
		"footprint": [Vector2i(14, 9), SHOP_CELL, Vector2i(16, 9)],
	},
	{
		"cell": LOOKOUT_CELL,
		"kind": "lookout",
		"label": "Look toward the world tree",
		"used": false,
		"no_collision": true,
	},
]

func _ready() -> void:
	_generate_map()
	_create_collisions()
	queue_redraw()

func _generate_map() -> void:
	cells.clear()
	for y in range(MAP_SIZE.y):
		var row: Array = []
		for x in range(MAP_SIZE.x):
			row.append(GRASS)
		cells.append(row)

	# A solid natural boundary makes the camera and world edge readable.
	for x in range(MAP_SIZE.x):
		cells[0][x] = WATER
		cells[MAP_SIZE.y - 1][x] = ROCK
	for y in range(MAP_SIZE.y):
		cells[y][0] = ROCK
		cells[y][MAP_SIZE.x - 1] = ROCK

	# Dirt paths cross the meadow and lead toward the props.
	for x in range(1, MAP_SIZE.x - 1):
		cells[12][x] = PATH
	for y in range(1, MAP_SIZE.y - 1):
		cells[y][20] = PATH
	for x in range(8, 14):
		cells[7][x] = DIRT

	# Pond in the far right corner.
	for y in range(4, 9):
		for x in range(28, 35):
			cells[y][x] = WATER

	# The old road now climbs into a narrow cliff-top lookout.
	for x in range(CLIFF_X_MIN, CLIFF_X_MAX + 1):
		cells[0][x] = CLIFF

	# A few compact, deterministic obstacle clusters.
	_set_rock_cluster([Vector2i(12, 4), Vector2i(13, 4), Vector2i(12, 5)])
	_set_rock_cluster([Vector2i(16, 18), Vector2i(17, 18), Vector2i(18, 18)])
	_set_rock_cluster([Vector2i(6, 15), Vector2i(7, 15), Vector2i(8, 15)])
	_set_rock_cluster([Vector2i(34, 15), Vector2i(35, 15), Vector2i(35, 16)])

	assert(_is_in_bounds(PLAYER_START_CELL))
	assert(is_walkable(PLAYER_START_CELL))
	assert(is_walkable(Vector2i(20, 1)))
	assert(is_walkable(LOOKOUT_CELL))

func get_camera_top_limit() -> int:
	return -SCENIC_TOP_PIXELS

func _set_rock_cluster(cluster: Array[Vector2i]) -> void:
	for cell in cluster:
		if _is_in_bounds(cell):
			cells[cell.y][cell.x] = ROCK

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y

func is_walkable(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return false
	return cells[cell.y][cell.x] != WATER and cells[cell.y][cell.x] != ROCK

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / float(TILE_SIZE)), floori(world_position.y / float(TILE_SIZE)))

func _is_prop_cell(cell: Vector2i) -> bool:
	for prop in props:
		if cell in _prop_cells(prop):
			return true
	return false

func get_pointer_cell(mouse_world: Vector2, player_position: Vector2, facing: Vector2, mode: String) -> Vector2i:
	var cell := world_to_cell(mouse_world)
	if not _is_in_bounds(cell) or _is_prop_cell(cell):
		return Vector2i(-1, -1)
	if mode == "hoe":
		if cells[cell.y][cell.x] != GRASS or farm_tiles.has(cell):
			return Vector2i(-1, -1)
	else:
		if not farm_tiles.has(cell) or int(farm_tiles[cell].get("state", -1)) != FARM_TILLED:
			return Vector2i(-1, -1)
	var player_cell := world_to_cell(player_position)
	var cell_distance := maxi(abs(cell.x - player_cell.x), abs(cell.y - player_cell.y))
	var max_distance := HOE_RANGE_CELLS if mode == "hoe" else SEED_RANGE_CELLS
	if cell_distance > max_distance:
		return Vector2i(-1, -1)
	var target_offset := cell_to_world(cell) - player_position
	if facing.length_squared() < 0.01 or facing.normalized().dot(target_offset.normalized()) < 0.25:
		return Vector2i(-1, -1)
	return cell

func till(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or cells[cell.y][cell.x] != GRASS or cell in farm_tiles or _is_prop_cell(cell):
		return false
	farm_tiles[cell] = {"state": FARM_TILLED}
	queue_redraw()
	return true

func plant_seed(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or not farm_tiles.has(cell):
		return false
	if int(farm_tiles[cell].get("state", -1)) != FARM_TILLED:
		return false
	farm_tiles[cell]["state"] = FARM_SEEDED
	queue_redraw()
	return true

func set_farm_mature(cell: Vector2i) -> void:
	if farm_tiles.has(cell):
		farm_tiles[cell]["state"] = FARM_MATURE
		queue_redraw()

func set_farm_tilled(cell: Vector2i) -> void:
	if farm_tiles.has(cell):
		farm_tiles[cell]["state"] = FARM_TILLED
		queue_redraw()

func clear_farm(cell: Vector2i) -> void:
	farm_tiles.erase(cell)
	queue_redraw()

func get_map_size_pixels() -> Vector2:
	return Vector2(MAP_SIZE.x * TILE_SIZE, MAP_SIZE.y * TILE_SIZE)

func get_shop_ground_position() -> Vector2:
	return cell_to_world(SHOP_CELL) + Vector2(0, TILE_SIZE * 0.5)

func _prop_cells(prop: Dictionary) -> Array:
	if prop.has("footprint"):
		return prop["footprint"]
	return [prop["cell"]]

func _create_collisions() -> void:
	var map_collisions := StaticBody2D.new()
	map_collisions.name = "MapCollisions"
	map_collisions.collision_layer = 1
	map_collisions.collision_mask = 1
	add_child(map_collisions)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			if cells[y][x] == WATER or cells[y][x] == ROCK:
				_add_rectangle_collision(map_collisions, cell_to_world(cell), Vector2(TILE_SIZE, TILE_SIZE))

	for prop in props:
		if bool(prop.get("no_collision", false)):
			continue
		var footprint: Array = _prop_cells(prop)
		var obstacle_size := Vector2(TILE_SIZE, TILE_SIZE) if prop["kind"] == "shop" else Vector2(18, 18)
		for cell in footprint:
			_add_rectangle_collision(map_collisions, cell_to_world(cell), obstacle_size)

	# A low stone lip keeps the lookout safe while leaving its floor walkable.
	_add_rectangle_collision(
		map_collisions,
		Vector2(cell_to_world(LOOKOUT_CELL).x, 0.0),
		Vector2(float((CLIFF_X_MAX - CLIFF_X_MIN + 1) * TILE_SIZE), 8.0)
	)

func _add_rectangle_collision(parent: Node, center: Vector2, size: Vector2) -> void:
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape_node.shape = rectangle
	shape_node.position = center
	parent.add_child(shape_node)

func _draw() -> void:
	_draw_backdrop()
	_draw_distant_tree_line()
	_draw_world_tree()

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			var tile_type: int = cells[y][x]
			var color := _tile_color(tile_type, cell)
			var rect := Rect2(Vector2(x, y) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
			draw_rect(rect, color)
			draw_line(rect.position, rect.position + Vector2(TILE_SIZE, 0), GRID_COLOR, 1.0)
			draw_line(rect.position, rect.position + Vector2(0, TILE_SIZE), GRID_COLOR, 1.0)
			if tile_type == WATER:
				var wave_x := rect.position.x + 7.0 + float((x * 11 + y * 5) % 12)
				draw_line(Vector2(wave_x, rect.position.y + 12), Vector2(wave_x + 9, rect.position.y + 12), Color(0.72, 0.91, 0.9, 0.34), 1.0)
				draw_line(Vector2(wave_x - 3, rect.position.y + 22), Vector2(wave_x + 5, rect.position.y + 22), Color(0.72, 0.91, 0.9, 0.2), 1.0)

	_draw_cliff_details()
	for prop in props:
		if prop["kind"] != "shop":
			_draw_prop(prop)
	for cell in farm_tiles:
		_draw_farm_tile(cell, farm_tiles[cell])
	for drop in drops:
		_draw_drop(drop)

func _draw_farm_tile(cell: Vector2i, farm: Dictionary) -> void:
	var rect := Rect2(Vector2(cell) * TILE_SIZE + Vector2(3, 3), Vector2(TILE_SIZE - 6, TILE_SIZE - 6))
	draw_rect(rect, Color("#8d603f"), true)
	draw_rect(rect, Color("#d0a36a"), false, 2.0)
	for row in range(3):
		var y := rect.position.y + 7.0 + row * 7.0
		draw_line(Vector2(rect.position.x + 4, y), Vector2(rect.end.x - 4, y), Color("#704a38"), 1.0)
	var state := int(farm.get("state", FARM_TILLED))
	if state == FARM_SEEDED:
		draw_circle(cell_to_world(cell) + Vector2(-5, 2), 2.5, Color("#59b35b"))
		draw_circle(cell_to_world(cell) + Vector2(5, 4), 2.5, Color("#4d9b4f"))
	elif state == FARM_MATURE:
		draw_circle(cell_to_world(cell) + Vector2(0, -2), 4.0, Color("#2e8249"))

func _draw_backdrop() -> void:
	# The negative-Y band is a distant valley, not extra walkable map space.
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
	var tree_base := cell_to_world(LOOKOUT_CELL) + Vector2(0, -4)
	for side in [-1.0, 1.0]:
		for depth in range(3):
			var spread := 125.0 + float(depth) * 105.0
			var valley := tree_base + Vector2(side * spread, -30.0 - float(depth) * 22.0)
			draw_line(tree_base + Vector2(side * 20.0, -8.0), valley, Color(0.67, 0.7, 0.61, 0.24 - depth * 0.045), 2.0)
	# Thin mist bands make the depth transition legible without hiding the tree.
	for index in range(3):
		var mist_y := -42.0 - float(index) * 47.0
		draw_line(Vector2(18, mist_y), Vector2(1262, mist_y - 8.0), Color(0.75, 0.82, 0.78, 0.12), 11.0)

func _draw_distant_tree_line() -> void:
	var base := cell_to_world(LOOKOUT_CELL) + Vector2(0, -8)
	var tree_specs := [
		[-1.0, 300.0, 0.34], [-1.0, 220.0, 0.48], [-1.0, 125.0, 0.68],
		[1.0, 300.0, 0.34], [1.0, 220.0, 0.48], [1.0, 125.0, 0.68],
	]
	for spec in tree_specs:
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
	# Layered trunk planes and roots sell a single enormous, old silhouette.
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-52, 0), base + Vector2(-29, -120), base + Vector2(-17, -226),
		trunk_top + Vector2(18, 0), base + Vector2(38, -150), base + Vector2(58, 0),
	]), DEAD_TRUNK)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(4, 0), base + Vector2(4, -215), trunk_top + Vector2(18, 0),
		base + Vector2(38, -150), base + Vector2(58, 0),
	]), Color("#66513a"))
	draw_polyline(PackedVector2Array([
		base + Vector2(-52, 0), base + Vector2(-29, -120), base + Vector2(-17, -226),
		trunk_top + Vector2(18, 0), base + Vector2(58, 0),
	]), TREE_OUTLINE, 4.0, true)
	for root in [Vector2(-64, 0), Vector2(-34, 4), Vector2(42, 3), Vector2(70, 0)]:
		draw_line(base + Vector2(0, -4), base + root, TREE_OUTLINE, 5.0)
	# Branches fan toward both sides, making the crown wider than the cliff.
	var branch_points := [
		[Vector2(-12, -164), Vector2(-118, -213)], [Vector2(-2, -188), Vector2(-178, -246)],
		[Vector2(18, -155), Vector2(124, -211)], [Vector2(16, -198), Vector2(184, -253)],
	]
	for branch in branch_points:
		draw_line(base + branch[0], base + branch[1], DEAD_TRUNK, 10.0)
		draw_line(base + branch[0], base + branch[1], TREE_OUTLINE, 2.0)
	var crown_centers := [
		Vector2(-160, -238), Vector2(-92, -263), Vector2(-20, -250), Vector2(58, -263),
		Vector2(135, -242), Vector2(-116, -196), Vector2(26, -195), Vector2(112, -192),
	]
	var crown_colors := [DEAD_LEAF_DARK, DEAD_LEAF_MID, DEAD_LEAF_LIGHT, DEAD_LEAF_MID]
	for index in range(crown_centers.size()):
		var center: Vector2 = base + crown_centers[index]
		var radius := 48.0 + float((index * 13) % 24)
		var color: Color = crown_colors[index % crown_colors.size()]
		draw_circle(center, radius, Color(color, 0.88))
		draw_circle(center + Vector2(-10, -8), radius * 0.62, Color(DEAD_LEAF_LIGHT, 0.36))
		draw_arc(center, radius, 0.0, TAU, 18, TREE_OUTLINE, 2.0, true)

func _draw_cliff_details() -> void:
	var left := float(CLIFF_X_MIN * TILE_SIZE)
	var right := float((CLIFF_X_MAX + 1) * TILE_SIZE)
	draw_line(Vector2(left, 1), Vector2(right, 1), Color("#d2b47a"), 4.0)
	draw_line(Vector2(left, 6), Vector2(right, 6), Color("#4b4035"), 2.0)
	for x in range(CLIFF_X_MIN + 1, CLIFF_X_MAX, 2):
		var post := Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, 0)
		draw_line(post, post + Vector2(0, -15), Color("#5a4938"), 3.0)
		draw_line(post + Vector2(0, -15), post + Vector2(32, -15), Color("#5a4938"), 2.0)

func _draw_drop(drop: Dictionary) -> void:
	var available := Time.get_ticks_msec() >= int(drop["available_at_msec"])
	var item_id := str(drop.get("item_id", ""))
	var base_color := Color("#4d9b55") if item_id == "plant" else Color("#f3c969")
	var color := base_color if available else Color(base_color, 0.35)
	var position: Vector2 = drop["position"]
	draw_circle(position + Vector2(0, 3), 8.0, Color(0.05, 0.1, 0.1, 0.3))
	draw_circle(position, 6.0, color)
	draw_circle(position + Vector2(-2, -2), 2.0, Color(1, 0.96, 0.7, 0.8) if available else Color(1, 0.96, 0.7, 0.3))
	if item_id == "plant" and available:
		draw_line(position + Vector2(0, 5), position + Vector2(0, -5), Color("#24523a"), 2.0)
		draw_circle(position + Vector2(-3, -5), 3.0, Color("#59b35b"))
		draw_circle(position + Vector2(3, -4), 3.0, Color("#72c45f"))
	elif not available:
		draw_arc(position, 10.0, 0.0, TAU, 24, Color(base_color, 0.55), 1.0)

func _tile_color(tile_type: int, cell: Vector2i) -> Color:
	match tile_type:
		DIRT:
			return DIRT_COLOR
		PATH:
			return PATH_COLOR
		WATER:
			return WATER_COLOR
		ROCK:
			return ROCK_COLOR
		CLIFF:
			return CLIFF_COLOR
		_:
			return GRASS_B if (cell.x * 3 + cell.y * 5) % 7 == 0 else GRASS_A

func _draw_prop(prop: Dictionary) -> void:
	var center: Vector2 = cell_to_world(prop["cell"])
	var outline := Color("#26353b")
	match prop["kind"]:
		"mailbox":
			draw_line(center + Vector2(0, 10), center + Vector2(0, -3), outline, 3.0)
			draw_rect(Rect2(center + Vector2(-10, -11), Vector2(20, 10)), Color("#d56b54"), true)
			draw_rect(Rect2(center + Vector2(-10, -11), Vector2(20, 10)), outline, false, 2.0)
			draw_circle(center + Vector2(7, -6), 2.0, Color("#f6d27d"))
		"notice":
			draw_line(center + Vector2(-7, 11), center + Vector2(-7, -5), outline, 3.0)
			draw_line(center + Vector2(7, 11), center + Vector2(7, -5), outline, 3.0)
			draw_rect(Rect2(center + Vector2(-13, -11), Vector2(26, 14)), Color("#d8b56d"), true)
			draw_rect(Rect2(center + Vector2(-13, -11), Vector2(26, 14)), outline, false, 2.0)
			draw_line(center + Vector2(-8, -6), center + Vector2(8, -6), Color("#755b42"), 1.0)
			draw_line(center + Vector2(-8, -2), center + Vector2(4, -2), Color("#755b42"), 1.0)
		"crate":
			var used: bool = prop["used"]
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), Color("#9d704c"), true)
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), outline, false, 2.0)
			if used:
				draw_line(center + Vector2(-10, -7), center + Vector2(10, -12), Color("#e0bc73"), 3.0)
				draw_line(center + Vector2(-8, 5), center + Vector2(8, 5), Color("#6b4b3b"), 2.0)
			else:
				draw_line(center + Vector2(-8, -7), center + Vector2(8, 7), Color("#d4a666"), 2.0)
				draw_line(center + Vector2(8, -7), center + Vector2(-8, 7), Color("#d4a666"), 2.0)
		"lookout":
			# A small marker gives the player a readable arrival point.
			draw_line(center + Vector2(0, 10), center + Vector2(0, -14), Color("#5a4938"), 3.0)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -14), center + Vector2(18, -9), center + Vector2(0, -4),
			]), Color("#d5b15f"))
			draw_line(center + Vector2(-20, 8), center + Vector2(20, 8), Color("#5a4938"), 2.0)

func _find_target(origin: Vector2, facing: Vector2) -> Dictionary:
	if facing.length_squared() < 0.01:
		return {}
	var direction := facing.normalized()

	# Treat the shop footprint as one interaction target. Prefer it when any
	# reachable bay is aimed at, so its three ground cells behave consistently.
	var shop_target: Dictionary = {}
	var shop_distance := INF
	for prop in props:
		if prop["kind"] != "shop":
			continue
		for cell in _prop_cells(prop):
			var target_position: Vector2 = cell_to_world(cell)
			var offset := target_position - origin
			var distance := offset.length()
			if distance > INTERACTION_RANGE or distance < 0.001:
				continue
			if direction.dot(offset.normalized()) < 0.25:
				continue
			if distance < shop_distance:
				shop_target = prop
				shop_distance = distance
		if not shop_target.is_empty():
			return shop_target

	# Single-cell props retain nearest-target behavior and their original
	# dictionaries, allowing interact() to update crate state in place.
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for prop in props:
		if prop["kind"] == "shop":
			continue
		for cell in _prop_cells(prop):
			var target_position: Vector2 = cell_to_world(cell)
			var offset := target_position - origin
			var distance := offset.length()
			if distance > INTERACTION_RANGE or distance < 0.001:
				continue
			if direction.dot(offset.normalized()) < 0.25:
				continue
			if distance < nearest_distance:
				nearest = prop
				nearest_distance = distance
	return nearest

func get_interaction_target(origin: Vector2, facing: Vector2) -> Dictionary:
	return _find_target(origin, facing)

func add_drop(position: Vector2, item_id: String, count: int = 1, pickup_delay_msec: int = 3000) -> void:
	if item_id.is_empty() or count <= 0:
		return
	drops.append({
		"position": position,
		"item_id": item_id,
		"count": count,
		"available_at_msec": Time.get_ticks_msec() + pickup_delay_msec,
	})
	queue_redraw()

func get_pickup_candidate(origin: Vector2) -> int:
	var now := Time.get_ticks_msec()
	var max_distance_squared := pow(float(TILE_SIZE) * 0.5, 2)
	var nearest_index := -1
	var nearest_distance_squared := INF
	for index in range(drops.size()):
		var drop := drops[index]
		if now < int(drop["available_at_msec"]):
			continue
		var distance_squared := origin.distance_squared_to(drop["position"])
		if distance_squared <= max_distance_squared and distance_squared < nearest_distance_squared:
			nearest_index = index
			nearest_distance_squared = distance_squared
	return nearest_index

func take_drop(index: int) -> Dictionary:
	if index < 0 or index >= drops.size():
		return {}
	var result: Dictionary = drops[index]
	drops.remove_at(index)
	queue_redraw()
	return result

func get_interaction_prompt(origin: Vector2, facing: Vector2) -> String:
	var target := _find_target(origin, facing)
	if target.is_empty():
		return ""
	return target["label"]

func interact(origin: Vector2, facing: Vector2) -> String:
	var target := _find_target(origin, facing)
	if target.is_empty():
		return ""
	match target["kind"]:
		"mailbox":
			return "Mailbox: A quiet day. Maybe tomorrow."
		"notice":
			return "Notice board: Welcome to the meadow."
		"shop":
			return "Shop: Welcome! Take a look around."
		"lookout":
			return "Beyond the cliff, the ancient world tree holds the dead sky in its branches."
		"crate":
			if target["used"]:
				return "The crate is empty."
			target["used"] = true
			queue_redraw()
			return "You found a seed packet."
	return ""
