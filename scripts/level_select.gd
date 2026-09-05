extends Control
## Level selection screen for the Meadow Prototype.

@onready var meadow_button: Button = $Cards/MeadowCard/VBox/SelectButton
@onready var back_button: Button = $BackButton
@onready var notice: Label = $Notice

func _ready() -> void:
	meadow_button.pressed.connect(_on_meadow_selected)
	back_button.pressed.connect(_on_back_pressed)
	meadow_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_meadow_selected() -> void:
	notice.text = "ENTERING GREENMEADOW..."
	meadow_button.disabled = true
	await get_tree().create_timer(0.16).timeout
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
