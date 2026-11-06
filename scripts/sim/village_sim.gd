class_name VillageSim
extends RefCounted
## All game state and rules. Knows nothing about rendering or input, and only
## advances through tick(), so it can run headless in tests.

signal cell_changed(cell: Vector2i)
signal stats_changed
signal dragon_incoming(target: Vector2i)
signal dragon_struck(destroyed: Array[Vector2i], burned: Array[Vector2i])
## Sent just before dragon_struck when towers fight back. Each defender saved
## one of the threatened buildings, so all were saved if the counts match.
signal dragon_defended(defenders: Array[Vector2i], threatened: int)

enum Terrain { GRASS, WATER, FOREST }
enum DragonState { WAITING, INBOUND, DEPARTING, GONE }

const BUILDINGS := {
	&"house": {"name": "House", "cost": 10, "housing": 4},
	&"farm": {"name": "Farm", "cost": 15, "food": 2, "jobs": 2},
	&"lumber_camp": {"name": "Lumber Camp", "cost": 15, "wood": 2, "jobs": 2},
	&"well": {"name": "Well", "cost": 15, "water": 3, "jobs": 2},
	&"tower": {"name": "Tower", "cost": 40, "defense": true},
}
const POPULATION_INTERVAL := 5
## Every this many ticks, each villager eats 1 food and drinks 1 water.
const MEAL_INTERVAL := 4
## Shortages never drive out the last few villagers, so a village can recover.
const FOUNDERS := 4
const PRODUCTS := ["wood", "food", "water"]
## Towers defend buildings within this many cells of where the dragon strikes.
const TOWER_RANGE := 6.0
const TOWER_WATER_PER_DEFENSE := 25
## Saves from before water get enough to last this long while wells go up.
const OLD_SAVE_WATER_TICKS := 60
const CLEAR_START_RADIUS := 5
const SAVE_VERSION := 5
const ROAD_COST := 1
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
const INVALID_CELL := Vector2i(-2, -2)
## One building is under 10% of the village only once there are at least 11,
## so the dragon's timer doesn't run until then.
const DRAGON_MIN_BUILDINGS := 11
const DRAGON_MIN_WAIT_TICKS := 120
const DRAGON_MAX_WAIT_TICKS := 420
const DRAGON_MIN_DAMAGE := 0.03
const DRAGON_MAX_DAMAGE := 0.099
const DRAGON_MIN_BURN_RADIUS := 0
const DRAGON_MAX_BURN_RADIUS := 1
const DRAGON_INBOUND_TICKS := 5
const DRAGON_DEPARTING_TICKS := 4

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
var villagers: Array[Villager] = []

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


## A negative new_dragon_seed picks a different dragon for each new game.
func _init(map_width := 40, map_height := 40, map_seed := 1, new_dragon_seed := -1) -> void:
	width = map_width
	height = map_height
	_generate_terrain(map_seed)
	dragon_seed = randi() if new_dragon_seed < 0 else new_dragon_seed
	dragon_timer = _dragon_rng(0).randi_range(DRAGON_MIN_WAIT_TICKS, DRAGON_MAX_WAIT_TICKS)
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


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and terrain_at(cell) == Terrain.GRASS and not _buildings.has(cell)


func walk_speed(villager: Villager) -> float:
	return ROAD_WALK_SPEED if has_road(villager.cell) else GRASS_WALK_SPEED


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
		and terrain_at(cell) == Terrain.GRASS
		and not _buildings.has(cell)
		and not _roads.has(cell)
		and wood >= BUILDINGS[type].cost
	)


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


func demolish(cell: Vector2i) -> bool:
	if _roads.erase(cell):
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
			wood += BUILDINGS[_buildings[villager.job]].get("wood", 0)
			food += BUILDINGS[_buildings[villager.job]].get("food", 0)
			water += BUILDINGS[_buildings[villager.job]].get("water", 0)
	for index in range(villagers.size()):
		_advance_villager(villagers[index], index)

	if tick_count % MEAL_INTERVAL == 0:
		food = maxi(food - population, 0)
		water = maxi(water - population, 0)

	if tick_count % POPULATION_INTERVAL == 0:
		var short_of_supplies := food == 0 or water == 0
		if short_of_supplies:
			if population > FOUNDERS:
				population -= 1
		elif population < housing():
			population += 1
	_advance_dragon()
	stats_changed.emit()


func to_save_data() -> Dictionary:
	var saved_buildings: Array[Dictionary] = []
	for cell: Vector2i in _buildings:
		saved_buildings.append({"x": cell.x, "y": cell.y, "type": String(_buildings[cell])})
	_match_villagers_to_population()
	_update_jobs()
	var saved_villagers: Array[Dictionary] = []
	for villager in villagers:
		saved_villagers.append(villager.to_data())
	var saved_scorch: Array[Dictionary] = []
	for cell: Vector2i in _scorched:
		saved_scorch.append({"x": cell.x, "y": cell.y})
	var saved_roads: Array[Dictionary] = []
	for cell: Vector2i in _roads:
		saved_roads.append({"x": cell.x, "y": cell.y})
	return {
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
	}


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
			or sim.terrain_at(cell) != Terrain.GRASS
			or sim._buildings.has(cell)
		):
			return null
		sim._buildings[cell] = type
	if sim.population > sim.housing():
		return null
	if version >= 3 and not sim._load_roads(data):
		return null
	# Saves from before the dragon keep the new dragon chosen by _init().
	if version >= 2 and not sim._load_dragon(data):
		return null
	sim._rebuild_grid()
	# Saves from before villagers were simulated get new ones from the population.
	if version >= 4 and not sim._load_villagers(data):
		return null
	if version < 5:
		sim.water = sim.population * OLD_SAVE_WATER_TICKS / MEAL_INTERVAL
	return sim


func _load_villagers(data: Dictionary) -> bool:
	if not data.get("villagers") is Array or data.villagers.size() != population:
		return false
	for entry: Variant in data.villagers:
		var villager := _read_villager(entry)
		if villager == null:
			return false
		villagers.append(villager)
	return true


func _read_villager(entry: Variant) -> Villager:
	if not entry is Dictionary or not entry.get("path") is Array:
		return null
	var villager := Villager.new()
	villager.home = _read_cell(entry.get("home"))
	villager.job = _read_cell(entry.get("job"))
	villager.cell = _read_cell(entry.get("cell"))
	villager.from_building = _read_cell(entry.get("from_building"))
	villager.to_building = _read_cell(entry.get("to_building"))
	var state := _whole_number(entry, "state")
	villager.timer = _whole_number(entry, "timer")
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


func _load_roads(data: Dictionary) -> bool:
	if not data.get("roads") is Array:
		return false
	for entry: Variant in data.roads:
		if not entry is Dictionary:
			return false
		var cell := Vector2i(_whole_number(entry, "x"), _whole_number(entry, "y"))
		if not is_walkable(cell) or _roads.has(cell):
			return false
		_roads[cell] = true
	return true


func _load_dragon(data: Dictionary) -> bool:
	var state := _whole_number(data, "dragon_state")
	dragon_timer = _whole_number(data, "dragon_timer")
	dragon_seed = _whole_number(data, "dragon_seed")
	dragon_target = Vector2i(_whole_number(data, "dragon_target_x"), _whole_number(data, "dragon_target_y"))
	if state < 0 or state >= DragonState.size() or dragon_timer < 0 or dragon_seed < 0:
		return false
	if not in_bounds(dragon_target) or not data.get("scorched") is Array:
		return false
	dragon_state = state as DragonState
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
	if dragon_state == DragonState.GONE:
		return
	if dragon_state == DragonState.WAITING and _buildings.size() < DRAGON_MIN_BUILDINGS:
		return
	dragon_timer -= 1
	if dragon_timer > 0:
		return
	match dragon_state:
		DragonState.WAITING:
			_dragon_set_off()
		DragonState.INBOUND:
			_dragon_strike()
		DragonState.DEPARTING:
			dragon_state = DragonState.GONE


func _dragon_set_off() -> void:
	var cells := _buildings.keys()
	cells.sort()
	dragon_target = cells[_dragon_rng(2).randi_range(0, cells.size() - 1)]
	dragon_state = DragonState.INBOUND
	dragon_timer = DRAGON_INBOUND_TICKS
	dragon_incoming.emit(dragon_target)


## Burns the buildings closest to the target. The player may have demolished
## buildings during the approach, and then the 10% limit could not be met.
func _dragon_strike() -> void:
	dragon_state = DragonState.DEPARTING
	dragon_timer = DRAGON_DEPARTING_TICKS
	var destroyed: Array[Vector2i] = []
	var burned: Array[Vector2i] = []
	if _buildings.size() >= DRAGON_MIN_BUILDINGS:
		var rng := _dragon_rng(1)
		var damage := rng.randf_range(DRAGON_MIN_DAMAGE, DRAGON_MAX_DAMAGE)
		var count := maxi(floori(_buildings.size() * damage), 1)
		count -= _defend_with_towers(count)
		var cells: Array[Vector2i] = _buildings.keys()
		cells.sort_custom(_closer_to_dragon)
		destroyed = cells.slice(0, count)
		for cell in destroyed:
			_buildings.erase(cell)
			_layout_changed(cell)
			cell_changed.emit(cell)
		population = mini(population, housing())
		burned = _burn_around(destroyed, rng.randi_range(DRAGON_MIN_BURN_RADIUS, DRAGON_MAX_BURN_RADIUS))
	dragon_struck.emit(destroyed, burned)


## Nearest towers in range fire first, one per threatened building, while water lasts.
## Returns how many buildings they saved.
func _defend_with_towers(threatened: int) -> int:
	var in_range: Array[Vector2i] = []
	for tower in towers():
		if Vector2(tower).distance_to(Vector2(dragon_target)) <= TOWER_RANGE:
			in_range.append(tower)
	in_range.sort_custom(_closer_to_dragon)
	var defenders: Array[Vector2i] = []
	for tower in in_range:
		if defenders.size() == threatened or water < TOWER_WATER_PER_DEFENSE:
			break
		water -= TOWER_WATER_PER_DEFENSE
		defenders.append(tower)
	if not defenders.is_empty():
		dragon_defended.emit(defenders, threatened)
	return defenders.size()


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
			if not _can_commute(villager.home, workplace):
				continue
			if best == Villager.NO_CELL or _better_job(workplace, best, villager.home, workers_making):
				best = workplace
		if best != Villager.NO_CELL:
			villager.job = best
			_workers_at[best] = _workers_at.get(best, 0) + 1
			var product := _product_of(best)
			workers_making[product] = workers_making.get(product, 0) + 1
	_rebalance_jobs(all_workplaces, workers_making)


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


func _dragon_rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([dragon_seed, salt])
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
