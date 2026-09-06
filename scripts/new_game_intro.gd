extends Control
## Seven-panel story intro shown only after starting a new game.

enum IntroState {
	REVEALING,
	WAITING,
	ADVANCING,
	ENTERING,
}

const PANEL_COUNT := 7
const FADE_IN_DURATION := 0.72
const PANEL_FADE_DURATION := 0.28
const FINAL_PANEL_DURATION := 2.4
const SKIP_FADE_DURATION := 0.18

@onready var panel_image: TextureRect = $PanelImage
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var click_hint: Label = $HintLayer/ClickHint
@onready var skip_hint: Label = $HintLayer/SkipHint

var language := "en"
var panel_index := 0
var intro_state := IntroState.REVEALING
var _active_tween: Tween
var _transition_serial := 0
var _scene_change_started := false
var _enter_after_fade := false

func _ready() -> void:
	language = "zh" if str(GameState.language) == "zh" else "en"
	click_hint.text = "单击左键继续" if language == "zh" else "LEFT CLICK TO CONTINUE"
	skip_hint.text = "ESC  跳过" if language == "zh" else "ESC  SKIP"
	panel_image.texture = _load_panel(panel_index)
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_to(0.0, FADE_IN_DURATION, _wait_for_click)

func _input(event: InputEvent) -> void:
	if _scene_change_started:
		return
	var key_event := event as InputEventKey
	if key_event != null \
	and key_event.pressed \
	and not key_event.echo \
	and key_event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_skip_intro()
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null \
	or mouse_event.button_index != MOUSE_BUTTON_LEFT \
	or not mouse_event.pressed:
		return
	get_viewport().set_input_as_handled()
	if intro_state == IntroState.WAITING:
		_advance()

func _load_panel(index: int) -> Texture2D:
	var folder := "cn" if language == "zh" else "en"
	var path := "res://start/panels/%s/%02d.png" % [folder, index + 1]
	return load(path) as Texture2D

func _wait_for_click() -> void:
	if _scene_change_started:
		return
	intro_state = IntroState.WAITING

func _advance() -> void:
	if intro_state != IntroState.WAITING or _scene_change_started:
		return
	intro_state = IntroState.ADVANCING
	if panel_index >= PANEL_COUNT - 1:
		_fade_to(1.0, FINAL_PANEL_DURATION, _enter_game)
		return
	_fade_to(1.0, PANEL_FADE_DURATION, _show_next_panel)

func _show_next_panel() -> void:
	if _scene_change_started:
		return
	panel_index += 1
	panel_image.texture = _load_panel(panel_index)
	_fade_to(0.0, PANEL_FADE_DURATION, _wait_for_click)

func _skip_intro() -> void:
	if _scene_change_started:
		return
	_scene_change_started = true
	_enter_after_fade = true
	intro_state = IntroState.ENTERING
	_transition_serial += 1
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(
		fade_overlay,
		"color:a",
		1.0,
		SKIP_FADE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(_enter_game)

func _enter_game() -> void:
	if not _enter_after_fade and not _scene_change_started:
		_scene_change_started = true
	_enter_after_fade = false
	intro_state = IntroState.ENTERING
	get_tree().change_scene_to_file("res://Main.tscn")

func _fade_to(target_alpha: float, duration: float, callback: Callable) -> void:
	_transition_serial += 1
	var serial := _transition_serial
	if is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(
		fade_overlay,
		"color:a",
		target_alpha,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_callback(func() -> void:
		if serial == _transition_serial and not _scene_change_started:
			callback.call()
	)
