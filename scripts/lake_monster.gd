class_name MeadowLakeMonster
extends CharacterBody2D
## Four-tile water-lily boss with fast pursuit, wall-stunning charges, and seed volleys.

signal died(position: Vector2)
signal stunned
signal seed_volley_requested(origin: Vector2, directions: Array[Vector2])
signal health_changed(current: int, maximum: int)

const WORLD_MASK := 1
const PLAYER_MASK := 2
const MONSTER_MASK := 16
const MAX_HEALTH := 16
const BODY_SIZE := Vector2(64.0, 64.0)
const MOVE_SPEED := 105.0
const CHARGE_SPEED := 430.0
const ATTACK_RANGE := 62.0
const ATTACK_WINDUP := 0.22
const ATTACK_COOLDOWN := 0.55
const CHARGE_WINDUP := 0.35
const STUN_DURATION := 4.0
const MELEE_DAMAGE := 2
const CHARGE_DAMAGE := 3
const SEED_VOLLEY_MIN_INTERVAL := 2.2
const SEED_VOLLEY_MAX_INTERVAL := 3.8
const SEED_VOLLEY_HALF_ANGLE := deg_to_rad(60.0)

var entity_id := ""
var target: MeadowPlayer
var world: MeadowWorld
var health := MAX_HEALTH
var state := "emerging"
var state_elapsed := 0.0
var attacks_done := 0
var attacks_before_charge := 2
var charge_direction := Vector2.RIGHT
var charge_endpoint := Vector2.ZERO
var charge_hit_player := false
var attack_hit_resolved := false
var seed_volley_timer := 3.0
var dead := false
var facing := Vector2.LEFT

func setup(new_target: MeadowPlayer, new_world: MeadowWorld, spawn_map_position: Vector2) -> void:
	target = new_target
	world = new_world
	global_position = world.to_global(spawn_map_position)
	seed_volley_timer = randf_range(SEED_VOLLEY_MIN_INTERVAL, SEED_VOLLEY_MAX_INTERVAL)
	queue_redraw()

func capture_state() -> Dictionary:
	var map_position := world.to_local(global_position) if is_instance_valid(world) else global_position
	var map_facing := world.global_direction_to_map(facing) if is_instance_valid(world) else facing
	map_facing = map_facing.normalized() if map_facing.length_squared() > 0.01 else Vector2.LEFT
	return {
		"kind": "lake_monster",
		"entity_id": entity_id,
		"position": [map_position.x, map_position.y],
		"health": clampi(health, 1, MAX_HEALTH),
		"state": "stunned" if state == "stunned" else "chase",
		"stun_remaining": maxf(0.0, STUN_DURATION - state_elapsed) if state == "stunned" else 0.0,
		"facing": [map_facing.x, map_facing.y],
	}

func restore_state(data: Dictionary) -> void:
	entity_id = str(data.get("entity_id", ""))
	var fallback := world.to_local(global_position) if is_instance_valid(world) else global_position
	var map_position := _data_to_position(data.get("position", []), fallback)
	global_position = world.to_global(map_position) if is_instance_valid(world) else map_position
	health = clampi(int(data.get("health", MAX_HEALTH)), 1, MAX_HEALTH)
	var map_facing := _data_to_direction(data.get("facing", []), Vector2.LEFT)
	facing = world.map_direction_to_global(map_facing).normalized() if is_instance_valid(world) else map_facing
	state = "stunned" if str(data.get("state", "chase")) == "stunned" else "chase"
	if state == "stunned":
		var remaining := clampf(float(data.get("stun_remaining", STUN_DURATION)), 0.0, STUN_DURATION)
		state_elapsed = STUN_DURATION - remaining
	else:
		state_elapsed = 0.0
	dead = false
	attacks_done = 0
	charge_hit_player = false
	attack_hit_resolved = false
	velocity = Vector2.ZERO
	collision_layer = MONSTER_MASK
	queue_redraw()

func _data_to_position(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and value.size() == 2:
		var position := Vector2(float(value[0]), float(value[1]))
		if is_finite(position.x) and is_finite(position.y):
			return position
	return fallback

func _data_to_direction(value: Variant, fallback: Vector2) -> Vector2:
	var direction := _data_to_position(value, fallback)
	if direction.length_squared() < 0.01:
		return Vector2.LEFT
	return direction.normalized()

func _ready() -> void:
	collision_layer = MONSTER_MASK
	collision_mask = WORLD_MASK
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = BODY_SIZE
	shape_node.shape = rectangle
	add_child(shape_node)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target) or target.dead:
		velocity = Vector2.ZERO
		return
	state_elapsed += delta
	_update_seed_volley(delta)
	match state:
		"emerging":
			velocity = Vector2.ZERO
			if state_elapsed >= 0.8:
				_change_state("chase")
		"chase":
			_chase()
		"attack":
			_attack()
		"charge_windup":
			velocity = Vector2.ZERO
			if state_elapsed >= CHARGE_WINDUP:
				_begin_charge()
		"charging":
			_charge(delta)
		"stunned":
			velocity = Vector2.ZERO
			if state_elapsed >= STUN_DURATION:
				attacks_done = 0
				_change_state("chase")
	queue_redraw()

func _change_state(next_state: String) -> void:
	state = next_state
	state_elapsed = 0.0
	attack_hit_resolved = false
	velocity = Vector2.ZERO

func _chase() -> void:
	var offset := target.global_position - global_position
	if offset.length_squared() < 0.01:
		velocity = Vector2.ZERO
		return
	facing = offset.normalized()
	if offset.length() <= ATTACK_RANGE:
		velocity = Vector2.ZERO
		_change_state("attack")
		return
	velocity = facing * MOVE_SPEED
	move_and_slide()

func _attack() -> void:
	velocity = Vector2.ZERO
	var offset := target.global_position - global_position
	if offset.length_squared() > 0.01:
		facing = offset.normalized()
	if not attack_hit_resolved and state_elapsed >= ATTACK_WINDUP:
		attack_hit_resolved = true
		if offset.length() <= ATTACK_RANGE:
			target.take_damage(MELEE_DAMAGE)
	if state_elapsed >= ATTACK_WINDUP + ATTACK_COOLDOWN:
		attacks_done += 1
		if attacks_done >= attacks_before_charge:
			_change_state("charge_windup")
		else:
			_change_state("chase")

func _grid_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() < 0.01:
		return Vector2.RIGHT
	if absf(direction.x) >= absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	return Vector2(0.0, signf(direction.y))

func _begin_charge() -> void:
	var offset := target.global_position - global_position
	if offset.length_squared() < 0.01:
		offset = facing
	var map_offset: Vector2 = world.global_direction_to_map(offset).normalized()
	var map_charge_direction: Vector2 = _grid_direction(map_offset)
	charge_direction = world.map_direction_to_global(map_charge_direction).normalized()
	facing = charge_direction
	var trigger_cell := world.world_to_cell(world.to_local(target.global_position))
	var endpoint_step := Vector2i(roundi(map_charge_direction.x), roundi(map_charge_direction.y)) * 2
	var endpoint_cell := trigger_cell + endpoint_step
	endpoint_cell.x = clampi(endpoint_cell.x, 1, world.MAP_SIZE.x - 2)
	endpoint_cell.y = clampi(endpoint_cell.y, 1, world.MAP_SIZE.y - 2)
	charge_endpoint = world.to_global(world.cell_to_world(endpoint_cell))
	charge_hit_player = false
	_change_state("charging")

func _charge(delta: float) -> void:
	var from := global_position
	var collision := move_and_collide(charge_direction * CHARGE_SPEED * delta)
	var to := global_position
	if not charge_hit_player:
		var player_query := PhysicsRayQueryParameters2D.create(from, to)
		player_query.collision_mask = PLAYER_MASK
		player_query.collide_with_areas = false
		player_query.collide_with_bodies = true
		player_query.exclude = [get_rid()]
		var player_hit := get_world_2d().direct_space_state.intersect_ray(player_query)
		if not player_hit.is_empty():
			charge_hit_player = true
			target.take_damage(CHARGE_DAMAGE)
	if collision != null:
		_enter_stun()

func _enter_stun() -> void:
	_change_state("stunned")
	stunned.emit()

func _update_seed_volley(delta: float) -> void:
	if health * 2 >= MAX_HEALTH or state in ["emerging", "charging", "stunned"]:
		return
	seed_volley_timer -= delta
	if seed_volley_timer > 0.0:
		return
	seed_volley_timer = randf_range(SEED_VOLLEY_MIN_INTERVAL, SEED_VOLLEY_MAX_INTERVAL)
	_fire_seed_volley_layers()

func _fire_seed_volley_layers() -> void:
	for layer in range(3):
		if dead or not is_instance_valid(target) or target.dead:
			return
		var aim := target.global_position - global_position
		if aim.length_squared() < 0.01:
			aim = facing
		var center_angle := aim.angle() + randf_range(deg_to_rad(-12.0), deg_to_rad(12.0))
		var projectile_count := randi_range(5, 7)
		var directions: Array[Vector2] = []
		for index in range(projectile_count):
			var ratio := float(index) / float(projectile_count - 1)
			var angle := center_angle + lerpf(-SEED_VOLLEY_HALF_ANGLE, SEED_VOLLEY_HALF_ANGLE, ratio)
			directions.append(Vector2.RIGHT.rotated(angle))
		seed_volley_requested.emit(global_position, directions)
		if layer < 2:
			await get_tree().create_timer(0.2).timeout

func apply_knockback(direction: Vector2, strength: float = 52.0) -> void:
	if dead or state in ["charging", "stunned"] or direction.length_squared() < 0.01:
		return
	global_position += direction.normalized() * strength * 0.05

func take_damage(amount: int = 1) -> bool:
	if dead or amount <= 0:
		return false
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		dead = true
		collision_layer = 0
		velocity = Vector2.ZERO
		died.emit(global_position)
		queue_free()
	return true

func _draw() -> void:
	var emergence := clampf(state_elapsed / 0.8, 0.0, 1.0) if state == "emerging" else 1.0
	var petal_color := Color("#79a9bd") if state != "stunned" else Color("#969b83")
	draw_circle(Vector2(0, 16), 37.0 * emergence, Color(0.05, 0.1, 0.1, 0.32))
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var petal_center := Vector2.RIGHT.rotated(angle) * 22.0 * emergence
		draw_circle(petal_center, 18.0 * emergence, petal_color)
		draw_arc(petal_center, 18.0 * emergence, 0.0, TAU, 18, Color("#c4ece1"), 2.0)
	draw_circle(Vector2.ZERO, 22.0 * emergence, Color("#365c78") if state != "stunned" else Color("#777c68"))
	draw_circle(Vector2.ZERO, 10.0 * emergence, Color("#e2c965"))
	draw_circle(Vector2(-7, -3), 2.5, Color("#26353b"))
	draw_circle(Vector2(7, -3), 2.5, Color("#26353b"))
	if state == "charge_windup":
		draw_arc(Vector2.ZERO, 43.0, facing.angle() - 0.35, facing.angle() + 0.35, 10, Color("#ef8b6d"), 5.0)
	elif state == "charging":
		draw_line(-facing * 36.0, -facing * 62.0, Color("#d66b58"), 8.0)
	elif state == "stunned":
		draw_arc(Vector2.ZERO, 43.0, 0.0, TAU, 24, Color("#f3c969"), 3.0)
	if health * 2 < MAX_HEALTH and not dead:
		for index in range(5):
			var angle := TAU * float(index) / 5.0 + state_elapsed
			draw_circle(Vector2.RIGHT.rotated(angle) * 48.0, 3.0, Color("#f0d987"))
