extends RefCounted
## Smoke checks for independent maps, content ownership, and MapHost replacement.

static func run(root: Window) -> Array[String]:
	var failures: Array[String] = []
	var green_scene := load("res://maps/Greenmeadow.tscn") as PackedScene
	var shore_scene := load("res://maps/SunsetShore.tscn") as PackedScene
	_check(green_scene != null, "Greenmeadow scene loads", failures)
	_check(shore_scene != null, "Sunset Shore scene loads", failures)
	if green_scene == null or shore_scene == null:
		return failures
	var green := green_scene.instantiate() as MeadowWorld
	var shore := shore_scene.instantiate() as MeadowWorld
	root.add_child(green)
	root.add_child(shore)
	_check(green.get_map_id() == &"greenmeadow", "Greenmeadow has the expected stable ID", failures)
	_check(shore.get_map_id() == &"sunset_shore", "Sunset Shore has the expected stable ID", failures)
	_check(green.get_node_or_null("Shop") != null, "Greenmeadow owns its shop", failures)
	var green_ids := _prop_ids(green)
	_check("greenmeadow.mailbox" in green_ids, "Greenmeadow owns its mailbox", failures)
	_check("greenmeadow.notice_board" in green_ids, "Greenmeadow owns its notice board", failures)
	_check(shore.get_node_or_null("Shop") != null, "Sunset Shore owns its beach shop", failures)
	_check(shore.get_shop_node() != green.get_shop_node(), "Each map owns an independent shop instance", failures)
	_check_shop_footprint(green, "Greenmeadow", failures)
	_check_shop_footprint(shore, "Sunset Shore", failures)
	var shore_ids := _prop_ids(shore)
	_check("sunset_shore.shop" in shore_ids, "Sunset Shore owns its shop prop", failures)
	for prop_id in shore_ids:
		_check(not prop_id.begins_with("greenmeadow."), "Sunset Shore has no Greenmeadow prop: %s" % prop_id, failures)
	_check(not shore.supports_lake_encounter(), "Sunset Shore has no Greenmeadow lake encounter", failures)
	_test_drop_restoration(green, shore, failures)
	green.free()
	shore.free()
	var host := MeadowMapHost.new()
	root.add_child(host)
	var hosted_green := host.activate_map(&"greenmeadow")
	_check(hosted_green != null and host.get_child_count() == 1, "MapHost loads exactly one Greenmeadow instance", failures)
	if hosted_green != null:
		hosted_green.till(Vector2i(3, 3))
	var hosted_shore := host.activate_map(&"sunset_shore")
	_check(hosted_shore != null and host.get_child_count() == 1, "MapHost replaces Greenmeadow with exactly one shore instance", failures)
	if hosted_shore != null:
		_check(not hosted_shore.farm_tiles.has(Vector2i(3, 3)), "Runtime farm state does not leak through MapHost", failures)
	host.free()
	return failures

static func _test_drop_restoration(green: MeadowWorld, shore: MeadowWorld, failures: Array[String]) -> void:
	var water_position := green.cell_to_world(Vector2i(28, 4))
	_check(green.is_water_cell(Vector2i(28, 4)), "Drop test uses a Greenmeadow water cell", failures)
	_check(green.add_drop(water_position, "plant", 1, 0), "A bounded water-cell drop is accepted", failures)
	var snapshot := green.capture_state()
	green.restore_state(snapshot)
	_check(green.drops.size() == 1, "A water-cell drop survives capture and restore", failures)
	if green.drops.size() == 1:
		_check((green.drops[0].get("position", Vector2.ZERO) as Vector2).is_equal_approx(water_position), "Restored water-cell drop keeps its map-local position", failures)
	green.restore_state({})
	shore.restore_state({})
	var isolated_position := green.cell_to_world(Vector2i(6, 6))
	var shore_position := shore.cell_to_world(Vector2i(6, 6))
	_check(green.add_drop(isolated_position, "pea_drop", 2, 0), "A Greenmeadow pea drop is accepted", failures)
	_check(shore.drops.is_empty(), "Greenmeadow drops do not leak into Sunset Shore", failures)
	_check(shore.add_drop(shore_position, "cactus_drop", 3, 0), "A Sunset Shore cactus drop is accepted independently", failures)
	var green_drop_state := green.capture_state()
	green.restore_state(green_drop_state)
	_check(green.drops.size() == 1 and str(green.drops[0].get("item_id", "")) == "pea_drop", "Greenmeadow restores only its pea drop", failures)
	_check(shore.drops.size() == 1 and str(shore.drops[0].get("item_id", "")) == "cactus_drop", "Restoring Greenmeadow leaves the Sunset Shore drop unchanged", failures)
	green.restore_state({})
	shore.restore_state({})
	var delayed_position := green.cell_to_world(Vector2i(7, 7))
	_check(green.add_drop(delayed_position, "mutated_pea_drop", 1, 3000), "A delayed mutated-pea drop is accepted", failures)
	_check(green.get_pickup_candidate(delayed_position) == -1, "A drop cannot be picked up during its pickup delay", failures)
	var delayed_snapshot := green.capture_state()
	var delayed_drops: Array = delayed_snapshot.get("drops", [])
	_check(delayed_drops.size() == 1, "Capture retains the delayed drop", failures)
	if delayed_drops.size() == 1:
		_check(int(delayed_drops[0].get("pickup_delay_msec", 0)) > 0, "Capture preserves a positive remaining pickup delay", failures)
	green.restore_state(delayed_snapshot)
	_check(green.get_pickup_candidate(delayed_position) == -1, "Restoring a delayed drop does not make it immediately collectible", failures)
	green.restore_state({})
	_check(green.add_drop(delayed_position, "cactus_drop", 1, 0), "A zero-delay cactus drop is accepted", failures)
	_check(green.get_pickup_candidate(delayed_position) == 0, "A zero-delay drop is immediately collectible", failures)
	green.restore_state({})
	_check(not green.add_drop(Vector2(-1.0, 16.0), "plant", 1, 0), "Negative-X drops are rejected", failures)
	_check(not green.add_drop(Vector2(16.0, -1.0), "plant", 1, 0), "Negative-Y drops are rejected", failures)
	var map_size := green.get_map_size_pixels()
	_check(not green.add_drop(Vector2(map_size.x, 16.0), "plant", 1, 0), "Drops at the exclusive right edge are rejected", failures)
	_check(not green.add_drop(Vector2(16.0, map_size.y), "plant", 1, 0), "Drops at the exclusive bottom edge are rejected", failures)
	var all_accepted := true
	for index in range(MeadowWorld.MAX_DROPS):
		var position := Vector2(8.0 + float(index % 40) * 31.0, 8.0 + float(index / 40) * 31.0)
		all_accepted = green.add_drop(position, "plant", 1, 0) and all_accepted
	_check(all_accepted and green.drops.size() == MeadowWorld.MAX_DROPS, "The first 256 runtime drops are retained", failures)
	_check(not green.add_drop(Vector2(16.0, 16.0), "plant", 1, 0), "The 257th runtime drop is rejected", failures)
	_check(green.drops.size() == MeadowWorld.MAX_DROPS, "Rejected 257th runtime drop does not mutate the drop list", failures)

static func _check_shop_footprint(map: MeadowWorld, map_name: String, failures: Array[String]) -> void:
	var shop_cells: Array = []
	for prop in map.props:
		if str(prop.get("kind", "")) == "shop":
			shop_cells = prop.get("footprint", [])
			break
	_check(map.get_shop_node().position.is_equal_approx(Vector2(512, 320)), "%s shop keeps its centered anchor" % map_name, failures)
	var expected_cells: Array[Vector2i] = []
	for y in range(9, 11):
		for x in range(14, 18):
			expected_cells.append(Vector2i(x, y))
	_check(shop_cells.size() == 8, "%s shop blocks 8 cells" % map_name, failures)
	for cell in expected_cells:
		_check(cell in shop_cells, "%s shop footprint includes %s" % [map_name, cell], failures)

static func _prop_ids(map: MeadowWorld) -> Array[String]:
	var result: Array[String] = []
	for prop in map.props:
		result.append(str(prop.get("id", "")))
	return result

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
