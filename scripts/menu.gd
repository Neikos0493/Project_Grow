extends Control
## Main menu for the Meadow Prototype exploration game.

@onready var start_button: Button = $Content/MenuPanel/Buttons/StartButton
@onready var how_to_play_button: Button = $Content/MenuPanel/Buttons/HowToPlayButton
@onready var settings_button: Button = $Content/MenuPanel/Buttons/SettingsButton
@onready var quit_button: Button = $Content/MenuPanel/Buttons/QuitButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var language_option: OptionButton = $SettingsPanel/Margin/VBox/LanguageRow/LanguageOption
@onready var music_toggle: CheckButton = $SettingsPanel/Margin/VBox/MusicRow/MusicToggle
@onready var fullscreen_toggle: CheckButton = $SettingsPanel/Margin/VBox/FullscreenRow/FullscreenToggle
@onready var status_label: Label = $Content/Status

var language := "zh"

func _ready() -> void:
	start_button.grab_focus()
	start_button.pressed.connect(_start_game)
	settings_button.pressed.connect(_toggle_settings)
	quit_button.pressed.connect(_quit_game)
	$SettingsPanel/Margin/VBox/CloseButton.pressed.connect(_toggle_settings)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	how_to_play_button.pressed.connect(_show_controls)
	language_option.item_selected.connect(_on_language_selected)
	language_option.add_item("English")
	language_option.add_item("中文")
	_load_language()
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
	GameState.clear_inventory()
	status_label.text = "正在进入草甸..." if language == "zh" else "LOADING THE MEADOW..."
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
	status_label.text = "WASD 移动   |   鼠标瞄准   |   点击使用工具   |   E 互动   |   Q 丢弃" if language == "zh" else "WASD MOVE   |   MOUSE AIM   |   CLICK USE TOOL   |   E INTERACT   |   Q DROP"
	how_to_play_button.grab_focus()

func _on_language_selected(index: int) -> void:
	language = "zh" if index == 1 else "en"
	GameState.language = language
	_apply_language()
	var config := ConfigFile.new()
	config.set_value("settings", "language", language)
	config.save("user://settings.cfg")

func _load_language() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		language = str(config.get_value("settings", "language", "zh"))
	GameState.language = language
	language_option.select(1 if language == "zh" else 0)
	_apply_language()

func _apply_language() -> void:
	var zh := language == "zh"
	$Content/Kicker.text = "一方等待生长的小世界" if zh else "A SMALL WORLD, WAITING TO GROW"
	$Content/Title.text = "草甸" if zh else "MEADOW"
	$Content/TitleAccent.text = "原型" if zh else "PROTOTYPE"
	$Content/MenuPanel/Buttons/Header.text = "篝火已点亮。" if zh else "THE FIRES ARE LIT."
	start_button.text = "开始旅程" if zh else "START JOURNEY"
	how_to_play_button.text = "玩法说明" if zh else "HOW TO PLAY"
	settings_button.text = "设置" if zh else "SETTINGS"
	quit_button.text = "退出游戏" if zh else "QUIT TO DESKTOP"
	$Content/Footer.text = "v0.1  /  一处宁静的探索之地" if zh else "v0.1  /  A QUIET PLACE TO EXPLORE"
	$SettingsPanel/Margin/VBox/Title.text = "设置" if zh else "SETTINGS"
	$SettingsPanel/Margin/VBox/LanguageRow/Label.text = "语言" if zh else "LANGUAGE"
	$SettingsPanel/Margin/VBox/MusicRow/Label.text = "环境音" if zh else "AMBIENT SOUND"
	$SettingsPanel/Margin/VBox/FullscreenRow/Label.text = "全屏" if zh else "FULLSCREEN"
	$SettingsPanel/Margin/VBox/Hint.text = "更改会立即生效。" if zh else "Changes apply immediately."
	$SettingsPanel/Margin/VBox/CloseButton.text = "完成" if zh else "DONE"
	music_toggle.text = "开" if zh else "ON"
	fullscreen_toggle.text = "开" if zh else "ON"

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _quit_game() -> void:
	status_label.text = "下次再见，草甸" if language == "zh" else "SEE YOU IN THE MEADOW"
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
