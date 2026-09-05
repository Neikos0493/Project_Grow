extends SceneTree
## Exercises travel transactions, local-space persistence, capacity, and save failures.

func _initialize() -> void:
	var game_state := root.get_node_or_null("GameState")
	if not _expect(game_state != null, "GameState autoload is unavailable"):
		return
	game_state.save_path = "user://test_travel_autosave.json"
	game_state.temp_path = "user://test_travel_autosave.json.tmp"
	game_state.backup_path = "user://test_travel_autosave.json.bak"
	game_state.delete_save_files()
	game_state.reset_session()
	await process_frame
	var packed := load("res://Main.tscn") as PackedScene
	var main := packed.instantiate() as MeadowMain
	root.add_child(main)
	await process_frame
	await process_frame
	if not _expect(main.world.get_map_id() == &"greenmeadow", "Gameplay did not start in Greenmeadow"):
		return
	if not _expect(game_state == root.get_node("GameState"), "Travel test did not use the GameState autoload"):
		return
	main.world.till(Vector2i(3, 3))
	main.player.restore_state(3)
	var source_plant := main._create_pursuing_plant(Vector2i(6, 6))
	if not _expect(source_plant != null, "Could not create the source-map travel probe"):
		return
	source_plant.age = 0.25
	var source_plant_entity_id := source_plant.entity_id
	main.quest_state = main.QUEST_WATER_GROWING
	main.water_growth_elapsed = 0.5
	var source_age := source_plant.age
	var source_growth_elapsed := main.water_growth_elapsed
	var probes := {
		"source_seen": false,
		"source_frozen": false,
		"destination_seen": false,
		"destination_suspended": false,
		"destination_at_disembark_start": false,
		"destination_end_persisted": false,
	}
	var source_timer := create_timer(0.15)
	source_timer.timeout.connect(func() -> void:
		probes["source_seen"] = main.traveling and main.world.get_map_id() == &"greenmeadow"
		probes["source_frozen"] = (
			main.map_host.is_runtime_suspended()
			and main.world.process_mode == Node.PROCESS_MODE_DISABLED
			and is_equal_approx(source_plant.age, source_age)
			and is_equal_approx(main.water_growth_elapsed, source_growth_elapsed)
		)
	)
	var destination_timer := create_timer(1.45)
	destination_timer.timeout.connect(func() -> void:
		probes["destination_seen"] = main.traveling and main.world.get_map_id() == &"sunset_shore"
		probes["destination_suspended"] = (
			main.map_host.is_runtime_suspended()
			and main.world.process_mode == Node.PROCESS_MODE_DISABLED
		)
		if probes["destination_seen"]:
			var disembark_start := main.world.get_disembark_start_position()
			probes["destination_at_disembark_start"] = main.world.to_local(main.player.global_position).is_equal_approx(disembark_start)
			var persisted_destination: Dictionary = game_state.get_map_state(&"sunset_shore")
			probes["destination_end_persisted"] = _vector_from_data(
				persisted_destination.get("last_player_position", [])
			).is_equal_approx(main.world.get_disembark_end_position())
	)
	await main._travel_to(&"sunset_shore")
	if not _expect(bool(probes["source_seen"]), "Travel did not remain on the source map during cover"):
		return
	if not _expect(bool(probes["source_frozen"]), "Source runtime or encounter time advanced during cover"):
		return
	if not _expect(bool(probes["destination_seen"]), "Travel did not expose the destination during the arrival phase"):
		return
	if not _expect(bool(probes["destination_suspended"]), "Destination runtime was not suspended during reveal"):
		return
	if not _expect(bool(probes["destination_at_disembark_start"]), "Player was not placed at the destination disembark start before reveal"):
		return
	if not _expect(bool(probes["destination_end_persisted"]), "Crash-safe destination save did not persist the disembark end before reveal"):
		return
	if not _expect(main.world.get_map_id() == &"sunset_shore" and main.map_host.get_child_count() == 1, "Travel did not replace Greenmeadow with one Sunset Shore"):
		return
	if not _expect(main.world.get_shop_node() != null and main.shop == main.world.get_shop_node(), "Sunset Shore did not bind its own beach shop"):
		return
	if not _expect(main.shop_panel.is_shop_product(main.ORANGE_SEED), "Sunset Shore shop did not expose orange seeds"):
		return
	if not _expect(not main.world.farm_tiles.has(Vector2i(3, 3)), "Greenmeadow farm state leaked into Sunset Shore"):
		return
	if not _expect(not main.map_host.is_runtime_suspended() and main.world.process_mode == Node.PROCESS_MODE_INHERIT, "Destination runtime did not resume after arrival"):
		return
	if not _expect(main.world.ship_transition_offset.is_equal_approx(Vector2.ZERO), "Ship arrival offset was not reset before travel returned"):
		return
	if not _expect(not main.traveling and not main.player.controls_locked, "Player controls were not unlocked when travel returned"):
		return
	if not _expect(
		main.world.to_local(main.player.global_position).is_equal_approx(main.world.get_disembark_end_position()),
		"Travel returned before the player reached the destination disembark end"
	):
		return
	if not _expect(_is_ship_adjacent_arrival(main.world), "Sunset Shore arrival is not beside its ship"):
		return
	if not _expect(not main.travel_transition.visible and is_zero_approx(main.travel_transition.overlay_alpha), "Travel returned before the reveal finished"):
		return
	if not _expect(main.player.health == 3, "Player health changed while traveling"):
		return
	var cactus_cell := Vector2i(3, 3)
	if not _expect(main.world.plant_orange_seed(cactus_cell), "Could not reserve Sunset Shore sand for a cactus"):
		return
	var cactus := main._create_orange_cactus(cactus_cell)
	if not _expect(cactus != null, "Could not create the Sunset Shore cactus persistence probe"):
		return
	cactus.age = 1.25
	var cactus_entity_id := cactus.entity_id
	main.quest_state = main.QUEST_AWAITING_PLANT
	main.world.till(Vector2i(3, 6))
	await main._travel_to(&"greenmeadow")
	if not _expect(main.world.get_map_id() == &"greenmeadow" and main.world.farm_tiles.has(Vector2i(3, 3)), "Greenmeadow farm state was not restored"):
		return
	if not _expect(not main.world.farm_tiles.has(Vector2i(3, 6)), "Sunset Shore farm state leaked into Greenmeadow"):
		return
	if not _expect(main.player.health == 3, "Player health was not preserved across the round trip"):
		return
	if not _expect(
		main.map_host.get_child_count() == 1
		and not main.map_host.is_runtime_suspended()
		and main.world.process_mode == Node.PROCESS_MODE_INHERIT,
		"Greenmeadow runtime did not resume after the return trip"
	):
		return
	if not _expect(main.world.ship_transition_offset.is_equal_approx(Vector2.ZERO), "Return-trip ship offset was not reset"):
		return
	if not _expect(not main.traveling and not main.player.controls_locked, "Player stayed locked after the return trip"):
		return
	if not _expect(
		main.world.to_local(main.player.global_position).is_equal_approx(main.world.get_disembark_end_position()),
		"Return travel completed before the player reached the disembark end"
	):
		return
	if not _expect(_is_ship_adjacent_arrival(main.world), "Greenmeadow arrival is not beside its ship"):
		return
	var restored_source_plant: MeadowPursuingPlant
	for child in main.plants.get_children():
		if child is MeadowPursuingPlant and child.entity_id == source_plant_entity_id:
			restored_source_plant = child
			break
	if not _expect(restored_source_plant != null, "Greenmeadow source plant was not restored before the pause check"):
		return
	var paused_age := restored_source_plant.age
	main._set_paused(true)
	await create_timer(0.12).timeout
	if not _expect(is_equal_approx(restored_source_plant.age, paused_age), "Pause menu did not freeze active-map entities"):
		return
	main._set_paused(false)
	await main._travel_to(&"sunset_shore")
	var restored_cactus: MeadowOrangeCactus
	for child in main.plants.get_children():
		if child is MeadowOrangeCactus and child.entity_id == cactus_entity_id:
			restored_cactus = child
			break
	if not _expect(restored_cactus != null, "Sunset Shore cactus was not restored after map travel"):
		return
	if not _expect(is_equal_approx(restored_cactus.age, 1.25), "Sunset Shore cactus growth state did not survive map travel"):
		return
	if not _expect(main.world.farm_tiles.has(cactus_cell), "Sunset Shore cactus farm cell did not survive map travel"):
		return
	restored_cactus.age = MeadowOrangeCactus.GROW_TIME
	restored_cactus.mature = true
	restored_cactus.matured.emit(cactus_cell)
	if not _expect(not main.world.farm_tiles.has(cactus_cell), "A mature Sunset Shore cactus did not release its sand farm record"):
		return
	await main._travel_to(&"greenmeadow")
	_clear_runtime_entities(main)
	if not _test_typed_plant_deaths(main):
		return
	if not _test_mutated_restore_and_ring(main):
		return
	if not _test_inventory_exchanges(main):
		return
	if not _test_lake_seed_transactions(main):
		return
	if not _test_cross_map_death_reset(main, game_state):
		return
	if not await _test_transformed_map_coordinates(main):
		return
	if not _test_capacity_transactions(main):
		return
	if not _test_quest_relic_fallbacks(main):
		return
	if not _test_save_failure_backoff(main, game_state):
		return
	game_state.save_path = "user://test_travel_autosave.json"
	game_state.temp_path = "user://test_travel_autosave.json.tmp"
	game_state.backup_path = "user://test_travel_autosave.json.bak"
	game_state.delete_save_files()
	main.queue_free()
	await process_frame
	print("PASS: travel, map-local state, capacity, and save-failure regressions")
	quit(0)

func _is_ship_adjacent_arrival(map: MeadowWorld) -> bool:
	var ship_cell := map.get_ship_cell()
	var arrival_cell := map.world_to_cell(map.get_disembark_end_position())
	return arrival_cell != ship_cell \
		and maxi(abs(arrival_cell.x - ship_cell.x), abs(arrival_cell.y - ship_cell.y)) <= 1 \
		and map.is_position_walkable(map.get_disembark_end_position())

func _test_typed_plant_deaths(main: MeadowMain) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
	var cases: Array[Dictionary] = [
		{"kind": "ordinary", "cell": Vector2i(4, 4), "drop": main.PEA_DROP},
		{"kind": "mutated", "cell": Vector2i(5, 4), "drop": main.MUTATED_PEA_DROP},
	]
	for death_case in cases:
		var cell: Vector2i = death_case["cell"]
		var state := {"mutated": death_case["kind"] == "mutated"}
		var plant := main._create_pursuing_plant(cell, state)
		if not _expect(plant != null, "Could not create the %s death-drop probe" % death_case["kind"]):
			return false
		plant.mature = true
		plant.age = MeadowPursuingPlant.GROW_TIME
		var drops_before := main.world.drops.size()
		if not _expect(plant.take_damage(MeadowPursuingPlant.MAX_HEALTH), "%s plant did not accept lethal damage" % death_case["kind"]):
			return false
		if not _expect(main.world.drops.size() == drops_before + 1, "%s plant death did not add exactly one drop" % death_case["kind"]):
			return false
		var drop: Dictionary = main.world.drops.back()
		if not _expect(str(drop.get("item_id", "")) == str(death_case["drop"]) and int(drop.get("count", 0)) == 1, "%s plant death produced the wrong typed drop" % death_case["kind"]):
			return false
		if not _expect(_drop_is_immediately_available(drop), "%s plant death did not apply the approximately 3000ms pickup delay" % death_case["kind"]):
			return false
	main.world.restore_state({})
	_clear_runtime_entities(main)
	main.map_host.set_runtime_suspended(false)
	return true

func _test_mutated_restore_and_ring(main: MeadowMain) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
	var cell := Vector2i(7, 7)
	var state := {
		"kind": "pursuing_plant",
		"mutated": true,
		"entity_id": "greenmeadow:plant:mutated-restore",
		"cell": [cell.x, cell.y],
		"position": [main.world.cell_to_world(cell).x, main.world.cell_to_world(cell).y],
		"health": 2,
		"age": MeadowPursuingPlant.GROW_TIME,
		"mature": true,
		"jump_cooldown_remaining": 0.4,
	}
	var plant := main._create_pursuing_plant(cell, state)
	if not _expect(plant is MeadowMutatedPlant, "A persisted mutated pursuing plant was not restored as its subclass"):
		return false
	var captured := plant.capture_state()
	if not _expect(bool(captured.get("mutated", false)), "Restored mutated subclass did not preserve its mutation marker"):
		return false
	var ring_probe := {
		"calls": 0,
		"origin": Vector2.ZERO,
		"directions": [] as Array[Vector2],
	}
	(plant as MeadowMutatedPlant).projectile_requested.connect(func(origin: Vector2, directions: Array[Vector2]) -> void:
		ring_probe["calls"] = int(ring_probe["calls"]) + 1
		ring_probe["origin"] = origin
		var captured_directions: Array[Vector2] = []
		captured_directions.assign(directions)
		ring_probe["directions"] = captured_directions
	)
	(plant as MeadowMutatedPlant)._emit_ring_projectiles()
	var ring_origin: Vector2 = ring_probe["origin"]
	var ring_directions: Array[Vector2] = ring_probe["directions"]
	if not _expect(int(ring_probe["calls"]) == 1 and ring_origin.is_equal_approx(plant.global_position), "Mutated plant did not emit one projectile ring signal from itself"):
		return false
	if not _expect(ring_directions.size() == MeadowMutatedPlant.RING_PROJECTILE_COUNT and ring_directions.size() == 6, "Mutated projectile ring did not contain six directions"):
		return false
	for index in range(ring_directions.size()):
		var expected := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
		if not _expect(ring_directions[index].is_equal_approx(expected), "Mutated projectile ring directions were not evenly ordered"):
			return false
	_clear_runtime_entities(main)
	main.map_host.set_runtime_suspended(false)
	return true

func _test_inventory_exchanges(main: MeadowMain) -> bool:
	main.inventory.import_state(_inventory_state([
		{"id": "mutated_pea_drop", "count": 1},
		{"id": "hoe", "count": 1},
		{"id": "yellow_ball", "count": 1},
		{"id": "melee_weapon", "count": 1},
		{"id": "green_seed", "count": 64},
	]))
	if not _expect(main.inventory.try_exchange(main.MUTATED_PEA_DROP, main.LILY_SEED), "Atomic exchange rejected a full inventory whose final mutated pea freed a slot"):
		return false
	if not _expect(not main.inventory.has_item(main.MUTATED_PEA_DROP) and main.inventory.has_item(main.LILY_SEED), "Successful mutated-pea exchange did not atomically replace the final pea with a lily seed"):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": "mutated_pea_drop", "count": 2},
		{"id": "hoe", "count": 1},
		{"id": "yellow_ball", "count": 1},
		{"id": "melee_weapon", "count": 1},
		{"id": "green_seed", "count": 64},
	]))
	var before := main.inventory.export_state()
	if not _expect(not main.inventory.try_exchange(main.MUTATED_PEA_DROP, main.LILY_SEED), "Atomic exchange succeeded although removing one stacked pea left the inventory full"):
		return false
	if not _expect(main.inventory.export_state() == before, "Failed stacked mutated-pea exchange did not roll back every slot"):
		return false
	return true

func _test_lake_seed_transactions(main: MeadowMain) -> bool:
	main.map_host.set_runtime_suspended(true)
	_clear_runtime_entities(main)
	for seed_item_id in [main.LILY_SEED, main.BLUE_SEED]:
		main.world.restore_state({})
		main.quest_state = main.QUEST_SEED_GRANTED
		main.inventory.import_state(_inventory_state([
			{"id": seed_item_id, "count": 1},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		]))
		var root := Vector2i(28, 4)
		var player_position := main.world.cell_to_world(Vector2i(27, 4))
		var pointer_position := main.world.cell_to_world(root)
		if not _expect(main._plant_lake_seed(pointer_position, player_position, Vector2.RIGHT, seed_item_id), "%s did not activate pond growth" % seed_item_id):
			return false
		if not _expect(not main.inventory.has_item(seed_item_id), "%s pond activation did not consume the selected seed" % seed_item_id):
			return false
		if not _expect(main.quest_state == main.QUEST_WATER_GROWING and main.water_root == root, "%s pond activation did not begin the encounter" % seed_item_id):
			return false
		if not _expect(main.world.water_growth.size() == 4, "%s pond activation did not reserve its four-cell footprint" % seed_item_id):
			return false
		main.world.restore_state({})
		main.quest_state = main.QUEST_SEED_GRANTED
		main.inventory.import_state(_inventory_state([
			{"id": seed_item_id, "count": 1},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		]))
		# Select a different valid item while explicitly requesting this seed. The
		# world reservation succeeds first, then the inventory guard must undo it.
		main.inventory.slots[1] = {"id": "hoe", "count": 1}
		main.inventory.select_slot(1)
		var rollback_inventory := main.inventory.export_state()
		if not _expect(not main._plant_lake_seed(pointer_position, player_position, Vector2.RIGHT, seed_item_id), "%s selection mismatch did not reject the pond transaction" % seed_item_id):
			return false
		if not _expect(main.inventory.export_state() == rollback_inventory, "%s failed pond transaction changed inventory" % seed_item_id):
			return false
		if not _expect(main.world.water_growth.is_empty(), "%s failed pond transaction did not roll back water growth" % seed_item_id):
			return false
		if not _expect(main.quest_state == main.QUEST_SEED_GRANTED, "%s failed pond transaction advanced the quest" % seed_item_id):
			return false
	main.world.restore_state({})
	main.map_host.set_runtime_suspended(false)
	return true

func _test_cross_map_death_reset(main: MeadowMain, game_state: Node) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	var root := Vector2i(28, 4)
	if not _expect(main.world.plant_blue_seed(root), "Could not build the stored Greenmeadow encounter death probe"):
		return false
	main.quest_state = main.QUEST_WATER_GROWING
	main._begin_water_growth(root)
	main.water_growth_elapsed = 1.25
	var green_snapshot := main._capture_map_state()
	game_state.set_map_state(&"greenmeadow", green_snapshot)
	var preserved_green: Dictionary = game_state.get_map_state(
		&"greenmeadow"
	)
	var preserved_quest: int = main.quest_state
	var shore := main.map_host.activate_map(&"sunset_shore")
	if not _expect(shore != null, "Could not activate Sunset Shore for the cross-map death probe"):
		return false
	main._bind_active_map(shore)
	main.map_host.set_runtime_suspended(true)
	main._restoring = true
	main._restore_map_state(game_state.get_map_state(&"sunset_shore"))
	main._restoring = false
	main.quest_state = preserved_quest
	main.player.restore_state(1)
	main.player.take_damage(1)
	if not _expect(main.quest_state == preserved_quest, "Dying on Sunset Shore changed the global Greenmeadow encounter quest"):
		return false
	if not _expect(game_state.get_map_state(&"greenmeadow") == preserved_green, "Dying on Sunset Shore changed the stored Greenmeadow water or encounter snapshot"):
		return false
	main.player.respawn_at(main.world.to_global(main.world.get_respawn_position()))
	var green := main.map_host.activate_map(&"greenmeadow")
	if not _expect(green != null, "Could not return to Greenmeadow after the cross-map death probe"):
		return false
	main._bind_active_map(green)
	main.map_host.set_runtime_suspended(true)
	main._restoring = true
	main._restore_map_state(game_state.get_map_state(&"greenmeadow"))
	main._restoring = false
	if not _expect(main.world.water_growth == _growth_lookup_from_snapshot(preserved_green), "Stored Greenmeadow water growth was not restored after Sunset Shore death"):
		return false
	if not _expect(main._capture_encounter_state() == preserved_green.get("encounter", {}), "Stored Greenmeadow encounter was not restored after Sunset Shore death"):
		return false
	main.world.restore_state({})
	_clear_runtime_entities(main)
	main.quest_state = main.QUEST_AWAITING_PLANT
	main.map_host.set_runtime_suspended(false)
	return true

func _growth_lookup_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for entry_value in snapshot.get("water_growth", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var cell_data: Variant = entry.get("cell", [])
		var root_data: Variant = entry.get("root", [])
		if cell_data is Array and cell_data.size() == 2 and root_data is Array and root_data.size() == 2:
			result[Vector2i(int(cell_data[0]), int(cell_data[1]))] = {
				"root": Vector2i(int(root_data[0]), int(root_data[1])),
				"state": int(entry.get("state", 0)),
				"order": int(entry.get("order", 0)),
			}
	return result

func _drop_is_immediately_available(drop: Dictionary) -> bool:
	return int(drop.get("available_at_msec", 0)) <= Time.get_ticks_msec()

func _test_transformed_map_coordinates(main: MeadowMain) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	main.map_host.position = Vector2(137.0, 83.0)
	main.map_host.rotation = 0.31
	var player_map_position := Vector2(176.0, 208.0)
	var drop_map_position := Vector2(304.0, 144.0)
	var plant_map_position := Vector2(240.0, 272.0)
	var monster_map_position := Vector2(944.0, 176.0)
	main.player.global_position = main.world.to_global(player_map_position)
	if not _expect(main.world.add_drop(drop_map_position, "plant", 1, 0), "Transformed map rejected a valid map-local drop"):
		return false
	var plant_state := {
		"entity_id": "greenmeadow:plant:coordinate-test",
		"cell": [7, 8],
		"position": [plant_map_position.x, plant_map_position.y],
		"health": 2,
		"age": 1.5,
		"mature": false,
		"jump_cooldown_remaining": 0.0,
	}
	var plant := main._create_pursuing_plant(Vector2i(7, 8), plant_state)
	if not _expect(plant != null, "Could not create transformed plant probe"):
		return false
	var monster := MeadowLakeMonster.new()
	main.plants.add_child(monster)
	monster.entity_id = "greenmeadow:lake_monster:coordinate-test"
	monster.setup(main.player, main.world, monster_map_position)
	monster.facing = main.world.map_direction_to_global(Vector2.UP).normalized()
	main.lake_monster = monster
	var snapshot := main._capture_map_state()
	var captured_player := _vector_from_data(snapshot.get("last_player_position", []))
	var captured_drop := _vector_from_data(snapshot.get("drops", [])[0].get("position", []))
	var entity_entries: Array = snapshot.get("entities", [])
	var encounter: Dictionary = snapshot.get("encounter", {})
	var captured_monster: Dictionary = encounter.get("monster", {})
	if not _expect(captured_player.is_equal_approx(player_map_position), "Player position was not captured in map-local space"):
		return false
	if not _expect(captured_drop.is_equal_approx(drop_map_position), "Drop position was not captured in map-local space"):
		return false
	if not _expect(entity_entries.size() == 1, "Transformed coordinate snapshot did not contain exactly one plant"):
		return false
	var captured_plant: Dictionary = entity_entries[0]
	if not _expect(_vector_from_data(captured_plant.get("position", [])).is_equal_approx(plant_map_position), "Plant position was not captured in map-local space"):
		return false
	if not _expect(_vector_from_data(captured_monster.get("position", [])).is_equal_approx(monster_map_position), "Lake monster position was not captured in map-local space"):
		return false
	if not _expect(_vector_from_data(captured_monster.get("facing", [])).is_equal_approx(Vector2.UP), "Lake monster facing was not captured in map-local space"):
		return false
	main.player.global_position = Vector2.ZERO
	main.world.restore_state(snapshot)
	plant.global_position = Vector2.ZERO
	monster.global_position = Vector2.ZERO
	plant.restore_state(captured_plant)
	monster.restore_state(captured_monster)
	main._place_player_for_entry("continue", snapshot)
	if not _expect(main.player.global_position.is_equal_approx(main.world.to_global(player_map_position)), "Player restore did not convert map-local position to global space"):
		return false
	if not _expect(main.world.drops.size() == 1 and (main.world.drops[0].get("position", Vector2.ZERO) as Vector2).is_equal_approx(drop_map_position), "Drop restore did not preserve its map-local position"):
		return false
	if not _expect(plant.global_position.is_equal_approx(main.world.to_global(plant_map_position)), "Plant restore did not convert map-local position to global space"):
		return false
	if not _expect(monster.global_position.is_equal_approx(main.world.to_global(monster_map_position)), "Lake monster restore did not convert map-local position to global space"):
		return false
	if not _expect(monster.facing.is_equal_approx(main.world.map_direction_to_global(Vector2.UP).normalized()), "Lake monster restore did not convert map-local facing to global space"):
		return false
	main.lake_monster = null
	_clear_runtime_entities(main)
	main.world.restore_state({})
	main.map_host.position = Vector2.ZERO
	main.map_host.rotation = 0.0
	main.player.global_position = main.world.to_global(main.world.get_ship_arrival_position())
	main.map_host.set_runtime_suspended(false)
	await process_frame
	return true

func _test_capacity_transactions(main: MeadowMain) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
	var cactus_cell := Vector2i(3, 3)
	var shore := main.map_host.activate_map(&"sunset_shore")
	if not _expect(shore != null, "Could not activate Sunset Shore for cactus death coverage"):
		return false
	main._bind_active_map(shore)
	main.map_host.set_runtime_suspended(true)
	if not _expect(main.world.plant_orange_seed(cactus_cell), "Could not reserve cactus farm state for lethal-drop coverage"):
		return false
	var cactus := main._create_orange_cactus(cactus_cell)
	if not _expect(cactus != null, "Could not create cactus death-drop probe"):
		return false
	cactus.mature = true
	cactus.age = MeadowOrangeCactus.GROW_TIME
	main._on_orange_cactus_matured(cactus_cell)
	if not _expect(not main.world.farm_tiles.has(cactus_cell), "Cactus maturity did not release its sand cell"):
		return false
	if not _expect(main.world.plant_orange_seed(cactus_cell), "Could not reserve the released sand cell for a newer cactus"):
		return false
	if not _expect(cactus.take_damage(MeadowOrangeCactus.MAX_HEALTH), "Cactus did not accept lethal damage"):
		return false
	if not _expect(main.world.farm_tiles.has(cactus_cell), "Older cactus death erased the newer cactus farm reservation"):
		return false
	if not _expect(int(main.world.farm_tiles[cactus_cell].get("state", -1)) == MeadowWorld.FARM_SEEDED, "Older cactus death changed the newer cactus farm state"):
		return false
	if not _expect(main.world.drops.size() == 1 and str(main.world.drops[0].get("item_id", "")) == main.CACTUS_DROP, "Cactus death did not produce one typed cactus drop"):
		return false
	if not _expect(_drop_is_immediately_available(main.world.drops[0]), "Cactus death did not apply the approximately 3000ms pickup delay"):
		return false
	var green := main.map_host.activate_map(&"greenmeadow")
	if not _expect(green != null, "Could not restore Greenmeadow after cactus death coverage"):
		return false
	main._bind_active_map(green)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
	var all_plants_created := true
	for index in range(MeadowWorld.MAX_PERSISTED_PLANTS):
		var plant := main._create_pursuing_plant(Vector2i(5, 5))
		all_plants_created = plant != null and all_plants_created
	if not _expect(all_plants_created and main._live_pursuing_plant_count() == MeadowWorld.MAX_PERSISTED_PLANTS, "The first 256 runtime plants were not retained"):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": "green_seed", "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	var target_cell := Vector2i(3, 3)
	if not _expect(main.world.till(target_cell), "Could not prepare the plant-capacity test tile"):
		return false
	var seed_count := main.inventory.get_selected_count()
	var plant_count := main._live_pursuing_plant_count()
	var planting_result := main._plant_green_seed_at(target_cell)
	if not _expect(planting_result == "capacity", "The 257th runtime plant was not rejected at capacity"):
		return false
	if not _expect(main.inventory.get_selected_count() == seed_count, "Rejected 257th plant consumed a seed"):
		return false
	if not _expect(main._live_pursuing_plant_count() == plant_count, "Rejected 257th plant changed the runtime entity count"):
		return false
	if not _expect(int(main.world.farm_tiles[target_cell].get("state", -1)) == MeadowWorld.FARM_TILLED, "Rejected 257th plant changed the farm tile"):
		return false
	_clear_runtime_entities(main)
	main.world.restore_state({})
	var all_drops_created := _fill_world_drops(main)
	if not _expect(all_drops_created, "Could not fill all 256 runtime drop slots"):
		return false
	var full_drop_list: Array = main.world.drops.duplicate(true)
	var full_drop_cell := Vector2i(8, 8)
	var full_drop_plant := main._create_pursuing_plant(full_drop_cell, {"mutated": false})
	if not _expect(full_drop_plant != null, "Could not create the full-drop-list death probe"):
		return false
	full_drop_plant.mature = true
	full_drop_plant.age = MeadowPursuingPlant.GROW_TIME
	if not _expect(full_drop_plant.take_damage(MeadowPursuingPlant.MAX_HEALTH), "Full-drop-list plant did not complete lethal death behavior"):
		return false
	if not _expect(full_drop_plant.dead and full_drop_plant.is_queued_for_deletion(), "Full-drop-list plant death depended on creating a ground drop"):
		return false
	if not _expect(main.world.drops == full_drop_list, "Plant death changed an already full ground-drop list"):
		return false
	if not _expect(not main.plant_entities.has(full_drop_cell), "Full-drop-list plant death did not clean runtime bookkeeping"):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": "plant", "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	main.player.global_position = main.world.to_global(main.world.get_ship_arrival_position())
	var item_count := main.inventory.get_selected_count()
	var drops_before_discard: Array = main.world.drops.duplicate(true)
	main._drop_selected_item()
	if not _expect(main.world.drops == drops_before_discard, "Rejected manual drop changed the full world-drop list"):
		return false
	if not _expect(main.inventory.get_selected_count() == item_count, "Rejected manual drop consumed an inventory item"):
		return false
	main.map_host.set_runtime_suspended(false)
	return true

func _test_quest_relic_fallbacks(main: MeadowMain) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.inventory.import_state(_inventory_state([
		{"id": "hoe", "count": 1},
		{"id": "green_seed", "count": 64},
		{"id": "yellow_ball", "count": 1},
		{"id": "melee_weapon", "count": 1},
		{"id": "", "count": 0},
	]))
	var water_position := main.world.cell_to_world(Vector2i(28, 4))
	var inventory_result := main._grant_quest_relic(water_position)
	if not _expect(inventory_result == "inventory" and main.inventory.has_item(main.QUEST_ITEM_1), "Full ground did not fall back to inventory for the quest relic"):
		return false
	if not _expect(main.world.drops.size() == MeadowWorld.MAX_DROPS, "Inventory relic fallback changed the full ground list"):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": "hoe", "count": 1},
		{"id": "green_seed", "count": 64},
		{"id": "yellow_ball", "count": 1},
		{"id": "melee_weapon", "count": 1},
		{"id": "blue_seed", "count": 1},
	]))
	var oldest_drop: Dictionary = main.world.drops[0].duplicate(true)
	var replacement_result := main._grant_quest_relic(water_position)
	if not _expect(replacement_result == "replaced", "Double-full relic grant did not replace the oldest ground item"):
		return false
	if not _expect(main.world.drops.size() == MeadowWorld.MAX_DROPS, "Double-full relic replacement exceeded the drop cap"):
		return false
	if not _expect(oldest_drop not in main.world.drops, "Double-full relic grant did not replace the oldest ground item"):
		return false
	var relic_count := 0
	var relic_position := Vector2.ZERO
	for drop in main.world.drops:
		if str(drop.get("item_id", "")) == main.QUEST_ITEM_1:
			relic_count += 1
			relic_position = drop.get("position", Vector2.ZERO)
	if not _expect(relic_count == 1, "Double-full relic replacement did not preserve exactly one relic"):
		return false
	if not _expect(main.world.is_position_walkable(relic_position), "Quest relic fallback was not relocated to walkable terrain"):
		return false
	main.map_host.set_runtime_suspended(false)
	return true

func _test_save_failure_backoff(main: MeadowMain, game_state: Node) -> bool:
	var valid_save_path: String = game_state.save_path
	var valid_temp_path: String = game_state.temp_path
	var valid_backup_path: String = game_state.backup_path
	var blocker_path := "user://test_travel_autosave.blocker"
	if FileAccess.file_exists(blocker_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	if not _expect(blocker != null, "Could not create the isolated autosave failure blocker"):
		return false
	blocker.store_string("not a directory")
	blocker.close()
	game_state.save_path = blocker_path + "/autosave.json"
	game_state.temp_path = blocker_path + "/autosave.json.tmp"
	game_state.backup_path = blocker_path + "/autosave.json.bak"
	main._save_failure_count = 0
	main._save_failure_notified = false
	main._save_retry_remaining = 0.0
	main._save_dirty = true
	if not _expect(not main._capture_and_save(), "Autosave unexpectedly succeeded through a file used as a directory"):
		return false
	if not _expect(main._save_failure_count == 1 and is_equal_approx(main._save_retry_remaining, 1.0), "First autosave failure did not schedule one-second backoff"):
		return false
	main._update_autosave(0.25)
	if not _expect(main._save_failure_count == 1 and main._save_retry_remaining > 0.0, "Autosave retried before the backoff expired"):
		return false
	main._update_autosave(0.75)
	if not _expect(main._save_failure_count == 2 and is_equal_approx(main._save_retry_remaining, 2.0), "Autosave did not retry once when the first backoff expired"):
		return false
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if not _expect(not main._closing and main.is_inside_tree(), "Failed close-request save did not keep the game open"):
		return false
	if not _expect(main._save_failure_count == 3, "Close request did not make exactly one immediate save attempt"):
		return false
	game_state.save_path = valid_save_path
	game_state.temp_path = valid_temp_path
	game_state.backup_path = valid_backup_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	return true

func _fill_world_drops(main: MeadowMain) -> bool:
	var all_created := true
	for index in range(MeadowWorld.MAX_DROPS):
		var position := Vector2(8.0 + float(index % 40) * 31.0, 8.0 + float(index / 40) * 31.0)
		all_created = main.world.add_drop(position, "plant", 1, 0) and all_created
	return all_created and main.world.drops.size() == MeadowWorld.MAX_DROPS

func _clear_runtime_entities(main: MeadowMain) -> void:
	for child in main.plants.get_children():
		child.free()
	main.plant_entities.clear()
	main.lake_monster = null

func _inventory_state(slots: Array[Dictionary]) -> Dictionary:
	return {"slots": slots, "selected_slot": 0}

func _vector_from_data(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(INF, INF)

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false

func _fail(message: String) -> void:
	push_error("FAIL: %s" % message)
	quit(1)
