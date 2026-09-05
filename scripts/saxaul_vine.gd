class_name MeadowSaxaulVine
extends StaticBody2D
## Persistent three-health vine minion spawned by the saxaul boss.

signal laser_requested(origin: Vector2, directions: Array[Vector2])
signal died(vine: MeadowSaxaulVine)

const PLANT_MASK := 4
const WORLD_MASK := 1
const MAX_HEALTH := 3
const FIRE_INTERVAL := 0.75
const LASER_SPEED := 520.0
const LASER_LENGTH := 72.0

var target: MeadowPlayer
var health := MAX_HEALTH
var fire_timer := 0.35
var dead := false
var phase := 0.0

func setup(player_target: MeadowPlayer) -> void:
	target = player_target
	queue_redraw()

func _ready() -> void:
	collision_layer = PLANT_MASK
	collision_mask = WORLD_MASK
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape_node.shape = circle
	add_child(shape_node)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	phase += delta
	if not is_instance_valid(target) or target.dead:
		return
	fire_timer -= delta
	if fire_timer > 0.0:
		queue_redraw()
		return
	fire_timer = FIRE_INTERVAL
	var direction := target.global_position - global_position
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	var center_angle := direction.angle()
	var directions: Array[Vector2] = []
	for index in range(3):
		var ratio := float(index) / 2.0
		var angle := center_angle + lerpf(-PI / 6.0, PI / 6.0, ratio)
		directions.append(Vector2.RIGHT.rotated(angle))
	laser_requested.emit(global_position, directions)
	queue_redraw()

func take_damage(amount: int = 1) -> bool:
	if dead or amount <= 0:
		return false
	health = maxi(0, health - amount)
	queue_redraw()
	if health == 0:
		dead = true
		collision_layer = 0
		died.emit(self)
		queue_free()
	return true

func _draw() -> void:
	draw_circle(Vector2(0, 5), 15.0, Color(0.05, 0.1, 0.1, 0.32))
	draw_line(Vector2(0, 8), Vector2(0, -12), Color("#73513a"), 6.0)
	draw_circle(Vector2(-6, -12), 8.0, Color("#6f9b4d"))
	draw_circle(Vector2(6, -10), 8.0, Color("#8eb75c"))
	draw_arc(Vector2.ZERO, 17.0 + sin(phase * 5.0) * 1.5, 0.0, TAU, 20, Color("#f3c969"), 2.0)
	for index in range(health):
		draw_circle(Vector2(-7 + index * 7, -25), 2.0, Color("#f0d987"))
