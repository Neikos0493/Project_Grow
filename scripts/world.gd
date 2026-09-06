class_name MeadowWorld
extends Node2D
## Content-neutral grid map with common farming, drops, collisions, and interactions.

signal state_changed

const TILE_SIZE := 32
const MAP_SIZE := Vector2i(40, 24)
const SCENIC_TOP_PIXELS := 288
const INTERACTION_RANGE := 52.0
const HOE_RANGE_CELLS := 1
const SEED_RANGE_CELLS := 1
const FARM_TILLED := 0
const FARM_SEEDED := 1
const FARM_MATURE := 2
const WORLD_COLLISION_LAYER := 1
const WATER_COLLISION_LAYER := 8
const MAX_DROPS := 256
const MAX_PERSISTED_PLANTS := 256
const PEA_WAIT_TEXTURE := preload("res://image/Monster_pea/ball-wait-Sheet.png")
const SUNFLOWER_TEXTURE := preload("res://image/NPC/Sprite-0005-Sheet.png")
const WORM_TEXTURE := preload("res://image/worm/worm-Sheet.png")
const WORM_FRAME_COUNT := 8
const WORM_FRAME_WIDTH := 64
const WORM_FRAME_DURATION := 0.16
const WORM_TRANSFORM_DURATION := (
	WORM_FRAME_COUNT * WORM_FRAME_DURATION
)

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

var cells: Array[Array] = []
var farm_tiles: Dictionary = {}
var water_growth: Dictionary = {}
var permanent_grass: Dictionary = {}
var drops: Array[Dictionary] = []
var props: Array[Dictionary] = []
var language := "en"
var ship_transition_offset := Vector2.ZERO
var ship_flame_length := 12.0
var water_anchor_min := Vector2i(-1, -1)
var water_anchor_max := Vector2i(-1, -1)
var _is_restoring := false
var enable_pea_npc := false
var pea_npc_phase := 0
var pea_npc_transform_elapsed := 0.0

func _ready() -> void:
	_build_map()
	_validate_map()
	_create_collisions()
	_after_map_ready()
	queue_redraw()

func _process(_delta: float) -> void:
	if _has_animated_props():
		queue_redraw()

func _has_animated_props() -> bool:
	for prop in props:
		var kind := str(prop.get("kind", ""))
		if kind == "ranger":
			return true
		if kind == "pea_npc" and enable_pea_npc:
			return true
	return false

func _build_map() -> void:
	_initialize_grid(GRASS)

func _after_map_ready() -> void:
	pass

func _initialize_grid(fill_type: int) -> void:
	cells.clear()
	for _y in range(MAP_SIZE.y):
		var row: Array = []
		for _x in range(MAP_SIZE.x):
			row.append(fill_type)
		cells.append(row)

func _validate_map() -> void:
	assert(cells.size() == MAP_SIZE.y)
	assert(is_walkable(get_initial_spawn_cell()))
	assert(is_walkable(get_respawn_cell()))
	assert(is_walkable(get_ship_cell()))
	var prop_ids: Dictionary = {}
	for prop in props:
		var prop_id := str(prop.get("id", ""))
		assert(not prop_id.is_empty())
		assert(not prop_ids.has(prop_id))
		prop_ids[prop_id] = true

func get_map_id() -> StringName:
	return &"unknown"

func get_level_title() -> String:
	return "UNKNOWN"

func get_level_subtitle() -> String:
	return ""

func get_arrival_message() -> String:
	return ""

func get_respawn_message() -> String:
	return ""

func get_initial_spawn_cell() -> Vector2i:
	return Vector2i(1, 1)

func get_respawn_cell() -> Vector2i:
	return get_initial_spawn_cell()

func get_ship_cell() -> Vector2i:
	return get_initial_spawn_cell()

func supports_lake_encounter() -> bool:
	return water_anchor_min.x >= 0 and water_anchor_max.x >= water_anchor_min.x

func supports_orange_farming() -> bool:
	return false

func supports_saxaul_encounter() -> bool:
	return false

func get_shop_node() -> MeadowShop:
	return null

func get_plants_container() -> Node2D:
	return get_node("Runtime/Plants") as Node2D

func get_projectiles_container() -> Node2D:
	return get_node("Runtime/Projectiles") as Node2D

func uses_editor_tiles() -> bool:
	return has_node("MapTiles")

func set_language(value: String) -> void:
	language = "zh" if value == "zh" else "en"
	queue_redraw()

func set_ship_transition_offset(value: Vector2) -> void:
	ship_transition_offset = value
	queue_redraw()

func set_ship_flame_length(value: float) -> void:
	ship_flame_length = value
	queue_redraw()

func set_pea_npc_phase(value: int) -> void:
	pea_npc_phase = clampi(value, 0, 1)
	queue_redraw()

func advance_pea_npc_transform(delta: float) -> void:
	if pea_npc_phase != 1:
		return
	pea_npc_transform_elapsed = minf(
		WORM_TRANSFORM_DURATION,
		pea_npc_transform_elapsed + delta
	)
	queue_redraw()

func get_camera_top_limit() -> int:
	return -SCENIC_TOP_PIXELS

func get_map_size_pixels() -> Vector2:
	return Vector2(MAP_SIZE.x * TILE_SIZE, MAP_SIZE.y * TILE_SIZE)

# These grid helpers use coordinates local to this map root, not canvas-global space.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)

func world_to_cell(map_position: Vector2) -> Vector2i:
	return Vector2i(floori(map_position.x / float(TILE_SIZE)), floori(map_position.y / float(TILE_SIZE)))

func global_direction_to_map(direction: Vector2) -> Vector2:
	return global_transform.affine_inverse().basis_xform(direction)

func map_direction_to_global(direction: Vector2) -> Vector2:
	return global_transform.basis_xform(direction)

func get_initial_spawn_position() -> Vector2:
	return cell_to_world(get_initial_spawn_cell())

func get_respawn_position() -> Vector2:
	return cell_to_world(get_respawn_cell())

func get_ship_arrival_position() -> Vector2:
	return get_disembark_end_position()

func get_disembark_start_position() -> Vector2:
	# Start below the hull so the player never spawns inside its collision shape.
	return get_disembark_end_position()

func get_disembark_end_position() -> Vector2:
	# Arrive immediately below the ship rather than at this map's unrelated
	# new-game spawn. Fall back around the ship if its landing tile is blocked.
	var preferred_landing := cell_to_world(get_ship_cell() + Vector2i.DOWN)
	return get_nearest_walkable_position(preferred_landing)

func is_position_walkable(map_position: Vector2) -> bool:
	return is_map_position_in_bounds(map_position) \
		and is_walkable(world_to_cell(map_position))

func is_position_unoccupied(map_position: Vector2) -> bool:
	return is_position_walkable(map_position) \
		and not _is_prop_cell(world_to_cell(map_position))

func is_prop_cell(cell: Vector2i) -> bool:
	return _is_prop_cell(cell)

func is_valid_farm_cell(cell: Vector2i, kind: String = "") -> bool:
	if not _is_in_bounds(cell) or _is_prop_cell(cell):
		return false
	if kind == "orange_cactus":
		return supports_orange_farming() \
			and cells[cell.y][cell.x] == SAND
	return cells[cell.y][cell.x] == GRASS

func get_nearest_valid_farm_cell(
	origin: Vector2i,
	kind: String = "",
	reserved_cells: Dictionary = {},
	additional_grass: Dictionary = {},
	allow_shore_sand := false
) -> Vector2i:
	for radius in range(maxi(MAP_SIZE.x, MAP_SIZE.y)):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if radius > 0 \
				and x > origin.x - radius \
				and x < origin.x + radius \
				and y > origin.y - radius \
				and y < origin.y + radius:
					continue
				var cell := Vector2i(x, y)
				var valid_cell := is_valid_farm_cell(cell, kind)
				if kind != "orange_cactus" \
				and additional_grass.has(cell) \
				and _is_in_bounds(cell) \
				and not _is_prop_cell(cell):
					valid_cell = true
				if kind.is_empty() \
				and allow_shore_sand \
				and supports_orange_farming() \
				and _is_in_bounds(cell) \
				and cells[cell.y][cell.x] == SAND \
				and not _is_prop_cell(cell):
					valid_cell = true
				if valid_cell \
				and not farm_tiles.has(cell) \
				and not reserved_cells.has(cell):
					return cell
	return Vector2i(-1, -1)

func is_map_position_in_bounds(map_position: Vector2) -> bool:
	if not is_finite(map_position.x) or not is_finite(map_position.y):
		return false
	var map_size := get_map_size_pixels()
	return map_position.x >= 0.0 and map_position.y >= 0.0 and map_position.x < map_size.x and map_position.y < map_size.y

func is_drop_position_valid(map_position: Vector2) -> bool:
	# Drops deliberately use only the playable rectangle: water and rock are
	# valid persistence locations because existing drops must not disappear.
	return is_map_position_in_bounds(map_position)

func get_nearest_walkable_position(map_position: Vector2) -> Vector2:
	if not is_map_position_in_bounds(map_position):
		map_position = get_ship_arrival_position()
	var origin := world_to_cell(map_position)
	for radius in range(maxi(MAP_SIZE.x, MAP_SIZE.y)):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if radius > 0 and x > origin.x - radius and x < origin.x + radius and y > origin.y - radius and y < origin.y + radius:
					continue
				var cell := Vector2i(x, y)
				if is_walkable(cell) and not _is_prop_cell(cell):
					return cell_to_world(cell)
	return get_ship_arrival_position()

func is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y

func _is_in_bounds(cell: Vector2i) -> bool:
	return is_cell_in_bounds(cell)

func is_walkable(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or cells.size() != MAP_SIZE.y:
		return false
	return cells[cell.y][cell.x] != WATER \
		and cells[cell.y][cell.x] != ROCK \
		and cells[cell.y][cell.x] != CLIFF

func _set_rock_cluster(cluster: Array[Vector2i]) -> void:
	for cell in cluster:
		if _is_in_bounds(cell):
			cells[cell.y][cell.x] = ROCK

func _prop_cells(prop: Dictionary) -> Array:
	if prop.has("footprint"):
		return prop["footprint"]
	return [prop["cell"]]

func _is_prop_cell(cell: Vector2i) -> bool:
	for prop in props:
		if cell in _prop_cells(prop):
			return true
	return false

func get_pointer_cell(mouse_map_position: Vector2, player_map_position: Vector2, facing_map_direction: Vector2, mode: String) -> Vector2i:
	var cell := world_to_cell(mouse_map_position)
	if not _is_in_bounds(cell) or _is_prop_cell(cell):
		return Vector2i(-1, -1)
	if mode == "saxaul_seed":
		if not can_plant_saxaul_seed(cell):
			return Vector2i(-1, -1)
	elif mode == "orange_seed":
		if not supports_orange_farming() \
		or cells[cell.y][cell.x] != SAND \
		or farm_tiles.has(cell):
			return Vector2i(-1, -1)
	elif mode == "hoe":
		if cells[cell.y][cell.x] != GRASS or farm_tiles.has(cell):
			return Vector2i(-1, -1)
	elif cells[cell.y][cell.x] != GRASS or not farm_tiles.has(cell) or int(farm_tiles[cell].get("state", -1)) != FARM_TILLED:
		return Vector2i(-1, -1)
	var player_cell := world_to_cell(player_map_position)
	var cell_distance := maxi(abs(cell.x - player_cell.x), abs(cell.y - player_cell.y))
	var max_distance := HOE_RANGE_CELLS if mode == "hoe" else SEED_RANGE_CELLS
	if cell_distance > max_distance:
		return Vector2i(-1, -1)
	var target_offset := cell_to_world(cell) - player_map_position
	if facing_map_direction.length_squared() < 0.01 or facing_map_direction.normalized().dot(target_offset.normalized()) < 0.25:
		return Vector2i(-1, -1)
	return cell

func till_nearby(player_map_position: Vector2) -> int:
	var center := world_to_cell(player_map_position)
	var tilled_count := 0
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			if _till_without_signal(Vector2i(x, y)):
				tilled_count += 1
	if tilled_count > 0:
		_state_did_change()
	return tilled_count

func till(cell: Vector2i) -> bool:
	if not _till_without_signal(cell):
		return false
	_state_did_change()
	return true

func _till_without_signal(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or cells[cell.y][cell.x] != GRASS or farm_tiles.has(cell) or _is_prop_cell(cell):
		return false
	farm_tiles[cell] = {"state": FARM_TILLED}
	return true

func plant_seed(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or cells[cell.y][cell.x] != GRASS or not farm_tiles.has(cell):
		return false
	if int(farm_tiles[cell].get("state", -1)) != FARM_TILLED:
		return false
	farm_tiles[cell]["state"] = FARM_SEEDED
	_state_did_change()
	return true

func plant_orange_seed(cell: Vector2i) -> bool:
	if not supports_orange_farming() or not _is_in_bounds(cell) or cells[cell.y][cell.x] != SAND or farm_tiles.has(cell) or _is_prop_cell(cell):
		return false
	farm_tiles[cell] = {"state": FARM_SEEDED}
	_state_did_change()
	return true

func can_plant_saxaul_seed(center: Vector2i) -> bool:
	if not supports_saxaul_encounter() or farm_tiles.has(center):
		return false
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell := Vector2i(x, y)
			if not _is_in_bounds(cell) \
			or cells[cell.y][cell.x] != SAND \
			or _is_prop_cell(cell) \
			or farm_tiles.has(cell):
				return false
	return true

func plant_saxaul_seed(center: Vector2i) -> bool:
	if not can_plant_saxaul_seed(center):
		return false
	farm_tiles[center] = {"state": FARM_SEEDED}
	_state_did_change()
	return true

func convert_saxaul_patch_to_grass(center: Vector2i) -> Array[Vector2i]:
	var converted: Array[Vector2i] = []
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell := Vector2i(x, y)
			if _is_in_bounds(cell) and cells[cell.y][cell.x] == SAND:
				cells[cell.y][cell.x] = GRASS
				permanent_grass[cell] = true
				farm_tiles.erase(cell)
				converted.append(cell)
	if not converted.is_empty():
		_state_did_change()
	return converted

func revert_saxaul_patch_to_sand(
	center: Vector2i,
	occupied_cells: Dictionary = {}
) -> void:
	var reverted := false
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell := Vector2i(x, y)
			if not permanent_grass.has(cell) \
			or farm_tiles.has(cell) \
			or occupied_cells.has(cell):
				continue
			permanent_grass.erase(cell)
			cells[cell.y][cell.x] = SAND
			reverted = true
	if reverted:
		_state_did_change()

func apply_permanent_grass(entries: Array) -> void:
	if not supports_saxaul_encounter():
		return
	for value in entries:
		var cell := Vector2i(-1, -1)
		if value is Vector2i:
			cell = value
		elif value is Array and value.size() == 2:
			cell = Vector2i(int(value[0]), int(value[1]))
		if _is_in_bounds(cell) and cells[cell.y][cell.x] == SAND:
			cells[cell.y][cell.x] = GRASS
			permanent_grass[cell] = true
			farm_tiles.erase(cell)
	queue_redraw()

func get_sand_spread_rings(center: Vector2i) -> Array:
	var rings: Array = []
	if not supports_saxaul_encounter():
		return rings
	var max_radius := maxi(
		maxi(center.x, MAP_SIZE.x - 1 - center.x),
		maxi(center.y, MAP_SIZE.y - 1 - center.y)
	)
	for radius in range(2, max_radius + 1):
		var ring: Array[Vector2i] = []
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if maxi(
					abs(cell.x - center.x),
					abs(cell.y - center.y)
				) != radius:
					continue
				if _is_in_bounds(cell) \
				and cells[cell.y][cell.x] == SAND \
				and not _is_prop_cell(cell):
					ring.append(cell)
		if not ring.is_empty():
			rings.append(ring)
	return rings

func convert_sand_cells_to_grass(target_cells: Array) -> Array[Vector2i]:
	var converted: Array[Vector2i] = []
	if not supports_saxaul_encounter():
		return converted
	for cell_value in target_cells:
		var cell := Vector2i(-1, -1)
		if cell_value is Vector2i:
			cell = cell_value
		elif cell_value is Array and cell_value.size() == 2:
			cell = Vector2i(int(cell_value[0]), int(cell_value[1]))
		if _is_in_bounds(cell) \
		and cells[cell.y][cell.x] == SAND \
		and not _is_prop_cell(cell):
			cells[cell.y][cell.x] = GRASS
			permanent_grass[cell] = true
			farm_tiles.erase(cell)
			converted.append(cell)
	if not converted.is_empty():
		_state_did_change()
	return converted

func set_farm_mature(cell: Vector2i) -> void:
	if farm_tiles.has(cell):
		farm_tiles[cell]["state"] = FARM_MATURE
		_state_did_change()

func set_farm_tilled(cell: Vector2i) -> void:
	if farm_tiles.has(cell):
		farm_tiles[cell]["state"] = FARM_TILLED
		_state_did_change()

func clear_farm(cell: Vector2i) -> void:
	if farm_tiles.erase(cell):
		_state_did_change()

func is_water_cell(cell: Vector2i) -> bool:
	return _is_in_bounds(cell) and cells[cell.y][cell.x] == WATER

func get_water_footprint(anchor: Vector2i) -> Array[Vector2i]:
	return [anchor, anchor + Vector2i.RIGHT, anchor + Vector2i.DOWN, anchor + Vector2i(1, 1)]

func get_water_anchor_for_root(root: Vector2i) -> Vector2i:
	if not supports_lake_encounter():
		return Vector2i(-1, -1)
	return Vector2i(clampi(root.x, water_anchor_min.x, water_anchor_max.x), clampi(root.y, water_anchor_min.y, water_anchor_max.y))

func get_water_growth_center(root: Vector2i) -> Vector2:
	var anchor := get_water_anchor_for_root(root)
	return cell_to_world(anchor) + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

func is_water_footprint_valid(anchor: Vector2i) -> bool:
	if not supports_lake_encounter():
		return false
	for cell in get_water_footprint(anchor):
		if not is_water_cell(cell) or water_growth.has(cell):
			return false
	return true

func can_plant_blue_seed(cell: Vector2i) -> bool:
	if not supports_lake_encounter() or not is_water_cell(cell) or water_growth.has(cell):
		return false
	return is_water_footprint_valid(get_water_anchor_for_root(cell))

func plant_blue_seed(cell: Vector2i) -> bool:
	var root := get_water_anchor_for_root(cell)
	if not can_plant_blue_seed(cell):
		return false
	for footprint_cell in get_water_footprint(root):
		water_growth[footprint_cell] = {"root": root, "state": 0, "order": 0}
	_state_did_change()
	return true

func set_water_growth_state(root: Vector2i, state: int) -> void:
	var canonical_root := get_water_anchor_for_root(root)
	for cell in water_growth.keys():
		if water_growth[cell].get("root", Vector2i(-1, -1)) == canonical_root:
			water_growth[cell]["state"] = state
	_state_did_change()

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
	_state_did_change()
	return true

func clear_water_growth(root: Vector2i) -> void:
	var canonical_root := get_water_anchor_for_root(root)
	var cells_to_clear: Array[Vector2i] = []
	for cell in water_growth.keys():
		if water_growth[cell].get("root", Vector2i(-1, -1)) == canonical_root:
			cells_to_clear.append(cell)
	for cell in cells_to_clear:
		water_growth.erase(cell)
	if not cells_to_clear.is_empty():
		_state_did_change()

func get_water_pointer_cell(mouse_map_position: Vector2, player_map_position: Vector2, facing_map_direction: Vector2) -> Vector2i:
	if not supports_lake_encounter():
		return Vector2i(-1, -1)
	var cell := world_to_cell(mouse_map_position)
	if not is_water_cell(cell):
		return Vector2i(-1, -1)
	var player_cell := world_to_cell(player_map_position)
	if maxi(abs(cell.x - player_cell.x), abs(cell.y - player_cell.y)) > 1:
		return Vector2i(-1, -1)
	var target_offset := cell_to_world(cell) - player_map_position
	if facing_map_direction.length_squared() < 0.01 or target_offset.length_squared() < 0.01:
		return Vector2i(-1, -1)
	if facing_map_direction.normalized().dot(target_offset.normalized()) < 0.25:
		return Vector2i(-1, -1)
	var root := get_water_anchor_for_root(cell)
	return root if can_plant_blue_seed(cell) else Vector2i(-1, -1)

func has_line_of_sight(from_map_position: Vector2, to_map_position: Vector2, exclude: Array[RID] = []) -> bool:
	var query := PhysicsRayQueryParameters2D.create(to_global(from_map_position), to_global(to_map_position))
	query.collision_mask = WORLD_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _find_target(origin: Vector2, facing: Vector2) -> Dictionary:
	if facing.length_squared() < 0.01:
		return {}
	var direction := facing.normalized()
	# A shop's wide footprint should win when the player faces one of its bays;
	# otherwise an adjacent prop can mask the shop's interaction.
	for kind in ["shop", ""]:
		var nearest: Dictionary = {}
		var nearest_distance := INF
		for prop in props:
			if str(prop.get("kind", "")) == "pea_npc" and not enable_pea_npc:
				continue
			if not kind.is_empty() and str(prop.get("kind", "")) != kind:
				continue
			if kind.is_empty() and str(prop.get("kind", "")) == "shop":
				continue
			for cell in _prop_cells(prop):
				var offset := cell_to_world(cell) - origin
				var distance := offset.length()
				if distance > INTERACTION_RANGE or distance < 0.001:
					continue
				if direction.dot(offset.normalized()) < 0.25:
					continue
				if distance < nearest_distance:
					nearest = prop
					nearest_distance = distance
		if not nearest.is_empty():
			return nearest
	return {}

func get_interaction_target(origin: Vector2, facing: Vector2) -> Dictionary:
	return _find_target(origin, facing)

func get_interaction_prompt(origin: Vector2, facing: Vector2) -> String:
	var target := _find_target(origin, facing)
	if target.is_empty():
		return ""
	return str(target.get("label_zh" if language == "zh" else "label_en", "互动" if language == "zh" else "Interact"))

func interact(origin: Vector2, facing: Vector2) -> String:
	var target := _find_target(origin, facing)
	if target.is_empty():
		return ""
	if str(target.get("kind", "")) == "crate":
		if bool(target.get("used", false)):
			return str(target.get("empty_zh" if language == "zh" else "empty_en", "木箱已经空了。" if language == "zh" else "The crate is empty."))
		target["used"] = true
		_state_did_change()
	return str(target.get("message_zh" if language == "zh" else "message_en", ""))

func add_drop(map_position: Vector2, item_id: String, count: int = 1, pickup_delay_msec: int = 3000) -> bool:
	if item_id.is_empty() or count <= 0 or drops.size() >= MAX_DROPS or not is_drop_position_valid(map_position):
		return false
	drops.append({
		"position": map_position,
		"item_id": item_id,
		"count": count,
		"available_at_msec": Time.get_ticks_msec() + maxi(0, pickup_delay_msec),
	})
	_state_did_change()
	return true

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
	_state_did_change()
	return result

func capture_state() -> Dictionary:
	var farm: Array[Dictionary] = []
	for cell in farm_tiles:
		farm.append({"cell": _cell_to_data(cell), "state": int(farm_tiles[cell].get("state", FARM_TILLED))})
	var growth: Array[Dictionary] = []
	for cell in water_growth:
		var value: Dictionary = water_growth[cell]
		growth.append({
			"cell": _cell_to_data(cell),
			"root": _cell_to_data(value.get("root", cell)),
			"state": int(value.get("state", 0)),
			"order": int(value.get("order", 0)),
		})
	var used_prop_ids: Array[String] = []
	for prop in props:
		if bool(prop.get("used", false)):
			used_prop_ids.append(str(prop.get("id", "")))
	var grass_data: Array[Array] = []
	for cell in permanent_grass:
		grass_data.append(_cell_to_data(cell))
	var drop_data: Array[Dictionary] = []
	var now := Time.get_ticks_msec()
	for drop in drops:
		drop_data.append({
			"position": _position_to_data(drop.get("position", Vector2.ZERO)),
			"item_id": str(drop.get("item_id", "")),
			"count": int(drop.get("count", 1)),
			"pickup_delay_msec": maxi(0, int(drop.get("available_at_msec", now)) - now),
		})
	return {
		"snapshot_version": 1,
		"farm": farm,
		"water_growth": growth,
		"used_prop_ids": used_prop_ids,
		"permanent_grass": grass_data,
		"drops": drop_data,
	}

func restore_state(data: Dictionary) -> void:
	_is_restoring = true
	farm_tiles.clear()
	water_growth.clear()
	permanent_grass.clear()
	drops.clear()
	apply_permanent_grass(data.get("permanent_grass", []))
	var used_lookup: Dictionary = {}
	for value in data.get("used_prop_ids", []):
		used_lookup[str(value)] = true
	for prop in props:
		prop["used"] = used_lookup.has(str(prop.get("id", "")))
	for entry_value in data.get("farm", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var cell := _data_to_cell(entry.get("cell", []))
		var state := clampi(int(entry.get("state", FARM_TILLED)), FARM_TILLED, FARM_MATURE)
		if not _is_in_bounds(cell) or _is_prop_cell(cell):
			continue
		var grass_farm: bool = cells[cell.y][cell.x] == GRASS
		var shore_sand_farm: bool = supports_orange_farming() and cells[cell.y][cell.x] == SAND
		if grass_farm or shore_sand_farm:
			farm_tiles[cell] = {"state": state}
	for entry_value in data.get("water_growth", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var cell := _data_to_cell(entry.get("cell", []))
		var root := _data_to_cell(entry.get("root", []))
		if is_water_cell(cell) and is_water_cell(root):
			water_growth[cell] = {
				"root": root,
				"state": clampi(int(entry.get("state", 0)), 0, 2),
				"order": maxi(0, int(entry.get("order", 0))),
			}
	for entry_value in data.get("drops", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var item_id := str(entry.get("item_id", ""))
		var count := int(entry.get("count", 0))
		var position := _data_to_position(entry.get("position", []))
		add_drop(position, item_id, count, clampi(int(entry.get("pickup_delay_msec", 0)), 0, 3000))
	_is_restoring = false
	queue_redraw()

func _cell_to_data(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]

func _position_to_data(position: Vector2) -> Array[float]:
	return [position.x, position.y]

func _data_to_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)

func _data_to_position(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		var position := Vector2(float(value[0]), float(value[1]))
		if is_finite(position.x) and is_finite(position.y):
			return position
	return Vector2(-INF, -INF)

func _state_did_change() -> void:
	queue_redraw()
	if not _is_restoring:
		state_changed.emit()

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
			elif cells[y][x] == ROCK or cells[y][x] == CLIFF:
				_add_rectangle_collision(map_collisions, cell_to_world(cell), Vector2(TILE_SIZE, TILE_SIZE))
	for prop in props:
		if bool(prop.get("no_collision", false)):
			continue
		var prop_kind := str(prop.get("kind", ""))
		var obstacle_size := Vector2(TILE_SIZE, TILE_SIZE) if prop_kind == "shop" else Vector2(18.0, 18.0)
		var configured_size: Variant = prop.get("collision_size", Vector2.ZERO)
		if configured_size is Vector2 and configured_size.x > 0.0 and configured_size.y > 0.0:
			obstacle_size = configured_size
		for cell in _prop_cells(prop):
			_add_rectangle_collision(map_collisions, cell_to_world(cell), obstacle_size)
	var map_size := get_map_size_pixels()
	var wall_thickness := float(TILE_SIZE)
	var half_wall := wall_thickness * 0.5
	_add_rectangle_collision(map_collisions, Vector2(-half_wall, map_size.y * 0.5), Vector2(wall_thickness, map_size.y + wall_thickness * 2.0))
	_add_rectangle_collision(map_collisions, Vector2(map_size.x + half_wall, map_size.y * 0.5), Vector2(wall_thickness, map_size.y + wall_thickness * 2.0))
	_add_rectangle_collision(map_collisions, Vector2(map_size.x * 0.5, -half_wall), Vector2(map_size.x + wall_thickness * 2.0, wall_thickness))
	_add_rectangle_collision(map_collisions, Vector2(map_size.x * 0.5, map_size.y + half_wall), Vector2(map_size.x + wall_thickness * 2.0, wall_thickness))
	_add_map_collisions(map_collisions)

func _add_map_collisions(_map_collisions: StaticBody2D) -> void:
	pass

func _add_rectangle_collision(parent: Node, center: Vector2, size: Vector2) -> void:
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape_node.shape = rectangle
	shape_node.position = center
	parent.add_child(shape_node)

func _draw() -> void:
	_draw_background()
	_draw_scenery_before_tiles()
	if not uses_editor_tiles():
		for y in range(MAP_SIZE.y):
			for x in range(MAP_SIZE.x):
				var cell := Vector2i(x, y)
				var tile_type: int = cells[y][x]
				var rect := Rect2(Vector2(x, y) * TILE_SIZE, Vector2.ONE * TILE_SIZE)
				draw_rect(rect, _tile_color(tile_type, cell))
				draw_line(rect.position, rect.position + Vector2(TILE_SIZE, 0), GRID_COLOR, 1.0)
				draw_line(rect.position, rect.position + Vector2(0, TILE_SIZE), GRID_COLOR, 1.0)
				if tile_type == WATER:
					var wave_x := rect.position.x + 7.0 + float((x * 11 + y * 5) % 12)
					draw_line(Vector2(wave_x, rect.position.y + 12), Vector2(wave_x + 9, rect.position.y + 12), Color(0.72, 0.91, 0.9, 0.34), 1.0)
					draw_line(Vector2(wave_x - 3, rect.position.y + 22), Vector2(wave_x + 5, rect.position.y + 22), Color(0.72, 0.91, 0.9, 0.2), 1.0)
	_draw_scenery_after_tiles()
	if not has_node("MapDecorations"):
		for prop in props:
			if prop.get("kind", "") == "pea_npc" and not enable_pea_npc:
				continue
			if prop.get("kind", "") != "shop":
				_draw_prop(prop)
		for cell in farm_tiles:
			_draw_farm_tile(cell, farm_tiles[cell])
		for cell in water_growth:
			_draw_water_growth_cell(cell, water_growth[cell])
		for drop in drops:
			_draw_drop(drop)

func _draw_background() -> void:
	pass

func _draw_scenery_before_tiles() -> void:
	pass

func _draw_scenery_after_tiles() -> void:
	pass

func _tile_color(tile_type: int, cell: Vector2i) -> Color:
	match tile_type:
		DIRT: return DIRT_COLOR
		PATH: return PATH_COLOR
		WATER: return WATER_COLOR
		ROCK: return ROCK_COLOR
		CLIFF: return CLIFF_COLOR
		SAND: return SAND_B if (cell.x * 3 + cell.y * 5) % 7 == 0 else SAND_A
		_: return GRASS_B if (cell.x * 3 + cell.y * 5) % 7 == 0 else GRASS_A

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

func _draw_prop(prop: Dictionary) -> void:
	if str(prop.get("kind", "")) == "pea_npc" and not enable_pea_npc:
		return
	var center: Vector2 = cell_to_world(prop["cell"])
	var outline := Color("#26353b")
	match str(prop.get("kind", "")):
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
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), Color("#9d704c"), true)
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), outline, false, 2.0)
			if bool(prop.get("used", false)):
				draw_line(center + Vector2(-10, -7), center + Vector2(10, -12), Color("#e0bc73"), 3.0)
			else:
				draw_line(center + Vector2(-8, -7), center + Vector2(8, 7), Color("#d4a666"), 2.0)
				draw_line(center + Vector2(8, -7), center + Vector2(-8, 7), Color("#d4a666"), 2.0)
		"lake_npc":
			_draw_flat_ellipse(center + Vector2(0, 10), Vector2(13, 5), Color(0.05, 0.1, 0.1, 0.3))
			draw_circle(center + Vector2(0, -5), 9.0, Color("#d6a36c"))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, -7), center + Vector2(0, -21), center + Vector2(13, -7)]), Color("#315c70"))
			draw_line(center + Vector2(0, 1), center + Vector2(0, 12), Color("#315c70"), 8.0)
			draw_line(center + Vector2(6, 3), center + Vector2(13, 13), Color("#8b633f"), 2.0)
			draw_circle(center + Vector2(15, 14), 3.0, Color("#6fcfe1"))
		"ranger":
			var frame := int(Time.get_ticks_msec() / 180) % 4
			var source := Rect2(frame * 64, 0, 64, 64)
			draw_texture_rect_region(SUNFLOWER_TEXTURE, Rect2(center - Vector2(32, 48), Vector2(64, 64)), source)
		"pea_npc":
			if pea_npc_phase == 1:
				var worm_frame := mini(
					WORM_FRAME_COUNT - 1,
					int(pea_npc_transform_elapsed / WORM_FRAME_DURATION)
				)
				var worm_source := Rect2(
					worm_frame * WORM_FRAME_WIDTH,
					0,
					WORM_FRAME_WIDTH,
					32
				)
				draw_texture_rect_region(
					WORM_TEXTURE,
					Rect2(
						center - Vector2(32, 16),
						Vector2(64, 32)
					),
					worm_source
				)
			else:
				var pea_frame := int(Time.get_ticks_msec() / 420) % 2
				var pea_source := Rect2(pea_frame * 67, 0, 67, 49)
				draw_texture_rect_region(PEA_WAIT_TEXTURE, Rect2(center - Vector2(34, 25), Vector2(67, 49)), pea_source)
		"lookout":
			draw_line(center + Vector2(0, 10), center + Vector2(0, -14), Color("#5a4938"), 3.0)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -14), center + Vector2(18, -9), center + Vector2(0, -4)]), Color("#d5b15f"))
			draw_line(center + Vector2(-20, 8), center + Vector2(20, 8), Color("#5a4938"), 2.0)
		"spaceship":
			_draw_spaceship(center + ship_transition_offset, outline)

func _draw_spaceship(center: Vector2, outline: Color) -> void:
	_draw_flat_ellipse(center + Vector2(0, 9), Vector2(20, 5), Color(0.05, 0.1, 0.1, 0.3))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-24, 2), center + Vector2(-12, -10), center + Vector2(13, -10), center + Vector2(24, 2), center + Vector2(12, 10), center + Vector2(-13, 10)]), Color("#d9e2cf"))
	draw_polyline(PackedVector2Array([center + Vector2(-24, 2), center + Vector2(-12, -10), center + Vector2(13, -10), center + Vector2(24, 2), center + Vector2(12, 10), center + Vector2(-13, 10), center + Vector2(-24, 2)]), outline, 2.0, true)
	draw_circle(center + Vector2(0, -1), 7.0, Color("#3e86a5"))
	draw_circle(center + Vector2(0, -2), 3.0, Color("#e7c66d"))
	if ship_flame_length > 0.0:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 10), center + Vector2(0, 10 + ship_flame_length), center + Vector2(8, 10)]), Color("#d66b58"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 10), center + Vector2(0, 8 + ship_flame_length * 0.7), center + Vector2(4, 10)]), Color("#f3c969"))
	draw_line(center + Vector2(-15, 7), center + Vector2(-20, 14), Color("#d66b58"), 3.0)
	draw_line(center + Vector2(15, 7), center + Vector2(20, 14), Color("#d66b58"), 3.0)

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
	else:
		if item_id == "pea_drop":
			var pea_texture := preload("res://image/Monster_pea/Bean.png")
			var pea_tint := Color(1.0, 1.0, 1.0, 1.0 if available else 0.35)
			draw_texture_rect(pea_texture, Rect2(position - Vector2(12, 12), Vector2(24, 24)), false, pea_tint)
		else:
			var base_color := Color("#f3c969")
			match item_id:
				"mutated_pea_drop":
					base_color = Color("#f3c969")
				"cactus_drop":
					base_color = Color("#e77a32")
				"pure_cactus_drop":
					base_color = Color("#f0c95c")
			draw_circle(position, 6.0, base_color if available else Color(base_color, 0.35))
	if not available:
		draw_arc(position, 10.0, 0.0, TAU, 24, Color(0.95, 0.78, 0.4, 0.45), 1.0)

func _draw_flat_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
