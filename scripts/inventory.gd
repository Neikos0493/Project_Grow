class_name MeadowInventory
extends Node
## Fixed five-slot inventory with metadata-aware item usage and stacking.

signal inventory_changed
signal selection_changed(selected_slot: int)

const SLOT_COUNT := 5
const MAX_STACK := 64
const ITEM_DEFINITIONS := {
	"hoe": {
		"name": "Hoe",
		"consumable": false,
		"droppable": false,
		"show_count": false,
		"max_stack": 1,
		"icon": "hoe",
		"sell_price": 0,
	},
	"green_seed": {
		"name": "Green Seed",
		"consumable": true,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "green_seed",
		"sell_price": 0,
	},
	"yellow_ball": {
		"name": "Yellow Ball",
		"consumable": true,
		"droppable": true,
		"show_count": false,
		"max_stack": MAX_STACK,
		"icon": "yellow_ball",
		"sell_price": 0,
	},
	"plant": {
		"name": "Plant",
		"consumable": false,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "plant",
		"sell_price": 50,
	},
}

var slots: Array[Dictionary] = []
var selected_slot := 0

func _ready() -> void:
	_reset_slots()

func _reset_slots() -> void:
	slots.clear()
	for _index in range(SLOT_COUNT):
		slots.append({"id": "", "count": 0})

func select_slot(index: int) -> void:
	var next_slot := clampi(index, 0, SLOT_COUNT - 1)
	if next_slot == selected_slot:
		return
	selected_slot = next_slot
	selection_changed.emit(selected_slot)

func cycle_selection(step: int) -> void:
	select_slot(posmod(selected_slot + step, SLOT_COUNT))

func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {"id": "", "count": 0}
	return slots[index]

func get_selected_item_id() -> String:
	return str(slots[selected_slot]["id"])

func get_selected_count() -> int:
	return int(slots[selected_slot]["count"])

func get_item_definition(item_id: String) -> Dictionary:
	if ITEM_DEFINITIONS.has(item_id):
		return ITEM_DEFINITIONS[item_id]
	return {"consumable": true, "droppable": true, "show_count": true, "max_stack": MAX_STACK}

func get_item_name(item_id: String) -> String:
	return str(get_item_definition(item_id).get("name", item_id))

func is_consumable(item_id: String) -> bool:
	return bool(get_item_definition(item_id).get("consumable", true))

func is_droppable(item_id: String) -> bool:
	return bool(get_item_definition(item_id).get("droppable", true))

func shows_count(item_id: String) -> bool:
	return bool(get_item_definition(item_id).get("show_count", true))

func get_item_max_stack(item_id: String) -> int:
	return maxi(1, int(get_item_definition(item_id).get("max_stack", MAX_STACK)))

func get_sell_price(item_id: String) -> int:
	return int(get_item_definition(item_id).get("sell_price", 0))

func can_add(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	var max_stack := get_item_max_stack(item_id)
	var remaining := amount
	for slot in slots:
		if slot["id"] == item_id:
			remaining -= max_stack - int(slot["count"])
		if remaining <= 0:
			return true
	for slot in slots:
		if str(slot["id"]).is_empty():
			remaining -= max_stack
		if remaining <= 0:
			return true
	return false

func try_add(item_id: String, amount: int = 1) -> bool:
	if not can_add(item_id, amount):
		return false
	var max_stack := get_item_max_stack(item_id)
	var remaining := amount
	for slot in slots:
		if slot["id"] == item_id and int(slot["count"]) < max_stack:
			var added := mini(remaining, max_stack - int(slot["count"]))
			slot["count"] = int(slot["count"]) + added
			remaining -= added
		if remaining <= 0:
			inventory_changed.emit()
			return true
	for slot in slots:
		if str(slot["id"]).is_empty():
			var added := mini(remaining, max_stack)
			slot["id"] = item_id
			slot["count"] = added
			remaining -= added
		if remaining <= 0:
			inventory_changed.emit()
			return true
	return false

func remove_from_slot(index: int, amount: int = 1) -> bool:
	if index < 0 or index >= slots.size() or amount <= 0:
		return false
	var slot := slots[index]
	if str(slot["id"]).is_empty() or int(slot["count"]) < amount:
		return false
	slot["count"] = int(slot["count"]) - amount
	if int(slot["count"]) <= 0:
		slot["id"] = ""
		slot["count"] = 0
	inventory_changed.emit()
	return true

func remove_selected(amount: int = 1) -> bool:
	return remove_from_slot(selected_slot, amount)

func use_selected(amount: int = 1) -> bool:
	var item_id := get_selected_item_id()
	if item_id.is_empty() or amount <= 0:
		return false
	if not is_consumable(item_id):
		return true
	return remove_selected(amount)

func consume_selected(amount: int = 1) -> bool:
	var item_id := get_selected_item_id()
	if not is_consumable(item_id):
		return false
	return remove_selected(amount)
