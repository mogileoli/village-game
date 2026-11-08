class_name DragonView
extends Node2D
## Draws dragon visits: the flight in, circling over the village, strikes, the
## water thrown at it, and the flight out. Everything follows the simulation's
## timers, so it keeps to pause, game speed and loaded saves.

const FIRE_TEXTURE := preload("res://assets/tiles/fire.png")
const SPLASH_TEXTURE := preload("res://assets/tiles/splash.png")
const HERO_SHOTS_TEXTURE := preload("res://assets/tiles/hero_shots.png")
const HERO_SHOT_FRAMES := 3
## How far a slain dragon tilts as it falls, in radians.
const FALL_TILT := 0.6
const FIRE_FRAMES := 3
const ENTRY_OFFSET := Vector2(-420, -120)
const EXIT_OFFSET := Vector2(420, -120)
const ALTITUDE := 56.0
const MOUTH_OFFSET := Vector2(36, 12)
const ORBIT_RADIUS := Vector2(30, 14)
const ORBIT_SPEED := 1.4
const FLAPS_PER_SECOND := 5.0
const FLAMES_PER_SECOND := 9.0
const FIRE_SECONDS := 3.0
const TOWER_NOZZLE := Vector2(0, -26)
const VILLAGER_HANDS := Vector2(0, -10)
const DROPS_PER_THROWER := 2
const MAX_THROWERS_SHOWN := 16
const DROP_SECONDS := 0.5
const DROP_GAP_SECONDS := 0.2
const DROP_ARC := 30.0

var _sim: VillageSim
var _map: MapView
var _time := 0.0
var _fires: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _departure_start := Vector2.ZERO
var _was_departing := false

@onready var _shadow: Sprite2D = $Shadow
@onready var _body: Sprite2D = $Body
@onready var _breath: Node2D = $Breath


func bind(sim: VillageSim, map: MapView) -> void:
	_sim = sim
	_map = map
	_sim.dragon_struck.connect(_on_struck)
	_sim.dragon_hit.connect(_on_hit)
	_sim.hero_attacked.connect(_on_hero_attacked)
	for list: Array[Dictionary] in [_fires, _drops]:
		for item in list:
			item.sprite.queue_free()
		list.clear()
	_was_departing = false


## Takes simulation seconds, so nothing moves while the game is paused.
func advance(sim_delta: float, tick_fraction: float) -> void:
	_time += sim_delta
	_update_fires(sim_delta)
	_update_drops(sim_delta)
	var state := _sim.dragon_state
	var flying := state in [VillageSim.DragonState.INBOUND, VillageSim.DragonState.RAMPAGE, VillageSim.DragonState.DEPARTING]
	_shadow.visible = flying
	_body.visible = flying
	_breath.visible = false
	if not flying:
		_was_departing = false
		return

	var ground := _ground_position(state, tick_fraction)
	var moved := ground - _shadow.position
	_shadow.position = ground
	# A slain dragon drops out of the sky and fades away instead of flying off.
	var fallen := 0.0
	if state == VillageSim.DragonState.DEPARTING and _sim.dragon_slain:
		fallen = 1.0 - clampf((_sim.dragon_timer - tick_fraction) / VillageSim.DRAGON_DEPARTING_TICKS, 0.0, 1.0)
	_body.position = ground + Vector2(0, -ALTITUDE * (1.0 - fallen))
	_body.rotation = fallen * FALL_TILT
	_body.modulate.a = 1.0 - fallen * fallen
	_shadow.modulate.a = _body.modulate.a
	if absf(moved.x) > 0.01:
		_body.flip_h = moved.x < 0.0
		_shadow.flip_h = _body.flip_h
	_body.frame_coords = Vector2i(int(_time * FLAPS_PER_SECOND) % 2, _sim.dragon_level - 1)
	var strike_in := _sim.dragon_ticks_until_strike()
	if state == VillageSim.DragonState.RAMPAGE and strike_in >= 0 and strike_in - tick_fraction <= 1.0:
		var mouth := MOUTH_OFFSET * Vector2(-1 if _body.flip_h else 1, 1)
		_draw_breath(_body.position + mouth, _map.cell_center(_sim.dragon_target))


func dragon_position() -> Vector2:
	return _body.position


func _ground_position(state: VillageSim.DragonState, tick_fraction: float) -> Vector2:
	var target := _map.cell_center(_sim.dragon_target)
	match state:
		VillageSim.DragonState.INBOUND:
			_was_departing = false
			var ticks_left := _sim.dragon_timer - tick_fraction
			return target + ENTRY_OFFSET * ticks_left / VillageSim.DRAGON_INBOUND_TICKS
		VillageSim.DragonState.RAMPAGE:
			_was_departing = false
			# Glide to each new target over the tick after a strike, circling all the while.
			var since_strike := _sim.dragon_rampage_ticks - _sim.dragon_last_strike_tick() + tick_fraction
			var previous := _map.cell_center(_sim.dragon_previous_target)
			var angle := _time * ORBIT_SPEED
			var orbit := Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS
			return previous.lerp(target, clampf(since_strike, 0.0, 1.0)) + orbit
	if not _was_departing:
		_was_departing = true
		_departure_start = _shadow.position if _shadow.visible else target
	var gone := 1.0 - (_sim.dragon_timer - tick_fraction) / VillageSim.DRAGON_DEPARTING_TICKS
	if _sim.dragon_slain:
		return _departure_start
	return _departure_start + EXIT_OFFSET * clampf(gone, 0.0, 1.0)


func _draw_breath(from: Vector2, to: Vector2) -> void:
	_breath.visible = true
	var count := _breath.get_child_count()
	for index in range(count):
		var flame: Sprite2D = _breath.get_child(index)
		flame.position = from.lerp(to, float(index + 1) / count)
		flame.frame = (int(_time * FLAMES_PER_SECOND) + index) % FIRE_FRAMES


func _on_struck(_destroyed: Array[Vector2i], burned: Array[Vector2i]) -> void:
	for cell in burned:
		var fire := Sprite2D.new()
		fire.texture = FIRE_TEXTURE
		fire.hframes = FIRE_FRAMES
		fire.position = _map.cell_center(cell) + Vector2(0, -4)
		add_child(fire)
		_fires.append({"sprite": fire, "age": 0.0})


## Water arcs from each tower and fighter to wherever the dragon is circling.
func _on_hit(attackers: Array[Vector2i], _damage: int) -> void:
	for thrower in range(mini(attackers.size(), MAX_THROWERS_SHOWN)):
		var cell := attackers[thrower]
		var hands := TOWER_NOZZLE if _sim.building_at(cell) == &"tower" else VILLAGER_HANDS
		for index in range(DROPS_PER_THROWER):
			var drop := Sprite2D.new()
			drop.texture = SPLASH_TEXTURE
			drop.visible = false
			add_child(drop)
			_drops.append({
				"sprite": drop,
				"from": _map.cell_center(cell) + hands,
				"age": -index * DROP_GAP_SECONDS - thrower * 0.03,
			})


## The hero's slash, arrow or axe blow, flying up to the dragon.
func _on_hero_attacked(hero: Hero) -> void:
	var shot := Sprite2D.new()
	shot.texture = HERO_SHOTS_TEXTURE
	shot.hframes = HERO_SHOT_FRAMES
	shot.frame = hero.weapon_index()
	shot.visible = false
	add_child(shot)
	_drops.append({"sprite": shot, "from": _map.cell_center(hero.cell) + VILLAGER_HANDS, "age": 0.0, "aimed": true})


func _update_drops(sim_delta: float) -> void:
	for drop: Dictionary in _drops.duplicate():
		drop.age += sim_delta
		var sprite: Sprite2D = drop.sprite
		var t: float = drop.age / DROP_SECONDS
		sprite.visible = t >= 0.0 and t <= 1.0
		if t > 1.0:
			sprite.queue_free()
			_drops.erase(drop)
		elif t >= 0.0:
			var from: Vector2 = drop.from
			sprite.position = from.lerp(_body.position, t) + Vector2(0, -sin(t * PI) * DROP_ARC)
			if drop.get("aimed", false):
				sprite.rotation = from.angle_to_point(_body.position)


func _update_fires(sim_delta: float) -> void:
	for index in range(_fires.size() - 1, -1, -1):
		var fire := _fires[index]
		fire.age += sim_delta
		if fire.age >= FIRE_SECONDS:
			fire.sprite.queue_free()
			_fires.remove_at(index)
		else:
			fire.sprite.frame = (int(_time * FLAMES_PER_SECOND) + index) % FIRE_FRAMES
