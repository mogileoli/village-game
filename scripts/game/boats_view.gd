class_name BoatsView
extends Node2D
## Draws each dock's boats. Where a boat is comes from its fisher's shift in
## the simulation, which decides what is caught; this only shows it.

const TEXTURE := preload("res://assets/tiles/boats.png")
const COLUMNS := 4
const ROWS := 3
const ACROSS := 0
const UP_DOWN := 2
const EMPTY_ROW := 0
const ROWING_ROW := 1
const FISHING_ROW := 2
const STROKES_PER_SECOND := 3.0
const BOBS_PER_SECOND := 1.0
## Pixels from the dock's center to where its boats tie up, toward open water.
const MOORING_REACH := 26.0
## Pixels between boats side by side.
const BOAT_SPACING := 10.0

var _sim: VillageSim
var _map: MapView
var _sprites: Array[Sprite2D] = []
var _time := 0.0


func bind(sim: VillageSim, map: MapView) -> void:
	_sim = sim
	_map = map
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()


func advance(sim_delta: float, tick_fraction: float) -> void:
	_time += sim_delta
	var used := 0
	for dock in _sim.workplaces():
		var building: Dictionary = VillageSim.BUILDINGS[_sim.building_at(dock)]
		if not building.has("fishing"):
			continue
		var fishers := _fishers_at(dock)
		var boats: int = building.jobs
		for index in range(boats):
			if used == _sprites.size():
				_add_sprite()
			var fisher: Villager = fishers[index] if index < fishers.size() else null
			_draw_boat(_sprites[used], dock, fisher, index - (boats - 1) / 2.0, tick_fraction)
			used += 1
	for index in range(used, _sprites.size()):
		_sprites[index].visible = false


func _add_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.hframes = COLUMNS
	sprite.vframes = ROWS
	add_child(sprite)
	_sprites.append(sprite)


## The dock's workers who are out on a shift, in a stable order.
func _fishers_at(dock: Vector2i) -> Array[Villager]:
	var fishers: Array[Villager] = []
	for villager in _sim.villagers:
		if villager.job == dock and villager.state == Villager.State.WORKING:
			fishers.append(villager)
	return fishers


## Points along the boat's way: its mooring beside the dock, then each water cell out.
func _waypoints(dock: Vector2i) -> PackedVector2Array:
	var route := _sim.fishing_route(dock)
	var center := _map.cell_center(dock)
	var points := PackedVector2Array()
	if route.size() == 1:
		# Nowhere to row to: the boats wait in front of the pier.
		points.append(center + Vector2.DOWN * MapView.TILE_SIZE.y * 0.3)
		return points
	var outward := Vector2(route[1] - dock)
	points.append(center + outward * MOORING_REACH)
	for index in range(1, route.size()):
		points.append(_map.cell_center(route[index]))
	return points


## How far out the boat is, from 0 tied up to 1 at the fishing spot. It rows
## out at the start of the shift and back at the end, as the sim times it.
func _how_far_out(fisher: Villager, tick_fraction: float) -> float:
	if fisher == null:
		return 0.0
	var since_start := fisher.shift_ticks + tick_fraction
	var until_end := fisher.timer - tick_fraction
	return clampf(minf(since_start, until_end) / VillageSim.BOAT_ROW_TICKS, 0.0, 1.0)


func _draw_boat(sprite: Sprite2D, dock: Vector2i, fisher: Villager, slot: float, tick_fraction: float) -> void:
	sprite.visible = true
	var points := _waypoints(dock)
	var out := _how_far_out(fisher, tick_fraction)
	var along := out * (points.size() - 1)
	var step := mini(floori(along), maxi(points.size() - 2, 0))
	var from := points[step]
	var to := points[mini(step + 1, points.size() - 1)]
	var heading := (to - from).normalized() if to != from else Vector2.RIGHT
	# Boats keep to their own side of the way out and back.
	var side := Vector2(-heading.y, heading.x)
	sprite.position = from.lerp(to, along - step) + side * slot * BOAT_SPACING
	if fisher != null and fisher.timer - tick_fraction < fisher.shift_ticks + tick_fraction:
		heading = -heading
	var across := absf(heading.x) >= absf(heading.y)
	sprite.flip_h = across and heading.x < 0.0
	var column := ACROSS if across else UP_DOWN
	if fisher == null:
		sprite.frame_coords = Vector2i(column, EMPTY_ROW)
	elif out >= 1.0:
		sprite.frame_coords = Vector2i(column + int(_time * BOBS_PER_SECOND) % 2, FISHING_ROW)
	else:
		sprite.frame_coords = Vector2i(column + int(_time * STROKES_PER_SECOND) % 2, ROWING_ROW)
