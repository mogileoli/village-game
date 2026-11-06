class_name DragonView
extends Node2D
## Draws the dragon's flight and fires. Its position comes from the simulation's
## timers, so it follows pause, game speed and loading a save.

const FIRE_TEXTURE := preload("res://assets/tiles/fire.png")
const SPLASH_TEXTURE := preload("res://assets/tiles/splash.png")
const NOZZLE_OFFSET := Vector2(0, -26)
const DROPS_PER_TOWER := 5
const DROP_SECONDS := 0.5
const DROP_GAP_SECONDS := 0.15
const DROP_ARC := 30.0
const FIRE_FRAMES := 3
const ENTRY_OFFSET := Vector2(-420, -120)
const EXIT_OFFSET := Vector2(420, -120)
const ALTITUDE := 56.0
const MOUTH_OFFSET := Vector2(36, 12)
const FLAPS_PER_SECOND := 5.0
const FLAMES_PER_SECOND := 9.0
const FIRE_SECONDS := 3.0
const BREATH_TICKS := 1

var _sim: VillageSim
var _map: MapView
var _time := 0.0
var _fires: Array[Sprite2D] = []
var _fire_age := 0.0
var _drops: Array[Dictionary] = []

@onready var _shadow: Sprite2D = $Shadow
@onready var _body: Sprite2D = $Body
@onready var _breath: Node2D = $Breath


func bind(sim: VillageSim, map: MapView) -> void:
	_sim = sim
	_map = map
	_sim.dragon_struck.connect(_on_struck)
	_sim.dragon_defended.connect(_on_defended)
	_clear_fires()
	_clear_drops()


## Takes simulation seconds, so nothing moves while the game is paused.
func advance(sim_delta: float, tick_fraction: float) -> void:
	_time += sim_delta
	_update_fires(sim_delta)
	_update_drops(sim_delta)
	var flying := _sim.dragon_state in [VillageSim.DragonState.INBOUND, VillageSim.DragonState.DEPARTING]
	_shadow.visible = flying
	_body.visible = flying
	_breath.visible = false
	if not flying:
		return

	var target := _map.cell_center(_sim.dragon_target)
	var ticks_left := _sim.dragon_timer - tick_fraction
	var ground: Vector2
	if _sim.dragon_state == VillageSim.DragonState.INBOUND:
		ground = target + ENTRY_OFFSET * ticks_left / VillageSim.DRAGON_INBOUND_TICKS
	else:
		ground = target + EXIT_OFFSET * (1.0 - ticks_left / VillageSim.DRAGON_DEPARTING_TICKS)
	_shadow.position = ground
	_body.position = ground + Vector2(0, -ALTITUDE)
	_body.frame = int(_time * FLAPS_PER_SECOND) % 2

	if _sim.dragon_state == VillageSim.DragonState.INBOUND and _sim.dragon_timer <= BREATH_TICKS:
		_draw_breath(_body.position + MOUTH_OFFSET, target)


func _draw_breath(from: Vector2, to: Vector2) -> void:
	_breath.visible = true
	var count := _breath.get_child_count()
	for index in range(count):
		var flame: Sprite2D = _breath.get_child(index)
		flame.position = from.lerp(to, float(index + 1) / count)
		flame.frame = (int(_time * FLAMES_PER_SECOND) + index) % FIRE_FRAMES


## Towers arc water at the dragon, which is overhead at the moment of the strike.
func _on_defended(defenders: Array[Vector2i], _threatened: int) -> void:
	var dragon := _map.cell_center(_sim.dragon_target) + Vector2(0, -ALTITUDE)
	for tower in defenders:
		for index in range(DROPS_PER_TOWER):
			var drop := Sprite2D.new()
			drop.texture = SPLASH_TEXTURE
			drop.visible = false
			add_child(drop)
			_drops.append({
				"sprite": drop,
				"from": _map.cell_center(tower) + NOZZLE_OFFSET,
				"to": dragon + Vector2(index * 3 - 6, index % 2 * 4),
				"age": -index * DROP_GAP_SECONDS,
			})


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
			sprite.position = from.lerp(drop.to, t) + Vector2(0, -sin(t * PI) * DROP_ARC)


func _clear_drops() -> void:
	for drop: Dictionary in _drops:
		drop.sprite.queue_free()
	_drops.clear()


func _on_struck(_destroyed: Array[Vector2i], burned: Array[Vector2i]) -> void:
	_clear_fires()
	for cell in burned:
		var fire := Sprite2D.new()
		fire.texture = FIRE_TEXTURE
		fire.hframes = FIRE_FRAMES
		fire.position = _map.cell_center(cell) + Vector2(0, -4)
		add_child(fire)
		_fires.append(fire)


func _update_fires(sim_delta: float) -> void:
	if _fires.is_empty():
		return
	_fire_age += sim_delta
	if _fire_age >= FIRE_SECONDS:
		_clear_fires()
		return
	for index in range(_fires.size()):
		_fires[index].frame = (int(_time * FLAMES_PER_SECOND) + index) % FIRE_FRAMES


func _clear_fires() -> void:
	for fire in _fires:
		fire.queue_free()
	_fires.clear()
	_fire_age = 0.0
