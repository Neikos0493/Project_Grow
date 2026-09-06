extends RefCounted
## Smoke checks for DTO normalization, map separation, JSON, and disk recovery.

static func run(game_state: Node) -> Array[String]:
	var failures: Array[String] = []
	game_state.save_path = "user://test_map_isolation_autosave.json"
	game_state.temp_path = "user://test_map_isolation_autosave.json.tmp"
	game_state.backup_path = "user://test_map_isolation_autosave.json.bak"
	game_state.delete_save_files()
	game_state.reset_session()
	var green_state := _empty_map_state([100.0, 100.0])
	green_state["farm"] = [{"cell": [3, 3], "state": 1}]
	green_state["used_prop_ids"] = ["greenmeadow.seed_crate"]
	var shore_state := _empty_map_state([200.0, 200.0])
	shore_state["farm"] = [{"cell": [4, 4], "state": 0}]
	_check(game_state.set_map_state(&"greenmeadow", green_state), "Greenmeadow snapshot is accepted", failures)
	_check(game_state.set_map_state(&"sunset_shore", shore_state), "Sunset Shore snapshot is accepted", failures)
	var green_copy: Dictionary = game_state.get_map_state(&"greenmeadow")
	var shore_copy: Dictionary = game_state.get_map_state(&"sunset_shore")
	_check(green_copy.get("farm", []) != shore_copy.get("farm", []), "Map farm snapshots remain independent", failures)
	green_copy["farm"].clear()
	_check(not game_state.get_map_state(&"greenmeadow").get("farm", []).is_empty(), "Returned snapshots are deep copies", failures)
	var payload: Dictionary = game_state._build_save_data()
	var parsed: Variant = JSON.parse_string(JSON.stringify(payload))
	var normalized: Dictionary = game_state._normalize_save(parsed) if parsed is Dictionary else {}
	_check(not normalized.is_empty(), "Valid save survives a JSON round trip", failures)
	if not normalized.is_empty():
		_check(is_zero_approx(float(normalized["global"].get("pea_npc_transform_elapsed", -1.0))), "Default pea transformation progress survives normalization", failures)
	var transforming_payload := payload.duplicate(true)
	transforming_payload["global"]["pea_npc_state"] = 1
	transforming_payload["global"]["pea_npc_transform_elapsed"] = 0.64
	var normalized_transforming: Dictionary = game_state._normalize_save(transforming_payload)
	_check(not normalized_transforming.is_empty(), "In-progress pea transformation save is accepted", failures)
	if not normalized_transforming.is_empty():
		_check(is_equal_approx(float(normalized_transforming["global"].get("pea_npc_transform_elapsed", 0.0)), 0.64), "Pea transformation progress survives normalization", failures)
	var legacy_transforming_payload := payload.duplicate(true)
	legacy_transforming_payload["global"]["pea_npc_state"] = 1
	legacy_transforming_payload["global"].erase("pea_npc_transform_elapsed")
	var normalized_legacy_transforming: Dictionary = game_state._normalize_save(legacy_transforming_payload)
	_check(not normalized_legacy_transforming.is_empty(), "Legacy pea transformation save is accepted", failures)
	if not normalized_legacy_transforming.is_empty():
		_check(is_equal_approx(float(normalized_legacy_transforming["global"].get("pea_npc_transform_elapsed", 0.0)), MeadowWorld.WORM_TRANSFORM_DURATION), "Legacy transformed pea defaults to its final frame", failures)
	var inconsistent_idle_payload := payload.duplicate(true)
	inconsistent_idle_payload["global"]["pea_npc_state"] = 0
	inconsistent_idle_payload["global"]["pea_npc_transform_elapsed"] = 0.64
	var normalized_idle: Dictionary = game_state._normalize_save(inconsistent_idle_payload)
	_check(not normalized_idle.is_empty(), "Idle pea state with stale progress is accepted", failures)
	if not normalized_idle.is_empty():
		_check(is_zero_approx(float(normalized_idle["global"].get("pea_npc_transform_elapsed", -1.0))), "Idle pea state clears stale transformation progress", failures)
	var inconsistent_complete_payload := payload.duplicate(true)
	inconsistent_complete_payload["global"]["pea_npc_state"] = 2
	inconsistent_complete_payload["global"]["pea_npc_transform_elapsed"] = 0.0
	var normalized_complete: Dictionary = game_state._normalize_save(inconsistent_complete_payload)
	_check(not normalized_complete.is_empty(), "Completed pea state with stale progress is accepted", failures)
	if not normalized_complete.is_empty():
		_check(is_equal_approx(float(normalized_complete["global"].get("pea_npc_transform_elapsed", 0.0)), MeadowWorld.WORM_TRANSFORM_DURATION), "Completed pea state is pinned to the final frame", failures)
	var legacy_weapon_payload := payload.duplicate(true)
	legacy_weapon_payload["global"]["inventory"]["slots"][0] = {
		"id": "yellow_ball",
		"count": 1,
	}
	legacy_weapon_payload["maps"]["greenmeadow"]["drops"] = [{
		"position": [144.0, 144.0],
		"item_id": "yellow_ball",
		"count": 1,
		"pickup_delay_msec": 0,
	}]
	var normalized_legacy_weapon: Dictionary = game_state._normalize_save(
		legacy_weapon_payload
	)
	_check(not normalized_legacy_weapon.is_empty(), "Legacy yellow-ball save is accepted", failures)
	if not normalized_legacy_weapon.is_empty():
		_check(str(normalized_legacy_weapon["global"]["inventory"]["slots"][0].get("id", "")) == "bow", "Legacy inventory weapon migrates to the bow", failures)
		_check(str(normalized_legacy_weapon["maps"]["greenmeadow"]["drops"][0].get("item_id", "")) == "bow", "Legacy dropped weapon migrates to the bow", failures)
	var legacy_task_item_payload := payload.duplicate(true)
	legacy_task_item_payload["global"]["inventory"]["slots"][0] = {
		"id": "quest_item_1",
		"count": 1,
	}
	legacy_task_item_payload["maps"]["greenmeadow"]["drops"] = [{
		"position": [144.0, 144.0],
		"item_id": "quest_item_1",
		"count": 1,
		"pickup_delay_msec": 0,
	}]
	var normalized_legacy_task_item: Dictionary = game_state._normalize_save(
		legacy_task_item_payload
	)
	_check(
		not normalized_legacy_task_item.is_empty(),
		"Legacy boss-task-item save is accepted",
		failures
	)
	if not normalized_legacy_task_item.is_empty():
		_check(
			str(normalized_legacy_task_item["global"]["inventory"]["slots"][0].get("id", "")).is_empty(),
			"Legacy boss task item is removed from inventory",
			failures
		)
		_check(
			normalized_legacy_task_item["maps"]["greenmeadow"]["drops"].is_empty(),
			"Legacy boss task item is removed from ground drops",
			failures
		)
	var invalid: Dictionary = payload.duplicate(true)
	invalid["current_map_id"] = "res://MainPond.tscn"
	_check(game_state._normalize_save(invalid).is_empty(), "Scene paths cannot be injected as map IDs", failures)
	invalid = payload.duplicate(true)
	invalid["global"]["inventory"]["slots"][0] = {"id": "unknown_item", "count": 1}
	_check(game_state._normalize_save(invalid).is_empty(), "Unknown inventory items invalidate a save", failures)
	_test_item_normalization(game_state, payload, failures)
	_test_collection_limits(game_state, payload, failures)
	_check(game_state.save_game(), "Validated autosave writes to disk", failures)
	game_state.coins = 1234
	_check(game_state.save_game(), "Second autosave creates a backup", failures)
	_test_corrupt_primary_rotation(game_state, failures)
	var corrupt := FileAccess.open(game_state.save_path, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("{broken json")
		corrupt.close()
	game_state.reset_session()
	_check(game_state.load_game(), "Invalid primary autosave recovers from backup", failures)
	_check(game_state.last_load_used_backup, "Backup recovery is reported", failures)
	_check(FileAccess.file_exists(game_state.save_path), "Backup recovery recreates the primary autosave", failures)
	game_state.delete_save_files()
	game_state.save_path = "user://autosave.json"
	game_state.temp_path = "user://autosave.json.tmp"
	game_state.backup_path = "user://autosave.json.bak"
	game_state.reset_session()
	return failures

static func _test_item_normalization(game_state: Node, payload: Dictionary, failures: Array[String]) -> void:
	var item_ids: Array[String] = ["pea_drop", "mutated_pea_drop", "cactus_drop", "saxaul_seed", "lily_seed", "plant", "blue_seed", "bean_seed", "sunglasses"]
	var stack_limits: Dictionary = {
		"pea_drop": 64,
		"mutated_pea_drop": 64,
		"cactus_drop": 64,
		"saxaul_seed": 1,
		"lily_seed": 1,
		"plant": 64,
		"blue_seed": 1,
		"bean_seed": 64,
		"sunglasses": 1,
	}
	for item_id in item_ids:
		var inventory_payload := payload.duplicate(true)
		inventory_payload["global"]["inventory"]["slots"][0] = {"id": item_id, "count": 65}
		var normalized_inventory: Dictionary = game_state._normalize_save(inventory_payload)
		_check(not normalized_inventory.is_empty(), "Inventory accepts known item ID %s" % item_id, failures)
		if not normalized_inventory.is_empty():
			var slot: Dictionary = normalized_inventory["global"]["inventory"]["slots"][0]
			_check(str(slot.get("id", "")) == item_id, "Inventory retains item ID %s" % item_id, failures)
			_check(int(slot.get("count", 0)) == int(stack_limits[item_id]), "Inventory clamps %s stacks to %d" % [item_id, int(stack_limits[item_id])], failures)
		var drop_payload := payload.duplicate(true)
		drop_payload["maps"]["greenmeadow"]["drops"] = [{
			"position": [144.0, 144.0],
			"item_id": item_id,
			"count": 65,
			"pickup_delay_msec": 4500,
		}]
		var normalized_drop: Dictionary = game_state._normalize_save(drop_payload)
		_check(not normalized_drop.is_empty(), "Drop DTO accepts known item ID %s" % item_id, failures)
		if not normalized_drop.is_empty():
			var drop: Dictionary = normalized_drop["maps"]["greenmeadow"]["drops"][0]
			_check(str(drop.get("item_id", "")) == item_id, "Drop DTO retains item ID %s" % item_id, failures)
			_check(int(drop.get("count", 0)) == int(stack_limits[item_id]), "Drop DTO clamps %s stacks to %d" % [item_id, int(stack_limits[item_id])], failures)
			_check(int(drop.get("pickup_delay_msec", -1)) == 3000, "Drop DTO clamps %s pickup delay to 3000 ms" % item_id, failures)
	var negative_delay_payload := payload.duplicate(true)
	negative_delay_payload["maps"]["greenmeadow"]["drops"] = [{
		"position": [144.0, 144.0],
		"item_id": "pea_drop",
		"count": 1,
		"pickup_delay_msec": -1,
	}]
	var normalized_negative_delay: Dictionary = game_state._normalize_save(negative_delay_payload)
	_check(not normalized_negative_delay.is_empty(), "A negative pickup delay is normalized", failures)
	if not normalized_negative_delay.is_empty():
		_check(int(normalized_negative_delay["maps"]["greenmeadow"]["drops"][0].get("pickup_delay_msec", -1)) == 0, "Drop DTO clamps negative pickup delay to zero", failures)
	var unknown_drop_payload := payload.duplicate(true)
	unknown_drop_payload["maps"]["greenmeadow"]["drops"] = [{
		"position": [144.0, 144.0],
		"item_id": "unknown_item",
		"count": 1,
		"pickup_delay_msec": 0,
	}]
	_check(game_state._normalize_save(unknown_drop_payload).is_empty(), "Unknown drop item IDs invalidate a save", failures)

static func _test_corrupt_primary_rotation(game_state: Node, failures: Array[String]) -> void:
	var backup_before: Dictionary = game_state._read_valid_save(
		game_state.backup_path
	)
	_check(not backup_before.is_empty(), "Corrupt-primary regression starts with a valid backup", failures)
	var corrupt := FileAccess.open(game_state.save_path, FileAccess.WRITE)
	_check(corrupt != null, "Corrupt-primary regression can overwrite the primary save", failures)
	if corrupt != null:
		corrupt.store_string("{broken json")
		corrupt.close()
	game_state.coins = 4321
	_check(game_state.save_game(), "Saving with a corrupt primary still installs a valid primary", failures)
	var primary_after: Dictionary = game_state._read_valid_save(
		game_state.save_path
	)
	var backup_after: Dictionary = game_state._read_valid_save(
		game_state.backup_path
	)
	_check(not primary_after.is_empty(), "Saving over a corrupt primary produces a valid primary save", failures)
	if not primary_after.is_empty():
		_check(int(primary_after["global"].get("coins", -1)) == 4321, "New primary contains the latest state", failures)
	_check(not backup_after.is_empty(), "Saving over a corrupt primary preserves a valid backup", failures)
	if not backup_before.is_empty() and not backup_after.is_empty():
		_check(int(backup_after["global"].get("coins", -1)) == int(backup_before["global"].get("coins", -2)), "Corrupt primary is not rotated over the valid backup", failures)

static func _test_collection_limits(game_state: Node, payload: Dictionary, failures: Array[String]) -> void:
	var drops: Array[Dictionary] = []
	for index in range(MeadowWorld.MAX_DROPS):
		drops.append({
			"position": [16.0 + float(index % 39) * 32.0, 16.0 + float(index / 39) * 32.0],
			"item_id": "plant",
			"count": 1,
			"pickup_delay_msec": 0,
		})
	var drop_payload := payload.duplicate(true)
	drop_payload["maps"]["greenmeadow"]["drops"] = drops
	var normalized_drops: Dictionary = game_state._normalize_save(drop_payload)
	_check(not normalized_drops.is_empty(), "A save with exactly 256 drops is accepted", failures)
	if not normalized_drops.is_empty():
		_check(normalized_drops["maps"]["greenmeadow"]["drops"].size() == MeadowWorld.MAX_DROPS, "Accepted drop DTO retains all 256 drops", failures)
	drop_payload["maps"]["greenmeadow"]["drops"].append(drops[0].duplicate(true))
	_check(game_state._normalize_save(drop_payload).is_empty(), "A save with 257 drops is rejected", failures)
	var entities: Array[Dictionary] = []
	for index in range(MeadowWorld.MAX_PERSISTED_PLANTS):
		entities.append({
			"kind": "pursuing_plant",
			"mutated": index % 2 == 0,
			"entity_id": "greenmeadow:plant:%d" % [index + 1],
			"cell": [index % 40, int(index / 40)],
			"position": [16.0 + float(index % 39) * 32.0, 16.0 + float(index / 39) * 32.0],
			"health": 3,
			"age": 1.0,
			"mature": false,
			"jump_cooldown_remaining": 0.0,
			"spawn_grace_remaining": 0.4,
		})
	var entity_payload := payload.duplicate(true)
	entity_payload["maps"]["greenmeadow"]["entities"] = entities
	var normalized_entities: Dictionary = game_state._normalize_save(entity_payload)
	_check(not normalized_entities.is_empty(), "A save with exactly 256 uniquely identified plants is accepted", failures)
	if not normalized_entities.is_empty():
		var accepted_entities: Array = normalized_entities["maps"]["greenmeadow"]["entities"]
		_check(accepted_entities.size() == MeadowWorld.MAX_PERSISTED_PLANTS, "Accepted entity DTO retains all 256 uniquely identified plants", failures)
		_check(bool(accepted_entities[0].get("mutated", false)) and not bool(accepted_entities[1].get("mutated", true)), "Plant mutation identity survives DTO normalization", failures)
		_check(is_equal_approx(float(accepted_entities[0].get("spawn_grace_remaining", 0.0)), 0.4), "Plant spawn grace survives DTO normalization", failures)
	var duplicate_payload := entity_payload.duplicate(true)
	duplicate_payload["maps"]["greenmeadow"]["entities"][1]["entity_id"] = duplicate_payload["maps"]["greenmeadow"]["entities"][0]["entity_id"]
	_check(game_state._normalize_save(duplicate_payload).is_empty(), "Duplicate ordinary-plant entity IDs are rejected", failures)
	var extra_entity: Dictionary = entities[0].duplicate(true)
	extra_entity["entity_id"] = "greenmeadow:plant:257"
	entity_payload["maps"]["greenmeadow"]["entities"].append(extra_entity)
	_check(game_state._normalize_save(entity_payload).is_empty(), "A save with 257 plants is rejected", failures)
	var grace_clamp_payload := payload.duplicate(true)
	grace_clamp_payload["maps"]["greenmeadow"]["entities"] = [entities[0].duplicate(true)]
	grace_clamp_payload["maps"]["greenmeadow"]["entities"][0]["spawn_grace_remaining"] = 4.0
	var normalized_grace_clamp: Dictionary = game_state._normalize_save(grace_clamp_payload)
	_check(not normalized_grace_clamp.is_empty(), "An oversized spawn grace value is normalized", failures)
	if not normalized_grace_clamp.is_empty():
		var clamped_entity: Dictionary = normalized_grace_clamp["maps"]["greenmeadow"]["entities"][0]
		_check(is_equal_approx(float(clamped_entity.get("spawn_grace_remaining", 0.0)), 1.0), "Spawn grace is clamped to one second", failures)
	var saxaul_payload := payload.duplicate(true)
	saxaul_payload["maps"]["sunset_shore"]["entities"] = [_saxaul_state(false)]
	var normalized_saxaul: Dictionary = game_state._normalize_save(saxaul_payload)
	_check(not normalized_saxaul.is_empty(), "A growing Sunset Shore saxaul DTO is accepted", failures)
	if not normalized_saxaul.is_empty():
		var saxaul: Dictionary = normalized_saxaul["maps"]["sunset_shore"]["entities"][0]
		_check(str(saxaul.get("kind", "")) == "saxaul_boss", "Saxaul boss identity survives DTO normalization", failures)
		_check(is_equal_approx(float(saxaul.get("spawn_grace_remaining", 0.0)), 0.4), "Saxaul spawn grace survives DTO normalization", failures)
		_check(int(saxaul.get("health", 0)) == MeadowSaxaulBoss.MAX_HEALTH, "Saxaul boss health survives DTO normalization", failures)
	var dead_saxaul_payload := payload.duplicate(true)
	dead_saxaul_payload["maps"]["sunset_shore"]["entities"] = [_saxaul_state(true)]
	dead_saxaul_payload["maps"]["sunset_shore"]["saxaul_spread"] = {"origin": [12, 12], "elapsed": 0.06}
	_check(not game_state._normalize_save(dead_saxaul_payload).is_empty(), "A dead saxaul spread DTO is accepted", failures)
	var duplicate_saxaul_payload := saxaul_payload.duplicate(true)
	duplicate_saxaul_payload["maps"]["sunset_shore"]["entities"].append(_saxaul_state(false, "sunset_shore:saxaul_boss:2"))
	_check(game_state._normalize_save(duplicate_saxaul_payload).is_empty(), "Duplicate saxaul bosses are rejected", failures)
	var green_saxaul_payload := payload.duplicate(true)
	green_saxaul_payload["maps"]["greenmeadow"]["entities"] = [_saxaul_state(false, "greenmeadow:saxaul_boss:1")]
	_check(game_state._normalize_save(green_saxaul_payload).is_empty(), "Greenmeadow rejects saxaul bosses", failures)
	var cactus_payload := payload.duplicate(true)
	cactus_payload["maps"]["sunset_shore"]["entities"] = [_orange_cactus_state()]
	var normalized_cactus: Dictionary = game_state._normalize_save(cactus_payload)
	_check(not normalized_cactus.is_empty(), "A Sunset Shore orange cactus DTO is accepted", failures)
	if not normalized_cactus.is_empty():
		_check(str(normalized_cactus["maps"]["sunset_shore"]["entities"][0].get("kind", "")) == "orange_cactus", "Orange cactus identity survives DTO normalization", failures)
		_check(is_equal_approx(float(normalized_cactus["maps"]["sunset_shore"]["entities"][0].get("spawn_grace_remaining", 0.0)), 0.4), "Orange cactus spawn grace survives DTO normalization", failures)
	var wrong_map_cactus := payload.duplicate(true)
	wrong_map_cactus["maps"]["greenmeadow"]["entities"] = [_orange_cactus_state()]
	_check(game_state._normalize_save(wrong_map_cactus).is_empty(), "Greenmeadow rejects Sunset Shore cactus entities", failures)
	var monster_payload := payload.duplicate(true)
	monster_payload["maps"]["greenmeadow"]["encounter"] = {
		"water_root": [28, 4],
		"spread_cells": [],
		"monster": {
			"kind": "lake_monster",
			"entity_id": "greenmeadow:lake_monster:12",
			"position": [912.0, 144.0],
			"health": MeadowLakeMonster.MAX_HEALTH,
			"state": "stunned",
			"stun_remaining": MeadowLakeMonster.STUN_DURATION,
			"state_elapsed": 0.0,
			"attacks_done": 1,
			"rush_should_stun": true,
			"contact_damage_remaining": 0.25,
			"spawn_grace_remaining": 0.4,
			"facing": [0.0, 1.0],
			"faces_left": false,
		},
	}
	var normalized_monster: Dictionary = game_state._normalize_save(monster_payload)
	_check(not normalized_monster.is_empty(), "A full-health stunned lake monster DTO is accepted", failures)
	if not normalized_monster.is_empty():
		var monster: Dictionary = normalized_monster["maps"]["greenmeadow"]["encounter"]["monster"]
		_check(int(monster.get("health", 0)) == MeadowLakeMonster.MAX_HEALTH, "Lake monster health 12 survives DTO normalization", failures)
		_check(is_equal_approx(float(monster.get("stun_remaining", 0.0)), MeadowLakeMonster.STUN_DURATION), "Lake monster stun duration survives DTO normalization", failures)
		_check(is_equal_approx(float(monster.get("state_elapsed", -1.0)), 0.0), "Lake monster state elapsed survives DTO normalization", failures)
		_check(is_equal_approx(float(monster.get("spawn_grace_remaining", 0.0)), 0.4), "Lake monster spawn grace survives DTO normalization", failures)
		_check(int(monster.get("attacks_done", 0)) == 1, "Lake monster attack count survives DTO normalization", failures)
		_check(bool(monster.get("rush_should_stun", false)), "Lake monster rush stun flag survives DTO normalization", failures)
		_check(is_equal_approx(float(monster.get("contact_damage_remaining", 0.0)), 0.25), "Lake monster contact cooldown survives DTO normalization", failures)
		_check(not bool(monster.get("faces_left", true)), "Lake monster facing mirror survives DTO normalization", failures)
	var sky_payload := payload.duplicate(true)
	sky_payload["global"]["world_tree_redemption_triggered"] = true
	sky_payload["maps"]["greenmeadow"]["entities"] = [_sky_boss_state()]
	var normalized_sky: Dictionary = game_state._normalize_save(sky_payload)
	_check(not normalized_sky.is_empty(), "An in-progress final Boss DTO is accepted", failures)
	if not normalized_sky.is_empty():
		var sky: Dictionary = normalized_sky["maps"]["greenmeadow"]["entities"][0]
		_check(str(sky.get("kind", "")) == "sky_boss", "Final Boss identity survives DTO normalization", failures)
		_check(int(sky.get("health", 0)) == MeadowFinalBoss.MAX_HEALTH - 10, "Final Boss health survives DTO normalization", failures)
	var sky_wrong_map := payload.duplicate(true)
	sky_wrong_map["maps"]["sunset_shore"]["entities"] = [_sky_boss_state()]
	_check(game_state._normalize_save(sky_wrong_map).is_empty(), "Final Boss DTO is rejected on Sunset Shore", failures)
	var sky_bad_cell := sky_payload.duplicate(true)
	sky_bad_cell["maps"]["greenmeadow"]["entities"][0]["cell"] = [19, 7]
	_check(game_state._normalize_save(sky_bad_cell).is_empty(), "Final Boss DTO rejects an invalid landing cell", failures)
	var sky_duplicate := sky_payload.duplicate(true)
	sky_duplicate["maps"]["greenmeadow"]["entities"].append(_sky_boss_state("greenmeadow:sky_boss:2"))
	_check(game_state._normalize_save(sky_duplicate).is_empty(), "Duplicate final Boss DTOs are rejected", failures)

static func _sky_boss_state(id: String = "greenmeadow:sky_boss:1") -> Dictionary:
	return {
		"kind": "sky_boss",
		"entity_id": id,
		"cell": [20, 7],
		"position": [656.0, 240.0],
		"health": MeadowFinalBoss.MAX_HEALTH - 10,
		"active": true,
		"fall_grace_remaining": 0.0,
		"attack_elapsed": 0.3,
		"rotation_angle": 1.2,
		"current_phase": 1,
		"phase_two_summoned": false,
		"phase_three_summoned": false,
		"contact_remaining": 0.0,
	}

static func _saxaul_state(dead: bool, id: String = "sunset_shore:saxaul_boss:1") -> Dictionary:
	return {
		"kind": "saxaul_boss",
		"entity_id": id,
		"cell": [12, 12],
		"position": [400.0, 400.0],
		"health": 0 if dead else MeadowSaxaulBoss.MAX_HEALTH,
		"age": MeadowSaxaulBoss.GROW_TIME if dead else 1.5,
		"mature": dead,
		"dead": dead,
		"attacks_done": 1,
		"attack_timer": 0.4,
		"ring_duration_remaining": 0.0,
		"ring_pulse_remaining": 0.0,
		"skill_windup": 0.0,
		"spawn_grace_remaining": 0.4,
		"skill_target_direction": [1.0, 0.0],
		"small_vine_origins": [],
	}

static func _orange_cactus_state() -> Dictionary:
	return {
		"kind": "orange_cactus",
		"entity_id": "sunset_shore:orange_cactus:1",
		"cell": [4, 4],
		"position": [144.0, 144.0],
		"health": 5,
		"age": 1.0,
		"mature": false,
		"wander_timer": 1.0,
		"volley_timer": 0.5,
		"facing": [1.0, 0.0],
		"wander_direction": [0.0, 0.0],
		"spawn_grace_remaining": 0.4,
	}

static func _empty_map_state(position: Array[float]) -> Dictionary:
	return {
		"snapshot_version": 1,
		"farm": [],
		"water_growth": [],
		"used_prop_ids": [],
		"drops": [],
		"entities": [],
		"encounter": {},
		"last_player_position": position,
		"next_entity_serial": 1,
	}

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
