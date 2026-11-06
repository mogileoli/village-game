extends Node2D
## Connects player input to the simulation and runs it at a fixed tick rate.

const TICK_SECONDS := 1.0
const MAX_SPEED := 3

var sim: VillageSim
var speed := 1

var _active_tool := &""
var _tick_timer := 0.0
var _speed_before_pause := 1
var _last_road_cell := Vector2i.ZERO
var _menu_open := false
## Set by the towers' defense, which comes just before the strike it softens.
var _buildings_saved := 0

@onready var _map: MapView = $Map
@onready var _dragon: DragonView = $Map/Dragon
@onready var _villagers: VillagersView = $Map/Actors/Villagers
@onready var _camera: Camera2D = $Camera
@onready var _hud: Hud = $HUD


func _ready() -> void:
	_hud.tool_selected.connect(func(tool: StringName) -> void: _active_tool = tool)
	_hud.save_requested.connect(_save_game)
	_hud.load_requested.connect(_load_game)
	_hud.menu_toggled.connect(_on_menu_toggled)
	SaveGame.move_old_save_to_slot()
	_hud.set_can_load(SaveGame.any_slot_used())
	_start_sim(VillageSim.new())


func _start_sim(new_sim: VillageSim) -> void:
	sim = new_sim
	sim.stats_changed.connect(_refresh_stats)
	sim.dragon_incoming.connect(_on_dragon_incoming)
	sim.dragon_struck.connect(_on_dragon_struck)
	sim.dragon_defended.connect(_on_dragon_defended)
	_map.bind(sim)
	_dragon.bind(sim, _map)
	_villagers.bind(sim, _map)
	_camera.bounds = _map.world_bounds()
	_camera.position = _map.world_center()
	_tick_timer = 0.0
	_hud.hide_banner()
	_refresh_stats()


func _save_game(slot: int, save_name: String) -> void:
	if SaveGame.write_slot(slot, sim, save_name) != OK:
		_hud.show_status("Couldn't save the game")
		return
	_hud.village_name = SaveGame.clean_name(save_name, slot)
	_hud.set_can_load(true)
	_hud.show_status("Saved in slot %d" % slot)


func _load_game(slot: int) -> void:
	var loaded := SaveGame.read_slot(slot)
	if loaded == null:
		_hud.show_status("Couldn't load: that save is missing or damaged")
		return
	_hud.village_name = SaveGame.slot_info(slot).name
	_start_sim(loaded)
	_hud.show_status("Loaded slot %d" % slot)


## The game waits while the menu is open, and typing a name doesn't move the camera.
func _on_menu_toggled(is_open: bool) -> void:
	_menu_open = is_open
	_camera.set_process(not is_open)
	_camera.set_process_unhandled_input(not is_open)


func _process(delta: float) -> void:
	if _menu_open:
		return
	var sim_delta := delta * speed
	_tick_timer += sim_delta
	while _tick_timer >= TICK_SECONDS:
		_tick_timer -= TICK_SECONDS
		sim.tick()
	_dragon.advance(sim_delta, _tick_timer / TICK_SECONDS)
	_villagers.advance(sim_delta, _tick_timer / TICK_SECONDS)
	_update_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_use_tool(_map.cell_at_mouse())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_hud.clear_tool()
	elif (
		event is InputEventMouseMotion
		and event.button_mask & MOUSE_BUTTON_MASK_LEFT
		and _active_tool == Hud.ROAD
	):
		_paint_road_to(_map.cell_at_mouse())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_hud.clear_tool()
			KEY_SPACE:
				_toggle_pause()
			KEY_1, KEY_2, KEY_3:
				_set_speed(event.physical_keycode - KEY_0)


func _on_dragon_incoming(target: Vector2i) -> void:
	_hud.show_banner("A dragon approaches!")
	_camera.focus_on(_map.cell_center(target))


func _on_dragon_defended(defenders: Array[Vector2i], _threatened: int) -> void:
	_buildings_saved = defenders.size()


func _on_dragon_struck(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
	var saved := _buildings_saved
	_buildings_saved = 0
	var message := ""
	if destroyed.is_empty() and saved > 0:
		message = "Your towers drove off the dragon!"
	elif destroyed.is_empty():
		message = "The dragon found nothing to burn"
	elif destroyed.size() == 1:
		message = "The dragon destroyed a building!"
	else:
		message = "The dragon destroyed %d buildings!" % destroyed.size()
	if saved > 0 and not destroyed.is_empty():
		message += " Towers saved %d." % saved
	_hud.show_banner(message)


func _use_tool(cell: Vector2i) -> void:
	if _active_tool == Hud.DEMOLISH:
		sim.demolish(cell)
	elif _active_tool == Hud.ROAD:
		sim.place_road(cell)
		_last_road_cell = cell
	elif _active_tool != &"":
		sim.place(_active_tool, cell)


## Fills every cell since the last one, so fast drags leave no gaps.
func _paint_road_to(target: Vector2i) -> void:
	var cell := _last_road_cell
	while cell != target:
		if cell.x != target.x:
			cell.x += signi(target.x - cell.x)
		else:
			cell.y += signi(target.y - cell.y)
		sim.place_road(cell)
	_last_road_cell = target


func _update_cursor() -> void:
	var cell := _map.cell_at_mouse()
	if _active_tool == &"tower":
		_map.show_range(cell, VillageSim.TOWER_RANGE)
	else:
		_map.hide_range()
	if _active_tool == Hud.DEMOLISH:
		_map.show_cursor(cell, sim.building_at(cell) != &"" or sim.has_road(cell), &"")
	elif _active_tool == Hud.ROAD:
		_map.show_cursor(cell, sim.can_place_road(cell), &"")
	elif _active_tool != &"":
		_map.show_cursor(cell, sim.can_place(_active_tool, cell), _active_tool)
	else:
		_map.show_cursor(cell, true, &"")


func _toggle_pause() -> void:
	if speed == 0:
		_set_speed(_speed_before_pause)
	else:
		_speed_before_pause = speed
		_set_speed(0)


func _set_speed(value: int) -> void:
	speed = clampi(value, 0, MAX_SPEED)
	_refresh_stats()


func _refresh_stats() -> void:
	_hud.show_stats(sim, speed)
