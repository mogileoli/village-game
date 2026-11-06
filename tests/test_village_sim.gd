extends SceneTree
## Run: godot --headless --path . --script res://tests/test_village_sim.gd

const TEST_SAVE := "user://test_save.json"

var _failures := 0


func _init() -> void:
	_test_map_is_deterministic_and_start_is_clear()
	_test_placement_rules()
	_test_production_and_growth()
	_test_starvation()
	_test_demolish_evicts()
	_test_save_round_trip()
	_test_save_overwrites_previous()
	_test_rejects_bad_saves()
	_test_dragon_needs_a_big_enough_village()
	_test_dragon_arrival_time_varies()
	_test_dragon_damage_is_under_ten_percent_and_varies()
	_test_dragon_burns_a_connected_area()
	_test_only_one_dragon_comes()
	_test_demolishing_during_approach_saves_the_village()
	_test_can_rebuild_on_scorched_ground()
	_test_dragon_survives_save_and_load()
	_test_old_saves_still_load()
	_test_road_rules()
	_test_roads_and_buildings_block_each_other()
	_test_demolishing_roads()
	_test_roads_survive_save_and_load()
	_test_dragon_spares_roads()
	_test_houses_and_workplaces()
	_test_no_workers_means_no_production()
	_test_only_people_inside_produce()
	_test_jobs_are_limited()
	_test_roads_raise_production()
	_test_walled_in_workplace_gets_no_workers()
	_test_people_get_new_jobs_when_buildings_go()
	_test_people_never_stand_in_buildings()
	_test_save_during_commute_plays_on_identically()
	_test_rejects_bad_villagers()
	_test_older_saves_get_villagers()
	_test_save_slots()
	_test_well_needs_workers()
	_test_people_need_water()
	_test_towers_save_buildings()
	_test_enough_towers_drive_off_the_dragon()
	_test_towers_need_water_and_range()
	_test_towers_are_not_jobs()
	_test_older_saves_get_water()
	_test_jobs_balance_wood_food_and_water()
	DirAccess.remove_absolute(TEST_SAVE)
	print("FAILED: %d" % _failures if _failures else "All sim tests passed")
	quit(1 if _failures else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: ", label)


func _test_map_is_deterministic_and_start_is_clear() -> void:
	var a := VillageSim.new(40, 40, 7)
	var b := VillageSim.new(40, 40, 7)
	var has_water := false
	var has_forest := false
	var same := true
	for y in range(40):
		for x in range(40):
			var cell := Vector2i(x, y)
			same = same and a.terrain_at(cell) == b.terrain_at(cell)
			has_water = has_water or a.terrain_at(cell) == VillageSim.Terrain.WATER
			has_forest = has_forest or a.terrain_at(cell) == VillageSim.Terrain.FOREST
	_check(same, "same seed gives same map")
	_check(has_water and has_forest, "map has water and forest")
	_check(a.terrain_at(Vector2i(20, 20)) == VillageSim.Terrain.GRASS, "start area is grass")


func _test_placement_rules() -> void:
	var sim := VillageSim.new()
	var cell := Vector2i(20, 20)
	_check(sim.place(&"house", cell), "can place on empty grass")
	_check(sim.wood == 50, "placing deducts wood")
	_check(not sim.place(&"farm", cell), "cannot place on occupied cell")
	_check(not sim.place(&"farm", Vector2i(-1, 0)), "cannot place out of bounds")
	sim.wood = 0
	_check(not sim.place(&"farm", Vector2i(21, 20)), "cannot place without wood")


func _test_production_and_growth() -> void:
	var sim := VillageSim.new()
	sim.place(&"house", Vector2i(20, 20))
	for i in range(VillageSim.POPULATION_INTERVAL):
		sim.tick()
	_check(sim.population == 1, "house attracts a settler")
	for i in range(VillageSim.POPULATION_INTERVAL * 10):
		sim.food = 100
		sim.water = 100
		sim.tick()
	_check(sim.population == sim.housing(), "population stops at housing cap")


func _test_starvation() -> void:
	var sim := VillageSim.new()
	sim.place(&"house", Vector2i(20, 20))
	sim.place(&"house", Vector2i(20, 22))
	sim.population = 8
	sim.food = 0
	for i in range(VillageSim.POPULATION_INTERVAL):
		sim.tick()
	_check(sim.population == 7, "people leave when there is no food")
	for i in range(VillageSim.POPULATION_INTERVAL * 20):
		sim.food = 0
		sim.tick()
	_check(sim.population == VillageSim.FOUNDERS, "founders stay through shortages: %d" % sim.population)


func _test_demolish_evicts() -> void:
	var sim := VillageSim.new()
	sim.place(&"house", Vector2i(20, 20))
	sim.population = 4
	_check(sim.demolish(Vector2i(20, 20)), "can demolish a building")
	_check(sim.population == 0, "demolishing housing removes residents")
	_check(sim.wood == 55, "demolishing refunds half the cost")
	_check(not sim.demolish(Vector2i(20, 20)), "cannot demolish an empty cell")


func _test_save_round_trip() -> void:
	var sim := VillageSim.new(40, 40, 7)
	sim.place(&"house", Vector2i(20, 20))
	sim.place(&"farm", Vector2i(21, 20))
	sim.place(&"lumber_camp", Vector2i(22, 20))
	for i in range(13):
		sim.tick()
	_check(SaveGame.write(sim, TEST_SAVE) == OK, "save writes a file")
	var loaded := SaveGame.read(TEST_SAVE)
	_check(loaded != null, "save loads back")
	if loaded == null:
		return
	_check(loaded.to_save_data() == sim.to_save_data(), "loaded game matches saved game")
	# tick_count must survive too, or population timing drifts after loading.
	for i in range(20):
		sim.tick()
		loaded.tick()
	_check(loaded.to_save_data() == sim.to_save_data(), "loaded game plays on identically")


func _test_save_overwrites_previous() -> void:
	var sim := VillageSim.new()
	sim.wood = 111
	SaveGame.write(sim, TEST_SAVE)
	sim.wood = 222
	_check(SaveGame.write(sim, TEST_SAVE) == OK, "saving again succeeds")
	var loaded := SaveGame.read(TEST_SAVE)
	_check(loaded != null and loaded.wood == 222, "newest save wins")


func _test_rejects_bad_saves() -> void:
	_check(SaveGame.read("user://no_such_save.json") == null, "missing file is rejected")
	for text: String in ["", "not json", "[1, 2]", "{}"]:
		_write_text(text)
		_check(SaveGame.read(TEST_SAVE) == null, "rejects file: '%s'" % text)

	var sim := VillageSim.new(40, 40, 7)
	sim.place(&"house", Vector2i(20, 20))
	var good := sim.to_save_data()
	_check(VillageSim.from_save_data(good) != null, "good data is accepted")
	var bad_values := {
		"version": 999,
		"width": 39,
		"terrain": "AAAA",
		"wood": -5,
		"food": 1.5,
		"water": -1,
		"population": 5,
		"tick_count": "soon",
		"buildings": "none",
		"dragon_state": 99,
		"dragon_timer": -1,
		"dragon_seed": "x",
		"dragon_target_x": 500,
		"scorched": "none",
		"roads": "none",
		"villagers": "none",
	}
	for key: String in bad_values:
		var bad := good.duplicate()
		bad[key] = bad_values[key]
		_check(VillageSim.from_save_data(bad) == null, "rejects bad %s" % key)
	for entry: Dictionary in [
		{"x": 20, "y": 21, "type": "castle"},
		{"x": 99, "y": 99, "type": "house"},
		{"x": 20, "y": 20, "type": "house"},
	]:
		var bad := good.duplicate()
		bad.buildings = good.buildings + [entry]
		_check(VillageSim.from_save_data(bad) == null, "rejects building %s" % entry)


func _write_text(text: String) -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Fills grass cells outward from the map center.
func _village(buildings: int, dragon_seed := 1) -> VillageSim:
	var sim := VillageSim.new(40, 40, 1, dragon_seed)
	sim.wood = 100000
	var cells: Array[Vector2i] = []
	for y in range(40):
		for x in range(40):
			cells.append(Vector2i(x, y))
	var center := Vector2i(20, 20)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))
	for cell in cells:
		if sim.building_count() == buildings:
			break
		sim.place(&"farm", cell)
	return sim


func _run_dragon(sim: VillageSim, until: VillageSim.DragonState) -> void:
	for i in range(1000):
		if sim.dragon_state == until:
			return
		sim.tick()


func _test_dragon_needs_a_big_enough_village() -> void:
	var sim := _village(VillageSim.DRAGON_MIN_BUILDINGS - 1)
	for i in range(VillageSim.DRAGON_MAX_WAIT_TICKS * 2):
		sim.tick()
	_check(sim.dragon_state == VillageSim.DragonState.WAITING, "dragon waits for 11 buildings")
	sim.place(&"farm", Vector2i(25, 20))
	sim.place(&"farm", Vector2i(26, 20))
	_check(sim.building_count() >= VillageSim.DRAGON_MIN_BUILDINGS, "test village grew")
	sim.tick()
	_check(sim.dragon_state == VillageSim.DragonState.WAITING, "dragon doesn't arrive the moment the village is big enough")


func _test_dragon_arrival_time_varies() -> void:
	var times := {}
	for dragon_seed in range(30):
		var timer := VillageSim.new(10, 10, 1, dragon_seed).dragon_timer
		_check(
			timer >= VillageSim.DRAGON_MIN_WAIT_TICKS and timer <= VillageSim.DRAGON_MAX_WAIT_TICKS,
			"arrival time is in range"
		)
		times[timer] = true
	_check(times.size() > 10, "arrival time varies: %d different" % times.size())


func _test_dragon_damage_is_under_ten_percent_and_varies() -> void:
	for size: int in [11, 20, 45, 120]:
		var losses := {}
		var burned_areas := {}
		for dragon_seed in range(40):
			var sim := _village(size, dragon_seed)
			_check(sim.building_count() == size, "built village of %d" % size)
			var result := [0, 0]
			sim.dragon_struck.connect(func(destroyed: Array[Vector2i], burned: Array[Vector2i]) -> void:
				result[0] = destroyed.size()
				result[1] = burned.size())
			_run_dragon(sim, VillageSim.DragonState.DEPARTING)
			_check(result[0] >= 1, "dragon destroys something")
			_check(result[0] / float(size) < 0.1, "%d of %d is under 10%%" % [result[0], size])
			_check(sim.building_count() == size - result[0], "destroyed buildings are removed")
			losses[result[0]] = true
			burned_areas[result[1]] = true
		if size == 120:
			_check(losses.size() >= 3, "damage varies: %d different" % losses.size())
		_check(burned_areas.size() >= 2, "burned area varies: %d different" % burned_areas.size())


func _test_dragon_burns_a_connected_area() -> void:
	var sim := _village(120, 3)
	var lost: Array[Vector2i] = []
	sim.dragon_struck.connect(func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		lost.assign(destroyed))
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	var target := sim.dragon_target
	var farthest_lost := 0
	for cell in lost:
		farthest_lost = maxi(farthest_lost, cell.distance_squared_to(target))
	for y in range(40):
		for x in range(40):
			var cell := Vector2i(x, y)
			if sim.building_at(cell) != &"":
				_check(cell.distance_squared_to(target) >= farthest_lost, "closest buildings burn first")


func _test_only_one_dragon_comes() -> void:
	var sim := _village(30)
	var visits := [0]
	sim.dragon_incoming.connect(func(_target: Vector2i) -> void: visits[0] += 1)
	for i in range(3000):
		sim.tick()
	_check(visits[0] == 1, "exactly one dragon: %d" % visits[0])
	_check(sim.dragon_state == VillageSim.DragonState.GONE, "dragon leaves for good")


func _test_demolishing_during_approach_saves_the_village() -> void:
	var sim := _village(12)
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	sim.demolish(sim.dragon_target)
	sim.demolish(_first_building(sim))
	var remaining := sim.building_count()
	var result := [-1]
	sim.dragon_struck.connect(func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		result[0] = destroyed.size())
	_run_dragon(sim, VillageSim.DragonState.GONE)
	_check(result[0] == 0, "too small a village loses nothing")
	_check(sim.building_count() == remaining, "buildings survive")


func _first_building(sim: VillageSim) -> Vector2i:
	for y in range(40):
		for x in range(40):
			if sim.building_at(Vector2i(x, y)) != &"":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _test_can_rebuild_on_scorched_ground() -> void:
	var sim := _village(30)
	var lost: Array[Vector2i] = []
	sim.dragon_struck.connect(func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		lost.assign(destroyed))
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	var cell := lost[0]
	_check(sim.is_scorched(cell), "destroyed building leaves scorched ground")
	_check(sim.place(&"house", cell), "can rebuild on scorched ground")
	_check(not sim.is_scorched(cell), "rebuilding clears the scorch")


func _test_dragon_survives_save_and_load() -> void:
	for state: VillageSim.DragonState in [VillageSim.DragonState.INBOUND, VillageSim.DragonState.DEPARTING]:
		var sim := _village(40, 5)
		_run_dragon(sim, state)
		SaveGame.write(sim, TEST_SAVE)
		var loaded := SaveGame.read(TEST_SAVE)
		_check(loaded != null, "mid-flight save loads")
		if loaded == null:
			return
		_check(loaded.to_save_data() == sim.to_save_data(), "mid-flight save matches")
		for i in range(12):
			sim.tick()
			loaded.tick()
		_check(loaded.to_save_data() == sim.to_save_data(), "loaded dragon behaves identically")
		_check(loaded.dragon_state == VillageSim.DragonState.GONE, "loaded dragon finishes its visit")


func _test_old_saves_still_load() -> void:
	var data := _village(5).to_save_data()
	data.version = 1
	for key: String in ["villagers", "roads", "scorched", "dragon_state", "dragon_timer", "dragon_target_x", "dragon_target_y", "dragon_seed"]:
		data.erase(key)
	var loaded := VillageSim.from_save_data(data)
	_check(loaded != null, "version 1 save loads")
	if loaded != null:
		_check(loaded.building_count() == 5, "version 1 buildings kept")
		_check(loaded.dragon_state == VillageSim.DragonState.WAITING, "version 1 save gets a dragon")

	var dragon_era := _village(5, 2).to_save_data()
	dragon_era.version = 2
	dragon_era.erase("roads")
	dragon_era.erase("villagers")
	var loaded_dragon_era := VillageSim.from_save_data(dragon_era)
	_check(loaded_dragon_era != null, "version 2 save loads")
	if loaded_dragon_era != null:
		_check(loaded_dragon_era.dragon_seed == 2, "version 2 keeps its dragon")


func _grass_cell(sim: VillageSim, terrain := VillageSim.Terrain.GRASS) -> Vector2i:
	for y in range(sim.height):
		for x in range(sim.width):
			if sim.terrain_at(Vector2i(x, y)) == terrain:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _test_road_rules() -> void:
	var sim := VillageSim.new()
	var cell := Vector2i(20, 20)
	var wood_before := sim.wood
	_check(sim.place_road(cell), "can place a road on grass")
	_check(sim.has_road(cell), "road is recorded")
	_check(sim.wood == wood_before - VillageSim.ROAD_COST, "road costs wood")
	_check(not sim.place_road(cell), "can't place a road twice")
	_check(sim.wood == wood_before - VillageSim.ROAD_COST, "failed road costs nothing")
	_check(not sim.place_road(Vector2i(-1, 0)), "no road off the map")
	_check(not sim.place_road(_grass_cell(sim, VillageSim.Terrain.WATER)), "no road on water")
	_check(not sim.place_road(_grass_cell(sim, VillageSim.Terrain.FOREST)), "no road through forest")
	sim.wood = 0
	_check(not sim.place_road(Vector2i(21, 20)), "no road without wood")


func _test_roads_and_buildings_block_each_other() -> void:
	var sim := VillageSim.new()
	sim.place_road(Vector2i(20, 20))
	_check(not sim.place(&"house", Vector2i(20, 20)), "no building on a road")
	sim.place(&"house", Vector2i(21, 20))
	_check(not sim.place_road(Vector2i(21, 20)), "no road on a building")
	_check(sim.building_count() == 1, "roads don't count as buildings")
	_check(sim.is_walkable(Vector2i(20, 20)), "roads are walkable")
	_check(not sim.is_walkable(Vector2i(21, 20)), "buildings aren't walkable")


func _test_demolishing_roads() -> void:
	var sim := VillageSim.new()
	sim.place_road(Vector2i(20, 20))
	var wood_before := sim.wood
	_check(sim.demolish(Vector2i(20, 20)), "can demolish a road")
	_check(not sim.has_road(Vector2i(20, 20)), "road is gone")
	_check(sim.wood == wood_before, "roads give no refund")


func _test_roads_survive_save_and_load() -> void:
	var sim := VillageSim.new()
	sim.place_road(Vector2i(20, 20))
	sim.place_road(Vector2i(21, 20))
	SaveGame.write(sim, TEST_SAVE)
	var loaded := SaveGame.read(TEST_SAVE)
	_check(loaded != null and loaded.has_road(Vector2i(21, 20)), "roads load back")
	var data := sim.to_save_data()
	var water := _grass_cell(sim, VillageSim.Terrain.WATER)
	data.roads = [{"x": water.x, "y": water.y}]
	_check(VillageSim.from_save_data(data) == null, "rejects a road on water")
	data.roads = [{"x": 20, "y": 20}, {"x": 20, "y": 20}]
	_check(VillageSim.from_save_data(data) == null, "rejects duplicate roads")


func _test_dragon_spares_roads() -> void:
	var sim := _village(30, 4)
	var road_cells: Array[Vector2i] = []
	for y in range(40):
		for x in range(40):
			if sim.place_road(Vector2i(x, y)):
				road_cells.append(Vector2i(x, y))
	var before := sim.building_count()
	var lost := [0]
	sim.dragon_struck.connect(func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		lost[0] = destroyed.size())
	_run_dragon(sim, VillageSim.DragonState.GONE)
	_check(lost[0] >= 1 and lost[0] / float(before) < 0.1, "roads don't affect the 10% limit")
	for cell in road_cells:
		_check(sim.has_road(cell) and not sim.is_scorched(cell), "road survives dragon")


func _test_houses_and_workplaces() -> void:
	var sim := VillageSim.new()
	sim.place(&"farm", Vector2i(22, 20))
	sim.place(&"house", Vector2i(21, 20))
	sim.place(&"lumber_camp", Vector2i(20, 20))
	sim.place(&"house", Vector2i(20, 21))
	var homes: Array[Vector2i] = [Vector2i(20, 21), Vector2i(21, 20)]
	var jobs: Array[Vector2i] = [Vector2i(20, 20), Vector2i(22, 20)]
	_check(sim.houses() == homes, "lists houses in a stable order")
	_check(sim.workplaces() == jobs, "lists workplaces in a stable order")


## A village with its people already moved in.
func _settled(placements: Dictionary, people: int) -> VillageSim:
	var sim := VillageSim.new(40, 40, 1, 1)
	sim.wood = 1000
	sim.food = 10000
	sim.water = 10000
	for cell: Vector2i in placements:
		_check(sim.place(placements[cell], cell), "placed %s at %s" % [placements[cell], cell])
	sim.population = people
	return sim


func _test_no_workers_means_no_production() -> void:
	var sim := VillageSim.new()
	sim.place(&"lumber_camp", Vector2i(20, 20))
	sim.place(&"farm", Vector2i(22, 20))
	var wood := sim.wood
	var food := sim.food
	for i in range(100):
		sim.tick()
	_check(sim.wood == wood and sim.food == food, "nobody working means nothing produced")
	_check(sim.filled_jobs() == 0 and sim.total_jobs() == 4, "jobs are counted: %d/%d" % [sim.filled_jobs(), sim.total_jobs()])


func _test_only_people_inside_produce() -> void:
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(22, 20): &"lumber_camp"}, 1)
	var worked := 0
	for i in range(200):
		var working := 0
		for villager in sim.villagers:
			if villager.state == Villager.State.WORKING:
				working += 1
		var wood := sim.wood
		sim.tick()
		var produced := sim.wood - wood
		_check(produced == 2 * working, "wood only comes from people inside (%d from %d)" % [produced, working])
		worked += working
	_check(worked > 50, "the villager actually works: %d ticks" % worked)
	var saw_commute := {}
	for i in range(100):
		saw_commute[sim.villagers[0].state] = true
		sim.tick()
	_check(saw_commute.size() >= 3, "they go between home, walking and work")


func _test_jobs_are_limited() -> void:
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(20, 22): &"house", Vector2i(22, 20): &"farm"}, 8)
	sim.tick()
	_check(sim.filled_jobs() == 2, "a farm has 2 jobs, filled %d" % sim.filled_jobs())
	_check(sim.workers_at(Vector2i(22, 20)) == 2, "the farm has 2 workers")
	sim.place(&"lumber_camp", Vector2i(24, 20))
	sim.tick()
	_check(sim.filled_jobs() == 4, "spare people take new jobs: %d" % sim.filled_jobs())


func _test_roads_raise_production() -> void:
	var house := Vector2i(16, 20)
	var camp := Vector2i(24, 20)
	var without_road := _settled({house: &"house", camp: &"lumber_camp"}, 2)
	var with_road := _settled({house: &"house", camp: &"lumber_camp"}, 2)
	for x in range(house.x, camp.x + 1):
		with_road.place_road(Vector2i(x, 21))
	var wood_without := without_road.wood
	var wood_with := with_road.wood
	for i in range(400):
		without_road.tick()
		with_road.tick()
	var gain_without := without_road.wood - wood_without
	var gain_with := with_road.wood - wood_with
	_check(gain_with > gain_without * 1.15, "road raises output: %d vs %d" % [gain_with, gain_without])


func _test_walled_in_workplace_gets_no_workers() -> void:
	var center := Vector2i(20, 20)
	var sim := _settled({
		center: &"lumber_camp",
		center + Vector2i.UP: &"house",
		center + Vector2i.DOWN: &"farm",
		center + Vector2i.LEFT: &"farm",
		center + Vector2i.RIGHT: &"farm",
	}, 4)
	sim.tick()
	_check(sim.workers_at(center) == 0, "nobody can reach a walled-in camp")
	sim.demolish(center + Vector2i.RIGHT)
	sim.tick()
	_check(sim.workers_at(center) > 0 or sim.filled_jobs() == sim.population, "opening a side lets people reach it")


func _test_people_get_new_jobs_when_buildings_go() -> void:
	var sim := _settled({
		Vector2i(20, 20): &"house", Vector2i(23, 20): &"farm", Vector2i(25, 20): &"lumber_camp",
	}, 2)
	for i in range(30):
		sim.tick()
	sim.demolish(Vector2i(23, 20))
	sim.tick()
	_check(sim.workers_at(Vector2i(25, 20)) == 2, "workers move to the remaining job")
	for i in range(60):
		sim.tick()
	sim.place(&"house", Vector2i(18, 20))
	sim.demolish(Vector2i(20, 20))
	_check(sim.population <= sim.housing(), "nobody is left without housing")
	sim.tick()
	for villager in sim.villagers:
		_check(villager.home == Vector2i(18, 20), "people move to the remaining house")


func _test_people_never_stand_in_buildings() -> void:
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(20, 24): &"house", Vector2i(24, 20): &"farm", Vector2i(24, 24): &"lumber_camp"}, 8)
	for i in range(300):
		sim.tick()
		# Keep changing the layout under people's feet.
		if i % 11 == 0:
			var spot := Vector2i(21 + i % 3, 21 + i % 3)
			if sim.building_at(spot) != &"":
				sim.demolish(spot)
			else:
				sim.place(&"farm", spot)
		for villager in sim.villagers:
			var outdoors := villager.state in [Villager.State.WALKING, Villager.State.OUTSIDE]
			if outdoors and villager.cell != Villager.NO_CELL and sim.tick_count > 2:
				if not sim.is_walkable(villager.cell):
					# Allowed only for the tick the layout changed.
					_check(i % 11 == 0 or i % 11 == 1, "person inside a building at tick %d" % i)


func _test_save_during_commute_plays_on_identically() -> void:
	var sim := _settled({
		Vector2i(16, 20): &"house", Vector2i(16, 22): &"house",
		Vector2i(24, 20): &"farm", Vector2i(24, 22): &"lumber_camp",
	}, 6)
	var saw_walking := false
	for round_index in range(8):
		for i in range(7):
			sim.tick()
		for villager in sim.villagers:
			saw_walking = saw_walking or villager.state == Villager.State.WALKING
		SaveGame.write(sim, TEST_SAVE)
		var loaded := SaveGame.read(TEST_SAVE)
		_check(loaded != null, "commuting villagers load back")
		if loaded == null:
			return
		_check(loaded.to_save_data() == sim.to_save_data(), "save matches the game")
		var original := VillageSim.from_save_data(sim.to_save_data())
		for i in range(25):
			original.tick()
			loaded.tick()
		_check(loaded.to_save_data() == original.to_save_data(), "loaded game plays on identically")
	_check(saw_walking, "the test saved while someone was walking")


func _test_rejects_bad_villagers() -> void:
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(24, 20): &"farm"}, 2)
	for i in range(8):
		sim.tick()
	var good := sim.to_save_data()
	_check(VillageSim.from_save_data(good) != null, "good villagers load")
	var fewer := good.duplicate(true)
	fewer.villagers.pop_back()
	_check(VillageSim.from_save_data(fewer) == null, "rejects villagers not matching the population")
	for change: Array in [
		["state", 99], ["timer", -3], ["cell", [999, 999]], ["home", "x"], ["path", "x"],
		["path", [[-5, 2]]], ["progress", "far"],
	]:
		var bad := good.duplicate(true)
		bad.villagers[0][change[0]] = change[1]
		_check(VillageSim.from_save_data(bad) == null, "rejects villager %s" % change[0])


func _test_older_saves_get_villagers() -> void:
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(24, 20): &"farm"}, 3)
	var data := sim.to_save_data()
	data.version = 3
	data.erase("villagers")
	var loaded := VillageSim.from_save_data(data)
	_check(loaded != null, "version 3 save loads")
	if loaded != null:
		loaded.tick()
		_check(loaded.villagers.size() == 3, "version 3 population becomes villagers")
		_check(loaded.filled_jobs() == 2, "they get jobs: %d" % loaded.filled_jobs())


func _test_save_slots() -> void:
	var test_directory := "user://test_slots"
	DirAccess.make_dir_recursive_absolute(test_directory)
	var real_directory := SaveGame.directory
	SaveGame.directory = test_directory
	_clear_slots(test_directory)

	_check(not SaveGame.any_slot_used(), "slots start empty")
	_check(SaveGame.slot_info(1).status == SaveGame.SlotInfo.Status.EMPTY, "empty slot reports empty")
	_check(SaveGame.read_slot(1) == null, "empty slot has no game")

	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(24, 20): &"farm"}, 2)
	for i in range(30):
		sim.tick()
	_check(SaveGame.write_slot(2, sim, "Sunny Hollow", 1000000) == OK, "saves to a slot")
	_check(SaveGame.any_slot_used(), "slot is now used")
	var info := SaveGame.slot_info(2)
	_check(info.status == SaveGame.SlotInfo.Status.READY, "slot is ready")
	_check(info.name == "Sunny Hollow", "name comes back: %s" % info.name)
	_check(info.saved_at == 1000000, "save time comes back: %d" % info.saved_at)
	_check(info.wood == sim.wood and info.food == sim.food, "resources come back")
	_check(info.population == sim.population and info.housing == sim.housing(), "people come back")
	_check(info.filled_jobs == sim.filled_jobs() and info.total_jobs == 2, "jobs come back")
	_check(info.buildings == 2 and info.game_seconds == 30, "buildings and time come back")
	var loaded := SaveGame.read_slot(2)
	_check(loaded != null and loaded.to_save_data() == sim.to_save_data(), "slot holds the whole game")
	_check(SaveGame.slot_info(1).status == SaveGame.SlotInfo.Status.EMPTY, "other slots are untouched")

	var before := int(Time.get_unix_time_from_system())
	_check(SaveGame.write_slot(2, sim, "Renamed") == OK, "can replace a slot")
	info = SaveGame.slot_info(2)
	_check(info.name == "Renamed", "replacing changes the name")
	_check(info.saved_at >= before, "save time defaults to now")

	for slot: int in [0, 4, -1]:
		_check(SaveGame.write_slot(slot, sim, "x") != OK, "no slot %d" % slot)
		_check(SaveGame.read_slot(slot) == null, "can't read slot %d" % slot)
		_check(not FileAccess.file_exists(SaveGame.slot_path(slot)), "slot %d wrote nothing" % slot)

	_check(SaveGame.clean_name("  Oak & Ash_é!  ", 1) == "Oak  Ash!", "strips unsupported characters")
	_check(SaveGame.clean_name("???".left(0), 3) == "Village 3", "blank name gets a default")
	_check(SaveGame.clean_name("&&&", 2) == "Village 2", "unusable name gets a default")
	_check(SaveGame.clean_name("x".repeat(99), 1).length() == SaveGame.MAX_NAME_LENGTH, "long name is cut")

	for text: String in ["not json", "{}", "[1]", '{"name": "x", "game": 5}', '{"name": "x", "game": {}}']:
		var file := FileAccess.open(SaveGame.slot_path(3), FileAccess.WRITE)
		file.store_string(text)
		file.close()
		_check(SaveGame.slot_info(3).status == SaveGame.SlotInfo.Status.DAMAGED, "damaged: %s" % text)
		_check(SaveGame.read_slot(3) == null, "damaged slot doesn't load: %s" % text)

	_test_old_save_moves_to_slot(test_directory, sim)
	_clear_slots(test_directory)
	DirAccess.remove_absolute(test_directory)
	SaveGame.directory = real_directory


func _test_old_save_moves_to_slot(test_directory: String, sim: VillageSim) -> void:
	_clear_slots(test_directory)
	var old_path := test_directory.path_join(SaveGame.OLD_SAVE_NAME)
	var file := FileAccess.open(old_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(sim.to_save_data()))
	file.close()
	var old_text := FileAccess.get_file_as_string(old_path)
	var old_time := FileAccess.get_modified_time(old_path)

	SaveGame.move_old_save_to_slot()
	var info := SaveGame.slot_info(1)
	_check(info.status == SaveGame.SlotInfo.Status.READY, "old save moves to slot 1")
	_check(info.name == SaveGame.OLD_SAVE_DISPLAY_NAME, "old save gets a name")
	_check(info.saved_at == old_time, "old save keeps its time")
	_check(info.wood == sim.wood, "old save keeps its game")
	_check(FileAccess.get_file_as_string(old_path) == old_text, "old file stays as a backup")

	SaveGame.write_slot(1, sim, "Mine", 5)
	SaveGame.move_old_save_to_slot()
	_check(SaveGame.slot_info(1).name == "Mine", "old save never overwrites a slot")


func _clear_slots(test_directory: String) -> void:
	for file_name: String in DirAccess.get_files_at(test_directory):
		DirAccess.remove_absolute(test_directory.path_join(file_name))


func _test_well_needs_workers() -> void:
	var empty := VillageSim.new()
	empty.place(&"well", Vector2i(20, 20))
	var before := empty.water
	for i in range(50):
		empty.tick()
	_check(empty.water == before, "a well with nobody working makes no water")
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(22, 20): &"well"}, 2)
	var made := 0
	for i in range(200):
		var working := 0
		for villager in sim.villagers:
			if villager.state == Villager.State.WORKING:
				working += 1
		var water := sim.water
		var people := sim.population
		sim.tick()
		var drunk := people if sim.tick_count % VillageSim.MEAL_INTERVAL == 0 else 0
		_check(sim.water - water == 3 * working - drunk, "well water comes from workers inside")
		made += working
	_check(made > 50, "the well is worked: %d" % made)
	_check(sim.workers_at(Vector2i(22, 20)) == 2, "a well has 2 jobs")


func _test_people_need_water() -> void:
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(20, 22): &"house"}, 8)
	sim.water = 0
	for i in range(VillageSim.POPULATION_INTERVAL):
		sim.tick()
	_check(sim.population == 7, "people leave without water")
	sim.water = 10
	sim.food = 10
	while sim.tick_count % VillageSim.MEAL_INTERVAL != VillageSim.MEAL_INTERVAL - 1:
		sim.tick()
	sim.water = 10
	sim.food = 10
	sim.tick()
	_check(sim.water == 10 - sim.population, "each villager drinks 1 water per meal: %d left" % sim.water)
	_check(sim.food == 10 - sim.population, "each villager eats 1 food per meal: %d left" % sim.food)


## A village whose dragon is on its way, with towers built nearest its target.
func _defended_village(tower_count: int, water: int, dragon_seed := 3) -> VillageSim:
	var sim := _village(60, dragon_seed)
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	var target := sim.dragon_target
	var cells: Array[Vector2i] = []
	for y in range(40):
		for x in range(40):
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(target) < b.distance_squared_to(target))
	var placed := 0
	for cell in cells:
		if placed == tower_count:
			break
		if sim.place(&"tower", cell):
			placed += 1
	_check(placed == tower_count, "placed %d towers" % placed)
	sim.water = water
	return sim


func _strike(sim: VillageSim) -> Dictionary:
	var result := {"destroyed": 0, "defenders": 0, "threatened": 0, "struck": false}
	sim.dragon_defended.connect(func(defenders: Array[Vector2i], threatened: int) -> void:
		result.defenders = defenders.size()
		result.threatened = threatened)
	sim.dragon_struck.connect(func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		result.struck = true
		result.destroyed = destroyed.size())
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	return result


func _test_towers_save_buildings() -> void:
	for dragon_seed in range(5):
		var sim := _defended_village(1, 100, dragon_seed)
		var tower := sim.towers()[0]
		_check(Vector2(tower).distance_to(Vector2(sim.dragon_target)) <= VillageSim.TOWER_RANGE, "tower is in range")
		var result := _strike(sim)
		_check(result.defenders == 1, "one tower defends")
		_check(result.destroyed == result.threatened - 1, "it saves one building: %d of %d lost" % [result.destroyed, result.threatened])
		_check(sim.water == 100 - VillageSim.TOWER_WATER_PER_DEFENSE, "defending costs water: %d" % sim.water)


func _test_enough_towers_drive_off_the_dragon() -> void:
	var sim := _defended_village(12, 1000)
	var before := sim.building_count()
	var result := _strike(sim)
	_check(result.struck and result.destroyed == 0, "enough towers save everything")
	_check(result.defenders == result.threatened, "only as many towers fire as needed")
	_check(sim.water == 1000 - result.defenders * VillageSim.TOWER_WATER_PER_DEFENSE, "only firing towers use water")
	_check(sim.building_count() == before, "no buildings lost")
	_run_dragon(sim, VillageSim.DragonState.GONE)
	_check(sim.dragon_state == VillageSim.DragonState.GONE, "the dragon still leaves")


func _test_towers_need_water_and_range() -> void:
	var dry := _defended_village(10, VillageSim.TOWER_WATER_PER_DEFENSE - 1)
	var dry_result := _strike(dry)
	_check(dry_result.defenders == 0 and dry_result.destroyed >= 1, "towers without water can't defend")
	_check(dry.water == VillageSim.TOWER_WATER_PER_DEFENSE - 1, "no water spent when it can't defend")
	var limited := _defended_village(10, VillageSim.TOWER_WATER_PER_DEFENSE)
	var one_shot := _strike(limited)
	_check(one_shot.defenders == 1 and limited.water == 0, "water limits how many towers fire")

	var far := _village(60, 3)
	_run_dragon(far, VillageSim.DragonState.INBOUND)
	far.water = 1000
	for y in range(40):
		for x in range(40):
			if Vector2(x, y).distance_to(Vector2(far.dragon_target)) > VillageSim.TOWER_RANGE + 1:
				far.place(&"tower", Vector2i(x, y))
	var far_result := _strike(far)
	_check(far_result.defenders == 0 and far_result.destroyed >= 1, "towers out of range don't defend")
	for size: int in [11, 30, 90]:
		for dragon_seed in range(10):
			var village := _village(size, dragon_seed)
			village.place(&"tower", Vector2i(30, 30))
			village.water = 0
			var result := _strike(village)
			_check(result.destroyed / float(village.building_count() + result.destroyed) < 0.1, "still under 10% with towers")


func _test_towers_are_not_jobs() -> void:
	var sim := VillageSim.new()
	sim.wood = 100
	sim.place(&"tower", Vector2i(20, 20))
	sim.place(&"well", Vector2i(22, 20))
	_check(sim.total_jobs() == 2, "towers have no jobs, wells have 2")
	var jobs: Array[Vector2i] = [Vector2i(22, 20)]
	var defenses: Array[Vector2i] = [Vector2i(20, 20)]
	_check(sim.workplaces() == jobs, "towers aren't workplaces")
	_check(sim.towers() == defenses, "towers are listed")


func _test_older_saves_get_water() -> void:
	var sim := _settled({Vector2i(20, 20): &"house", Vector2i(20, 22): &"house"}, 8)
	var data := sim.to_save_data()
	data.version = 4
	data.erase("water")
	var loaded := VillageSim.from_save_data(data)
	_check(loaded != null, "version 4 save loads")
	if loaded != null:
		_check(loaded.water == VillageSim.OLD_SAVE_WATER_TICKS * 2, "old save gets a minute of water: %d" % loaded.water)
	sim.water = 77
	var current := VillageSim.from_save_data(sim.to_save_data())
	_check(current != null and current.water == 77, "water is saved")


func _test_jobs_balance_wood_food_and_water() -> void:
	# Two farms right beside the houses and a well farther away.
	var sim := _settled({
		Vector2i(20, 20): &"house", Vector2i(20, 22): &"house",
		Vector2i(22, 20): &"farm", Vector2i(22, 22): &"farm", Vector2i(28, 20): &"well",
	}, 4)
	sim.tick()
	_check(sim.workers_at(Vector2i(28, 20)) == 2, "the farther well still gets workers: %d" % sim.workers_at(Vector2i(28, 20)))
	_check(sim.filled_jobs() == 4, "everyone has a job")

	# Everyone already works at farms; a new well must still get workers.
	var farming := _settled({
		Vector2i(20, 20): &"house", Vector2i(22, 20): &"farm", Vector2i(22, 22): &"farm",
	}, 4)
	for i in range(30):
		farming.tick()
	_check(farming.workers_at(Vector2i(22, 20)) + farming.workers_at(Vector2i(22, 22)) == 4, "all four farm at first")
	farming.place(&"well", Vector2i(26, 20))
	farming.tick()
	_check(farming.workers_at(Vector2i(26, 20)) == 2, "workers move to the new well: %d" % farming.workers_at(Vector2i(26, 20)))
	var food := farming.food
	for i in range(80):
		farming.tick()
		for villager in farming.villagers:
			if villager.state == Villager.State.WORKING:
				_check(farming._product_of(villager.job) != "" , "working villagers have a real job")
	_check(farming.water > 0, "the well gets worked")
