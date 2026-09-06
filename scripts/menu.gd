extends Control
## Main menu with single-slot Continue and confirmed New Game flows.

const MENU_CLICK_SOUND := preload("res://sound/主页面和ESC页面点击音效.mp3")

@onready var continue_button: Button = $Content/MenuPanel/Buttons/ContinueButton
@onready var start_button: Button = $Content/MenuPanel/Buttons/StartButton
@onready var how_to_play_button: Button = $Content/MenuPanel/Buttons/HowToPlayButton
@onready var settings_button: Button = $Content/MenuPanel/Buttons/SettingsButton
@onready var quit_button: Button = $Content/MenuPanel/Buttons/QuitButton
@onready var new_game_confirm: ConfirmationDialog = $NewGameConfirm
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var language_option: OptionButton = $SettingsPanel/Margin/VBox/LanguageRow/LanguageOption
@onready var music_toggle: CheckButton = $SettingsPanel/Margin/VBox/MusicRow/MusicToggle
@onready var fullscreen_toggle: CheckButton = $SettingsPanel/Margin/VBox/FullscreenRow/FullscreenToggle
@onready var status_label: Label = $Content/Status

var language := "zh"
var has_save := false
var starting := false
var menu_click_player: AudioStreamPlayer

func _ready() -> void:
	menu_click_player = AudioStreamPlayer.new()
	menu_click_player.stream = MENU_CLICK_SOUND
	menu_click_player.volume_db = -2.0
	add_child(menu_click_player)
	continue_button.pressed.connect(_play_menu_click_sound)
	continue_button.pressed.connect(_continue_game)
	start_button.pressed.connect(_play_menu_click_sound)
	start_button.pressed.connect(_request_new_game)
	new_game_confirm.confirmed.connect(_play_menu_click_sound)
	new_game_confirm.confirmed.connect(_start_new_game)
	settings_button.pressed.connect(_play_menu_click_sound)
	settings_button.pressed.connect(_toggle_settings)
	quit_button.pressed.connect(_play_menu_click_sound)
	quit_button.pressed.connect(_quit_game)
	$SettingsPanel/Margin/VBox/CloseButton.pressed.connect(_play_menu_click_sound)
	$SettingsPanel/Margin/VBox/CloseButton.pressed.connect(_toggle_settings)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	how_to_play_button.pressed.connect(_play_menu_click_sound)
	how_to_play_button.pressed.connect(_show_controls)
	language_option.item_selected.connect(_on_language_selected)
	language_option.add_item("English")
	language_option.add_item("中文")
	_load_language()
	settings_panel.hide()
	has_save = GameState.has_valid_save()
	continue_button.disabled = not has_save
	if has_save:
		continue_button.grab_focus()
	else:
		start_button.grab_focus()

func _play_menu_click_sound() -> void:
	if is_instance_valid(menu_click_player):
		menu_click_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if starting:
		return
	if event.is_action_pressed("ui_cancel"):
		if settings_panel.visible:
			_toggle_settings()
		else:
			_quit_game()
		get_viewport().set_input_as_handled()

func _continue_game() -> void:
	if starting or continue_button.disabled:
		return
	if not GameState.load_game():
		has_save = false
		continue_button.disabled = true
		status_label.text = "自动存档已损坏，无法继续。" if language == "zh" else "THE AUTOSAVE COULD NOT BE LOADED."
		start_button.grab_focus()
		return
	starting = true
	_set_buttons_disabled(true)
	if GameState.last_load_used_backup:
		status_label.text = "主存档损坏，正在从备份恢复..." if language == "zh" else "RECOVERING FROM THE AUTOSAVE BACKUP..."
	else:
		status_label.text = "正在继续旅程..." if language == "zh" else "CONTINUING THE JOURNEY..."
	await get_tree().create_timer(0.16).timeout
	get_tree().change_scene_to_file("res://Main.tscn")

func _request_new_game() -> void:
	if starting:
		return
	if has_save:
		new_game_confirm.dialog_text = "开始新游戏会覆盖当前自动存档。" if language == "zh" else "Starting a new game will replace the current automatic save."
		new_game_confirm.ok_button_text = "开始新游戏" if language == "zh" else "START NEW GAME"
		new_game_confirm.cancel_button_text = "取消" if language == "zh" else "CANCEL"
		new_game_confirm.popup_centered()
		return
	_start_new_game()

func _start_new_game() -> void:
	if starting:
		return
	if not GameState.start_new_game():
		status_label.text = "无法清除旧的自动存档。" if language == "zh" else "THE OLD AUTOSAVE COULD NOT BE CLEARED."
		return
	starting = true
	_set_buttons_disabled(true)
	status_label.text = "正在进入绿野..." if language == "zh" else "LOADING GREENMEADOW..."
	await get_tree().create_timer(0.16).timeout
	get_tree().change_scene_to_file("res://Main.tscn")

func _set_buttons_disabled(disabled: bool) -> void:
	continue_button.disabled = disabled or not has_save
	start_button.disabled = disabled
	how_to_play_button.disabled = disabled
	settings_button.disabled = disabled
	quit_button.disabled = disabled

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
	continue_button.text = "继续游戏" if zh else "CONTINUE"
	start_button.text = "开始新游戏" if zh else "START NEW GAME"
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
	new_game_confirm.title = "覆盖自动存档？" if zh else "Replace autosave?"

func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _quit_game() -> void:
	status_label.text = "下次再见，草甸" if language == "zh" else "SEE YOU IN THE MEADOW"
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
