class_name MeadowDialogueBox
extends Control
## Small modal dialogue panel used by the lake keeper.

signal closed

@onready var speaker_label: Label = $Panel/Speaker
@onready var body_label: Label = $Panel/Body
@onready var hint_label: Label = $Panel/Hint

var lines: Array[String] = []
var line_index := 0
var continue_hint := "E  Continue"
var close_hint := "E  Close"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func open_dialogue(speaker: String, new_lines: Array[String], hint: String) -> void:
	lines = new_lines
	line_index = 0
	speaker_label.text = speaker
	var hint_parts := hint.split("|", false)
	continue_hint = hint_parts[0] if not hint_parts.is_empty() else "E  Continue"
	close_hint = hint_parts[1] if hint_parts.size() > 1 else "E  Close"
	_update_body()
	show()

func advance() -> void:
	if not visible:
		return
	line_index += 1
	if line_index >= lines.size():
		close_dialogue()
		return
	_update_body()

func close_dialogue() -> void:
	if not visible:
		return
	hide()
	lines.clear()
	line_index = 0
	closed.emit()

func is_open() -> bool:
	return visible

func _update_body() -> void:
	body_label.text = lines[line_index] if line_index < lines.size() else ""
	var is_last := line_index >= lines.size() - 1
	hint_label.text = (close_hint if is_last else continue_hint)
