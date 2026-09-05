class_name MeadowInventoryHud
extends Control
## Drawn five-slot hotbar that stays fixed to the viewport.

var inventory: MeadowInventory

func set_inventory(value: MeadowInventory) -> void:
	inventory = value
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if inventory == null:
		return
	var slot_size := Vector2(52, 52)
	var gap := 6.0
	var total_width := slot_size.x * inventory.SLOT_COUNT + gap * (inventory.SLOT_COUNT - 1)
	var origin := Vector2((size.x - total_width) * 0.5, size.y - 66)
	for index in range(inventory.SLOT_COUNT):
		var rect := Rect2(origin + Vector2(index * (slot_size.x + gap), 0), slot_size)
		var selected := index == inventory.selected_slot
		draw_rect(rect, Color("#382f2b"), true)
		draw_rect(rect, Color("#f3c969") if selected else Color("#8b7458"), false, 3.0 if selected else 2.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, 15), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e9dfc4"))
		var slot := inventory.get_slot(index)
		var item_id := str(slot["id"])
		if item_id.is_empty() or int(slot["count"]) <= 0:
			continue
		_draw_item_icon(rect.position + Vector2(26, 29), item_id)
		if inventory.shows_count(item_id):
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(21, 46), str(slot["count"]), HORIZONTAL_ALIGNMENT_RIGHT, 25, 13, Color.WHITE)

func get_slot_at_viewport_position(position: Vector2) -> int:
	if inventory == null:
		return -1
	var slot_size := Vector2(52, 52)
	var gap := 6.0
	var total_width := slot_size.x * inventory.SLOT_COUNT + gap * (inventory.SLOT_COUNT - 1)
	var origin := Vector2((size.x - total_width) * 0.5, size.y - 66)
	for index in range(inventory.SLOT_COUNT):
		var rect := Rect2(origin + Vector2(index * (slot_size.x + gap), 0), slot_size)
		if rect.has_point(position):
			return index
	return -1

func _draw_item_icon(center: Vector2, item_id: String) -> void:
	var icon := str(inventory.get_item_definition(item_id).get("icon", ""))
	if icon == "yellow_ball":
		draw_circle(center + Vector2(0, 2), 13.0, Color(0.05, 0.1, 0.1, 0.45))
		draw_circle(center, 11.0, Color("#f3c969"))
		draw_circle(center + Vector2(-4, -4), 3.0, Color(1, 0.95, 0.7, 0.75))
	elif icon == "green_seed":
		draw_circle(center + Vector2(0, 2), 11.0, Color(0.05, 0.1, 0.1, 0.35))
		draw_circle(center, 9.0, Color("#59b35b"))
		draw_circle(center + Vector2(-3, -3), 2.5, Color("#a3de6d"))
	elif icon == "orange_seed":
		draw_circle(center + Vector2(0, 2), 11.0, Color(0.05, 0.1, 0.1, 0.35))
		draw_circle(center, 9.0, Color("#e77a32"))
		draw_circle(center + Vector2(-3, -3), 2.5, Color("#ffd080"))
	elif icon == "blue_seed":
		draw_circle(center + Vector2(0, 2), 11.0, Color(0.05, 0.1, 0.1, 0.35))
		draw_circle(center, 9.0, Color("#4b9ddd"))
		draw_circle(center + Vector2(-3, -3), 2.5, Color("#b6e8ff"))
	elif icon == "quest_item_1":
		draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color("#b36be0"), true)
		draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color("#ead3ff"), false, 2.0)
		draw_circle(center, 3.0, Color("#fff0a8"))
	elif icon == "pea_drop":
		draw_circle(center + Vector2(-4, 2), 6.0, Color("#8bcf62"))
		draw_circle(center + Vector2(5, -3), 6.0, Color("#70b94f"))
	elif icon == "mutated_pea_drop":
		draw_circle(center, 10.0, Color("#f3c969"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color("#fff1a8"))
	elif icon == "cactus_drop":
		draw_circle(center + Vector2(0, 2), 10.0, Color("#d85d38"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color("#ffd46c"))
	elif icon == "lily_seed":
		draw_circle(center + Vector2(0, 2), 10.0, Color("#7ca9dc"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color("#d8f1ff"))
	elif icon == "hoe":
		draw_line(center + Vector2(-7, 10), center + Vector2(5, -8), Color("#a8754f"), 4.0)
		draw_line(center + Vector2(1, -8), center + Vector2(11, -8), Color("#c6cbd0"), 4.0)
		draw_line(center + Vector2(1, -8), center + Vector2(5, -1), Color("#c6cbd0"), 3.0)
	elif icon == "plant":
		draw_line(center + Vector2(0, 10), center + Vector2(0, -5), Color("#24523a"), 3.0)
		draw_circle(center + Vector2(-5, -5), 6.0, Color("#4d9b55"))
		draw_circle(center + Vector2(5, -3), 6.0, Color("#72c45f"))
	elif icon == "melee_weapon":
		draw_rect(Rect2(center + Vector2(-12, -4), Vector2(24, 8)), Color("#f3c969"), true)
		draw_rect(Rect2(center + Vector2(-12, -4), Vector2(24, 8)), Color("#26353b"), false, 2.0)
		draw_rect(Rect2(center + Vector2(-7, -2), Vector2(14, 2)), Color(1.0, 0.96, 0.72, 0.8), true)
	else:
		draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color("#b68a5b"), true)
		draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color("#e9dfc4"), false, 2.0)
