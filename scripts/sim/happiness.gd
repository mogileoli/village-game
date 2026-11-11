class_name Happiness
extends RefCounted
## How content the villagers are, from 0 to 100. The target is a weighted mix of
## separate factors, each scored from 0 (awful) to 1 (couldn't be better), and
## the value drifts toward it a little each tick instead of jumping.
##
## To add a factor: add a row to FACTORS and a `_score_<id>(sim) -> float`
## method that returns 0..1. Weights are relative, so they needn't add up to 1.

enum Level { MISERABLE, UNHAPPY, OKAY, HAPPY, DELIGHTED }

## In the order the breakdown shows them.
const FACTORS: Array[Dictionary] = [
	{"id": &"food", "label": "Food", "weight": 0.23},
	{"id": &"water", "label": "Water", "weight": 0.23},
	{"id": &"jobs", "label": "Jobs", "weight": 0.18},
	{"id": &"housing", "label": "Homes", "weight": 0.10},
	{"id": &"defense", "label": "Defense", "weight": 0.07},
	{"id": &"safety", "label": "Safety", "weight": 0.07},
	{"id": &"roads", "label": "Roads", "weight": 0.04},
	{"id": &"entertainment", "label": "Fun", "weight": 0.08},
]
const LEVEL_NAMES: Array[String] = ["Miserable", "Unhappy", "Okay", "Happy", "Delighted"]
## The lowest value of each level after MISERABLE. A village short of food
## alone, with everything else fine, should still be only Okay.
const LEVEL_THRESHOLDS: Array[float] = [25.0, 45.0, 70.0, 88.0]
const MAX_VALUE := 100.0
const START_VALUE := 50.0
## Share of the gap to the target closed each tick, so big changes take a minute or two.
const SMOOTHING := 0.02
## The value is kept to this many steps per point, so it saves and loads exactly.
const STEPS_PER_POINT := 1000.0

## Food or water lasting this many ticks at the current population is plenty.
const SUPPLY_COMFORT_TICKS := 60.0
## Making this many times what's eaten or drunk is plenty too.
const SUPPLY_COMFORT_SURPLUS := 1.5
## Houses fuller than this start to feel crowded; completely full scores CROWDED_SCORE.
const COMFORTABLE_OCCUPANCY := 0.8
const CROWDED_SCORE := 0.5
## Guard points wanted per building once a village is big enough to draw dragons.
const BUILDINGS_PER_GUARD := 6.0
const TOWER_GUARD := 3.0
const FIGHTER_GUARD := 1.0
const HERO_GUARD := 4.0
## Each building a dragon destroys adds this many ticks of fear, up to the most.
const FEAR_TICKS_PER_LOST_BUILDING := 60
const MAX_FEAR_TICKS := 240
## Without any running attractions, fun neither helps nor hurts much. Running
## attractions raise it toward 1 as they entertain more of the village.
const NEUTRAL_SCORE := 0.5
## A village badly short of any of these can't be happier than OKAY, however
## well everything else is going.
const ESSENTIALS: Array[StringName] = [&"food", &"water", &"jobs"]
const ESSENTIAL_MINIMUM := 0.5

## Growth effects, counted in population rounds (one per VillageSim.POPULATION_INTERVAL).
## Happy villages get an extra settler every this many rounds, delighted ones more often.
const HAPPY_EXTRA_SETTLER_EVERY := 4
const DELIGHTED_EXTRA_SETTLER_EVERY := 2
## Unhappy villages only gain a settler every this many rounds.
const UNHAPPY_SETTLER_EVERY := 2
## Nobody settles in a miserable village, and someone leaves every this many rounds.
## VillageSim never lets this take it below its FOUNDERS.
const MISERABLE_LEAVER_EVERY := 4

var value := START_VALUE
## Ticks of fear left from buildings the dragon has destroyed.
var dragon_fear := 0


## Every factor's score from 0 to 1, keyed by id in FACTORS order.
func scores(sim: VillageSim) -> Dictionary[StringName, float]:
	var result: Dictionary[StringName, float] = {}
	for factor in FACTORS:
		result[factor.id] = clampf(call("_score_%s" % factor.id, sim), 0.0, 1.0)
	return result


## The value happiness is heading toward, from 0 to 100.
func target(sim: VillageSim) -> float:
	var factor_scores := scores(sim)
	var total := 0.0
	var weights := 0.0
	for factor in FACTORS:
		total += factor.weight * factor_scores[factor.id]
		weights += factor.weight
	var mix := MAX_VALUE * total / weights
	for essential in ESSENTIALS:
		if factor_scores[essential] < ESSENTIAL_MINIMUM:
			return minf(mix, _highest_okay_value())
	return mix


## Just under the HAPPY threshold.
static func _highest_okay_value() -> float:
	return LEVEL_THRESHOLDS[Level.HAPPY - 1] - 1.0 / STEPS_PER_POINT


func update(sim: VillageSim) -> void:
	dragon_fear = maxi(dragon_fear - 1, 0)
	value = _snap(value + (target(sim) - value) * SMOOTHING)


## Jumps straight to the target, for games saved before happiness existed.
func settle(sim: VillageSim) -> void:
	value = _snap(target(sim))


func dragon_destroyed(buildings: int) -> void:
	dragon_fear = mini(dragon_fear + buildings * FEAR_TICKS_PER_LOST_BUILDING, MAX_FEAR_TICKS)


func level() -> Level:
	return level_of(value)


static func level_of(happiness: float) -> Level:
	var result := 0
	for threshold in LEVEL_THRESHOLDS:
		if happiness >= threshold:
			result += 1
	return result as Level


## New villagers due this population round, before housing limits them.
func settlers(round_number: int) -> int:
	match level():
		Level.MISERABLE:
			return 0
		Level.UNHAPPY:
			return 1 if round_number % UNHAPPY_SETTLER_EVERY == 0 else 0
		Level.HAPPY:
			return 2 if round_number % HAPPY_EXTRA_SETTLER_EVERY == 0 else 1
		Level.DELIGHTED:
			return 2 if round_number % DELIGHTED_EXTRA_SETTLER_EVERY == 0 else 1
	return 1


func someone_leaves(round_number: int) -> bool:
	return level() == Level.MISERABLE and round_number % MISERABLE_LEAVER_EVERY == 0


func save_into(data: Dictionary) -> void:
	data["happiness"] = roundi(value * STEPS_PER_POINT)
	data["dragon_fear"] = dragon_fear


func load_from(data: Dictionary) -> bool:
	var steps := VillageSim._whole_number(data, "happiness")
	dragon_fear = VillageSim._whole_number(data, "dragon_fear")
	if steps < 0 or steps > MAX_VALUE * STEPS_PER_POINT or dragon_fear < 0 or dragon_fear > MAX_FEAR_TICKS:
		return false
	value = steps / STEPS_PER_POINT
	return true


func _snap(happiness: float) -> float:
	return roundf(clampf(happiness, 0.0, MAX_VALUE) * STEPS_PER_POINT) / STEPS_PER_POINT


# --- Factors ---

func _score_food(sim: VillageSim) -> float:
	return _supply_score(sim, "food", sim.food)


func _score_water(sim: VillageSim) -> float:
	return _supply_score(sim, "water", sim.water)


## People feel secure with a stock that lasts a good while, or with enough being
## made to keep up with what they eat or drink, whichever is better.
func _supply_score(sim: VillageSim, product: String, stock: int) -> float:
	if sim.population == 0:
		return 1.0
	var needed_per_tick := float(sim.population) / VillageSim.MEAL_INTERVAL
	var ticks_left := stock / needed_per_tick
	var keeping_up := _made_per_tick(sim, product) / (needed_per_tick * SUPPLY_COMFORT_SURPLUS)
	return maxf(ticks_left / SUPPLY_COMFORT_TICKS, keeping_up)


## What the people working right now make in a tick, as VillageSim.tick() counts it.
func _made_per_tick(sim: VillageSim, product: String) -> float:
	var made := 0
	for villager in sim.villagers:
		if villager.state == Villager.State.WORKING:
			made += VillageSim.BUILDINGS.get(sim.building_at(villager.job), {}).get(product, 0)
	return made


func _score_jobs(sim: VillageSim) -> float:
	if sim.population == 0:
		return 1.0
	return float(sim.filled_jobs()) / sim.population


## Room to spare feels best. Fuller houses feel crowded.
func _score_housing(sim: VillageSim) -> float:
	var room := sim.housing()
	if room == 0:
		return 1.0
	var occupancy := float(sim.population) / room
	var crowding := clampf((occupancy - COMFORTABLE_OCCUPANCY) / (1.0 - COMFORTABLE_OCCUPANCY), 0.0, 1.0)
	return 1.0 - crowding * (1.0 - CROWDED_SCORE)


## Towers, fighters and heroes against the size of the village. Villages too
## small to draw a dragon have nothing to fear yet.
func _score_defense(sim: VillageSim) -> float:
	var buildings := sim.building_count()
	if buildings < VillageSim.DRAGON_MIN_BUILDINGS:
		return 1.0
	var guard := (
		sim.towers().size() * TOWER_GUARD
		+ sim.fighter_count() * FIGHTER_GUARD
		+ sim.heroes.size() * HERO_GUARD
	)
	return guard / (buildings / BUILDINGS_PER_GUARD)


## Fear of the dragon, which fades after it last destroyed something.
func _score_safety(_sim: VillageSim) -> float:
	return 1.0 - float(dragon_fear) / MAX_FEAR_TICKS


## Share of houses with a road at the door.
func _score_roads(sim: VillageSim) -> float:
	var all_houses := sim.houses()
	if all_houses.is_empty():
		return 1.0
	var paved := 0
	for house in all_houses:
		for side: Vector2i in VillageSim.DOOR_ORDER:
			if sim.has_road(house + side):
				paved += 1
				break
	return float(paved) / all_houses.size()


## Hook for things to do for fun, such as a playground. Neutral until there are any.
func _score_entertainment(sim: VillageSim) -> float:
	return NEUTRAL_SCORE + (1.0 - NEUTRAL_SCORE) * sim.entertainment()
