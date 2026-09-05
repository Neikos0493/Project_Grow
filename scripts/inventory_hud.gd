class_name MeadowInventoryHud
extends Control
## Drawn five-slot hotbar that stays fixed to the viewport.

const SWORD_TEXTURE := preload("res://image/sword/Sword.png")
const HOE_TEXTURE := preload("res://image/hoe/sickle.png")
const BEAN_SEED_TEXTURE := preload("res://image/shop/beanSeed.png")
const BOW_TEXTURE := preload("res://assets/generated/weapons/forest_bow.png")
const TREE_GUN_TEXTURE := preload("res://assets/generated/weapons/tree_gun.png")
const BOW_SOURCE_RECT := Rect2(377, 8, 286, 821)
const GUN_SOURCE_RECT := Rect2(40, 311, 330, 245)

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
	if icon == "bow":
		draw_texture_rect_region(BOW_TEXTURE, Rect2(center - Vector2(15, 15), Vector2(30, 30)), BOW_SOURCE_RECT)
	elif icon == "tree_gun":
		draw_texture_rect_region(TREE_GUN_TEXTURE, Rect2(center - Vector2(16, 16), Vector2(32, 32)), GUN_SOURCE_RECT)
	elif icon == "bean_seed":
		var bean_icon_size := Vector2(25.0, 25.0)
		draw_texture_rect(BEAN_SEED_TEXTURE, Rect2(center - bean_icon_size * 0.5, bean_icon_size), false)
	elif icon == "sunglasses":
		draw_line(center + Vector2(-12, -2), center + Vector2(-2, -2), Color("#273746"), 4.0)
		draw_line(center + Vector2(2, -2), center + Vector2(12, -2), Color("#273746"), 4.0)
		draw_line(center + Vector2(-2, -2), center + Vector2(2, -2), Color("#273746"), 3.0)
		draw_line(center + Vector2(-12, -2), center + Vector2(-16, -6), Color("#273746"), 3.0)
		draw_line(center + Vector2(12, -2), center + Vector2(16, -6), Color("#273746"), 3.0)
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
	elif icon == "pea_drop":
		var pea_texture := preload("res://image/Monster_pea/Bean.png")
		draw_texture_rect(pea_texture, Rect2(center - Vector2(14, 14), Vector2(28, 28)), false)
	elif icon == "mutated_pea_drop":
		draw_circle(center, 10.0, Color("#f3c969"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color("#fff1a8"))
	elif icon == "cactus_drop":
		draw_circle(center + Vector2(0, 2), 10.0, Color("#d85d38"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color("#ffd46c"))
	elif icon == "saxaul_seed":
		draw_circle(center, 10.0, Color("#8a6542"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color("#d8e98c"))
	elif icon == "lily_seed":
		draw_circle(center + Vector2(0, 2), 10.0, Color("#7ca9dc"))
		draw_circle(center + Vector2(-3, -3), 3.0, Color("#d8f1ff"))
	elif icon == "hoe":
		var icon_size := Vector2(32.0, 32.0 * HOE_TEXTURE.get_height() / HOE_TEXTURE.get_width())
		draw_texture_rect(HOE_TEXTURE, Rect2(center - icon_size * 0.5, icon_size), false)
	elif icon == "plant":
		draw_line(center + Vector2(0, 10), center + Vector2(0, -5), Color("#24523a"), 3.0)
		draw_circle(center + Vector2(-5, -5), 6.0, Color("#4d9b55"))
		draw_circle(center + Vector2(5, -3), 6.0, Color("#72c45f"))
	elif icon == "melee_weapon":
		var icon_size := Vector2(32.0, 32.0 * SWORD_TEXTURE.get_height() / SWORD_TEXTURE.get_width())
		draw_texture_rect(SWORD_TEXTURE, Rect2(center - icon_size * 0.5, icon_size), false)
	else:
		draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color("#b68a5b"), true)
		draw_rect(Rect2(center - Vector2(9, 9), Vector2(18, 18)), Color("#e9dfc4"), false, 2.0)
