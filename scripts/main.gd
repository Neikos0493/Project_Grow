class_name MeadowMain
extends Node2D
## Persistent gameplay shell coordinating one isolated active map at a time.

const HOE := "hoe"
const GREEN_SEED := "green_seed"
const ORANGE_SEED := "orange_seed"
const BOW := "bow"
const TREE_GUN := "tree_gun"
const MELEE_WEAPON := "melee_weapon"
const PEA_DROP := "pea_drop"
const MUTATED_PEA_DROP := "mutated_pea_drop"
const CACTUS_DROP := "cactus_drop"
const SAXAUL_SEED := "saxaul_seed"
const LILY_SEED := "lily_seed"
const BLUE_SEED := "blue_seed"
const STARTING_COINS := 9999
const WORLD_MASK := 1
const PLAYER_MASK := 2
const PLANT_MASK := 4
const MONSTER_MASK := 16
const RESPAWN_HOLD_SECONDS := 2.0
const WATER_GROW_TIME := 2.5
const WATER_SPREAD_INTERVAL := 0.18
const WATER_EMERGE_DELAY := 0.65
const SAXAUL_SPREAD_INTERVAL := 0.12
const QUEST_AWAITING_PLANT := 0
const QUEST_SEED_GRANTED := 1
const QUEST_WATER_GROWING := 2
const QUEST_MONSTER_ACTIVE := 3
const QUEST_DEFEATED := 4
const AUTOSAVE_INTERVAL := 5.0
const AUTOSAVE_DEBOUNCE := 0.75
const AUTOSAVE_RETRY_MAX_SECONDS := 15.0
const DROP_PICKUP_DELAY_MSEC := 3000
const SMALL_SEED := "bean_seed"
const SUNGLASSES := "sunglasses"
const BOSS_LAKE := &"lake_monster"
const BOSS_SAXAUL := &"saxaul_boss"
const SAXAUL_VINE_SCRIPT = preload("res://scripts/saxaul_vine.gd")
const TREE_LASER_SCRIPT = preload("res://scripts/tree_laser.gd")
const BOTTLE_TEXTURES := [
	preload("res://assets/generated/bottle/bottle.png"),
	preload("res://assets/generated/bottle/bottle_half.png"),
	preload("res://assets/generated/bottle/bottle_full.png"),
]
const AUTO_FIRE_CADENCE := {
	BOW: 0.35,
	TREE_GUN: 1.0,
	MELEE_WEAPON: 0.4,
}
const TREE_GUN_CHARGE_DURATION := 1.0

@onready var map_host: MeadowMapHost = $MapHost
@onready var player: MeadowPlayer = $Player
@onready var melee_weapon: MeadowMeleeWeapon = $Player/MeleeWeapon
@onready var held_weapon: Node2D = $Player/HeldWeapon
@onready var camera: Camera2D = $Player/Camera2D
@onready var crosshair: MeadowCrosshair = $CursorLayer/Crosshair
@onready var inventory: MeadowInventory = $Inventory
@onready var inventory_hud: MeadowInventoryHud = $HUD/InventoryBar
@onready var inventory_sell_tooltip: Label = $HUD/InventorySellTooltip
@onready var coin_label: Label = $HUD/TopBar/CoinLabel
@onready var health_label: Label = $HUD/TopBar/HealthLabel
@onready var boss_bar: Control = $HUD/BossBar
@onready var boss_title: Label = $HUD/BossBar/Title
@onready var boss_fill: ColorRect = $HUD/BossBar/Track/Fill
@onready var shop_panel: MeadowShopPanel = $HUD/ShopPanel
@onready var radar_panel: MeadowRadarPanel = $HUD/RadarPanel
@onready var travel_transition: MeadowTravelTransition = $HUD/TravelTransition
@onready var pause_menu: Control = $HUD/PauseMenu
@onready var pause_title: Label = $HUD/PauseMenu/Panel/Title
@onready var pause_resume_button: Button = $HUD/PauseMenu/Panel/ResumeButton
@onready var pause_menu_button: Button = $HUD/PauseMenu/Panel/MenuButton
@onready var prompt_box: ColorRect = $HUD/PromptBox
@onready var prompt_label: Label = $HUD/PromptBox/Prompt
@onready var toast_box: ColorRect = $HUD/ToastBox
@onready var toast_label: Label = $HUD/ToastBox/Toast
@onready var death_overlay: ColorRect = $HUD/DeathOverlay
@onready var respawn_progress: ProgressBar = $HUD/DeathOverlay/DeathCard/RespawnProgress
@onready var dialogue_box: MeadowDialogueBox = $HUD/DialogueBox
@onready var bottle_button: TextureButton = $HUD/BottleButton
@onready var bottle_overlay: Control = $HUD/BottleOverlay
@onready var bottle_overlay_texture: TextureRect = $HUD/BottleOverlay/Bottle
@onready var bottle_message: Label = $HUD/BottleOverlay/Message
@onready var bottle_close_hint: Label = $HUD/BottleOverlay/CloseHint

var world: MeadowWorld
var shop: MeadowShop
var projectiles: Node2D
var plants: Node2D
var coins := STARTING_COINS
var language := "en"
var shop_open := false
var radar_open := false
var traveling := false
var _fire_held := false
var _held_weapon_id := ""
var _auto_fire_remaining := 0.0
var _tree_gun_charge_elapsed := 0.0
var tree_laser: MeadowTreeLaser
var plant_entities: Dictionary = {}
var next_entity_serial := 1
var _last_prompt := ""
var _inventory_sell_tooltip_slot := -1
var _inventory_sell_tooltip_item_id := ""
var _toast_tween: Tween
var _respawn_hold_elapsed := 0.0
var _respawn_triggered_for_death := false
var quest_state := QUEST_AWAITING_PLANT
var water_root := Vector2i(-1, -1)
var water_growth_elapsed := 0.0
var water_spread_elapsed := 0.0
var water_spread_cells: Array[Vector2i] = []
var water_spread_index := 0
var water_emerge_elapsed := 0.0
var lake_monster: MeadowLakeMonster
var saxaul_boss: MeadowSaxaulBoss
var saxaul_vines: Array[StaticBody2D] = []
var saxaul_spread_active := false
var saxaul_spread_rings: Array = []
var saxaul_spread_index := 0
var saxaul_spread_elapsed := 0.0
var _restoring := true
var _save_dirty := false
var _save_debounce_remaining := 0.0
var _autosave_elapsed := 0.0
var _save_retry_remaining := 0.0
var _save_failure_count := 0
var _save_failure_notified := false
var _closing := false
var _show_radar_unlock_toast_on_close := false
var _dialogue_choice_context := ""
var _saxaul_failure_seed_returned := false

@onready var game_state: Node = get_node("/root/GameState")

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_load_language()
	inventory.set_language(language)
	shop_panel.set_language(language)
	radar_panel.set_language(language)
	_connect_shared_signals()
	_configure_shared_ui()
	game_state.ensure_session()
	coins = game_state.coins
	quest_state = game_state.quest_state
	inventory.import_state(game_state.inventory_state)
	player.restore_state(game_state.player_health)
	var target_map_id: StringName = game_state.current_map_id
	if not map_host.has_map(target_map_id):
		target_map_id = &"greenmeadow"
	var active := map_host.activate_map(target_map_id)
	if active == null:
		push_error("Could not activate initial map: %s" % target_map_id)
		return
	_bind_active_map(active)
	var snapshot: Dictionary = game_state.get_map_state(target_map_id)
	_restore_map_state(snapshot)
	_place_player_for_entry(game_state.entry_mode, snapshot)
	game_state.entry_mode = "running"
	_restoring = false
	_update_death_ui_from_player()
	_refresh_inventory()
	_refresh_coins()
	# Energy remains gameplay state but is intentionally not shown in the top bar.
	_apply_game_language()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if not player.dead:
		player.controls_locked = false
	_show_toast(world.get_arrival_message())
	_mark_save_dirty()

func _connect_shared_signals() -> void:
	player.interaction_requested.connect(_on_interaction_requested)
	player.fire_requested.connect(_on_fire_requested)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	dialogue_box.closed.connect(_on_dialogue_closed)
	dialogue_box.choice_selected.connect(_on_dialogue_choice_selected)
	shop_panel.buy_pressed.connect(_on_buy_pressed)
	shop_panel.close_pressed.connect(_close_shop)
	shop_panel.set_inventory(inventory)
	radar_panel.point_selected.connect(_on_radar_point_selected)
	radar_panel.close_pressed.connect(_close_radar)
	inventory_hud.set_inventory(inventory)
	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.selection_changed.connect(_on_inventory_selection_changed)

func _configure_shared_ui() -> void:
	player.z_index = 10
	held_weapon.hide()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	shop_panel.hide()
	radar_panel.hide()
	dialogue_box.hide()
	prompt_box.hide()
	death_overlay.hide()
	boss_bar.hide()
	pause_menu.hide()
	bottle_overlay.hide()
	bottle_button.pressed.connect(_open_bottle_overlay)
	bottle_overlay.gui_input.connect(_on_bottle_overlay_gui_input)
	pause_resume_button.pressed.connect(_resume_game)
	pause_menu_button.pressed.connect(_return_to_menu)
	_apply_pause_language()
	inventory_sell_tooltip.hide()
	respawn_progress.max_value = RESPAWN_HOLD_SECONDS
	respawn_progress.value = 0.0
	_update_bottle_hud()

func _bind_active_map(map: MeadowWorld) -> void:
	world = map
	_dialogue_choice_context = ""
	boss_bar.hide()
	boss_fill.size.x = 620.0
	world.set_language(language)
	shop = world.get_shop_node()
	plants = world.get_plants_container()
	projectiles = world.get_projectiles_container()
	shop_panel.set_map_variant("pond" if world.get_map_id() == &"sunset_shore" else "main")
	var entering_map_two: bool = game_state.current_map_id != &"sunset_shore"
	world.enable_pea_npc = world.get_map_id() == &"sunset_shore" and game_state.map_two_return_count >= 1
	if world.get_map_id() == &"sunset_shore" \
	and entering_map_two \
	and game_state.sunflower_quest_state >= 2:
		game_state.map_two_return_count = mini(2, game_state.map_two_return_count + 1)
		world.enable_pea_npc = true
		_mark_save_dirty()
	world.set_pea_npc_phase(game_state.pea_npc_state)
	world.pea_npc_transform_elapsed = game_state.pea_npc_transform_elapsed
	if not world.state_changed.is_connected(_mark_save_dirty):
		world.state_changed.connect(_mark_save_dirty)
	var world_size := world.get_map_size_pixels()
	var local_top := float(world.get_camera_top_limit())
	var corners := [
		world.to_global(Vector2(0.0, local_top)),
		world.to_global(Vector2(world_size.x, local_top)),
		world.to_global(Vector2(0.0, world_size.y)),
		world.to_global(world_size),
	]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	camera.reset_smoothing()
	_apply_game_language()

func _place_player_for_entry(entry_mode: String, snapshot: Dictionary) -> void:
	var position := world.get_initial_spawn_position()
	if entry_mode == "continue":
		var saved_position := _data_to_position(snapshot.get("last_player_position", []))
		if is_finite(saved_position.x) and is_finite(saved_position.y):
			position = saved_position \
				if _is_safe_position(saved_position) \
				else world.get_nearest_walkable_position(saved_position)
	elif entry_mode == "travel":
		position = world.get_ship_arrival_position()
	player.global_position = world.to_global(position)
	player.velocity = Vector2.ZERO
	camera.reset_smoothing()

func _is_safe_position(position: Vector2) -> bool:
	return is_finite(position.x) \
		and is_finite(position.y) \
		and world.is_position_unoccupied(position)

func _player_facing_in_map() -> Vector2:
	var direction := world.global_direction_to_map(player.facing)
	return direction.normalized() if direction.length_squared() > 0.01 else Vector2.DOWN

func _load_language() -> void:
	language = str(game_state.language)
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		language = str(config.get_value("settings", "language", language))
	language = "zh" if language == "zh" else "en"
	game_state.language = language

func _msg(english: String, chinese: String) -> String:
	return chinese if language == "zh" else english

func _apply_game_language() -> void:
	if is_instance_valid(world):
		$HUD/TopBar/Title.text = world.get_level_title()
		$HUD/TopBar/Subtitle.text = world.get_level_subtitle()
	$HUD/TopBar/Help.text = _msg("WASD  Move    E  Interact", "WASD 移动    E 互动")
	$HUD/PromptBox/Prompt.text = _msg("E  Interact", "E 互动")
	$HUD/DeathOverlay/DeathCard/DeathTitle.text = _msg("YOU FAINTED", "你昏倒了")
	$HUD/DeathOverlay/DeathCard/RespawnInstruction.text = _msg("Hold SPACE for 2 seconds to return", "长按空格键 2 秒返回")
	$HUD/ShopPanel/DimLabel.text = _msg("WOODLAND SHOP", "林地商店")
	$HUD/DialogueBox/Panel/Hint.text = _msg("E  Continue|E  Close", "E  继续|E  关闭")
	_update_bottle_hud()
	if is_instance_valid(saxaul_boss) and saxaul_boss.mature and not saxaul_boss.dead:
		boss_title.text = _msg("SAXAUL TREE", "梭梭树")
	elif is_instance_valid(lake_monster) and not lake_monster.dead:
		boss_title.text = _msg("WATER LILY", "湖中睡莲")

	_apply_pause_language()

func _apply_pause_language() -> void:
	pause_title.text = _msg("PAUSED", "游戏暂停")
	pause_resume_button.text = _msg("RESUME", "继续游戏")
	pause_menu_button.text = _msg("MAIN MENU", "返回主菜单")

func _set_paused(value: bool) -> void:
	_clear_held_fire()
	if value:
		_clear_inventory_sell_tooltip()
	if is_instance_valid(map_host):
		map_host.set_runtime_suspended(value)
	get_tree().paused = value
	pause_menu.visible = value
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_HIDDEN)

func _resume_game() -> void:
	_set_paused(false)

func _return_to_menu() -> void:
	if not _capture_and_save():
		_show_persistent_toast(_msg("Save failed. The game remains open; try again after checking disk space.", "存档失败，游戏将保持开启；请检查磁盘空间后重试。"))
		return
	_set_paused(false)
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(world):
		return
	if traveling:
		_clear_held_fire()
		prompt_box.hide()
		return
	_update_autosave(delta)
	_update_auto_fire(delta)
	_update_water_encounter(delta)
	_update_saxaul_grass_spread(delta)
	if is_instance_valid(world) \
	and world.get_map_id() == &"sunset_shore" \
	and world.enable_pea_npc \
	and game_state.pea_npc_state == 1:
		world.advance_pea_npc_transform(delta)
		game_state.pea_npc_transform_elapsed = world.pea_npc_transform_elapsed
		if world.pea_npc_transform_elapsed >= MeadowWorld.WORM_TRANSFORM_DURATION:
			game_state.pea_npc_state = 2
			game_state.pea_npc_transform_elapsed = MeadowWorld.WORM_TRANSFORM_DURATION
			_mark_save_dirty()
	crosshair.queue_redraw()
	_update_depth_order()
	if not world.drops.is_empty():
		world.queue_redraw()
	if player.dead:
		_clear_held_fire()
		prompt_box.hide()
		_clear_inventory_sell_tooltip()
		_update_respawn_hold(delta)
		return
	if not shop_open:
		_try_pickup()
	if dialogue_box.is_open() or radar_open or bottle_overlay.visible:
		_clear_held_fire()
		prompt_box.hide()
		_clear_inventory_sell_tooltip()
		return
	if shop_open:
		_clear_held_fire()
		prompt_box.hide()
		_update_inventory_sell_tooltip()
		return
	_update_inventory_sell_tooltip()
	var next_prompt := world.get_interaction_prompt(world.to_local(player.global_position), _player_facing_in_map())
	if next_prompt == _last_prompt:
		return
	_last_prompt = next_prompt
	if next_prompt.is_empty():
		prompt_box.hide()
	else:
		prompt_label.text = "E  " + next_prompt
		prompt_box.show()

func _input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		if not get_tree().paused \
		and not traveling \
		and not player.dead \
		and not shop_open \
		and not radar_open \
		and not dialogue_box.is_open() \
		and not bottle_overlay.visible \
		and bottle_button.get_global_rect().has_point(mouse_event.position):
			_open_bottle_overlay()
			get_viewport().set_input_as_handled()
			return
		if get_tree().paused or traveling or player.dead or player.controls_locked or radar_open or dialogue_box.is_open() or bottle_overlay.visible:
			return
		var slot_index := inventory_hud.get_slot_at_viewport_position(mouse_event.position)
		if slot_index >= 0:
			_clear_held_fire()
			inventory.select_slot(slot_index)
			get_viewport().set_input_as_handled()
			return
		var item_id := inventory.get_selected_item_id()
		if AUTO_FIRE_CADENCE.has(item_id):
			_fire_held = true
			_held_weapon_id = item_id
			_auto_fire_remaining = 0.0
			_update_auto_fire(0.0)
		else:
			var direction := get_global_mouse_position() - player.global_position
			if direction.length_squared() > 0.01:
				_on_fire_requested(player.global_position, direction.normalized(), item_id)
		get_viewport().set_input_as_handled()
	else:
		_clear_held_fire()

func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
		_clear_held_fire()
	if _is_escape(event):
		if traveling or dialogue_box.is_open() or player.dead:
			return
		if bottle_overlay.visible:
			_close_bottle_overlay()
		elif radar_open:
			_close_radar()
		elif shop_open:
			_close_shop()
		else:
			_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused \
	or traveling \
	or dialogue_box.is_open() \
	or player.dead \
	or bottle_overlay.visible:
		return
	if radar_open:
		if _is_escape(event):
			_close_radar()
			get_viewport().set_input_as_handled()
		return
	if shop_open:
		if _is_escape(event):
			_close_shop()
			get_viewport().set_input_as_handled()
			return
		var shop_mouse := event as InputEventMouseButton
		if shop_mouse != null and shop_mouse.pressed and shop_mouse.button_index == MOUSE_BUTTON_RIGHT:
			_sell_inventory_slot(inventory_hud.get_slot_at_viewport_position(shop_mouse.position))
			get_viewport().set_input_as_handled()
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		match key_event.physical_keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				inventory.select_slot(key_event.physical_keycode - KEY_1)
				get_viewport().set_input_as_handled()
			KEY_Q:
				_drop_selected_item()
				get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				inventory.cycle_selection(-1)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				inventory.cycle_selection(1)
				get_viewport().set_input_as_handled()

func _clear_held_fire() -> void:
	_fire_held = false
	_held_weapon_id = ""
	_auto_fire_remaining = 0.0
	_tree_gun_charge_elapsed = 0.0
	if is_instance_valid(tree_laser):
		tree_laser.queue_free()
		tree_laser = null
	if is_instance_valid(held_weapon):
		held_weapon.hide()
		held_weapon.call("set_charge", 0.0)

func _update_auto_fire(delta: float) -> void:
	if not _fire_held or _held_weapon_id.is_empty():
		if is_instance_valid(held_weapon):
			held_weapon.hide()
		return
	if not AUTO_FIRE_CADENCE.has(_held_weapon_id):
		_clear_held_fire()
		return
	if player.dead or player.controls_locked or traveling or shop_open or radar_open or dialogue_box.is_open():
		_clear_held_fire()
		return
	if inventory.get_selected_item_id() != _held_weapon_id:
		_clear_held_fire()
		return
	var direction := get_global_mouse_position() - player.global_position
	if direction.length_squared() < 0.01:
		return
	player.set_attack_facing(direction)
	if not is_instance_valid(held_weapon):
		_clear_held_fire()
		return
	var normalized_direction := direction.normalized()
	held_weapon.call("set_weapon", _held_weapon_id, normalized_direction)
	held_weapon.show()
	if _held_weapon_id == TREE_GUN:
		_tree_gun_charge_elapsed = minf(
			TREE_GUN_CHARGE_DURATION,
			_tree_gun_charge_elapsed + delta
		)
		held_weapon.call("set_charge", _tree_gun_charge_elapsed)
		if _tree_gun_charge_elapsed < TREE_GUN_CHARGE_DURATION:
			return
		var muzzle_position: Vector2 = held_weapon.call("get_muzzle_global_position")
		if not is_instance_valid(tree_laser):
			tree_laser = TREE_LASER_SCRIPT.new()
			projectiles.add_child(tree_laser)
			tree_laser.setup(
				muzzle_position,
				normalized_direction,
				get_world_2d().direct_space_state,
				PLANT_MASK | MONSTER_MASK,
				4,
				player,
				Color("#9ee66f")
			)
		else:
			tree_laser.update_beam(muzzle_position, normalized_direction)
		return
	_auto_fire_remaining = maxf(0.0, _auto_fire_remaining - delta)
	if _auto_fire_remaining > 0.0:
		return
	_on_fire_requested(player.global_position, normalized_direction, _held_weapon_id)
	_auto_fire_remaining = float(AUTO_FIRE_CADENCE[_held_weapon_id])

func _is_escape(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and key_event.physical_keycode == KEY_ESCAPE and not key_event.echo

func _update_depth_order() -> void:
	if not is_instance_valid(shop):
		return
	var player_map_position := world.to_local(player.global_position)
	var player_cell := world.world_to_cell(player_map_position)
	# Put the player behind the shop only in its 4x2 blocked area and the
	# one-cell-high visual strip directly above that area.
	var shop_depth_zone := _get_shop_depth_zone()
	var player_behind_shop := shop_depth_zone.size.x > 0.0 and shop_depth_zone.size.y > 0.0 and shop_depth_zone.has_point(Vector2(player_cell))
	# Keep the shop above the entire player subtree while they are behind it.
	shop.z_index = 12 if player_behind_shop else 9

func _get_shop_depth_zone() -> Rect2:
	var min_cell := Vector2i(999999, 999999)
	var max_cell := Vector2i(-999999, -999999)
	for prop in world.props:
		if str(prop.get("kind", "")) != "shop":
			continue
		for cell_value in prop.get("footprint", []):
			if not cell_value is Vector2i:
				continue
			var cell: Vector2i = cell_value
			min_cell.x = mini(mini(min_cell.x, cell.x), cell.x)
			min_cell.y = mini(mini(min_cell.y, cell.y), cell.y)
			max_cell.x = maxi(maxi(max_cell.x, cell.x), cell.x)
			max_cell.y = maxi(maxi(max_cell.y, cell.y), cell.y)
		break
	if max_cell.x < min_cell.x or max_cell.y < min_cell.y:
		return Rect2()
	# Include one four-cell row above the blocked footprint.
	min_cell.y -= 1
	return Rect2(Vector2(min_cell), Vector2(max_cell - min_cell + Vector2i.ONE))

func _update_bottle_hud() -> void:
	if not is_instance_valid(bottle_button):
		return
	var bottle_index := clampi(game_state.get_defeated_boss_count(), 0, BOTTLE_TEXTURES.size() - 1)
	var texture: Texture2D = BOTTLE_TEXTURES[bottle_index]
	bottle_button.texture_normal = texture
	bottle_overlay_texture.texture = texture
	bottle_message.text = _msg(
		"The World Tree's gift\nOverflow brings new life" if bottle_index < 2 else "The World Tree is calling...",
		"世界树的馈赠\n满溢即是新生" if bottle_index < 2 else "世界树在呼唤它…"
	)
	bottle_close_hint.text = _msg("Click anywhere to close", "单击任意位置关闭")

func _open_bottle_overlay() -> void:
	if bottle_overlay.visible \
	or get_tree().paused \
	or traveling \
	or player.dead \
	or shop_open \
	or radar_open \
	or dialogue_box.is_open():
		return
	_clear_held_fire()
	player.controls_locked = true
	bottle_overlay.show()

func _close_bottle_overlay() -> void:
	if not bottle_overlay.visible:
		return
	bottle_overlay.hide()
	if not player.dead and not traveling:
		player.controls_locked = false

func _on_bottle_overlay_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_close_bottle_overlay()
		get_viewport().set_input_as_handled()

func _has_active_hostiles() -> bool:
	if not is_instance_valid(plants):
		return false
	for child in plants.get_children():
		if child is MeadowLakeMonster and not child.dead and not child.is_queued_for_deletion():
			return true
		if child is MeadowSaxaulBoss and child.mature and not child.dead and not child.is_queued_for_deletion():
			return true
		if child is MeadowPursuingPlant and child.mature and not child.dead and not child.is_queued_for_deletion():
			return true
		if child is MeadowOrangeCactus and child.mature and not child.dead and not child.is_queued_for_deletion():
			return true
	return false

func _on_interaction_requested() -> void:
	if bottle_overlay.visible:
		return
	if dialogue_box.is_open():
		if dialogue_box.is_choice_mode():
			dialogue_box.select_choice(0)
		else:
			dialogue_box.advance()
		return
	if traveling or player.dead or melee_weapon.swinging:
		return
	_clear_held_fire()
	if shop_open:
		_close_shop()
		return
	var player_map_position := world.to_local(player.global_position)
	var player_map_facing := _player_facing_in_map()
	var target := world.get_interaction_target(player_map_position, player_map_facing)
	if target.is_empty():
		_show_toast(_msg("Nothing to interact with here.", "这里没有可互动的东西。"))
		return
	match str(target.get("kind", "")):
		"shop":
			_open_shop()
			return
		"spaceship":
			_open_radar()
			return
		"lookout":
			_open_world_tree_dialogue()
			return
		"lake_npc":
			_open_lake_dialogue()
			return
		"ranger":
			_open_ranger_dialogue()
			return
		"pea_npc":
			_open_pea_npc_dialogue()
			return
		"crate":
			if not bool(target.get("used", false)):
				var already_has_hoe := inventory.has_item(HOE)
				var candidate_state := inventory.export_state()
				var candidate_slots: Array[Dictionary] = []
				candidate_slots.assign(candidate_state.get("slots", []))
				if not already_has_hoe:
					if candidate_slots.is_empty() or not str(candidate_slots[0].get("id", "")).is_empty():
						_show_toast(_msg("Slot 1 must be empty to take the hoe.", "物品栏 1 号位置需要留空才能拿取锄头。"))
						return
					candidate_slots[0] = {"id": HOE, "count": 1}
				var rewards_fit := inventory._add_to_slots(candidate_slots, SMALL_SEED, 3)
				if not rewards_fit:
					_show_toast(_msg("Inventory is full.", "背包已满。"))
					return
				candidate_state["slots"] = candidate_slots
				inventory.import_state(candidate_state)
				world.interact(player_map_position, player_map_facing)
				_show_toast(
					_msg("You found 3 small seeds.", "你找到了 3 颗个头稍小的种子。")
						if already_has_hoe
						else _msg("You found a hoe and 3 small seeds.", "你找到了一个锄头和 3 颗个头稍小的种子。")
				)
				return
	var message := world.interact(player_map_position, player_map_facing)
	_show_toast(message if not message.is_empty() else _msg("Nothing to interact with here.", "这里没有可互动的东西。"))

func _open_ranger_dialogue() -> void:
	if not world.supports_saxaul_encounter():
		return
	player.controls_locked = true
	prompt_box.hide()
	_clear_inventory_sell_tooltip()
	if game_state.sunflower_quest_state >= 2:
		dialogue_box.open_dialogue("迷之向日葵", ["我记忆中的草原回来了！"], _msg("E  Continue|E  Close", "E  继续|E  关闭"))
		return
	if game_state.sunflower_quest_state == 0:
		game_state.sunflower_quest_state = 1
		_mark_save_dirty()
		dialogue_box.open_dialogue("迷之向日葵", [
			"你看起来很不一般",
			"这里从前是一望无际的大草原，可惜现在变成了大荒漠",
			"你能给我找个墨镜来吗，这里的太阳太毒了",
			"我会为你准备一个好东西作为回礼！",
		], _msg("E  Continue|E  Close", "E  继续|E  关闭"))
		return
	var choice := "交付「墨镜」" if inventory.has_item(SUNGLASSES) else "交付「？？？」"
	_dialogue_choice_context = "sunflower"
	dialogue_box.open_choice_dialogue("迷之向日葵", "你来啦？", choice, _msg("E  Select", "E  选择"), "继续")

func _open_pea_npc_dialogue() -> void:
	if not world.enable_pea_npc:
		return
	player.controls_locked = true
	prompt_box.hide()
	_clear_inventory_sell_tooltip()
	if game_state.pea_npc_state >= 1:
		dialogue_box.open_dialogue("豌豆 吗？", ["……"], _msg("E  Continue|E  Close", "E  继续|E  关闭"))
		return
	var choice := "交付「金色豌豆」" if inventory.has_item(MUTATED_PEA_DROP) else "交付「？？？」"
	_dialogue_choice_context = "pea_npc"
	dialogue_box.open_choice_dialogue("豌豆 吗？", "你好。", choice, _msg("E  Select", "E  选择"), "继续")

func _open_world_tree_dialogue() -> void:
	if world.get_map_id() != &"greenmeadow":
		return
	player.controls_locked = true
	prompt_box.hide()
	_clear_inventory_sell_tooltip()
	var lines: Array[String] = []
	var energy_delivered := 0
	if not game_state.world_tree_map_unlocked and game_state.energy > 0:
		energy_delivered = game_state.energy
		game_state.energy = 0
		game_state.world_tree_energy = mini(100, game_state.world_tree_energy + energy_delivered)
		if game_state.world_tree_energy >= 100:
			game_state.world_tree_map_unlocked = true
			if &"world_tree" not in game_state.unlocked_map_ids:
				game_state.unlocked_map_ids.append(&"world_tree")
			lines.append(_msg(
				"The World Tree reaches 100 energy. Its inner realm is now open on the radar.",
				"世界树能量达到 100 点，内在领域现在已在雷达上开放。"
			))
		else:
			lines.append(_msg(
				"The World Tree accepted %d energy. Bring more Boss energy to reach 100." % energy_delivered,
				"世界树吸收了 %d 点能量。继续收集 Boss 能量，直到达到 100 点。" % energy_delivered
			))
	if lines.is_empty():
		if game_state.world_tree_map_unlocked:
			lines.append(_msg(
				"The World Tree is fully charged. Its inner realm is open on the radar.",
				"世界树已经充满能量，内在领域已在雷达上开放。"
			))
		elif game_state.energy <= 0:
			lines.append(_msg(
				"Defeat Bosses and bring their energy here.",
				"击败 Boss 后把能量带到这里。"
			))
	# Energy remains gameplay state but is intentionally not shown in the top bar.
	if energy_delivered > 0:
		_mark_save_dirty()
	dialogue_box.open_dialogue(
		_msg("World Tree", "世界树"),
		lines,
		_msg("E  Continue|E  Close", "E  继续|E  关闭")
	)

func _open_lake_dialogue() -> void:
	if not world.supports_lake_encounter():
		return
	player.controls_locked = true
	prompt_box.hide()
	_clear_inventory_sell_tooltip()
	var speaker := "？？？"
	if quest_state == QUEST_DEFEATED and game_state.has_defeated_boss(BOSS_LAKE):
		if not game_state.world_tree_blessing_unlocked:
			game_state.world_tree_blessing_unlocked = true
			if &"sunset_shore" not in game_state.unlocked_map_ids:
				game_state.unlocked_map_ids.append(&"sunset_shore")
			_mark_save_dirty()
			_show_radar_unlock_toast_on_close = true
			dialogue_box.open_dialogue(speaker, ["救世主…我为你揭示旅途的下一站…"], _msg("E  Continue|E  Close", "E  继续|E  关闭"))
			return
		dialogue_box.open_dialogue(speaker, ["祝你好运…"], _msg("E  Continue|E  Close", "E  继续|E  关闭"))
		return
	if quest_state == QUEST_AWAITING_PLANT:
		var choice := "交付「金色豌豆」" if inventory.has_item(MUTATED_PEA_DROP) else "交付「？？？」"
		_dialogue_choice_context = "lake_keeper"
		dialogue_box.open_choice_dialogue(
			speaker,
			"唯有至金之物能吸引湖中巨兽…",
			choice,
			_msg("E  Select", "E  选择"),
			_msg("Continue", "继续")
		)
		return
	var lines: Array[String] = []
	match quest_state:
		QUEST_SEED_GRANTED:
			lines = [_msg("Plant the blue seed in the pond to awaken the lake.", "把蓝色种子种进池塘，唤醒湖水。")]
		QUEST_WATER_GROWING, QUEST_MONSTER_ACTIVE:
			lines = [_msg("The lake is already awake. Be careful.", "湖水已经醒来。小心。")]
		_:
			lines = [_msg("The lake waits in silence.", "湖水正在寂静中等待。")]
	dialogue_box.open_dialogue(speaker, lines, _msg("E  Continue|E  Close", "E  继续|E  关闭"))

func _on_dialogue_choice_selected(_index: int) -> void:
	if not dialogue_box.is_open():
		return
	match _dialogue_choice_context:
		"sunflower":
			if inventory.try_exchange(SUNGLASSES, SAXAUL_SEED, 1):
				game_state.sunflower_quest_state = 2
				_dialogue_choice_context = ""
				_mark_save_dirty()
				dialogue_box.close_dialogue()
				player.controls_locked = true
				dialogue_box.open_dialogue("迷之向日葵", ["这是梭梭树树种，送你啦，种下去发生什么可跟我没关系！"], _msg("E  Continue|E  Close", "E  继续|E  关闭"))
			return
		"pea_npc":
			if not world.enable_pea_npc or game_state.pea_npc_state >= 2:
				return
			if inventory.remove_item(MUTATED_PEA_DROP, 1):
				game_state.pea_npc_state = 1
				game_state.pea_npc_transform_elapsed = 0.0
				world.set_pea_npc_phase(1)
				world.pea_npc_transform_elapsed = 0.0
				world.queue_redraw()
				_dialogue_choice_context = ""
				_mark_save_dirty()
				dialogue_box.close_dialogue()
				player.controls_locked = true
				dialogue_box.open_dialogue("豌豆 吗？", ["……"], _msg("E  Continue|E  Close", "E  继续|E 关闭"))
			return
		"lake_keeper":
			if quest_state == QUEST_AWAITING_PLANT and inventory.try_exchange(MUTATED_PEA_DROP, BLUE_SEED, 1):
				_dialogue_choice_context = ""
				quest_state = QUEST_SEED_GRANTED
				_mark_save_dirty()
				dialogue_box.close_dialogue()
				player.controls_locked = true
				dialogue_box.open_dialogue(
					"？？？",
					[_msg("Drop it into the water... and it will awaken...", "投入水中…它便会苏醒…")],
					_msg("E  Continue|E  Close", "E  继续|E  关闭")
				)
			return
	_dialogue_choice_context = ""

func _on_dialogue_closed() -> void:
	_clear_held_fire()
	_dialogue_choice_context = ""
	player.controls_locked = player.dead or traveling
	_last_prompt = ""
	if _show_radar_unlock_toast_on_close:
		_show_radar_unlock_toast_on_close = false
		_show_toast("雷达上出现了新的地点")
		radar_panel.set_navigation_state(world.get_map_id(), game_state.unlocked_map_ids)

func _open_radar() -> void:
	_clear_held_fire()
	radar_open = true
	player.controls_locked = true
	_clear_inventory_sell_tooltip()
	prompt_box.hide()
	radar_panel.set_navigation_state(world.get_map_id(), game_state.unlocked_map_ids)
	radar_panel.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_radar() -> void:
	radar_open = false
	player.controls_locked = player.dead or traveling
	radar_panel.hide()
	_last_prompt = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _on_radar_point_selected(map_id: StringName) -> void:
	if map_id == &"world_tree" and map_id not in game_state.unlocked_map_ids:
		_close_radar()
		_show_toast(_msg("This destination has not been revealed yet.", "这个地点还未在雷达上显现。"))
		return
	if map_id == world.get_map_id():
		_close_radar()
		_show_toast(_msg("This destination is already in range.", "当前已在此目的地。"))
		return
	if map_id not in game_state.unlocked_map_ids:
		_show_toast(_msg(
			"Defeat Bosses, deliver their energy to the World Tree, and reach 100 energy.",
			"请击败 Boss，把能量交给世界树，并累计到 100 点。"
		))
		return
	await _travel_to(map_id)

func _travel_to(map_id: StringName) -> void:
	if traveling or not map_host.has_map(map_id) or map_id == world.get_map_id():
		return
	var old_map_id := world.get_map_id()
	_close_radar()
	_close_shop()
	_clear_held_fire()
	traveling = true
	player.controls_locked = true
	player.visible = false
	player.set_collision_layer_value(2, false)
	melee_weapon.cancel_swing()
	map_host.set_runtime_suspended(true)
	if not _capture_and_save():
		map_host.set_runtime_suspended(false)
		traveling = false
		player.controls_locked = player.dead
		_show_toast(_msg("Travel canceled because the game could not be saved.", "无法保存游戏，旅行已取消。"))
		return
	var old_snapshot: Dictionary = game_state.get_map_state(old_map_id)
	var old_game_state := _capture_game_state_memory()
	var old_world := world
	var departure := create_tween().set_parallel(true)
	departure.tween_property(old_world, "ship_transition_offset", Vector2(0, -220), 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	departure.tween_method(old_world.set_ship_flame_length, 12.0, 48.0, 0.55)
	# Await the cover before the longer departure tween so its completion signal
	# cannot be emitted before a listener is attached.
	await travel_transition.cover()
	if departure.is_valid() and departure.is_running():
		await departure.finished
	var next_map := map_host.activate_map(map_id)
	if next_map == null:
		await _rollback_travel(old_map_id, old_snapshot, old_game_state, "Travel failed. You returned to the previous map.")
		return
	_bind_active_map(next_map)
	_restoring = true
	_restore_map_state(game_state.get_map_state(map_id))
	# Commit a safe on-map endpoint so a restart cannot strand the player under
	# the ship; visible disembark begins only after that snapshot is durable.
	player.global_position = world.to_global(
		world.get_disembark_end_position()
	)
	player.velocity = Vector2.ZERO
	world.set_ship_transition_offset(Vector2(0, -220))
	world.set_ship_flame_length(48.0)
	game_state.current_map_id = map_id
	game_state.entry_mode = "running"
	_restoring = false
	_apply_game_language()
	camera.reset_smoothing()
	# A destination is not committed until its frozen snapshot is on disk.
	if not _capture_and_save():
		await _rollback_travel(old_map_id, old_snapshot, old_game_state, "Travel could not be saved. You returned to the previous map.")
		return
	player.global_position = world.to_global(
		world.get_disembark_start_position()
	)
	camera.reset_smoothing()
	var arrival := create_tween().set_parallel(true)
	arrival.tween_property(world, "ship_transition_offset", Vector2.ZERO, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arrival.tween_method(world.set_ship_flame_length, 48.0, 12.0, 1.2)
	var disembark := create_tween()
	disembark.tween_interval(0.65)
	disembark.tween_property(
		player,
		"global_position",
		world.to_global(world.get_disembark_end_position()),
		0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Await reveal first; the destination remains suspended until every arrival
	# animation has completed.
	await travel_transition.reveal()
	if arrival.is_valid() and arrival.is_running():
		await arrival.finished
	if disembark.is_valid() and disembark.is_running():
		await disembark.finished
	map_host.set_runtime_suspended(false)
	player.visible = true
	player.set_collision_layer_value(2, true)
	traveling = false
	player.controls_locked = player.dead
	_show_toast(world.get_arrival_message())

func _capture_game_state_memory() -> Dictionary:
	return {
		"current_map_id": game_state.current_map_id,
		"inventory_state": game_state.inventory_state.duplicate(true),
		"coins": game_state.coins,
		"player_health": game_state.player_health,
		"quest_state": game_state.quest_state,
		"orange_seed_granted": game_state.orange_seed_granted,
		"green_plantings_since_mutation": game_state.green_plantings_since_mutation,
		"unlocked_map_ids": game_state.unlocked_map_ids.duplicate(),
		"map_states": game_state.map_states.duplicate(true),
		"entry_mode": game_state.entry_mode,
		"world_tree_blessing_unlocked": game_state.world_tree_blessing_unlocked,
		"defeated_boss_ids": game_state.defeated_boss_ids.duplicate(),
		"container_energy": game_state.container_energy,
		"sunflower_quest_state": game_state.sunflower_quest_state,
		"map_two_return_count": game_state.map_two_return_count,
		"pea_npc_state": game_state.pea_npc_state,
		"pea_npc_transform_elapsed": game_state.pea_npc_transform_elapsed,
		"world_tree_map_unlocked": game_state.world_tree_map_unlocked,
		"energy": game_state.energy,
		"world_tree_energy": game_state.world_tree_energy,
	}

func _restore_game_state_memory(state: Dictionary) -> void:
	game_state.current_map_id = state.get("current_map_id", game_state.current_map_id)
	game_state.inventory_state = state.get("inventory_state", {}).duplicate(true)
	game_state.coins = int(state.get("coins", game_state.coins))
	game_state.player_health = int(state.get("player_health", game_state.player_health))
	game_state.quest_state = int(state.get("quest_state", game_state.quest_state))
	game_state.orange_seed_granted = bool(state.get("orange_seed_granted", game_state.orange_seed_granted))
	game_state.green_plantings_since_mutation = int(state.get("green_plantings_since_mutation", game_state.green_plantings_since_mutation))
	game_state.unlocked_map_ids.clear()
	game_state.unlocked_map_ids.assign(state.get("unlocked_map_ids", []))
	game_state.map_states = state.get("map_states", {}).duplicate(true)
	game_state.entry_mode = str(state.get("entry_mode", game_state.entry_mode))
	game_state.world_tree_blessing_unlocked = bool(state.get("world_tree_blessing_unlocked", game_state.world_tree_blessing_unlocked))
	game_state.defeated_boss_ids.clear()
	for value in state.get("defeated_boss_ids", []):
		var boss_id := StringName(str(value))
		if boss_id in [&"lake_monster", &"saxaul_boss"] and boss_id not in game_state.defeated_boss_ids:
			game_state.defeated_boss_ids.append(boss_id)
	game_state.container_energy = clampi(int(state.get("container_energy", game_state.container_energy)), 0, 100)
	game_state.sunflower_quest_state = clampi(int(state.get("sunflower_quest_state", game_state.sunflower_quest_state)), 0, 2)
	game_state.map_two_return_count = clampi(int(state.get("map_two_return_count", game_state.map_two_return_count)), 0, 2)
	game_state.pea_npc_state = clampi(int(state.get("pea_npc_state", game_state.pea_npc_state)), 0, 2)
	game_state.pea_npc_transform_elapsed = clampf(float(state.get(
		"pea_npc_transform_elapsed",
		game_state.pea_npc_transform_elapsed
	)), 0.0, MeadowWorld.WORM_TRANSFORM_DURATION)
	game_state.world_tree_map_unlocked = bool(state.get("world_tree_map_unlocked", game_state.world_tree_map_unlocked))
	game_state.energy = clampi(int(state.get("energy", game_state.energy)), 0, 100)
	game_state.world_tree_energy = clampi(int(state.get("world_tree_energy", game_state.world_tree_energy)), 0, 100)
	_update_bottle_hud()
	# Energy remains gameplay state but is intentionally not shown in the top bar.

func _rollback_travel(old_map_id: StringName, old_snapshot: Dictionary, old_game_state: Dictionary, message: String) -> void:
	_restore_game_state_memory(old_game_state)
	player.visible = false
	player.set_collision_layer_value(2, false)
	var restored_map := map_host.activate_map(old_map_id)
	if restored_map == null:
		push_error("Could not restore map after failed travel: %s" % old_map_id)
	else:
		_bind_active_map(restored_map)
		_restoring = true
		_restore_map_state(old_snapshot)
		_place_player_for_entry("continue", old_snapshot)
		_restoring = false
		game_state.current_map_id = old_map_id
		game_state.entry_mode = "running"
		game_state.set_map_state(old_map_id, old_snapshot)
		world.set_ship_transition_offset(Vector2.ZERO)
		world.set_ship_flame_length(12.0)
	# The old map is restored before the cover is removed; gameplay stays frozen
	# until the visual rollback has finished.
	await travel_transition.reveal()
	map_host.set_runtime_suspended(false)
	player.visible = true
	player.set_collision_layer_value(2, true)
	traveling = false
	player.controls_locked = player.dead
	_show_toast(_msg(message, "旅行失败，已返回原地图。"))

func _open_shop() -> void:
	if player.dead or traveling or not is_instance_valid(shop):
		return
	_clear_held_fire()
	melee_weapon.cancel_swing()
	shop_open = true
	player.controls_locked = true
	_clear_inventory_sell_tooltip()
	shop_panel.clear_hover()
	shop_panel.show()
	prompt_box.hide()
	_refresh_coins()

func _close_shop() -> void:
	shop_open = false
	player.controls_locked = player.dead or traveling
	_clear_inventory_sell_tooltip()
	shop_panel.clear_hover()
	shop_panel.hide()
	_last_prompt = ""

func _on_buy_pressed(item_id: String) -> void:
	if player.dead or not shop_open or not shop_panel.is_shop_product(item_id):
		return
	var price := inventory.get_buy_price(item_id)
	if price <= 0:
		return
	if coins < price:
		_show_toast(_msg("Not enough coins.", "金币不足。"))
		return
	if not inventory.try_add(item_id):
		_show_toast(_msg("Inventory is full.", "背包已满。"))
		return
	coins -= price
	_refresh_coins()
	_mark_save_dirty()
	_show_toast(_msg("Bought %s for %d coins." % [inventory.get_item_name(item_id), price], "购买了 %s，花费 %d 金币。" % [inventory.get_item_name(item_id), price]))

func _sell_inventory_slot(slot_index: int) -> void:
	if slot_index < 0:
		return
	var slot := inventory.get_slot(slot_index)
	var item_id := str(slot.get("id", ""))
	if item_id.is_empty():
		return
	var price := inventory.get_sell_price(item_id)
	if price <= 0:
		_show_toast(_msg(
			"%s cannot be sold here." % inventory.get_item_name(item_id),
			"这里不能出售%s。" % inventory.get_item_name(item_id)
		))
		return
	if inventory.remove_from_slot(slot_index):
		coins += price
		_refresh_coins()
		_mark_save_dirty()
		_show_toast(_msg("Sold 1 %s for %d coins." % [inventory.get_item_name(item_id), price], "卖出 1 个%s，获得 %d 金币。" % [inventory.get_item_name(item_id), price]))
	_inventory_sell_tooltip_slot = -1
	_update_inventory_sell_tooltip()

func _update_inventory_sell_tooltip() -> void:
	_update_inventory_tooltip_at(get_viewport().get_mouse_position())

func _update_inventory_tooltip_at(mouse_position: Vector2) -> void:
	if get_tree().paused \
	or player.dead \
	or radar_open \
	or dialogue_box.is_open() \
	or bottle_overlay.visible:
		_clear_inventory_sell_tooltip()
		return
	var slot_index := inventory_hud.get_slot_at_viewport_position(mouse_position)
	if slot_index < 0:
		_clear_inventory_sell_tooltip()
		return
	var slot := inventory.get_slot(slot_index)
	var item_id := str(slot.get("id", ""))
	if item_id.is_empty() or int(slot.get("count", 0)) <= 0:
		_clear_inventory_sell_tooltip()
		return
	var price := inventory.get_sell_price(item_id) if shop_open else inventory.get_buy_price(item_id)
	if _inventory_sell_tooltip_slot != slot_index or _inventory_sell_tooltip_item_id != item_id:
		var price_text := _msg("PRICE: %d COINS" % price, "价格：%d 金币" % price)
		if shop_open:
			price_text = _msg("SELL PRICE: %d COINS" % price, "售价：%d 金币" % price) if price > 0 else _msg("CANNOT BE SOLD", "不可出售")
		elif price <= 0:
			price_text = _msg("NOT FOR SALE", "非卖品")
		inventory_sell_tooltip.text = "%s\n%s" % [inventory.get_item_name(item_id), price_text]
		_inventory_sell_tooltip_slot = slot_index
		_inventory_sell_tooltip_item_id = item_id
	var tooltip_size := inventory_sell_tooltip.size
	var viewport_size := get_viewport_rect().size
	var position := mouse_position + Vector2(14.0, -tooltip_size.y - 10.0)
	position.x = clampf(position.x, 8.0, viewport_size.x - tooltip_size.x - 8.0)
	position.y = clampf(position.y, 8.0, viewport_size.y - tooltip_size.y - 8.0)
	inventory_sell_tooltip.position = position
	inventory_sell_tooltip.show()

func _clear_inventory_sell_tooltip() -> void:
	_inventory_sell_tooltip_slot = -1
	_inventory_sell_tooltip_item_id = ""
	inventory_sell_tooltip.text = ""
	inventory_sell_tooltip.hide()

func _drop_selected_item() -> void:
	var item_id := inventory.get_selected_item_id()
	if item_id.is_empty():
		_show_toast(_msg("This slot is empty.", "当前栏位为空。"))
		return
	if not inventory.is_droppable(item_id):
		_show_toast(_msg("%s cannot be dropped." % inventory.get_item_name(item_id), "%s不能丢弃。" % inventory.get_item_name(item_id)))
		return
	var drop_index := world.drops.size()
	if not world.add_drop(world.to_local(player.global_position), item_id):
		_show_toast(_msg("There is no room for another ground item.", "地面已无法容纳更多物品。"))
		return
	if not inventory.remove_selected():
		world.take_drop(drop_index)
		return
	_show_toast(_msg("Dropped %s. It can be picked up in 3 seconds." % inventory.get_item_name(item_id), "已丢弃 %s，3 秒后可以拾取。" % inventory.get_item_name(item_id)))

func _try_pickup() -> void:
	var index := world.get_pickup_candidate(world.to_local(player.global_position))
	if index < 0:
		return
	var drop := world.drops[index]
	if not inventory.can_add(str(drop["item_id"]), int(drop["count"])):
		return
	var taken := world.take_drop(index)
	if inventory.try_add(str(taken["item_id"]), int(taken["count"])):
		_show_toast(_msg("Picked up %s." % inventory.get_item_name(str(taken["item_id"])), "拾取了 %s。" % inventory.get_item_name(str(taken["item_id"]))))

func _on_fire_requested(origin: Vector2, direction: Vector2, requested_item_id: String = "") -> void:
	if traveling or shop_open or radar_open or dialogue_box.is_open() or player.dead or player.controls_locked:
		return
	var item_id := requested_item_id if not requested_item_id.is_empty() else inventory.get_selected_item_id()
	if item_id == PEA_DROP:
		if inventory.get_selected_item_id() != PEA_DROP:
			return
		if not inventory.consume_selected():
			return
		if not player.heal(1):
			inventory.try_add(PEA_DROP, 1)
			return
		MeadowDamageNumber.spawn_heal(self, player.global_position + Vector2(0, -34), 1)
		_mark_save_dirty()
		return
	var pointer_map_position := world.to_local(get_global_mouse_position())
	var player_map_position := world.to_local(player.global_position)
	var player_map_facing := _player_facing_in_map()
	match item_id:
		HOE:
			var tilled_count := world.till_nearby(player_map_position)
			_show_toast(_msg("Tilled %d nearby tile(s)." % tilled_count, "翻耕了周围 %d 块土地。" % tilled_count) if tilled_count > 0 else _msg("There is no tillable grass here or nearby.", "所在地块与周围没有可翻耕的草地。"))
		GREEN_SEED, SMALL_SEED:
			var seed_cell := world.get_pointer_cell(pointer_map_position, player_map_position, player_map_facing, GREEN_SEED)
			if seed_cell.x < 0 or inventory.get_selected_count() <= 0:
				_show_toast(_msg("Seeds need an adjacent tilled tile in front of you.", "种子需要种在前方相邻的翻耕土地上。"))
				return
			var planting_result := _plant_green_seed_at(seed_cell, item_id)
			if planting_result == "capacity":
				_show_toast(_msg("This map cannot support another active plant.", "这张地图无法容纳更多活动植物。"))
				return
			if planting_result != "planted":
				_show_toast(_msg("Seeds need an adjacent tilled tile in front of you.", "种子需要种在前方相邻的翻耕土地上。"))
				return
			_show_toast(_msg("Seed planted. It will mature in 3 seconds.", "种子已种下，3 秒后成熟。"))
		ORANGE_SEED:
			var sand_cell := world.get_pointer_cell(pointer_map_position, player_map_position, player_map_facing, ORANGE_SEED)
			if sand_cell.x < 0 or inventory.get_selected_count() <= 0:
				_show_toast(_msg("Orange seeds need nearby beach sand in Sunset Shore.", "橙色种子需要种在日落海岸附近的沙地上。"))
				return
			var planting_result := _plant_orange_seed_at(sand_cell)
			if planting_result == "capacity":
				_show_toast(_msg("This map cannot support another active plant.", "这张地图无法容纳更多活动植物。"))
				return
			if planting_result != "planted":
				_show_toast(_msg("Orange seeds need nearby beach sand in Sunset Shore.", "橙色种子需要种在日落海岸附近的沙地上。"))
				return
			_show_toast(_msg("Orange seed planted. It will mature in 3 seconds.", "橙色种子已种下，3 秒后成熟。"))
		SAXAUL_SEED:
			var saxaul_cell := world.get_pointer_cell(
				pointer_map_position,
				player_map_position,
				player_map_facing,
				SAXAUL_SEED
			)
			var planting_result := _plant_saxaul_seed_at(saxaul_cell)
			match planting_result:
				"planted":
					_show_toast(_msg(
						"The saxaul seed is taking root.",
						"梭梭树种子正在扎根。"
					))
				"active":
					_show_toast(_msg(
						"A saxaul boss is already growing here.",
						"这里已经有一棵梭梭树正在生长。"
					))
				"capacity":
					_show_toast(_msg(
						"The map already has too many persistent plants.",
						"地图中可持久化的植物数量已达上限。"
					))
				_:
					_show_toast(_msg(
						"The saxaul seed needs the center of a clear 3 by 3 sand patch.",
						"梭梭树种子必须种在一片完整 3×3 沙地的中央。"
					))
		LILY_SEED, BLUE_SEED:
			_plant_lake_seed(
				pointer_map_position,
				player_map_position,
				player_map_facing,
				item_id
			)
		BOW:
			player.set_attack_facing(direction)
			_spawn_projectile(
				origin + direction * 14.0,
				direction,
				WORLD_MASK | PLANT_MASK | MONSTER_MASK,
				2,
				player,
				Color("#8edb66"),
				520.0,
				0.0,
				preload("res://assets/generated/weapons/forest_bow.png"),
				Rect2(759, 215, 92, 427),
				Vector2(7.0, 38.0),
				deg_to_rad(90.0)
			)
		TREE_GUN:
			# 神树 is maintained by _update_auto_fire after its one-second charge.
			player.set_attack_facing(direction)
		MELEE_WEAPON:
			if melee_weapon.try_swing(direction):
				player.set_attack_facing(direction)

func _plant_saxaul_seed_at(cell: Vector2i) -> String:
	if is_instance_valid(saxaul_boss) or game_state.has_defeated_boss(BOSS_SAXAUL):
		return "active"
	if cell.x < 0 \
	or inventory.get_selected_item_id() != SAXAUL_SEED \
	or inventory.get_selected_count() <= 0:
		return "invalid"
	if not _can_add_persisted_plant():
		return "capacity"
	if not world.plant_saxaul_seed(cell):
		return "invalid"
	var tree := _create_saxaul_boss(cell)
	if tree == null:
		world.clear_farm(cell)
		return "capacity"
	if not inventory.consume_selected():
		tree.free()
		saxaul_boss = null
		world.clear_farm(cell)
		return "invalid"
	_mark_save_dirty()
	return "planted"

func _plant_lake_seed(
	pointer_map_position: Vector2,
	player_map_position: Vector2,
	player_map_facing: Vector2,
	seed_item_id: String
) -> bool:
	var is_blue_seed := seed_item_id == BLUE_SEED
	if quest_state != QUEST_SEED_GRANTED or game_state.has_defeated_boss(BOSS_LAKE):
		_show_toast(_msg("The pond seed is not available right now.", "现在无法种下池塘种子。"))
		return false
	if not world.supports_lake_encounter():
		_show_toast(_msg(
			"This water cannot receive the seed.",
			"这里的水无法种下这颗种子。"
		))
		return false
	if is_instance_valid(lake_monster) or not world.water_growth.is_empty():
		_show_toast(_msg("The lake encounter is already active.", "湖中的战斗已经被唤醒。"))
		return false
	var water_cell := world.get_water_pointer_cell(
		pointer_map_position,
		player_map_position,
		player_map_facing
	)
	if water_cell.x < 0 or not world.plant_blue_seed(water_cell):
		_show_toast(_msg(
			"Blue seeds must be planted in a free pond tile beside you."
				if is_blue_seed
				else "Water lily seeds must be planted in a free pond tile beside you.",
			"蓝色种子必须种在身边空闲的池塘水格里。"
				if is_blue_seed
				else "睡莲种子必须种在身边空闲的池塘水格里。"
		))
		return false
	if inventory.get_selected_item_id() != seed_item_id \
	or not inventory.consume_selected():
		world.clear_water_growth(water_cell)
		return false
	_begin_water_growth(water_cell)
	_show_toast(_msg("The pond begins to stir.", "池塘开始涌动。"))
	return true

func _spawn_projectile(
	origin: Vector2,
	direction: Vector2,
	target_mask: int,
	damage: int,
	source: Node,
	tint: Color,
	speed: float = MeadowProjectile.SPEED,
	beam_length: float = 0.0,
	visual_texture: Texture2D = null,
	visual_source_rect := Rect2(0, 0, 0, 0),
	visual_display_size := Vector2.ZERO,
	rotation_offset := 0.0,
	animated_beam := false
) -> void:
	var projectile := MeadowProjectile.new()
	projectiles.add_child(projectile)
	projectile.setup(
		origin,
		direction,
		get_world_2d().direct_space_state,
		target_mask,
		damage,
		source,
		tint,
		speed,
		beam_length,
		visual_texture,
		visual_source_rect,
		visual_display_size,
		rotation_offset,
		animated_beam
	)
	if animated_beam:
		projectile.beam_texture = preload("res://assets/generated/weapons/tree_gun.png")
		projectile.beam_source_rects.clear()
		for source_rect in [
			Rect2(381, 243, 805, 30),
			Rect2(381, 276, 803, 26),
			Rect2(381, 328, 804, 32),
			Rect2(391, 363, 793, 17),
			Rect2(402, 418, 782, 25),
		]:
			projectile.beam_source_rects.append(source_rect)

func _on_green_plant_projectile_requested(origin: Vector2, directions: Array[Vector2]) -> void:
	if player.dead:
		return
	for direction in directions:
		_spawn_projectile(
			origin + direction * 14.0,
			direction,
			WORLD_MASK | PLAYER_MASK,
			1,
			null,
			Color("#f3c969"),
			180.0,
			0.0,
			MeadowProjectile.MUTATED_PEA_TEXTURE,
			MeadowProjectile.MUTATED_PEA_SOURCE_RECT,
			MeadowProjectile.MUTATED_PEA_DISPLAY_SIZE
		)

func _on_orange_cactus_projectile_requested(origin: Vector2, directions: Array[Vector2]) -> void:
	if player.dead:
		return
	for direction in directions:
		_spawn_projectile(origin + direction * 14.0, direction, WORLD_MASK | PLAYER_MASK, 1, null, Color("#e77a32"), 180.0)

func _plant_green_seed_at(cell: Vector2i, seed_item_id: String = GREEN_SEED) -> String:
	if inventory.get_selected_item_id() != seed_item_id or inventory.get_selected_count() <= 0:
		return "invalid"
	if not _can_add_persisted_plant():
		return "capacity"
	if not world.plant_seed(cell):
		return "invalid"
	var plant := _create_pursuing_plant(cell, {}, seed_item_id == SMALL_SEED)
	if plant == null:
		world.set_farm_tilled(cell)
		return "capacity"
	if not inventory.consume_selected():
		_remove_runtime_plant(plant.cell, plant)
		world.set_farm_tilled(cell)
		return "invalid"
	if seed_item_id != SMALL_SEED:
		if plant is MeadowMutatedPlant:
			game_state.green_plantings_since_mutation = 0
		else:
			game_state.green_plantings_since_mutation += 1
	_mark_save_dirty()
	return "planted"

func _plant_orange_seed_at(cell: Vector2i) -> String:
	if inventory.get_selected_count() <= 0:
		return "invalid"
	if not _can_add_persisted_plant():
		return "capacity"
	if not world.plant_orange_seed(cell):
		return "invalid"
	var cactus := _create_orange_cactus(cell)
	if cactus == null:
		world.clear_farm(cell)
		return "capacity"
	if not inventory.consume_selected():
		_remove_runtime_plant(cactus.cell, cactus)
		world.clear_farm(cell)
		return "invalid"
	_mark_save_dirty()
	return "planted"

func _live_persisted_plant_count() -> int:
	var count := 0
	if not is_instance_valid(plants):
		return count
	for child in plants.get_children():
		if (child is MeadowPursuingPlant or child is MeadowOrangeCactus) \
		and not child.dead \
		and not child.is_queued_for_deletion():
			count += 1
		elif child is MeadowSaxaulBoss \
		and not child.is_queued_for_deletion():
			count += 1
	return count

func _can_add_persisted_plant() -> bool:
	return is_instance_valid(plants) and _live_persisted_plant_count() < MeadowWorld.MAX_PERSISTED_PLANTS

func _live_pursuing_plant_count() -> int:
	var count := 0
	for child in plants.get_children():
		if child is MeadowPursuingPlant and not child.dead and not child.is_queued_for_deletion():
			count += 1
	return count

func _create_pursuing_plant(cell: Vector2i, restored_state: Dictionary = {}, force_green: bool = false) -> MeadowPursuingPlant:
	if not world.is_cell_in_bounds(cell) or not is_instance_valid(plants) or not _can_add_persisted_plant():
		return null
	var is_mutation := bool(restored_state.get("mutated", false))
	if restored_state.is_empty() and not force_green:
		is_mutation = game_state.green_plantings_since_mutation >= 9 or randf() < 0.1
	var plant: MeadowPursuingPlant = MeadowMutatedPlant.new() if is_mutation else MeadowPursuingPlant.new()
	plants.add_child(plant)
	plant.global_position = world.to_global(world.cell_to_world(cell))
	plant.entity_id = str(restored_state.get("entity_id", ""))
	if plant.entity_id.is_empty():
		plant.entity_id = _next_entity_id("plant")
	plant.setup(cell, player, world)
	if not restored_state.is_empty():
		plant.restore_state(restored_state)
	_connect_plant(plant)
	if plant is MeadowMutatedPlant:
		(plant as MeadowMutatedPlant).projectile_requested.connect(_on_green_plant_projectile_requested)
	plant_entities[plant.cell] = int(plant_entities.get(plant.cell, 0)) + 1
	return plant

func _create_saxaul_boss(
	cell: Vector2i,
	restored_state: Dictionary = {}
) -> MeadowSaxaulBoss:
	if not world.supports_saxaul_encounter() \
	or not world.is_cell_in_bounds(cell) \
	or not is_instance_valid(plants) \
	or is_instance_valid(saxaul_boss) \
	or not _can_add_persisted_plant():
		return null
	var tree := MeadowSaxaulBoss.new()
	_saxaul_failure_seed_returned = false
	plants.add_child(tree)
	tree.global_position = world.to_global(world.cell_to_world(cell))
	tree.entity_id = str(restored_state.get("entity_id", ""))
	if tree.entity_id.is_empty():
		tree.entity_id = _next_entity_id("saxaul_boss")
	tree.setup(cell, player, world)
	if not restored_state.is_empty():
		tree.restore_state(restored_state)
	tree.matured.connect(_on_saxaul_matured)
	tree.ring_attack_requested.connect(_on_saxaul_ring_attack)
	tree.vine_volley_requested.connect(_on_saxaul_vine_volley)
	tree.vines_requested.connect(_on_saxaul_vines_requested)
	tree.health_changed.connect(_on_saxaul_health_changed)
	tree.died.connect(_on_saxaul_died)
	saxaul_boss = tree
	if tree.mature and not tree.dead:
		_show_saxaul_boss_bar()
	return tree

func _create_orange_cactus(cell: Vector2i, restored_state: Dictionary = {}) -> MeadowOrangeCactus:
	if not world.supports_orange_farming() or not world.is_cell_in_bounds(cell) or not is_instance_valid(plants) or not _can_add_persisted_plant():
		return null
	var cactus := MeadowOrangeCactus.new()
	plants.add_child(cactus)
	cactus.global_position = world.to_global(world.cell_to_world(cell))
	cactus.entity_id = str(restored_state.get("entity_id", ""))
	if cactus.entity_id.is_empty():
		cactus.entity_id = _next_entity_id("orange_cactus")
	cactus.setup(cell, player, world)
	if not restored_state.is_empty():
		cactus.restore_state(restored_state)
	cactus.projectile_requested.connect(_on_orange_cactus_projectile_requested)
	cactus.died.connect(_on_orange_cactus_died)
	cactus.matured.connect(_on_orange_cactus_matured)
	plant_entities[cactus.cell] = int(plant_entities.get(cactus.cell, 0)) + 1
	return cactus

func _remove_runtime_plant(cell: Vector2i, plant: Node) -> void:
	var count := int(plant_entities.get(cell, 0))
	if count <= 1:
		plant_entities.erase(cell)
	else:
		plant_entities[cell] = count - 1
	plant.queue_free()

func _connect_plant(plant: MeadowPursuingPlant) -> void:
	var drop_item_id := MUTATED_PEA_DROP \
		if plant is MeadowMutatedPlant \
		else PEA_DROP
	plant.died.connect(_on_plant_died.bind(drop_item_id))
	plant.matured.connect(_on_plant_matured)

func _on_plant_matured(cell: Vector2i) -> void:
	world.clear_farm(cell)
	_mark_save_dirty()

func _on_orange_cactus_matured(cell: Vector2i) -> void:
	world.clear_farm(cell)
	_mark_save_dirty()

func _on_orange_cactus_died(cell: Vector2i, global_position: Vector2) -> void:
	_on_plant_died(cell, global_position, CACTUS_DROP)

func _on_plant_died(
	cell: Vector2i,
	global_position: Vector2,
	drop_item_id: String
) -> void:
	var plant_count := int(plant_entities.get(cell, 0))
	if plant_count == 1:
		plant_entities.erase(cell)
	elif plant_count > 1:
		plant_entities[cell] = plant_count - 1
	var dropped := world.add_drop(
		world.to_local(global_position),
		drop_item_id,
		1,
		0
	)
	_mark_save_dirty()
	var item_name := inventory.get_item_name(drop_item_id)
	if dropped:
		_show_toast(_msg(
			"The plant dropped %s. It can be picked up now." % item_name,
			"植物掉落了%s，现在可以拾取。" % item_name
		))
	else:
		_show_toast(_msg(
			"The plant fell, but the ground-item limit was reached.",
			"植物倒下了，但地面物品已达到上限。"
		))

func _next_entity_id(kind: String) -> String:
	var result := "%s:%s:%d" % [world.get_map_id(), kind, next_entity_serial]
	next_entity_serial += 1
	return result

func _on_saxaul_matured(cell: Vector2i) -> void:
	if not world.supports_saxaul_encounter():
		return
	world.convert_saxaul_patch_to_grass(cell)
	_show_saxaul_boss_bar()
	_mark_save_dirty()
	_show_toast(_msg(
		"The saxaul tree turned the surrounding sand into grass!",
		"梭梭树让周围的沙地永久变成了草地！"
	))

func _show_saxaul_boss_bar() -> void:
	if not is_instance_valid(saxaul_boss):
		return
	boss_title.text = _msg("SAXAUL TREE", "梭梭树")
	_on_saxaul_health_changed(
		saxaul_boss.health,
		saxaul_boss.MAX_HEALTH
	)
	boss_bar.show()

func _on_saxaul_ring_attack(
	origin: Vector2,
	directions: Array[Vector2]
) -> void:
	for direction in directions:
		_spawn_projectile(
			origin + direction * 24.0,
			direction,
			WORLD_MASK | PLAYER_MASK,
			1,
			saxaul_boss,
			Color("#9ee66f"),
			520.0,
			72.0
		)

func _on_saxaul_vine_volley(
	origins: Array[Vector2],
	directions: Array[Vector2]
) -> void:
	if player.dead or not is_instance_valid(saxaul_boss) or saxaul_boss.dead:
		return
	for origin in origins:
		for direction in directions:
			_spawn_projectile(
				origin + direction * 12.0,
				direction,
				WORLD_MASK | PLAYER_MASK,
				1,
				saxaul_boss,
				Color("#f3c969"),
				520.0,
				72.0
			)

func _on_saxaul_vines_requested(origins: Array[Vector2]) -> void:
	if not saxaul_vines.is_empty() or not is_instance_valid(saxaul_boss):
		return
	for origin in origins:
		var vine: StaticBody2D = SAXAUL_VINE_SCRIPT.new()
		plants.add_child(vine)
		vine.global_position = origin
		vine.call("setup", player)
		vine.connect("laser_requested", _on_saxaul_vine_laser.bind(vine))
		vine.connect("died", _on_saxaul_vine_died)
		saxaul_vines.append(vine)

func _on_saxaul_vine_laser(origin: Vector2, directions: Array[Vector2], vine: StaticBody2D) -> void:
	if player.dead:
		return
	for direction in directions:
		_spawn_projectile(
			origin + direction * 12.0,
			direction,
			WORLD_MASK | PLAYER_MASK,
			1,
			vine,
			Color("#f3c969"),
			520.0,
			72.0
		)

func _on_saxaul_vine_died(vine: StaticBody2D) -> void:
	saxaul_vines.erase(vine)
	_mark_save_dirty()

func _on_saxaul_health_changed(current: int, maximum: int) -> void:
	_set_boss_health(current, maximum)
	if is_instance_valid(saxaul_boss):
		_mark_save_dirty()

func _clear_saxaul_vines() -> void:
	for vine in saxaul_vines:
		if is_instance_valid(vine):
			vine.set("dead", true)
			vine.queue_free()
	saxaul_vines.clear()

func _on_saxaul_died(cell: Vector2i, global_position: Vector2) -> void:
	_clear_saxaul_vines()
	boss_bar.hide()
	if game_state.has_defeated_boss(BOSS_SAXAUL):
		if not is_instance_valid(saxaul_boss) or saxaul_boss.dead:
			_prepare_saxaul_spread(cell)
		return
	game_state.record_boss_defeat(BOSS_SAXAUL)
	_award_boss_energy()
	_update_bottle_hud()
	_play_boss_death_feedback(global_position)
	_mark_save_dirty()
	if not is_instance_valid(saxaul_boss) or saxaul_boss.dead:
		_prepare_saxaul_spread(cell)
		_mark_save_dirty()
		_show_toast(_msg(
			"The fallen saxaul is spreading grass across the desert.",
			"倒下的梭梭树开始让草地向整片沙漠蔓延。"
		))

func _prepare_saxaul_spread(origin: Vector2i) -> void:
	saxaul_spread_active = true
	saxaul_spread_rings = world.get_sand_spread_rings(origin)
	saxaul_spread_index = 0
	saxaul_spread_elapsed = 0.0
	if saxaul_spread_rings.is_empty():
		saxaul_spread_active = false
		if is_instance_valid(saxaul_boss):
			saxaul_boss.queue_free()
			saxaul_boss = null

func _update_saxaul_grass_spread(delta: float) -> void:
	if not saxaul_spread_active \
	or not world.supports_saxaul_encounter() \
	or not is_instance_valid(saxaul_boss) \
	or not saxaul_boss.dead:
		return
	saxaul_spread_elapsed += delta
	if saxaul_spread_elapsed < SAXAUL_SPREAD_INTERVAL:
		return
	saxaul_spread_elapsed = maxf(
		0.0,
		saxaul_spread_elapsed - SAXAUL_SPREAD_INTERVAL
	)
	if saxaul_spread_index >= saxaul_spread_rings.size():
		saxaul_spread_active = false
		saxaul_boss.queue_free()
		saxaul_boss = null
		_mark_save_dirty()
		_show_toast(_msg(
			"Grass now covers every open patch of desert sand.",
			"草地已经覆盖了所有空旷沙地。"
		))
		return
	world.convert_sand_cells_to_grass(
		saxaul_spread_rings[saxaul_spread_index]
	)
	saxaul_spread_index += 1
	saxaul_spread_rings = world.get_sand_spread_rings(
		saxaul_boss.cell
	)
	saxaul_spread_index = 0
	_mark_save_dirty()

func _begin_water_growth(root: Vector2i) -> void:
	quest_state = QUEST_WATER_GROWING
	water_root = root
	water_growth_elapsed = 0.0
	water_spread_elapsed = 0.0
	water_spread_cells = world.get_water_growth_ring(root)
	water_spread_index = 0
	water_emerge_elapsed = 0.0
	_mark_save_dirty()

func _update_water_encounter(delta: float) -> void:
	if not world.supports_lake_encounter() or quest_state != QUEST_WATER_GROWING or player.dead:
		return
	if water_growth_elapsed < WATER_GROW_TIME:
		water_growth_elapsed += delta
		if water_growth_elapsed >= WATER_GROW_TIME:
			world.set_water_growth_state(water_root, 1)
		return
	if water_spread_index < water_spread_cells.size():
		water_spread_elapsed += delta
		if water_spread_elapsed >= WATER_SPREAD_INTERVAL:
			water_spread_elapsed = 0.0
			world.add_water_growth_cell(water_spread_cells[water_spread_index], water_root, water_spread_index + 1)
			water_spread_index += 1
		return
	water_emerge_elapsed += delta
	if water_emerge_elapsed >= WATER_EMERGE_DELAY:
		_spawn_lake_monster()

func _spawn_lake_monster(restored_state: Dictionary = {}) -> void:
	if game_state.has_defeated_boss(BOSS_LAKE) \
	or is_instance_valid(lake_monster) or not world.supports_lake_encounter():
		return
	quest_state = QUEST_MONSTER_ACTIVE
	var monster := MeadowLakeMonster.new()
	plants.add_child(monster)
	var restored_entity_id := str(restored_state.get("entity_id", ""))
	monster.entity_id = restored_entity_id if not restored_entity_id.is_empty() else _next_entity_id("lake_monster")
	monster.setup(player, world, world.get_water_growth_center(water_root))
	monster.died.connect(_on_lake_monster_died)
	monster.stunned.connect(_on_lake_monster_stunned)
	monster.seed_volley_requested.connect(_on_lake_monster_seed_volley)
	monster.health_changed.connect(_on_lake_monster_health_changed)
	if not restored_state.is_empty():
		monster.restore_state(restored_state)
	lake_monster = monster
	boss_title.text = _msg("WATER LILY", "湖中睡莲")
	_on_lake_monster_health_changed(monster.health, monster.MAX_HEALTH)
	boss_bar.show()
	_mark_save_dirty()
	if restored_state.is_empty():
		_show_toast(_msg("The water lily has awakened!", "湖中睡莲苏醒了！"))

func _on_lake_monster_stunned() -> void:
	_mark_save_dirty()
	_show_toast(_msg("The water lily is stunned for 4 seconds.", "湖中睡莲眩晕 4 秒。"))

func _on_lake_monster_seed_volley(origin: Vector2, directions: Array[Vector2]) -> void:
	if player.dead or not is_instance_valid(lake_monster) or lake_monster.dead:
		return
	for direction in directions:
		_spawn_projectile(origin + direction * 36.0, direction, WORLD_MASK | PLAYER_MASK, 1, lake_monster, Color("#a85de8"), 230.0)

func _set_boss_health(current: int, maximum: int) -> void:
	var ratio := 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	boss_fill.size.x = 620.0 * ratio

func _on_lake_monster_health_changed(current: int, maximum: int) -> void:
	_set_boss_health(current, maximum)
	if is_instance_valid(lake_monster):
		_mark_save_dirty()

func _play_boss_death_feedback(global_position: Vector2) -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(camera):
		var original_offset := camera.offset
		var shake := create_tween()
		shake.tween_property(camera, "offset", original_offset + Vector2(6, -4), 0.06)
		shake.tween_property(camera, "offset", original_offset + Vector2(-5, 4), 0.06)
		shake.tween_property(camera, "offset", original_offset, 0.1)
	for index in range(20):
		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
		dot.color = Color("#69e58a")
		var start := global_position \
			+ Vector2.from_angle(TAU * index / 20.0) \
			* randf_range(8.0, 64.0)
		world.add_child(dot)
		dot.global_position = start
		var home_to_player := func(weight: float) -> void:
			if is_instance_valid(dot) and is_instance_valid(player):
				dot.global_position = start.lerp(player.global_position, weight)
		var tween := dot.create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
		tween.tween_interval(2.0)
		tween.tween_method(home_to_player, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(dot.queue_free)

func _on_lake_monster_died(global_position: Vector2) -> void:
	boss_bar.hide()
	if is_instance_valid(lake_monster):
		lake_monster.set_meta("death_handled", true)
	lake_monster = null
	if quest_state != QUEST_MONSTER_ACTIVE or game_state.has_defeated_boss(BOSS_LAKE):
		return
	if not game_state.record_boss_defeat(BOSS_LAKE):
		return
	_award_boss_energy()
	world.clear_water_growth(water_root)
	water_root = Vector2i(-1, -1)
	quest_state = QUEST_DEFEATED
	_update_bottle_hud()
	_mark_save_dirty()
	_play_boss_death_feedback(global_position)

func _reset_lake_encounter_on_player_death() -> void:
	if not world.supports_lake_encounter() \
	or (quest_state != QUEST_WATER_GROWING \
	and quest_state != QUEST_MONSTER_ACTIVE):
		return
	_clear_active_lake_encounter()
	quest_state = QUEST_SEED_GRANTED
	_return_failed_boss_seed(BLUE_SEED)
	_mark_save_dirty()

func _reset_saxaul_encounter_on_player_death() -> void:
	if _saxaul_failure_seed_returned \
	or not world.supports_saxaul_encounter() \
	or not is_instance_valid(saxaul_boss) \
	or saxaul_boss.dead \
	or game_state.has_defeated_boss(BOSS_SAXAUL):
		return
	_saxaul_failure_seed_returned = true
	var position := world.to_local(player.global_position)
	var boss_cell := saxaul_boss.cell
	var occupied_cells: Dictionary = {}
	for child in plants.get_children():
		if (child is MeadowPursuingPlant or child is MeadowOrangeCactus) \
		and not child.dead \
		and not child.is_queued_for_deletion():
			occupied_cells[child.cell] = true
	_clear_saxaul_vines()
	world.revert_saxaul_patch_to_sand(boss_cell, occupied_cells)
	world.clear_farm(boss_cell)
	saxaul_boss.queue_free()
	saxaul_boss = null
	boss_bar.hide()
	saxaul_spread_active = false
	saxaul_spread_rings.clear()
	_return_failed_boss_seed(SAXAUL_SEED, position)
	_mark_save_dirty()

func _return_failed_boss_seed(
	item_id: String,
	map_position: Vector2 = Vector2.INF
) -> void:
	if inventory.has_item(item_id):
		return
	for drop in world.drops:
		if str(drop.get("item_id", "")) == item_id:
			return
	if inventory.try_add(item_id, 1):
		return
	var drop_position := world.to_local(player.global_position) \
		if map_position == Vector2.INF \
		else map_position
	var safe_position := world.get_nearest_walkable_position(
		drop_position
	)
	if world.add_drop(safe_position, item_id, 1, 0):
		return
	if world.drops.size() >= MeadowWorld.MAX_DROPS:
		world.drops.pop_front()
		world.add_drop(safe_position, item_id, 1, 0)

func _clear_active_lake_encounter() -> void:
	if is_instance_valid(lake_monster):
		lake_monster.dead = true
		lake_monster.queue_free()
	boss_bar.hide()
	lake_monster = null
	if water_root.x >= 0:
		world.clear_water_growth(water_root)
	water_root = Vector2i(-1, -1)
	water_growth_elapsed = 0.0
	water_spread_elapsed = 0.0
	water_spread_cells.clear()
	water_spread_index = 0
	water_emerge_elapsed = 0.0


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = _msg("HP  %d/%d" % [current, maximum], "生命 %d/%d" % [current, maximum])
	_mark_save_dirty()

func _on_player_died() -> void:
	_clear_held_fire()
	melee_weapon.cancel_swing()
	_close_bottle_overlay()
	_reset_lake_encounter_on_player_death()
	_reset_saxaul_encounter_on_player_death()
	_respawn_triggered_for_death = false
	_reset_respawn_hold()
	_close_shop()
	if dialogue_box.is_open():
		dialogue_box.close_dialogue()
	prompt_box.hide()
	_last_prompt = ""
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	toast_box.hide()
	death_overlay.show()
	_capture_and_save()

func _update_death_ui_from_player() -> void:
	death_overlay.visible = player.dead
	player.controls_locked = player.dead

func _update_respawn_hold(delta: float) -> void:
	if _respawn_triggered_for_death:
		return
	if not Input.is_action_pressed("respawn"):
		_reset_respawn_hold()
		return
	_respawn_hold_elapsed = minf(_respawn_hold_elapsed + delta, RESPAWN_HOLD_SECONDS)
	respawn_progress.value = _respawn_hold_elapsed
	if _respawn_hold_elapsed >= RESPAWN_HOLD_SECONDS:
		_respawn_triggered_for_death = true
		_respawn_player()

func _reset_respawn_hold() -> void:
	_respawn_hold_elapsed = 0.0
	respawn_progress.value = 0.0

func _respawn_player() -> void:
	melee_weapon.cancel_swing()
	if not player.respawn_at(world.to_global(world.get_respawn_position())):
		_respawn_triggered_for_death = false
		return
	_reset_respawn_hold()
	death_overlay.hide()
	shop_open = false
	_clear_inventory_sell_tooltip()
	shop_panel.clear_hover()
	shop_panel.hide()
	prompt_box.hide()
	_last_prompt = ""
	camera.reset_smoothing()
	_mark_save_dirty()
	_show_toast(world.get_respawn_message())

func _award_boss_energy() -> void:
	game_state.energy = mini(100, game_state.energy + 50)
	# Energy remains gameplay state but is intentionally not shown in the top bar.
	_mark_save_dirty()

func _refresh_coins() -> void:
	coin_label.text = _msg("COINS  %d" % coins, "金币  %d" % coins)

func _on_inventory_changed() -> void:
	_refresh_inventory()
	_mark_save_dirty()

func _on_inventory_selection_changed(_selected_slot: int) -> void:
	_refresh_inventory()
	_mark_save_dirty()

func _refresh_inventory(_selected_slot: int = -1) -> void:
	inventory_hud.queue_redraw()

func _show_toast(message: String) -> void:
	if message.is_empty():
		return
	_show_persistent_toast(message)
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_box, "modulate:a", 0.0, 0.55)
	_toast_tween.tween_callback(toast_box.hide)

func _show_persistent_toast(message: String) -> void:
	if message.is_empty():
		return
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_tween = null
	toast_label.text = message
	toast_box.modulate = Color.WHITE
	toast_box.show()

func _capture_map_state() -> Dictionary:
	if not is_instance_valid(world):
		return {}
	var result := world.capture_state()
	result["last_player_position"] = _position_to_data(world.to_local(player.global_position))
	result["next_entity_serial"] = next_entity_serial
	var entity_states: Array[Dictionary] = []
	for child in plants.get_children():
		if (child is MeadowPursuingPlant or child is MeadowOrangeCactus) \
		and not child.dead \
		and not child.is_queued_for_deletion():
			entity_states.append(child.capture_state())
		elif child is MeadowSaxaulBoss \
		and not child.is_queued_for_deletion():
			entity_states.append(child.capture_state())
	result["entities"] = entity_states
	result["encounter"] = _capture_encounter_state()
	if world.supports_saxaul_encounter() \
	and is_instance_valid(saxaul_boss) \
	and saxaul_boss.dead \
	and saxaul_spread_active:
		result["saxaul_spread"] = {
			"origin": _cell_to_data(saxaul_boss.cell),
			"elapsed": saxaul_spread_elapsed,
		}
	return result

func _capture_encounter_state() -> Dictionary:
	if not world.supports_lake_encounter():
		return {}
	var spread_data: Array[Array] = []
	for cell in water_spread_cells:
		spread_data.append(_cell_to_data(cell))
	var result := {
		"water_root": _cell_to_data(water_root),
		"growth_elapsed": water_growth_elapsed,
		"spread_elapsed": water_spread_elapsed,
		"spread_cells": spread_data,
		"spread_index": water_spread_index,
		"emerge_elapsed": water_emerge_elapsed,
	}
	if is_instance_valid(lake_monster) and not lake_monster.dead:
		result["monster"] = lake_monster.capture_state()
	return result

func _clear_runtime_entities() -> void:
	boss_bar.hide()
	boss_fill.size.x = 620.0
	saxaul_spread_active = false
	saxaul_spread_rings.clear()
	saxaul_spread_index = 0
	saxaul_spread_elapsed = 0.0
	if not is_instance_valid(plants):
		plant_entities.clear()
		lake_monster = null
		saxaul_boss = null
		saxaul_vines.clear()
		return
	for child in plants.get_children():
		if child is MeadowPursuingPlant \
		or child is MeadowOrangeCactus \
		or child is MeadowLakeMonster \
		or child is MeadowSaxaulBoss \
		or child.get_script() == SAXAUL_VINE_SCRIPT:
			child.free()
	plant_entities.clear()
	lake_monster = null
	saxaul_boss = null
	saxaul_vines.clear()

func _restore_map_state(snapshot: Dictionary) -> void:
	_clear_runtime_entities()
	next_entity_serial = maxi(1, int(snapshot.get("next_entity_serial", 1)))
	water_root = Vector2i(-1, -1)
	water_growth_elapsed = 0.0
	water_spread_elapsed = 0.0
	water_spread_cells.clear()
	water_spread_index = 0
	water_emerge_elapsed = 0.0
	var restored_snapshot := snapshot.duplicate(true)
	_migrate_blocked_farm_entities(restored_snapshot)
	world.restore_state(restored_snapshot)
	for entry_value in restored_snapshot.get("entities", []):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var cell := _data_to_cell(entry.get("cell", []))
		match str(entry.get("kind", "")):
			"pursuing_plant":
				_create_pursuing_plant(cell, entry)
			"orange_cactus":
				_create_orange_cactus(cell, entry)
			"saxaul_boss":
				_saxaul_failure_seed_returned = false
				_create_saxaul_boss(cell, entry)
	if world.supports_lake_encounter():
		_restore_encounter_state(restored_snapshot.get("encounter", {}))
		if quest_state == QUEST_MONSTER_ACTIVE and not is_instance_valid(lake_monster):
			quest_state = QUEST_WATER_GROWING if not world.water_growth.is_empty() else QUEST_SEED_GRANTED
	elif world.supports_saxaul_encounter():
		_restore_saxaul_spread(
			restored_snapshot.get("saxaul_spread", {})
		)
	if map_host.is_runtime_suspended():
		# Restored runtime children are created after map activation, so fold them
		# into the active suspension before travel cover or reveal can advance.
		map_host.set_runtime_suspended(true)

func _migrate_blocked_farm_entities(snapshot: Dictionary) -> void:
	var farm_entries: Array = snapshot.get("farm", [])
	var entity_entries: Array = snapshot.get("entities", [])
	var restored_grass: Dictionary = {}
	for grass_value in snapshot.get("permanent_grass", []):
		restored_grass[_data_to_cell(grass_value)] = true
	var farm_by_cell: Dictionary = {}
	var reserved_cells: Dictionary = {}
	for farm_value in farm_entries:
		if not farm_value is Dictionary:
			continue
		var farm: Dictionary = farm_value
		var farm_cell := _data_to_cell(farm.get("cell", []))
		farm_by_cell[farm_cell] = farm
		if not world.is_prop_cell(farm_cell):
			reserved_cells[farm_cell] = true
	for entity_value in entity_entries:
		if not entity_value is Dictionary:
			continue
		var entity: Dictionary = entity_value
		var kind := str(entity.get("kind", ""))
		if kind != "pursuing_plant" and kind != "orange_cactus":
			continue
		var old_cell := _data_to_cell(entity.get("cell", []))
		if not world.is_prop_cell(old_cell):
			reserved_cells[old_cell] = true
			continue
		var replacement := world.get_nearest_valid_farm_cell(
			old_cell,
			kind,
			reserved_cells,
			restored_grass
		)
		if replacement.x < 0:
			continue
		reserved_cells[replacement] = true
		var old_center := world.cell_to_world(old_cell)
		var entity_position := _data_to_position(
			entity.get("position", [])
		)
		if not is_finite(entity_position.x) \
		or not is_finite(entity_position.y):
			entity_position = old_center
		var offset := entity_position - old_center
		entity["cell"] = _cell_to_data(replacement)
		entity["position"] = _position_to_data(
			world.cell_to_world(replacement) + offset
		)
		if farm_by_cell.has(old_cell):
			var farm: Dictionary = farm_by_cell[old_cell]
			farm["cell"] = _cell_to_data(replacement)
			farm_by_cell.erase(old_cell)
			farm_by_cell[replacement] = farm
	for farm_value in farm_entries:
		if not farm_value is Dictionary:
			continue
		var farm: Dictionary = farm_value
		var old_cell := _data_to_cell(farm.get("cell", []))
		if not world.is_prop_cell(old_cell):
			continue
		var replacement := world.get_nearest_valid_farm_cell(
			old_cell,
			"",
			reserved_cells,
			restored_grass,
			world.supports_orange_farming()
		)
		if replacement.x < 0:
			continue
		farm["cell"] = _cell_to_data(replacement)
		reserved_cells[replacement] = true

func _restore_saxaul_spread(value: Variant) -> void:
	if not value is Dictionary or value.is_empty():
		return
	var spread: Dictionary = value
	if not is_instance_valid(saxaul_boss) or not saxaul_boss.dead:
		return
	var origin := _data_to_cell(
		spread.get("origin", [saxaul_boss.cell.x, saxaul_boss.cell.y])
	)
	if origin != saxaul_boss.cell:
		return
	saxaul_spread_active = true
	saxaul_spread_rings = world.get_sand_spread_rings(origin)
	saxaul_spread_index = 0
	saxaul_spread_elapsed = clampf(
		float(spread.get("elapsed", 0.0)),
		0.0,
		SAXAUL_SPREAD_INTERVAL
	)

func _restore_encounter_state(value: Variant) -> void:
	if not value is Dictionary:
		return
	var encounter: Dictionary = value
	water_root = _data_to_cell(encounter.get("water_root", []))
	water_growth_elapsed = maxf(0.0, float(encounter.get("growth_elapsed", 0.0)))
	water_spread_elapsed = maxf(0.0, float(encounter.get("spread_elapsed", 0.0)))
	for cell_value in encounter.get("spread_cells", []):
		water_spread_cells.append(_data_to_cell(cell_value))
	water_spread_index = clampi(int(encounter.get("spread_index", 0)), 0, water_spread_cells.size())
	water_emerge_elapsed = maxf(0.0, float(encounter.get("emerge_elapsed", 0.0)))
	var monster_value: Variant = encounter.get("monster", {})
	if quest_state == QUEST_MONSTER_ACTIVE and monster_value is Dictionary and not monster_value.is_empty():
		_spawn_lake_monster(monster_value)

func _mark_save_dirty() -> void:
	if _restoring or _closing:
		return
	_save_dirty = true
	_save_debounce_remaining = AUTOSAVE_DEBOUNCE

func _update_autosave(delta: float) -> void:
	if _restoring or traveling or _closing:
		return
	_autosave_elapsed += delta
	var retrying := _save_retry_remaining > 0.0
	if retrying:
		_save_retry_remaining = maxf(0.0, _save_retry_remaining - delta)
		_save_debounce_remaining = _save_retry_remaining
		if _save_retry_remaining > 0.0:
			return
	if _save_dirty and not retrying:
		_save_debounce_remaining = maxf(0.0, _save_debounce_remaining - delta)
	if _autosave_elapsed >= AUTOSAVE_INTERVAL or (_save_dirty and _save_debounce_remaining <= 0.0):
		_capture_and_save()

func _capture_and_save() -> bool:
	if _restoring or not is_instance_valid(world):
		return false
	game_state.capture_global(inventory, coins, player.health, quest_state)
	game_state.set_map_state(world.get_map_id(), _capture_map_state())
	game_state.current_map_id = world.get_map_id()
	var saved: bool = game_state.save_game()
	_autosave_elapsed = 0.0
	if saved:
		var recovered := _save_failure_notified
		_save_dirty = false
		_save_debounce_remaining = 0.0
		_save_retry_remaining = 0.0
		_save_failure_count = 0
		_save_failure_notified = false
		if recovered:
			_show_toast(_msg("Autosave recovered.", "自动保存已恢复。"))
		return true
	_save_dirty = true
	_save_failure_count += 1
	_save_retry_remaining = minf(pow(2.0, float(_save_failure_count - 1)), AUTOSAVE_RETRY_MAX_SECONDS)
	_save_debounce_remaining = _save_retry_remaining
	if not _save_failure_notified:
		_save_failure_notified = true
		_show_toast(_msg("Autosave failed. Retrying shortly.", "自动保存失败，将稍后重试。"))
	return false

func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_held_fire()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_capture_and_save()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and not _closing:
		_closing = true
		if _capture_and_save():
			get_tree().quit()
		else:
			_closing = false
			_show_persistent_toast(_msg("Save failed. The game remains open; check disk space and close again to retry.", "存档失败，游戏将保持开启；请检查磁盘空间后再次关闭。"))

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if get_tree() != null:
		get_tree().auto_accept_quit = true

func _cell_to_data(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]

func _position_to_data(position: Vector2) -> Array[float]:
	return [position.x, position.y]

func _data_to_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)

func _data_to_position(value: Variant) -> Vector2:
	if value is Array and value.size() == 2:
		var position := Vector2(float(value[0]), float(value[1]))
		if is_finite(position.x) and is_finite(position.y):
			return position
	return Vector2(-INF, -INF)
