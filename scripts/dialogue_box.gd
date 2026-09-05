class_name MeadowDialogueBox
extends Control
## Small modal dialogue panel used by the lake keeper.

signal closed
signal choice_selected(index: int)

@onready var speaker_label: Label = $Panel/Speaker
@onready var body_label: Label = $Panel/Body
@onready var hint_label: Label = $Panel/Hint
@onready var choice_button: Button = $Panel/ChoiceButton
@onready var continue_button: Button = $Panel/ContinueButton

var lines: Array[String] = []
var choices: Array[String] = []
var choice_mode := false
var line_index := 0
var continue_hint := "E  Continue"
var close_hint := "E  Close"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	choice_button.pressed.connect(_emit_choice)
	continue_button.pressed.connect(_advance_from_button)
	choice_button.hide()
	continue_button.hide()
	hide()

func open_dialogue(speaker: String, new_lines: Array[String], hint: String) -> void:
	choices.clear()
	choice_mode = false
	choice_button.hide()
	continue_button.hide()
	lines = new_lines
	line_index = 0
	speaker_label.text = speaker
	var hint_parts := hint.split("|", false)
	continue_hint = hint_parts[0] if not hint_parts.is_empty() else "E  Continue"
	close_hint = hint_parts[1] if hint_parts.size() > 1 else "E  Close"
	_update_body()
	show()

func _emit_choice() -> void:
	if visible and choice_mode:
		choice_selected.emit(0)

func _advance_from_button() -> void:
	if not visible:
		return
	if choice_mode:
		close_dialogue()
	else:
		advance()

func open_choice_dialogue(
	speaker: String,
	body: String,
	choice: String,
	hint: String,
	continue_text: String = "Continue"
) -> void:
	open_dialogue(speaker, [body], hint)
	choice_mode = true
	choices = [choice]
	choice_button.text = choice
	choice_button.show()
	continue_button.text = continue_text
	continue_button.show()
	hint_label.text = ""

func is_choice_mode() -> bool:
	return visible and choice_mode

func select_choice(index: int = 0) -> void:
	if not visible or not choice_mode or index < 0 or index >= choices.size():
		return
	choice_selected.emit(index)

func continue_dialogue() -> void:
	if not visible:
		return
	close_dialogue()

func advance() -> void:
	if not visible or choice_mode:
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
	choices.clear()
	choice_mode = false
	choice_button.hide()
	continue_button.hide()
	line_index = 0
	closed.emit()

func is_open() -> bool:
	return visible

func _update_body() -> void:
	body_label.text = lines[line_index] if line_index < lines.size() else ""
	var is_last := line_index >= lines.size() - 1
	hint_label.text = (close_hint if is_last else continue_hint)
	continue_button.visible = false
