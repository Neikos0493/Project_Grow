extends Node
## Versioned single-slot session and autosave service.

const SCHEMA_VERSION := 1
var save_path := "user://autosave.json"
var temp_path := "user://autosave.json.tmp"
var backup_path := "user://autosave.json.bak"
const MAX_SAVE_BYTES := 4 * 1024 * 1024
const MAX_MAP_ENTRIES := 2
const MAX_FARM_TILES := 960
const MAX_WATER_GROWTH := 64
const MAX_PERMANENT_GRASS := 960
const MAX_DROPS := MeadowWorld.MAX_DROPS
const MAX_ENTITIES := MeadowWorld.MAX_PERSISTED_PLANTS
const MAX_COINS := 999999999
const MAX_HEALTH := 5
const PEA_TRANSFORM_DURATION := MeadowWorld.WORM_TRANSFORM_DURATION
const QUEST_STATE_MIN := 0
const QUEST_STATE_MAX := 4
const KNOWN_MAP_IDS := [&"greenmeadow", &"sunset_shore"]
const DEFAULT_UNLOCKED_MAP_IDS := [&"greenmeadow"]
const KNOWN_BOSS_IDS := [&"lake_monster", &"saxaul_boss", &"sky_boss"]
const LEGACY_ITEM_REPLACEMENTS := {
	"yellow_ball": "bow",
}
const KNOWN_ITEM_IDS := {
	"hoe": 1,
	"green_seed": 64,
	"bean_seed": 64,
	"sunglasses": 1,
	"orange_seed": 64,
	"bow": 1,
	"tree_gun": 1,
	"melee_weapon": 1,
	"pea_drop": 64,
	"mutated_pea_drop": 64,
	"cactus_drop": 64,
	"pure_cactus_drop": 64,
	"saxaul_seed": 1,
	"lily_seed": 1,
	"blue_seed": 1,
	"plant": 64,
}

var session_initialized := false
var language := "zh"
var current_map_id := &"greenmeadow"
var inventory_state: Dictionary = {}
var coins := 9999
var player_health := MAX_HEALTH
var quest_state := QUEST_STATE_MIN
var unlocked_map_ids: Array[StringName] = []
var map_states: Dictionary = {}
var entry_mode := "new_game"
var last_load_used_backup := false
var orange_seed_granted := false
var green_plantings_since_mutation := 0
var world_tree_blessing_unlocked := false
var world_tree_redemption_triggered := false
var defeated_boss_ids: Array[StringName] = []
var container_energy := 0
var sunflower_quest_state := 0
var map_two_return_count := 0
var pea_npc_state := 0
var pea_npc_transform_elapsed := 0.0
var energy := 0
var world_tree_energy := 0
var cactus_kills_since_drop := 0

func _ready() -> void:
	if not session_initialized:
		reset_session()

func reset_session() -> void:
	session_initialized = true
	current_map_id = &"greenmeadow"
	inventory_state = _default_inventory_state()
	coins = 9999
	player_health = MAX_HEALTH
	quest_state = QUEST_STATE_MIN
	unlocked_map_ids.clear()
	unlocked_map_ids.assign(DEFAULT_UNLOCKED_MAP_IDS)
	map_states.clear()
	entry_mode = "new_game"
	last_load_used_backup = false
	orange_seed_granted = false
	green_plantings_since_mutation = 0
	world_tree_blessing_unlocked = false
	world_tree_redemption_triggered = false
	defeated_boss_ids.clear()
	container_energy = 0
	sunflower_quest_state = 0
	map_two_return_count = 0
	pea_npc_state = 0
	pea_npc_transform_elapsed = 0.0
	energy = 0
	world_tree_energy = 0
	cactus_kills_since_drop = 0

func ensure_session() -> void:
	if not session_initialized:
		reset_session()

func capture_global(inventory: MeadowInventory, next_coins: int, health: int, next_quest_state: int) -> void:
	inventory_state = inventory.export_state()
	coins = clampi(next_coins, 0, MAX_COINS)
	player_health = clampi(health, 0, MAX_HEALTH)
	quest_state = clampi(next_quest_state, QUEST_STATE_MIN, QUEST_STATE_MAX)
	container_energy = clampi(container_energy, 0, 100)
	energy = clampi(energy, 0, 100)
	world_tree_energy = clampi(world_tree_energy, 0, 100)
	cactus_kills_since_drop = clampi(cactus_kills_since_drop, 0, 4)
	var valid_bosses: Array[StringName] = []
	for boss_id in defeated_boss_ids:
		if boss_id in KNOWN_BOSS_IDS and boss_id not in valid_bosses:
			valid_bosses.append(boss_id)
	defeated_boss_ids = valid_bosses

func set_map_state(map_id: StringName, state: Dictionary) -> bool:
	if map_id not in KNOWN_MAP_IDS:
		return false
	map_states[String(map_id)] = state.duplicate(true)
	return true

func get_map_state(map_id: StringName) -> Dictionary:
	var value: Variant = map_states.get(String(map_id), {})
	return value.duplicate(true) if value is Dictionary else {}

func has_valid_save() -> bool:
	return not _read_valid_save(save_path).is_empty() or not _read_valid_save(backup_path).is_empty()

func load_game() -> bool:
	var data := _read_valid_save(save_path)
	last_load_used_backup = false
	if data.is_empty():
		data = _read_valid_save(backup_path)
		last_load_used_backup = not data.is_empty()
	if data.is_empty():
		return false
	_apply_valid_save(data)
	entry_mode = "continue"
	if last_load_used_backup:
		_recover_primary_from_backup(data)
	return true

func save_game() -> bool:
	ensure_session()
	var normalized := _normalize_save(_build_save_data())
	if normalized.is_empty():
		push_error("Autosave validation failed before writing.")
		return false
	var json := JSON.stringify(normalized, "\t")
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null:
		push_error("Could not open temporary autosave file: %s" % FileAccess.get_open_error())
		return false
	temp.store_string(json)
	temp.flush()
	temp.close()
	if _read_valid_save(temp_path).is_empty():
		push_error("Temporary autosave did not pass validation.")
		_remove_if_exists(temp_path)
		return false
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	var rotated_backup := false
	if FileAccess.file_exists(save_path):
		var current_primary_is_valid := not _read_valid_save(save_path).is_empty()
		if current_primary_is_valid:
			_remove_if_exists(backup_path)
			var backup_error := DirAccess.rename_absolute(
				absolute_save,
				absolute_backup
			)
			if backup_error != OK:
				push_error("Could not rotate autosave backup: %s" % backup_error)
				_remove_if_exists(temp_path)
				return false
			rotated_backup = true
		else:
			var remove_error := DirAccess.remove_absolute(absolute_save)
			if remove_error != OK:
				push_error("Could not replace invalid autosave: %s" % remove_error)
				_remove_if_exists(temp_path)
				return false
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if replace_error != OK:
		push_error("Could not install autosave: %s" % replace_error)
		if rotated_backup and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		_remove_if_exists(temp_path)
		return false
	return true

func _recover_primary_from_backup(data: Dictionary) -> void:
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null:
		return
	temp.store_string(JSON.stringify(data, "\t"))
	temp.flush()
	temp.close()
	if _read_valid_save(temp_path).is_empty():
		_remove_if_exists(temp_path)
		return
	_remove_if_exists(save_path)
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if error != OK:
		_remove_if_exists(temp_path)

func delete_save_files() -> bool:
	var succeeded := true
	for path in [save_path, temp_path, backup_path]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				succeeded = false
	return succeeded

func start_new_game() -> bool:
	if not delete_save_files():
		return false
	reset_session()
	return true

func _build_save_data() -> Dictionary:
	var maps: Dictionary = {}
	for map_id in KNOWN_MAP_IDS:
		var key := String(map_id)
		if map_states.has(key) and map_states[key] is Dictionary:
			maps[key] = map_states[key].duplicate(true)
	var unlocked: Array[String] = []
	for map_id in unlocked_map_ids:
		if map_id in KNOWN_MAP_IDS and String(map_id) not in unlocked:
			unlocked.append(String(map_id))
	return {
		"schema_version": SCHEMA_VERSION,
		"current_map_id": String(current_map_id),
		"global": {
			"inventory": inventory_state.duplicate(true),
			"coins": coins,
			"player_health": player_health,
			"quest_state": quest_state,
			"orange_seed_granted": orange_seed_granted,
			"green_plantings_since_mutation": green_plantings_since_mutation,
			"world_tree_blessing_unlocked": world_tree_blessing_unlocked,
			"world_tree_redemption_triggered": world_tree_redemption_triggered,
			"defeated_boss_ids": _boss_ids_to_strings(),
			"container_energy": container_energy,
			"sunflower_quest_state": sunflower_quest_state,
			"map_two_return_count": map_two_return_count,
			"pea_npc_state": pea_npc_state,
			"pea_npc_transform_elapsed": pea_npc_transform_elapsed,
				"energy": energy,
			"world_tree_energy": world_tree_energy,
			"cactus_kills_since_drop": cactus_kills_since_drop,
			"unlocked_map_ids": unlocked,
		},
		"maps": maps,
	}

func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_SAVE_BYTES:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	return _normalize_save(parsed)

func _normalize_save(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return {}
	var map_id := StringName(str(data.get("current_map_id", "")))
	if map_id == &"world_tree":
		map_id = &"greenmeadow"
	if map_id not in KNOWN_MAP_IDS:
		return {}
	var global_value: Variant = data.get("global", {})
	var maps_value: Variant = data.get("maps", {})
	if not global_value is Dictionary or not maps_value is Dictionary or maps_value.size() > MAX_MAP_ENTRIES:
		return {}
	var normalized_global := _normalize_global(global_value)
	if normalized_global.is_empty():
		return {}
	var normalized_maps: Dictionary = {}
	for key_value in maps_value.keys():
		var key := str(key_value)
		if StringName(key) == &"world_tree":
			continue
		if StringName(key) not in KNOWN_MAP_IDS or not maps_value[key_value] is Dictionary:
			return {}
		var normalized_map := _normalize_map_state(StringName(key), maps_value[key_value])
		if normalized_map.is_empty():
			return {}
		normalized_maps[key] = normalized_map
	return {
		"schema_version": SCHEMA_VERSION,
		"current_map_id": String(map_id),
		"global": normalized_global,
		"maps": normalized_maps,
	}

func _normalize_global(data: Dictionary) -> Dictionary:
	var inventory_value: Variant = data.get("inventory", {})
	if not inventory_value is Dictionary:
		return {}
	var normalized_inventory := _normalize_inventory(inventory_value)
	if normalized_inventory.is_empty():
		return {}
	var unlocked_value: Variant = data.get("unlocked_map_ids", [])
	if not unlocked_value is Array:
		return {}
	var unlocked: Array[String] = []
	for value in unlocked_value:
		var map_id := StringName(str(value))
		if map_id not in KNOWN_MAP_IDS:
			return {}
		if String(map_id) not in unlocked:
			unlocked.append(String(map_id))
	if String(&"greenmeadow") not in unlocked:
		unlocked.append(String(&"greenmeadow"))
	var world_tree_blessing_unlocked := bool(data.get("world_tree_blessing_unlocked", false))
	var defeated_value: Variant = data.get("defeated_boss_ids", [])
	if not data.has("defeated_boss_ids"):
		defeated_value = []
		if int(data.get("quest_state", QUEST_STATE_MIN)) == QUEST_STATE_MAX:
			defeated_value = ["lake_monster"]
	if not defeated_value is Array:
		return {}
	var normalized_bosses: Array[String] = []
	for value in defeated_value:
		var boss_id := StringName(str(value))
		if boss_id not in KNOWN_BOSS_IDS:
			return {}
		if String(boss_id) not in normalized_bosses:
			normalized_bosses.append(String(boss_id))
	var normalized_pea_npc_state := clampi(
		int(data.get("pea_npc_state", 0)),
		0,
		2
	)
	var normalized_pea_transform_elapsed := 0.0
	if normalized_pea_npc_state == 1:
		normalized_pea_transform_elapsed = clampf(float(data.get(
			"pea_npc_transform_elapsed",
			PEA_TRANSFORM_DURATION
		)), 0.0, PEA_TRANSFORM_DURATION)
	elif normalized_pea_npc_state == 2:
		normalized_pea_transform_elapsed = PEA_TRANSFORM_DURATION
	if not world_tree_blessing_unlocked:
		unlocked.erase(String(&"sunset_shore"))
	elif String(&"sunset_shore") not in unlocked:
		unlocked.append(String(&"sunset_shore"))
	return {
		"inventory": normalized_inventory,
		"coins": clampi(int(data.get("coins", 9999)), 0, MAX_COINS),
		"player_health": clampi(int(data.get("player_health", MAX_HEALTH)), 0, MAX_HEALTH),
		"quest_state": clampi(int(data.get("quest_state", QUEST_STATE_MIN)), QUEST_STATE_MIN, QUEST_STATE_MAX),
		"orange_seed_granted": bool(data.get("orange_seed_granted", false)),
		"green_plantings_since_mutation": clampi(int(data.get("green_plantings_since_mutation", 0)), 0, 9),
		"world_tree_blessing_unlocked": world_tree_blessing_unlocked,
		"world_tree_redemption_triggered": bool(data.get("world_tree_redemption_triggered", false)),
		"defeated_boss_ids": normalized_bosses,
		"container_energy": clampi(int(data.get("container_energy", normalized_bosses.size() * 50)), 0, 100),
		"sunflower_quest_state": clampi(int(data.get("sunflower_quest_state", 0)), 0, 2),
		"map_two_return_count": clampi(int(data.get("map_two_return_count", 0)), 0, 2),
		"pea_npc_state": normalized_pea_npc_state,
		"pea_npc_transform_elapsed": normalized_pea_transform_elapsed,
		"energy": clampi(int(data.get("energy", 0)), 0, 100),
		"world_tree_energy": clampi(int(data.get("world_tree_energy", 0)), 0, 100),
		"cactus_kills_since_drop": clampi(int(data.get("cactus_kills_since_drop", 0)), 0, 4),
		"unlocked_map_ids": unlocked,
	}

func _normalize_inventory(data: Dictionary) -> Dictionary:
	var slots_value: Variant = data.get("slots", [])
	if not slots_value is Array or slots_value.size() != 5:
		return {}
	var slots: Array[Dictionary] = []
	for value in slots_value:
		if not value is Dictionary:
			return {}
		var item_id := str(value.get("id", ""))
		item_id = str(LEGACY_ITEM_REPLACEMENTS.get(item_id, item_id))
		var count := int(value.get("count", 0))
		if item_id.is_empty() or item_id == "quest_item_1":
			slots.append({"id": "", "count": 0})
			continue
		if not KNOWN_ITEM_IDS.has(item_id) or count <= 0:
			return {}
		slots.append({"id": item_id, "count": clampi(count, 1, int(KNOWN_ITEM_IDS[item_id]))})
	return {
		"slots": slots,
		"selected_slot": clampi(int(data.get("selected_slot", 0)), 0, 4),
	}

func _normalize_map_state(map_id: StringName, data: Dictionary) -> Dictionary:
	if int(data.get("snapshot_version", -1)) != 1:
		return {}
	var farm_value: Variant = data.get("farm", [])
	var growth_value: Variant = data.get("water_growth", [])
	var props_value: Variant = data.get("used_prop_ids", [])
	var grass_value: Variant = data.get("permanent_grass", [])
	var drops_value: Variant = data.get("drops", [])
	var entities_value: Variant = data.get("entities", [])
	var encounter_value: Variant = data.get("encounter", {})
	var saxaul_spread_value: Variant = data.get("saxaul_spread", {})
	if not farm_value is Array or farm_value.size() > MAX_FARM_TILES:
		return {}
	if not growth_value is Array or growth_value.size() > MAX_WATER_GROWTH:
		return {}
	if not props_value is Array or props_value.size() > 64:
		return {}
	if not grass_value is Array \
	or grass_value.size() > MAX_PERMANENT_GRASS:
		return {}
	if not drops_value is Array or drops_value.size() > MAX_DROPS:
		return {}
	if not entities_value is Array \
	or entities_value.size() > MAX_ENTITIES + 1:
		return {}
	if not encounter_value is Dictionary \
	or not saxaul_spread_value is Dictionary:
		return {}
	var default_position := [656.0, 80.0] if map_id == &"greenmeadow" else [464.0, 432.0]
	var result := {
		"snapshot_version": 1,
		"farm": _normalize_farm(farm_value),
		"water_growth": _normalize_growth(map_id, growth_value),
		"used_prop_ids": _normalize_prop_ids(map_id, props_value),
		"permanent_grass": _normalize_permanent_grass(
			map_id,
			grass_value
		),
		"drops": _normalize_drops(drops_value),
		"entities": _normalize_entities(map_id, entities_value),
		"encounter": _normalize_encounter(map_id, encounter_value),
		"saxaul_spread": _normalize_saxaul_spread(
			map_id,
			saxaul_spread_value
		),
		"last_player_position": _normalize_position(data.get("last_player_position", []), default_position, true),
		"next_entity_serial": clampi(int(data.get("next_entity_serial", 1)), 1, 1000000000),
	}
	if result["farm"] == null \
	or result["water_growth"] == null \
	or result["used_prop_ids"] == null \
	or result["permanent_grass"] == null \
	or result["drops"] == null \
	or result["entities"] == null \
	or result["encounter"] == null \
	or result["saxaul_spread"] == null:
		return {}
	var saxaul_count := 0
	var dead_saxaul := false
	var ordinary_entity_count := 0
	for entity_value in result["entities"]:
		var entity: Dictionary = entity_value
		if str(entity.get("kind", "")) == "saxaul_boss":
			saxaul_count += 1
			dead_saxaul = bool(entity.get("dead", false))
		else:
			ordinary_entity_count += 1
	if ordinary_entity_count > MAX_ENTITIES:
		return {}
	if saxaul_count > 1 \
	or (not result["saxaul_spread"].is_empty() \
	and (saxaul_count != 1 or not dead_saxaul)):
		return {}
	return result

func _normalize_farm(entries: Array) -> Variant:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value in entries:
		if not value is Dictionary:
			return null
		var cell: Variant = _normalize_cell(value.get("cell", []))
		if cell == null:
			return null
		var key := "%d,%d" % [cell[0], cell[1]]
		if seen.has(key):
			return null
		seen[key] = true
		result.append({"cell": cell, "state": clampi(int(value.get("state", 0)), 0, 2)})
	return result

func _normalize_growth(map_id: StringName, entries: Array) -> Variant:
	if map_id != &"greenmeadow" and not entries.is_empty():
		return null
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value in entries:
		if not value is Dictionary:
			return null
		var cell: Variant = _normalize_cell(value.get("cell", []))
		var root: Variant = _normalize_cell(value.get("root", []))
		if cell == null or root == null:
			return null
		var key := "%d,%d" % [cell[0], cell[1]]
		if seen.has(key):
			return null
		seen[key] = true
		result.append({"cell": cell, "root": root, "state": clampi(int(value.get("state", 0)), 0, 2), "order": clampi(int(value.get("order", 0)), 0, 64)})
	return result

func _normalize_prop_ids(map_id: StringName, entries: Array) -> Variant:
	var result: Array[String] = []
	var prefix := String(map_id) + "."
	for value in entries:
		var prop_id := str(value)
		if not prop_id.begins_with(prefix) or prop_id in result:
			return null
		result.append(prop_id)
	return result

func _normalize_permanent_grass(
	map_id: StringName,
	entries: Array
) -> Variant:
	if map_id != &"sunset_shore" and not entries.is_empty():
		return null
	var result: Array[Array] = []
	var seen: Dictionary = {}
	for value in entries:
		var cell: Variant = _normalize_cell(value)
		if cell == null:
			return null
		var key := "%d,%d" % [cell[0], cell[1]]
		if seen.has(key):
			return null
		seen[key] = true
		result.append(cell)
	return result

func _normalize_drops(entries: Array) -> Variant:
	var result: Array[Dictionary] = []
	for value in entries:
		if not value is Dictionary:
			return null
		var item_id := str(value.get("item_id", ""))
		item_id = str(LEGACY_ITEM_REPLACEMENTS.get(item_id, item_id))
		var position: Variant = _normalize_position(value.get("position", []), null, true)
		var count := int(value.get("count", 0))
		if item_id == "quest_item_1":
			continue
		if not KNOWN_ITEM_IDS.has(item_id) or position == null or count <= 0:
			return null
		result.append({
			"position": position,
			"item_id": item_id,
			"count": clampi(count, 1, int(KNOWN_ITEM_IDS[item_id])),
			"pickup_delay_msec": clampi(int(value.get("pickup_delay_msec", 0)), 0, 3000),
		})
	return result

func _normalize_entities(map_id: StringName, entries: Array) -> Variant:
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for value in entries:
		if not value is Dictionary:
			return null
		var kind := str(value.get("kind", ""))
		if kind != "pursuing_plant" \
		and kind != "orange_cactus" \
		and kind != "saxaul_boss":
			return null
		if (kind == "orange_cactus" or kind == "saxaul_boss") \
		and map_id != &"sunset_shore":
			return null
		var entity_id := str(value.get("entity_id", ""))
		var cell: Variant = _normalize_cell(value.get("cell", []))
		var position: Variant = _normalize_position(value.get("position", []), null, true)
		if entity_id.is_empty() or seen_ids.has(entity_id) or cell == null or position == null:
			return null
		seen_ids[entity_id] = true
		if kind == "pursuing_plant":
			result.append({
				"kind": kind,
				"mutated": bool(value.get("mutated", false)),
				"entity_id": entity_id,
				"cell": cell,
				"position": position,
				"health": clampi(int(value.get("health", 3)), 1, 3),
				"age": clampf(float(value.get("age", 0.0)), 0.0, 3.0),
				"mature": bool(value.get("mature", false)),
				"jump_cooldown_remaining": clampf(float(value.get("jump_cooldown_remaining", 0.0)), 0.0, 1.1),
				"spawn_grace_remaining": clampf(float(value.get("spawn_grace_remaining", 0.0)), 0.0, MeadowPursuingPlant.SPAWN_GRACE_DURATION),
			})
		elif kind == "orange_cactus":
			var facing: Variant = _normalize_direction(value.get("facing", []))
			var wander_direction: Variant = _normalize_optional_direction(value.get("wander_direction", []))
			if facing == null or wander_direction == null:
				return null
			result.append({
				"kind": kind,
				"entity_id": entity_id,
				"cell": cell,
				"position": position,
				"health": clampi(int(value.get("health", 5)), 1, 5),
				"age": clampf(float(value.get("age", 0.0)), 0.0, 3.0),
				"mature": bool(value.get("mature", false)),
				"wander_timer": clampf(float(value.get("wander_timer", 0.0)), 0.0, 2.4),
				"volley_timer": clampf(float(value.get("volley_timer", 0.0)), 0.0, 1.6),
				"facing": facing,
				"wander_direction": wander_direction,
				"spawn_grace_remaining": clampf(float(value.get("spawn_grace_remaining", 0.0)), 0.0, MeadowOrangeCactus.SPAWN_GRACE_DURATION),
			})
		else:
			var skill_direction: Variant = _normalize_direction(
				value.get("skill_target_direction", [])
			)
			var vine_value: Variant = value.get("small_vine_origins", [])
			if skill_direction == null \
			or not vine_value is Array \
			or vine_value.size() > 2:
				return null
			var vine_origins: Array[Array] = []
			for origin_value in vine_value:
				var vine_origin: Variant = _normalize_position(
					origin_value,
					null,
					true
				)
				if vine_origin == null:
					return null
				vine_origins.append(vine_origin)
			var dead := bool(value.get("dead", false))
			var health := clampi(
				int(value.get("health", MeadowSaxaulBoss.MAX_HEALTH)),
				0 if dead else 1,
				MeadowSaxaulBoss.MAX_HEALTH
			)
			if dead != (health <= 0) \
			or (dead and not bool(value.get("mature", false))) \
			or (dead and map_id != &"sunset_shore"):
				return null
			result.append({
				"kind": kind,
				"entity_id": entity_id,
				"cell": cell,
				"position": position,
				"health": health,
				"age": clampf(float(value.get("age", 0.0)), 0.0, MeadowSaxaulBoss.GROW_TIME),
				"mature": bool(value.get("mature", false)),
				"dead": dead,
				"attacks_done": clampi(int(value.get("attacks_done", 0)), 0, 2),
				"attack_timer": clampf(float(value.get("attack_timer", 0.8)), 0.0, MeadowSaxaulBoss.RING_COOLDOWN),
				"ring_duration_remaining": clampf(float(value.get("ring_duration_remaining", 0.0)), 0.0, MeadowSaxaulBoss.RING_DURATION),
				"ring_pulse_remaining": clampf(float(value.get("ring_pulse_remaining", 0.0)), 0.0, MeadowSaxaulBoss.RING_PULSE_INTERVAL),
				"skill_windup": clampf(float(value.get("skill_windup", 0.0)), 0.0, MeadowSaxaulBoss.SKILL_WINDUP),
				"spawn_grace_remaining": clampf(float(value.get("spawn_grace_remaining", 0.0)), 0.0, MeadowSaxaulBoss.SPAWN_GRACE_DURATION),
				"skill_target_direction": skill_direction,
				"small_vine_origins": vine_origins,
			})
	return result

func _normalize_saxaul_spread(
	map_id: StringName,
	data: Dictionary
) -> Variant:
	if map_id != &"sunset_shore":
		return {} if data.is_empty() else null
	if data.is_empty():
		return {}
	var origin: Variant = _normalize_cell(data.get("origin", []))
	if origin == null:
		return null
	return {
		"origin": origin,
		"elapsed": clampf(
			float(data.get("elapsed", 0.0)),
			0.0,
			0.12
		),
	}

func _normalize_encounter(map_id: StringName, data: Dictionary) -> Variant:
	if map_id != &"greenmeadow":
		return {} if data.is_empty() else null
	if data.is_empty():
		return {}
	var root: Variant = _normalize_optional_cell(data.get("water_root", []))
	var spread_value: Variant = data.get("spread_cells", [])
	if root == null or not spread_value is Array or spread_value.size() > MAX_WATER_GROWTH:
		return null
	var spread: Array[Array] = []
	for value in spread_value:
		var cell: Variant = _normalize_cell(value)
		if cell == null:
			return null
		spread.append(cell)
	var result := {
		"water_root": root,
		"growth_elapsed": clampf(float(data.get("growth_elapsed", 0.0)), 0.0, 2.5),
		"spread_elapsed": clampf(float(data.get("spread_elapsed", 0.0)), 0.0, 0.18),
		"spread_cells": spread,
		"spread_index": clampi(int(data.get("spread_index", 0)), 0, spread.size()),
		"emerge_elapsed": clampf(float(data.get("emerge_elapsed", 0.0)), 0.0, 0.65),
	}
	var monster_value: Variant = data.get("monster", {})
	if not monster_value is Dictionary:
		return null
	if not monster_value.is_empty():
		var monster: Variant = _normalize_monster(monster_value)
		if monster == null:
			return null
		result["monster"] = monster
	return result

func _normalize_monster(data: Dictionary) -> Variant:
	var entity_id := str(data.get("entity_id", ""))
	var position: Variant = _normalize_position(data.get("position", []), null, true)
	var facing: Variant = _normalize_direction(data.get("facing", []))
	if entity_id.is_empty() or position == null or facing == null:
		return null
	var saved_state := str(data.get("state", "chase"))
	if saved_state == "charge_windup":
		saved_state = "rush_windup"
	elif saved_state == "charging":
		saved_state = "rushing"
	var state := saved_state if saved_state in ["emerging", "chase", "attack", "attack_pause", "rush_windup", "rushing", "rush_end", "stunned"] else "chase"
	var faces_left := bool(data.get("faces_left", float(facing[0]) < 0.0))
	return {
		"kind": "lake_monster",
		"entity_id": entity_id,
		"position": position,
		"health": clampi(int(data.get("health", MeadowLakeMonster.MAX_HEALTH)), 1, MeadowLakeMonster.MAX_HEALTH),
		"state": state,
		"stun_remaining": clampf(float(data.get("stun_remaining", 0.0)), 0.0, MeadowLakeMonster.STUN_DURATION) if state == "stunned" else 0.0,
		"state_elapsed": clampf(float(data.get("state_elapsed", 0.0)), 0.0, MeadowLakeMonster.state_elapsed_limit(state)),
		"attacks_done": clampi(int(data.get("attacks_done", 0)), 0, MeadowLakeMonster.ATTACKS_BEFORE_RUSH),
		"rush_should_stun": bool(data.get("rush_should_stun", false)),
		"charge_direction": _normalize_direction(data.get("charge_direction", [1.0, 0.0])) if state == "rushing" else [1.0, 0.0],
		"charge_endpoint": _normalize_position(data.get("charge_endpoint", position), position, true),
		"charge_hit_player": bool(data.get("charge_hit_player", false)),
		"contact_damage_remaining": clampf(float(data.get("contact_damage_remaining", 0.0)), 0.0, MeadowLakeMonster.CONTACT_DAMAGE_COOLDOWN),
		"spawn_grace_remaining": clampf(float(data.get("spawn_grace_remaining", 0.0)), 0.0, MeadowLakeMonster.SPAWN_GRACE_DURATION),
		"facing": facing,
		"faces_left": faces_left,
	}

func _normalize_cell(value: Variant) -> Variant:
	if not value is Array or value.size() != 2:
		return null
	var x := int(value[0])
	var y := int(value[1])
	if x < 0 or y < 0 or x >= 40 or y >= 24:
		return null
	return [x, y]

func _normalize_optional_cell(value: Variant) -> Variant:
	if value is Array and value.size() == 2 and int(value[0]) == -1 and int(value[1]) == -1:
		return [-1, -1]
	return _normalize_cell(value)

func _normalize_position(value: Variant, fallback: Variant, require_playable_bounds: bool) -> Variant:
	if value is Array and value.size() == 2:
		var x := float(value[0])
		var y := float(value[1])
		var minimum_y := 0.0 if require_playable_bounds else -288.0
		if is_finite(x) and is_finite(y) and x >= 0.0 and y >= minimum_y and x < 1280.0 and y < 768.0:
			return [x, y]
	return fallback

func _normalize_direction(value: Variant) -> Variant:
	if not value is Array or value.size() != 2:
		return null
	var direction := Vector2(float(value[0]), float(value[1]))
	if not is_finite(direction.x) or not is_finite(direction.y) or direction.length_squared() < 0.01:
		return null
	direction = direction.normalized()
	return [direction.x, direction.y]

func _normalize_optional_direction(value: Variant) -> Variant:
	if not value is Array or value.size() != 2:
		return null
	var direction := Vector2(float(value[0]), float(value[1]))
	if not is_finite(direction.x) or not is_finite(direction.y):
		return null
	if direction.length_squared() < 0.01:
		return [0.0, 0.0]
	direction = direction.normalized()
	return [direction.x, direction.y]

func _apply_valid_save(data: Dictionary) -> void:
	var global_data: Dictionary = data["global"]
	session_initialized = true
	current_map_id = StringName(str(data["current_map_id"]))
	inventory_state = global_data["inventory"].duplicate(true)
	coins = int(global_data["coins"])
	player_health = int(global_data["player_health"])
	quest_state = int(global_data["quest_state"])
	orange_seed_granted = bool(global_data.get("orange_seed_granted", false))
	green_plantings_since_mutation = int(global_data.get("green_plantings_since_mutation", 0))
	world_tree_blessing_unlocked = bool(global_data.get("world_tree_blessing_unlocked", false))
	defeated_boss_ids.clear()
	for value in global_data.get("defeated_boss_ids", []):
		var boss_id := StringName(str(value))
		if boss_id in KNOWN_BOSS_IDS and boss_id not in defeated_boss_ids:
			defeated_boss_ids.append(boss_id)
	container_energy = clampi(int(global_data.get("container_energy", defeated_boss_ids.size() * 50)), 0, 100)
	sunflower_quest_state = clampi(int(global_data.get("sunflower_quest_state", 0)), 0, 2)
	map_two_return_count = clampi(int(global_data.get("map_two_return_count", 0)), 0, 2)
	pea_npc_state = clampi(int(global_data.get("pea_npc_state", 0)), 0, 2)
	if pea_npc_state == 1:
		pea_npc_transform_elapsed = clampf(float(global_data.get(
			"pea_npc_transform_elapsed",
			PEA_TRANSFORM_DURATION
		)), 0.0, PEA_TRANSFORM_DURATION)
	else:
		pea_npc_transform_elapsed = PEA_TRANSFORM_DURATION if pea_npc_state == 2 else 0.0
	world_tree_redemption_triggered = bool(global_data.get("world_tree_redemption_triggered", false))
	energy = clampi(int(global_data.get("energy", 0)), 0, 100)
	world_tree_energy = clampi(int(global_data.get("world_tree_energy", 0)), 0, 100)
	cactus_kills_since_drop = clampi(int(global_data.get("cactus_kills_since_drop", 0)), 0, 4)
	unlocked_map_ids.clear()
	for value in global_data["unlocked_map_ids"]:
		unlocked_map_ids.append(StringName(str(value)))
	map_states = data["maps"].duplicate(true)

func has_defeated_boss(boss_id: StringName) -> bool:
	return boss_id in defeated_boss_ids

func record_boss_defeat(boss_id: StringName) -> bool:
	if boss_id not in KNOWN_BOSS_IDS or boss_id in defeated_boss_ids:
		return false
	defeated_boss_ids.append(boss_id)
	container_energy = clampi(maxi(container_energy, defeated_boss_ids.size() * 50), 0, 100)
	return true

func get_defeated_boss_count() -> int:
	var count := 0
	for boss_id in KNOWN_BOSS_IDS:
		if boss_id in defeated_boss_ids:
			count += 1
	return count

func _boss_ids_to_strings() -> Array[String]:
	var result: Array[String] = []
	for boss_id in defeated_boss_ids:
		if boss_id in KNOWN_BOSS_IDS and String(boss_id) not in result:
			result.append(String(boss_id))
	return result

func _default_inventory_state() -> Dictionary:
	return {
		"slots": [
			{"id": "melee_weapon", "count": 1},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		],
		"selected_slot": 0,
	}

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
