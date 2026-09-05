class_name MeadowWorld
extends Node2D
## Procedural grid world, collision generation, and lightweight interactables.

const TILE_SIZE := 32
const MAP_SIZE := Vector2i(40, 24)
const PLAYER_START_CELL := Vector2i(20, 2)
const SHOP_CELL := Vector2i(15, 9)
const LOOKOUT_CELL := Vector2i(20, 0)
const SCENIC_TOP_PIXELS := 288
const CLIFF_X_MIN := 14
const CLIFF_X_MAX := 26
const INTERACTION_RANGE := 52.0
const HOE_RANGE_CELLS := 1
const SEED_RANGE_CELLS := 1
const FARM_TILLED := 0
const FARM_SEEDED := 1
const FARM_MATURE := 2
const WORLD_COLLISION_LAYER := 1
const WATER_COLLISION_LAYER := 8

const GRASS := 0
const DIRT := 1
const PATH := 2
const WATER := 3
const ROCK := 4
const CLIFF := 5
const SAND := 6

const GRASS_A := Color("#5a9c62")
const GRASS_B := Color("#66a868")
const DIRT_COLOR := Color("#b68a5b")
const PATH_COLOR := Color("#d0ad68")
const SAND_A := Color("#d9b86c")
const SAND_B := Color("#e7cc83")
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
const BEACH_BACKDROP_TEXTURE := preload("res://assets/beach_backdrop.png")

@export_enum("meadow", "pond") var level_variant := "meadow"

var cells: Array[Array] = []
var farm_tiles: Dictionary = {}
var water_growth: Dictionary = {}
var drops: Array[Dictionary] = []
var language := "en"
var ship_transition_offset := Vector2.ZERO
var ship_flame_length := 12.0
var props: Array[Dictionary] = [
	{"cell": Vector2i(10, 7), "kind": "mailbox", "label": "Read mailbox", "used": false},
	{"cell": Vector2i(20, 12), "kind": "notice", "label": "Read notice board", "used": false},
	{"cell": Vector2i(25, 17), "kind": "crate", "label": "Open crate", "used": false},
	{"cell": Vector2i(27, 6), "kind": "lake_npc", "label": "Talk to the lake keeper", "used": false},
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
	{
		"cell": Vector2i(20, 1),
		"kind": "spaceship",
		"label": "Open navigation radar",
		"used": false,
		"no_collision": true,
	},
]

func set_language(value: String) -> void:
	language = "zh" if value == "zh" else "en"

func set_ship_transition_offset(value: Vector2) -> void:
	ship_transition_offset = value
	queue_redraw()

func set_ship_flame_length(value: float) -> void:
	ship_flame_length = value
	queue_redraw()

func _prop_label(kind: String) -> String:
	if language != "zh":
		for prop in props:
			if prop["kind"] == kind:
				return str(prop["label"])
	match kind:
		"mailbox": return "阅读邮箱"
		"notice": return "阅读告示牌"
		"crate": return "打开木箱"
		"shop": return "进入商店"
		"lookout": return "眺望世界树"
		"spaceship": return "打开导航雷达"
		"lake_npc": return "与湖之守望者交谈"
		"ranger": return "与护林员交谈"
	return "互动"

func _ready() -> void:
	_configure_level_props()
	_generate_map()
	_create_collisions()
	queue_redraw()

func _configure_level_props() -> void:
	if level_variant != "pond":
		return
	for index in range(props.size() - 1, -1, -1):
		if str(props[index].get("kind", "")) == "lake_npc":
			props.remove_at(index)
	props.append({
		"cell": Vector2i(8, 8),
		"kind": "ranger",
		"label": "Talk to the ranger",
		"used": false,
	})

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
	if level_variant == "pond":
		_apply_pond_layout()

	assert(_is_in_bounds(PLAYER_START_CELL))
	assert(is_walkable(PLAYER_START_CELL))
	assert(is_walkable(Vector2i(20, 1)))
	assert(is_walkable(LOOKOUT_CELL))

func _apply_pond_layout() -> void:
	# The second map is a wide shore: sand, ocean, boardwalks, and small grass dunes.
	for y in range(1, MAP_SIZE.y - 1):
		for x in range(1, MAP_SIZE.x - 1):
			cells[y][x] = SAND
	for y in range(1, MAP_SIZE.y - 1):
		for x in range(26, MAP_SIZE.x - 1):
			cells[y][x] = WATER
	for x in range(2, 27):
		cells[14][x] = PATH
	for y in range(2, 15):
		cells[y][10] = PATH
	for y in range(14, MAP_SIZE.y - 2):
		cells[y][21] = PATH
	for y in range(5, 11):
		for x in range(3, 9):
			cells[y][x] = GRASS
	for y in range(17, 21):
		for x in range(12, 19):
			cells[y][x] = GRASS
	for cell in [Vector2i(25, 12), Vector2i(25, 13), Vector2i(25, 14), Vector2i(25, 15), Vector2i(26, 14)]:
		cells[cell.y][cell.x] = PATH
	_set_rock_cluster([Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)])
	_set_rock_cluster([Vector2i(15, 6), Vector2i(16, 6), Vector2i(17, 6)])
	_set_rock_cluster([Vector2i(18, 19), Vector2i(19, 19), Vector2i(20, 19)])

func get_player_start_cell() -> Vector2i:
	return PLAYER_START_CELL

func get_level_title() -> String:
	if level_variant == "pond":
		return "日落海岸" if language == "zh" else "SUNSET SHORE"
	return "绿野" if language == "zh" else "GREENMEADOW"

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
	if mode == "orange_seed":
		if level_variant != "pond" or cells[cell.y][cell.x] != SAND or farm_tiles.has(cell):
			return Vector2i(-1, -1)
	elif mode == "hoe":
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

func plant_orange_seed(cell: Vector2i) -> bool:
	if level_variant != "pond" or not _is_in_bounds(cell) or cells[cell.y][cell.x] != SAND or farm_tiles.has(cell):
		return false
	farm_tiles[cell] = {"state": FARM_SEEDED}
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

func is_water_cell(cell: Vector2i) -> bool:
	return _is_in_bounds(cell) and cells[cell.y][cell.x] == WATER

func get_water_footprint(anchor: Vector2i) -> Array[Vector2i]:
	return [
		anchor,
		anchor + Vector2i.RIGHT,
		anchor + Vector2i.DOWN,
		anchor + Vector2i(1, 1),
	]

func get_water_anchor_for_root(root: Vector2i) -> Vector2i:
	return Vector2i(clampi(root.x, 28, 33), clampi(root.y, 4, 7))

func get_water_footprint_for_root(root: Vector2i) -> Array[Vector2i]:
	return get_water_footprint(get_water_anchor_for_root(root))

func get_water_growth_center(root: Vector2i) -> Vector2:
	var anchor := get_water_anchor_for_root(root)
	return cell_to_world(anchor) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

func is_water_footprint_valid(anchor: Vector2i) -> bool:
	for cell in get_water_footprint(anchor):
		if not is_water_cell(cell) or water_growth.has(cell):
			return false
	return true

func can_plant_blue_seed(cell: Vector2i) -> bool:
	if not is_water_cell(cell) or water_growth.has(cell):
		return false
	return is_water_footprint_valid(get_water_anchor_for_root(cell))

func plant_blue_seed(cell: Vector2i) -> bool:
	var root := get_water_anchor_for_root(cell)
	if not can_plant_blue_seed(cell):
		return false
	for footprint_cell in get_water_footprint(root):
		water_growth[footprint_cell] = {"root": root, "state": 0, "order": 0}
	queue_redraw()
	return true

func set_water_growth_state(root: Vector2i, state: int) -> void:
	var canonical_root := get_water_anchor_for_root(root)
	for cell in water_growth.keys():
		if water_growth[cell].get("root", Vector2i(-1, -1)) == canonical_root:
			water_growth[cell]["state"] = state
	queue_redraw()

func get_water_growth_ring(root: Vector2i) -> Array[Vector2i]:
	var canonical_root := get_water_anchor_for_root(root)
	var ring: Array[Vector2i] = []
	for y in range(canonical_root.y - 1, canonical_root.y + 3):
		for x in range(canonical_root.x - 1, canonical_root.x + 3):
			if x != canonical_root.x - 1 and x != canonical_root.x + 2 and y != canonical_root.y - 1 and y != canonical_root.y + 2:
				continue
			var cell := Vector2i(x, y)
			if is_water_cell(cell) and not water_growth.has(cell):
				ring.append(cell)
	return ring

func add_water_growth_cell(cell: Vector2i, root: Vector2i, order: int) -> bool:
	var canonical_root := get_water_anchor_for_root(root)
	if not is_water_cell(cell) or water_growth.has(cell):
		return false
	water_growth[cell] = {"root": canonical_root, "state": 2, "order": order}
	queue_redraw()
	return true

func clear_water_growth(root: Vector2i) -> void:
	var canonical_root := get_water_anchor_for_root(root)
	var cells_to_clear: Array[Vector2i] = []
	for cell in water_growth.keys():
		if water_growth[cell].get("root", Vector2i(-1, -1)) == canonical_root:
			cells_to_clear.append(cell)
	for cell in cells_to_clear:
		water_growth.erase(cell)
	queue_redraw()

func get_water_pointer_cell(mouse_world: Vector2, player_position: Vector2, facing: Vector2) -> Vector2i:
	var cell := world_to_cell(mouse_world)
	if not is_water_cell(cell):
		return Vector2i(-1, -1)
	var player_cell := world_to_cell(player_position)
	if maxi(abs(cell.x - player_cell.x), abs(cell.y - player_cell.y)) > 1:
		return Vector2i(-1, -1)
	var target_offset := cell_to_world(cell) - player_position
	if facing.length_squared() < 0.01 or target_offset.length_squared() < 0.01:
		return Vector2i(-1, -1)
	if facing.normalized().dot(target_offset.normalized()) < 0.25:
		return Vector2i(-1, -1)
	var root := get_water_anchor_for_root(cell)
	return root if can_plant_blue_seed(cell) else Vector2i(-1, -1)

func has_line_of_sight(from: Vector2, to: Vector2, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = WORLD_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

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
	map_collisions.collision_layer = WORLD_COLLISION_LAYER
	map_collisions.collision_mask = WORLD_COLLISION_LAYER
	add_child(map_collisions)

	var water_collisions := StaticBody2D.new()
	water_collisions.name = "WaterCollisions"
	water_collisions.collision_layer = WATER_COLLISION_LAYER
	water_collisions.collision_mask = WATER_COLLISION_LAYER
	add_child(water_collisions)

	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			var cell := Vector2i(x, y)
			if cells[y][x] == WATER:
				_add_rectangle_collision(water_collisions, cell_to_world(cell), Vector2(TILE_SIZE, TILE_SIZE))
			elif cells[y][x] == ROCK:
				_add_rectangle_collision(map_collisions, cell_to_world(cell), Vector2(TILE_SIZE, TILE_SIZE))

	for prop in props:
		if bool(prop.get("no_collision", false)):
			continue
		var footprint: Array = _prop_cells(prop)
		var obstacle_size := Vector2(TILE_SIZE, TILE_SIZE) if prop["kind"] == "shop" else Vector2(18, 18)
		for cell in footprint:
			_add_rectangle_collision(map_collisions, cell_to_world(cell), obstacle_size)

	# Invisible world-layer walls keep physics bodies and charge raycasts inside the map.
	var map_size := get_map_size_pixels()
	var wall_thickness := float(TILE_SIZE)
	var half_wall := wall_thickness * 0.5
	_add_rectangle_collision(map_collisions, Vector2(-half_wall, map_size.y * 0.5), Vector2(wall_thickness, map_size.y + wall_thickness * 2.0))
	_add_rectangle_collision(map_collisions, Vector2(map_size.x + half_wall, map_size.y * 0.5), Vector2(wall_thickness, map_size.y + wall_thickness * 2.0))
	_add_rectangle_collision(map_collisions, Vector2(map_size.x * 0.5, -half_wall), Vector2(map_size.x + wall_thickness * 2.0, wall_thickness))
	_add_rectangle_collision(map_collisions, Vector2(map_size.x * 0.5, map_size.y + half_wall), Vector2(map_size.x + wall_thickness * 2.0, wall_thickness))

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
	if level_variant == "pond":
		_draw_beach_details()

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
	for cell in water_growth:
		_draw_water_growth_cell(cell, water_growth[cell])
	for drop in drops:
		_draw_drop(drop)

func _draw_water_growth_cell(cell: Vector2i, growth: Dictionary) -> void:
	var rect := Rect2(Vector2(cell) * TILE_SIZE + Vector2(2, 2), Vector2(TILE_SIZE - 4, TILE_SIZE - 4))
	var state := int(growth.get("state", 0))
	var color := Color("#275d78") if state == 0 else Color("#287d89")
	if state >= 2:
		color = Color("#3b9ba0")
	draw_rect(rect, Color(color, 0.72), true)
	draw_rect(rect, Color("#8de0d0", 0.85), false, 2.0)
	var center := cell_to_world(cell)
	if state == 0:
		draw_circle(center, 4.0, Color("#b6e8ff"))
		draw_arc(center, 9.0, 0.0, TAU, 16, Color("#6fcfe1", 0.8), 1.5)
	else:
		draw_line(center + Vector2(-8, 4), center + Vector2(-2, -7), Color("#8de0d0"), 2.0)
		draw_line(center + Vector2(8, 5), center + Vector2(2, -9), Color("#65c7a5"), 2.0)
		draw_circle(center + Vector2(0, -9), 5.0 if state == 1 else 8.0, Color("#3da99b"))
	if state >= 2:
		draw_circle(center + Vector2(-5, -12), 3.0, Color("#b0f1d1"))

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
	if level_variant == "pond":
		draw_texture_rect_region(BEACH_BACKDROP_TEXTURE, Rect2(0, -SCENIC_TOP_PIXELS, MAP_SIZE.x * TILE_SIZE, SCENIC_TOP_PIXELS), Rect2(0, 0, 1536, 300))
		draw_rect(Rect2(0, -SCENIC_TOP_PIXELS, MAP_SIZE.x * TILE_SIZE, SCENIC_TOP_PIXELS), Color(1.0, 0.72, 0.4, 0.12), true)
		return
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

func _draw_beach_details() -> void:
	for point in [Vector2(118, 142), Vector2(420, 318), Vector2(690, 594), Vector2(248, 670), Vector2(565, 438)]:
		draw_circle(point, 3.0, Color("#f6e1a3"))
		draw_arc(point + Vector2(7, 0), 6.0, 0.2, 2.6, 14, Color("#b87c59"), 1.5)
	for base in [Vector2(82, 470), Vector2(610, 188)]:
		draw_line(base, base + Vector2(5, -58), Color("#75503b"), 7.0)
		draw_line(base + Vector2(5, -52), base + Vector2(-26, -76), Color("#356d51"), 5.0)
		draw_line(base + Vector2(5, -48), base + Vector2(28, -79), Color("#3f8056"), 5.0)
		draw_line(base + Vector2(5, -48), base + Vector2(8, -88), Color("#4c8e5b"), 5.0)

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
	var position: Vector2 = drop["position"]
	draw_circle(position + Vector2(0, 3), 8.0, Color(0.05, 0.1, 0.1, 0.3))
	if item_id == "plant":
		var alpha := 1.0 if available else 0.35
		draw_line(position + Vector2(0, 6), position + Vector2(0, -6), Color(Color("#24523a"), alpha), 2.0)
		draw_circle(position + Vector2(-4, -5), 4.0, Color(Color("#59b35b"), alpha))
		draw_circle(position + Vector2(4, -4), 4.0, Color(Color("#72c45f"), alpha))
		if not available:
			draw_arc(position, 10.0, 0.0, TAU, 24, Color(0.3, 0.61, 0.33, 0.55), 1.0)
		return
	var drop_color := Color("#8bcf62")
	if item_id == "mutated_pea_drop":
		drop_color = Color("#f3c969")
	elif item_id == "cactus_drop":
		drop_color = Color("#d85d38")
	var color := drop_color if available else Color(drop_color, 0.35)
	draw_circle(position, 6.0, color)
	draw_circle(position + Vector2(-2, -2), 2.0, Color(1, 0.96, 0.7, 0.8) if available else Color(1, 0.96, 0.7, 0.3))
	if not available:
		draw_arc(position, 10.0, 0.0, TAU, 24, Color(drop_color, 0.55), 1.0)

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
		SAND:
			return SAND_B if (cell.x * 3 + cell.y * 5) % 7 == 0 else SAND_A
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
		"ranger":
			_draw_flat_ellipse(center + Vector2(0, 10), Vector2(13, 5), Color(0.05, 0.1, 0.1, 0.3))
			draw_circle(center + Vector2(0, -5), 9.0, Color("#d6a36c"))
			draw_rect(Rect2(center + Vector2(-13, -13), Vector2(26, 7)), Color("#b56b3b"), true)
			draw_rect(Rect2(center + Vector2(-10, -18), Vector2(20, 7)), Color("#b56b3b"), true)
			draw_line(center + Vector2(0, 1), center + Vector2(0, 12), Color("#3e7650"), 8.0)
			draw_line(center + Vector2(-5, 4), center + Vector2(-13, 14), Color("#3e7650"), 3.0)
			draw_line(center + Vector2(5, 4), center + Vector2(13, 14), Color("#3e7650"), 3.0)
			draw_line(center + Vector2(8, 7), center + Vector2(14, -3), Color("#75503b"), 2.0)
			draw_circle(center + Vector2(14, -4), 3.0, Color("#d9e2cf"))
			return
		"lookout":
			# A small marker gives the player a readable arrival point.
			draw_line(center + Vector2(0, 10), center + Vector2(0, -14), Color("#5a4938"), 3.0)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -14), center + Vector2(18, -9), center + Vector2(0, -4),
			]), Color("#d5b15f"))
			draw_line(center + Vector2(-20, 8), center + Vector2(20, 8), Color("#5a4938"), 2.0)
		"spaceship":
			# A simple beacon ship marks the in-world level navigation point.
			center += ship_transition_offset
			_draw_flat_ellipse(center + Vector2(0, 9), Vector2(20, 5), Color(0.05, 0.1, 0.1, 0.3))
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-24, 2), center + Vector2(-12, -10), center + Vector2(13, -10),
				center + Vector2(24, 2), center + Vector2(12, 10), center + Vector2(-13, 10),
			]), Color("#d9e2cf"))
			draw_polyline(PackedVector2Array([
				center + Vector2(-24, 2), center + Vector2(-12, -10), center + Vector2(13, -10),
				center + Vector2(24, 2), center + Vector2(12, 10), center + Vector2(-13, 10),
				center + Vector2(-24, 2),
			]), outline, 2.0, true)
			draw_circle(center + Vector2(0, -1), 7.0, Color("#3e86a5"))
			draw_circle(center + Vector2(0, -2), 3.0, Color("#e7c66d"))
			if ship_flame_length > 0.0:
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-8, 10), center + Vector2(0, 10 + ship_flame_length), center + Vector2(8, 10),
				]), Color("#d66b58"))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-4, 10), center + Vector2(0, 8 + ship_flame_length * 0.7), center + Vector2(4, 10),
				]), Color("#f3c969"))
			draw_line(center + Vector2(-15, 7), center + Vector2(-20, 14), Color("#d66b58"), 3.0)
			draw_line(center + Vector2(15, 7), center + Vector2(20, 14), Color("#d66b58"), 3.0)

func _draw_flat_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

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
	return _prop_label(str(target["kind"]))

func interact(origin: Vector2, facing: Vector2) -> String:
	var target := _find_target(origin, facing)
	if target.is_empty():
		return ""
	var chinese := language == "zh"
	match target["kind"]:
		"mailbox":
			return "邮箱：今天很安静。也许明天会有消息。" if chinese else "Mailbox: A quiet day. Maybe tomorrow."
		"notice":
			return "告示牌：欢迎来到草甸。" if chinese else "Notice board: Welcome to the meadow."
		"shop":
			return "商店：欢迎！随便看看吧。" if chinese else "Shop: Welcome! Take a look around."
		"lookout":
			return "越过悬崖，古老的世界树让沉寂的天空停留在枝头。" if chinese else "Beyond the cliff, the ancient world tree holds the dead sky in its branches."
		"spaceship":
			return "导航雷达已准备就绪。" if chinese else "Navigation radar ready."
		"lake_npc":
			return "Lake keeper: Bring me one mature plant and I will give you a blue seed." if not chinese else "湖之守望者：带一株成熟植物来，我会给你蓝色种子。"
		"ranger":
			return "护林员：欢迎来到日落海岸。" if chinese else "Ranger: Welcome to Sunset Shore."
		"crate":
			if target["used"]:
				return "木箱已经空了。" if chinese else "The crate is empty."
			target["used"] = true
			queue_redraw()
			return "你找到了一包种子。" if chinese else "You found a seed packet."
	return ""
