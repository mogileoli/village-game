class_name MapView
extends Node2D
## Draws the simulation's map and converts between screen and grid positions.

const TILE_SIZE := Vector2i(32, 32)
const BUILDING_REGION := Vector2i(32, 48)
const LAND_SOURCE := 0
const WATER_SOURCE := 1
const SHORE_SOURCE := 0
const SCORCH_SOURCE := 0
const ROAD_SOURCE := 0
const BRIDGE_SOURCE := 1
const IDLE_SOURCE := 0
## Atlas columns for grass. Plain tiles repeat so flowers stay occasional.
const GRASS_TILES := [0, 0, 0, 0, 1, 1, 1, 2, 2, 3, 4, 0, 1, 0]
const GRASS_COLUMNS := 5
const TREE_TILE := Vector2i(5, 0)
const WATER_FRAMES := 3
const WATER_FRAMES_PER_SECOND := 2.0
const SIDES := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIAGONALS := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
const BUILDING_ATLAS := {
	&"house": 0, &"farm": 1, &"lumber_camp": 2, &"well": 3, &"tower": 4, &"training_center": 5,
	&"playground": 7,
}
const ATTRACTION_ICONS := preload("res://assets/ui/attractions.png")
## The boarded-up hatch after the attraction icons, for a burned entrance.
const BURIED_ICON_COLUMN := 6
const ATTRACTION_ICON_SIZE := 16
## Where an entrance's attraction count sits: on its sign, above the cell.
const BADGE_OFFSET := Vector2(-3, -26)
const BURIED_BADGE_OFFSET := Vector2(-3, -6)
const BADGE_COLOR := Color.WHITE
const BURIED_BADGE_COLOR := Color(0.75, 0.75, 0.8)
const RANGE_RING_POINTS := 48
const VALID_COLOR := Color.WHITE
const INVALID_COLOR := Color(1, 0.25, 0.2)

var _sim: VillageSim
var _building_source := -1
## Attraction counts shown on playground entrances and on burned ones' hatches.
var _badges: Dictionary[Vector2i, Node2D] = {}
var _badge_layer := Node2D.new()

@onready var _terrain: TileMapLayer = $Terrain
@onready var _shore: TileMapLayer = $Shore
@onready var _scorch: TileMapLayer = $Scorch
@onready var _roads: TileMapLayer = $Roads
@onready var _buildings: TileMapLayer = $Actors/Buildings
@onready var _idle_marks: TileMapLayer = $IdleMarks
@onready var _highlight: Sprite2D = $Highlight
@onready var _range_ring: Line2D = $RangeRing
@onready var _preview: TileMapLayer = $Preview


func _ready() -> void:
	_terrain.tile_set = _make_terrain_tileset()
	_shore.tile_set = _make_shore_tileset()
	_scorch.tile_set = _make_scorch_tileset()
	_roads.tile_set = _make_road_tileset()
	_idle_marks.tile_set = _make_idle_tileset()
	var building_tiles := _make_building_tileset()
	_buildings.tile_set = building_tiles
	_preview.tile_set = building_tiles
	_badge_layer.z_index = 1
	add_child(_badge_layer)


func bind(sim: VillageSim) -> void:
	_sim = sim
	_sim.cell_changed.connect(_on_cell_changed)
	_sim.stats_changed.connect(_draw_idle_marks)
	_terrain.clear()
	_shore.clear()
	_scorch.clear()
	_roads.clear()
	_buildings.clear()
	for badge: Node2D in _badges.values():
		badge.queue_free()
	_badges.clear()
	for y in range(_sim.height):
		for x in range(_sim.width):
			_on_cell_changed(Vector2i(x, y))
	_draw_idle_marks()


func cell_center(cell: Vector2i) -> Vector2:
	return _terrain.map_to_local(cell)


func cell_at_mouse() -> Vector2i:
	return _terrain.local_to_map(_terrain.get_local_mouse_position())


func world_bounds() -> Rect2:
	var bounds := Rect2(_terrain.map_to_local(Vector2i.ZERO), Vector2.ZERO)
	bounds = bounds.expand(_terrain.map_to_local(Vector2i(_sim.width - 1, 0)))
	bounds = bounds.expand(_terrain.map_to_local(Vector2i(0, _sim.height - 1)))
	return bounds.expand(_terrain.map_to_local(Vector2i(_sim.width - 1, _sim.height - 1)))


func world_center() -> Vector2:
	return _terrain.map_to_local(Vector2i(_sim.width, _sim.height) / 2)


## Outlines the area a tower placed at this cell would defend.
func show_range(cell: Vector2i, radius_cells: float) -> void:
	_range_ring.visible = _sim.in_bounds(cell)
	_range_ring.position = _terrain.map_to_local(cell)
	if _range_ring.get_point_count() == RANGE_RING_POINTS:
		return
	var radius := (radius_cells + 0.5) * TILE_SIZE.x
	var points := PackedVector2Array()
	for index in range(RANGE_RING_POINTS):
		points.append(Vector2.from_angle(TAU * index / RANGE_RING_POINTS) * radius)
	_range_ring.points = points


func hide_range() -> void:
	_range_ring.visible = false


func show_cursor(cell: Vector2i, valid: bool, ghost_type: StringName) -> void:
	_preview.clear()
	_highlight.visible = _sim.in_bounds(cell)
	if not _highlight.visible:
		return
	_highlight.position = _terrain.map_to_local(cell)
	_highlight.modulate = VALID_COLOR if valid else INVALID_COLOR
	if ghost_type != &"" and valid:
		_preview.set_cell(cell, _building_source, Vector2i(BUILDING_ATLAS[ghost_type], 0))


## Marks farms and camps that nobody works at, so they aren't producing.
func _draw_idle_marks() -> void:
	_idle_marks.clear()
	for cell in _sim.workplaces():
		if _sim.workers_at(cell) == 0:
			_idle_marks.set_cell(cell, IDLE_SOURCE, Vector2i.ZERO)


func _draw_ground_details(cell: Vector2i) -> void:
	_draw_scorch(cell)
	_draw_road(cell)


## Road tiles join neighboring roads, and a building's door to the north.
## Bridges also join any ground people can step onto from them.
func _draw_road(cell: Vector2i) -> void:
	if not _sim.has_road(cell):
		_roads.erase_cell(cell)
		return
	var bridge := _sim.is_bridge(cell)
	var joined_sides := 0
	for index in range(SIDES.size()):
		var neighbor: Vector2i = cell + SIDES[index]
		if _sim.has_road(neighbor) or (bridge and _sim.is_walkable(neighbor)):
			joined_sides |= 1 << index
	if _sim.building_at(cell + Vector2i.UP) != &"":
		joined_sides |= 1
	_roads.set_cell(cell, BRIDGE_SOURCE if bridge else ROAD_SOURCE, Vector2i(joined_sides, 0))


## Scorch tiles have rough edges only on sides that don't touch more scorch.
func _draw_scorch(cell: Vector2i) -> void:
	if not _sim.is_scorched(cell):
		_scorch.erase_cell(cell)
		return
	var rough_sides := 0
	for index in range(SIDES.size()):
		if not _sim.is_scorched(cell + SIDES[index]):
			rough_sides |= 1 << index
	_scorch.set_cell(cell, SCORCH_SOURCE, Vector2i(rough_sides, 0))


func _draw_terrain(cell: Vector2i) -> void:
	match _sim.terrain_at(cell):
		VillageSim.Terrain.WATER:
			_terrain.set_cell(cell, WATER_SOURCE, Vector2i(_land_sides(cell), 0))
			var corners := _land_corners(cell)
			if corners != 0:
				_shore.set_cell(cell, SHORE_SOURCE, Vector2i(corners, 0))
		VillageSim.Terrain.FOREST:
			_terrain.set_cell(cell, LAND_SOURCE, TREE_TILE)
		_:
			var column: int = GRASS_TILES[hash(cell) % GRASS_TILES.size()]
			_terrain.set_cell(cell, LAND_SOURCE, Vector2i(column, 0))


## Bitmask of the sides of a water cell that touch land, for its shoreline.
func _land_sides(cell: Vector2i) -> int:
	var mask := 0
	for index in range(SIDES.size()):
		if _is_land(cell + SIDES[index]):
			mask |= 1 << index
	return mask


## Bitmask of the corners of a water cell that touch land at that corner only.
func _land_corners(cell: Vector2i) -> int:
	var mask := 0
	for index in range(DIAGONALS.size()):
		var diagonal: Vector2i = DIAGONALS[index]
		if (
			_is_land(cell + diagonal)
			and not _is_land(cell + Vector2i(diagonal.x, 0))
			and not _is_land(cell + Vector2i(0, diagonal.y))
		):
			mask |= 1 << index
	return mask


func _is_land(cell: Vector2i) -> bool:
	return _sim.in_bounds(cell) and _sim.terrain_at(cell) != VillageSim.Terrain.WATER


func _on_cell_changed(cell: Vector2i) -> void:
	_draw_terrain(cell)
	_draw_ground_details(cell)
	for side: Vector2i in SIDES:
		_draw_ground_details(cell + side)
	var type := _sim.building_at(cell)
	if type == &"":
		_buildings.erase_cell(cell)
	else:
		_buildings.set_cell(cell, _building_source, Vector2i(BUILDING_ATLAS[type], 0))
	_draw_badge(cell)


## Numbers a playground's attractions on its sign. Attractions left by a burned
## entrance show as a boarded-up hatch with their number.
func _draw_badge(cell: Vector2i) -> void:
	if _badges.has(cell):
		_badges[cell].queue_free()
		_badges.erase(cell)
	var count := _sim.attractions_at(cell).size()
	var buried := _sim.has_buried_attractions(cell)
	if count == 0 or not (buried or _sim.is_playground(cell)):
		return
	var badge := Node2D.new()
	badge.position = _terrain.map_to_local(cell)
	if buried:
		var hatch := Sprite2D.new()
		var region := AtlasTexture.new()
		region.atlas = ATTRACTION_ICONS
		region.region = Rect2(BURIED_ICON_COLUMN * ATTRACTION_ICON_SIZE, 0, ATTRACTION_ICON_SIZE, ATTRACTION_ICON_SIZE)
		hatch.texture = region
		badge.add_child(hatch)
	var label := Label.new()
	label.text = str(count)
	label.position = BURIED_BADGE_OFFSET if buried else BADGE_OFFSET
	label.add_theme_color_override("font_color", BURIED_BADGE_COLOR if buried else BADGE_COLOR)
	badge.add_child(label)
	_badge_layer.add_child(badge)
	_badges[cell] = badge


func _make_tileset() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = TILE_SIZE
	return tiles


func _make_terrain_tileset() -> TileSet:
	var tiles := _make_tileset()
	var land := TileSetAtlasSource.new()
	land.texture = preload("res://assets/tiles/land.png")
	land.texture_region_size = TILE_SIZE
	for column: int in range(GRASS_COLUMNS):
		land.create_tile(Vector2i(column, 0))
	land.create_tile(TREE_TILE)
	tiles.add_source(land, LAND_SOURCE)

	var water := TileSetAtlasSource.new()
	water.texture = preload("res://assets/tiles/water.png")
	water.texture_region_size = TILE_SIZE
	for mask in range(16):
		var coords := Vector2i(mask, 0)
		water.create_tile(coords)
		water.set_tile_animation_columns(coords, 1)
		water.set_tile_animation_frames_count(coords, WATER_FRAMES)
		water.set_tile_animation_speed(coords, WATER_FRAMES_PER_SECOND)
	tiles.add_source(water, WATER_SOURCE)
	return tiles


func _make_shore_tileset() -> TileSet:
	var tiles := _make_tileset()
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/tiles/shore_corners.png")
	source.texture_region_size = TILE_SIZE
	for mask in range(16):
		source.create_tile(Vector2i(mask, 0))
	tiles.add_source(source, SHORE_SOURCE)
	return tiles


func _make_scorch_tileset() -> TileSet:
	var tiles := _make_tileset()
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/tiles/scorch.png")
	source.texture_region_size = TILE_SIZE
	for rough_sides in range(16):
		source.create_tile(Vector2i(rough_sides, 0))
	tiles.add_source(source, SCORCH_SOURCE)
	return tiles


func _make_road_tileset() -> TileSet:
	var tiles := _make_tileset()
	for entry: Array in [[preload("res://assets/tiles/roads.png"), ROAD_SOURCE], [preload("res://assets/tiles/bridges.png"), BRIDGE_SOURCE]]:
		var source := TileSetAtlasSource.new()
		source.texture = entry[0]
		source.texture_region_size = TILE_SIZE
		for joined_sides in range(16):
			source.create_tile(Vector2i(joined_sides, 0))
		tiles.add_source(source, entry[1])
	return tiles


func _make_idle_tileset() -> TileSet:
	var tiles := _make_tileset()
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/ui/idle_mark.png")
	source.texture_region_size = Vector2i(14, 16)
	source.create_tile(Vector2i.ZERO)
	# Stays within the building's own cell, so it can't look like it's on a neighbor.
	source.get_tile_data(Vector2i.ZERO, 0).texture_origin = Vector2i(0, 8)
	tiles.add_source(source, IDLE_SOURCE)
	return tiles


func _make_building_tileset() -> TileSet:
	var tiles := _make_tileset()
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/tiles/buildings.png")
	source.texture_region_size = BUILDING_REGION
	_building_source = tiles.add_source(source)
	for index: int in BUILDING_ATLAS.values():
		var coords := Vector2i(index, 0)
		source.create_tile(coords)
		# Each image is one cell plus 16px of height rising above it.
		var tile := source.get_tile_data(coords, 0)
		tile.texture_origin = Vector2i(0, 8)
		# Sort by the front wall, so people walk behind and in front correctly.
		tile.y_sort_origin = TILE_SIZE.y / 2
	return tiles
