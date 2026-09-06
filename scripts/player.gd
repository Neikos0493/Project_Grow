class_name MeadowPlayer
extends CharacterBody2D
## Responsive movement, direction-based actions, and player health.

signal interaction_requested
signal fire_requested(origin: Vector2, direction: Vector2)
signal health_changed(current: int, maximum: int)
signal died

const MOVE_SPEED := 150.0
const MOVE_ACCELERATION := 720.0
const MOVE_DECELERATION := 980.0
const MAX_HEALTH := 5
const CHARACTER_FRAME_COUNT := 4
const CHARACTER_ANIMATION_FPS := 8.0
const OUT_OF_COMBAT_DELAY := 1.0
const HIT_SOUND := preload("res://sound/角色受击音效.mp3")
const INVINCIBILITY_DURATION := 1.0
const HIT_FLASH_INTERVAL := 0.1

const CHARACTER_SHEETS := {
	"idle_down": ["res://image/Character/character-wait-Sheet.png", 22, 31],
	"idle_up": ["res://image/Character/character-wait-back-Sheet.png", 22, 31],
	"idle_left": ["res://image/Character/character-wait-left-Sheet.png", 22, 32],
	"idle_right": ["res://image/Character/character-wait-right-Sheet.png", 22, 32],
	"walk_down": ["res://image/Character/charcter-walk-Sheet.png", 22, 32],
	"walk_up": ["res://image/Character/charcter-walk-back-Sheet.png", 22, 32],
	"walk_left": ["res://image/Character/character-walk-left-Sheet.png", 21, 28],
	"walk_right": ["res://image/Character/character-walk-right-Sheet.png", 21, 28],
}

@onready var character_sprite: AnimatedSprite2D = $CharacterSprite

var hit_sound_player: AudioStreamPlayer
var facing := Vector2.DOWN
var health := MAX_HEALTH
var dead := false
var time_since_damage := OUT_OF_COMBAT_DELAY
var invincibility_remaining := 0.0
var hit_flash_elapsed := 0.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hit_sound_player = AudioStreamPlayer.new()
	hit_sound_player.stream = HIT_SOUND
	hit_sound_player.volume_db = -2.0
	add_child(hit_sound_player)
	_build_character_animations()
	_update_character_animation()
	queue_redraw()
	health_changed.emit(health, MAX_HEALTH)

func _physics_process(delta: float) -> void:
	if invincibility_remaining > 0.0:
		invincibility_remaining = maxf(0.0, invincibility_remaining - delta)
		hit_flash_elapsed += delta
		modulate = Color(1.0, 1.0, 1.0, 0.35) if int(hit_flash_elapsed / HIT_FLASH_INTERVAL) % 2 == 0 else Color.WHITE
	else:
		modulate = Color.WHITE
	if not dead:
		time_since_damage += delta
	if controls_locked or dead:
		velocity = velocity.move_toward(Vector2.ZERO, MOVE_DECELERATION * delta)
		_update_character_animation()
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not Input.is_action_pressed("fire") and input_direction.length_squared() > 0.01:
		_set_facing(input_direction)
	elif Input.is_action_pressed("fire"):
		_update_pointer_facing()
	var target_velocity := input_direction * MOVE_SPEED
	var response := MOVE_ACCELERATION if input_direction.length_squared() > 0.0 else MOVE_DECELERATION
	velocity = velocity.move_toward(target_velocity, response * delta)
	move_and_slide()
	_update_character_animation()

func _set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		return
	var next_facing := direction.normalized()
	if facing.is_equal_approx(next_facing):
		return
	facing = next_facing
	_update_character_animation()
	queue_redraw()

func set_attack_facing(direction: Vector2) -> void:
	_set_facing(direction)

func _update_pointer_facing() -> void:
	var pointer_direction := get_global_mouse_position() - global_position
	if pointer_direction.length_squared() > 0.01:
		_set_facing(pointer_direction)

func _build_character_animations() -> void:
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	for animation_name in CHARACTER_SHEETS:
		var sheet_data: Array = CHARACTER_SHEETS[animation_name]
		var texture := load(sheet_data[0]) as Texture2D
		if texture == null:
			push_error("Could not load character sheet: %s" % sheet_data[0])
			continue
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_speed(animation_name, CHARACTER_ANIMATION_FPS)
		sprite_frames.set_animation_loop(animation_name, true)
		for frame_index in range(CHARACTER_FRAME_COUNT):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(frame_index * sheet_data[1], 0, sheet_data[1], sheet_data[2])
			sprite_frames.add_frame(animation_name, atlas)
	character_sprite.sprite_frames = sprite_frames

func _update_character_animation() -> void:
	if not is_instance_valid(character_sprite) or character_sprite.sprite_frames == null:
		return
	var direction := _cardinal_direction(facing)
	var moving := velocity.length_squared() > 20.0 and not controls_locked and not dead
	var animation_name := ("walk_" if moving else "idle_") + direction
	if character_sprite.animation != animation_name:
		character_sprite.play(animation_name)
	elif not character_sprite.is_playing():
		character_sprite.play()

func _cardinal_direction(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	var key_event := event as InputEventKey
	if event.is_action_pressed("interact") and (key_event == null or not key_event.echo):
		interaction_requested.emit()
		get_viewport().set_input_as_handled()
		return
	# Main handles normal gameplay clicks so it can support held weapons. Keep
	# this fallback for standalone use of the player scene.
	if not controls_locked and event.is_action_pressed("fire") and (key_event == null or not key_event.echo):
		var aim := get_global_mouse_position() - global_position
		if aim.length_squared() > 0.01:
			fire_requested.emit(global_position, aim.normalized())

func restore_state(saved_health: int) -> void:
	invincibility_remaining = 0.0
	hit_flash_elapsed = 0.0
	modulate = Color.WHITE
	health = clampi(saved_health, 0, MAX_HEALTH)
	time_since_damage = OUT_OF_COMBAT_DELAY
	dead = health == 0
	controls_locked = dead
	velocity = Vector2.ZERO
	_update_character_animation()
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()

func take_damage(amount: int = 1) -> bool:
	if dead or invincibility_remaining > 0.0 or amount <= 0:
		return false
	invincibility_remaining = INVINCIBILITY_DURATION
	hit_flash_elapsed = 0.0
	time_since_damage = 0.0
	health = maxi(0, health - amount)
	if is_instance_valid(hit_sound_player):
		hit_sound_player.play()
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	if health == 0:
		dead = true
		controls_locked = true
		_update_character_animation()
		died.emit()
	return true

func heal(amount: int = 1) -> bool:
	if dead or amount <= 0 or health >= MAX_HEALTH:
		return false
	var previous_health := health
	health = mini(MAX_HEALTH, health + amount)
	if health == previous_health:
		return false
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	return true

func is_out_of_combat() -> bool:
	return not dead and time_since_damage >= OUT_OF_COMBAT_DELAY

func respawn_at(spawn_global_position: Vector2) -> bool:
	if not dead:
		return false
	invincibility_remaining = 0.0
	hit_flash_elapsed = 0.0
	modulate = Color.WHITE
	global_position = spawn_global_position
	velocity = Vector2.ZERO
	health = MAX_HEALTH
	time_since_damage = OUT_OF_COMBAT_DELAY
	dead = false
	controls_locked = false
	_update_character_animation()
	health_changed.emit(health, MAX_HEALTH)
	queue_redraw()
	return true

func _draw() -> void:
	# Keep the shadow on the ground while the sprite is visually lifted above it.
	draw_shadow_ellipse(Vector2(0, 13), Vector2(14, 5), Color(0.05, 0.1, 0.1, 0.34))

func draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
