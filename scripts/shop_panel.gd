class_name MeadowShopPanel
extends Control
## Data-driven wooden shop panel with hover details and product signals.

signal buy_pressed(item_id: String)
signal close_pressed

const CARD_SIZE := Vector2(68, 78)
const CARD_GAP := 8.0
const CARD_COLOR := Color("#493329")
const CARD_HOVER_COLOR := Color("#634431")
const CARD_OUTLINE := Color("#a87850")
const GOLD := Color("#f3c969")

@onready var product_hitboxes: Control = $ProductHitboxes
@onready var scroll_bar: HScrollBar = $ProductScrollBar
@onready var hover_details: Label = $HoverDetails
@onready var close_button: Button = $CloseButton

var inventory: MeadowInventory
var hovered_item_id := ""
var language := "zh"
var beach_shop := false

func set_map_variant(value: String) -> void:
	beach_shop = value == "pond"
	_rebuild_product_hitboxes()
	queue_redraw()

func set_language(value: String) -> void:
	language = "zh" if value == "zh" else "en"
	_update_hover_text()

func _update_hover_text() -> void:
	if hovered_item_id.is_empty() or inventory == null:
		return
	hover_details.text = "%s\n%s" % [inventory.get_item_name(hovered_item_id), inventory.get_item_description(hovered_item_id)]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	close_button.pressed.connect(_on_close_button_pressed)
	scroll_bar.hide()
	hover_details.hide()
	_rebuild_product_hitboxes()
	resized.connect(_layout_products)
	queue_redraw()

func set_inventory(value: MeadowInventory) -> void:
	inventory = value
	queue_redraw()

func is_shop_product(item_id: String) -> bool:
	return item_id in _visible_product_ids()

func _visible_product_ids() -> Array[String]:
	var ids: Array[String] = ["hoe", "green_seed", "yellow_ball", "melee_weapon"]
	if beach_shop:
		ids.append("orange_seed")
	return ids

func _rebuild_product_hitboxes() -> void:
	for child in product_hitboxes.get_children():
		child.free()
	for item_id in _visible_product_ids():
		var hitbox := Control.new()
		hitbox.name = "%sHitbox" % item_id.capitalize()
		hitbox.size = CARD_SIZE
		hitbox.mouse_filter = Control.MOUSE_FILTER_STOP
		hitbox.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hitbox.mouse_entered.connect(_on_product_mouse_entered.bind(item_id))
		hitbox.mouse_exited.connect(_on_product_mouse_exited.bind(item_id))
		hitbox.gui_input.connect(_on_product_gui_input.bind(item_id))
		product_hitboxes.add_child(hitbox)
	_layout_products()

func _layout_products() -> void:
	var ids := _visible_product_ids()
	var columns := maxi(1, floori((size.x - 16.0 + CARD_GAP) / (CARD_SIZE.x + CARD_GAP)))
	for index in range(ids.size()):
		var hitbox := product_hitboxes.get_node_or_null("%sHitbox" % ids[index].capitalize())
		if hitbox != null:
			var row := index / columns
			var column := index % columns
			hitbox.position = Vector2(8.0 + column * (CARD_SIZE.x + CARD_GAP), 52.0 + row * (CARD_SIZE.y + CARD_GAP))

func _draw() -> void:
	var panel := Rect2(0, 0, size.x, size.y)
	draw_rect(panel, Color("#5a392b"), true)
	draw_rect(panel, Color("#d2a466"), false, 4.0)
	for y in range(14, int(size.y), 18):
		draw_line(Vector2(10, y), Vector2(size.x - 10, y), Color(0.2, 0.1, 0.08, 0.22), 1.0)
	draw_circle(Vector2(18, 18), 2.0, Color("#e2b873"))
	draw_circle(Vector2(size.x - 18, size.y - 18), 2.0, Color("#e2b873"))
	var ids := _visible_product_ids()
	for index in range(ids.size()):
		_draw_product(ids[index], _product_rect(index, ids.size()))

func _product_rect(index: int, _item_count: int) -> Rect2:
	var columns := maxi(1, floori((size.x - 16.0 + CARD_GAP) / (CARD_SIZE.x + CARD_GAP)))
	var row := index / columns
	var column := index % columns
	return Rect2(Vector2(8.0 + column * (CARD_SIZE.x + CARD_GAP), 52.0 + row * (CARD_SIZE.y + CARD_GAP)), CARD_SIZE)

func _draw_product(item_id: String, card: Rect2) -> void:
	var hovered := item_id == hovered_item_id
	draw_rect(card, CARD_HOVER_COLOR if hovered else CARD_COLOR, true)
	draw_rect(card, GOLD if hovered else CARD_OUTLINE, false, 2.5 if hovered else 2.0)
	if inventory == null:
		return
	var definition := inventory.get_item_definition(item_id)
	var icon_center := card.position + Vector2(card.size.x * 0.5, 29.0)
	_draw_item_icon(icon_center, str(definition.get("icon", "")))
	var font := ThemeDB.fallback_font
	var item_name := inventory.get_item_name(item_id)
	var name_width := card.size.x - 10.0
	draw_string(font, Vector2(card.position.x + 5.0, card.position.y + 55.0), item_name, HORIZONTAL_ALIGNMENT_CENTER, name_width, 11, Color("#f4e9c9"))
	_draw_price(card, inventory.get_buy_price(item_id))

func _draw_price(card: Rect2, price: int) -> void:
	var text := "%d 金币" % price if language == "zh" else "%d COINS" % price
	var font := ThemeDB.fallback_font
	var font_size := 11
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var anchor := card.position + Vector2(card.size.x - 7.0, card.size.y - 7.0)
	draw_set_transform(anchor, deg_to_rad(-8.0), Vector2.ONE)
	draw_string(font, Vector2(-text_width + 1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, Color(0.08, 0.04, 0.03, 0.7))
	draw_string(font, Vector2(-text_width, 0), text, HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_item_icon(center: Vector2, icon: String) -> void:
	if icon == "yellow_ball":
		draw_circle(center + Vector2(0, 3), 25.0, Color(0.12, 0.06, 0.04, 0.5))
		draw_circle(center, 22.0, Color("#26353b"))
		draw_circle(center, 19.0, Color("#f3c969"))
		draw_circle(center + Vector2(-6, -7), 5.0, Color(1.0, 0.96, 0.72, 0.85))
	elif icon == "green_seed":
		draw_circle(center + Vector2(0, 2), 15.0, Color(0.05, 0.1, 0.1, 0.35))
		draw_circle(center, 13.0, Color("#59b35b"))
		draw_circle(center + Vector2(-4, -4), 3.5, Color("#a3de6d"))
	elif icon == "orange_seed":
		draw_circle(center + Vector2(0, 2), 15.0, Color(0.05, 0.1, 0.1, 0.35))
		draw_circle(center, 13.0, Color("#e77a32"))
		draw_circle(center + Vector2(-4, -4), 3.5, Color("#ffd080"))
	elif icon == "hoe":
		draw_line(center + Vector2(-10, 14), center + Vector2(7, -11), Color("#a8754f"), 5.0)
		draw_line(center + Vector2(2, -11), center + Vector2(15, -11), Color("#c6cbd0"), 5.0)
		draw_line(center + Vector2(2, -11), center + Vector2(7, -2), Color("#c6cbd0"), 3.5)
	elif icon == "plant":
		draw_line(center + Vector2(0, 12), center + Vector2(0, -6), Color("#24523a"), 4.0)
		draw_circle(center + Vector2(-6, -6), 7.0, Color("#4d9b55"))
		draw_circle(center + Vector2(6, -4), 7.0, Color("#72c45f"))
	elif icon == "melee_weapon":
		draw_rect(Rect2(center + Vector2(-18, -6), Vector2(36, 12)), Color("#f3c969"), true)
		draw_rect(Rect2(center + Vector2(-18, -6), Vector2(36, 12)), Color("#26353b"), false, 2.0)
		draw_rect(Rect2(center + Vector2(-11, -3), Vector2(22, 3)), Color(1.0, 0.96, 0.72, 0.8), true)
	else:
		draw_rect(Rect2(center - Vector2(12, 12), Vector2(24, 24)), Color("#b68a5b"), true)
		draw_rect(Rect2(center - Vector2(12, 12), Vector2(24, 24)), Color("#e9dfc4"), false, 2.0)

func _on_product_mouse_entered(item_id: String) -> void:
	if inventory == null or not is_shop_product(item_id):
		return
	hovered_item_id = item_id
	_update_hover_text()
	hover_details.show()
	queue_redraw()

func _on_product_mouse_exited(item_id: String) -> void:
	if hovered_item_id == item_id:
		clear_hover()

func _on_product_gui_input(event: InputEvent, item_id: String) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		buy_pressed.emit(item_id)

func _on_close_button_pressed() -> void:
	close_pressed.emit()

func clear_hover() -> void:
	hovered_item_id = ""
	hover_details.hide()
	queue_redraw()
