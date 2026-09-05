class_name MeadowMapHost
extends Node2D
## Owns exactly one independently-authored map scene at a time.

signal map_changed(map: MeadowWorld)

const MAP_SCENES := {
	&"greenmeadow": preload("res://maps/Greenmeadow.tscn"),
	&"sunset_shore": preload("res://maps/SunsetShore.tscn"),
}

var active_map: MeadowWorld
var _runtime_suspended := false
var _suspended_process_modes: Dictionary = {}

func set_runtime_suspended(value: bool) -> void:
	_runtime_suspended = value
	if not is_instance_valid(active_map):
		_suspended_process_modes.clear()
		return
	if value:
		_set_subtree_suspended(active_map)
	else:
		_restore_subtree_process_modes()

func _set_subtree_suspended(node: Node) -> void:
	if not _suspended_process_modes.has(node):
		_suspended_process_modes[node] = node.process_mode
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_set_subtree_suspended(child)

func _restore_subtree_process_modes() -> void:
	for node in _suspended_process_modes:
		if is_instance_valid(node):
			node.process_mode = int(_suspended_process_modes[node])
	_suspended_process_modes.clear()

func is_runtime_suspended() -> bool:
	return _runtime_suspended

func has_map(map_id: StringName) -> bool:
	return MAP_SCENES.has(map_id)

func get_known_map_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for map_id in MAP_SCENES:
		result.append(map_id)
	return result

func activate_map(map_id: StringName) -> MeadowWorld:
	if not has_map(map_id):
		return null
	var packed_scene: PackedScene = MAP_SCENES[map_id]
	var next_map := packed_scene.instantiate() as MeadowWorld
	if next_map == null:
		return null
	if next_map.get_map_id() != map_id:
		next_map.free()
		return null
	var previous_map := active_map
	active_map = null
	_suspended_process_modes.clear()
	if _runtime_suspended:
		# Lock authored descendants before the scene enters the tree; _ready()
		# descendants are covered again immediately after add_child().
		_set_subtree_suspended(next_map)
	if is_instance_valid(previous_map):
		previous_map.free()
	add_child(next_map)
	active_map = next_map
	if _runtime_suspended:
		# _ready() may add runtime children, so apply the lock once more after
		# the scene enters the tree as well as before it does.
		_set_subtree_suspended(next_map)
	assert(get_child_count() == 1)
	map_changed.emit(active_map)
	return active_map
