class_name MeadowLakeMonster
extends CharacterBody2D
## Procedural lake monster with pursuit, melee, charge, and stun states.

signal died(position: Vector2)
signal stunned
signal health_changed(current: int, maximum: int)

const WORLD_MASK := 1
const PLAYER_MASK := 2
const MONSTER_MASK := 16
const MAX_HEALTH := 12
const MOVE_SPEED := 70.0
const CHARGE_SPEED := 410.0
const ATTACK_RANGE := 30.0
const ATTACK_WINDUP := 0.2
const ATTACK_COOLDOWN := 0.4
const CHARGE_WINDUP := 0.35
const STUN_DURATION := 2.4
const MELEE_DAMAGE := 2
const CHARGE_DAMAGE := 4

var entity_id := ""
var target: MeadowPlayer
var world: MeadowWorld
var health := MAX_HEALTH
var state := "emerging"
var state_elapsed := 0.0
var attacks_done := 0
var attacks_before_charge := 1
var charge_endpoint := Vector2.ZERO
var charge_direction := Vector2.RIGHT
var charge_hit_player := false
var attack_hit_resolved := false
var dead := false
var facing := Vector2.LEFT

func setup(new_target: MeadowPlayer, new_world: MeadowWorld, spawn_map_position: Vector2) -> void:
	target = new_target
	world = new_world
	global_position = world.to_global(spawn_map_position)
	attacks_before_charge = randi_range(1, 2)
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
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape_node.shape = circle
	add_child(shape_node)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(target) or target.dead:
		velocity = Vector2.ZERO
		return
	state_elapsed += delta
	match state:
		"emerging":
			velocity = Vector2.ZERO
			if state_elapsed >= 0.65:
				_change_state("chase")
		"chase":
			_chase()
		"attack":
			_attack(delta)
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
		return
	facing = offset.normalized()
	if offset.length() <= ATTACK_RANGE:
		_change_state("attack")
		return
	velocity = facing * MOVE_SPEED
	move_and_slide()

func _attack(_delta: float) -> void:
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

func _begin_charge() -> void:
	var offset := target.global_position - global_position
	if offset.length_squared() < 0.01:
		offset = facing
	var map_offset := world.global_direction_to_map(offset).normalized()
	var map_charge_direction := _grid_direction(map_offset)
	charge_direction = world.map_direction_to_global(map_charge_direction).normalized()
	facing = charge_direction
	var trigger_cell := world.world_to_cell(world.to_local(target.global_position))
	var endpoint_step := Vector2i(roundi(map_charge_direction.x), roundi(map_charge_direction.y)) * 2
	var endpoint_cell := trigger_cell + endpoint_step
	# Keep the planned endpoint inside the playable map; obstacles can still stop it earlier.
	endpoint_cell.x = clampi(endpoint_cell.x, 1, world.MAP_SIZE.x - 2)
	endpoint_cell.y = clampi(endpoint_cell.y, 1, world.MAP_SIZE.y - 2)
	charge_endpoint = world.to_global(world.cell_to_world(endpoint_cell))
	charge_hit_player = false
	_change_state("charging")

func _grid_direction(direction: Vector2) -> Vector2:
	var result := Vector2(signf(direction.x), signf(direction.y))
	if result.length_squared() < 0.01:
		return Vector2.RIGHT
	return result.normalized()

func _charge(delta: float) -> void:
	var from := global_position
	var step := charge_direction * CHARGE_SPEED * delta
	var reached_endpoint := from.distance_to(charge_endpoint) <= step.length()
	var to := charge_endpoint if reached_endpoint else from + step
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = WORLD_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var obstacle := space.intersect_ray(query)
	if not obstacle.is_empty():
		global_position = obstacle["position"] - charge_direction * 4.0
		_enter_stun()
		return
	if not charge_hit_player:
		var player_query := PhysicsRayQueryParameters2D.create(from, to)
		player_query.collision_mask = PLAYER_MASK
		player_query.collide_with_areas = false
		player_query.collide_with_bodies = true
		player_query.exclude = [get_rid()]
		var player_hit := space.intersect_ray(player_query)
		if not player_hit.is_empty():
			charge_hit_player = true
			target.take_damage(CHARGE_DAMAGE)
	global_position = to
	if reached_endpoint or world.world_to_cell(world.to_local(global_position)) == world.world_to_cell(world.to_local(charge_endpoint)):
		global_position = charge_endpoint
		attacks_done = 0
		_change_state("chase")

func _enter_stun() -> void:
	_change_state("stunned")
	stunned.emit()

func apply_knockback(direction: Vector2, strength: float = 52.0) -> void:
	if dead or state == "charging" or state == "stunned":
		return
	global_position += direction.normalized() * strength * 0.12

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
	return true

func _draw() -> void:
	var pulse := 1.0 + 0.08 * sin(state_elapsed * 8.0)
	var radius := 15.0 * pulse if state != "emerging" else 10.0 + state_elapsed * 8.0
	draw_circle(Vector2(0, 6), radius + 3.0, Color(0.05, 0.1, 0.1, 0.3))
	draw_circle(Vector2.ZERO, radius, Color("#365c78") if state != "stunned" else Color("#777c68"))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color("#b7e7de"), 2.0)
	draw_circle(Vector2(-5, -3), 3.0, Color("#f2d16f"))
	draw_circle(Vector2(5, -3), 3.0, Color("#f2d16f"))
	draw_circle(Vector2(-5, -3), 1.0, Color("#26353b"))
	draw_circle(Vector2(5, -3), 1.0, Color("#26353b"))
	if state == "charging":
		draw_line(-facing * 22.0, -facing * 34.0, Color("#d66b58"), 4.0)
	elif state == "stunned":
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 18, Color("#f3c969"), 2.0)
