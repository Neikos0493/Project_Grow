extends RefCounted
## Regression checks for enemy spawn grace and expanded trigger ranges.

static func run(root: Window) -> Array[String]:
	var failures: Array[String] = []
	var packed := load("res://Main.tscn") as PackedScene
	_check(packed != null, "Gameplay scene loads for enemy grace checks", failures)
	if packed == null:
		return failures
	var main := packed.instantiate() as MeadowMain
	root.add_child(main)
	await root.get_tree().process_frame
	await root.get_tree().process_frame
	if not is_instance_valid(main.world) or not is_instance_valid(main.plants):
		failures.append("Gameplay scene did not initialize enemy test containers")
		main.queue_free()
		return failures
	main.map_host.set_runtime_suspended(true)
	_test_pursuing_plant(main, failures)
	_test_orange_cactus(main, failures)
	_test_saxaul_boss(main, failures)
	_test_lake_monster(main, failures)
	main.queue_free()
	return failures

static func _test_pursuing_plant(main: MeadowMain, failures: Array[String]) -> void:
	var plant := MeadowPursuingPlant.new()
	main.plants.add_child(plant)
	plant.global_position = main.player.global_position - Vector2(MeadowPursuingPlant.ATTACK_RANGE - 1.0, 0.0)
	plant.setup(Vector2i(3, 3), main.player, main.world)
	plant.mature = true
	plant.age = MeadowPursuingPlant.GROW_TIME
	plant.spawn_grace_remaining = MeadowPursuingPlant.SPAWN_GRACE_DURATION
	var start := plant.global_position
	plant.apply_knockback(Vector2.RIGHT, 100.0)
	_check(plant.global_position.is_equal_approx(start), "Pursuing plant ignores knockback during spawn grace", failures)
	plant._physics_process(0.5)
	_check(plant.global_position.is_equal_approx(start), "Pursuing plant remains still during spawn grace", failures)
	_check(not plant.jumping, "Pursuing plant does not jump during spawn grace", failures)
	plant._physics_process(0.5)
	_check(plant.spawn_grace_remaining <= 0.0, "Pursuing plant grace expires after one second", failures)
	plant._physics_process(0.01)
	_check(plant.jumping, "Pursuing plant uses expanded attack range", failures)
	plant.queue_free()

static func _test_orange_cactus(main: MeadowMain, failures: Array[String]) -> void:
	var cactus := MeadowOrangeCactus.new()
	main.plants.add_child(cactus)
	cactus.global_position = main.player.global_position - Vector2(MeadowOrangeCactus.ATTACK_RANGE - 1.0, 0.0)
	cactus.setup(Vector2i(4, 4), main.player, main.world)
	cactus.mature = true
	cactus.age = MeadowOrangeCactus.GROW_TIME
	cactus.spawn_grace_remaining = MeadowOrangeCactus.SPAWN_GRACE_DURATION
	var start := cactus.global_position
	cactus.apply_knockback(Vector2.RIGHT, 100.0)
	_check(cactus.global_position.is_equal_approx(start), "Orange cactus ignores knockback during spawn grace", failures)
	cactus._physics_process(0.5)
	_check(cactus.global_position.is_equal_approx(start), "Orange cactus remains still during spawn grace", failures)
	cactus._physics_process(0.5)
	_check(cactus.spawn_grace_remaining <= 0.0, "Orange cactus grace expires after one second", failures)
	cactus.queue_free()

static func _test_saxaul_boss(main: MeadowMain, failures: Array[String]) -> void:
	var boss := MeadowSaxaulBoss.new()
	main.plants.add_child(boss)
	boss.global_position = main.player.global_position - Vector2(MeadowSaxaulBoss.ATTACK_RANGE - 1.0, 0.0)
	boss.setup(Vector2i(12, 12), main.player, main.world)
	boss.mature = true
	boss.age = MeadowSaxaulBoss.GROW_TIME
	boss.spawn_grace_remaining = MeadowSaxaulBoss.SPAWN_GRACE_DURATION
	var boss_start := boss.global_position
	boss._physics_process(0.5)
	_check(boss.global_position.is_equal_approx(boss_start), "Saxaul boss remains stationary during spawn grace", failures)
	_check(boss.ring_duration_remaining <= 0.0 and boss.skill_windup <= 0.0, "Saxaul boss does not attack during spawn grace", failures)
	boss._physics_process(0.5)
	_check(boss.spawn_grace_remaining <= 0.0, "Saxaul boss grace expires after one second", failures)
	boss.queue_free()

static func _test_lake_monster(main: MeadowMain, failures: Array[String]) -> void:
	var monster := MeadowLakeMonster.new()
	main.plants.add_child(monster)
	monster.setup(main.player, main.world, main.world.to_local(main.player.global_position - Vector2(MeadowLakeMonster.ATTACK_RANGE - 1.0, 0.0)))
	var start := monster.global_position
	var health := monster.health
	monster.apply_knockback(Vector2.RIGHT, 100.0)
	_check(monster.global_position.is_equal_approx(start), "Lake monster ignores knockback during spawn grace", failures)
	monster._physics_process(0.5)
	_check(monster.global_position.is_equal_approx(start), "Lake monster remains still during spawn grace", failures)
	_check(monster.state == "emerging", "Lake monster remains emerging during spawn grace", failures)
	_check(monster.health == health, "Lake monster health is protected during spawn grace", failures)
	monster._physics_process(0.5)
	_check(monster.spawn_grace_remaining <= 0.0, "Lake monster grace expires after one second", failures)
	monster._physics_process(0.01)
	_check(monster.state == "attack", "Lake monster uses expanded attack range", failures)
	var monster_shape := monster.get_child(0) as CollisionShape2D
	_check(monster_shape != null and monster_shape.shape is RectangleShape2D and (monster_shape.shape as RectangleShape2D).size == MeadowLakeMonster.BODY_SIZE, "Lake monster occupies four tiles", failures)
	_check(MeadowLakeMonster.MOVE_SPEED < MeadowPlayer.MOVE_SPEED, "Lake monster is slower than player", failures)
	_check(MeadowLakeMonster.ATTACK_COOLDOWN > MeadowLakeMonster.ATTACK_PAUSE_DURATION, "Lake monster pauses after each attack", failures)
	monster.queue_free()

static func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
