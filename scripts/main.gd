class_name MeadowMain
extends Node2D
## Coordinates farming, combat, inventory, shop UI, drops, and world interactions.

const HOE := "hoe"
const GREEN_SEED := "green_seed"
const YELLOW_BALL := "yellow_ball"
const MELEE_WEAPON := "melee_weapon"
const PLANT := "plant"
const STARTING_COINS := 9999
const WORLD_MASK := 1
const PLAYER_MASK := 2
const PLANT_MASK := 4
const RESPAWN_HOLD_SECONDS := 2.0

@onready var world: MeadowWorld = $World
@onready var player: MeadowPlayer = $Player
@onready var melee_weapon: MeadowMeleeWeapon = $Player/MeleeWeapon
@onready var camera: Camera2D = $Player/Camera2D
@onready var shop: MeadowShop = $Shop
@onready var crosshair: MeadowCrosshair = $CursorLayer/Crosshair
@onready var inventory: MeadowInventory = $Inventory
@onready var projectiles: Node2D = $Projectiles
@onready var plants: Node2D = $Plants
@onready var inventory_hud: MeadowInventoryHud = $HUD/InventoryBar
@onready var inventory_sell_tooltip: Label = $HUD/InventorySellTooltip
@onready var coin_label: Label = $HUD/TopBar/CoinLabel
@onready var health_label: Label = $HUD/TopBar/HealthLabel
@onready var shop_panel: MeadowShopPanel = $HUD/ShopPanel
@onready var radar_panel: Control = $HUD/RadarPanel
@onready var prompt_box: ColorRect = $HUD/PromptBox
@onready var prompt_label: Label = $HUD/PromptBox/Prompt
@onready var toast_box: ColorRect = $HUD/ToastBox
@onready var toast_label: Label = $HUD/ToastBox/Toast
@onready var death_overlay: ColorRect = $HUD/DeathOverlay
@onready var respawn_progress: ProgressBar = $HUD/DeathOverlay/DeathCard/RespawnProgress

var coins := STARTING_COINS
var language := "en"
var shop_open := false
var radar_open := false
var plant_entities: Dictionary = {}
var _last_prompt := ""
var _inventory_sell_tooltip_slot := -1
var _inventory_sell_tooltip_item_id := ""
var _toast_tween: Tween
var _respawn_hold_elapsed := 0.0
var _respawn_triggered_for_death := false

func _ready() -> void:
	_load_language()
	world.set_language(language)
	inventory.set_language(language)
	shop_panel.set_language(language)
	radar_panel.set_language(language)
	_apply_game_language()
	player.position = world.cell_to_world(world.PLAYER_START_CELL)
	shop.position = world.get_shop_ground_position()
	player.z_index = 10
	_update_depth_order()
	var world_size := world.get_map_size_pixels()
	camera.limit_left = 0
	camera.limit_top = world.get_camera_top_limit()
	camera.limit_right = int(world_size.x)
	camera.limit_bottom = int(world_size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.interaction_requested.connect(_on_interaction_requested)
	player.fire_requested.connect(_on_fire_requested)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	shop_panel.buy_pressed.connect(_on_buy_pressed)
	shop_panel.close_pressed.connect(_close_shop)
	shop_panel.set_inventory(inventory)
	radar_panel.point_selected.connect(_on_radar_point_selected)
	radar_panel.close_pressed.connect(_close_radar)
	inventory_hud.set_inventory(inventory)
	inventory.inventory_changed.connect(_refresh_inventory)
	inventory.selection_changed.connect(_refresh_inventory)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	shop_panel.hide()
	radar_panel.hide()
	prompt_box.hide()
	death_overlay.hide()
	respawn_progress.max_value = RESPAWN_HOLD_SECONDS
	respawn_progress.value = 0.0
	_on_health_changed(player.health, player.MAX_HEALTH)
	_refresh_inventory()
	_refresh_coins()
	_show_toast(_msg("Explore the meadow. Find the mailbox.", "探索草甸，找到邮箱。"))


func _load_language() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		language = str(config.get_value("settings", "language", "en"))

func _msg(english: String, chinese: String) -> String:
	return chinese if language == "zh" else english

func _apply_game_language() -> void:
	$HUD/TopBar/Title.text = _msg("MEADOW PROTOTYPE", "草甸原型")
	$HUD/TopBar/Subtitle.text = _msg("A quiet place to explore", "一处宁静的探索之地")
	$HUD/TopBar/Help.text = _msg("WASD  Move    E  Interact", "WASD 移动    E 互动")
	$HUD/PromptBox/Prompt.text = _msg("E  Interact", "E 互动")
	$HUD/ToastBox/Toast.text = _msg("Explore the meadow.", "探索这片草甸。")
	$HUD/DeathOverlay/DeathCard/DeathTitle.text = _msg("YOU FAINTED", "你昏倒了")
	$HUD/DeathOverlay/DeathCard/RespawnInstruction.text = _msg("Hold SPACE for 2 seconds to return", "长按空格键 2 秒返回")
	$HUD/ShopPanel/DimLabel.text = _msg("WOODLAND SHOP", "林地商店")

func _process(delta: float) -> void:
	crosshair.queue_redraw()
	_update_depth_order()
	if not world.drops.is_empty():
		world.queue_redraw()
	if player.dead:
		prompt_box.hide()
		_clear_inventory_sell_tooltip()
		_update_respawn_hold(delta)
		return
	if not shop_open:
		_try_pickup()
	if radar_open:
		prompt_box.hide()
		_clear_inventory_sell_tooltip()
		return
	if shop_open:
		prompt_box.hide()
		_update_inventory_sell_tooltip()
		return
	_clear_inventory_sell_tooltip()
	var next_prompt := world.get_interaction_prompt(player.global_position, player.facing)
	if next_prompt == _last_prompt:
		return
	_last_prompt = next_prompt
	if next_prompt.is_empty():
		prompt_box.hide()
	else:
		prompt_label.text = "E  " + next_prompt
		prompt_box.show()

func _unhandled_input(event: InputEvent) -> void:
	if player.dead:
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
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				inventory.cycle_selection(-1)
				get_viewport().set_input_as_handled()
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				inventory.cycle_selection(1)
				get_viewport().set_input_as_handled()

func _is_escape(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and key_event.physical_keycode == KEY_ESCAPE and not key_event.echo

func _update_depth_order() -> void:
	var shop_edge_y := shop.global_position.y + world.TILE_SIZE * 0.5
	var same_column: bool = abs(player.global_position.x - shop.global_position.x) <= world.TILE_SIZE * 1.5 + 10.0
	shop.z_index = 11 if same_column and player.global_position.y <= shop_edge_y else 9

func _on_interaction_requested() -> void:
	if player.dead or melee_weapon.swinging:
		return
	if shop_open:
		_close_shop()
		return
	var target := world.get_interaction_target(player.global_position, player.facing)
	if not target.is_empty() and target["kind"] == "shop":
		_open_shop()
		return
	if not target.is_empty() and target["kind"] == "spaceship":
		_open_radar()
		return
	if not target.is_empty() and target["kind"] == "crate" and not bool(target["used"]):
		if not inventory.can_add(GREEN_SEED, 3):
			_show_toast(_msg("Inventory is full.", "背包已满。"))
			return
	var message := world.interact(player.global_position, player.facing)
	if not message.is_empty() and not target.is_empty() and target["kind"] == "crate":
		if inventory.try_add(GREEN_SEED, 3):
			message = _msg("You found 3 green seeds.", "你找到了 3 颗绿种子。")

		else:
			_show_toast(_msg("Inventory is full.", "背包已满。"))
			return
	_show_toast(_msg("Nothing to interact with here.", "这里没有可互动的东西。") if message.is_empty() else message)

func _open_radar() -> void:
	radar_open = true
	player.controls_locked = true
	prompt_box.hide()
	radar_panel.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_radar() -> void:
	radar_open = false
	player.controls_locked = false
	radar_panel.hide()
	_last_prompt = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _on_radar_point_selected(point_id: int) -> void:
	match point_id:
		1:
			_close_radar()
			_show_toast(_msg("Greenmeadow is already in range.", "绿野就在附近。"))
		2:
			_close_radar()
			_show_toast(_msg("Whisper Pond signal locked. New content is growing there.", "静语池塘信号已锁定，那里会有新的内容。"))
		3:
			_close_radar()
			_show_toast(_msg("World Tree signal locked. Keep exploring the meadow.", "世界树信号已锁定，继续探索草甸吧。"))

func _open_shop() -> void:
	if player.dead:
		return
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
	player.controls_locked = player.dead
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
	if not inventory.can_add(item_id):
		_show_toast(_msg("Inventory is full.", "背包已满。"))
		return
	if not inventory.try_add(item_id):
		_show_toast(_msg("Inventory is full.", "背包已满。"))
		return
	coins -= price
	_refresh_coins()
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
		_show_toast(_msg("%s cannot be sold here." % inventory.get_item_name(item_id), "这里不能出售%s。" % inventory.get_item_name(item_id)))
		return
	if not inventory.remove_from_slot(slot_index):
		return
	coins += price
	_refresh_coins()
	_show_toast(_msg("Sold 1 %s for %d coins." % [inventory.get_item_name(item_id), price], "卖出 1 个%s，获得 %d 金币。" % [inventory.get_item_name(item_id), price]))
	_inventory_sell_tooltip_slot = -1
	_update_inventory_sell_tooltip()

func _update_inventory_sell_tooltip() -> void:
	if not shop_open or player.dead:
		_clear_inventory_sell_tooltip()
		return
	var mouse_position := get_viewport().get_mouse_position()
	var slot_index := inventory_hud.get_slot_at_viewport_position(mouse_position)
	if slot_index < 0:
		_clear_inventory_sell_tooltip()
		return
	var slot := inventory.get_slot(slot_index)
	var item_id := str(slot.get("id", ""))
	if item_id.is_empty() or int(slot.get("count", 0)) <= 0:
		_clear_inventory_sell_tooltip()
		return
	var price := inventory.get_sell_price(item_id)
	if price <= 0:
		_clear_inventory_sell_tooltip()
		return
	if _inventory_sell_tooltip_slot != slot_index or _inventory_sell_tooltip_item_id != item_id:
		inventory_sell_tooltip.text = "%s\n%s" % [inventory.get_item_name(item_id), _msg("SELL PRICE: %d COINS" % price, "售价：%d 金币" % price)]
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
	if not inventory.remove_selected():
		return
	world.add_drop(player.global_position, item_id)
	_show_toast(_msg("Dropped %s. It can be picked up in 3 seconds." % inventory.get_item_name(item_id), "已丢弃 %s，3 秒后可以拾取。" % inventory.get_item_name(item_id)))

func _try_pickup() -> void:
	var index := world.get_pickup_candidate(player.global_position)
	if index < 0:
		return
	var drop := world.drops[index]
	var item_id := str(drop["item_id"])
	var count := int(drop["count"])
	if not inventory.can_add(item_id, count):
		return
	var taken := world.take_drop(index)
	if inventory.try_add(str(taken["item_id"]), int(taken["count"])):
		_show_toast(_msg("Picked up %s." % inventory.get_item_name(str(taken["item_id"])), "拾取了 %s。" % inventory.get_item_name(str(taken["item_id"]))))

func _on_fire_requested(origin: Vector2, direction: Vector2) -> void:
	if shop_open or radar_open or player.dead:
		return
	var item_id := inventory.get_selected_item_id()
	var pointer := get_global_mouse_position()
	match item_id:
		HOE:
			var hoe_cell := world.get_pointer_cell(pointer, player.global_position, player.facing, HOE)
			if world.till(hoe_cell):
				_show_toast(_msg("Tilled the ground.", "土地已翻耕。"))
			else:
				_show_toast(_msg("The hoe needs a nearby grass tile in front of you.", "锄头需要对准前方附近的草地。"))
		GREEN_SEED:
			var seed_cell := world.get_pointer_cell(pointer, player.global_position, player.facing, GREEN_SEED)
			if seed_cell.x < 0 or inventory.get_selected_count() <= 0:
				_show_toast(_msg("Seeds need an adjacent tilled tile in front of you.", "种子需要种在前方相邻的翻耕土地上。"))
				return
			if not world.plant_seed(seed_cell):
				return
			var plant := MeadowPlant.new()
			plants.add_child(plant)
			plant.global_position = world.cell_to_world(seed_cell)
			plant.setup(seed_cell, player)
			plant.projectile_requested.connect(_on_plant_projectile_requested)
			plant.died.connect(_on_plant_died)
			plant.matured.connect(_on_plant_matured)
			plant_entities[seed_cell] = plant
			if not inventory.consume_selected():
				plant_entities.erase(seed_cell)
				world.set_farm_tilled(seed_cell)
				plant.queue_free()
				return
			_show_toast(_msg("Seed planted. It will mature in 3 seconds.", "种子已种下，3 秒后成熟。"))
		YELLOW_BALL:
			_spawn_projectile(origin + direction * 14.0, direction, WORLD_MASK | PLANT_MASK, 1, player, Color("#f3c969"))
		MELEE_WEAPON:
			melee_weapon.try_swing(direction)

func _spawn_projectile(origin: Vector2, direction: Vector2, target_mask: int, damage: int, source: Node, tint: Color) -> void:
	var projectile := MeadowProjectile.new()
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, get_world_2d().direct_space_state, target_mask, damage, source, tint)

func _on_plant_projectile_requested(origin: Vector2, direction: Vector2) -> void:
	if player.dead:
		return
	_spawn_projectile(origin + direction * 14.0, direction, WORLD_MASK | PLAYER_MASK, 1, null, Color("#d66b58"))

func _on_plant_matured(cell: Vector2i) -> void:
	world.set_farm_mature(cell)

func _on_plant_died(cell: Vector2i, position: Vector2) -> void:
	if not plant_entities.has(cell):
		return
	plant_entities.erase(cell)
	world.clear_farm(cell)
	world.add_drop(position, PLANT, 1, 0)
	_show_toast(_msg("The plant fell. Pick it up and sell it at the shop.", "植物倒下了，拾取后可以带到商店出售。"))

func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = _msg("HP  %d/%d" % [current, maximum], "生命 %d/%d" % [current, maximum])

func _on_player_died() -> void:
	melee_weapon.cancel_swing()
	_respawn_triggered_for_death = false
	_reset_respawn_hold()
	_close_shop()
	prompt_box.hide()
	_last_prompt = ""
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	toast_box.hide()
	death_overlay.show()

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
	var spawn_global_position := world.to_global(world.cell_to_world(world.PLAYER_START_CELL))
	if not player.respawn_at(spawn_global_position):
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
	_show_toast(_msg("You returned to the meadow.", "你回到了草甸。"))

func _refresh_coins() -> void:
	coin_label.text = _msg("COINS  %d" % coins, "金币  %d" % coins)

func _refresh_inventory(_selected_slot: int = -1) -> void:
	inventory_hud.queue_redraw()

func _show_toast(message: String) -> void:
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	toast_label.text = message
	toast_box.modulate = Color.WHITE
	toast_box.show()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast_box, "modulate:a", 0.0, 0.55)
	_toast_tween.tween_callback(toast_box.hide)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
