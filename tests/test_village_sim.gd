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
	_test_old_saves_still_load()
	_test_road_rules()
	_test_roads_and_buildings_block_each_other()
	_test_demolishing_roads()
	_test_roads_survive_save_and_load()
	_test_clearing_forest()
	_test_bridge_rules()
	_test_bridges_connect_villagers()
	_test_removing_a_bridge_underfoot()
	_test_bridges_and_clearings_survive_save_and_load()
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
	_test_towers_are_not_jobs()
	_test_older_saves_get_water()
	_test_jobs_balance_wood_food_and_water()
	_test_dragon_needs_a_big_enough_village()
	_test_dragon_arrival_time_varies()
	_test_dragon_visits_stay_and_strike_more_than_once()
	_test_dragon_damage_limits_and_variety()
	_test_dragons_keep_coming_and_level_up()
	_test_small_villages_only_see_level_1()
	_test_dragon_choice_of_target()
	_test_strikes_burn_the_closest_buildings()
	_test_demolishing_during_approach_saves_the_village()
	_test_can_rebuild_on_scorched_ground()
	_test_towers_drive_off_the_dragon()
	_test_defense_needs_water_and_range()
	_test_dragon_spares_roads()
	_test_training_makes_fighters()
	_test_fighters_rush_to_the_dragon_and_throw_water()
	_test_dragon_survives_save_and_load()
	_test_older_saves_get_more_dragons()
	_test_hero_unlocks_at_50_people_after_a_dragon()
	_test_hero_choices_must_be_valid()
	_test_one_hero_per_ten_villagers()
	_test_heroes_fight_together()
	_test_armor_trades_health_for_speed()
	_test_hero_hunts_and_slays_without_water()
	_test_hero_holds_the_dragon_without_more_damage()
	_test_longbow_stays_out_of_the_fire()
	_test_hero_is_wounded_and_recovers()
	_test_hero_saves_and_plays_on_identically()
	_test_teleport_only_to_walkable_ground()
	_test_teleported_hero_holds_then_patrols()
	_test_teleported_hero_still_hunts()
	_test_older_saves_have_no_hero()
	_test_single_hero_saves_still_load()
	_test_rejects_bad_heroes()
	_test_docks_placement_rules()
	_test_docks_fish_for_food()
	_test_boats_stay_on_water()
	_test_docks_rival_farms()
	_test_cut_short_shift_loses_the_catch()
	_test_docks_save_and_play_on_identically()
	_test_older_saves_reject_docks()
	_test_dragon_burns_docks_but_not_water()
	_test_happiness_factor_table()
	_test_happiness_supplies()
	_test_happiness_jobs()
	_test_happiness_housing()
	_test_happiness_defense()
	_test_happiness_fears_dragon_damage()
	_test_happiness_roads()
	_test_happiness_range_and_weights()
	_test_happiness_moves_gradually()
	_test_happiness_changes_growth()
	_test_happiness_survives_save_and_load()
	_test_older_saves_get_happiness()
	_test_building_attractions()
	_test_staff_run_attractions()
	_test_entertainment_value()
	_test_fun_jobs_come_after_food_and_water()
	_test_dragon_buries_attractions()
	_test_demolishing_a_playground()
	_test_playgrounds_save_and_load()
	_test_older_saves_have_no_playgrounds()
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


func _first_building(sim: VillageSim) -> Vector2i:
	for y in range(40):
		for x in range(40):
			if sim.building_at(Vector2i(x, y)) != &"":
				return Vector2i(x, y)
	return Vector2i(-1, -1)


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
	var forest := _grass_cell(sim, VillageSim.Terrain.FOREST)
	data.roads = [{"x": forest.x, "y": forest.y}]
	_check(VillageSim.from_save_data(data) == null, "rejects a road in the forest")
	data.roads = [{"x": water.x, "y": water.y}]
	data.version = VillageSim.FIRST_BRIDGE_VERSION - 1
	_check(VillageSim.from_save_data(data) == null, "rejects a road on water from before bridges")
	data.version = VillageSim.SAVE_VERSION
	data.roads = [{"x": 20, "y": 20}, {"x": 20, "y": 20}]
	_check(VillageSim.from_save_data(data) == null, "rejects duplicate roads")


func _test_clearing_forest() -> void:
	var sim := VillageSim.new()
	var forest := _grass_cell(sim, VillageSim.Terrain.FOREST)
	var wood_before := sim.wood
	_check(not sim.is_walkable(forest), "forest can't be walked through")
	_check(not sim.place(&"house", forest), "can't build in the forest")
	_check(sim.clear_forest(forest), "can clear forest")
	_check(sim.terrain_at(forest) == VillageSim.Terrain.GRASS, "cleared forest is grass")
	_check(sim.wood == wood_before + VillageSim.CLEARED_FOREST_WOOD, "clearing forest gives wood")
	_check(sim.is_walkable(forest), "cleared forest can be walked on")
	_check(sim.place(&"house", forest), "can build where forest was cleared")
	wood_before = sim.wood
	_check(not sim.clear_forest(forest), "can't clear the same forest twice")
	_check(not sim.clear_forest(Vector2i(20, 20)), "can't clear grass")
	_check(not sim.clear_forest(_grass_cell(sim, VillageSim.Terrain.WATER)), "can't clear water")
	_check(not sim.clear_forest(Vector2i(-1, 0)), "can't clear off the map")
	_check(sim.wood == wood_before, "failed clearing gives nothing")


func _test_bridge_rules() -> void:
	var sim := VillageSim.new()
	var water := _grass_cell(sim, VillageSim.Terrain.WATER)
	var wood_before := sim.wood
	_check(not sim.is_walkable(water), "water can't be walked on")
	_check(sim.place_bridge(water), "can build a bridge on water")
	_check(sim.is_bridge(water) and sim.is_walkable(water), "bridges can be walked on")
	_check(sim.wood == wood_before - VillageSim.BRIDGE_COST, "bridge costs wood")
	_check(not sim.place_bridge(water), "can't build a bridge twice")
	_check(not sim.place_bridge(Vector2i(20, 20)), "no bridge on grass")
	_check(not sim.place_bridge(_grass_cell(sim, VillageSim.Terrain.FOREST)), "no bridge in the forest")
	_check(not sim.place_bridge(Vector2i(-1, 0)), "no bridge off the map")
	_check(not sim.place(&"house", water), "can't build on a bridge")
	_check(not sim.place_road(water), "can't put a road on a bridge")
	wood_before = sim.wood
	_check(sim.demolish(water), "can demolish a bridge")
	_check(not sim.is_walkable(water), "demolished bridge is water again")
	_check(sim.wood == wood_before + VillageSim.BRIDGE_COST / 2, "demolishing a bridge refunds half")
	sim.wood = VillageSim.BRIDGE_COST - 1
	_check(not sim.place_bridge(water), "no bridge without wood")


## A house and a farm on opposite banks of a river running down column 22.
func _river_sim() -> VillageSim:
	var sim := _settled({}, 0)
	for y in range(sim.height):
		for x in range(sim.width):
			sim._terrain[y * sim.width + x] = VillageSim.Terrain.WATER if x == 22 else VillageSim.Terrain.GRASS
	sim._rebuild_grid()
	sim.place(&"house", Vector2i(20, 20))
	sim.place(&"farm", Vector2i(24, 20))
	sim.population = 2
	return sim


func _test_bridges_connect_villagers() -> void:
	var sim := _river_sim()
	sim.tick()
	_check(sim.workers_at(Vector2i(24, 20)) == 0, "a river cuts people off from work")
	sim.place_bridge(Vector2i(22, 20))
	_check(sim.workers_at(Vector2i(24, 20)) == 2, "a bridge lets people reach work")
	var food_before := sim.food
	var crossed := false
	for i in range(40):
		sim.tick()
		crossed = crossed or sim.food > food_before
	_check(crossed, "people cross the bridge and produce")
	sim.demolish(Vector2i(22, 20))
	_check(sim.workers_at(Vector2i(24, 20)) == 0, "removing the bridge cuts them off again")


func _test_removing_a_bridge_underfoot() -> void:
	var sim := _river_sim()
	var bridge := Vector2i(22, 20)
	sim.place_bridge(bridge)
	var walker: Villager = null
	for i in range(100):
		sim.tick()
		for villager in sim.villagers:
			if villager.cell == bridge:
				walker = villager
		if walker != null:
			break
	_check(walker != null, "someone walks onto the bridge")
	sim.demolish(bridge)
	_check(walker != null and sim.is_walkable(walker.cell), "nobody is left standing in the water")
	_check(VillageSim.from_save_data(sim.to_save_data()) != null, "can save right after removing a bridge in use")
	for i in range(10):
		sim.tick()
		_check(sim.is_walkable(walker.cell) or walker.state not in [Villager.State.WALKING, Villager.State.OUTSIDE], "stays out of the water")


func _test_bridges_and_clearings_survive_save_and_load() -> void:
	var sim := VillageSim.new()
	var water := _grass_cell(sim, VillageSim.Terrain.WATER)
	var forest := _grass_cell(sim, VillageSim.Terrain.FOREST)
	sim.place_bridge(water)
	sim.clear_forest(forest)
	SaveGame.write(sim, TEST_SAVE)
	var loaded := SaveGame.read(TEST_SAVE)
	_check(loaded != null and loaded.is_bridge(water) and loaded.is_walkable(water), "bridges load back")
	_check(loaded != null and loaded.terrain_at(forest) == VillageSim.Terrain.GRASS, "cleared forest stays cleared")


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
		["path", [[-5, 2]]], ["progress", "far"], ["fish", -1], ["shift_ticks", "x"],
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
	_check(info.happiness == roundi(sim.happiness.value), "happiness comes back: %d" % info.happiness)
	_check("Happiness %d" % info.happiness in SaveMenu.describe_slot(info), "the slot shows happiness")
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


# --- Dragons ---

func _run_dragon(sim: VillageSim, until: VillageSim.DragonState) -> void:
	for i in range(2000):
		if sim.dragon_state == until:
			return
		sim.tick()


## Plays one whole dragon visit and reports what happened.
func _visit(sim: VillageSim) -> Dictionary:
	var result := {
		"level": 0, "strikes": 0, "destroyed": 0, "driven_off": false, "rampage": 0,
		"hits": 0, "attackers": [], "left": false, "buildings_before": 0, "water_before": 0,
	}
	var on_strike := func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		result.strikes += 1
		result.destroyed += destroyed.size()
	var on_hit := func(attackers: Array[Vector2i], _damage: int) -> void:
		result.hits += 1
		result.attackers.append_array(attackers)
	var on_left := func(driven_off: bool, _destroyed: int) -> void:
		result.left = true
		result.driven_off = driven_off
		result.rampage = sim.dragon_rampage_ticks
	sim.dragon_struck.connect(on_strike)
	sim.dragon_hit.connect(on_hit)
	sim.dragon_left.connect(on_left)
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	result.level = sim.dragon_level
	result.buildings_before = sim.building_count()
	result.water_before = sim.water
	for i in range(200):
		sim.tick()
		if result.left:
			break
	sim.dragon_struck.disconnect(on_strike)
	sim.dragon_hit.disconnect(on_hit)
	sim.dragon_left.disconnect(on_left)
	return result


func _test_dragon_needs_a_big_enough_village() -> void:
	var sim := _village(VillageSim.DRAGON_MIN_BUILDINGS - 1)
	for i in range(VillageSim.FIRST_DRAGON_WAIT_TICKS.y * 2):
		sim.tick()
	_check(sim.dragon_state == VillageSim.DragonState.WAITING, "dragon waits for 11 buildings")
	sim.place(&"farm", Vector2i(25, 20))
	sim.place(&"farm", Vector2i(26, 20))
	sim.tick()
	_check(sim.dragon_state == VillageSim.DragonState.WAITING, "dragon doesn't arrive the moment the village is big enough")


func _test_dragon_arrival_time_varies() -> void:
	var times := {}
	for dragon_seed in range(30):
		var timer := VillageSim.new(10, 10, 1, dragon_seed).dragon_timer
		_check(timer >= VillageSim.FIRST_DRAGON_WAIT_TICKS.x and timer <= VillageSim.FIRST_DRAGON_WAIT_TICKS.y, "first wait in range")
		times[timer] = true
	_check(times.size() > 10, "arrival time varies: %d different" % times.size())
	_check(VillageSim.FIRST_DRAGON_WAIT_TICKS.y < 420, "dragons come sooner than before")


func _test_dragon_visits_stay_and_strike_more_than_once() -> void:
	var stays := {}
	var multi_strike := 0
	for dragon_seed in range(20):
		var result := _visit(_village(40, dragon_seed))
		_check(result.left and not result.driven_off, "undefended dragon leaves on its own")
		var level: Dictionary = VillageSim.DRAGON_LEVELS[1]
		var shortest: int = level.stay.x
		_check(result.rampage >= mini(shortest, VillageSim.DRAGON_FIRST_STRIKE_TICK) , "dragon stays a while")
		stays[result.rampage] = true
		if result.strikes >= 2:
			multi_strike += 1
	_check(stays.size() >= 3, "how long it stays varies: %d different" % stays.size())
	_check(multi_strike >= 10, "dragons usually strike more than once: %d of 20" % multi_strike)


func _test_dragon_damage_limits_and_variety() -> void:
	for size: int in [11, 20, 45, 120]:
		var losses := {}
		for dragon_seed in range(25):
			var result := _visit(_village(size, dragon_seed))
			_check(result.destroyed >= 1, "undefended dragon destroys something")
			_check(result.destroyed / float(result.buildings_before) < 0.1, "level 1: %d of %d is under 10%%" % [result.destroyed, result.buildings_before])
			losses[result.destroyed] = true
		if size == 120:
			_check(losses.size() >= 3, "damage varies: %d different" % losses.size())


func _test_dragons_keep_coming_and_level_up() -> void:
	var sim := _village(60, 9)
	var levels: Array[int] = []
	for visit in range(5):
		var result := _visit(sim)
		levels.append(result.level)
		var limit := 0.1 if result.level == 1 else 0.2
		_check(result.destroyed / float(result.buildings_before) < limit, "visit %d (level %d) stays under its limit" % [visit + 1, result.level])
		# Rebuild so the village stays big enough for level 2.
		while sim.building_count() < 60:
			_village_fill(sim)
	_check(levels.slice(0, VillageSim.LEVEL_2_FROM_VISIT - 1).all(func(level: int) -> bool: return level == 1), "early dragons are level 1: %s" % [levels])
	_check(levels[VillageSim.LEVEL_2_FROM_VISIT - 1] == 2, "level 2 arrives on visit %d: %s" % [VillageSim.LEVEL_2_FROM_VISIT, levels])
	_check(sim.dragon_visits == 5, "five visits happened")

	var level_1_stays: Array[int] = []
	var level_2_stays: Array[int] = []
	var level_1_losses := 0.0
	var level_2_losses := 0.0
	for dragon_seed in range(12):
		var village := _village(60, dragon_seed)
		for visit in range(VillageSim.LEVEL_2_FROM_VISIT):
			var result := _visit(village)
			while village.building_count() < 60:
				_village_fill(village)
			if result.level == 1:
				level_1_stays.append(result.rampage)
				level_1_losses += result.destroyed
			else:
				level_2_stays.append(result.rampage)
				level_2_losses += result.destroyed
	var average := func(values: Array[int]) -> float:
		return values.reduce(func(total: int, value: int) -> int: return total + value, 0) / float(values.size())
	_check(average.call(level_2_stays) > average.call(level_1_stays), "level 2 stays longer: %.1f vs %.1f" % [average.call(level_2_stays), average.call(level_1_stays)])
	_check(level_2_losses / level_2_stays.size() > level_1_losses / level_1_stays.size(), "level 2 does more damage")


func _village_fill(sim: VillageSim) -> void:
	for y in range(40):
		for x in range(40):
			if sim.place(&"farm", Vector2i(x, y)):
				return


func _test_small_villages_only_see_level_1() -> void:
	var sim := _village(VillageSim.LEVEL_2_MIN_BUILDINGS - 5, 4)
	for visit in range(4):
		var result := _visit(sim)
		_check(result.level == 1, "a small village only meets level 1")
		while sim.building_count() < VillageSim.LEVEL_2_MIN_BUILDINGS - 5:
			_village_fill(sim)


func _test_dragon_choice_of_target() -> void:
	var sim := VillageSim.new(40, 40, 1, 1)
	sim.wood = 10000
	sim.place(&"farm", Vector2i(10, 10))
	sim.place(&"house", Vector2i(30, 10))
	sim.place(&"lumber_camp", Vector2i(10, 30))
	sim.place(&"tower", Vector2i(30, 30))
	sim.place(&"training_center", Vector2i(20, 32))
	sim.dragon_level = 1
	_check(sim.dragon_interest(Vector2i(10, 10)) > sim.dragon_interest(Vector2i(30, 10)), "level 1 prefers farms to houses")
	_check(sim.dragon_interest(Vector2i(30, 10)) > sim.dragon_interest(Vector2i(30, 30)), "level 1 avoids towers")
	var farm_alone := sim.dragon_interest(Vector2i(10, 10))
	sim.place(&"tower", Vector2i(12, 10))
	_check(sim.dragon_interest(Vector2i(10, 10)) < farm_alone, "a tower nearby puts a level 1 dragon off")
	sim.dragon_level = 2
	_check(sim.dragon_interest(Vector2i(20, 32)) > sim.dragon_interest(Vector2i(10, 30)), "level 2 goes after training centers")
	_check(sim.dragon_interest(Vector2i(30, 30)) > sim.dragon_interest(Vector2i(10, 30)), "level 2 goes after towers")


func _test_strikes_burn_the_closest_buildings() -> void:
	var sim := _village(120, 3)
	var lost: Array[Vector2i] = []
	var target := [Vector2i.ZERO]
	sim.dragon_struck.connect(func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		if lost.is_empty():
			target[0] = sim.dragon_previous_target
			lost.assign(destroyed))
	_run_dragon(sim, VillageSim.DragonState.RAMPAGE)
	var aim := sim.dragon_target
	while lost.is_empty():
		sim.tick()
	_check(target[0] == aim, "strike lands where the dragon aimed")
	var farthest_lost := 0
	for cell in lost:
		farthest_lost = maxi(farthest_lost, cell.distance_squared_to(aim))
	for y in range(40):
		for x in range(40):
			if sim.building_at(Vector2i(x, y)) != &"":
				_check(Vector2i(x, y).distance_squared_to(aim) >= farthest_lost, "closest buildings burn first")


func _test_demolishing_during_approach_saves_the_village() -> void:
	var sim := _village(12)
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	sim.demolish(sim.dragon_target)
	sim.demolish(_first_building(sim))
	var remaining := sim.building_count()
	var result := _visit(sim)
	_check(result.destroyed == 0, "too small a village loses nothing")
	_check(sim.building_count() == remaining, "buildings survive")


func _test_can_rebuild_on_scorched_ground() -> void:
	var sim := _village(30)
	var lost: Array[Vector2i] = []
	sim.dragon_struck.connect(func(destroyed: Array[Vector2i], _burned: Array[Vector2i]) -> void:
		lost.append_array(destroyed))
	_visit(sim)
	var cell := lost[0]
	_check(sim.is_scorched(cell), "destroyed building leaves scorched ground")
	_check(sim.place(&"house", cell), "can rebuild on scorched ground")
	_check(not sim.is_scorched(cell), "rebuilding clears the scorch")


## A village with towers built right beside each place the dragon could aim.
func _towered_village(towers: int, water: int, dragon_seed := 3) -> VillageSim:
	var sim := _village(40, dragon_seed)
	sim.wood = 100000
	# Spread evenly around the village, so no side is left open.
	var placed := 0
	for index in range(towers * 4):
		if placed == towers:
			break
		var angle := TAU * index / towers
		var cell := Vector2i((Vector2(20, 20) + Vector2.from_angle(angle) * (5 + index / towers)).round())
		if sim.place(&"tower", cell):
			placed += 1
	_check(placed == towers, "placed %d towers" % placed)
	sim.water = water
	return sim


func _test_towers_drive_off_the_dragon() -> void:
	var undefended := 0
	var defended := 0
	var driven_off := 0
	for dragon_seed in range(10):
		undefended += _visit(_village(40, dragon_seed)).destroyed
		var sim := _towered_village(12, 5000, dragon_seed)
		var result := _visit(sim)
		defended += result.destroyed
		if result.driven_off:
			driven_off += 1
			_check(sim.dragon_resolve == 0, "driven off means its resolve is gone")
		_check(result.hits > 0 and sim.water < result.water_before, "towers spend water to hit the dragon")
	_check(driven_off >= 8, "towers usually drive it off: %d of 10" % driven_off)
	_check(defended < undefended, "defended villages lose less: %d vs %d" % [defended, undefended])


func _test_defense_needs_water_and_range() -> void:
	var dry := _towered_village(12, 0)
	var dry_result := _visit(dry)
	_check(dry_result.hits == 0 and not dry_result.driven_off, "no water, no defense")

	var far := _village(40, 3)
	far.wood = 100000
	far.water = 5000
	for y in range(40):
		for x in range(40):
			if Vector2(x, y).distance_to(Vector2(20, 20)) > 16:
				far.place(&"tower", Vector2i(x, y))
	var far_result := _visit(far)
	_check(far_result.hits == 0, "towers out of range don't reach the dragon")
	_check(far.water >= 5000 - 200, "out-of-range towers don't waste water")


func _test_dragon_spares_roads() -> void:
	var sim := _village(30, 4)
	var road_cells: Array[Vector2i] = []
	for y in range(40):
		for x in range(40):
			if sim.place_road(Vector2i(x, y)):
				road_cells.append(Vector2i(x, y))
	var result := _visit(sim)
	_check(result.destroyed >= 1 and result.destroyed / float(result.buildings_before) < 0.1, "roads don't affect the 10% limit")
	for cell in road_cells:
		_check(sim.has_road(cell) and not sim.is_scorched(cell), "road survives dragon")


func _test_training_makes_fighters() -> void:
	var sim := _settled({
		Vector2i(20, 20): &"house", Vector2i(20, 22): &"house", Vector2i(23, 20): &"training_center",
		Vector2i(23, 22): &"farm", Vector2i(26, 20): &"well", Vector2i(26, 22): &"lumber_camp",
	}, 8)
	sim.tick()
	_check(sim.workers_at(Vector2i(23, 20)) == 2, "two people train at a time")
	var trainee_index := -1
	for index in range(sim.villagers.size()):
		if sim.villagers[index].job == Vector2i(23, 20):
			trainee_index = index
	var trainee := sim.villagers[trainee_index]
	var inside := 0
	while not sim.is_fighter(trainee) and sim.tick_count < 2000:
		var was_inside := trainee.state == Villager.State.WORKING
		var before := trainee.training
		sim.tick()
		if not was_inside:
			_check(trainee.training == before, "training only happens inside")
		else:
			inside += 1
	_check(sim.is_fighter(trainee), "staying long enough makes a fighter")
	_check(inside == VillageSim.TRAINING_TICKS, "it takes %d ticks inside: %d" % [VillageSim.TRAINING_TICKS, inside])
	sim.tick()
	_check(trainee.job != Vector2i(23, 20), "a trained fighter goes back to other work")
	_check(sim.workers_at(Vector2i(23, 20)) == 2, "someone else takes the training place")
	var saved := VillageSim.from_save_data(sim.to_save_data())
	_check(saved != null and saved.fighter_count() == sim.fighter_count(), "training is saved")
	for i in range(400):
		sim.tick()
	_check(sim.fighter_count() >= 4, "the center keeps training people: %d" % sim.fighter_count())
	for villager in sim.villagers:
		if sim.is_fighter(villager):
			_check(villager.job != Vector2i(23, 20), "fighters don't retrain")


func _test_fighters_rush_to_the_dragon_and_throw_water() -> void:
	var sim := _village(40, 6)
	sim.wood = 100000
	for y: int in [33, 35]:
		for x in range(10, 30, 2):
			sim.place(&"house", Vector2i(x, y))
	sim.population = sim.housing()
	sim.water = 5000
	sim.food = 5000
	sim.tick()
	for villager in sim.villagers:
		villager.training = VillageSim.TRAINING_TICKS
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	var fighters_walking := sim.villagers.filter(func(villager: Villager) -> bool:
		return villager.state == Villager.State.WALKING).size()
	_check(fighters_walking > sim.villagers.size() / 2, "fighters head for the dragon: %d" % fighters_walking)
	var result := _visit(sim)
	var villager_throws: int = result.attackers.filter(func(cell: Vector2i) -> bool: return sim.building_at(cell) != &"tower").size()
	_check(villager_throws > 0, "fighters throw water")
	_check(result.driven_off, "a crowd of fighters drives the dragon off")
	for i in range(40):
		sim.tick()
	var near := sim.villagers.filter(func(villager: Villager) -> bool:
		return villager.state == Villager.State.OUTSIDE and sim._near_dragon(villager.cell)).size()
	_check(near < sim.villagers.size(), "fighters go back to their routine afterward")


func _test_dragon_survives_save_and_load() -> void:
	for state: VillageSim.DragonState in [VillageSim.DragonState.INBOUND, VillageSim.DragonState.RAMPAGE, VillageSim.DragonState.DEPARTING]:
		var sim := _towered_village(2, 300, 5)
		_run_dragon(sim, state)
		if state == VillageSim.DragonState.RAMPAGE:
			for i in range(3):
				sim.tick()
		SaveGame.write(sim, TEST_SAVE)
		var loaded := SaveGame.read(TEST_SAVE)
		_check(loaded != null, "mid-visit save loads")
		if loaded == null:
			return
		_check(loaded.to_save_data() == sim.to_save_data(), "mid-visit save matches")
		for i in range(40):
			sim.tick()
			loaded.tick()
		_check(loaded.to_save_data() == sim.to_save_data(), "loaded dragon behaves identically")
		_check(loaded.dragon_state == VillageSim.DragonState.WAITING, "the visit ends and the next dragon waits")
	var data := _village(20).to_save_data()
	for change: Array in [["dragon_level", 9], ["dragon_resolve", -4], ["dragon_visits", "x"], ["dragon_state", 3]]:
		var bad := data.duplicate(true)
		bad[change[0]] = change[1]
		_check(VillageSim.from_save_data(bad) == null, "rejects bad %s" % change[0])


func _test_older_saves_get_more_dragons() -> void:
	var sim := _village(30, 2)
	_visit(sim)
	_run_dragon(sim, VillageSim.DragonState.WAITING)
	var data := sim.to_save_data()
	data.version = 5
	data.dragon_state = VillageSim.DragonState.GONE
	for key: String in ["dragon_level", "dragon_visits", "dragon_resolve", "dragon_stay", "dragon_budget",
			"dragon_destroyed", "dragon_rampage_ticks", "dragon_previous_x", "dragon_previous_y"]:
		data.erase(key)
	var loaded := VillageSim.from_save_data(data)
	_check(loaded != null, "a save from the one-dragon days loads")
	if loaded == null:
		return
	_check(loaded.dragon_state == VillageSim.DragonState.WAITING and loaded.dragon_visits == 1, "its dragon will come back")
	var next := _visit(loaded)
	_check(next.left and next.level == 1, "the next dragon is level 1")
	var with_villagers := _settled({Vector2i(20, 20): &"house"}, 2).to_save_data()
	with_villagers.version = 5
	for villager: Dictionary in with_villagers.villagers:
		villager.erase("training")
	var old_people := VillageSim.from_save_data(with_villagers)
	_check(old_people != null and old_people.fighter_count() == 0, "older villagers start untrained")


# --- Hero ---

func _hero_ready_village(armor := &"chainmail", weapon := &"longsword", look := &"ember") -> VillageSim:
	var map := VillageSim.new(40, 40, 1, 1)
	var placements := {}
	for y in range(14, 27, 3):
		for x in range(14, 27, 3):
			if map.terrain_at(Vector2i(x, y)) == VillageSim.Terrain.GRASS:
				placements[Vector2i(x, y)] = &"farm"
	var sim := _settled(placements, VillageSim.HERO_MIN_POPULATION)
	sim.dragon_visits = 1
	_check(sim.create_hero("Aria", armor, weapon, look), "hero created")
	sim.population = 0
	return sim


## Runs to the start of a long fight, so a test can watch the hero at work.
func _start_long_fight(sim: VillageSim, resolve: int) -> void:
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	sim.dragon_stay = 60
	sim.dragon_budget = 15
	sim.dragon_resolve = resolve


func _test_hero_unlocks_at_50_people_after_a_dragon() -> void:
	var sim := VillageSim.new(40, 40, 1, 1)
	sim.population = 50
	_check(not sim.can_create_hero(), "no hero before any dragon")
	sim.dragon_visits = 1
	sim.dragon_state = VillageSim.DragonState.INBOUND
	_check(not sim.can_create_hero(), "no hero while the first dragon is still on its way")
	sim.dragon_state = VillageSim.DragonState.RAMPAGE
	_check(sim.can_create_hero(), "a hero once a dragon has reached 50 people")
	sim.dragon_state = VillageSim.DragonState.WAITING
	_check(sim.can_create_hero(), "a hero after the dragon has gone")
	sim.population = 49
	_check(not sim.can_create_hero(), "no hero with 49 people")
	_check(not sim.create_hero("Aria", &"leather", &"longbow", &"frost"), "creating is refused while locked")
	_check(sim.heroes.is_empty(), "and leaves no hero behind")


func _test_hero_choices_must_be_valid() -> void:
	var sim := VillageSim.new(40, 40, 1, 1)
	sim.population = 50
	sim.dragon_visits = 1
	_check(not sim.create_hero("  <>  ", &"leather", &"longbow", &"frost"), "needs a usable name")
	_check(not sim.create_hero("Aria", &"tin", &"longbow", &"frost"), "needs real armor")
	_check(not sim.create_hero("Aria", &"leather", &"spoon", &"frost"), "needs a real weapon")
	_check(not sim.create_hero("Aria", &"leather", &"longbow", &"plain"), "needs a real look")
	_check(sim.heroes.is_empty(), "bad choices leave no hero behind")
	_check(sim.create_hero("  Aria <3 the Very Long Named  ", &"leather", &"longbow", &"frost"), "valid choices work")
	_check(sim.heroes[0].hero_name == "Aria 3 the Very", "name is cleaned and shortened: %s" % sim.heroes[0].hero_name)
	var rows := {}
	for armor: StringName in Hero.ARMORS:
		for weapon: StringName in Hero.WEAPONS:
			for look: StringName in Hero.LOOKS:
				rows[Hero.sprite_row_for(armor, weapon, look)] = true
	_check(rows.size() == 27 and rows.has(0) and rows.has(26), "every combination has its own sprite row")


func _test_one_hero_per_ten_villagers() -> void:
	var sim := VillageSim.new(40, 40, 1, 1)
	sim.population = 59
	sim.dragon_visits = 1
	_check(sim.hero_limit() == 5, "59 people support 5 heroes")
	for i in range(5):
		_check(sim.create_hero("Hero %d" % i, &"leather", &"longbow", &"frost"), "hero %d fits" % i)
	_check(not sim.can_create_hero(), "the limit is reached")
	_check(not sim.create_hero("Extra", &"leather", &"longbow", &"frost"), "a sixth hero needs 60 people")
	sim.population = 60
	_check(sim.create_hero("Sixth", &"leather", &"longbow", &"frost"), "60 people allow a sixth")
	sim.population = 30
	_check(sim.heroes.size() == 6, "heroes stay when the village shrinks")
	sim.population = 49
	_check(not sim.can_create_hero(), "and none can join under 50 people")


func _test_heroes_fight_together() -> void:
	var sim := _hero_ready_village()
	sim.population = 50
	_check(sim.create_hero("Bram", &"leather", &"battle_axe", &"raven"), "second hero created")
	_check(sim.create_hero("Cato", &"dragonscale", &"longsword", &"frost"), "third hero created")
	sim.population = 0
	var attackers := {}
	sim.hero_attacked.connect(func(hero: Hero) -> void: attackers[hero.hero_name] = true)
	_start_long_fight(sim, 100000)
	for i in range(12):
		sim.tick()
		var cells := {}
		for hero in sim.heroes:
			if hero.state != Villager.State.WALKING:
				_check(not cells.has(hero.cell), "heroes don't stand on each other at tick %d" % i)
				cells[hero.cell] = true
	_check(attackers.size() == 3, "all three heroes attack: %s" % [attackers.keys()])
	sim.dragon_resolve = 0
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	_check(sim.dragon_slain and sim.dragon_slayers().size() >= 2, "the heroes share the kill")
	for hero in sim.dragon_slayers():
		_check(hero.dragons_slain == 1, "%s's tally goes up" % hero.hero_name)


func _test_armor_trades_health_for_speed() -> void:
	var light := Hero.create("A", &"leather", &"longsword", &"ember")
	var middle := Hero.create("B", &"chainmail", &"longsword", &"ember")
	var heavy := Hero.create("C", &"dragonscale", &"longsword", &"ember")
	_check(light.max_health() < middle.max_health() and middle.max_health() < heavy.max_health(), "heavier armor protects more")
	_check(light.speed_factor() > middle.speed_factor() and middle.speed_factor() > heavy.speed_factor(), "heavier armor is slower")
	var sim := VillageSim.new(40, 40, 1, 1)
	light.cell = Vector2i(20, 20)
	heavy.cell = Vector2i(20, 20)
	_check(sim.walk_speed(light) > sim.walk_speed(heavy), "armor changes walking pace")
	_check(heavy.speed_factor() >= 1.0, "even the heaviest armor keeps pace with villagers")


func _test_hero_hunts_and_slays_without_water() -> void:
	var sim := _hero_ready_village()
	var hits := [0]
	sim.hero_attacked.connect(func(_hero: Hero) -> void: hits[0] += 1)
	var results := {"driven_off": false}
	sim.dragon_left.connect(func(driven_off: bool, _destroyed: int) -> void: results.driven_off = driven_off)
	_start_long_fight(sim, 60)
	var water := sim.water
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	_check(sim.dragon_state == VillageSim.DragonState.DEPARTING and results.driven_off, "the hero brought the dragon down")
	_check(hits[0] == 6, "a longsword takes 6 hits to wear down 60 resolve: %d" % hits[0])
	_check(sim.dragon_slain and sim.heroes[0].dragons_slain == 1, "the dragon counts as slain")
	_check(sim.water == water, "the hero doesn't use water")
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	_check(not sim.dragon_slain, "the next dragon starts out alive")


func _test_hero_holds_the_dragon_without_more_damage() -> void:
	var sim := _hero_ready_village()
	var before := sim.building_count()
	_run_dragon(sim, VillageSim.DragonState.INBOUND)
	sim.dragon_budget = 1
	sim.dragon_stay = 20
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	_check(sim.dragon_slain, "the dragon stays to be slain even after its one building")
	_check(before - sim.building_count() == 1, "and burns no more than its limit: %d" % (before - sim.building_count()))


func _test_longbow_stays_out_of_the_fire() -> void:
	var sim := _hero_ready_village(&"leather", &"longbow")
	_start_long_fight(sim, 100000)
	var shots := [0]
	sim.hero_attacked.connect(func(hero: Hero) -> void:
		shots[0] += 1
		_check(Vector2(hero.cell).distance_to(Vector2(sim.dragon_target)) <= 7.0, "arrows stay in range"))
	for i in range(30):
		sim.tick()
	_check(shots[0] > 15, "the archer keeps shooting: %d" % shots[0])
	_check(sim.heroes[0].health == sim.heroes[0].max_health(), "and is never burned: %d" % sim.heroes[0].health)


func _test_hero_is_wounded_and_recovers() -> void:
	var sim := _hero_ready_village(&"leather", &"battle_axe")
	var wounded := [0]
	sim.hero_wounded.connect(func(_hero: Hero) -> void: wounded[0] += 1)
	var results := {"driven_off": false}
	sim.dragon_left.connect(func(driven_off: bool, _destroyed: int) -> void: results.driven_off = driven_off)
	_start_long_fight(sim, 100000)
	for i in range(40):
		sim.tick()
		if sim.heroes[0].wounded:
			break
	_check(wounded[0] == 1 and sim.heroes[0].wounded and sim.heroes[0].health == 0, "dragon fire wounds a hero who stays close")
	var hits := [0]
	sim.hero_attacked.connect(func(_hero: Hero) -> void: hits[0] += 1)
	for i in range(8):
		sim.tick()
	_check(hits[0] == 0, "a wounded hero stops fighting")
	_check(Vector2(sim.heroes[0].cell).distance_to(Vector2(sim.dragon_target)) > VillageSim.DRAGON_FIRE_REACH, "and gets clear of the fire")
	sim.dragon_resolve = 0
	_run_dragon(sim, VillageSim.DragonState.WAITING)
	_check(results.driven_off and not sim.dragon_slain, "a dragon others drive off isn't the wounded hero's kill")
	for i in range(sim.heroes[0].max_health() / VillageSim.HERO_RECOVERY + 1):
		sim.tick()
	_check(not sim.heroes[0].wounded and sim.heroes[0].health == sim.heroes[0].max_health(), "the hero heals between dragons")


func _test_hero_saves_and_plays_on_identically() -> void:
	var sim := _hero_ready_village(&"dragonscale", &"battle_axe", &"raven")
	_start_long_fight(sim, 100000)
	for i in range(3):
		sim.tick()
	sim.heroes[0].dragons_slain = 4
	var loaded := VillageSim.from_save_data(JSON.parse_string(JSON.stringify(sim.to_save_data())))
	_check(loaded != null and loaded.heroes.size() == 1, "hero survives save and load")
	if loaded == null or loaded.heroes.is_empty():
		return
	_check(loaded.heroes[0].hero_name == "Aria" and loaded.heroes[0].armor == &"dragonscale", "name and armor are kept")
	_check(loaded.heroes[0].weapon == &"battle_axe" and loaded.heroes[0].look == &"raven", "weapon and look are kept")
	_check(loaded.heroes[0].dragons_slain == 4, "the tally is kept")
	for i in range(12):
		sim.tick()
		loaded.tick()
		_check(sim.heroes[0].cell == loaded.heroes[0].cell and sim.heroes[0].health == loaded.heroes[0].health, "loaded hero matches on tick %d" % i)
	_check(sim.dragon_resolve == loaded.dragon_resolve, "and the fight goes the same way")


func _test_older_saves_have_no_hero() -> void:
	var data := _village(20).to_save_data()
	data.version = 7
	for key: String in ["heroes", "dragon_slain"]:
		data.erase(key)
	var loaded := VillageSim.from_save_data(data)
	_check(loaded != null and loaded.heroes.is_empty(), "a save from before heroes loads without one")


func _test_single_hero_saves_still_load() -> void:
	var sim := _hero_ready_village(&"leather", &"longbow", &"frost")
	var data: Dictionary = sim.to_save_data().duplicate(true)
	data.version = 8
	data.hero = data.heroes[0]
	data.hero.erase("fought")
	data.dragon_hero_fought = true
	data.erase("heroes")
	var loaded := VillageSim.from_save_data(data)
	_check(loaded != null and loaded.heroes.size() == 1, "a one-hero save keeps its hero")
	if loaded != null and loaded.heroes.size() == 1:
		_check(loaded.heroes[0].hero_name == "Aria" and loaded.heroes[0].fought, "with their name and fight")
	data.hero = null
	var none := VillageSim.from_save_data(data)
	_check(none != null and none.heroes.is_empty(), "a version 8 save with no hero loads empty")
	data.hero = 12
	_check(VillageSim.from_save_data(data) == null, "a version 8 save with a bad hero is rejected")


func _test_rejects_bad_heroes() -> void:
	var sim := _hero_ready_village()
	var data := sim.to_save_data()
	for change: Array in [
		["armor", "tin"], ["weapon", 7], ["look", ""], ["name", ""], ["name", "<<<"], ["health", -1],
		["health", 9999], ["wounded", "no"], ["fought", "no"], ["dragons_slain", -2], ["cell", [-1, -1]], ["state", Villager.State.WORKING],
	]:
		var bad := data.duplicate(true)
		bad.heroes[0][change[0]] = change[1]
		_check(VillageSim.from_save_data(bad) == null, "rejects a hero with bad %s: %s" % [change[0], change[1]])
	var not_a_hero := data.duplicate(true)
	not_a_hero.heroes = [12]
	_check(VillageSim.from_save_data(not_a_hero) == null, "rejects a hero that isn't one")
	var missing := data.duplicate(true)
	missing.erase("dragon_slain")
	_check(VillageSim.from_save_data(missing) == null, "rejects a save missing the slain flag")


## A walkable cell well away from the village used by _hero_ready_village.
func _far_cell(sim: VillageSim) -> Vector2i:
	for y in range(39, -1, -1):
		for x in range(39, -1, -1):
			if sim.is_walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _test_teleport_only_to_walkable_ground() -> void:
	var sim := _hero_ready_village()
	var hero: Hero = sim.heroes[0]
	var start := hero.cell
	var water := Vector2i(-1, -1)
	for y in range(40):
		for x in range(40):
			if sim.terrain_at(Vector2i(x, y)) == VillageSim.Terrain.WATER:
				water = Vector2i(x, y)
	_check(not sim.teleport_hero(hero, water), "can't teleport onto water")
	_check(not sim.teleport_hero(hero, _first_building(sim)), "can't teleport onto a building")
	_check(not sim.teleport_hero(hero, Vector2i(99, 99)), "can't teleport off the map")
	_check(hero.cell == start, "refused teleports don't move the hero")
	var stranger := Hero.create("Zed", &"leather", &"longbow", &"frost")
	_check(not sim.teleport_hero(stranger, _far_cell(sim)), "only the village's own heroes teleport")
	for i in range(30):
		sim.tick()
		if hero.state == Villager.State.WALKING:
			break
	_check(hero.state == Villager.State.WALKING, "hero is out walking")
	var far := _far_cell(sim)
	_check(sim.teleport_hero(hero, far), "can teleport mid-walk")
	_check(hero.cell == far and hero.path.is_empty() and hero.state == Villager.State.OUTSIDE, "the trip is dropped")
	var loaded := VillageSim.from_save_data(JSON.parse_string(JSON.stringify(sim.to_save_data())))
	_check(loaded != null and loaded.heroes[0].cell == far, "a teleported hero saves and loads")


func _test_teleported_hero_holds_then_patrols() -> void:
	var sim := _hero_ready_village()
	var hero: Hero = sim.heroes[0]
	var far := _far_cell(sim)
	sim.teleport_hero(hero, far)
	for i in range(VillageSim.HERO_TELEPORT_HOLD - 1):
		sim.tick()
	_check(hero.cell == far, "the hero holds their new spot: %s" % hero.cell)
	for i in range(20):
		sim.tick()
	_check(hero.cell != far, "and later goes back on patrol")


func _test_teleported_hero_still_hunts() -> void:
	var sim := _hero_ready_village()
	var hero: Hero = sim.heroes[0]
	sim.teleport_hero(hero, _far_cell(sim))
	var hits := [0]
	sim.hero_attacked.connect(func(_hero: Hero) -> void: hits[0] += 1)
	_start_long_fight(sim, 100000)
	for i in range(45):
		sim.tick()
	_check(hits[0] > 0, "a dragon calls a teleported hero away from their post")


# --- Docks ---

## Grass west of column 24 and a lake from there east, with a house near the shore.
func _lake_sim(people := 0) -> VillageSim:
	var sim := VillageSim.new(40, 40, 1, 1)
	for y in range(sim.height):
		for x in range(sim.width):
			sim._terrain[y * sim.width + x] = VillageSim.Terrain.WATER if x >= 24 else VillageSim.Terrain.GRASS
	sim._rebuild_grid()
	sim.wood = 1000
	sim.food = 10000
	sim.water = 10000
	sim.place(&"house", Vector2i(20, 20))
	sim.population = people
	return sim


func _test_docks_placement_rules() -> void:
	var sim := _lake_sim()
	var shore := Vector2i(24, 20)
	_check(not sim.can_place(&"docks", Vector2i(22, 20)), "no docks on grass")
	_check(not sim.can_place(&"docks", Vector2i(30, 20)), "no docks out of reach of land")
	_check(not sim.can_place(&"farm", shore), "other buildings stay off the water")
	var wood := sim.wood
	_check(sim.place(&"docks", shore), "docks go on water beside land")
	_check(sim.wood == wood - VillageSim.BUILDINGS.docks.cost, "docks cost wood")
	_check(not sim.is_walkable(shore), "nobody walks onto the docks")
	_check(not sim.place_bridge(shore), "no bridge on the docks")
	_check(sim.place_bridge(Vector2i(24, 10)) and not sim.place(&"docks", Vector2i(24, 10)), "no docks on a bridge")
	_check(sim.place(&"docks", Vector2i(25, 10)), "a bridge counts as ground to reach docks from")
	sim.wood = VillageSim.BUILDINGS.docks.cost - 1
	_check(not sim.can_place(&"docks", Vector2i(24, 30)), "no docks without wood")
	_check(sim.demolish(shore) and sim.terrain_at(shore) == VillageSim.Terrain.WATER, "demolished docks leave water")


## Food only comes ashore at the end of a shift, and matches what was caught.
func _test_docks_fish_for_food() -> void:
	var sim := _lake_sim(2)
	var dock := Vector2i(24, 20)
	sim.place(&"docks", dock)
	sim.tick()
	_check(sim.workers_at(dock) == 2, "docks take workers: %d" % sim.workers_at(dock))
	var landings := 0
	var fishing_ticks := 0
	for i in range(300):
		var food := sim.food
		var fish_before: Array[int] = []
		var working_before: Array[bool] = []
		for villager in sim.villagers:
			fish_before.append(villager.fish)
			working_before.append(villager.state == Villager.State.WORKING)
			if sim.is_fishing(villager):
				fishing_ticks += 1
		sim.tick()
		var eaten := sim.population if sim.tick_count % VillageSim.MEAL_INTERVAL == 0 else 0
		var expected := 0
		# New villagers move in as the house fills; they start at home.
		for index in range(fish_before.size()):
			var villager := sim.villagers[index]
			if working_before[index] and villager.state != Villager.State.WORKING:
				expected += (fish_before[index] + VillageSim.FISH_PER_FOOD / 2) / VillageSim.FISH_PER_FOOD
				landings += 1
			elif villager.fish > fish_before[index]:
				_check(villager.state == Villager.State.WORKING, "only people at work catch fish")
		_check(sim.food - food + eaten == expected, "food is the catch brought ashore, tick %d" % sim.tick_count)
	_check(landings >= 10, "catches come ashore: %d" % landings)
	_check(fishing_ticks > 100, "people spend time fishing: %d" % fishing_ticks)
	_check(sim.fish_per_tick(dock) == VillageSim.FISH_BASE_CATCH + 8, "open water out from the shore is richest")


func _test_boats_stay_on_water() -> void:
	var sim := _lake_sim()
	var dock := Vector2i(24, 20)
	sim.place(&"docks", dock)
	var route := sim.fishing_route(dock)
	_check(route[0] == dock and route.size() == VillageSim.FISHING_RANGE + 1, "the boat rows out as far as it may: %s" % [route])
	for index in range(1, route.size()):
		_check(sim.is_boatable(route[index]), "the route is open water: %s" % route[index])
		var step := route[index] - route[index - 1]
		_check(absi(step.x) + absi(step.y) == 1, "the route has no jumps")
	# A pond of two cells: the boat can't go anywhere else.
	var pond := _lake_sim()
	for y in range(pond.height):
		for x in range(24, pond.width):
			pond._terrain[y * pond.width + x] = VillageSim.Terrain.GRASS
	pond._terrain[20 * pond.width + 24] = VillageSim.Terrain.WATER
	pond._terrain[20 * pond.width + 25] = VillageSim.Terrain.WATER
	pond._rebuild_grid()
	var pond_dock := Vector2i(24, 20)
	pond.place(&"docks", pond_dock)
	_check(pond.fishing_route(pond_dock) == ([pond_dock, Vector2i(25, 20)] as Array[Vector2i]), "a pond's boat stays in the pond")
	_check(pond.fish_per_tick(pond_dock) == VillageSim.FISH_BASE_CATCH, "a pond has few fish")
	pond.place_bridge(Vector2i(25, 20))
	_check(pond.fishing_route(pond_dock) == ([pond_dock] as Array[Vector2i]), "boats don't go under bridges")


## Food made by one workplace on the shore with two workers, over a long time.
func _food_made(type: StringName) -> int:
	var sim := _lake_sim(2)
	# Both doors are on the same shore cell, so the walk to work is the same.
	sim.place(type, Vector2i(24, 20) if type == &"docks" else Vector2i(23, 19))
	var made := 0
	for i in range(2000):
		var food := sim.food
		sim.tick()
		made += sim.food - food + (sim.population if sim.tick_count % VillageSim.MEAL_INTERVAL == 0 else 0)
	return made


func _test_docks_rival_farms() -> void:
	var farm := _food_made(&"farm")
	var docks := _food_made(&"docks")
	var ratio := float(docks) / farm
	_check(ratio > 0.9 and ratio < 1.2, "docks make about as much food as a farm: %d vs %d" % [docks, farm])


func _test_cut_short_shift_loses_the_catch() -> void:
	var sim := _lake_sim(1)
	var dock := Vector2i(24, 20)
	sim.place(&"docks", dock)
	for i in range(100):
		sim.tick()
		if sim.villagers[0].fish > 0:
			break
	var villager := sim.villagers[0]
	_check(villager.fish > 0, "the villager goes fishing")
	var food := sim.food
	sim.demolish(dock)
	sim.tick()
	_check(villager.fish == 0 and villager.state != Villager.State.WORKING, "losing the docks loses the catch")
	_check(sim.food <= food, "and no food comes ashore")


func _test_docks_save_and_play_on_identically() -> void:
	var sim := _lake_sim(4)
	sim.place(&"house", Vector2i(20, 22))
	sim.place(&"docks", Vector2i(24, 20))
	sim.place(&"docks", Vector2i(24, 24))
	var saw_fish := false
	for round_index in range(6):
		for i in range(9):
			sim.tick()
		for villager in sim.villagers:
			saw_fish = saw_fish or villager.fish > 0
		var loaded := VillageSim.from_save_data(JSON.parse_string(JSON.stringify(sim.to_save_data())))
		_check(loaded != null, "docks and boats load back")
		if loaded == null:
			return
		var original := VillageSim.from_save_data(sim.to_save_data())
		for i in range(30):
			original.tick()
			loaded.tick()
		_check(loaded.to_save_data() == original.to_save_data(), "a loaded fishing village plays on identically")
	_check(saw_fish, "the test saved while someone had fish in the boat")


func _test_older_saves_reject_docks() -> void:
	var sim := _lake_sim(2)
	sim.place(&"docks", Vector2i(24, 20))
	var data := sim.to_save_data()
	data.version = VillageSim.FIRST_DOCKS_VERSION - 1
	_check(VillageSim.from_save_data(data) == null, "a save from before docks can't have any")
	var old := _village(5).to_save_data()
	old.version = VillageSim.FIRST_DOCKS_VERSION - 1
	for entry: Dictionary in old.villagers:
		entry.erase("fish")
		entry.erase("shift_ticks")
	_check(VillageSim.from_save_data(old) != null, "a version 9 save without catches still loads")
	var wet := sim.to_save_data()
	wet.buildings.append({"x": 30, "y": 5, "type": "farm"})
	_check(VillageSim.from_save_data(wet) == null, "rejects a farm on water")
	var dry := sim.to_save_data()
	dry.buildings.append({"x": 5, "y": 5, "type": "docks"})
	_check(VillageSim.from_save_data(dry) == null, "rejects docks on grass")


func _test_dragon_burns_docks_but_not_water() -> void:
	var sim := _lake_sim()
	var dock := Vector2i(24, 20)
	sim.place(&"docks", dock)
	for cell in sim._burn_around([dock] as Array[Vector2i], 2):
		_check(sim.terrain_at(cell) == VillageSim.Terrain.GRASS, "only grass is scorched: %s" % cell)
	_check(not sim.is_scorched(Vector2i(25, 20)), "the lake isn't scorched")
	_check(sim.is_scorched(Vector2i(23, 20)), "the shore is")
	for i in range(VillageSim.DRAGON_MIN_BUILDINGS):
		sim.place(&"house", Vector2i(2 + i * 2, 2))
	sim.dragon_target = dock
	sim.dragon_budget = 1
	sim.dragon_stay = VillageSim.DRAGON_FIRST_STRIKE_TICK
	sim.dragon_rampage_ticks = VillageSim.DRAGON_FIRST_STRIKE_TICK
	sim.dragon_state = VillageSim.DragonState.RAMPAGE
	sim._dragon_strike()
	_check(sim.building_at(dock) == &"", "a dragon can destroy docks")
	_check(sim.terrain_at(dock) == VillageSim.Terrain.WATER and not sim.is_scorched(dock), "leaving unburned water")


# --- Happiness ---

## Houses spaced out with walkable ground between, then any other buildings asked for.
func _happiness_village(houses: int, others: Dictionary = {}) -> VillageSim:
	var sim := VillageSim.new(40, 40, 1, 1)
	sim.wood = 100000
	var free: Array[Vector2i] = []
	for y in range(12, 29, 2):
		for x in range(12, 29, 2):
			free.append(Vector2i(x, y))
	var wanted: Array[StringName] = []
	for i in range(houses):
		wanted.append(&"house")
	for type: StringName in others:
		for i in range(others[type]):
			wanted.append(type)
	for type in wanted:
		while not sim.place(type, free.pop_front()):
			pass
	return sim


func _test_happiness_factor_table() -> void:
	var sim := VillageSim.new()
	var ids: Array[StringName] = []
	for factor in Happiness.FACTORS:
		_check(sim.happiness.has_method("_score_%s" % factor.id), "factor %s has a score method" % factor.id)
		_check(factor.weight > 0.0 and factor.label is String, "factor %s has a weight and label" % factor.id)
		ids.append(factor.id)
	_check(sim.happiness_factors().keys() == ids, "every factor is scored, in order")
	_check(&"entertainment" in ids, "there's an entertainment hook")
	_check(sim.happiness_factors()[&"entertainment"] == Happiness.NEUTRAL_SCORE, "entertainment is neutral for now")
	_check(sim.happiness.value == Happiness.START_VALUE, "a new village starts in between")


func _test_happiness_supplies() -> void:
	var sim := _happiness_village(2)
	sim.population = 8
	sim.food = 0
	sim.water = 0
	var scores := sim.happiness_factors()
	_check(scores[&"food"] == 0.0 and scores[&"water"] == 0.0, "nothing in store and nobody making it")
	sim.food = 8 * int(Happiness.SUPPLY_COMFORT_TICKS) / VillageSim.MEAL_INTERVAL
	sim.water = sim.food / 2
	scores = sim.happiness_factors()
	_check(is_equal_approx(scores[&"food"], 1.0), "a big enough stock is plenty: %f" % scores[&"food"])
	_check(is_equal_approx(scores[&"water"], 0.5), "half that is half as good: %f" % scores[&"water"])

	var farming := _happiness_village(2, {&"farm": 4})
	farming.population = 8
	var best := 0.0
	for i in range(40):
		farming.food = 0
		farming.tick()
		best = maxf(best, farming.happiness_factors()[&"food"])
	_check(best >= 1.0, "making more than is eaten feels secure even with an empty store: %f" % best)


func _test_happiness_jobs() -> void:
	var idle := _happiness_village(2)
	idle.population = 8
	_check(idle.happiness_factors()[&"jobs"] == 0.0, "nobody employed")
	var half := _happiness_village(2, {&"farm": 2})
	half.population = 8
	_check(is_equal_approx(half.happiness_factors()[&"jobs"], 0.5), "half employed: %f" % half.happiness_factors()[&"jobs"])
	var full := _happiness_village(2, {&"farm": 2, &"well": 2})
	full.population = 8
	_check(full.happiness_factors()[&"jobs"] == 1.0, "everyone employed")
	_check(VillageSim.new().happiness_factors()[&"jobs"] == 1.0, "nobody to employ is fine")


func _test_happiness_housing() -> void:
	var sim := _happiness_village(5)
	_check(sim.happiness_factors()[&"housing"] == 1.0, "empty houses are roomy")
	sim.population = 16
	_check(sim.happiness_factors()[&"housing"] == 1.0, "80 in 100 full is still comfortable")
	sim.population = 20
	_check(is_equal_approx(sim.happiness_factors()[&"housing"], Happiness.CROWDED_SCORE), "full houses are crowded")
	sim.population = 18
	var between: float = sim.happiness_factors()[&"housing"]
	_check(between > Happiness.CROWDED_SCORE and between < 1.0, "crowding grows as houses fill: %f" % between)


func _test_happiness_defense() -> void:
	var small := _happiness_village(VillageSim.DRAGON_MIN_BUILDINGS - 1)
	_check(small.happiness_factors()[&"defense"] == 1.0, "too small to draw a dragon")
	var open := _happiness_village(12)
	_check(open.happiness_factors()[&"defense"] == 0.0, "a big village with no defenses worries")
	var towered := _happiness_village(11, {&"tower": 1})
	_check(towered.happiness_factors()[&"defense"] == 1.0, "a tower guards a dozen buildings")
	var stretched := _happiness_village(23, {&"tower": 1})
	var partly: float = stretched.happiness_factors()[&"defense"]
	_check(partly > 0.5 and partly < 1.0, "one tower isn't enough for twice the village: %f" % partly)
	stretched.population = 4
	stretched.tick()
	stretched.villagers[0].training = VillageSim.TRAINING_TICKS
	stretched.villagers[1].training = VillageSim.TRAINING_TICKS
	_check(stretched.happiness_factors()[&"defense"] > partly, "trained fighters help")
	var heroic := _happiness_village(23, {&"tower": 1})
	heroic.heroes.append(Hero.create("Aria", &"chainmail", &"longsword", &"ember"))
	_check(heroic.happiness_factors()[&"defense"] == 1.0, "a hero helps a lot")


func _test_happiness_fears_dragon_damage() -> void:
	var sim := _village(30, 3)
	_check(sim.happiness_factors()[&"safety"] == 1.0, "no dragon damage yet")
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	_check(sim.dragon_destroyed > 0, "the dragon destroyed something")
	var scared: float = sim.happiness_factors()[&"safety"]
	_check(scared < 1.0, "losses scare people: %f" % scared)
	for i in range(30):
		sim.tick()
	_check(sim.happiness_factors()[&"safety"] > scared, "the fear fades")
	sim.happiness.dragon_destroyed(100)
	_check(sim.happiness_factors()[&"safety"] == 0.0, "fear has a limit")
	for i in range(Happiness.MAX_FEAR_TICKS):
		sim.happiness.update(sim)
	_check(sim.happiness_factors()[&"safety"] == 1.0, "and wears off completely")


func _test_happiness_roads() -> void:
	var sim := _happiness_village(2)
	_check(sim.happiness_factors()[&"roads"] == 0.0, "no roads to the houses")
	sim.place_road(sim.houses()[0] + Vector2i.DOWN)
	_check(sim.happiness_factors()[&"roads"] == 0.5, "one of two houses on a road")


func _test_happiness_range_and_weights() -> void:
	var thriving := _happiness_village(5, {&"farm": 2, &"well": 2})
	thriving.population = 8
	thriving.food = 10000
	thriving.water = 10000
	for house in thriving.houses():
		thriving.place_road(house + Vector2i.DOWN)
	var scores := thriving.happiness_factors()
	var weighted := 0.0
	var weights := 0.0
	for factor in Happiness.FACTORS:
		weighted += factor.weight * scores[factor.id]
		weights += factor.weight
	var best := thriving.happiness.target(thriving)
	_check(is_equal_approx(best, 100.0 * weighted / weights), "the target is the weighted mix")
	_check(Happiness.level_of(best) == Happiness.Level.DELIGHTED and best <= 100.0, "a thriving village is delighted: %f" % best)

	var wretched := _happiness_village(VillageSim.DRAGON_MIN_BUILDINGS + 3)
	wretched.population = wretched.housing()
	wretched.food = 0
	wretched.water = 0
	wretched.happiness.dragon_destroyed(100)
	var worst := wretched.happiness.target(wretched)
	_check(worst >= 0.0 and Happiness.level_of(worst) == Happiness.Level.MISERABLE, "a starving, jobless, scared village is miserable: %f" % worst)
	var hungry := _happiness_village(2, {&"farm": 2, &"well": 2})
	hungry.population = 8
	hungry.food = 0
	hungry.water = 10000
	_check(Happiness.level_of(hungry.happiness.target(hungry)) <= Happiness.Level.OKAY, "running out of food alone is enough to stop being happy")
	wretched.happiness.value = 0.0
	var in_range := true
	for i in range(1000):
		wretched.tick()
		in_range = in_range and wretched.happiness.value >= 0.0 and wretched.happiness.value <= 100.0
	_check(in_range, "happiness stays in range")
	_check(Happiness.level_of(0.0) == Happiness.Level.MISERABLE, "0 is miserable")
	_check(Happiness.level_of(25.0) == Happiness.Level.UNHAPPY, "25 is unhappy")
	_check(Happiness.level_of(44.9) == Happiness.Level.UNHAPPY, "44.9 is unhappy")
	_check(Happiness.level_of(45.0) == Happiness.Level.OKAY, "45 is okay")
	_check(Happiness.level_of(87.9) == Happiness.Level.HAPPY, "87.9 is happy")
	_check(Happiness.level_of(100.0) == Happiness.Level.DELIGHTED, "100 is delighted")


func _test_happiness_moves_gradually() -> void:
	var villages: Array[VillageSim] = []
	for i in range(2):
		var sim := _happiness_village(2)
		sim.population = 8
		sim.food = 0
		sim.water = 0
		sim.happiness.value = 100.0
		villages.append(sim)
	var a := villages[0]
	a.tick()
	_check(a.happiness.value < 100.0 and a.happiness.value > 97.0, "one tick moves it only a little: %f" % a.happiness.value)
	for i in range(299):
		a.tick()
	for i in range(300):
		villages[1].tick()
	_check(absf(a.happiness.value - a.happiness.target(a)) < 2.0, "it settles near the target: %f" % a.happiness.value)
	_check(a.happiness.value < 40.0, "a hungry, jobless village ends up unhappy: %f" % a.happiness.value)
	_check(a.happiness.value == villages[1].happiness.value, "the same village gets the same happiness")


## Runs a village with happiness held at this value, returning how many people came.
func _growth_at(happiness: float, ticks: int) -> int:
	var sim := _happiness_village(10, {&"farm": 3, &"well": 3})
	sim.population = 4
	for i in range(ticks):
		sim.food = 10000
		sim.water = 10000
		sim.happiness.value = happiness
		sim.tick()
	return sim.population - 4


func _test_happiness_changes_growth() -> void:
	var ticks := VillageSim.POPULATION_INTERVAL * 20
	_check(_growth_at(55.0, ticks) == 20, "an okay village grows as before")
	_check(_growth_at(35.0, ticks) == 10, "an unhappy village grows half as fast")
	_check(_growth_at(78.0, ticks) == 25, "a happy village grows a quarter faster")
	_check(_growth_at(100.0, ticks) == 30, "a delighted village grows half again as fast")
	_check(_growth_at(0.0, ticks) == 0, "nobody joins a miserable village, and the founders stay")

	var leaving := _happiness_village(10, {&"farm": 3, &"well": 3})
	leaving.population = 20
	for i in range(VillageSim.POPULATION_INTERVAL * Happiness.MISERABLE_LEAVER_EVERY * 4):
		leaving.food = 10000
		leaving.water = 10000
		leaving.happiness.value = 0.0
		leaving.tick()
	_check(leaving.population == 16, "people slowly leave a miserable village: %d" % leaving.population)
	for i in range(VillageSim.POPULATION_INTERVAL * 200):
		leaving.happiness.value = 0.0
		leaving.tick()
	_check(leaving.population == VillageSim.FOUNDERS, "but the founders always stay: %d" % leaving.population)


func _test_happiness_survives_save_and_load() -> void:
	var sim := _village(30, 3)
	sim.population = 20
	_run_dragon(sim, VillageSim.DragonState.DEPARTING)
	for i in range(7):
		sim.tick()
	_check(sim.happiness.dragon_fear > 0 and sim.happiness.value != Happiness.START_VALUE, "happiness has moved")
	var data := sim.to_save_data()
	_check(data.version == 12, "saves are version 12")
	var loaded := VillageSim.from_save_data(JSON.parse_string(JSON.stringify(data)))
	_check(loaded != null, "a game with happiness loads")
	if loaded == null:
		return
	_check(loaded.happiness.value == sim.happiness.value, "happiness loads exactly")
	_check(loaded.happiness.dragon_fear == sim.happiness.dragon_fear, "fear loads")
	for i in range(50):
		sim.tick()
		loaded.tick()
	_check(loaded.happiness.value == sim.happiness.value and loaded.population == sim.population, "and plays on identically")

	for bad: Variant in [-1, 100001, 1.5, "50", null]:
		var broken := sim.to_save_data()
		broken.happiness = bad
		_check(VillageSim.from_save_data(broken) == null, "rejects happiness %s" % bad)
	var scared := sim.to_save_data()
	scared.dragon_fear = Happiness.MAX_FEAR_TICKS + 1
	_check(VillageSim.from_save_data(scared) == null, "rejects too much fear")


func _test_older_saves_get_happiness() -> void:
	var sim := _happiness_village(2)
	sim.population = 8
	sim.food = 0
	var data := sim.to_save_data()
	data.version = 9
	data.erase("happiness")
	data.erase("dragon_fear")
	var loaded := VillageSim.from_save_data(data)
	_check(loaded != null, "a version 9 save loads")
	if loaded != null:
		var gap := absf(loaded.happiness.value - loaded.happiness.target(loaded))
		_check(gap <= 0.5 / Happiness.STEPS_PER_POINT, "it starts as happy as it should be: %f" % gap)
		_check(loaded.happiness.value < Happiness.START_VALUE, "a hungry, jobless village starts unhappy: %f" % loaded.happiness.value)
		_check(loaded.happiness.dragon_fear == 0, "with no fear")


# --- Playgrounds ---

const PLAYGROUND := Vector2i(24, 20)


func _test_building_attractions() -> void:
	var sim := VillageSim.new(40, 40, 1, 1)
	sim.wood = 100
	sim.water = 0
	_check(not sim.build_attraction(PLAYGROUND, &"darts"), "no attractions without an entrance")
	_check(sim.place(&"playground", PLAYGROUND), "a playground entrance goes on grass")
	_check(sim.wood == 75, "the entrance costs 25 wood")
	_check(sim.total_jobs() == 0 and sim.workplaces().is_empty(), "an empty playground has no jobs")
	_check(sim.build_attraction(PLAYGROUND, &"darts"), "darts can be built")
	_check(sim.wood == 55, "darts cost 20 wood: %d" % sim.wood)
	_check(not sim.can_build_attraction(PLAYGROUND, &"darts"), "only one darts per entrance")
	_check(not sim.build_attraction(PLAYGROUND, &"darts") and sim.wood == 55, "a second darts costs nothing")
	_check(not sim.build_attraction(PLAYGROUND, &"roller_coaster"), "a roller coaster costs too much")
	_check(not sim.build_attraction(PLAYGROUND, &"rocket"), "unknown attractions can't be built")
	sim.wood = 1000
	_check(not sim.build_attraction(PLAYGROUND, &"water_slide"), "a water slide also needs water")
	sim.water = 60
	_check(sim.build_attraction(PLAYGROUND, &"water_slide"), "a water slide with water")
	_check(sim.wood == 880 and sim.water == 0, "it costs 120 wood and 60 water")
	var built: Array[StringName] = [&"darts", &"water_slide"]
	_check(sim.attractions_at(PLAYGROUND) == built, "attractions are listed in build order")
	_check(sim.attraction_count() == 2, "two attractions")
	_check(sim.total_jobs() == 4, "staff are jobs: %d" % sim.total_jobs())
	var playgrounds: Array[Vector2i] = [PLAYGROUND]
	_check(sim.workplaces() == playgrounds, "a staffed playground is a workplace")
	var previous_price := 0
	for type: StringName in VillageSim.ATTRACTIONS:
		var price: int = VillageSim.ATTRACTIONS[type].cost.wood
		_check(price > previous_price, "attractions are listed cheapest first")
		previous_price = price


const FUN_HOUSES: Array[Vector2i] = [Vector2i(20, 20), Vector2i(20, 22), Vector2i(18, 20), Vector2i(18, 22)]


## Just enough houses for these people (up to 16, so a multiple of 4 stays put),
## a farm and a well, and a playground with these attractions.
func _fun_village(attractions: Array, people: int) -> VillageSim:
	var placements := {Vector2i(22, 18): &"farm", Vector2i(22, 24): &"well", PLAYGROUND: &"playground"}
	for index in range(ceili(people / 4.0)):
		placements[FUN_HOUSES[index]] = &"house"
	var sim := _settled(placements, people)
	sim.wood = 100000
	sim.water = 100000
	for type: StringName in attractions:
		_check(sim.build_attraction(PLAYGROUND, type), "built %s" % type)
	return sim


func _test_staff_run_attractions() -> void:
	var sim := _fun_village([&"darts", &"arcade"], 8)
	sim.tick()
	_check(sim.workers_at(PLAYGROUND) == 2, "both attractions get staff: %d" % sim.workers_at(PLAYGROUND))
	var saw_inside := false
	var saw_running := false
	for i in range(120):
		var inside := 0
		for villager in sim.villagers:
			if villager.job == PLAYGROUND and villager.state == Villager.State.WORKING:
				inside += 1
		var staff := sim.attraction_staff(PLAYGROUND)
		_check(staff[&"darts"].x == 1 and staff[&"arcade"].x == 1, "each attraction has its staff hired")
		_check(staff[&"darts"].y + staff[&"arcade"].y == inside, "only staff inside run attractions")
		saw_inside = saw_inside or inside > 0
		saw_running = saw_running or sim.entertainment() > 0.0
		sim.tick()
	_check(saw_inside and saw_running, "staff go underground and the attractions run")
	_check(sim.entertainment() > 0.0 and sim.entertainment() <= 1.0, "entertainment is 0..1: %f" % sim.entertainment())


func _test_entertainment_value() -> void:
	var nobody := _fun_village([&"darts"], 0)
	for i in range(30):
		nobody.tick()
	_check(nobody.entertainment() == 0.0, "nobody to entertain is no entertainment")

	var unstaffed := _fun_village([], 8)
	for i in range(60):
		unstaffed.tick()
	_check(unstaffed.entertainment() == 0.0, "no attractions means no entertainment")

	# With their staff all inside, darts and arcade have room for 16 guests.
	var sim := _fun_village([&"darts", &"arcade"], 8)
	sim.tick()
	for villager in sim.villagers:
		if villager.job == PLAYGROUND:
			villager.state = Villager.State.WORKING
	_check(sim._entertainment_room() == VillageSim.ENTERTAINMENT_SCALE * 16, "room for 16 guests")
	for i in range(80):
		for villager in sim.villagers:
			if villager.job == PLAYGROUND:
				villager.state = Villager.State.WORKING
				villager.timer = 100
		sim.tick()
	_check(sim.entertainment() == 1.0, "16 guests is everyone of 8: %f" % sim.entertainment())
	sim.population = 32
	for i in range(80):
		sim.population = 32
		for villager in sim.villagers:
			if villager.job == PLAYGROUND:
				villager.state = Villager.State.WORKING
				villager.timer = 100
		sim.tick()
	_check(sim.entertainment() == 0.5, "16 guests is half of 32: %f" % sim.entertainment())

	# Over time a bigger playground entertains more.
	var small := _fun_village([&"darts"], 16)
	var big := _fun_village([&"darts", &"arcade", &"mini_golf", &"bowling_alley"], 16)
	var small_total := 0.0
	var big_total := 0.0
	for i in range(200):
		small.tick()
		big.tick()
		small_total += small.entertainment()
		big_total += big.entertainment()
	_check(big_total > small_total * 2.0, "more attractions entertain more: %f vs %f" % [big_total, small_total])
	_check(big.entertainment() <= 1.0, "entertainment never passes 1")


func _test_fun_jobs_come_after_food_and_water() -> void:
	# A farm and a well have 4 jobs. With 4 people nobody staffs the darts.
	var sim := _fun_village([&"darts"], 4)
	for i in range(20):
		sim.tick()
	_check(sim.workers_at(PLAYGROUND) == 0, "food and water come before fun")
	_check(sim.workers_at(Vector2i(22, 18)) == 2 and sim.workers_at(Vector2i(22, 24)) == 2, "the farm and well are full")
	sim.place(&"house", FUN_HOUSES[1])
	sim.population = 5
	sim.tick()
	_check(sim.workers_at(PLAYGROUND) == 1, "a spare villager staffs the darts")

	# Staff already at the playground leave for a new farm.
	var busy := _fun_village([&"darts", &"arcade", &"mini_golf"], 8)
	for i in range(30):
		busy.tick()
	_check(busy.workers_at(PLAYGROUND) == 4, "4 spare people staff the attractions: %d" % busy.workers_at(PLAYGROUND))
	busy.place(&"farm", Vector2i(16, 20))
	busy.tick()
	_check(busy.workers_at(Vector2i(16, 20)) == 2, "the new farm takes staff from fun: %d" % busy.workers_at(Vector2i(16, 20)))
	_check(busy.workers_at(PLAYGROUND) == 2, "the playground keeps who's left: %d" % busy.workers_at(PLAYGROUND))
	# Balancing never moves farmers or well workers into the playground.
	for i in range(100):
		busy.tick()
		_check(busy.filled_jobs() - busy.workers_at(PLAYGROUND) == 6, "needed jobs stay filled")


## Has the dragon strike this cell, with enough budget to burn just it.
func _dragon_burns(sim: VillageSim, cell: Vector2i) -> void:
	sim.dragon_state = VillageSim.DragonState.RAMPAGE
	sim.dragon_target = cell
	sim.dragon_stay = 10
	sim.dragon_rampage_ticks = VillageSim.DRAGON_FIRST_STRIKE_TICK
	sim.dragon_budget = 1
	sim.dragon_destroyed = 0
	sim._dragon_strike()


func _test_dragon_buries_attractions() -> void:
	var sim := _fun_village([&"darts", &"bowling_alley"], 12)
	for x in range(26, 32):
		sim.place(&"tower", Vector2i(x, 26))
	for i in range(20):
		sim.tick()
	_check(sim.workers_at(PLAYGROUND) > 0, "the playground is staffed")
	_dragon_burns(sim, PLAYGROUND)
	_check(sim.building_at(PLAYGROUND) == &"", "the dragon burns the entrance")
	sim.tick()
	_check(sim.workers_at(PLAYGROUND) == 0 and sim.attraction_count() == 0, "nothing runs without an entrance")
	_check(sim.has_buried_attractions(PLAYGROUND), "the attractions wait underground")
	_check(not sim.can_place(&"house", PLAYGROUND), "only a playground can be built over them")
	var built: Array[StringName] = [&"darts", &"bowling_alley"]
	_check(sim.place(&"playground", PLAYGROUND), "the entrance can be rebuilt")
	_check(sim.attractions_at(PLAYGROUND) == built and not sim.has_buried_attractions(PLAYGROUND), "and reopens them")
	sim.tick()
	_check(sim.workers_at(PLAYGROUND) > 0, "staff come back")

	_dragon_burns(sim, PLAYGROUND)
	var wood := sim.wood
	_check(sim.demolish(PLAYGROUND), "the ruin can be filled in")
	_check(sim.wood == wood + 10 + 45, "filling in refunds half the attractions: %d" % (sim.wood - wood))
	_check(not sim.has_buried_attractions(PLAYGROUND) and sim.can_place(&"house", PLAYGROUND), "and frees the cell")
	_check(not sim.demolish(PLAYGROUND), "nothing more to fill in")


func _test_demolishing_a_playground() -> void:
	var sim := _fun_village([&"arcade", &"water_slide"], 8)
	var wood := sim.wood
	var water := sim.water
	_check(sim.demolish(PLAYGROUND), "a playground can be demolished")
	_check(sim.wood == wood + 12 + 20 + 60, "half of the entrance and attractions back: %d" % (sim.wood - wood))
	_check(sim.water == water + 30, "and half the water slide's water")
	_check(sim.attractions_at(PLAYGROUND).is_empty() and not sim.has_buried_attractions(PLAYGROUND), "the attractions are gone")
	sim.place(&"playground", PLAYGROUND)
	_check(sim.attractions_at(PLAYGROUND).is_empty(), "a new entrance starts empty")


func _test_playgrounds_save_and_load() -> void:
	var sim := _fun_village([&"darts", &"arcade", &"roller_coaster"], 16)
	sim.place(&"playground", Vector2i(26, 22))
	sim.build_attraction(Vector2i(26, 22), &"mini_golf")
	for x in range(26, 32):
		sim.place(&"tower", Vector2i(x, 26))
	for i in range(37):
		sim.tick()
	_dragon_burns(sim, Vector2i(26, 22))
	sim.dragon_state = VillageSim.DragonState.WAITING
	_check(sim.entertainment() > 0.0, "the village is entertained before saving")
	SaveGame.write(sim, TEST_SAVE)
	var loaded := SaveGame.read(TEST_SAVE)
	_check(loaded != null, "a game with playgrounds loads")
	if loaded == null:
		return
	_check(loaded.to_save_data() == sim.to_save_data(), "the loaded playgrounds match")
	_check(loaded.entertainment() == sim.entertainment(), "entertainment is kept")
	_check(loaded.has_buried_attractions(Vector2i(26, 22)), "buried attractions are kept")
	for i in range(40):
		sim.tick()
		loaded.tick()
	_check(loaded.to_save_data() == sim.to_save_data(), "and plays on identically")

	var good := sim.to_save_data()
	for change: Array in [
		["types", ["rocket"]], ["types", ["darts", "darts"]], ["types", []], ["types", "darts"],
		["x", 99], ["x", 20],
	]:
		var bad: Dictionary = good.duplicate(true)
		bad.attractions[0][change[0]] = change[1]
		_check(VillageSim.from_save_data(bad) == null, "rejects attraction %s = %s" % change)
	for value: Variant in [-1, 1001, "lots", null]:
		var bad: Dictionary = good.duplicate(true)
		bad.entertainment = value
		_check(VillageSim.from_save_data(bad) == null, "rejects entertainment %s" % value)
	var missing: Dictionary = good.duplicate(true)
	missing.erase("attractions")
	_check(VillageSim.from_save_data(missing) == null, "a version 11 save needs its attractions")


func _test_older_saves_have_no_playgrounds() -> void:
	var data := _settled({Vector2i(20, 20): &"house", Vector2i(24, 20): &"farm"}, 3).to_save_data()
	for version in [9, 10]:
		var old: Dictionary = data.duplicate(true)
		old.version = version
		old.erase("attractions")
		old.erase("entertainment")
		var loaded := VillageSim.from_save_data(old)
		_check(loaded != null, "a version %d save loads" % version)
		if loaded != null:
			_check(loaded.attraction_count() == 0 and loaded.entertainment() == 0.0, "with no attractions")
