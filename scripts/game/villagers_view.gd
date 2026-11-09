class_name VillagersView
extends Node2D
## Draws the simulation's villagers, smoothing their walking between ticks.

const TEXTURE := preload("res://assets/tiles/villagers.png")
const HERO_TEXTURE := preload("res://assets/tiles/hero.png")
const HERO_ROWS := 27
const HERO_WOUNDED_TINT := Color(1.0, 0.55, 0.55)
const HERO_NAME_COLOR := Color(0.97, 0.82, 0.28)
const HERO_NAME_WIDTH := 96.0
const HERO_NAME_RISE := 32.0
## Where a click counts as being on a hero, relative to their feet. Includes the name.
const HERO_CLICK_AREA := Rect2(-10, -32, 20, 34)

## This hero's name is drawn in white.
var selected_hero: Hero = null
const LOOKS := 4
## The sprite sheet row worn by trained fighters.
const FIGHTER_LOOK := 4
const WALK_FRAMES_PER_SECOND := 6.0
const DOOR_INSET := 14.0
const MAX_LANE := 6
const FRAME_DOWN := 0
const FRAME_UP := 2
const FRAME_SIDE := 4

var _sim: VillageSim
var _map: MapView
var _sprites: Array[Sprite2D] = []
var _time := 0.0
var _hero_sprites: Array[Sprite2D] = []


func bind(sim: VillageSim, map: MapView) -> void:
	_sim = sim
	_map = map
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	for sprite in _hero_sprites:
		sprite.queue_free()
	_hero_sprites.clear()


func advance(sim_delta: float, tick_fraction: float) -> void:
	_time += sim_delta
	var villagers := _sim.villagers
	while _sprites.size() < villagers.size():
		_add_sprite()
	while _sprites.size() > villagers.size():
		_sprites.pop_back().queue_free()
	for index in range(villagers.size()):
		_draw_villager(villagers[index], _sprites[index], index, tick_fraction)
	while _hero_sprites.size() < _sim.heroes.size():
		_add_hero_sprite()
	for index in range(_sim.heroes.size()):
		_draw_hero(_sim.heroes[index], _hero_sprites[index], tick_fraction)


func _add_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.hframes = 6
	sprite.vframes = LOOKS + 1
	sprite.offset = Vector2(0, -7)
	sprite.frame_coords = Vector2i(FRAME_DOWN, _sprites.size() % LOOKS)
	sprite.visible = false
	add_child(sprite)
	_sprites.append(sprite)


func _draw_villager(villager: Villager, sprite: Sprite2D, index: int, tick_fraction: float) -> void:
	var walking := villager.state == Villager.State.WALKING
	sprite.visible = walking or villager.state == Villager.State.OUTSIDE
	if not sprite.visible or villager.cell == Villager.NO_CELL:
		return
	sprite.frame_coords.y = FIGHTER_LOOK if _sim.is_fighter(villager) else index % LOOKS
	var lane := _lane(index)
	if not walking:
		sprite.position = _map.cell_center(villager.cell) + lane
		sprite.frame_coords.x = FRAME_DOWN
		return
	var position_now := _walking_position(villager, lane, tick_fraction)
	var moved := position_now - sprite.position
	sprite.position = position_now
	if moved.length_squared() > 0.0:
		_face(sprite, moved)


## The hero under the mouse, or the one in front if several overlap.
func hero_at_mouse() -> Hero:
	var mouse := get_local_mouse_position()
	var found: Hero = null
	var front := -INF
	for index in range(mini(_hero_sprites.size(), _sim.heroes.size())):
		var feet := _hero_sprites[index].position
		if feet.y > front and HERO_CLICK_AREA.has_point(mouse - feet):
			found = _sim.heroes[index]
			front = feet.y
	return found


func _add_hero_sprite() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = HERO_TEXTURE
	sprite.hframes = 6
	sprite.vframes = HERO_ROWS
	sprite.offset = Vector2(0, -9)
	add_child(sprite)
	var tag := Label.new()
	tag.size = Vector2(HERO_NAME_WIDTH, 0)
	tag.position = Vector2(-HERO_NAME_WIDTH / 2.0, -HERO_NAME_RISE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sprite.add_child(tag)
	_hero_sprites.append(sprite)


func _draw_hero(hero: Hero, sprite: Sprite2D, tick_fraction: float) -> void:
	sprite.frame_coords.y = hero.sprite_row()
	sprite.modulate = HERO_WOUNDED_TINT if hero.wounded else Color.WHITE
	var tag: Label = sprite.get_child(0)
	tag.text = hero.hero_name
	tag.modulate = Color.WHITE if hero == selected_hero else HERO_NAME_COLOR
	if hero.state != Villager.State.WALKING:
		sprite.position = _map.cell_center(hero.cell)
		sprite.frame_coords.x = FRAME_DOWN
		return
	var position_now := _walking_position(hero, Vector2.ZERO, tick_fraction)
	var moved := position_now - sprite.position
	sprite.position = position_now
	if moved.length_squared() > 0.0:
		_face(sprite, moved)


## Keeps people from walking in single file. Stable for each person.
func _lane(index: int) -> Vector2:
	var span := MAX_LANE * 2 + 1
	var roll := hash(index)
	return Vector2(roll % span - MAX_LANE, (roll >> 8) % span - MAX_LANE)


func _walking_position(villager: Villager, lane: Vector2, tick_fraction: float) -> Vector2:
	var path := villager.path
	var progress := minf(villager.progress + _sim.walk_speed(villager) * tick_fraction, villager.trip_end())
	var last := path.size() - 1
	if progress < 0.0:
		var door := _door_front(villager.from_building, path[0])
		return door.lerp(_map.cell_center(path[0]) + lane, (progress + 0.5) * 2.0)
	if progress > last:
		var door := _door_front(villager.to_building, path[last])
		return (_map.cell_center(path[last]) + lane).lerp(door, (progress - last) * 2.0)
	var step := mini(floori(progress), maxi(last - 1, 0))
	var next := mini(step + 1, last)
	return (_map.cell_center(path[step]) + lane).lerp(_map.cell_center(path[next]) + lane, progress - step)


func _door_front(building: Vector2i, door_cell: Vector2i) -> Vector2:
	var side := door_cell - building
	if building == Villager.NO_CELL or absi(side.x) + absi(side.y) != 1:
		return _map.cell_center(door_cell)
	return _map.cell_center(building) + Vector2(side) * DOOR_INSET


func _face(sprite: Sprite2D, direction: Vector2) -> void:
	var base := FRAME_SIDE
	if absf(direction.y) > absf(direction.x):
		base = FRAME_DOWN if direction.y > 0.0 else FRAME_UP
		sprite.flip_h = false
	else:
		sprite.flip_h = direction.x < 0.0
	sprite.frame_coords.x = base + int(_time * WALK_FRAMES_PER_SECOND) % 2
