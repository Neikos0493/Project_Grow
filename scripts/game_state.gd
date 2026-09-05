extends Node
## Runtime-only inventory snapshot shared between map scenes.

var has_inventory_snapshot := false
var inventory_slots: Array[Dictionary] = []
var selected_slot := 0

func capture_inventory(inventory: MeadowInventory) -> void:
	inventory_slots.clear()
	for slot in inventory.slots:
		inventory_slots.append({
			"id": str(slot.get("id", "")),
			"count": int(slot.get("count", 0)),
		})
	selected_slot = inventory.selected_slot
	has_inventory_snapshot = true

func restore_inventory(inventory: MeadowInventory) -> bool:
	if not has_inventory_snapshot:
		return false
	inventory.slots.clear()
	for slot in inventory_slots:
		inventory.slots.append({
			"id": str(slot.get("id", "")),
			"count": int(slot.get("count", 0)),
		})
	while inventory.slots.size() < inventory.SLOT_COUNT:
		inventory.slots.append({"id": "", "count": 0})
	inventory.selected_slot = clampi(selected_slot, 0, inventory.SLOT_COUNT - 1)
	inventory.inventory_changed.emit()
	inventory.selection_changed.emit(inventory.selected_slot)
	return true

func clear_inventory() -> void:
	has_inventory_snapshot = false
	inventory_slots.clear()
	selected_slot = 0
