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
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "hoe",
		"sell_price": 0,
		"buy_price": 50,
		"description": "Tills nearby grass into plantable soil.",
	},
	"green_seed": {
		"name": "Green Seed",
		"consumable": true,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "green_seed",
		"sell_price": 2,
		"buy_price": 5,
		"description": "Plant it on tilled soil to grow a meadow plant.",
	},
	"bean_seed": {
		"name": "Small Seed",
		"consumable": true,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "bean_seed",
		"sell_price": 2,
		"buy_price": 5,
		"description": "A smaller seed that always grows an ordinary green pea plant.",
	},
	"sunglasses": {
		"name": "Sunglasses",
		"consumable": false,
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "sunglasses",
		"sell_price": 0,
		"buy_price": 25,
		"description": "A pair of shades for the desert sun.",
	},
	"bow": {
		"name": "Forestwood Bow",
		"consumable": false,
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "bow",
		"sell_price": 0,
		"buy_price": 120,
		"description": "A wooden bow that fires arrows without ammunition.",
	},
	"tree_gun": {
		"name": "神树",
		"consumable": false,
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "tree_gun",
		"sell_price": 0,
		"buy_price": 240,
		"description": "A living gun that charges a boundary-crossing laser.",
	},
	"melee_weapon": {
		"name": "The Village's Best Sword",
		"consumable": false,
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "melee_weapon",
		"sell_price": 25,
		"buy_price": 50,
		"description": "Swings a short yellow blade that lightly knocks back monsters.",
	},
	"orange_seed": {
		"name": "Orange Seed",
		"consumable": true,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "orange_seed",
		"sell_price": 4,
		"buy_price": 5,
		"description": "Plant it in beach sand to grow a fan-leaf cactus.",
	},
	"blue_seed": {
		"name": "Blue Seed",
		"consumable": true,
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "blue_seed",
		"sell_price": 0,
		"buy_price": 0,
		"description": "Plant it in the pond to awaken something ancient.",
	},
	"pea_drop": {
		"name": "Pea",
		"consumable": true,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "pea_drop",
		"sell_price": 20,
		"buy_price": 0,
		"description": "May be edible.",
	},
	"mutated_pea_drop": {
		"name": "Golden Pea",
		"consumable": false,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "mutated_pea_drop",
		"sell_price": 200,
		"buy_price": 0,
		"description": "A golden pea that can awaken the lake monster.",
	},
	"cactus_drop": {
		"name": "Cactus Fruit",
		"consumable": false,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "cactus_drop",
		"sell_price": 100,
		"buy_price": 0,
		"description": "A valuable fruit from an orange cactus.",
	},
	"pure_cactus_drop": {
		"name": "Pure Cactus Fruit",
		"consumable": false,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "pure_cactus_drop",
		"sell_price": 500,
		"buy_price": 0,
		"description": "Five cactus fruits refined into a pure offering for the saxaul seed.",
	},
	"saxaul_seed": {
		"name": "Saxaul Seed",
		"consumable": true,
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "saxaul_seed",
		"sell_price": 0,
		"buy_price": 0,
		"description": "Plant it in a clear 3 by 3 patch of beach sand.",
	},
	"lily_seed": {
		"name": "Water Lily Seed",
		"consumable": true,
		"droppable": true,
		"show_count": false,
		"max_stack": 1,
		"icon": "lily_seed",
		"sell_price": 0,
		"buy_price": 0,
		"description": "Plant it in the pond to awaken the lake monster.",
	},
	"plant": {
		"name": "Plant",
		"consumable": false,
		"droppable": true,
		"show_count": true,
		"max_stack": MAX_STACK,
		"icon": "plant",
		"sell_price": 50,
		"buy_price": 0,
		"description": "A mature plant that can be sold at the shop.",
	},
}

var slots: Array[Dictionary] = []
var selected_slot := 0
var language := "zh"

func set_language(value: String) -> void:
	language = "zh" if value == "zh" else "en"

func _ready() -> void:
	_reset_slots()

func _reset_slots() -> void:
	slots.clear()
	for _index in range(SLOT_COUNT):
		slots.append({"id": "", "count": 0})

func export_state() -> Dictionary:
	var slot_data: Array[Dictionary] = []
	for index in range(SLOT_COUNT):
		var slot := get_slot(index)
		slot_data.append({
			"id": str(slot.get("id", "")),
			"count": int(slot.get("count", 0)),
		})
	return {
		"slots": slot_data,
		"selected_slot": clampi(selected_slot, 0, SLOT_COUNT - 1),
	}

func import_state(data: Dictionary) -> void:
	var next_slots: Array[Dictionary] = []
	var incoming: Variant = data.get("slots", [])
	for index in range(SLOT_COUNT):
		var normalized := {"id": "", "count": 0}
		if incoming is Array and index < incoming.size() and incoming[index] is Dictionary:
			var item_id := str(incoming[index].get("id", ""))
			if ITEM_DEFINITIONS.has(item_id):
				var count := clampi(int(incoming[index].get("count", 0)), 0, get_item_max_stack(item_id))
				if count > 0:
					normalized = {"id": item_id, "count": count}
		next_slots.append(normalized)
	slots = next_slots
	selected_slot = clampi(int(data.get("selected_slot", 0)), 0, SLOT_COUNT - 1)
	inventory_changed.emit()
	selection_changed.emit(selected_slot)

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

func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if str(slot.get("id", "")) == item_id:
			total += int(slot.get("count", 0))
	return total

func has_item(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	for slot in slots:
		if str(slot["id"]) == item_id and int(slot["count"]) > 0:
			return true
	return false

func get_item_definition(item_id: String) -> Dictionary:
	if ITEM_DEFINITIONS.has(item_id):
		return ITEM_DEFINITIONS[item_id]
	return {"consumable": true, "droppable": true, "show_count": true, "max_stack": MAX_STACK}

func get_item_name(item_id: String) -> String:
	if language == "zh":
		match item_id:
			"hoe": return "锄头"
			"green_seed": return "个头稍大的种子"
			"bean_seed": return "个头稍小的种子"
			"sunglasses": return "墨镜"
			"bow": return "森木林弓"
			"tree_gun": return "神树"
			"melee_weapon": return "村里最好的剑"
			"pea_drop": return "豌豆"
			"mutated_pea_drop": return "金色豌豆"
			"cactus_drop": return "仙人掌果实"
			"pure_cactus_drop": return "纯净仙人掌果实"
			"saxaul_seed": return "梭梭树种子"
			"lily_seed": return "睡莲种子"
			"plant": return "植物"
			"orange_seed": return "橙色种子"
			"blue_seed": return "蓝色种子"
	return str(get_item_definition(item_id).get("name", item_id))

func get_item_description(item_id: String) -> String:
	if language == "zh":
		match item_id:
			"hoe": return "将附近的草地翻耕成可种植的土地。"
			"green_seed": return "或许能种出些不一般的东西"
			"bean_seed": return "只能长成普通的绿色豌豆植株。"
			"sunglasses": return "给沙漠里的太阳戴上墨镜。"
			"bow": return "森林的力量凝结出源源不断的箭矢"
			"tree_gun": return "蓄力一秒后发射穿越边界的绿色激光。"
			"melee_weapon": return "挥舞黄色短刃，轻微击退怪物。"
			"pea_drop": return "或许能吃"
			"mutated_pea_drop": return "湖之守望者需要的稀有金色豌豆。"
			"cactus_drop": return "仙人掌掉落的高价值果实。"
			"pure_cactus_drop": return "五个仙人掌果实提炼成的纯净贡品，可向 NPC 兑换梭梭树种子。"
			"saxaul_seed": return "种在第二个区域一片完整的 3×3 沙地中央。"
			"lily_seed": return "种在池塘里，可以唤醒湖怪。"
			"plant": return "成熟植物，可以在商店出售。"
			"orange_seed": return "种在沙地上，长成会发射扇形弹幕的仙人掌。"
			"blue_seed": return "只能种在水里，会唤醒湖中的古老生物。"
	return str(get_item_definition(item_id).get("description", ""))

func is_consumable(item_id: String) -> bool:
	return bool(get_item_definition(item_id).get("consumable", true))

func is_droppable(item_id: String) -> bool:
	return bool(get_item_definition(item_id).get("droppable", true))

func shows_count(item_id: String) -> bool:
	return bool(get_item_definition(item_id).get("show_count", true))

func get_item_max_stack(item_id: String) -> int:
	var max_stack := maxi(1, int(get_item_definition(item_id).get("max_stack", MAX_STACK)))
	if is_consumable(item_id):
		return mini(max_stack, MAX_STACK)
	return max_stack

func get_sell_price(item_id: String) -> int:
	return int(get_item_definition(item_id).get("sell_price", 0))

func get_buy_price(item_id: String) -> int:
	return int(get_item_definition(item_id).get("buy_price", 0))

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

func try_add_to_slot(item_id: String, amount: int, slot_index: int) -> bool:
	if not ITEM_DEFINITIONS.has(item_id) or amount <= 0 or slot_index < 0 or slot_index >= slots.size():
		return false
	var slot := slots[slot_index]
	var existing_id := str(slot.get("id", ""))
	var existing_count := int(slot.get("count", 0))
	if not existing_id.is_empty() and existing_id != item_id:
		return false
	if existing_count + amount > get_item_max_stack(item_id):
		return false
	slot["id"] = item_id
	slot["count"] = existing_count + amount
	inventory_changed.emit()
	return true

func try_craft(input_item_id: String, input_amount: int, output_item_id: String, output_amount: int = 1) -> bool:
	if input_item_id.is_empty() or output_item_id.is_empty() or input_amount <= 0 or output_amount <= 0:
		return false
	var candidate_slots: Array[Dictionary] = slots.duplicate(true)
	if not _remove_from_slots(candidate_slots, input_item_id, input_amount):
		return false
	if not _add_to_slots(candidate_slots, output_item_id, output_amount):
		return false
	slots = candidate_slots
	inventory_changed.emit()
	return true

func can_add_bundle(rewards: Array[Dictionary]) -> bool:
	if rewards.is_empty():
		return false
	var candidate_slots: Array[Dictionary] = slots.duplicate(true)
	for reward in rewards:
		var item_id := str(reward.get("item_id", ""))
		var amount := int(reward.get("amount", 0))
		if not ITEM_DEFINITIONS.has(item_id) or amount <= 0:
			return false
		if not _add_to_slots(candidate_slots, item_id, amount):
			return false
	return true

func try_add_bundle(rewards: Array[Dictionary]) -> bool:
	if not can_add_bundle(rewards):
		return false
	var candidate_slots: Array[Dictionary] = slots.duplicate(true)
	for reward in rewards:
		var item_id := str(reward.get("item_id", ""))
		var amount := int(reward.get("amount", 0))
		if not ITEM_DEFINITIONS.has(item_id) or amount <= 0:
			return false
		if not _add_to_slots(candidate_slots, item_id, amount):
			return false
	slots = candidate_slots
	inventory_changed.emit()
	return true

func try_exchange(remove_item_id: String, add_item_id: String, amount: int = 1) -> bool:
	if remove_item_id.is_empty() or add_item_id.is_empty() or amount <= 0:
		return false
	var candidate_slots: Array[Dictionary] = slots.duplicate(true)
	if not _remove_from_slots(candidate_slots, remove_item_id, amount):
		return false
	if not _add_to_slots(candidate_slots, add_item_id, amount):
		return false
	slots = candidate_slots
	inventory_changed.emit()
	return true

func _remove_from_slots(target_slots: Array[Dictionary], item_id: String, amount: int) -> bool:
	var total := 0
	for slot in target_slots:
		if str(slot["id"]) == item_id:
			total += int(slot["count"])
	if total < amount:
		return false
	var remaining := amount
	for slot in target_slots:
		if str(slot["id"]) != item_id:
			continue
		var removed := mini(remaining, int(slot["count"]))
		slot["count"] = int(slot["count"]) - removed
		remaining -= removed
		if int(slot["count"]) <= 0:
			slot["id"] = ""
			slot["count"] = 0
		if remaining <= 0:
			return true
	return false

func _add_to_slots(target_slots: Array[Dictionary], item_id: String, amount: int) -> bool:
	if not ITEM_DEFINITIONS.has(item_id):
		return false
	var max_stack := get_item_max_stack(item_id)
	var remaining := amount
	for slot in target_slots:
		if str(slot["id"]) == item_id and int(slot["count"]) < max_stack:
			var added := mini(remaining, max_stack - int(slot["count"]))
			slot["count"] = int(slot["count"]) + added
			remaining -= added
			if remaining <= 0:
				return true
	for slot in target_slots:
		if str(slot["id"]).is_empty():
			var added := mini(remaining, max_stack)
			slot["id"] = item_id
			slot["count"] = added
			remaining -= added
			if remaining <= 0:
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

func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false
	var total := 0
	for slot in slots:
		if str(slot["id"]) == item_id:
			total += int(slot["count"])
	if total < amount:
		return false
	var remaining := amount
	for slot in slots:
		if str(slot["id"]) != item_id:
			continue
		var removed := mini(remaining, int(slot["count"]))
		slot["count"] = int(slot["count"]) - removed
		remaining -= removed
		if int(slot["count"]) <= 0:
			slot["id"] = ""
			slot["count"] = 0
		if remaining <= 0:
			break
	inventory_changed.emit()
	return true

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
