extends Control
## Main menu for the Meadow Prototype exploration game.

@onready var start_button: Button = $Content/MenuPanel/Buttons/StartButton
@onready var settings_button: Button = $Content/MenuPanel/Buttons/SettingsButton
@onready var quit_button: Button = $Content/MenuPanel/Buttons/QuitButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var music_toggle: CheckButton = $SettingsPanel/Margin/VBox/MusicRow/MusicToggle
@onready var fullscreen_toggle: CheckButton = $SettingsPanel/Margin/VBox/FullscreenRow/FullscreenToggle
@onready var status_label: Label = $Content/Status

func _ready() -> void:
	start_button.grab_focus()
	start_button.pressed.connect(_start_game)
	settings_button.pressed.connect(_toggle_settings)
	quit_button.pressed.connect(_quit_game)
	$SettingsPanel/Margin/VBox/CloseButton.pressed.connect(_toggle_settings)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	$Content/MenuPanel/Buttons/HowToPlayButton.pressed.connect(_show_controls)
	settings_panel.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_toggle_settings()
		else:
			_quit_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and start_button.has_focus():
		_start_game()

func _start_game() -> void:
	status_label.text = "LOADING THE MEADOW..."
	start_button.disabled = true
	await get_tree().create_timer(0.16).timeout
	get_tree().change_scene_to_file("res://Main.tscn")

func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible
	if settings_panel.visible:
		$SettingsPanel/Margin/VBox/CloseButton.grab_focus()
	else:
		settings_button.grab_focus()

func _show_controls() -> void:
	status_label.text = "WASD MOVE   |   MOUSE AIM   |   CLICK USE TOOL   |   E INTERACT   |   Q DROP"
	$Content/MenuPanel/Buttons/HowToPlayButton.grab_focus()

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _quit_game() -> void:
	status_label.text = "SEE YOU IN THE MEADOW"
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
