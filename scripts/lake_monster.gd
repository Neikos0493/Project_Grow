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
const SPAWN_GRACE_DURATION := 1.0
const ATTACK_RANGE := 80.0
const CONTACT_DAMAGE_RANGE := 41.0
const CONTACT_DAMAGE_COOLDOWN := 0.6
const ATTACK_FRAME_COUNT := 8
const ATTACK_FRAME_TIME := 0.08
const ATTACK_PAUSE_DURATION := 0.1
const ATTACK_COOLDOWN := ATTACK_FRAME_TIME * ATTACK_FRAME_COUNT
const CHARGE_WINDUP := 0.28
const STUN_DURATION := 4.0
const MELEE_DAMAGE := 2
const CONTACT_DAMAGE := 1
const CHARGE_DAMAGE := 3
const ATTACKS_BEFORE_RUSH := 2
const SEED_VOLLEY_MIN_INTERVAL := 2.2
const SEED_VOLLEY_MAX_INTERVAL := 3.8
const SEED_VOLLEY_HALF_ANGLE := deg_to_rad(60.0)
const WARNING_DURATION := 0.36
const VOLLEY_WARNING_DURATION := 0.3
const WAIT_FPS := 4.0
const RUSH_WINDUP_DURATION := 0.28
const RUSH_END_DURATION := 0.12
const DEATH_FPS := 12.0
const DEATH_FRAME_COUNT := 16

const WATERLILY_WAIT := preload("res://image/waterlily/waterlily-change-wait-Sheet.png")
const WATERLILY_ATTACK := preload("res://image/waterlily/waterlily-change-attack-Sheet.png")
const WATERLILY_RUSH := preload("res://image/waterlily/waterlily-change-rush-Sheet.png")
const WATERLILY_DEATH := preload("res://image/waterlily/waterlily-change-death-Sheet.png")

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
var contact_damage_remaining := 0.0
var seed_volley_timer := 3.0
var seed_warning_active := false
var spawn_grace_remaining := 0.0
var rush_should_stun := false
var dead := false
var facing := Vector2.LEFT
var faces_left := true

var visual_sprite: Sprite2D
var warning_label: Label
var warning_remaining := 0.0
var warning_total := WARNING_DURATION

func setup(new_target: MeadowPlayer, new_world: MeadowWorld, spawn_map_position: Vector2) -> void:
	target = new_target
	world = new_world
	global_position = world.to_global(spawn_map_position)
	seed_volley_timer = randf_range(SEED_VOLLEY_MIN_INTERVAL, SEED_VOLLEY_MAX_INTERVAL)
	spawn_grace_remaining = SPAWN_GRACE_DURATION
	_update_visual()

func capture_state() -> Dictionary:
	var map_position := world.to_local(global_position) if is_instance_valid(world) else global_position
	var map_facing := world.global_direction_to_map(facing) if is_instance_valid(world) else facing
	map_facing = map_facing.normalized() if map_facing.length_squared() > 0.01 else Vector2.LEFT
	return {
		"kind": "lake_monster",
		"entity_id": entity_id,
		"position": [map_position.x, map_position.y],
		"health": clampi(health, 1, MAX_HEALTH),
		"state": state if state in ["emerging", "chase", "attack", "attack_pause", "charge_windup", "charging", "rush_windup", "rushing", "rush_end", "stunned"] else "chase",
		"stun_remaining": maxf(0.0, STUN_DURATION - state_elapsed) if state == "stunned" else 0.0,
		"state_elapsed": maxf(0.0, state_elapsed),
		"charge_direction": _direction_to_data(charge_direction),
		"charge_endpoint": _position_to_data(charge_endpoint),
		"charge_hit_player": charge_hit_player,
		"attacks_done": clampi(attacks_done, 0, ATTACKS_BEFORE_RUSH),
		"rush_should_stun": rush_should_stun,
		"contact_damage_remaining": maxf(0.0, contact_damage_remaining),
		"spawn_grace_remaining": clampf(spawn_grace_remaining, 0.0, SPAWN_GRACE_DURATION),
		"facing": [map_facing.x, map_facing.y],
		"faces_left": faces_left,
	}

func restore_state(data: Dictionary) -> void:
	entity_id = str(data.get("entity_id", ""))
	var fallback := world.to_local(global_position) if is_instance_valid(world) else global_position
	var map_position := _data_to_position(data.get("position", []), fallback)
	global_position = world.to_global(map_position) if is_instance_valid(world) else map_position
	health = clampi(int(data.get("health", MAX_HEALTH)), 1, MAX_HEALTH)
	var map_facing := _data_to_direction(data.get("facing", []), Vector2.LEFT)
	facing = world.map_direction_to_global(map_facing).normalized() if is_instance_valid(world) else map_facing
	faces_left = bool(data.get("faces_left", facing.x < 0.0))
	var saved_state := str(data.get("state", "chase"))
	if saved_state == "charge_windup":
		saved_state = "rush_windup"
	elif saved_state == "charging":
		saved_state = "rushing"
	var valid_states := ["emerging", "chase", "attack", "attack_pause", "rush_windup", "rushing", "rush_end", "stunned"]
	state = saved_state if saved_state in valid_states else "chase"
	spawn_grace_remaining = clampf(float(data.get("spawn_grace_remaining", 0.0)), 0.0, SPAWN_GRACE_DURATION)
	if state == "stunned":
		var remaining := clampf(float(data.get("stun_remaining", STUN_DURATION)), 0.0, STUN_DURATION)
		state_elapsed = STUN_DURATION - remaining
	else:
		state_elapsed = clampf(float(data.get("state_elapsed", 0.0)), 0.0, state_elapsed_limit(state))
	if state == "emerging" and spawn_grace_remaining <= 0.0:
		state = "chase"
		state_elapsed = 0.0
	dead = false
	attacks_done = clampi(int(data.get("attacks_done", 0)), 0, ATTACKS_BEFORE_RUSH)
	rush_should_stun = bool(data.get("rush_should_stun", false))
	contact_damage_remaining = clampf(float(data.get("contact_damage_remaining", 0.0)), 0.0, CONTACT_DAMAGE_COOLDOWN)
	var saved_charge_direction := _data_to_direction(data.get("charge_direction", []), Vector2.RIGHT)
	charge_direction = world.map_direction_to_global(saved_charge_direction).normalized() if is_instance_valid(world) else saved_charge_direction
	var charge_fallback := global_position + charge_direction * 128.0
	var saved_endpoint := _data_to_position(data.get("charge_endpoint", []), charge_fallback)
	charge_endpoint = world.to_global(saved_endpoint) if is_instance_valid(world) else saved_endpoint
	charge_hit_player = bool(data.get("charge_hit_player", false))
	attack_hit_resolved = false
	seed_warning_active = false
	velocity = Vector2.ZERO
	collision_layer = MONSTER_MASK
	_update_visual()

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

static func state_elapsed_limit(value: String) -> float:
	match value:
		"emerging":
			return 0.8
		"attack":
			return ATTACK_COOLDOWN
		"attack_pause":
			return ATTACK_PAUSE_DURATION
		"rush_windup":
			return RUSH_WINDUP_DURATION
		"rush_end":
			return RUSH_END_DURATION
		"stunned":
			return STUN_DURATION
		_:
			return 5.0

func _direction_to_data(direction: Vector2) -> Array[float]:
	var normalized := direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var map_direction := world.global_direction_to_map(normalized) if is_instance_valid(world) else normalized
	return [map_direction.x, map_direction.y]

func _position_to_data(position: Vector2) -> Array[float]:
	var map_position := world.to_local(position) if is_instance_valid(world) else position
	return [map_position.x, map_position.y]

func _ready() -> void:
	collision_layer = MONSTER_MASK
	collision_mask = WORLD_MASK | PLAYER_MASK
	var shape_node := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = BODY_SIZE
	shape_node.shape = rectangle
	add_child(shape_node)

	visual_sprite = Sprite2D.new()
	visual_sprite.name = "WaterLilySprite"
	visual_sprite.centered = true
	visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual_sprite.scale = Vector2.ONE * (64.0 / 48.0)
	add_child(visual_sprite)

	warning_label = Label.new()
	warning_label.name = "AttackWarning"
	warning_label.position = Vector2(-38.0, -70.0)
	warning_label.size = Vector2(76.0, 34.0)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_label.add_theme_color_override("font_color", Color("#ff3f45"))
	warning_label.add_theme_color_override("font_outline_color", Color("#4d0710"))
	warning_label.add_theme_constant_override("outline_size", 4)
	warning_label.add_theme_font_size_override("font_size", 28)
	warning_label.visible = false
	add_child(warning_label)
	_update_visual()

func _physics_process(delta: float) -> void:
	if dead:
		state_elapsed += delta
		_update_warning(delta)
		_update_visual()
		if state_elapsed >= float(DEATH_FRAME_COUNT) / DEATH_FPS:
			queue_free()
		return
	if spawn_grace_remaining > 0.0:
		if state == "emerging":
			state_elapsed += delta
			if state_elapsed >= 0.8:
				_change_state("chase")
		spawn_grace_remaining = maxf(0.0, spawn_grace_remaining - delta)
		velocity = Vector2.ZERO
		_update_warning(delta)
		_update_visual()
		return
	if not is_instance_valid(target) or target.dead:
		velocity = Vector2.ZERO
		_update_warning(delta)
		_update_visual()
		return
	state_elapsed += delta
	contact_damage_remaining = maxf(0.0, contact_damage_remaining - delta)
	_update_contact_damage()
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
		"attack_pause":
			velocity = Vector2.ZERO
			if state_elapsed >= ATTACK_PAUSE_DURATION:
				attacks_done += 1
				if attacks_done >= ATTACKS_BEFORE_RUSH:
					_start_rush_windup()
				else:
					_change_state("chase")
		"rush_windup":
			velocity = Vector2.ZERO
			if state_elapsed >= RUSH_WINDUP_DURATION:
				_begin_charge()
		"rushing":
			_charge(delta)
		"rush_end":
			velocity = Vector2.ZERO
			if state_elapsed >= RUSH_END_DURATION:
				if rush_should_stun:
					_enter_stun()
				else:
					attacks_done = 0
					_change_state("chase")
		"stunned":
			velocity = Vector2.ZERO
			if state_elapsed >= STUN_DURATION:
				attacks_done = 0
				_change_state("chase")
	_update_warning(delta)
	_update_visual()

func _change_state(next_state: String) -> void:
	state = next_state
	state_elapsed = 0.0
	attack_hit_resolved = false
	velocity = Vector2.ZERO
	_update_visual()

func _start_rush_windup() -> void:
	_show_warning("!")
	_change_state("rush_windup")

func _chase() -> void:
	var offset := target.global_position - global_position
	if offset.length_squared() < 0.01:
		velocity = Vector2.ZERO
		return
	facing = offset.normalized()
	if absf(offset.x) > 0.01:
		faces_left = offset.x < 0.0
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
		if absf(offset.x) > 0.01:
			faces_left = offset.x < 0.0
	var frame := _attack_frame()
	if not attack_hit_resolved and (frame == 4 or frame == 5) \
	and offset.length() <= ATTACK_RANGE:
		attack_hit_resolved = target.take_damage(MELEE_DAMAGE)
	if state_elapsed >= ATTACK_COOLDOWN:
		_change_state("attack_pause")

func _attack_frame() -> int:
	return clampi(int(state_elapsed / ATTACK_FRAME_TIME), 0, ATTACK_FRAME_COUNT - 1)

func _update_contact_damage() -> void:
	if contact_damage_remaining > 0.0 or not is_instance_valid(target) or target.dead:
		return
	if global_position.distance_to(target.global_position) <= CONTACT_DAMAGE_RANGE:
		if target.take_damage(CONTACT_DAMAGE):
			contact_damage_remaining = CONTACT_DAMAGE_COOLDOWN

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
	rush_should_stun = false
	collision_mask = WORLD_MASK
	_change_state("rushing")

func _charge(delta: float) -> void:
	var remaining_distance := global_position.distance_to(charge_endpoint)
	if remaining_distance <= 1.0:
		_finish_charge(false)
		return
	var step := minf(CHARGE_SPEED * delta, remaining_distance)
	var from := global_position
	var collision := move_and_collide(charge_direction * step)
	var to := global_position
	if not charge_hit_player and _is_player_in_rush_path(from, to):
		charge_hit_player = true
		target.take_damage(CHARGE_DAMAGE)
	if collision != null:
		var collider := collision.get_collider()
		var hit_world := collider is StaticBody2D
		_finish_charge(hit_world)
	elif global_position.distance_to(charge_endpoint) <= 1.0:
		_finish_charge(false)

func _is_player_in_rush_path(from: Vector2, to: Vector2) -> bool:
	if not is_instance_valid(target) or target.dead:
		return false
	var segment := to - from
	var segment_length_squared := segment.length_squared()
	var projection := 0.0
	if segment_length_squared > 0.01:
		projection = clampf((target.global_position - from).dot(segment) / segment_length_squared, 0.0, 1.0)
	var nearest := from.lerp(to, projection)
	if nearest.distance_to(target.global_position) <= CONTACT_DAMAGE_RANGE + 14.0:
		return true
	var player_query := PhysicsRayQueryParameters2D.create(from, to)
	player_query.collision_mask = PLAYER_MASK
	player_query.collide_with_areas = false
	player_query.collide_with_bodies = true
	player_query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(player_query).is_empty()

func _finish_charge(hit_world: bool) -> void:
	rush_should_stun = hit_world
	collision_mask = WORLD_MASK | PLAYER_MASK
	_change_state("rush_end")

func _show_warning(text: String) -> void:
	if not is_instance_valid(warning_label):
		return
	warning_label.text = text
	warning_total = WARNING_DURATION
	warning_remaining = WARNING_DURATION
	warning_label.modulate.a = 0.0
	warning_label.visible = true

func _update_warning(delta: float) -> void:
	if not is_instance_valid(warning_label) or warning_remaining <= 0.0:
		if is_instance_valid(warning_label):
			warning_label.visible = false
		return
	warning_remaining = maxf(0.0, warning_remaining - delta)
	var progress := 1.0 - warning_remaining / warning_total
	warning_label.modulate.a = sin(clampf(progress, 0.0, 1.0) * PI)
	warning_label.visible = warning_remaining > 0.0

func _enter_stun() -> void:
	_change_state("stunned")
	stunned.emit()

func _update_seed_volley(delta: float) -> void:
	if health * 2 >= MAX_HEALTH or state in ["emerging", "rush_windup", "rushing", "rush_end", "stunned"] or seed_warning_active:
		return
	seed_volley_timer -= delta
	if seed_volley_timer > 0.0:
		return
	seed_volley_timer = randf_range(SEED_VOLLEY_MIN_INTERVAL, SEED_VOLLEY_MAX_INTERVAL)
	seed_warning_active = true
	_show_warning("!!!")
	_start_seed_volley_after_warning()

func _start_seed_volley_after_warning() -> void:
	await get_tree().create_timer(VOLLEY_WARNING_DURATION).timeout
	if dead or not is_instance_valid(target) or target.dead \
	or state in ["rush_windup", "rushing", "rush_end", "stunned"]:
		seed_warning_active = false
		return
	seed_warning_active = false
	_fire_seed_volley_layers()

func _fire_seed_volley_layers() -> void:
	for layer in range(3):
		if dead or not is_instance_valid(target) or target.dead \
		or state in ["rush_windup", "rushing", "rush_end", "stunned"]:
			seed_warning_active = false
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
	if dead or spawn_grace_remaining > 0.0 or state in ["rushing", "rush_end", "stunned"] or direction.length_squared() < 0.01:
		return
	global_position += direction.normalized() * strength * 0.05

func get_damage_number_position() -> Vector2:
	return global_position + Vector2(0, -54)

func take_damage(amount: int = 1) -> bool:
	if dead or spawn_grace_remaining > 0.0 or amount <= 0:
		return false
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		dead = true
		state = "death"
		state_elapsed = 0.0
		collision_layer = 0
		collision_mask = 0
		velocity = Vector2.ZERO
		seed_warning_active = false
		warning_remaining = 0.0
		if is_instance_valid(warning_label):
			warning_label.visible = false
		died.emit(global_position)
	_update_visual()
	return true

func _update_visual() -> void:
	if not is_instance_valid(visual_sprite):
		return
	var texture: Texture2D = WATERLILY_WAIT
	var frame_count := 2
	var frame := 0
	match state:
		"attack":
			texture = WATERLILY_ATTACK
			frame_count = ATTACK_FRAME_COUNT
			frame = _attack_frame()
		"rush_windup":
			texture = WATERLILY_RUSH
			frame_count = 4
			frame = 1 if state_elapsed < RUSH_WINDUP_DURATION * 0.45 else 0
		"rushing":
			texture = WATERLILY_RUSH
			frame_count = 4
			frame = 2
		"rush_end":
			texture = WATERLILY_RUSH
			frame_count = 4
			frame = 3
		"death":
			texture = WATERLILY_DEATH
			frame_count = DEATH_FRAME_COUNT
			frame = clampi(int(state_elapsed * DEATH_FPS), 0, DEATH_FRAME_COUNT - 1)
		_:
			texture = WATERLILY_WAIT
			frame_count = 2
			frame = int(state_elapsed * WAIT_FPS) % frame_count
	visual_sprite.texture = texture
	visual_sprite.hframes = frame_count
	visual_sprite.vframes = 1
	visual_sprite.frame = clampi(frame, 0, frame_count - 1)
	visual_sprite.flip_h = faces_left
