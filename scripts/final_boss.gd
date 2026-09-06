class_name MeadowFinalBoss
extends CharacterBody2D
## Final boss summoned by the World Tree redemption event.

signal projectile_requested(origin: Vector2, direction: Vector2, speed: float, homing: bool)
signal summon_requested(phase: int)
signal phase_changed(phase: int)
signal health_changed(current: int, maximum: int)
signal died(position: Vector2)

const MAX_HEALTH := MeadowLakeMonster.MAX_HEALTH * 10
const MOVE_SPEED := 72.0
const PHASE_TWO_MOVE_SPEED := 108.0
const BASE_BULLET_SPEED := 180.0
const PHASE_TWO_BULLET_SPEED := BASE_BULLET_SPEED * 2.0
const CONTACT_DAMAGE := 2
const CONTACT_COOLDOWN := 0.8
const PHASE_ONE_INTERVAL := 0.85
const PHASE_TWO_INTERVAL := 0.425
const PHASE_THREE_INTERVAL := 1.0 / 60.0
const ATTACK_RANGE := 150.0 * MeadowWorld.TILE_SIZE
const FALL_GRACE := 1.25
const WORLD_MASK := 1
const PLAYER_MASK := 2
const HIT_FLASH_DURATION := 0.18
const HIT_FLASH_INTERVAL := 0.06
const FINAL_BOSS_TEXTURE := preload("res://assets/Hu1.png")

var target: MeadowPlayer
var world: MeadowWorld
var health := MAX_HEALTH
var dead := false
var active := false
var fall_grace_remaining := FALL_GRACE
var attack_elapsed := 0.0
var rotation_angle := 0.0
var contact_remaining := 0.0
var entity_id := ""
var current_phase := 1
var phase_two_summoned := false
var phase_three_summoned := false
var visual_sprite: Sprite2D
var hit_flash_remaining := 0.0
var hit_flash_elapsed := 0.0

func setup(new_target: MeadowPlayer, new_world: MeadowWorld) -> void:
	target = new_target
	world = new_world
	collision_layer = 4
	collision_mask = WORLD_MASK | PLAYER_MASK
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func capture_state() -> Dictionary:
	var map_position := world.to_local(global_position) if is_instance_valid(world) else global_position
	# Never persist the falling tween's off-map position. A close or autosave during
	# the landing animation must resume as a playable, active encounter.
	if not active:
		map_position = world.cell_to_world(Vector2i(20, 7)) if is_instance_valid(world) else map_position
	return {
		"kind": "sky_boss",
		"entity_id": entity_id,
		"cell": [20, 7],
		"position": [map_position.x, map_position.y],
		"health": clampi(health, 1, MAX_HEALTH),
		"active": true,
		"fall_grace_remaining": FALL_GRACE if not active else clampf(fall_grace_remaining, 0.0, FALL_GRACE),
		"attack_elapsed": 0.0 if not active else maxf(0.0, attack_elapsed),
		"rotation_angle": 0.0 if not active else rotation_angle,
		"current_phase": 1 if not active else clampi(current_phase, 1, 3),
		"phase_two_summoned": false if not active else phase_two_summoned,
		"phase_three_summoned": false if not active else phase_three_summoned,
		"contact_remaining": 0.0 if not active else maxf(0.0, contact_remaining),
	}

func restore_state(data: Dictionary) -> void:
	var fallback := world.cell_to_world(Vector2i(20, 7)) if is_instance_valid(world) else global_position
	var value: Variant = data.get("position", [])
	var map_position := fallback
	if value is Array and value.size() == 2:
		var candidate := Vector2(float(value[0]), float(value[1]))
		if is_finite(candidate.x) and is_finite(candidate.y):
			map_position = candidate
	global_position = world.to_global(map_position) if is_instance_valid(world) else map_position
	health = clampi(int(data.get("health", MAX_HEALTH)), 1, MAX_HEALTH)
	active = bool(data.get("active", true))
	fall_grace_remaining = clampf(float(data.get("fall_grace_remaining", FALL_GRACE)), 0.0, FALL_GRACE)
	if not active:
		active = true
		fall_grace_remaining = FALL_GRACE
	attack_elapsed = maxf(0.0, float(data.get("attack_elapsed", 0.0)))
	rotation_angle = fmod(float(data.get("rotation_angle", 0.0)), TAU)
	if rotation_angle < 0.0:
		rotation_angle += TAU
	current_phase = clampi(int(data.get("current_phase", _get_phase())), 1, 3)
	phase_two_summoned = bool(data.get("phase_two_summoned", false))
	phase_three_summoned = bool(data.get("phase_three_summoned", false))
	contact_remaining = clampf(float(data.get("contact_remaining", 0.0)), 0.0, CONTACT_COOLDOWN)
	dead = false
	velocity = Vector2.ZERO
	collision_layer = 4
	collision_mask = WORLD_MASK | PLAYER_MASK
	queue_redraw()

func activate() -> void:
	active = true
	fall_grace_remaining = FALL_GRACE
	attack_elapsed = 0.0
	queue_redraw()

func _ready() -> void:
	visual_sprite = Sprite2D.new()
	visual_sprite.name = "FinalBossSprite"
	visual_sprite.texture = FINAL_BOSS_TEXTURE
	visual_sprite.hframes = 5
	visual_sprite.frame = 0
	visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual_sprite.scale = Vector2.ONE * 1.15
	add_child(visual_sprite)
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	collision_shape.shape = circle
	add_child(collision_shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead or not active:
		return
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	if hit_flash_remaining > 0.0:
		hit_flash_elapsed += delta
		modulate = Color("#ff4b4b") if int(hit_flash_elapsed / HIT_FLASH_INTERVAL) % 2 == 0 else Color.WHITE
	else:
		modulate = Color.WHITE
	if is_instance_valid(visual_sprite):
		visual_sprite.frame = int(Time.get_ticks_msec() / 125) % 5
	if fall_grace_remaining > 0.0:
		fall_grace_remaining = maxf(0.0, fall_grace_remaining - delta)
		return
	if not is_instance_valid(target) or target.dead:
		return
	contact_remaining = maxf(0.0, contact_remaining - delta)
	var phase := _get_phase()
	if phase != current_phase:
		current_phase = phase
		phase_changed.emit(phase)
		if phase == 2 and not phase_two_summoned:
			phase_two_summoned = true
			summon_requested.emit(2)
		elif phase == 3 and not phase_three_summoned:
			phase_three_summoned = true
			summon_requested.emit(3)
	if phase < 3:
		var offset := target.global_position - global_position
		velocity = offset.normalized() * (MOVE_SPEED if phase == 1 else PHASE_TWO_MOVE_SPEED) if offset.length_squared() > 1.0 else Vector2.ZERO
		move_and_slide()
		if contact_remaining <= 0.0 and global_position.distance_to(target.global_position) <= 42.0:
			if target.take_damage(CONTACT_DAMAGE):
				contact_remaining = CONTACT_COOLDOWN
	else:
		velocity = Vector2.ZERO
	attack_elapsed += delta
	if global_position.distance_to(target.global_position) > ATTACK_RANGE:
		queue_redraw()
		return
	var interval := PHASE_ONE_INTERVAL if phase == 1 else PHASE_TWO_INTERVAL if phase == 2 else PHASE_THREE_INTERVAL
	while attack_elapsed >= interval:
		attack_elapsed -= interval
		_fire_for_phase(phase)
	queue_redraw()

func _get_phase() -> int:
	var ratio := float(health) / float(MAX_HEALTH)
	if ratio > 0.5:
		return 1
	if ratio > 0.2:
		return 2
	return 3

func _fire_for_phase(phase: int) -> void:
	if phase == 3:
		var direction := Vector2.RIGHT.rotated(rotation_angle)
		rotation_angle = fmod(rotation_angle + deg_to_rad(11.0), TAU)
		projectile_requested.emit(global_position, direction, BASE_BULLET_SPEED, false)
		return
	var bullet_speed := BASE_BULLET_SPEED if phase == 1 else PHASE_TWO_BULLET_SPEED
	var homing := false
	var bullet_count := 8 if phase == 1 else 12
	var volley_rotation := 0.0 if phase == 1 else rotation_angle
	if phase == 2:
		rotation_angle = fmod(rotation_angle + deg_to_rad(11.0), TAU)
	for index in range(bullet_count):
		var direction := Vector2.RIGHT.rotated(volley_rotation + TAU * float(index) / float(bullet_count))
		projectile_requested.emit(global_position, direction, bullet_speed, homing)

func take_damage(amount: int) -> bool:
	if dead or not active or amount <= 0:
		return false
	health = maxi(0, health - amount)
	hit_flash_remaining = HIT_FLASH_DURATION
	hit_flash_elapsed = 0.0
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	if health <= 0:
		dead = true
		velocity = Vector2.ZERO
		died.emit(global_position)
		queue_free()
	return true

func get_damage_number_position() -> Vector2:
	return global_position + Vector2(0, -62)

func _draw() -> void:
	var phase := _get_phase()
	var phase_color := Color("#8d56c9") if phase == 1 else Color("#d45c87") if phase == 2 else Color("#e24e4e")
	draw_circle(Vector2(0, 24), 34.0, Color(0.05, 0.1, 0.1, 0.42))
	draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 32, phase_color, 3.0, true)
