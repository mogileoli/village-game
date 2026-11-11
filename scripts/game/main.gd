extends Node2D
## Connects player input to the simulation and runs it at a fixed tick rate.

const TICK_SECONDS := 1.0
const MAX_SPEED := 3

var sim: VillageSim
var speed := 1

var _active_tool := &""
var _tick_timer := 0.0
var _speed_before_pause := 1
var _last_painted_cell := Vector2i.ZERO
var _menu_open := false
var _hero_could_be_created := false
## The hero waiting for the player to click where to send them.
var _teleporting: Hero = null

@onready var _map: MapView = $Map
@onready var _dragon: DragonView = $Map/Dragon
@onready var _villagers: VillagersView = $Map/Actors/Villagers
@onready var _boats: BoatsView = $Map/Actors/Boats
@onready var _camera: CameraController = $Camera
@onready var _hud: Hud = $HUD


func _ready() -> void:
	_hud.tool_selected.connect(func(tool: StringName) -> void:
		if tool != &"":
			_cancel_teleport()
		_active_tool = tool
		_camera.left_drag_pans = tool == &"")
	_hud.save_requested.connect(_save_game)
	_hud.load_requested.connect(_load_game)
	_hud.menu_toggled.connect(_on_menu_toggled)
	_hud.hero_created.connect(_create_hero)
	_hud.hero_focus_requested.connect(func(hero: Hero) -> void:
		_select_hero(hero)
		_focus_on_hero(hero))
	_hud.hero_details_closed.connect(_select_hero.bind(null))
	_hud.teleport_pressed.connect(_on_teleport_pressed)
	_hud.attraction_chosen.connect(_build_attraction)
	SaveGame.move_old_save_to_slot()
	_hud.set_can_load(SaveGame.any_slot_used())
	_start_sim(VillageSim.new())


func _start_sim(new_sim: VillageSim) -> void:
	sim = new_sim
	sim.stats_changed.connect(_refresh_stats)
	sim.dragon_incoming.connect(_on_dragon_incoming)
	sim.dragon_struck.connect(_on_dragon_struck)
	sim.dragon_left.connect(_on_dragon_left)
	sim.hero_wounded.connect(_on_hero_wounded)
	_hero_could_be_created = sim.can_create_hero()
	_map.bind(sim)
	_dragon.bind(sim, _map)
	_villagers.bind(sim, _map)
	_boats.bind(sim, _map)
	_camera.bounds = _map.world_bounds()
	_camera.position = _map.world_center()
	_tick_timer = 0.0
	_hud.hide_banner()
	_hud.close_playground()
	_select_hero(null)
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
	_boats.advance(sim_delta, _tick_timer / TICK_SECONDS)
	_update_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _teleporting != null:
				_teleport_to(_map.cell_at_mouse())
			else:
				_use_tool(_map.cell_at_mouse())
		elif event.button_index == MOUSE_BUTTON_LEFT and _active_tool == &"" and _teleporting == null:
			# On release, because the camera has already taken any release that ends a drag.
			_inspect(_map.cell_at_mouse())
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			# On release, so dragging with the right button to move the map keeps the tool.
			_cancel_teleport()
			_hud.clear_tool()
	elif (
		event is InputEventMouseMotion
		and event.button_mask & MOUSE_BUTTON_MASK_LEFT
		and _active_tool in Hud.PAINT_TOOLS
	):
		_paint_to(_map.cell_at_mouse())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				_cancel_teleport()
				_hud.clear_tool()
			KEY_SPACE:
				_toggle_pause()
			KEY_1, KEY_2, KEY_3:
				_set_speed(event.physical_keycode - KEY_0)


func _on_dragon_incoming(target: Vector2i, level: int) -> void:
	_hud.show_banner("A dragon approaches!" if level == 1 else "A level %d dragon approaches!" % level)
	_camera.focus_on(_map.cell_center(target))


func _on_dragon_struck(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
	if destroyed.size() == 1:
		_hud.show_banner("The dragon destroyed a building!")
	elif destroyed.size() > 1:
		_hud.show_banner("The dragon destroyed %d buildings!" % destroyed.size())


func _on_dragon_left(driven_off: bool, destroyed: int) -> void:
	var losses := ""
	if destroyed == 1:
		losses = " 1 building lost."
	elif destroyed > 1:
		losses = " %d buildings lost." % destroyed
	if sim.dragon_slain:
		var slayers := sim.dragon_slayers()
		var victor := slayers[0].hero_name if slayers.size() == 1 else "Your heroes"
		_hud.show_banner("%s slew the dragon!%s" % [victor, losses])
	elif driven_off:
		_hud.show_banner("You drove off the dragon!" + losses)
	elif destroyed == 0:
		_hud.show_banner("The dragon flew away")
	else:
		_hud.show_banner("The dragon flew away." + losses)


## A click with no tool selects a hero there, or else opens a playground.
func _inspect(cell: Vector2i) -> void:
	var clicked := _villagers.hero_at_mouse()
	if clicked != null:
		_select_hero(clicked)
	elif sim.is_playground(cell):
		_hud.open_playground(sim, cell)
	elif sim.has_buried_attractions(cell):
		var count := sim.attractions_at(cell).size()
		_hud.show_status("Build a Playground here to reopen %d attraction%s" % [count, "" if count == 1 else "s"])


func _build_attraction(cell: Vector2i, type: StringName) -> void:
	if sim.build_attraction(cell, type):
		_hud.show_status("Built the %s" % VillageSim.ATTRACTIONS[type].name)


func _use_tool(cell: Vector2i) -> void:
	if _active_tool == Hud.DEMOLISH:
		sim.demolish(cell)
	elif _active_tool in Hud.PAINT_TOOLS:
		_paint(cell)
		_last_painted_cell = cell
	elif _active_tool != &"":
		sim.place(_active_tool, cell)


func _paint(cell: Vector2i) -> void:
	match _active_tool:
		Hud.ROAD:
			sim.place_road(cell)
		Hud.BRIDGE:
			sim.place_bridge(cell)
		Hud.CLEAR_FOREST:
			sim.clear_forest(cell)


## Fills every cell since the last one, so fast drags leave no gaps.
func _paint_to(target: Vector2i) -> void:
	var cell := _last_painted_cell
	while cell != target:
		if cell.x != target.x:
			cell.x += signi(target.x - cell.x)
		else:
			cell.y += signi(target.y - cell.y)
		_paint(cell)
	_last_painted_cell = target


func _update_cursor() -> void:
	var cell := _map.cell_at_mouse()
	if _teleporting != null:
		_map.hide_range()
		_map.show_cursor(cell, sim.can_teleport_to(cell), &"")
		return
	if _active_tool == &"tower":
		_map.show_range(cell, VillageSim.TOWER_RANGE)
	else:
		_map.hide_range()
	if _active_tool == Hud.DEMOLISH:
		var removable := sim.building_at(cell) != &"" or sim.has_road(cell) or sim.has_buried_attractions(cell)
		_map.show_cursor(cell, removable, &"")
	elif _active_tool == Hud.ROAD:
		_map.show_cursor(cell, sim.can_place_road(cell), &"")
	elif _active_tool == Hud.BRIDGE:
		_map.show_cursor(cell, sim.can_place_bridge(cell), &"")
	elif _active_tool == Hud.CLEAR_FOREST:
		_map.show_cursor(cell, sim.can_clear_forest(cell), &"")
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
	var can_create := sim.can_create_hero()
	if can_create and not _hero_could_be_created:
		_hud.show_banner("Your village can now call a Hero!")
	_hero_could_be_created = can_create


func _create_hero(hero_name: String, armor: StringName, weapon: StringName, look: StringName) -> void:
	if sim.create_hero(hero_name, armor, weapon, look):
		var hero: Hero = sim.heroes[-1]
		_hud.show_banner("%s has come to hunt dragons!" % hero.hero_name)
		_focus_on_hero(hero)


## Shows this hero's details, or closes them if null.
func _select_hero(hero: Hero) -> void:
	_cancel_teleport()
	_villagers.selected_hero = hero
	_hud.show_hero_details(hero)
	_refresh_stats()


func _on_teleport_pressed(hero: Hero) -> void:
	if _teleporting != null:
		_cancel_teleport()
		return
	_hud.clear_tool()
	_teleporting = hero
	_camera.left_drag_pans = false
	_hud.set_teleporting(true)
	_hud.show_status("Click where to send %s" % hero.hero_name)


func _teleport_to(cell: Vector2i) -> void:
	if not sim.teleport_hero(_teleporting, cell):
		_hud.show_status("%s can't go there" % _teleporting.hero_name)
		return
	_hud.show_status("%s teleported" % _teleporting.hero_name)
	_cancel_teleport()


func _cancel_teleport() -> void:
	if _teleporting == null:
		return
	_teleporting = null
	_camera.left_drag_pans = _active_tool == &""
	_hud.set_teleporting(false)


func _focus_on_hero(hero: Hero) -> void:
	_camera.focus_on(_map.cell_center(hero.cell))


func _on_hero_wounded(hero: Hero) -> void:
	_hud.show_banner("%s was wounded and fell back!" % hero.hero_name)
