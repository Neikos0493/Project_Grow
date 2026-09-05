extends SceneTree
## Headless smoke-test entry point.

func _initialize() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		push_error("FAIL: GameState autoload is unavailable")
		quit(1)
		return
	var failures: Array[String] = []
	var map_test: GDScript = load("res://tests/test_map_isolation.gd")
	var save_test: GDScript = load("res://tests/test_save_round_trip.gd")
	var enemy_test: GDScript = load("res://tests/test_enemy_grace.gd")
	await process_frame
	failures.append_array(map_test.run(root))
	failures.append_array(save_test.run(game_state))
	failures.append_array(await enemy_test.run(root))
	if failures.is_empty():
		print("PASS: map isolation and save-state smoke tests")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: %s" % failure)
	quit(1)
