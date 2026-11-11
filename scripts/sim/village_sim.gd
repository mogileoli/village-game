class_name VillageSim
extends RefCounted
## All game state and rules. Knows nothing about rendering or input, and only
## advances through tick(), so it can run headless in tests.

signal cell_changed(cell: Vector2i)
signal stats_changed
signal dragon_incoming(target: Vector2i, level: int)
signal dragon_struck(destroyed: Array[Vector2i], burned: Array[Vector2i])
## Towers and trained villagers threw water at the dragon from these cells.
signal dragon_hit(attackers: Array[Vector2i], damage: int)
signal dragon_left(driven_off: bool, destroyed: int)
signal hero_attacked(hero: Hero)
signal hero_wounded(hero: Hero)

enum Terrain { GRASS, WATER, FOREST }
## GONE only appears in saves from when there was one dragon per game.
enum DragonState { WAITING, INBOUND, DEPARTING, GONE, RAMPAGE }

const BUILDINGS := {
	&"house": {"name": "House", "cost": 10, "housing": 4},
	&"farm": {"name": "Farm", "cost": 15, "food": 2, "jobs": 2},
	&"lumber_camp": {"name": "Lumber Camp", "cost": 15, "wood": 2, "jobs": 2},
	&"well": {"name": "Well", "cost": 15, "water": 3, "jobs": 2},
	&"tower": {"name": "Tower", "cost": 40, "defense": true},
	&"training_center": {"name": "Training Center", "label": "Training", "cost": 30, "training": 1, "jobs": 2},
	# Docks make food through fishing trips (see _fish), not every tick, so the
	# 0 here only marks food as what they produce.
	&"docks": {"name": "Docks", "cost": 20, "food": 0, "jobs": 2, "on_water": true, "fishing": true},
}
const POPULATION_INTERVAL := 5
## Every this many ticks, each villager eats 1 food and drinks 1 water.
const MEAL_INTERVAL := 4
## Shortages never drive out the last few villagers, so a village can recover.
const FOUNDERS := 4
const PRODUCTS := ["wood", "food", "water", "training"]
## Ticks a villager has to spend inside a training center to become a fighter.
const TRAINING_TICKS := 45
## Towers reach a dragon this many cells away, and fighters reach FIGHTER_RANGE.
const TOWER_RANGE := 6.0
const TOWER_SHOT_WATER := 5
const TOWER_DAMAGE := 6
const FIGHTER_RANGE := 4.0
const FIGHTER_SHOT_WATER := 2
const FIGHTER_DAMAGE := 3
## Saves from before water get enough to last this long while wells go up.
const OLD_SAVE_WATER_TICKS := 60
const CLEAR_START_RADIUS := 5
const SAVE_VERSION := 12
## The first save version that can have roads on water, which are bridges.
const FIRST_BRIDGE_VERSION := 7
const FIRST_HERO_VERSION := 8
## The first save version that can hold more than one hero.
const FIRST_HERO_ROSTER_VERSION := 9
## The first save version with docks, and with villagers' catches of fish.
const FIRST_DOCKS_VERSION := 10
## The first save version that keeps how happy the village is.
const FIRST_HAPPINESS_VERSION := 12
const ROAD_COST := 1
const BRIDGE_COST := 5
## Wood gained from each forest cell cleared.
const CLEARED_FOREST_WOOD := 1
## Cells walked per tick. Path costs match them, so paths take the quickest route.
const GRASS_WALK_SPEED := 0.75
const ROAD_WALK_SPEED := 1.5
const GRASS_PATH_COST := 2.0
const ROAD_PATH_COST := 1.0
const WORK_TICKS := Vector2i(10, 14)
const HOME_TICKS := Vector2i(3, 6)
const OUTSIDE_TICKS := Vector2i(1, 3)
const RETRY_TICKS := 2
const WANDER_RADIUS := 5
const NEAREST_CELL_SEARCH := 8
const DOOR_ORDER := [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]
## A fishing shift at the docks: the boat rows out for this many ticks, fishes,
## then rows back for this many ticks before the shift ends.
const BOAT_ROW_TICKS := 2
## How many cells of water a boat may row out from its dock to find fish.
const FISHING_RANGE := 4
## Fish caught each tick at the fishing spot: this, plus one for each open
## water cell around the spot, so open water out from the shore is richer.
const FISH_BASE_CATCH := 18
## Fish it takes to make one food. An average 12 tick shift has 8 ticks of
## fishing, so open water gives 26 food a shift, a narrow river 20 and a farm
## worker 24.
const FISH_PER_FOOD := 8
const INVALID_CELL := Vector2i(-2, -2)
## One building is under 10% of the village only once there are at least 11,
## so a dragon's timer doesn't run until then.
const DRAGON_MIN_BUILDINGS := 11
const FIRST_DRAGON_WAIT_TICKS := Vector2i(90, 300)
const NEXT_DRAGON_WAIT_TICKS := Vector2i(90, 210)
const DRAGON_INBOUND_TICKS := 5
const DRAGON_DEPARTING_TICKS := 4
## Over the village, the dragon strikes on this tick and then every interval.
const DRAGON_FIRST_STRIKE_TICK := 2
const DRAGON_STRIKE_INTERVAL := 4
const LEVEL_2_FROM_VISIT := 3
const LEVEL_2_MIN_BUILDINGS := 25
## Per level: resolve is how much water damage drives it off; stay is its base
## time over the village, plus a tick per buildings_per_extra_tick buildings;
## damage is the share of buildings it may destroy in a visit; appetite and
## caution steer what it attacks (see dragon_interest).
const DRAGON_LEVELS := {
	1: {
		"resolve": 60, "hero_damage": 25, "stay": Vector2i(10, 13), "buildings_per_extra_tick": 10, "max_extra_stay": 6,
		"damage": Vector2(0.03, 0.099), "burn_radius": Vector2i(0, 1), "caution": 2.0,
		"appetite": {&"farm": 3.0, &"house": 2.0, &"lumber_camp": 1.5, &"well": 1.0, &"training_center": 1.0, &"tower": 0.0},
	},
	2: {
		"resolve": 150, "hero_damage": 40, "stay": Vector2i(16, 20), "buildings_per_extra_tick": 8, "max_extra_stay": 10,
		"damage": Vector2(0.10, 0.199), "burn_radius": Vector2i(1, 1), "caution": 0.5,
		"appetite": {&"training_center": 4.0, &"tower": 3.5, &"house": 2.5, &"farm": 2.0, &"well": 2.0, &"lumber_camp": 1.5},
	},
}
## A hero this close to where a dragon strikes gets burned.
const DRAGON_FIRE_REACH := 3.0
const HERO_MIN_POPULATION := 50
## One hero can be created for every this many villagers.
const VILLAGERS_PER_HERO := 10
const HERO_PATROL_PAUSE := Vector2i(3, 8)
## Ticks a teleported hero holds their new spot before patrolling again.
const HERO_TELEPORT_HOLD := 30
## Health regained each tick when no dragon is visiting.
const HERO_RECOVERY := 4
## How far a wounded hero runs from the dragon.
const HERO_RETREAT_CELLS := 9.0
const HERO_SALT := 5000
const DRAGON_CLUSTER_DISTANCE := 2
const DRAGON_CLUSTER_BONUS := 0.25
const FIGHTER_CAUTION_SHARE := 0.25
## A random nudge to each building's appeal, so dragons don't always pick the same one.
const DRAGON_WHIM := 0.5
const DRAGON_SALT_PLAN := 1000
const DRAGON_SALT_NEXT_WAIT := 2000
const DRAGON_SALT_FIRST_TARGET := 3000

var width: int
var height: int
var wood := 60
var food := 20
var water := 40
var population := 0
var tick_count := 0
var dragon_state := DragonState.WAITING
var dragon_timer := 0
var dragon_target := Vector2i.ZERO
var dragon_seed := 0
var dragon_level := 1
## Visits begun so far, including the current one.
var dragon_visits := 0
var dragon_resolve := 0
var dragon_stay := 0
var dragon_budget := 0
var dragon_destroyed := 0
var dragon_rampage_ticks := 0
var dragon_previous_target := Vector2i.ZERO
var villagers: Array[Villager] = []
var heroes: Array[Hero] = []
var dragon_slain := false
var happiness := Happiness.new()

var _terrain := PackedByteArray()
var _buildings: Dictionary[Vector2i, StringName] = {}
var _scorched: Dictionary[Vector2i, bool] = {}
var _roads: Dictionary[Vector2i, bool] = {}
var _grid := AStarGrid2D.new()
## Goes up whenever walkable cells change, so walkers know to find a new path.
var _layout_version := 0
var _jobs_need_update := true
var _regions: Dictionary[Vector2i, int] = {}
var _workers_at: Dictionary[Vector2i, int] = {}
## Each dock's boat route, worked out again when the layout changes.
var _fishing_routes: Dictionary[Vector2i, Array] = {}
var _fishing_routes_version := -1


## A negative new_dragon_seed picks a different dragon for each new game.
func _init(map_width := 40, map_height := 40, map_seed := 1, new_dragon_seed := -1) -> void:
	width = map_width
	height = map_height
	_generate_terrain(map_seed)
	dragon_seed = randi() if new_dragon_seed < 0 else new_dragon_seed
	dragon_timer = _visit_rng(0).randi_range(FIRST_DRAGON_WAIT_TICKS.x, FIRST_DRAGON_WAIT_TICKS.y)
	_rebuild_grid()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func terrain_at(cell: Vector2i) -> Terrain:
	return _terrain[cell.y * width + cell.x] as Terrain


func building_at(cell: Vector2i) -> StringName:
	return _buildings.get(cell, &"")


func is_scorched(cell: Vector2i) -> bool:
	return _scorched.has(cell)


func building_count() -> int:
	return _buildings.size()


func has_road(cell: Vector2i) -> bool:
	return _roads.has(cell)


## A bridge is a road on a water cell, so people walk on it just as fast.
func is_bridge(cell: Vector2i) -> bool:
	return has_road(cell) and terrain_at(cell) == Terrain.WATER


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _buildings.has(cell) and (terrain_at(cell) == Terrain.GRASS or _roads.has(cell))


func walk_speed(villager: Villager) -> float:
	return (ROAD_WALK_SPEED if has_road(villager.cell) else GRASS_WALK_SPEED) * villager.speed_factor()


func workers_at(cell: Vector2i) -> int:
	_update_jobs()
	return _workers_at.get(cell, 0)


func filled_jobs() -> int:
	_update_jobs()
	var total := 0
	for count: int in _workers_at.values():
		total += count
	return total


func total_jobs() -> int:
	var total := 0
	for type: StringName in _buildings.values():
		total += BUILDINGS[type].get("jobs", 0)
	return total


func houses() -> Array[Vector2i]:
	return _sorted_buildings(func(type: StringName) -> bool: return BUILDINGS[type].has("housing"))


func workplaces() -> Array[Vector2i]:
	return _sorted_buildings(func(type: StringName) -> bool: return BUILDINGS[type].has("jobs"))


func towers() -> Array[Vector2i]:
	return _sorted_buildings(func(type: StringName) -> bool: return BUILDINGS[type].has("defense"))


func housing() -> int:
	var total := 0
	for type: StringName in _buildings.values():
		total += BUILDINGS[type].get("housing", 0)
	return total


func can_place(type: StringName, cell: Vector2i) -> bool:
	return (
		in_bounds(cell)
		and terrain_at(cell) == _terrain_for(type)
		and not _buildings.has(cell)
		and not _roads.has(cell)
		and wood >= BUILDINGS[type].cost
		and (not BUILDINGS[type].has("on_water") or _touches_ground(cell))
	)


## Docks go on water; everything else on grass.
static func _terrain_for(type: StringName) -> Terrain:
	return Terrain.WATER if BUILDINGS[type].has("on_water") else Terrain.GRASS


## Whether people can step onto this water cell from ground beside it.
func _touches_ground(cell: Vector2i) -> bool:
	for side: Vector2i in DOOR_ORDER:
		if is_walkable(cell + side):
			return true
	return false


func place(type: StringName, cell: Vector2i) -> bool:
	if not can_place(type, cell):
		return false
	wood -= BUILDINGS[type].cost
	_buildings[cell] = type
	_scorched.erase(cell)
	_layout_changed(cell)
	cell_changed.emit(cell)
	stats_changed.emit()
	return true


func can_place_road(cell: Vector2i) -> bool:
	return is_walkable(cell) and not _roads.has(cell) and wood >= ROAD_COST


func place_road(cell: Vector2i) -> bool:
	if not can_place_road(cell):
		return false
	wood -= ROAD_COST
	_roads[cell] = true
	_scorched.erase(cell)
	_update_grid_cell(cell)
	cell_changed.emit(cell)
	stats_changed.emit()
	return true


func can_place_bridge(cell: Vector2i) -> bool:
	return (
		in_bounds(cell)
		and terrain_at(cell) == Terrain.WATER
		and not _roads.has(cell)
		and not _buildings.has(cell)
		and wood >= BRIDGE_COST
	)


func place_bridge(cell: Vector2i) -> bool:
	if not can_place_bridge(cell):
		return false
	wood -= BRIDGE_COST
	_roads[cell] = true
	_layout_changed(cell)
	cell_changed.emit(cell)
	stats_changed.emit()
	return true


func can_clear_forest(cell: Vector2i) -> bool:
	return in_bounds(cell) and terrain_at(cell) == Terrain.FOREST


func clear_forest(cell: Vector2i) -> bool:
	if not can_clear_forest(cell):
		return false
	_terrain[cell.y * width + cell.x] = Terrain.GRASS
	wood += CLEARED_FOREST_WOOD
	_layout_changed(cell)
	cell_changed.emit(cell)
	stats_changed.emit()
	return true


func demolish(cell: Vector2i) -> bool:
	if _roads.erase(cell):
		if terrain_at(cell) == Terrain.WATER:
			wood += BRIDGE_COST / 2
			_layout_changed(cell)
			_move_villagers_off(cell)
		else:
			_update_grid_cell(cell)
		cell_changed.emit(cell)
		stats_changed.emit()
		return true
	var type := building_at(cell)
	if type == &"":
		return false
	_buildings.erase(cell)
	# The refund also lets a player who spent all their wood recover.
	wood += BUILDINGS[type].cost / 2
	population = mini(population, housing())
	_layout_changed(cell)
	cell_changed.emit(cell)
	stats_changed.emit()
	return true


func tick() -> void:
	tick_count += 1
	_match_villagers_to_population()
	_update_jobs()
	for villager in villagers:
		if villager.state == Villager.State.WORKING:
			var workplace: Dictionary = BUILDINGS[_buildings[villager.job]]
			if workplace.has("fishing"):
				_fish(villager)
			wood += workplace.get("wood", 0)
			food += workplace.get("food", 0)
			water += workplace.get("water", 0)
			if workplace.has("training") and not is_fighter(villager):
				villager.training += workplace.training
				if is_fighter(villager):
					# Trained: free the place for someone else.
					_jobs_need_update = true
	for index in range(villagers.size()):
		_advance_villager(villagers[index], index)

	if tick_count % MEAL_INTERVAL == 0:
		food = maxi(food - population, 0)
		water = maxi(water - population, 0)

	happiness.update(self)
	if tick_count % POPULATION_INTERVAL == 0:
		_update_population()
	_advance_heroes()
	_advance_dragon()
	stats_changed.emit()


## Shortages drive people out. Otherwise people settle while there's room, faster
## in a happy village and slower in an unhappy one.
func _update_population() -> void:
	var round_number := tick_count / POPULATION_INTERVAL
	var short_of_supplies := food == 0 or water == 0
	if short_of_supplies or happiness.someone_leaves(round_number):
		if population > FOUNDERS:
			population -= 1
	elif population < housing():
		population = mini(population + happiness.settlers(round_number), housing())


## Each factor's happiness score from 0 to 1. See Happiness.FACTORS.
func happiness_factors() -> Dictionary[StringName, float]:
	return happiness.scores(self)


func to_save_data() -> Dictionary:
	var saved_buildings: Array[Dictionary] = []
	for cell: Vector2i in _buildings:
		saved_buildings.append({"x": cell.x, "y": cell.y, "type": String(_buildings[cell])})
	_match_villagers_to_population()
	_update_jobs()
	# A path crossing something just built or removed wouldn't load back.
	for villager in _everyone():
		if villager.state == Villager.State.WALKING and villager.layout_version != _layout_version:
			_reroute(villager)
	var saved_villagers: Array[Dictionary] = []
	for villager in villagers:
		saved_villagers.append(villager.to_data())
	var saved_scorch: Array[Dictionary] = []
	for cell: Vector2i in _scorched:
		saved_scorch.append({"x": cell.x, "y": cell.y})
	var saved_roads: Array[Dictionary] = []
	for cell: Vector2i in _roads:
		saved_roads.append({"x": cell.x, "y": cell.y})
	var data := {
		"version": SAVE_VERSION,
		"width": width,
		"height": height,
		"terrain": Marshalls.raw_to_base64(_terrain),
		"wood": wood,
		"food": food,
		"water": water,
		"population": population,
		"tick_count": tick_count,
		"buildings": saved_buildings,
		"scorched": saved_scorch,
		"roads": saved_roads,
		"villagers": saved_villagers,
		"dragon_state": dragon_state,
		"dragon_timer": dragon_timer,
		"dragon_target_x": dragon_target.x,
		"dragon_target_y": dragon_target.y,
		"dragon_seed": dragon_seed,
		"dragon_level": dragon_level,
		"dragon_visits": dragon_visits,
		"dragon_resolve": dragon_resolve,
		"dragon_stay": dragon_stay,
		"dragon_budget": dragon_budget,
		"dragon_destroyed": dragon_destroyed,
		"dragon_rampage_ticks": dragon_rampage_ticks,
		"dragon_previous_x": dragon_previous_target.x,
		"dragon_previous_y": dragon_previous_target.y,
		"dragon_slain": dragon_slain,
		"heroes": heroes.map(func(hero: Hero) -> Dictionary: return hero.to_data()),
	}
	happiness.save_into(data)
	return data


## Returns null if the data isn't a valid save, so bad files can't corrupt a game.
static func from_save_data(data: Dictionary) -> VillageSim:
	var version := _whole_number(data, "version")
	if version < 1 or version > SAVE_VERSION or not data.get("terrain") is String:
		return null
	var map_width := _whole_number(data, "width")
	var map_height := _whole_number(data, "height")
	var terrain := Marshalls.base64_to_raw(data.terrain)
	if map_width <= 0 or map_height <= 0 or terrain.size() != map_width * map_height:
		return null
	for value in terrain:
		if value >= Terrain.size():
			return null

	var sim := VillageSim.new(map_width, map_height)
	sim._terrain = terrain
	sim.wood = _whole_number(data, "wood")
	sim.food = _whole_number(data, "food")
	sim.water = _whole_number(data, "water") if version >= 5 else 0
	sim.population = _whole_number(data, "population")
	sim.tick_count = _whole_number(data, "tick_count")
	if sim.wood < 0 or sim.food < 0 or sim.water < 0 or sim.population < 0 or sim.tick_count < 0:
		return null

	if not data.get("buildings") is Array:
		return null
	for entry: Variant in data.buildings:
		if not entry is Dictionary or not entry.get("type") is String:
			return null
		var cell := Vector2i(_whole_number(entry, "x"), _whole_number(entry, "y"))
		var type := StringName(entry.type)
		if (
			not BUILDINGS.has(type)
			or not sim.in_bounds(cell)
			or sim.terrain_at(cell) != _terrain_for(type)
			or (BUILDINGS[type].has("on_water") and version < FIRST_DOCKS_VERSION)
			or sim._buildings.has(cell)
		):
			return null
		sim._buildings[cell] = type
	if sim.population > sim.housing():
		return null
	if version >= 3 and not sim._load_roads(data, version):
		return null
	# Saves from before the dragon keep the new dragon chosen by _init().
	if version >= 2 and not sim._load_dragon(data, version):
		return null
	sim._rebuild_grid()
	# Saves from before villagers were simulated get new ones from the population.
	if version >= 4 and not sim._load_villagers(data, version):
		return null
	if version >= FIRST_HERO_VERSION and not sim._load_heroes(data, version):
		return null
	if version < 5:
		sim.water = sim.population * OLD_SAVE_WATER_TICKS / MEAL_INTERVAL
	if version >= FIRST_HAPPINESS_VERSION:
		if not sim.happiness.load_from(data):
			return null
	else:
		# Older saves start out exactly as happy as their village makes them.
		sim.happiness.settle(sim)
	return sim


func _load_villagers(data: Dictionary, version: int) -> bool:
	if not data.get("villagers") is Array or data.villagers.size() != population:
		return false
	for entry: Variant in data.villagers:
		var villager := _read_villager(entry, version)
		if villager == null:
			return false
		villagers.append(villager)
	return true


func _read_villager(entry: Variant, version: int, into: Villager = null) -> Villager:
	if not entry is Dictionary or not entry.get("path") is Array:
		return null
	var villager := into if into != null else Villager.new()
	villager.home = _read_cell(entry.get("home"))
	villager.job = _read_cell(entry.get("job"))
	villager.cell = _read_cell(entry.get("cell"))
	villager.from_building = _read_cell(entry.get("from_building"))
	villager.to_building = _read_cell(entry.get("to_building"))
	var state := _whole_number(entry, "state")
	villager.timer = _whole_number(entry, "timer")
	villager.training = _whole_number(entry, "training") if version >= 6 else 0
	if villager.training < 0:
		return null
	if version >= FIRST_DOCKS_VERSION:
		villager.fish = _whole_number(entry, "fish")
		villager.shift_ticks = _whole_number(entry, "shift_ticks")
		if villager.fish < 0 or villager.shift_ticks < 0:
			return null
	if state < 0 or state >= Villager.State.size() or villager.timer < 0:
		return null
	villager.state = state as Villager.State
	for cell in [villager.home, villager.job, villager.cell, villager.from_building, villager.to_building]:
		if cell == INVALID_CELL:
			return null
	for step: Variant in entry.path:
		var cell := _read_cell(step)
		if not is_walkable(cell):
			return null
		villager.path.append(cell)
	var progress: Variant = entry.get("progress")
	if not (progress is float or progress is int):
		return null
	villager.progress = progress
	var walking := villager.state == Villager.State.WALKING
	if walking and (villager.path.is_empty() or villager.progress < -0.5 or villager.progress > villager.trip_end()):
		return null
	villager.layout_version = _layout_version
	return villager


## Returns INVALID_CELL unless the value is an [x, y] pair on the map or NO_CELL.
func _read_cell(value: Variant) -> Vector2i:
	if not value is Array or value.size() != 2:
		return INVALID_CELL
	var pair := {"x": value[0], "y": value[1]}
	if pair.x is float and pair.x == -1.0 and pair.y is float and pair.y == -1.0:
		return Villager.NO_CELL
	if pair.x is int and pair.x == -1 and pair.y is int and pair.y == -1:
		return Villager.NO_CELL
	var cell := Vector2i(_whole_number(pair, "x"), _whole_number(pair, "y"))
	return cell if in_bounds(cell) else INVALID_CELL


func _load_roads(data: Dictionary, version: int) -> bool:
	if not data.get("roads") is Array:
		return false
	for entry: Variant in data.roads:
		if not entry is Dictionary:
			return false
		var cell := Vector2i(_whole_number(entry, "x"), _whole_number(entry, "y"))
		var valid_bridge := version >= FIRST_BRIDGE_VERSION and in_bounds(cell) and terrain_at(cell) == Terrain.WATER
		if not (is_walkable(cell) or valid_bridge) or _roads.has(cell):
			return false
		_roads[cell] = true
	return true


func _load_dragon_visit(data: Dictionary) -> bool:
	dragon_level = _whole_number(data, "dragon_level")
	dragon_visits = _whole_number(data, "dragon_visits")
	dragon_resolve = _whole_number(data, "dragon_resolve")
	dragon_stay = _whole_number(data, "dragon_stay")
	dragon_budget = _whole_number(data, "dragon_budget")
	dragon_destroyed = _whole_number(data, "dragon_destroyed")
	dragon_rampage_ticks = _whole_number(data, "dragon_rampage_ticks")
	dragon_previous_target = Vector2i(_whole_number(data, "dragon_previous_x"), _whole_number(data, "dragon_previous_y"))
	if not DRAGON_LEVELS.has(dragon_level) or dragon_state == DragonState.GONE:
		return false
	for value in [dragon_visits, dragon_resolve, dragon_stay, dragon_budget, dragon_destroyed, dragon_rampage_ticks]:
		if value < 0:
			return false
	return in_bounds(dragon_previous_target)


func _load_dragon(data: Dictionary, version: int) -> bool:
	var state := _whole_number(data, "dragon_state")
	dragon_timer = _whole_number(data, "dragon_timer")
	dragon_seed = _whole_number(data, "dragon_seed")
	dragon_target = Vector2i(_whole_number(data, "dragon_target_x"), _whole_number(data, "dragon_target_y"))
	if state < 0 or state >= DragonState.size() or dragon_timer < 0 or dragon_seed < 0:
		return false
	if not in_bounds(dragon_target) or not data.get("scorched") is Array:
		return false
	dragon_state = state as DragonState
	if version >= 6:
		if not _load_dragon_visit(data):
			return false
	elif dragon_state == DragonState.GONE:
		# Saves from when only one dragon came: the next one is on its way.
		dragon_visits = 1
		dragon_state = DragonState.WAITING
		dragon_timer = _visit_rng(DRAGON_SALT_NEXT_WAIT).randi_range(NEXT_DRAGON_WAIT_TICKS.x, NEXT_DRAGON_WAIT_TICKS.y)
	elif dragon_state != DragonState.WAITING:
		dragon_visits = 1
		_plan_visit()
		dragon_previous_target = dragon_target
		if dragon_state == DragonState.DEPARTING:
			dragon_destroyed = dragon_budget
	for entry: Variant in data.scorched:
		if not entry is Dictionary:
			return false
		var cell := Vector2i(_whole_number(entry, "x"), _whole_number(entry, "y"))
		if not is_walkable(cell) or _roads.has(cell):
			return false
		_scorched[cell] = true
	return true


## JSON numbers load as floats. Returns -1 for anything that isn't a whole number.
static func _whole_number(data: Dictionary, key: String) -> int:
	var value: Variant = data.get(key)
	if value is int:
		return value
	if value is float and value == floorf(value):
		return int(value)
	return -1


func _advance_dragon() -> void:
	match dragon_state:
		DragonState.WAITING:
			if _buildings.size() < DRAGON_MIN_BUILDINGS:
				return
			dragon_timer -= 1
			if dragon_timer <= 0:
				_dragon_set_off()
		DragonState.INBOUND:
			dragon_timer -= 1
			if dragon_timer <= 0:
				dragon_state = DragonState.RAMPAGE
				dragon_rampage_ticks = 0
		DragonState.RAMPAGE:
			_dragon_rampage_tick()
		DragonState.DEPARTING:
			dragon_timer -= 1
			if dragon_timer <= 0:
				dragon_state = DragonState.WAITING
				dragon_timer = _visit_rng(DRAGON_SALT_NEXT_WAIT).randi_range(NEXT_DRAGON_WAIT_TICKS.x, NEXT_DRAGON_WAIT_TICKS.y)


func dragon_is_visiting() -> bool:
	return dragon_state in [DragonState.INBOUND, DragonState.RAMPAGE]


func dragon_max_resolve() -> int:
	return DRAGON_LEVELS[dragon_level].resolve


## Ticks until the next strike, or -1 if no more strikes are planned this visit.
func dragon_ticks_until_strike() -> int:
	if dragon_state == DragonState.INBOUND:
		return dragon_timer + DRAGON_FIRST_STRIKE_TICK
	if dragon_state != DragonState.RAMPAGE:
		return -1
	var next := DRAGON_FIRST_STRIKE_TICK
	while next <= dragon_rampage_ticks:
		next += DRAGON_STRIKE_INTERVAL
	return next - dragon_rampage_ticks if next <= dragon_stay else -1


## The rampage tick of the latest strike, or 0 before the first one.
func dragon_last_strike_tick() -> int:
	if dragon_rampage_ticks < DRAGON_FIRST_STRIKE_TICK:
		return 0
	var since_first := dragon_rampage_ticks - DRAGON_FIRST_STRIKE_TICK
	return dragon_rampage_ticks - since_first % DRAGON_STRIKE_INTERVAL


## How much this visit's dragon wants to attack a building. It's drawn to the
## building types it likes and to clusters, and put off by nearby defenses,
## though a level 2 dragon is much bolder than a level 1.
func dragon_interest(cell: Vector2i) -> float:
	var level: Dictionary = DRAGON_LEVELS[dragon_level]
	var interest: float = level.appetite.get(_buildings.get(cell, &""), 1.0)
	for other: Vector2i in _buildings:
		if other != cell and _distance(other, cell) <= DRAGON_CLUSTER_DISTANCE:
			interest += DRAGON_CLUSTER_BONUS
	for tower in towers():
		if Vector2(tower).distance_to(Vector2(cell)) <= TOWER_RANGE:
			interest -= level.caution
	for villager in villagers:
		if is_fighter(villager) and Vector2(villager.cell).distance_to(Vector2(cell)) <= FIGHTER_RANGE:
			interest -= level.caution * FIGHTER_CAUTION_SHARE
	return interest


func _dragon_set_off() -> void:
	dragon_visits += 1
	var big_enough := _buildings.size() >= LEVEL_2_MIN_BUILDINGS
	dragon_level = 2 if dragon_visits >= LEVEL_2_FROM_VISIT and big_enough else 1
	_plan_visit()
	dragon_target = _choose_dragon_target(DRAGON_SALT_FIRST_TARGET)
	dragon_previous_target = dragon_target
	dragon_state = DragonState.INBOUND
	dragon_timer = DRAGON_INBOUND_TICKS
	dragon_incoming.emit(dragon_target, dragon_level)
	_call_fighters()


## Decides how long the dragon stays and how many buildings it may destroy.
## Both grow with the village, and both are bigger for a level 2 dragon.
func _plan_visit() -> void:
	var level: Dictionary = DRAGON_LEVELS[dragon_level]
	var rng := _visit_rng(DRAGON_SALT_PLAN)
	var base_stay: Vector2i = level.stay
	var damage: Vector2 = level.damage
	dragon_resolve = level.resolve
	dragon_stay = rng.randi_range(base_stay.x, base_stay.y) + mini(
		level.max_extra_stay, _buildings.size() / level.buildings_per_extra_tick
	)
	dragon_budget = maxi(floori(_buildings.size() * rng.randf_range(damage.x, damage.y)), 1)
	dragon_destroyed = 0
	dragon_rampage_ticks = 0
	dragon_slain = false
	for hero in heroes:
		hero.fought = false


func _choose_dragon_target(salt: int) -> Vector2i:
	var rng := _visit_rng(salt)
	var cells: Array[Vector2i] = _buildings.keys()
	cells.sort()
	var best := dragon_target
	var best_interest := -INF
	for cell in cells:
		var interest := dragon_interest(cell) + rng.randf() * DRAGON_WHIM
		if interest > best_interest:
			best_interest = interest
			best = cell
	return best


func _dragon_rampage_tick() -> void:
	dragon_rampage_ticks += 1
	_defenders_attack()
	_heroes_attack()
	if dragon_resolve <= 0:
		_dragon_leave(true)
		return
	if dragon_last_strike_tick() == dragon_rampage_ticks:
		_dragon_strike()
	# A hero's challenge holds the dragon for its whole stay. It can't burn more for it.
	if dragon_state == DragonState.RAMPAGE and (
		dragon_rampage_ticks >= dragon_stay or (dragon_destroyed >= dragon_budget and not _any_able_hero())
	):
		_dragon_leave(false)


## Burns the buildings closest to the target, spreading the visit's damage over
## its remaining strikes. If the player demolished buildings during the visit,
## the limit can't be met, so a too-small village loses nothing.
func _dragon_strike() -> void:
	var destroyed: Array[Vector2i] = []
	var burned: Array[Vector2i] = []
	var remaining := dragon_budget - dragon_destroyed
	if _buildings.size() >= DRAGON_MIN_BUILDINGS and remaining > 0:
		var strikes_left := 1 + (dragon_stay - dragon_rampage_ticks) / DRAGON_STRIKE_INTERVAL
		var count := mini(remaining, ceili(float(remaining) / strikes_left))
		var cells: Array[Vector2i] = _buildings.keys()
		cells.sort_custom(_closer_to_dragon)
		destroyed = cells.slice(0, count)
		for cell in destroyed:
			_buildings.erase(cell)
			_layout_changed(cell)
			cell_changed.emit(cell)
		population = mini(population, housing())
		happiness.dragon_destroyed(destroyed.size())
		var radius: Vector2i = DRAGON_LEVELS[dragon_level].burn_radius
		burned = _burn_around(destroyed, _visit_rng(dragon_rampage_ticks).randi_range(radius.x, radius.y))
		dragon_destroyed += destroyed.size()
	_burn_heroes()
	dragon_struck.emit(destroyed, burned)
	if not _buildings.is_empty():
		dragon_previous_target = dragon_target
		dragon_target = _choose_dragon_target(DRAGON_SALT_FIRST_TARGET + dragon_rampage_ticks)
		_call_fighters()


func _dragon_leave(driven_off: bool) -> void:
	dragon_slain = driven_off and not dragon_slayers().is_empty()
	if dragon_slain:
		for hero in dragon_slayers():
			hero.dragons_slain += 1
	dragon_state = DragonState.DEPARTING
	dragon_timer = DRAGON_DEPARTING_TICKS
	dragon_left.emit(driven_off, dragon_destroyed)


## Towers and trained villagers near the dragon throw water at it while water lasts.
func _defenders_attack() -> void:
	var attackers: Array[Vector2i] = []
	var damage := 0
	for tower in towers():
		if water < TOWER_SHOT_WATER:
			break
		if Vector2(tower).distance_to(Vector2(dragon_target)) <= TOWER_RANGE:
			water -= TOWER_SHOT_WATER
			damage += TOWER_DAMAGE
			attackers.append(tower)
	for villager in villagers:
		if water < FIGHTER_SHOT_WATER:
			break
		if is_fighter(villager) and _is_outdoors(villager) and _near_dragon(villager.cell):
			water -= FIGHTER_SHOT_WATER
			damage += FIGHTER_DAMAGE
			attackers.append(villager.cell)
	if damage > 0:
		dragon_resolve = maxi(dragon_resolve - damage, 0)
		dragon_hit.emit(attackers, damage)


func _is_outdoors(villager: Villager) -> bool:
	return villager.state in [Villager.State.WALKING, Villager.State.OUTSIDE]


func _near_dragon(cell: Vector2i) -> bool:
	return cell != Villager.NO_CELL and Vector2(cell).distance_to(Vector2(dragon_target)) <= FIGHTER_RANGE


## Sends every trained villager toward the dragon's target.
func _call_fighters() -> void:
	for index in range(villagers.size()):
		var villager := villagers[index]
		if is_fighter(villager) and not _near_dragon(villager.cell):
			_send_to_dragon(villager, index)


func _send_to_dragon(villager: Villager, index: int) -> bool:
	if villager.state == Villager.State.WALKING and villager.path.size() > 0 and _near_dragon(villager.path[-1]):
		return true
	var from_building := Villager.NO_CELL
	if villager.state == Villager.State.AT_HOME:
		from_building = villager.home
	elif villager.state == Villager.State.WORKING:
		from_building = villager.job
	# Spread fighters around the target instead of all aiming for one cell.
	var spread: Vector2i = DOOR_ORDER[index % DOOR_ORDER.size()] * (1 + index % 2)
	var goal := _nearest_walkable(dragon_target + spread)
	if villager.state == Villager.State.WALKING:
		villager.state = Villager.State.OUTSIDE
		villager.from_building = Villager.NO_CELL
	return _route(villager, from_building, Villager.NO_CELL, goal)


func is_fighter(villager: Villager) -> bool:
	return villager.training >= TRAINING_TICKS


func fighter_count() -> int:
	var count := 0
	for villager in villagers:
		if is_fighter(villager):
			count += 1
	return count


func _closer_to_dragon(a: Vector2i, b: Vector2i) -> bool:
	var distance_a := a.distance_squared_to(dragon_target)
	var distance_b := b.distance_squared_to(dragon_target)
	return distance_a < distance_b if distance_a != distance_b else a < b


func _burn_around(centers: Array[Vector2i], radius: int) -> Array[Vector2i]:
	var burned: Array[Vector2i] = []
	for center in centers:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := center + Vector2i(x, y)
				if (
					Vector2(x, y).length() <= radius + 0.5
					and in_bounds(cell)
					and terrain_at(cell) == Terrain.GRASS
					and not _buildings.has(cell)
					and not _roads.has(cell)
					and not _scorched.has(cell)
				):
					_scorched[cell] = true
					burned.append(cell)
					cell_changed.emit(cell)
	return burned


func _sorted_buildings(matches: Callable) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _buildings:
		if matches.call(_buildings[cell]):
			cells.append(cell)
	cells.sort()
	return cells


# --- Heroes ---

## A dragon that reached the village counts, even if it was driven off before it burned anything.
func dragon_has_attacked() -> bool:
	return dragon_visits > 1 or (dragon_visits == 1 and dragon_state != DragonState.INBOUND)


## How many heroes this many villagers can support.
func hero_limit() -> int:
	return population / VILLAGERS_PER_HERO


func can_create_hero() -> bool:
	return population >= HERO_MIN_POPULATION and dragon_has_attacked() and heroes.size() < hero_limit()


func create_hero(hero_name: String, armor: StringName, weapon: StringName, look: StringName) -> bool:
	if not can_create_hero():
		return false
	var new_hero := Hero.create(hero_name, armor, weapon, look)
	if new_hero == null:
		return false
	new_hero.cell = _nearest_walkable(Vector2i(width, height) / 2)
	new_hero.state = Villager.State.OUTSIDE
	new_hero.timer = 1
	new_hero.layout_version = _layout_version
	heroes.append(new_hero)
	stats_changed.emit()
	return true


func can_teleport_to(cell: Vector2i) -> bool:
	return is_walkable(cell)


## Moves a hero there at once. They wait there unless a dragon calls them away.
func teleport_hero(hero: Hero, cell: Vector2i) -> bool:
	if not hero in heroes or not can_teleport_to(cell):
		return false
	hero.cell = cell
	hero.path.clear()
	hero.progress = 0.0
	hero.from_building = Villager.NO_CELL
	hero.to_building = Villager.NO_CELL
	hero.state = Villager.State.OUTSIDE
	hero.timer = HERO_TELEPORT_HOLD
	stats_changed.emit()
	return true


## The heroes who fought this visit's dragon and are still standing.
func dragon_slayers() -> Array[Hero]:
	var slayers: Array[Hero] = []
	for hero in heroes:
		if hero.fought and not hero.wounded:
			slayers.append(hero)
	return slayers


func _everyone() -> Array[Villager]:
	var all := villagers.duplicate()
	all.append_array(heroes)
	return all


func _any_able_hero() -> bool:
	for hero in heroes:
		if not hero.wounded:
			return true
	return false


func _advance_heroes() -> void:
	for index in range(heroes.size()):
		_advance_hero(heroes[index], HERO_SALT + index * 2)


func _advance_hero(hero: Hero, salt: int) -> void:
	if not is_walkable(hero.cell):
		hero.cell = _nearest_walkable(hero.cell)
	var visiting := dragon_is_visiting()
	if visiting and not hero.wounded:
		_hero_hunt(hero)
	if hero.state == Villager.State.WALKING:
		_walk(hero, salt)
	elif not visiting:
		_hero_patrol(hero, salt)
	if not visiting:
		hero.health = mini(hero.health + HERO_RECOVERY, hero.max_health())
		hero.wounded = hero.wounded and hero.health < hero.max_health()


## Heads for a spot to fight from, unless already at one or on the way to one.
func _hero_hunt(hero: Hero) -> void:
	if hero.state == Villager.State.WALKING:
		if not hero.path.is_empty() and _hero_good_spot(hero, hero.path[-1]):
			return
	elif _hero_good_spot(hero, hero.cell):
		return
	var goal := _hero_fighting_spot(hero)
	if goal != hero.cell:
		_route(hero, Villager.NO_CELL, Villager.NO_CELL, goal)


func _hero_can_reach(hero: Hero, cell: Vector2i) -> bool:
	return Vector2(cell).distance_to(Vector2(dragon_target)) <= hero.reach()


func _hero_good_spot(hero: Hero, cell: Vector2i) -> bool:
	var outside_fire := Vector2(cell).distance_to(Vector2(dragon_target)) > DRAGON_FIRE_REACH
	return _hero_can_reach(hero, cell) and (outside_fire or not hero.keeps_clear())


## Whether another hero is standing on this cell or walking to it.
func _hero_spot_taken(hero: Hero, cell: Vector2i) -> bool:
	for other in heroes:
		if other == hero:
			continue
		var walking := other.state == Villager.State.WALKING and not other.path.is_empty()
		if (other.path[-1] if walking else other.cell) == cell:
			return true
	return false


## The closest free cell the hero can get to and fight from.
func _hero_fighting_spot(hero: Hero) -> Vector2i:
	var best := Villager.NO_CELL
	var region: int = _regions.get(hero.cell, -1)
	var limit := ceili(hero.reach())
	for y in range(-limit, limit + 1):
		for x in range(-limit, limit + 1):
			var cell := dragon_target + Vector2i(x, y)
			if not is_walkable(cell) or _regions.get(cell, -1) != region or not _hero_good_spot(hero, cell):
				continue
			if _hero_spot_taken(hero, cell):
				continue
			if best == Villager.NO_CELL or _distance(cell, hero.cell) < _distance(best, hero.cell):
				best = cell
	return best if best != Villager.NO_CELL else _nearest_walkable(dragon_target)


## Between dragons, heroes walk from building to building.
func _hero_patrol(hero: Hero, salt: int) -> void:
	hero.timer -= 1
	if hero.timer > 0 or _buildings.is_empty():
		return
	hero.timer = _roll(salt, HERO_PATROL_PAUSE)
	var cells: Array[Vector2i] = _buildings.keys()
	cells.sort()
	var spot := cells[_roll(salt + 1, Vector2i(0, cells.size() - 1))]
	_route(hero, Villager.NO_CELL, Villager.NO_CELL, _nearest_walkable(spot))


func _heroes_attack() -> void:
	for hero in heroes:
		if hero.wounded or not _hero_can_reach(hero, hero.cell):
			continue
		dragon_resolve = maxi(dragon_resolve - hero.damage(), 0)
		hero.fought = true
		hero_attacked.emit(hero)


func _burn_heroes() -> void:
	for hero in heroes:
		if hero.wounded or Vector2(hero.cell).distance_to(Vector2(dragon_target)) > DRAGON_FIRE_REACH:
			continue
		hero.health = maxi(hero.health - DRAGON_LEVELS[dragon_level].hero_damage, 0)
		if hero.health > 0:
			continue
		hero.wounded = true
		var away := Vector2(hero.cell - dragon_target).normalized()
		var retreat := hero.cell + Vector2i((away if away != Vector2.ZERO else Vector2.DOWN) * HERO_RETREAT_CELLS)
		retreat = retreat.clamp(Vector2i.ZERO, Vector2i(width - 1, height - 1))
		_route(hero, Villager.NO_CELL, Villager.NO_CELL, _nearest_walkable(retreat))
		hero_wounded.emit(hero)


func _load_heroes(data: Dictionary, version: int) -> bool:
	if not data.get("dragon_slain") is bool:
		return false
	dragon_slain = data.dragon_slain
	var roster := version >= FIRST_HERO_ROSTER_VERSION
	if roster and not data.get("heroes") is Array:
		return false
	if not roster and not data.get("dragon_hero_fought") is bool:
		return false
	# Version 8 saves had at most one hero, and kept whether they'd fought on the visit.
	var entries: Array = data.heroes if roster else ([] if data.get("hero") == null else [data.hero])
	for entry: Variant in entries:
		var loaded := _read_hero(entry, version)
		if loaded == null:
			return false
		if not roster:
			loaded.fought = data.dragon_hero_fought
		heroes.append(loaded)
	return true


## Returns null if this isn't a valid saved hero.
func _read_hero(entry: Variant, version: int) -> Hero:
	if not entry is Dictionary or not entry.get("wounded") is bool:
		return null
	for key: String in ["name", "armor", "weapon", "look"]:
		if not entry.get(key) is String:
			return null
	var loaded := Hero.create(entry.name, StringName(entry.armor), StringName(entry.weapon), StringName(entry.look))
	if loaded == null or loaded.hero_name != entry.name or _read_villager(entry, version, loaded) == null:
		return null
	if version >= FIRST_HERO_ROSTER_VERSION:
		if not entry.get("fought") is bool:
			return null
		loaded.fought = entry.fought
	loaded.health = _whole_number(entry, "health")
	loaded.wounded = entry.wounded
	loaded.dragons_slain = _whole_number(entry, "dragons_slain")
	if loaded.health < 0 or loaded.health > loaded.max_health() or loaded.dragons_slain < 0:
		return null
	if loaded.cell == Villager.NO_CELL or not loaded.state in [Villager.State.WALKING, Villager.State.OUTSIDE]:
		return null
	return loaded


# --- Fishing ---

## The water cells a dock's boats row through, from the dock itself out to the
## best fishing spot in range. Just the dock if there's no open water beside it.
func fishing_route(dock: Vector2i) -> Array[Vector2i]:
	if _fishing_routes_version != _layout_version:
		_fishing_routes.clear()
		_fishing_routes_version = _layout_version
	if not _fishing_routes.has(dock):
		_fishing_routes[dock] = _find_fishing_route(dock)
	var route: Array[Vector2i] = []
	route.assign(_fishing_routes[dock])
	return route


## Boats travel on open water only: not under bridges or through other docks.
func is_boatable(cell: Vector2i) -> bool:
	return in_bounds(cell) and terrain_at(cell) == Terrain.WATER and not _roads.has(cell) and not _buildings.has(cell)


## Fish caught each tick spent at a dock's fishing spot.
func fish_per_tick(dock: Vector2i) -> int:
	var spot: Vector2i = fishing_route(dock)[-1]
	return FISH_BASE_CATCH + _open_water_around(spot)


## Whether this villager's boat is out at the fishing spot, rather than rowing.
func is_fishing(villager: Villager) -> bool:
	return (
		villager.state == Villager.State.WORKING
		and villager.shift_ticks >= BOAT_ROW_TICKS
		and villager.timer > BOAT_ROW_TICKS
	)


func _fish(villager: Villager) -> void:
	if is_fishing(villager):
		villager.fish += fish_per_tick(villager.job)
	villager.shift_ticks += 1


## Brings the boat's catch ashore as food, at the end of a shift.
func _land_catch(villager: Villager) -> void:
	food += (villager.fish + FISH_PER_FOOD / 2) / FISH_PER_FOOD
	_lose_catch(villager)


## A shift that starts over, or is cut short, starts with an empty boat.
func _lose_catch(villager: Villager) -> void:
	villager.fish = 0
	villager.shift_ticks = 0


## Searches outward over open water for the spot with the most open water
## around it, preferring spots farther out, and returns the way there.
func _find_fishing_route(dock: Vector2i) -> Array[Vector2i]:
	var came_from: Dictionary[Vector2i, Vector2i] = {dock: dock}
	var steps: Dictionary[Vector2i, int] = {dock: 0}
	var pending: Array[Vector2i] = [dock]
	var best := dock
	var best_score := -1
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_front()
		if cell != dock:
			var score := _open_water_around(cell) * (FISHING_RANGE + 1) + steps[cell]
			if score > best_score:
				best = cell
				best_score = score
		if steps[cell] == FISHING_RANGE:
			continue
		for side: Vector2i in DOOR_ORDER:
			var next: Vector2i = cell + side
			if not came_from.has(next) and is_boatable(next):
				came_from[next] = cell
				steps[next] = steps[cell] + 1
				pending.append(next)
	var route: Array[Vector2i] = [best]
	while route[0] != dock:
		route.push_front(came_from[route[0]])
	return route


func _open_water_around(spot: Vector2i) -> int:
	var count := 0
	for y in range(-1, 2):
		for x in range(-1, 2):
			if (x != 0 or y != 0) and is_boatable(spot + Vector2i(x, y)):
				count += 1
	return count


# --- Villagers ---

func _rebuild_grid() -> void:
	_grid.region = Rect2i(0, 0, width, height)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	for y in range(height):
		for x in range(width):
			_update_grid_cell(Vector2i(x, y))
	_jobs_need_update = true


func _update_grid_cell(cell: Vector2i) -> void:
	_grid.set_point_solid(cell, not is_walkable(cell))
	_grid.set_point_weight_scale(cell, ROAD_PATH_COST if _roads.has(cell) else GRASS_PATH_COST)


func _layout_changed(cell: Vector2i) -> void:
	_update_grid_cell(cell)
	_layout_version += 1
	_jobs_need_update = true


## Nobody is left standing in the water when a bridge goes.
func _move_villagers_off(cell: Vector2i) -> void:
	for villager in _everyone():
		if villager.cell == cell:
			villager.cell = _nearest_walkable(cell)


func _match_villagers_to_population() -> void:
	while villagers.size() < population:
		var villager := Villager.new()
		villager.timer = _roll(villagers.size(), HOME_TICKS)
		villager.layout_version = _layout_version
		villagers.append(villager)
		_jobs_need_update = true
	while villagers.size() > population:
		villagers.pop_back()
		_jobs_need_update = true


func _update_jobs() -> void:
	_match_villagers_to_population()
	if not _jobs_need_update:
		return
	_jobs_need_update = false
	_find_regions()
	_assign_homes()
	var previous_jobs: Array[Vector2i] = []
	for villager in villagers:
		previous_jobs.append(villager.job)
	_assign_jobs()
	for index in range(villagers.size()):
		var moved := villagers[index]
		if moved.state == Villager.State.WORKING and moved.job != previous_jobs[index]:
			moved.state = Villager.State.OUTSIDE
			moved.timer = RETRY_TICKS
			_lose_catch(moved)
	for villager in villagers:
		if villager.cell == Villager.NO_CELL:
			var door := _door_of(villager.home, -1)
			villager.cell = door if door != Villager.NO_CELL else _nearest_walkable(villager.home)
		if villager.state == Villager.State.AT_HOME and villager.home == Villager.NO_CELL:
			villager.state = Villager.State.OUTSIDE
			villager.timer = RETRY_TICKS
		elif villager.state == Villager.State.WORKING and villager.job == Villager.NO_CELL:
			villager.state = Villager.State.OUTSIDE
			villager.timer = RETRY_TICKS
			_lose_catch(villager)


## Labels each connected stretch of walkable ground, to tell what can be reached.
func _find_regions() -> void:
	_regions.clear()
	var next_region := 0
	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if _regions.has(start) or not is_walkable(start):
				continue
			_regions[start] = next_region
			var pending: Array[Vector2i] = [start]
			while not pending.is_empty():
				var cell: Vector2i = pending.pop_back()
				for side: Vector2i in DOOR_ORDER:
					var neighbor: Vector2i = cell + side
					if not _regions.has(neighbor) and is_walkable(neighbor):
						_regions[neighbor] = next_region
						pending.append(neighbor)
			next_region += 1


func _assign_homes() -> void:
	var residents: Dictionary[Vector2i, int] = {}
	for villager in villagers:
		var keep := _is_house(villager.home)
		if keep and residents.get(villager.home, 0) >= BUILDINGS[_buildings[villager.home]].housing:
			keep = false
		if keep:
			residents[villager.home] = residents.get(villager.home, 0) + 1
		else:
			villager.home = Villager.NO_CELL
	var all_houses := houses()
	for villager in villagers:
		if villager.home != Villager.NO_CELL:
			continue
		var best := Villager.NO_CELL
		for house in all_houses:
			if residents.get(house, 0) < BUILDINGS[_buildings[house]].housing:
				if best == Villager.NO_CELL or _distance(house, villager.cell) < _distance(best, villager.cell):
					best = house
		if best != Villager.NO_CELL:
			villager.home = best
			residents[best] = residents.get(best, 0) + 1


func _assign_jobs() -> void:
	_workers_at.clear()
	for villager in villagers:
		if (
			_is_workplace(villager.job)
			and _can_take(villager, villager.job)
			and _can_commute(villager.home, villager.job)
			and _workers_at.get(villager.job, 0) < BUILDINGS[_buildings[villager.job]].jobs
		):
			_workers_at[villager.job] = _workers_at.get(villager.job, 0) + 1
		else:
			villager.job = Villager.NO_CELL
	var all_workplaces := workplaces()
	var workers_making: Dictionary[String, int] = {}
	for cell: Vector2i in _workers_at:
		var product := _product_of(cell)
		workers_making[product] = workers_making.get(product, 0) + _workers_at[cell]
	for villager in villagers:
		if villager.job != Villager.NO_CELL or villager.home == Villager.NO_CELL:
			continue
		# Fill whichever product has the fewest workers, then the nearest job for it.
		var best := Villager.NO_CELL
		for workplace in all_workplaces:
			if _workers_at.get(workplace, 0) >= BUILDINGS[_buildings[workplace]].jobs:
				continue
			if not _can_commute(villager.home, workplace) or not _can_take(villager, workplace):
				continue
			if best == Villager.NO_CELL or _better_job(workplace, best, villager.home, workers_making):
				best = workplace
		if best != Villager.NO_CELL:
			villager.job = best
			_workers_at[best] = _workers_at.get(best, 0) + 1
			var product := _product_of(best)
			workers_making[product] = workers_making.get(product, 0) + 1
	_rebalance_jobs(all_workplaces, workers_making)
	_swap_fighters_out_of_training(all_workplaces)


## Moves workers from the busiest product to the one with fewest workers until
## they're within one of each other, so a new well doesn't sit empty.
func _rebalance_jobs(all_workplaces: Array[Vector2i], workers_making: Dictionary[String, int]) -> void:
	var offered: Array[String] = []
	for workplace in all_workplaces:
		if not _product_of(workplace) in offered:
			offered.append(_product_of(workplace))
	for attempt in range(villagers.size()):
		var fewest := ""
		var most := ""
		for product in offered:
			var count: int = workers_making.get(product, 0)
			if fewest == "" or count < workers_making.get(fewest, 0):
				fewest = product
			if most == "" or count > workers_making.get(most, 0):
				most = product
		if fewest == "" or workers_making.get(most, 0) - workers_making.get(fewest, 0) <= 1:
			return
		if not _move_a_worker(most, fewest, all_workplaces, workers_making):
			offered.erase(fewest)


func _move_a_worker(
	from_product: String, to_product: String, all_workplaces: Array[Vector2i], workers_making: Dictionary[String, int]
) -> bool:
	for index in range(villagers.size() - 1, -1, -1):
		var villager := villagers[index]
		if villager.job == Villager.NO_CELL or _product_of(villager.job) != from_product:
			continue
		var best := Villager.NO_CELL
		for workplace in all_workplaces:
			if (
				_product_of(workplace) == to_product
				and _workers_at.get(workplace, 0) < BUILDINGS[_buildings[workplace]].jobs
				and _can_commute(villager.home, workplace)
				and _can_take(villager, workplace)
				and (best == Villager.NO_CELL or _distance(workplace, villager.home) < _distance(best, villager.home))
			):
				best = workplace
		if best == Villager.NO_CELL:
			continue
		_workers_at[villager.job] -= 1
		if _workers_at[villager.job] == 0:
			_workers_at.erase(villager.job)
		villager.job = best
		_workers_at[best] = _workers_at.get(best, 0) + 1
		workers_making[from_product] -= 1
		workers_making[to_product] = workers_making.get(to_product, 0) + 1
		return true
	return false


## A fighter left without a job takes over an untrained villager's job, and that
## villager takes the open training place, so training keeps going.
func _swap_fighters_out_of_training(all_workplaces: Array[Vector2i]) -> void:
	for fighter in villagers:
		if fighter.job != Villager.NO_CELL or fighter.home == Villager.NO_CELL or not is_fighter(fighter):
			continue
		for center in all_workplaces:
			if _product_of(center) != "training" or _workers_at.get(center, 0) >= BUILDINGS[_buildings[center]].jobs:
				continue
			var trainee := _untrained_worker_for(fighter, center)
			if trainee == null:
				continue
			fighter.job = trainee.job
			trainee.job = center
			_workers_at[center] = _workers_at.get(center, 0) + 1
			break


func _untrained_worker_for(fighter: Villager, center: Vector2i) -> Villager:
	for villager in villagers:
		if (
			not is_fighter(villager)
			and villager.job != Villager.NO_CELL
			and _product_of(villager.job) != "training"
			and _can_commute(villager.home, center)
			and _can_commute(fighter.home, villager.job)
		):
			return villager
	return null


## Fighters are already trained, so they don't take places at training centers.
func _can_take(villager: Villager, workplace: Vector2i) -> bool:
	return not (is_fighter(villager) and _product_of(workplace) == "training")


func _better_job(a: Vector2i, b: Vector2i, home: Vector2i, workers_making: Dictionary[String, int]) -> bool:
	var workers_a: int = workers_making.get(_product_of(a), 0)
	var workers_b: int = workers_making.get(_product_of(b), 0)
	if workers_a != workers_b:
		return workers_a < workers_b
	return _distance(a, home) < _distance(b, home)


func _product_of(workplace: Vector2i) -> String:
	for product: String in PRODUCTS:
		if BUILDINGS[_buildings[workplace]].has(product):
			return product
	return ""


func _is_house(cell: Vector2i) -> bool:
	return _buildings.has(cell) and BUILDINGS[_buildings[cell]].has("housing")


func _is_workplace(cell: Vector2i) -> bool:
	return _buildings.has(cell) and BUILDINGS[_buildings[cell]].has("jobs")


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _can_commute(from_building: Vector2i, to_building: Vector2i) -> bool:
	for side: Vector2i in DOOR_ORDER:
		var region: int = _regions.get(from_building + side, -1)
		if region >= 0 and _door_of(to_building, region) != Villager.NO_CELL:
			return true
	return false


## The first walkable cell beside a building, in the given region if not negative.
func _door_of(building: Vector2i, region: int) -> Vector2i:
	if building == Villager.NO_CELL:
		return Villager.NO_CELL
	for side: Vector2i in DOOR_ORDER:
		var cell: Vector2i = building + side
		if is_walkable(cell) and (region < 0 or _regions.get(cell, -1) == region):
			return cell
	return Villager.NO_CELL


func _nearest_walkable(from: Vector2i) -> Vector2i:
	if from == Villager.NO_CELL:
		from = Vector2i(width, height) / 2
	for radius in range(NEAREST_CELL_SEARCH + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var cell := from + Vector2i(x, y)
				if is_walkable(cell):
					return cell
	return from


func _advance_villager(villager: Villager, index: int) -> void:
	if villager.state == Villager.State.WALKING:
		_walk(villager, index)
		return
	villager.timer -= 1
	if villager.timer <= 0:
		_start_trip(villager, index)


func _start_trip(villager: Villager, index: int) -> void:
	if is_fighter(villager) and dragon_is_visiting():
		if _near_dragon(villager.cell) and _is_outdoors(villager):
			villager.timer = 1
			return
		if _send_to_dragon(villager, index):
			return
	var from_building := Villager.NO_CELL
	var to_building := Villager.NO_CELL
	var goal := Villager.NO_CELL
	if villager.state == Villager.State.AT_HOME:
		from_building = villager.home
		if villager.job != Villager.NO_CELL:
			to_building = villager.job
		else:
			var offset := Vector2i(
				_roll(index, Vector2i(-WANDER_RADIUS, WANDER_RADIUS)),
				_roll(index + 1000, Vector2i(-WANDER_RADIUS, WANDER_RADIUS)),
			)
			goal = _nearest_walkable(villager.cell + offset)
	else:
		if villager.state == Villager.State.WORKING:
			from_building = villager.job
		to_building = villager.home
	if not _route(villager, from_building, to_building, goal):
		villager.timer = RETRY_TICKS


func _route(villager: Villager, from_building: Vector2i, to_building: Vector2i, goal: Vector2i) -> bool:
	if _grid.is_point_solid(villager.cell):
		villager.cell = _nearest_walkable(villager.cell)
	if to_building != Villager.NO_CELL:
		goal = _door_of(to_building, _regions.get(villager.cell, -1))
	if goal == Villager.NO_CELL or _grid.is_point_solid(goal):
		return false
	var path := _grid.get_id_path(villager.cell, goal)
	if path.is_empty():
		return false
	if from_building != Villager.NO_CELL and from_building == villager.job:
		_land_catch(villager)
	villager.path = path
	villager.from_building = from_building
	villager.to_building = to_building
	villager.progress = -0.5 if from_building != Villager.NO_CELL else 0.0
	villager.layout_version = _layout_version
	villager.state = Villager.State.WALKING
	return true


func _walk(villager: Villager, index: int) -> void:
	if villager.layout_version != _layout_version and not _reroute(villager):
		return
	villager.progress += walk_speed(villager)
	villager.cell = villager.path[clampi(floori(villager.progress), 0, villager.path.size() - 1)]
	if villager.progress >= villager.trip_end():
		_arrive(villager, index)


## The layout changed mid-trip, so head for the same place by a new path.
func _reroute(villager: Villager) -> bool:
	var goal: Vector2i = villager.path[-1]
	var target := villager.to_building
	var target_gone := target != Villager.NO_CELL and not _buildings.has(target)
	if not target_gone and _route(villager, Villager.NO_CELL, target, goal):
		return true
	villager.path.clear()
	villager.progress = 0.0
	villager.to_building = Villager.NO_CELL
	villager.state = Villager.State.OUTSIDE
	villager.timer = RETRY_TICKS
	return false


func _arrive(villager: Villager, index: int) -> void:
	var building := villager.to_building
	if building != Villager.NO_CELL and building == villager.job:
		villager.state = Villager.State.WORKING
		villager.timer = _roll(index, WORK_TICKS)
		_lose_catch(villager)
	elif building != Villager.NO_CELL and building == villager.home:
		villager.state = Villager.State.AT_HOME
		villager.timer = _roll(index, HOME_TICKS)
	else:
		villager.state = Villager.State.OUTSIDE
		villager.timer = _roll(index, OUTSIDE_TICKS)
	villager.path.clear()
	villager.progress = 0.0
	villager.from_building = Villager.NO_CELL
	villager.to_building = Villager.NO_CELL


## A repeatable random number, so a loaded game plays out the same way.
func _roll(salt: int, limits: Vector2i) -> int:
	var span := limits.y - limits.x + 1
	return limits.x + hash([dragon_seed, tick_count, salt]) % span


## Repeatable randomness for the current dragon visit.
func _visit_rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([dragon_seed, dragon_visits, salt])
	return rng


func _generate_terrain(map_seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.07
	var center := Vector2(width, height) / 2.0
	_terrain.resize(width * height)
	for y in range(height):
		for x in range(width):
			var value := noise.get_noise_2d(x, y)
			var type := Terrain.GRASS
			if Vector2(x, y).distance_to(center) > CLEAR_START_RADIUS:
				if value < -0.25:
					type = Terrain.WATER
				elif value > 0.2:
					type = Terrain.FOREST
			_terrain[y * width + x] = type
