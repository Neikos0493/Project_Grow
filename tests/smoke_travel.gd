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
	var expected_prices := {
		"bean_seed": [0, 0],
		"green_seed": [25, 12],
		"melee_weapon": [50, 25],
		"bow": [300, 150],
		"tree_gun": [1000, 500],
		"hoe": [50, 25],
		"orange_seed": [5, 2],
		"sunglasses": [25, 12],
	}
	for item_id in expected_prices:
		var prices: Array = expected_prices[item_id]
		if not _expect(main.inventory.get_buy_price(item_id) == int(prices[0]), "%s buy price is incorrect" % item_id):
			return
		if not _expect(main.inventory.get_sell_price(item_id) == int(prices[1]), "%s sell price is incorrect" % item_id):
			return
	if not _expect(main.inventory.get_sell_price("cactus_drop") == 100, "Cactus fruit sell price changed unexpectedly"):
		return
	for item_id in [main.SMALL_SEED, main.GREEN_SEED, main.MELEE_WEAPON]:
		if not _expect(main.shop_panel.is_shop_product(item_id), "Greenmeadow shop is missing %s" % item_id):
			return
	for item_id in [main.BOW, main.TREE_GUN]:
		if not _expect(not main.shop_panel.is_shop_product(item_id), "Greenmeadow shop incorrectly sells %s" % item_id):
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
	for item_id in [main.SMALL_SEED, main.GREEN_SEED, main.MELEE_WEAPON, main.BOW, main.TREE_GUN, main.HOE, main.ORANGE_SEED, main.SUNGLASSES]:
		if not _expect(main.shop_panel.is_shop_product(item_id), "Sunset Shore shop is missing %s" % item_id):
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
	if not _expect(not main.shop_panel.is_shop_product(main.BOW) and not main.shop_panel.is_shop_product(main.TREE_GUN), "Greenmeadow shop exposes second-map weapons after return"):
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
	if not _test_gameplay_update_regressions(main, game_state):
		return
	if not await _test_requested_feature_regressions(main, game_state):
		return
	if not _test_cross_map_death_reset(main, game_state):
		return
	if not await _test_transformed_map_coordinates(main):
		return
	if not _test_capacity_transactions(main):
		return
	if not _test_bosses_drop_no_task_items(main):
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
		{"id": "bow", "count": 1},
		{"id": "melee_weapon", "count": 1},
		{"id": "green_seed", "count": 64},
	]))
	if not _expect(main.inventory.try_exchange(main.MUTATED_PEA_DROP, main.BLUE_SEED), "Atomic exchange rejected a full inventory whose final mutated pea freed a slot"):
		return false
	if not _expect(not main.inventory.has_item(main.MUTATED_PEA_DROP) and main.inventory.has_item(main.BLUE_SEED), "Successful mutated-pea exchange did not atomically replace the final pea with a blue seed"):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": "mutated_pea_drop", "count": 2},
		{"id": "hoe", "count": 1},
		{"id": "bow", "count": 1},
		{"id": "melee_weapon", "count": 1},
		{"id": "green_seed", "count": 64},
	]))
	var before := main.inventory.export_state()
	if not _expect(not main.inventory.try_exchange(main.MUTATED_PEA_DROP, main.BLUE_SEED), "Atomic exchange succeeded although removing one stacked pea left the inventory full"):
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

func _test_gameplay_update_regressions(main: MeadowMain, game_state: Node) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
	var default_inventory: Dictionary = game_state._default_inventory_state()
	if not _expect(default_inventory["slots"][0] == {"id": main.MELEE_WEAPON, "count": 1}, "New games do not start with one village sword in slot 1"):
		return false
	for slot_index in range(1, MeadowInventory.SLOT_COUNT):
		if not _expect(default_inventory["slots"][slot_index] == {"id": "", "count": 0}, "New games start with an unexpected extra item"):
			return false
	if not _expect(int(default_inventory.get("selected_slot", -1)) == 0, "New games do not select the starting sword"):
		return false
	for item_id in MeadowInventory.ITEM_DEFINITIONS:
		if not _expect(main.inventory.is_droppable(str(item_id)), "Item is not droppable: %s" % item_id):
			return false
	var center := Vector2i(5, 5)
	var player_position := main.world.cell_to_world(center)
	var hoe_target := center + Vector2i.RIGHT
	var hoe_cell := main.world.get_pointer_cell(
		main.world.cell_to_world(hoe_target),
		player_position,
		Vector2.ZERO,
		main.HOE
	)
	if not _expect(hoe_cell == hoe_target, "Hoe rejected a target in the surrounding ring"):
		return false
	if not _expect(main.world.till(hoe_cell), "Hoe could not till the pointer target"):
		return false
	if not _expect(main.world.farm_tiles.size() == 1 and main.world.farm_tiles.has(hoe_target), "Hoe tilled more than the pointer target"):
		return false
	if not _expect(
		main.world.get_pointer_cell(
			main.world.cell_to_world(center + Vector2i(2, 0)),
			player_position,
			Vector2.ZERO,
			main.HOE
		) == Vector2i(-1, -1),
		"Hoe accepted a target outside its work range"
	):
		return false
	main.world.restore_state({})
	main.inventory.import_state(_inventory_state([
		{"id": main.SMALL_SEED, "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	game_state.green_plantings_since_mutation = 9
	if not _expect(main.world.till(center), "Could not prepare the small-seed regression tile"):
		return false
	if not _expect(main._plant_green_seed_at(center, main.SMALL_SEED) == "planted", "Small seed could not be planted"):
		return false
	var planted: Node = null
	for child in main.plants.get_children():
		if child is MeadowPursuingPlant:
			planted = child
			break
	var small_seed_is_ordinary := planted is MeadowPursuingPlant \
		and not (planted is MeadowMutatedPlant)
	if not _expect(small_seed_is_ordinary, "Small seed produced a mutated pea plant"):
		return false
	if not _expect(game_state.green_plantings_since_mutation == 9, "Small seed changed the ordinary-seed mutation counter"):
		return false
	_clear_runtime_entities(main)
	var shore := main.map_host.activate_map(&"sunset_shore")
	if not _expect(
		shore != null,
		"Could not activate Sunset Shore for the Saxaul rollback probe"
	):
		return false
	main._bind_active_map(shore)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	var patch_center := Vector2i(12, 12)
	var patch_cells := main.world.convert_saxaul_patch_to_grass(patch_center)
	if not _expect(patch_cells.size() == 9, "Could not prepare the Saxaul rollback patch"):
		return false
	var farm_cell := patch_center + Vector2i.RIGHT
	var occupied_cell := patch_center + Vector2i.LEFT
	main.world.farm_tiles[farm_cell] = {"state": MeadowWorld.FARM_SEEDED}
	var occupied := {occupied_cell: true}
	main.world.revert_saxaul_patch_to_sand(patch_center, occupied)
	if not _expect(main.world.permanent_grass.has(farm_cell) and main.world.farm_tiles.has(farm_cell), "Saxaul retry rollback erased player farming state"):
		return false
	if not _expect(main.world.cells[farm_cell.y][farm_cell.x] == MeadowWorld.GRASS, "Saxaul retry rollback left protected farm state on sand"):
		return false
	if not _expect(main.world.permanent_grass.has(occupied_cell) and main.world.cells[occupied_cell.y][occupied_cell.x] == MeadowWorld.GRASS, "Saxaul retry rollback reverted grass beneath a live plant"):
		return false
	if not _expect(main.world.permanent_grass.size() == 2, "Saxaul retry rollback kept unoccupied encounter grass"):
		return false
	var green := main.map_host.activate_map(&"greenmeadow")
	if not _expect(
		green != null,
		"Could not restore Greenmeadow after the Saxaul rollback probe"
	):
		return false
	main._bind_active_map(green)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	game_state.pea_npc_state = 1
	game_state.pea_npc_transform_elapsed = 0.64
	main.world.set_pea_npc_phase(1)
	main.world.pea_npc_transform_elapsed = game_state.pea_npc_transform_elapsed
	main.world.advance_pea_npc_transform(0.16)
	game_state.pea_npc_transform_elapsed = main.world.pea_npc_transform_elapsed
	var captured_global: Dictionary = game_state._build_save_data()["global"]
	if not _expect(is_equal_approx(float(captured_global.get("pea_npc_transform_elapsed", 0.0)), 0.8), "Pea transformation progress was not captured"):
		return false
	main.world.restore_state({})
	_clear_runtime_entities(main)
	game_state.pea_npc_state = 0
	game_state.pea_npc_transform_elapsed = 0.0
	main.map_host.set_runtime_suspended(false)
	return true

func _test_requested_feature_regressions(
	main: MeadowMain,
	game_state: Node
) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
	game_state.defeated_boss_ids.clear()
	main._update_bottle_hud()
	if not _expect(
		main.bottle_button.texture_normal == main.BOTTLE_TEXTURES[0],
		"Empty bottle texture was not selected with no defeated bosses"
	):
		return false
	if not _expect(
		main.bottle_message.text == main._msg(
			"The World Tree's gift\nOverflow brings new life",
			"世界树的馈赠\n满溢即是新生"
		),
		"Empty bottle message is incorrect"
	):
		return false
	game_state.record_boss_defeat(main.BOSS_LAKE)
	main._update_bottle_hud()
	if not _expect(
		main.bottle_button.texture_normal == main.BOTTLE_TEXTURES[1],
		"Half bottle texture was not selected after one boss"
	):
		return false
	game_state.record_boss_defeat(main.BOSS_SAXAUL)
	main._update_bottle_hud()
	if not _expect(
		main.bottle_button.texture_normal == main.BOTTLE_TEXTURES[2],
		"Full bottle texture was not selected after two bosses"
	):
		return false
	if not _expect(
		main.bottle_message.text == main._msg(
			"The World Tree is calling...",
			"世界树在呼唤它…"
		),
		"Full bottle message is incorrect"
	):
		return false
	main._open_bottle_overlay()
	if not _expect(
		main.bottle_overlay.visible and main.player.controls_locked,
		"Bottle overlay did not open and lock controls"
	):
		return false
	var selected_before_bottle_input := main.inventory.selected_slot
	var bottle_number_key := InputEventKey.new()
	bottle_number_key.physical_keycode = KEY_2
	bottle_number_key.pressed = true
	main._unhandled_input(bottle_number_key)
	var bottle_wheel := InputEventMouseButton.new()
	bottle_wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	bottle_wheel.pressed = true
	main._unhandled_input(bottle_wheel)
	var bottle_player_position := main.player.global_position
	main._on_interaction_requested()
	if not _expect(
		main.inventory.selected_slot == selected_before_bottle_input
		and main.player.global_position == bottle_player_position
		and not main.dialogue_box.is_open()
		and not main.shop_open
		and not main.radar_open,
		"Bottle overlay leaked inventory or interaction input to gameplay"
	):
		return false
	main._close_bottle_overlay()
	if not _expect(
		not main.bottle_overlay.visible and not main.player.controls_locked,
		"Bottle overlay did not close and unlock controls"
	):
		return false
	main._open_bottle_overlay()
	main.player.restore_state(1)
	if not _expect(
		main.player.take_damage(1),
		"Player did not accept lethal damage for the bottle close probe"
	):
		return false
	if not _expect(
		main.player.dead
		and not main.bottle_overlay.visible
		and main.player.controls_locked,
		"Player death did not close the bottle overlay and retain the death lock"
	):
		return false
	if not _expect(
		main.player.respawn_at(
			main.world.to_global(main.world.get_respawn_position())
		),
		"Could not restore the player after the bottle death probe"
	):
		return false
	main.death_overlay.hide()
	game_state.defeated_boss_ids.clear()
	main._update_bottle_hud()
	main.world.restore_state({})
	main.inventory.import_state(_inventory_state([
		{"id": main.MELEE_WEAPON, "count": 1},
		{"id": main.GREEN_SEED, "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	var crate_cell := Vector2i(25, 17)
	var crate_origin := main.world.cell_to_world(crate_cell + Vector2i.LEFT)
	main.player.global_position = main.world.to_global(crate_origin)
	main.player.facing = Vector2.RIGHT
	main._on_interaction_requested()
	if not _expect(
		main.inventory.get_slot(0) == {"id": main.MELEE_WEAPON, "count": 1}
		and main.inventory.get_slot(1) == {"id": main.GREEN_SEED, "count": 1},
		"Crate overwrote an existing inventory item"
	):
		return false
	var hoe_slot := -1
	var small_seed_count := 0
	for slot_index in range(main.inventory.SLOT_COUNT):
		var reward_slot := main.inventory.get_slot(slot_index)
		if str(reward_slot.get("id", "")) == main.HOE:
			hoe_slot = slot_index
	if not _expect(hoe_slot >= 2, "Crate still forced the hoe into an occupied slot"):
		return false
	for slot_index in range(main.inventory.SLOT_COUNT):
		var slot := main.inventory.get_slot(slot_index)
		if str(slot.get("id", "")) == main.SMALL_SEED:
			small_seed_count += int(slot.get("count", 0))
	if not _expect(
		small_seed_count == 3,
		"Crate did not grant three small seeds"
	):
		return false
	var crate_target := main.world.get_interaction_target(
		crate_origin,
		Vector2.RIGHT
	)
	if not _expect(
		bool(crate_target.get("used", false)),
		"Crate was not marked used after its first reward"
	):
		return false
	var crate_inventory := main.inventory.export_state()
	main._on_interaction_requested()
	if not _expect(
		main.inventory.export_state() == crate_inventory,
		"Used crate granted rewards a second time"
	):
		return false
	main.world.restore_state({})
	main.inventory.import_state(_inventory_state([
		{"id": main.HOE, "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	main._on_interaction_requested()
	var legacy_small_seed_count := 0
	for slot_index in range(main.inventory.SLOT_COUNT):
		var legacy_slot := main.inventory.get_slot(slot_index)
		if str(legacy_slot.get("id", "")) == main.SMALL_SEED:
			legacy_small_seed_count += int(legacy_slot.get("count", 0))
	var legacy_crate_target := main.world.get_interaction_target(
		crate_origin,
		Vector2.RIGHT
	)
	if not _expect(
		legacy_small_seed_count == 3
		and bool(legacy_crate_target.get("used", false)),
		"Existing-save hoe owner could not claim the crate's three small seeds"
	):
		return false
	main.world.restore_state({})
	main.inventory.import_state(_inventory_state([
		{"id": main.MELEE_WEAPON, "count": 1},
		{"id": main.GREEN_SEED, "count": 64},
		{"id": main.BOW, "count": 1},
		{"id": main.TREE_GUN, "count": 1},
		{"id": main.SUNGLASSES, "count": 1},
	]))
	var full_crate_inventory := main.inventory.export_state()
	main._on_interaction_requested()
	var full_crate_target := main.world.get_interaction_target(crate_origin, Vector2.RIGHT)
	if not _expect(
		main.inventory.export_state() == full_crate_inventory
			and main.world.drops.size() == 2
			and bool(full_crate_target.get("used", false)),
		"Full inventory did not drop the crate rewards at the player's position"
	):
		return false
	main.world.restore_state({})
	main.inventory.import_state(_inventory_state([
		{"id": main.MUTATED_PEA_DROP, "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	main.quest_state = main.QUEST_AWAITING_PLANT
	main.player.controls_locked = true
	main._dialogue_choice_context = "lake_keeper"
	main.dialogue_box.open_choice_dialogue(
		"？？？",
		"……",
		"交付「金色豌豆」",
		"E  Select",
		"继续"
	)
	main._on_dialogue_choice_selected(0)
	if not _expect(
		main.quest_state == main.QUEST_SEED_GRANTED
		and not main.inventory.has_item(main.MUTATED_PEA_DROP)
		and main.inventory.has_item(main.BLUE_SEED),
		"Lake Keeper exchange did not replace one Golden Pea with a Blue Seed"
	):
		return false
	if not _expect(
		main.dialogue_box.body_label.text == main._msg(
			"Drop it into the water... and it will awaken...",
			"投入水中…它便会苏醒…"
		),
		"Lake Keeper follow-up dialogue is incorrect"
	):
		return false
	main.dialogue_box.close_dialogue()
	main.player.controls_locked = false
	main.inventory.import_state(_inventory_state([
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	main.quest_state = main.QUEST_MONSTER_ACTIVE
	main.lake_monster = null
	main._reset_lake_encounter_on_player_death()
	if not _expect(
		main.quest_state == main.QUEST_SEED_GRANTED
		and main.inventory.has_item(main.BLUE_SEED),
		"Failed Lake encounter did not return a usable Blue Seed"
	):
		return false
	var shore := main.map_host.activate_map(&"sunset_shore")
	if not _expect(
		shore != null,
		"Could not activate Sunset Shore for feature position checks"
	):
		return false
	main._bind_active_map(shore)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	var sunflower_cell := Vector2i(-1, -1)
	var pea_cell := Vector2i(-1, -1)
	for prop in main.world.props:
		match str(prop.get("id", "")):
			"sunset_shore.ranger":
				sunflower_cell = prop.get("cell", sunflower_cell)
			"sunset_shore.pea_npc":
				pea_cell = prop.get("cell", pea_cell)
	if not _expect(
		sunflower_cell == Vector2i(5, 8)
		and pea_cell == Vector2i(7, 8),
		"Sunflower or Pea NPC was not moved three tiles left"
	):
		return false
	var saved_ranger_position := main.world.cell_to_world(sunflower_cell)
	main._place_player_for_entry(
		"continue",
		{
			"last_player_position": [
				saved_ranger_position.x,
				saved_ranger_position.y,
			]
		}
	)
	var relocated_ranger_position := main.world.to_local(
		main.player.global_position
	)
	if not _expect(
		main.world.is_position_unoccupied(relocated_ranger_position)
		and not relocated_ranger_position.is_equal_approx(
			main.world.get_initial_spawn_position()
		)
		and maxi(
			abs(main.world.world_to_cell(relocated_ranger_position).x - sunflower_cell.x),
			abs(main.world.world_to_cell(relocated_ranger_position).y - sunflower_cell.y)
		) <= 1,
		"Legacy player position on the moved sunflower was not relocated nearby"
	):
		return false
	var restored_grass_cell := Vector2i(12, 12)
	var blocked_shore_snapshot := {
		"permanent_grass": [[restored_grass_cell.x, restored_grass_cell.y]],
		"farm": [{"cell": [sunflower_cell.x, sunflower_cell.y], "state": MeadowWorld.FARM_SEEDED}],
		"entities": [{
			"kind": "pursuing_plant",
			"entity_id": "legacy-shore-ranger-plant",
			"cell": [sunflower_cell.x, sunflower_cell.y],
			"position": [saved_ranger_position.x, saved_ranger_position.y],
			"health": MeadowPursuingPlant.MAX_HEALTH,
			"age": 0.5,
			"mature": false,
		}],
	}
	main._restore_map_state(blocked_shore_snapshot)
	var migrated_shore_plant: MeadowPursuingPlant
	for child in main.plants.get_children():
		if child is MeadowPursuingPlant \
		and child.entity_id == "legacy-shore-ranger-plant":
			migrated_shore_plant = child
			break
	if not _expect(
		is_instance_valid(migrated_shore_plant)
		and migrated_shore_plant.cell != sunflower_cell
		and main.world.is_valid_farm_cell(migrated_shore_plant.cell)
		and main.world.farm_tiles.has(migrated_shore_plant.cell)
		and not main.world.is_prop_cell(migrated_shore_plant.cell)
		and main.world.permanent_grass.has(restored_grass_cell),
		"Legacy plant and farm on the moved sunflower were not relocated safely"
	):
		return false
	main.world.restore_state({})
	_clear_runtime_entities(main)
	var standalone_shore_snapshot := {
		"farm": [{
			"cell": [sunflower_cell.x, sunflower_cell.y],
			"state": MeadowWorld.FARM_TILLED,
		}],
	}
	main._restore_map_state(standalone_shore_snapshot)
	if not _expect(
		main.world.farm_tiles.size() == 1
		and not main.world.farm_tiles.has(sunflower_cell)
		and not main.world.is_prop_cell(
			main.world.farm_tiles.keys()[0]
		),
		"Standalone legacy farm on the moved sunflower was not relocated"
	):
		return false
	main.world.restore_state({})
	_clear_runtime_entities(main)
	main.world.set_pea_npc_phase(1)
	main.world.pea_npc_transform_elapsed = MeadowWorld.WORM_TRANSFORM_DURATION
	main.world.advance_pea_npc_transform(0.5)
	if not _expect(
		main.world.pea_npc_phase == 1
		and is_equal_approx(
			main.world.pea_npc_transform_elapsed,
			MeadowWorld.WORM_TRANSFORM_DURATION
		),
		"Completed Pea transformation did not remain on its static final state"
	):
		return false
	var green := main.map_host.activate_map(&"greenmeadow")
	if not _expect(
		green != null,
		"Could not restore Greenmeadow after requested feature probes"
	):
		return false
	main._bind_active_map(green)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	var ship_cell := main.world.get_ship_cell()
	var saved_ship_position := main.world.cell_to_world(ship_cell)
	main._place_player_for_entry(
		"continue",
		{"last_player_position": [saved_ship_position.x, saved_ship_position.y]}
	)
	var relocated_player_position := main.world.to_local(
		main.player.global_position
	)
	if not _expect(
		main.world.is_position_unoccupied(relocated_player_position)
		and not relocated_player_position.is_equal_approx(
			main.world.get_initial_spawn_position()
		)
		and maxi(
			abs(main.world.world_to_cell(relocated_player_position).x - ship_cell.x),
			abs(main.world.world_to_cell(relocated_player_position).y - ship_cell.y)
		) <= 1,
		"Legacy player position on the moved ship was not relocated nearby"
	):
		return false
	var blocked_green_snapshot := {
		"farm": [{"cell": [ship_cell.x, ship_cell.y], "state": MeadowWorld.FARM_SEEDED}],
		"entities": [{
			"kind": "pursuing_plant",
			"entity_id": "legacy-green-ship-plant",
			"cell": [ship_cell.x, ship_cell.y],
			"position": [saved_ship_position.x, saved_ship_position.y],
			"health": MeadowPursuingPlant.MAX_HEALTH,
			"age": 0.5,
			"mature": false,
		}],
	}
	main._restore_map_state(blocked_green_snapshot)
	var migrated_green_plant: MeadowPursuingPlant
	for child in main.plants.get_children():
		if child is MeadowPursuingPlant \
		and child.entity_id == "legacy-green-ship-plant":
			migrated_green_plant = child
			break
	if not _expect(
		is_instance_valid(migrated_green_plant)
		and migrated_green_plant.cell != ship_cell
		and main.world.farm_tiles.has(migrated_green_plant.cell)
		and not main.world.is_prop_cell(migrated_green_plant.cell),
		"Legacy farm and plant on the moved ship were not relocated together"
	):
		return false
	main.world.restore_state({})
	_clear_runtime_entities(main)
	if not _expect(
		main.world.get_ship_cell() == Vector2i(5, 20),
		"Greenmeadow ship is not in the lower-left area"
	):
		return false
	if not _expect(
		main.world.get_initial_spawn_cell() \
		== main.world.get_ship_cell() + Vector2i.DOWN
		and main.world.get_respawn_cell() \
		== main.world.get_ship_cell() + Vector2i.DOWN,
		"Greenmeadow spawn points did not follow the moved ship"
	):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": main.HOE, "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	main.shop_open = false
	var slot_size := Vector2(52, 52)
	var gap := 6.0
	var total_width := slot_size.x * main.inventory.SLOT_COUNT \
		+ gap * (main.inventory.SLOT_COUNT - 1)
	var slot_center := Vector2(
		(main.inventory_hud.size.x - total_width) * 0.5 + 26.0,
		main.inventory_hud.size.y - 40.0
	)
	main._update_inventory_tooltip_at(slot_center)
	if not _expect(
		main.inventory_sell_tooltip.visible
		and main.inventory.get_item_name(main.HOE) \
		in main.inventory_sell_tooltip.text
		and main.inventory.get_item_description(main.HOE) \
		in main.inventory_sell_tooltip.text,
		"Hotbar hover did not show the same item description as the shop"
	):
		return false
	main.shop_open = true
	main._update_inventory_tooltip_at(slot_center)
	if not _expect(
		main.inventory.get_item_description(main.HOE) \
		in main.inventory_sell_tooltip.text,
		"Shop hotbar hover did not show the item description"
	):
		return false
	main.shop_open = false
	main._clear_inventory_sell_tooltip()
	main._set_paused(true)
	if not _expect(
		not main.inventory_sell_tooltip.visible,
		"Opening the pause menu did not clear the hotbar tooltip"
	):
		return false
	main._set_paused(false)
	main._clear_inventory_sell_tooltip()
	shore = main.map_host.activate_map(&"sunset_shore")
	if not _expect(
		shore != null,
		"Could not activate Sunset Shore for the Saxaul retry probe"
	):
		return false
	main._bind_active_map(shore)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	var boss_cell := Vector2i(12, 12)
	var boss_patch := main.world.convert_saxaul_patch_to_grass(boss_cell)
	if not _expect(
		boss_patch.size() == 9,
		"Could not prepare the Saxaul retry feature probe"
	):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	main.saxaul_boss = main._create_saxaul_boss(boss_cell)
	if not _expect(
		is_instance_valid(main.saxaul_boss),
		"Could not create the Saxaul retry feature probe"
	):
		return false
	main._reset_saxaul_encounter_on_player_death()
	if not _expect(
		main.inventory.has_item(main.SAXAUL_SEED)
		and not is_instance_valid(main.saxaul_boss),
		"Failed Saxaul encounter did not return a usable summoning seed"
	):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": main.GREEN_SEED, "count": 64},
		{"id": main.SMALL_SEED, "count": 64},
		{"id": main.ORANGE_SEED, "count": 64},
		{"id": main.PEA_DROP, "count": 64},
		{"id": main.CACTUS_DROP, "count": 64},
	]))
	main.world.restore_state({})
	main.inventory.import_state(_inventory_state([
		{"id": main.SAXAUL_SEED, "count": 1},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
		{"id": "", "count": 0},
	]))
	var immature_boss_cell := Vector2i(12, 12)
	if not _expect(
		main.world.plant_saxaul_seed(immature_boss_cell),
		"Could not reserve an immature Saxaul retry patch"
	):
		return false
	main.saxaul_boss = main._create_saxaul_boss(immature_boss_cell)
	if not _expect(
		is_instance_valid(main.saxaul_boss)
		and main.inventory.consume_selected(),
		"Could not create the immature Saxaul retry encounter"
	):
		return false
	main._saxaul_failure_seed_returned = false
	main._reset_saxaul_encounter_on_player_death()
	if not _expect(
		not main.world.farm_tiles.has(immature_boss_cell)
		and main.inventory.has_item(main.SAXAUL_SEED)
		and main.world.can_plant_saxaul_seed(immature_boss_cell),
		"Immature Saxaul failure left its retry patch blocked"
	):
		return false
	main.inventory.import_state(_inventory_state([
		{"id": main.GREEN_SEED, "count": 64},
		{"id": main.SMALL_SEED, "count": 64},
		{"id": main.ORANGE_SEED, "count": 64},
		{"id": main.PEA_DROP, "count": 64},
		{"id": main.CACTUS_DROP, "count": 64},
	]))
	main.world.restore_state({})
	if not _expect(
		_fill_world_drops(main),
		"Could not fill ground drops for the retry-seed capacity probe"
	):
		return false
	main._return_failed_boss_seed(main.SAXAUL_SEED, Vector2(420.0, 420.0))
	var retry_seed_drop_count := 0
	for drop in main.world.drops:
		if str(drop.get("item_id", "")) == main.SAXAUL_SEED:
			retry_seed_drop_count += 1
	if not _expect(
		main.world.drops.size() == MeadowWorld.MAX_DROPS
		and retry_seed_drop_count == 1,
		"Full inventory and ground capacity lost the failed-boss retry seed"
	):
		return false
	main.world.restore_state({})
	game_state.defeated_boss_ids.clear()
	main.quest_state = main.QUEST_AWAITING_PLANT
	green = main.map_host.activate_map(&"greenmeadow")
	if not _expect(
		green != null,
		"Could not restore Greenmeadow after the Saxaul retry probe"
	):
		return false
	main._bind_active_map(green)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	main.map_host.set_runtime_suspended(false)
	var particle_children_before := main.world.get_child_count()
	main.player.global_position = Vector2(760.0, 520.0)
	main._play_boss_death_feedback(Vector2(240.0, 220.0))
	var particles: Array[Polygon2D] = []
	for child in main.world.get_children():
		if child is Polygon2D \
		and child.color == Color("#69e58a"):
			particles.append(child)
	if not _expect(
		main.world.get_child_count() == particle_children_before + 20
		and particles.size() == 20,
		"Boss death feedback did not create twenty green particles"
	):
		return false
	var particle_starts: Array[Vector2] = []
	for particle in particles:
		particle_starts.append(particle.global_position)
	await create_timer(1.9).timeout
	for index in range(particles.size()):
		if not _expect(
			is_instance_valid(particles[index])
			and particles[index].global_position.is_equal_approx(
				particle_starts[index]
			),
			"Boss death particle moved before the two-second hold ended"
		):
			return false
	await create_timer(0.2).timeout
	var particle_started_homing := false
	for index in range(particles.size()):
		if is_instance_valid(particles[index]) \
		and not particles[index].global_position.is_equal_approx(
			particle_starts[index]
		):
			particle_started_homing = true
			break
	if not _expect(
		particle_started_homing,
		"Boss death particles did not home toward the player after two seconds"
	):
		return false
	await create_timer(0.55).timeout
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

func _test_bosses_drop_no_task_items(main: MeadowMain) -> bool:
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	main.inventory.import_state(_inventory_state([
		{"id": "hoe", "count": 1},
		{"id": "green_seed", "count": 64},
		{"id": "bow", "count": 1},
		{"id": "melee_weapon", "count": 1},
		{"id": "blue_seed", "count": 1},
	]))
	main.quest_state = main.QUEST_MONSTER_ACTIVE
	var game_state := main.get_node("/root/GameState")
	game_state.defeated_boss_ids.erase(main.BOSS_LAKE)
	var drops_before: Array = main.world.drops.duplicate(true)
	var inventory_before := main.inventory.export_state()
	main._on_lake_monster_died(main.player.global_position)
	if not _expect(main.world.drops == drops_before, "Lake boss death created a ground task item"):
		return false
	if not _expect(main.inventory.export_state() == inventory_before, "Lake boss death inserted a task item into inventory"):
		return false
	if not _expect(game_state.has_defeated_boss(main.BOSS_LAKE), "Lake boss death did not record its completion"):
		return false
	var shore := main.map_host.activate_map(&"sunset_shore")
	if not _expect(
		shore != null,
		"Could not activate Sunset Shore for the Saxaul death-drop probe"
	):
		return false
	main._bind_active_map(shore)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
	game_state.defeated_boss_ids.erase(main.BOSS_SAXAUL)
	var boss_cell := Vector2i(12, 12)
	var boss_patch := main.world.convert_saxaul_patch_to_grass(boss_cell)
	if not _expect(
		boss_patch.size() == 9,
		"Could not prepare the Saxaul death-drop probe"
	):
		return false
	var boss := main._create_saxaul_boss(boss_cell, {
		"health": MeadowSaxaulBoss.MAX_HEALTH,
		"age": MeadowSaxaulBoss.GROW_TIME,
		"mature": true,
		"spawn_grace_remaining": 0.0,
	})
	if not _expect(
		is_instance_valid(boss),
		"Could not create the Saxaul death-drop probe"
	):
		return false
	drops_before = main.world.drops.duplicate(true)
	inventory_before = main.inventory.export_state()
	if not _expect(
		boss.take_damage(MeadowSaxaulBoss.MAX_HEALTH),
		"Saxaul boss did not accept lethal damage"
	):
		return false
	if not _expect(
		main.world.drops == drops_before,
		"Saxaul boss death created a ground task item"
	):
		return false
	if not _expect(
		main.inventory.export_state() == inventory_before,
		"Saxaul boss death inserted a task item into inventory"
	):
		return false
	if not _expect(
		game_state.has_defeated_boss(main.BOSS_SAXAUL),
		"Saxaul boss death did not record its completion"
	):
		return false
	var green := main.map_host.activate_map(&"greenmeadow")
	if not _expect(
		green != null,
		"Could not restore Greenmeadow after the Saxaul death-drop probe"
	):
		return false
	main._bind_active_map(green)
	main.map_host.set_runtime_suspended(true)
	main.world.restore_state({})
	_clear_runtime_entities(main)
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
	main.saxaul_boss = null

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
