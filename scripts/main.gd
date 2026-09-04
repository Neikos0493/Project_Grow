class_name MeadowMain
extends Node2D
## Coordinates farming, combat, inventory, shop UI, drops, and world interactions.

const HOE := "hoe"
const GREEN_SEED := "green_seed"
const YELLOW_BALL := "yellow_ball"
const PLANT := "plant"
const YELLOW_BALL_PRICE := 50
const STARTING_COINS := 9999
const WORLD_MASK := 1
const PLAYER_MASK := 2
const PLANT_MASK := 4
const RESPAWN_HOLD_SECONDS := 2.0

@onready var world: MeadowWorld = $World
@onready var player: MeadowPlayer = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var shop: MeadowShop = $Shop
@onready var crosshair: MeadowCrosshair = $CursorLayer/Crosshair
@onready var inventory: MeadowInventory = $Inventory
@onready var projectiles: Node2D = $Projectiles
@onready var plants: Node2D = $Plants
@onready var inventory_hud: MeadowInventoryHud = $HUD/InventoryBar
@onready var coin_label: Label = $HUD/TopBar/CoinLabel
@onready var health_label: Label = $HUD/TopBar/HealthLabel
@onready var shop_panel: MeadowShopPanel = $HUD/ShopPanel
@onready var prompt_box: ColorRect = $HUD/PromptBox
@onready var prompt_label: Label = $HUD/PromptBox/Prompt
@onready var toast_box: ColorRect = $HUD/ToastBox
@onready var toast_label: Label = $HUD/ToastBox/Toast
@onready var death_overlay: ColorRect = $HUD/DeathOverlay
@onready var respawn_progress: ProgressBar = $HUD/DeathOverlay/DeathCard/RespawnProgress

var coins := STARTING_COINS
var shop_open := false
var plant_entities: Dictionary = {}
var _last_prompt := ""
var _toast_tween: Tween
var _respawn_hold_elapsed := 0.0
var _respawn_triggered_for_death := false

func _ready() -> void:
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
	inventory_hud.set_inventory(inventory)
	inventory.inventory_changed.connect(_refresh_inventory)
	inventory.selection_changed.connect(_refresh_inventory)
	if inventory.get_selected_item_id().is_empty():
		inventory.try_add(HOE)
		inventory.try_add(GREEN_SEED, 3)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	shop_panel.hide()
	prompt_box.hide()
	death_overlay.hide()
	respawn_progress.max_value = RESPAWN_HOLD_SECONDS
	respawn_progress.value = 0.0
	_on_health_changed(player.health, player.MAX_HEALTH)
	_refresh_inventory()
	_refresh_coins()
	_show_toast("Explore the meadow. Find the mailbox.")

func _process(delta: float) -> void:
	crosshair.queue_redraw()
	_update_depth_order()
	if not world.drops.is_empty():
		world.queue_redraw()
	if player.dead:
		prompt_box.hide()
		_update_respawn_hold(delta)
		return
	if not shop_open:
		_try_pickup()
	if shop_open:
		prompt_box.hide()
		return
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
	if player.dead:
		return
	if shop_open:
		_close_shop()
		return
	var target := world.get_interaction_target(player.global_position, player.facing)
	if not target.is_empty() and target["kind"] == "shop":
		_open_shop()
		return
	if not target.is_empty() and target["kind"] == "crate" and not bool(target["used"]):
		if not inventory.can_add(GREEN_SEED, 3):
			_show_toast("Inventory is full.")
			return
	var message := world.interact(player.global_position, player.facing)
	if not message.is_empty() and not target.is_empty() and target["kind"] == "crate" and message == "You found a seed packet.":
		if inventory.try_add(GREEN_SEED, 3):
			message = "You found 3 green seeds."

		else:
			_show_toast("Inventory is full.")
			return
	_show_toast("Nothing to interact with here." if message.is_empty() else message)

func _open_shop() -> void:
	if player.dead:
		return
	shop_open = true
	player.controls_locked = true
	shop_panel.clear_hover()
	shop_panel.show()
	prompt_box.hide()
	_refresh_coins()

func _close_shop() -> void:
	shop_open = false
	player.controls_locked = player.dead
	shop_panel.clear_hover()
	shop_panel.hide()
	_last_prompt = ""

func _on_buy_pressed() -> void:
	if player.dead or not shop_open:
		return
	if coins < YELLOW_BALL_PRICE:
		_show_toast("Not enough coins.")
		return
	if not inventory.can_add(YELLOW_BALL):
		_show_toast("Inventory is full.")
		return
	if inventory.try_add(YELLOW_BALL):
		coins -= YELLOW_BALL_PRICE
		_refresh_coins()
		_show_toast("Bought a yellow ball for 50 coins.")

func _sell_inventory_slot(slot_index: int) -> void:
	if slot_index < 0:
		return
	var slot := inventory.get_slot(slot_index)
	var item_id := str(slot.get("id", ""))
	if item_id != PLANT:
		_show_toast("Only plants can be sold here.")
		return
	var price := inventory.get_sell_price(item_id)
	if price <= 0 or not inventory.remove_from_slot(slot_index):
		return
	coins += price
	_refresh_coins()
	_show_toast("Sold 1 plant for %d coins." % price)

func _drop_selected_item() -> void:
	var item_id := inventory.get_selected_item_id()
	if item_id.is_empty():
		_show_toast("This slot is empty.")
		return
	if not inventory.is_droppable(item_id):
		_show_toast("The hoe cannot be dropped.")
		return
	if not inventory.remove_selected():
		return
	world.add_drop(player.global_position, item_id)
	_show_toast("Dropped %s. It can be picked up in 3 seconds." % inventory.get_item_name(item_id))

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
		_show_toast("Picked up %s." % inventory.get_item_name(str(taken["item_id"])))

func _on_fire_requested(origin: Vector2, direction: Vector2) -> void:
	if shop_open or player.dead:
		return
	var item_id := inventory.get_selected_item_id()
	var pointer := get_global_mouse_position()
	match item_id:
		HOE:
			var hoe_cell := world.get_pointer_cell(pointer, player.global_position, player.facing, HOE)
			if world.till(hoe_cell):
				_show_toast("Tilled the ground.")
			else:
				_show_toast("The hoe needs a nearby grass tile in front of you.")
		GREEN_SEED:
			var seed_cell := world.get_pointer_cell(pointer, player.global_position, player.facing, GREEN_SEED)
			if seed_cell.x < 0 or inventory.get_selected_count() <= 0:
				_show_toast("Seeds need an adjacent tilled tile in front of you.")
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
			_show_toast("Seed planted. It will mature in 3 seconds.")
		YELLOW_BALL:
				_spawn_projectile(origin + direction * 14.0, direction, WORLD_MASK | PLANT_MASK, 1, player, Color("#f3c969"))

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
	_show_toast("The plant fell. Pick it up and sell it at the shop.")

func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP  %d/%d" % [current, maximum]

func _on_player_died() -> void:
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
	var spawn_global_position := world.to_global(world.cell_to_world(world.PLAYER_START_CELL))
	if not player.respawn_at(spawn_global_position):
		_respawn_triggered_for_death = false
		return
	_reset_respawn_hold()
	death_overlay.hide()
	shop_open = false
	shop_panel.clear_hover()
	shop_panel.hide()
	prompt_box.hide()
	_last_prompt = ""
	camera.reset_smoothing()
	_show_toast("You returned to the meadow.")

func _refresh_coins() -> void:
	coin_label.text = "COINS  %d" % coins

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
