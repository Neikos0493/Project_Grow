class_name MeadowMapDecorations
extends Node2D
## Draws authored map props above the editable terrain TileMap.

@export var world_path: NodePath = NodePath("..")
@onready var world: MeadowWorld = get_node(world_path) as MeadowWorld

func _ready() -> void:
	z_index = 2
	if is_instance_valid(world) and not world.state_changed.is_connected(queue_redraw):
		world.state_changed.connect(queue_redraw)
	queue_redraw()

func _process(_delta: float) -> void:
	# Keeps animated ship flame and stateful props in sync with the map.
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world):
		return
	for prop in world.props:
		if str(prop.get("kind", "")) == "pea_npc" and not world.enable_pea_npc:
			continue
		if str(prop.get("kind", "")) != "shop":
			_draw_prop(prop)
	for drop in world.drops:
		_draw_drop(drop)
	for cell in world.farm_tiles:
		_draw_farm_tile(cell, world.farm_tiles[cell])
	for cell in world.water_growth:
		_draw_water_growth_cell(cell, world.water_growth[cell])

func _draw_prop(prop: Dictionary) -> void:
	var center: Vector2 = world.cell_to_world(prop["cell"])
	var outline := Color("#26353b")
	match str(prop.get("kind", "")):
		"mailbox":
			draw_line(center + Vector2(0, 10), center + Vector2(0, -3), outline, 3.0)
			draw_rect(Rect2(center + Vector2(-10, -11), Vector2(20, 10)), Color("#d56b54"), true)
			draw_rect(Rect2(center + Vector2(-10, -11), Vector2(20, 10)), outline, false, 2.0)
			draw_circle(center + Vector2(7, -6), 2.0, Color("#f6d27d"))
		"notice":
			draw_line(center + Vector2(-7, 11), center + Vector2(-7, -5), outline, 3.0)
			draw_line(center + Vector2(7, 11), center + Vector2(7, -5), outline, 3.0)
			draw_rect(Rect2(center + Vector2(-13, -11), Vector2(26, 14)), Color("#d8b56d"), true)
			draw_rect(Rect2(center + Vector2(-13, -11), Vector2(26, 14)), outline, false, 2.0)
			draw_line(center + Vector2(-8, -6), center + Vector2(8, -6), Color("#755b42"), 1.0)
			draw_line(center + Vector2(-8, -2), center + Vector2(4, -2), Color("#755b42"), 1.0)
		"crate":
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), Color("#9d704c"), true)
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), outline, false, 2.0)
			if bool(prop.get("used", false)):
				draw_line(center + Vector2(-10, -7), center + Vector2(10, -12), Color("#e0bc73"), 3.0)
			else:
				draw_line(center + Vector2(-8, -7), center + Vector2(8, 7), Color("#d4a666"), 2.0)
				draw_line(center + Vector2(8, -7), center + Vector2(-8, 7), Color("#d4a666"), 2.0)
		"lake_npc":
			_draw_flat_ellipse(center + Vector2(0, 10), Vector2(13, 5), Color(0.05, 0.1, 0.1, 0.3))
			draw_circle(center + Vector2(0, -5), 9.0, Color("#d6a36c"))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, -7), center + Vector2(0, -21), center + Vector2(13, -7)]), Color("#315c70"))
			draw_line(center + Vector2(0, 1), center + Vector2(0, 12), Color("#315c70"), 8.0)
			draw_line(center + Vector2(6, 3), center + Vector2(13, 13), Color("#8b633f"), 2.0)
			draw_circle(center + Vector2(15, 14), 3.0, Color("#6fcfe1"))
		"ranger":
			_draw_flat_ellipse(center + Vector2(0, 10), Vector2(13, 5), Color(0.05, 0.1, 0.1, 0.3))
			draw_circle(center + Vector2(0, -5), 9.0, Color("#d6a36c"))
			draw_rect(Rect2(center + Vector2(-13, -13), Vector2(26, 7)), Color("#b56b3b"), true)
			draw_rect(Rect2(center + Vector2(-10, -18), Vector2(20, 7)), Color("#b56b3b"), true)
			draw_line(center + Vector2(0, 1), center + Vector2(0, 12), Color("#3e7650"), 8.0)
		"lookout":
			draw_line(center + Vector2(0, 10), center + Vector2(0, -14), Color("#5a4938"), 3.0)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -14), center + Vector2(18, -9), center + Vector2(0, -4)]), Color("#d5b15f"))
			draw_line(center + Vector2(-20, 8), center + Vector2(20, 8), Color("#5a4938"), 2.0)
		"spaceship":
			_draw_spaceship(center + world.ship_transition_offset, outline)

func _draw_spaceship(center: Vector2, outline: Color) -> void:
	_draw_flat_ellipse(center + Vector2(0, 9), Vector2(20, 5), Color(0.05, 0.1, 0.1, 0.3))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-24, 2), center + Vector2(-12, -10), center + Vector2(13, -10), center + Vector2(24, 2), center + Vector2(12, 10), center + Vector2(-13, 10)]), Color("#d9e2cf"))
	draw_polyline(PackedVector2Array([center + Vector2(-24, 2), center + Vector2(-12, -10), center + Vector2(13, -10), center + Vector2(24, 2), center + Vector2(12, 10), center + Vector2(-13, 10), center + Vector2(-24, 2)]), outline, 2.0, true)
	draw_circle(center + Vector2(0, -1), 7.0, Color("#3e86a5"))
	draw_circle(center + Vector2(0, -2), 3.0, Color("#e7c66d"))
	if world.ship_flame_length > 0.0:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 10), center + Vector2(0, 10 + world.ship_flame_length), center + Vector2(8, 10)]), Color("#d66b58"))
		draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 10), center + Vector2(0, 8 + world.ship_flame_length * 0.7), center + Vector2(4, 10)]), Color("#f3c969"))
	draw_line(center + Vector2(-15, 7), center + Vector2(-20, 14), Color("#d66b58"), 3.0)
	draw_line(center + Vector2(15, 7), center + Vector2(20, 14), Color("#d66b58"), 3.0)

func _draw_farm_tile(cell: Vector2i, farm: Dictionary) -> void:
	var tile_size := MeadowWorld.TILE_SIZE
	var rect := Rect2(Vector2(cell) * tile_size + Vector2(3, 3), Vector2(tile_size - 6, tile_size - 6))
	draw_rect(rect, Color("#8d603f"), true)
	draw_rect(rect, Color("#d0a36a"), false, 2.0)
	for row in range(3):
		var y := rect.position.y + 7.0 + row * 7.0
		draw_line(Vector2(rect.position.x + 4, y), Vector2(rect.end.x - 4, y), Color("#704a38"), 1.0)
	var state := int(farm.get("state", MeadowWorld.FARM_TILLED))
	if state == MeadowWorld.FARM_SEEDED:
		draw_circle(world.cell_to_world(cell) + Vector2(-5, 2), 2.5, Color("#59b35b"))
		draw_circle(world.cell_to_world(cell) + Vector2(5, 4), 2.5, Color("#4d9b4f"))
	elif state == MeadowWorld.FARM_MATURE:
		draw_circle(world.cell_to_world(cell) + Vector2(0, -2), 4.0, Color("#2e8249"))

func _draw_water_growth_cell(cell: Vector2i, growth: Dictionary) -> void:
	var tile_size := MeadowWorld.TILE_SIZE
	var rect := Rect2(Vector2(cell) * tile_size + Vector2(2, 2), Vector2(tile_size - 4, tile_size - 4))
	var state := int(growth.get("state", 0))
	var color := Color("#275d78") if state == 0 else Color("#287d89")
	if state >= 2:
		color = Color("#3b9ba0")
	draw_rect(rect, Color(color, 0.72), true)
	draw_rect(rect, Color("#8de0d0", 0.85), false, 2.0)
	var center := world.cell_to_world(cell)
	if state == 0:
		draw_circle(center, 4.0, Color("#b6e8ff"))
		draw_arc(center, 9.0, 0.0, TAU, 16, Color("#6fcfe1", 0.8), 1.5)
	else:
		draw_line(center + Vector2(-8, 4), center + Vector2(-2, -7), Color("#8de0d0"), 2.0)
		draw_line(center + Vector2(8, 5), center + Vector2(2, -9), Color("#65c7a5"), 2.0)
		draw_circle(center + Vector2(0, -9), 5.0 if state == 1 else 8.0, Color("#3da99b"))
	if state >= 2:
		draw_circle(center + Vector2(-5, -12), 3.0, Color("#b0f1d1"))

func _draw_drop(drop: Dictionary) -> void:
	var available := Time.get_ticks_msec() >= int(drop["available_at_msec"])
	var item_id := str(drop.get("item_id", ""))
	var position: Vector2 = drop["position"]
	draw_circle(position + Vector2(0, 3), 8.0, Color(0.05, 0.1, 0.1, 0.3))
	var base_color := Color("#f3c969")
	match item_id:
		"pea_drop": base_color = Color("#59b35b")
		"mutated_pea_drop": base_color = Color("#f3c969")
		"cactus_drop": base_color = Color("#e77a32")
	draw_circle(position, 6.0, base_color if available else Color(base_color, 0.35))
	if not available:
		draw_arc(position, 10.0, 0.0, TAU, 24, Color(0.95, 0.78, 0.4, 0.45), 1.0)

func _draw_flat_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
