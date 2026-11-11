extends SceneTree
## Draws all game art in a 16-bit top-down adventure style. Every color is a
## multiple of 8 per channel, like the SNES's 15-bit palette.
## Run: godot --headless --path . --script res://tools/generate_art.gd
## Overwrites the PNGs in assets/, so don't rerun it after hand-editing them.

const CELL := 32
const BUILDING_H := 48
const WATER_FRAMES := 3
const LAND := 1 << 0

# Outline
const INK := Color8(24, 16, 32)
# Grass
const G_DARK := Color8(56, 136, 56)
const G_MID := Color8(88, 168, 72)
const G_LIGHT := Color8(136, 200, 88)
# Trees
const T_INK := Color8(16, 56, 40)
const T_DARK := Color8(24, 104, 56)
const T_MID := Color8(48, 144, 64)
const T_LIGHT := Color8(112, 192, 80)
# Water
const W_DEEP := Color8(40, 80, 168)
const W_MID := Color8(56, 112, 200)
const W_LIGHT := Color8(112, 168, 232)
const W_FOAM := Color8(208, 232, 248)
const BANK_DARK := Color8(96, 64, 40)
# Wood
const WOOD_DARK := Color8(88, 48, 24)
const WOOD_MID := Color8(136, 80, 40)
const WOOD_LIGHT := Color8(184, 128, 64)
const WOOD_END := Color8(232, 192, 120)
# Roof
const ROOF_DARK := Color8(112, 24, 32)
const ROOF_MID := Color8(176, 56, 40)
const ROOF_LIGHT := Color8(224, 96, 48)
const ROOF_SHINE := Color8(248, 152, 88)
# Walls and stone
const PLASTER := Color8(240, 216, 160)
const PLASTER_DARK := Color8(200, 160, 112)
const STONE_DARK := Color8(88, 96, 120)
const STONE_MID := Color8(136, 144, 160)
const STONE_LIGHT := Color8(184, 192, 200)
const GLASS := Color8(96, 152, 216)
# Crops
const SOIL_DARK := Color8(104, 56, 32)
const SOIL_LIGHT := Color8(144, 88, 48)
const WHEAT := Color8(248, 208, 72)
const WHEAT_DARK := Color8(200, 152, 40)
const LEAF := Color8(72, 160, 48)
# Dragon and fire
const D_DARK := Color8(120, 24, 40)
const D_MID := Color8(192, 48, 40)
const D_LIGHT := Color8(232, 96, 48)
const D_BELLY := Color8(248, 200, 104)
const D_WING := Color8(152, 40, 56)
const D_HORN := Color8(240, 232, 208)
const CHAR_DARK := Color8(40, 32, 32)
const CHAR_MID := Color8(64, 56, 48)
const ASH := Color8(96, 88, 80)
const EMBER := Color8(248, 112, 32)
const FIRE_RED := Color8(216, 48, 24)
const FIRE_ORANGE := Color8(248, 136, 24)
const FIRE_YELLOW := Color8(248, 224, 88)
# Roads
const ROAD_LIGHT := Color8(224, 192, 136)
const ROAD_MID := Color8(200, 160, 104)
const ROAD_EDGE := Color8(144, 104, 64)
# Interface
const NAVY := Color8(16, 16, 72)
const NAVY_LIGHT := Color8(40, 48, 120)
const GOLD := Color8(248, 208, 72)
const WHITE := Color8(248, 248, 248)
const GRAY := Color8(144, 152, 176)
const SKIN := Color8(248, 192, 136)
const TUNIC := Color8(56, 112, 200)

const FONT_COLUMNS := 16
const GLYPH_W := 7
const GLYPH_H := 9
const ATTRACTION_ICON := 16
## 5x7 glyphs, one 5-bit value per row.
const GLYPHS := {
	"A": [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11], "B": [0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E],
	"C": [0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E], "D": [0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E],
	"E": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F], "F": [0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10],
	"G": [0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F], "H": [0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11],
	"I": [0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E], "J": [0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C],
	"K": [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11], "L": [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F],
	"M": [0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11], "N": [0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11],
	"O": [0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E], "P": [0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10],
	"Q": [0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D], "R": [0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11],
	"S": [0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E], "T": [0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],
	"U": [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E], "V": [0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04],
	"W": [0x11, 0x11, 0x11, 0x15, 0x15, 0x1B, 0x11], "X": [0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11],
	"Y": [0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04], "Z": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F],
	"0": [0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E], "1": [0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
	"2": [0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F], "3": [0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
	"4": [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02], "5": [0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
	"6": [0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E], "7": [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
	"8": [0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E], "9": [0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
	".": [0, 0, 0, 0, 0, 0x0C, 0x0C], ",": [0, 0, 0, 0, 0x0C, 0x04, 0x08],
	":": [0, 0x0C, 0x0C, 0, 0x0C, 0x0C, 0], "'": [0x0C, 0x04, 0x08, 0, 0, 0, 0],
	"!": [0x04, 0x04, 0x04, 0x04, 0x04, 0, 0x04], "?": [0x0E, 0x11, 0x01, 0x02, 0x04, 0, 0x04],
	"(": [0x02, 0x04, 0x08, 0x08, 0x08, 0x04, 0x02], ")": [0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08],
	"-": [0, 0, 0, 0x1F, 0, 0, 0], "/": [0x01, 0x01, 0x02, 0x04, 0x08, 0x10, 0x10],
	"+": [0, 0x04, 0x04, 0x1F, 0x04, 0x04, 0],
}


func _init() -> void:
	_save_land()
	_save_water()
	_save_shore_corners()
	_save_buildings()
	_save_scorch()
	_save_fire()
	_save_dragon()
	_save_roads()
	_save_bridges()
	_save_boats()
	_save_villagers()
	_save_hero()
	_save_hero_shots()
	_save_cursor()
	_save_icons()
	_save_happiness_faces()
	_save_idle_mark()
	_save_attraction_icons()
	_save_panels()
	_save_font()
	quit()


# --- Drawing helpers ---

func _new_image(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h), color)


func _dot(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


func _ellipse(image: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			if pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1.0:
				_dot(image, x, y, color)


# --- Terrain ---

func _grass(image: Image, x0: int, tufts: int, tile_seed: int) -> void:
	_rect(image, x0, 0, CELL, CELL, G_MID)
	var rng := RandomNumberGenerator.new()
	rng.seed = tile_seed
	for i in range(tufts):
		var x := x0 + rng.randi_range(2, CELL - 5)
		var y := rng.randi_range(2, CELL - 4)
		_dot(image, x, y, G_DARK)
		_dot(image, x + 2, y, G_DARK)
		_dot(image, x + 1, y + 1, G_DARK)
		_dot(image, x + 1, y - 1, G_LIGHT)


func _flower(image: Image, x: int, y: int, petal: Color) -> void:
	for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		_dot(image, x + offset.x, y + offset.y, petal)
	_dot(image, x, y, GOLD)
	_dot(image, x, y + 2, G_DARK)


func _tree(image: Image, x0: int) -> void:
	_grass(image, x0, 2, 91)
	# Shadow and trunk.
	_ellipse(image, x0 + 16, 27, 11, 3.5, G_DARK)
	_rect(image, x0 + 13, 22, 6, 7, INK)
	_rect(image, x0 + 14, 22, 4, 6, WOOD_MID)
	_rect(image, x0 + 14, 22, 1, 6, WOOD_LIGHT)
	_rect(image, x0 + 17, 22, 1, 6, WOOD_DARK)
	# The canopy is built from overlapping lumps, outline first.
	var lumps: Array[Vector3] = [
		Vector3(16, 5.5, 5.5), Vector3(8.5, 8.5, 6), Vector3(23.5, 8.5, 6),
		Vector3(6.5, 15, 5.5), Vector3(25.5, 15, 5.5), Vector3(11, 18, 5.5),
		Vector3(21, 18, 5.5), Vector3(16, 12, 7),
	]
	for lump in lumps:
		_ellipse(image, x0 + lump.x, lump.y, lump.z + 1, lump.z + 1, T_INK)
	for lump in lumps:
		_ellipse(image, x0 + lump.x, lump.y, lump.z, lump.z, T_DARK)
	for lump in lumps:
		_ellipse(image, x0 + lump.x - 0.5, lump.y - 1, lump.z - 1, lump.z - 1.5, T_MID)
	for lump in lumps:
		_ellipse(image, x0 + lump.x - 1.5, lump.y - 2, lump.z * 0.4, lump.z * 0.3, T_LIGHT)


func _save_land() -> void:
	var image := _new_image(CELL * 6, CELL)
	_grass(image, 0, 3, 11)
	_grass(image, CELL, 5, 22)
	_grass(image, CELL * 2, 7, 33)
	_grass(image, CELL * 3, 3, 44)
	_flower(image, CELL * 3 + 9, 10, WHITE)
	_flower(image, CELL * 3 + 21, 19, WHITE)
	_flower(image, CELL * 3 + 12, 25, WHITE)
	_grass(image, CELL * 4, 3, 55)
	_flower(image, CELL * 4 + 22, 8, Color8(240, 112, 136))
	_flower(image, CELL * 4 + 8, 20, Color8(240, 112, 136))
	_tree(image, CELL * 5)
	image.save_png("res://assets/tiles/land.png")


## How far a pixel is from land, given which sides of the tile are land.
## Corners between two land sides are rounded.
func _distance_to_land(x: int, y: int, mask: int) -> float:
	var distance := 99.0
	if mask & 1: distance = minf(distance, y)
	if mask & 2: distance = minf(distance, CELL - 1 - x)
	if mask & 4: distance = minf(distance, CELL - 1 - y)
	if mask & 8: distance = minf(distance, x)
	var radius := 7.0
	var near_x := [x, CELL - 1 - x]
	var near_y := [y, CELL - 1 - y]
	for corner: Array in [[1, 8, 0, 0], [1, 2, 1, 0], [4, 8, 0, 1], [4, 2, 1, 1]]:
		if mask & corner[0] and mask & corner[1]:
			var dx: float = radius - near_x[corner[2]]
			var dy: float = radius - near_y[corner[3]]
			if dx > 0 and dy > 0:
				distance = minf(distance, radius - sqrt(dx * dx + dy * dy))
	return distance


## Mask bits say which sides are land: 1 north, 2 east, 4 south, 8 west.
## Each column is one mask and each row is one animation frame.
func _save_water() -> void:
	var image := _new_image(CELL * 16, CELL * WATER_FRAMES)
	var ripples: Array[Vector3i] = [
		Vector3i(4, 6, 5), Vector3i(19, 4, 6), Vector3i(11, 13, 4), Vector3i(25, 15, 5),
		Vector3i(3, 21, 6), Vector3i(16, 24, 5), Vector3i(27, 27, 3),
	]
	for mask in range(16):
		for frame in range(WATER_FRAMES):
			var x0 := mask * CELL
			var y0 := frame * CELL
			_rect(image, x0, y0, CELL, CELL, W_MID)
			for i in range(ripples.size()):
				var ripple := ripples[i]
				var shift := frame * (2 if i % 2 == 0 else -2)
				for dx in range(ripple.z):
					var x := posmod(ripple.x + shift + dx, CELL)
					image.set_pixel(x0 + x, y0 + ripple.y, W_LIGHT if i % 3 else W_DEEP)
			for y in range(CELL):
				for x in range(CELL):
					var distance := _distance_to_land(x, y, mask)
					if distance < 8.0:
						image.set_pixel(x0 + x, y0 + y, _shore_color(distance, x + y, frame))
	image.save_png("res://assets/tiles/water.png")


## Transparent overlays that round the shoreline where land touches a water
## cell only at a corner. Bits: 1 northeast, 2 southeast, 4 southwest, 8 northwest.
func _save_shore_corners() -> void:
	var image := _new_image(CELL * 16, CELL)
	var corners: Array[Vector2i] = [
		Vector2i(CELL - 1, 0), Vector2i(CELL - 1, CELL - 1), Vector2i(0, CELL - 1), Vector2i(0, 0),
	]
	for mask in range(16):
		for bit in range(corners.size()):
			if not mask & (1 << bit):
				continue
			for y in range(CELL):
				for x in range(CELL):
					var distance := Vector2(x, y).distance_to(corners[bit])
					if distance < 8.0:
						image.set_pixel(mask * CELL + x, y, _shore_color(distance, x + y, 0))
	image.save_png("res://assets/tiles/shore_corners.png")


func _shore_color(distance: float, foam_phase: int, frame: int) -> Color:
	if distance < 2.0:
		return G_MID
	if distance < 3.0:
		return G_DARK
	if distance < 5.0:
		return BANK_DARK
	if distance < 6.0:
		return W_FOAM if (foam_phase + frame * 2) % 6 < 4 else W_LIGHT
	return W_DEEP


# --- Buildings ---

func _shadow(image: Image, x: int, y: int, w: int) -> void:
	_rect(image, x, y, w, 2, G_DARK)


func _shingled_roof(image: Image, x0: int, top: int, bottom: int, inset: int) -> void:
	for y in range(top, bottom + 1):
		var taper := int((1.0 - float(y - top) / (bottom - top)) * inset)
		var left := x0 + 1 + taper
		var right := x0 + 30 - taper
		var course := (y - top) / 4
		for x in range(left, right + 1):
			var phase := posmod(x - x0 + course % 2 * 3, 6)
			var color := ROOF_LIGHT
			if (y - top) % 4 == 3:
				color = ROOF_MID if phase in [1, 2, 3, 4] else ROOF_DARK
			elif phase == 0:
				color = ROOF_MID
			elif (y - top) % 4 == 0 and phase in [2, 3]:
				color = ROOF_SHINE
			image.set_pixel(x, y, color)
		_dot(image, left - 1, y, INK)
		_dot(image, left, y, ROOF_MID)
		_dot(image, right + 1, y, INK)
		_dot(image, right, y, ROOF_DARK)
	var ridge_inset := inset
	_rect(image, x0 + ridge_inset, top - 1, 32 - ridge_inset * 2, 1, INK)
	_rect(image, x0 + ridge_inset + 1, top, 30 - ridge_inset * 2, 2, ROOF_SHINE)
	_rect(image, x0, bottom + 1, 32, 1, INK)
	_rect(image, x0 + 1, bottom, 30, 1, ROOF_DARK)


func _house(image: Image, x0: int) -> void:
	_shadow(image, x0 + 3, 45, 28)
	# Walls, base stones and timber frame.
	_rect(image, x0 + 3, 31, 26, 15, INK)
	_rect(image, x0 + 4, 31, 24, 14, PLASTER)
	_rect(image, x0 + 4, 33, 24, 1, PLASTER_DARK)
	_rect(image, x0 + 4, 41, 24, 4, STONE_MID)
	for x in range(x0 + 4, x0 + 28, 4):
		_rect(image, x, 41, 1, 4, STONE_DARK)
		_rect(image, x + 1, 41, 2, 1, STONE_LIGHT)
	_rect(image, x0 + 4, 31, 1, 11, WOOD_MID)
	_rect(image, x0 + 27, 31, 1, 11, WOOD_DARK)
	# Windows.
	for x: int in [x0 + 7, x0 + 21]:
		_rect(image, x - 1, 34, 6, 6, WOOD_DARK)
		_rect(image, x, 35, 4, 4, GLASS)
		_rect(image, x, 35, 2, 1, W_FOAM)
		_rect(image, x + 2, 35, 1, 4, WOOD_DARK)
	# Door.
	_rect(image, x0 + 13, 36, 6, 9, INK)
	_rect(image, x0 + 14, 35, 4, 1, INK)
	_rect(image, x0 + 14, 36, 4, 9, WOOD_MID)
	_rect(image, x0 + 15, 36, 1, 9, WOOD_DARK)
	_dot(image, x0 + 17, 40, GOLD)
	_rect(image, x0 + 12, 45, 8, 1, STONE_LIGHT)
	# Chimney, then the roof over its base.
	_rect(image, x0 + 21, 2, 7, 11, INK)
	_rect(image, x0 + 22, 3, 5, 10, STONE_MID)
	_rect(image, x0 + 22, 3, 1, 10, STONE_LIGHT)
	_rect(image, x0 + 26, 3, 1, 10, STONE_DARK)
	_shingled_roof(image, x0, 8, 30, 3)


func _farm(image: Image, x0: int) -> void:
	_shadow(image, x0 + 2, 46, 28)
	_rect(image, x0 + 2, 21, 28, 25, SOIL_LIGHT)
	for y in range(23, 45, 5):
		_rect(image, x0 + 2, y + 3, 28, 2, SOIL_DARK)
		for x in range(x0 + 4, x0 + 29, 4):
			_rect(image, x, y + 1, 1, 3, LEAF)
			_rect(image, x, y - 1, 2, 2, WHEAT)
			_dot(image, x + 1, y, WHEAT_DARK)
	# Fence around the field.
	for y: int in [20, 44]:
		_rect(image, x0 + 1, y, 30, 1, WOOD_LIGHT)
		_rect(image, x0 + 1, y + 1, 30, 1, WOOD_DARK)
	for x in range(x0 + 1, x0 + 31, 7):
		_rect(image, x, 18, 2, 5, INK)
		_rect(image, x, 18, 1, 4, WOOD_LIGHT)
		_rect(image, x, 42, 2, 6, INK)
		_rect(image, x, 42, 1, 5, WOOD_LIGHT)


func _log_end(image: Image, x: int, y: int) -> void:
	_ellipse(image, x, y, 3, 3, INK)
	_ellipse(image, x, y, 2, 2, WOOD_END)
	_dot(image, x, y, WOOD_MID)


func _lumber_camp(image: Image, x0: int) -> void:
	_shadow(image, x0 + 2, 45, 28)
	# Cabin walls made of stacked logs.
	_rect(image, x0 + 2, 29, 22, 17, INK)
	for y in range(30, 45, 3):
		_rect(image, x0 + 3, y, 20, 2, WOOD_MID)
		_rect(image, x0 + 3, y + 2, 20, 1, WOOD_DARK)
		_dot(image, x0 + 3, y, WOOD_END)
		_dot(image, x0 + 22, y, WOOD_END)
	_rect(image, x0 + 7, 36, 6, 9, INK)
	_rect(image, x0 + 8, 37, 4, 8, WOOD_DARK)
	_dot(image, x0 + 11, 41, GOLD)
	# Plank roof.
	_rect(image, x0, 11, 26, 19, INK)
	for x in range(x0 + 1, x0 + 25):
		var plank := WOOD_DARK if (x - x0) % 4 == 0 else WOOD_LIGHT if (x - x0) % 4 == 1 else WOOD_MID
		_rect(image, x, 12, 1, 16, plank)
	_rect(image, x0 + 1, 12, 24, 2, WOOD_END)
	_rect(image, x0 + 1, 27, 24, 2, WOOD_DARK)
	# Log pile.
	for log_end: Vector2i in [Vector2i(20, 43), Vector2i(26, 43), Vector2i(23, 38), Vector2i(29, 38)]:
		_log_end(image, x0 + log_end.x, log_end.y)


func _well(image: Image, x0: int) -> void:
	_shadow(image, x0 + 4, 45, 25)
	# Round stone wall with water inside.
	_ellipse(image, x0 + 16, 37, 12, 6, STONE_LIGHT)
	_ellipse(image, x0 + 16, 37, 9, 4, W_DEEP)
	_ellipse(image, x0 + 16, 37.5, 6, 2, W_MID)
	_rect(image, x0 + 4, 37, 24, 8, STONE_MID)
	for row in range(2):
		for x in range(x0 + 4 + row * 2, x0 + 28, 4):
			_rect(image, x, 39 + row * 3, 1, 2, STONE_DARK)
	_rect(image, x0 + 4, 37, 24, 1, STONE_LIGHT)
	# Posts, crossbar, rope and bucket.
	_rect(image, x0 + 5, 16, 2, 22, WOOD_MID)
	_rect(image, x0 + 25, 16, 2, 22, WOOD_DARK)
	_rect(image, x0 + 5, 20, 22, 2, WOOD_LIGHT)
	_rect(image, x0 + 15, 22, 1, 9, WOOD_END)
	_rect(image, x0 + 13, 30, 5, 4, WOOD_MID)
	_rect(image, x0 + 13, 30, 5, 1, WOOD_LIGHT)
	# Little shingled roof.
	_polygon(image, x0, [Vector2(2, 18), Vector2(16, 6), Vector2(30, 18)], ROOF_MID)
	_polygon(image, x0, [Vector2(5, 17), Vector2(16, 8), Vector2(27, 17)], ROOF_LIGHT)
	for y in range(10, 18, 3):
		_rect(image, x0 + 16 - (y - 6), y, (y - 6) * 2, 1, ROOF_MID)
	_rect(image, x0 + 2, 18, 29, 1, ROOF_DARK)
	_outline(image, x0, CELL)


func _tower(image: Image, x0: int) -> void:
	_shadow(image, x0 + 6, 45, 22)
	# Stone shaft, lit from the left.
	_rect(image, x0 + 8, 14, 16, 32, STONE_MID)
	_rect(image, x0 + 8, 14, 3, 32, STONE_LIGHT)
	_rect(image, x0 + 21, 14, 3, 32, STONE_DARK)
	for row in range(8):
		var y := 16 + row * 4
		_rect(image, x0 + 8, y, 16, 1, STONE_DARK)
		_rect(image, x0 + 12 + row % 2 * 4, y - 3, 1, 3, STONE_DARK)
	# Door and window slit.
	_rect(image, x0 + 13, 38, 6, 8, INK)
	_rect(image, x0 + 14, 39, 4, 7, WOOD_DARK)
	_rect(image, x0 + 15, 23, 2, 6, INK)
	# Water tank with battlements and a nozzle.
	_rect(image, x0 + 4, 6, 24, 9, WOOD_MID)
	_rect(image, x0 + 4, 6, 24, 1, WOOD_LIGHT)
	for x in range(x0 + 4, x0 + 28, 4):
		_rect(image, x, 7, 1, 8, WOOD_DARK)
	_rect(image, x0 + 4, 9, 24, 2, STONE_LIGHT)
	_ellipse(image, x0 + 16, 5, 10, 2, W_MID)
	_rect(image, x0 + 12, 4, 4, 1, W_FOAM)
	for x in range(x0 + 4, x0 + 28, 6):
		_rect(image, x, 1, 3, 4, STONE_MID)
	_rect(image, x0 + 27, 10, 4, 2, STONE_DARK)
	_rect(image, x0 + 30, 9, 1, 4, W_LIGHT)
	_outline(image, x0, CELL)


func _training_center(image: Image, x0: int) -> void:
	_shadow(image, x0 + 2, 45, 28)
	# Plank hall with a slate roof.
	_rect(image, x0 + 2, 28, 20, 18, WOOD_MID)
	for x in range(x0 + 2, x0 + 22, 3):
		_rect(image, x, 28, 1, 18, WOOD_DARK)
	_rect(image, x0 + 9, 36, 6, 10, INK)
	_rect(image, x0 + 10, 37, 4, 9, WOOD_DARK)
	_polygon(image, x0, [Vector2(0, 29), Vector2(12, 16), Vector2(24, 29)], STONE_DARK)
	_polygon(image, x0, [Vector2(3, 28), Vector2(12, 18), Vector2(21, 28)], STONE_MID)
	for y in range(21, 28, 3):
		_rect(image, x0 + 12 - (y - 16), y, (y - 16) * 2, 1, STONE_DARK)
	# Banner pole with a blue water-drop flag.
	_rect(image, x0 + 25, 6, 1, 40, WOOD_DARK)
	_rect(image, x0 + 26, 7, 6, 8, TUNIC)
	_rect(image, x0 + 28, 9, 2, 3, W_FOAM)
	# Practice target: a straw dummy and a water bucket.
	_rect(image, x0 + 27, 36, 1, 9, WOOD_DARK)
	_ellipse(image, x0 + 27.5, 33, 3, 3, WHEAT)
	_rect(image, x0 + 24, 37, 7, 2, WHEAT_DARK)
	_rect(image, x0 + 22, 42, 4, 4, WOOD_MID)
	_rect(image, x0 + 22, 42, 4, 1, W_LIGHT)
	_outline(image, x0, CELL)


## A plank pier standing on posts in the water. The gaps between planks are
## left see-through so the water tile below shows. Only the bottom CELL rows
## are its own cell; posts and a crate rise a little above it.
func _docks(image: Image, x0: int) -> void:
	# Posts standing in the water, with a ripple where they meet it.
	for x: int in [2, 14, 26]:
		_rect(image, x0 + x - 1, 44, 6, 1, W_FOAM)
		_rect(image, x0 + x, 40, 4, 4, INK)
		_rect(image, x0 + x + 1, 40, 2, 4, WOOD_DARK)
		_dot(image, x0 + x + 1, 42, WOOD_MID)
	# Planks running out over the water, with ragged ends and gaps between.
	for plank in range(6):
		var left := x0 + 1 + plank * 5
		var top := 19 + plank % 2
		var bottom := 40 - (plank + 1) % 2 * 2
		_rect(image, left, top - 1, 5, bottom - top + 2, INK)
		_rect(image, left + 1, top, 3, bottom - top, WOOD_MID if plank % 3 == 1 else WOOD_LIGHT)
		_rect(image, left + 1, bottom - 1, 3, 1, WOOD_DARK)
		_dot(image, left + 2, top + 1, WOOD_END)
		_dot(image, left + 2, bottom - 3, WOOD_END)
	# A beam across the front, holding the planks together.
	_rect(image, x0, 36, 32, 4, INK)
	_rect(image, x0 + 1, 37, 30, 2, WOOD_DARK)
	_rect(image, x0 + 1, 37, 30, 1, WOOD_MID)
	# Mooring posts on the back corners, one with a coil of rope.
	for x: int in [1, 27]:
		_rect(image, x0 + x, 12, 4, 10, INK)
		_rect(image, x0 + x + 1, 13, 2, 8, WOOD_MID)
		_rect(image, x0 + x + 1, 13, 2, 1, WOOD_END)
	_rect(image, x0 + 27, 16, 4, 2, WHEAT_DARK)
	# A crate of fish.
	_rect(image, x0 + 15, 20, 11, 9, INK)
	_rect(image, x0 + 16, 21, 9, 7, WOOD_DARK)
	_rect(image, x0 + 17, 22, 7, 4, STONE_DARK)
	for fish: Vector2i in [Vector2i(17, 22), Vector2i(19, 24), Vector2i(18, 23)]:
		_rect(image, x0 + fish.x, fish.y, 4, 1, STONE_LIGHT)
		_dot(image, x0 + fish.x + 4, fish.y, STONE_MID)
	_rect(image, x0 + 16, 26, 9, 1, WOOD_LIGHT)


## A stairway down to the underground playground, under a striped fairground arch.
func _playground(image: Image, x0: int) -> void:
	_shadow(image, x0 + 3, 45, 27)
	# Stone-lined stairwell, its far steps fading into the dark below.
	_rect(image, x0 + 7, 26, 18, 20, INK)
	_rect(image, x0 + 8, 27, 16, 18, STONE_MID)
	_rect(image, x0 + 8, 27, 16, 1, STONE_LIGHT)
	var steps := [CHAR_DARK, NAVY, NAVY_LIGHT, STONE_DARK, STONE_MID]
	for index in range(steps.size()):
		var y := 28 + index * 3
		_rect(image, x0 + 10, y, 12, 3, steps[index])
		_rect(image, x0 + 10, y + 2, 12, 1, INK if index < 2 else STONE_DARK if index > 2 else NAVY)
	_rect(image, x0 + 10, 43, 12, 2, STONE_LIGHT)
	# Candy-striped posts.
	for post_x: int in [x0 + 3, x0 + 25]:
		_rect(image, post_x - 1, 13, 6, 33, INK)
		for y in range(14, 45):
			var red := (y / 3) % 2 == 0
			_rect(image, post_x, y, 3, 1, ROOF_MID if red else WHITE)
			_rect(image, post_x + 3, y, 1, 1, ROOF_DARK if red else GRAY)
	# Golden sign board with a row of lights.
	_rect(image, x0 + 1, 6, 30, 10, INK)
	_rect(image, x0 + 2, 7, 28, 8, ROOF_DARK)
	_rect(image, x0 + 3, 8, 26, 6, GOLD)
	_rect(image, x0 + 3, 13, 26, 1, WHEAT_DARK)
	for x in range(x0 + 5, x0 + 28, 4):
		_dot(image, x, 10, ROOF_MID)
		_dot(image, x + 1, 10, W_MID)
	# Pennants on top.
	for flag: Array in [[4, ROOF_MID], [11, W_MID], [18, LEAF], [25, ROOF_MID]]:
		var left: int = flag[0]
		_polygon(image, x0, [Vector2(left, 1), Vector2(left + 4, 1), Vector2(left + 2, 5)], flag[1])
	_rect(image, x0 + 3, 1, 26, 1, WOOD_DARK)
	_outline(image, x0, CELL)


func _save_buildings() -> void:
	var image := _new_image(CELL * 8, BUILDING_H)
	_house(image, 0)
	_farm(image, CELL)
	_lumber_camp(image, CELL * 2)
	_well(image, CELL * 3)
	_tower(image, CELL * 4)
	_training_center(image, CELL * 5)
	_docks(image, CELL * 6)
	_playground(image, CELL * 7)
	image.save_png("res://assets/tiles/buildings.png")


# --- Dragon ---

func _polygon(image: Image, x0: int, points: Array, color: Color) -> void:
	var polygon := PackedVector2Array(points)
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	for y in range(int(bounds.position.y), int(bounds.end.y) + 1):
		for x in range(int(bounds.position.x), int(bounds.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
				_dot(image, x0 + x, y, color)


## Puts an ink outline around everything already drawn in one frame.
func _outline(image: Image, x0: int, w: int) -> void:
	var outside: Array[Vector2i] = []
	for y in range(image.get_height()):
		for x in range(x0, x0 + w):
			if image.get_pixel(x, y).a > 0.0:
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor := Vector2i(x, y) + offset
				if (
					neighbor.x >= x0 and neighbor.x < x0 + w
					and neighbor.y >= 0 and neighbor.y < image.get_height()
					and image.get_pixelv(neighbor).a > 0.0
				):
					outside.append(Vector2i(x, y))
					break
	for cell in outside:
		image.set_pixelv(cell, INK)


func _wing(image: Image, x0: int, raised: bool) -> void:
	var shoulder := Vector2(34, 28)
	var root := Vector2(50, 30)
	var tips: Array[Vector2]
	if raised:
		tips = [Vector2(16, 5), Vector2(28, 2), Vector2(42, 1), Vector2(54, 9)]
	else:
		tips = [Vector2(13, 47), Vector2(25, 53), Vector2(39, 54), Vector2(52, 44)]
	var previous := shoulder
	var valley := Vector2(25, 16) if raised else Vector2(24, 38)
	_polygon(image, x0, [shoulder, tips[0], valley], D_WING)
	for index in range(tips.size() - 1):
		var a := tips[index]
		var b := tips[index + 1]
		var notch := (a + b) / 2.0 + (shoulder - (a + b) / 2.0) * 0.18
		_polygon(image, x0, [shoulder, a, notch], D_WING)
		_polygon(image, x0, [shoulder, notch, b], D_MID if index == 1 else D_WING)
		previous = b
	_polygon(image, x0, [shoulder, previous, root], D_WING)
	# Finger bones.
	for tip in tips:
		for step in range(21):
			var point := shoulder.lerp(tip, step / 20.0)
			_dot(image, x0 + int(point.x), int(point.y), D_LIGHT)


func _dragon_frame(image: Image, x0: int, raised: bool) -> void:
	_wing(image, x0, raised)
	# Tail, tapering from the body with a spade tip.
	for step in range(13):
		var t := step / 12.0
		var center := Vector2(32, 31).lerp(Vector2(7, 24), t)
		center.y += sin(t * 3.0) * 3.0
		_ellipse(image, x0 + center.x, center.y, lerpf(5.0, 1.2, t), lerpf(4.5, 1.2, t), D_MID)
	_polygon(image, x0, [Vector2(9, 24), Vector2(1, 18), Vector2(2, 28)], D_LIGHT)
	# Body, neck and head.
	_ellipse(image, x0 + 40, 30, 11, 7.5, D_MID)
	for step in range(9):
		var t := step / 8.0
		_ellipse(image, x0 + lerpf(48, 60, t), lerpf(26, 15, t), lerpf(5.0, 3.2, t), lerpf(5.0, 3.2, t), D_MID)
	_ellipse(image, x0 + 64, 13, 6, 4.5, D_MID)
	_polygon(image, x0, [Vector2(66, 10), Vector2(76, 13), Vector2(66, 16)], D_MID)
	_polygon(image, x0, [Vector2(65, 16), Vector2(74, 16), Vector2(66, 19)], D_DARK)
	# Shading, belly and back plates.
	_ellipse(image, x0 + 41, 34, 8.5, 3.0, D_BELLY)
	_ellipse(image, x0 + 38, 25.5, 6.0, 1.5, D_LIGHT)
	for step in range(5):
		var t := step / 4.0
		_ellipse(image, x0 + lerpf(52, 62, t) + 1, lerpf(27, 18, t), 1.5, 1.5, D_BELLY)
	for x in range(26, 50, 4):
		_polygon(image, x0, [Vector2(x, 25), Vector2(x + 1, 20), Vector2(x + 3, 25)], D_DARK)
	# Horns, eye and nostril.
	_polygon(image, x0, [Vector2(60, 10), Vector2(54, 3), Vector2(63, 9)], D_HORN)
	_polygon(image, x0, [Vector2(64, 9), Vector2(60, 2), Vector2(67, 9)], D_HORN)
	_rect(image, x0 + 65, 11, 2, 2, FIRE_YELLOW)
	_dot(image, x0 + 66, 12, INK)
	_dot(image, x0 + 73, 13, INK)
	_outline(image, x0, 80)


func _save_dragon() -> void:
	# Row 1 is the level 1 dragon. Row 2 recolors it for the level 2 dragon.
	var image := _new_image(160, 112)
	var frames := _new_image(160, 56)
	_dragon_frame(frames, 0, true)
	_dragon_frame(frames, 80, false)
	image.blit_rect(frames, Rect2i(0, 0, 160, 56), Vector2i.ZERO)
	var level_2_colors := {
		D_DARK: Color8(40, 24, 72), D_MID: Color8(88, 56, 152), D_LIGHT: Color8(136, 104, 208),
		D_BELLY: Color8(192, 232, 112), D_WING: Color8(64, 40, 112), D_HORN: Color8(248, 216, 96),
	}
	for y in range(56):
		for x in range(160):
			var color := frames.get_pixel(x, y)
			frames.set_pixel(x, y, level_2_colors.get(color, color))
	image.blit_rect(frames, Rect2i(0, 0, 160, 56), Vector2i(0, 56))
	image.save_png("res://assets/tiles/dragon.png")

	var shadow := _new_image(80, 40)
	var color := Color(T_INK, 0.5)
	_ellipse(shadow, 42, 20, 13, 6, color)
	_ellipse(shadow, 14, 20, 12, 2, color)
	_ellipse(shadow, 62, 19, 9, 3, color)
	_ellipse(shadow, 36, 20, 7, 17, color)
	shadow.save_png("res://assets/tiles/dragon_shadow.png")


func _save_fire() -> void:
	var image := _new_image(CELL * 3, 40)
	for frame in range(3):
		var x0 := frame * CELL
		var sway: int = [-1, 1, 0][frame]
		_ellipse(image, x0 + 16, 29, 12, 9, FIRE_RED)
		_ellipse(image, x0 + 16 + sway, 20, 8, 13, FIRE_RED)
		_ellipse(image, x0 + 16 + sway * 2, 9, 3, 7, FIRE_RED)
		_ellipse(image, x0 + 8 - sway, 21, 3, 7, FIRE_ORANGE)
		_ellipse(image, x0 + 24 + sway, 19, 3, 8, FIRE_ORANGE)
		_ellipse(image, x0 + 16, 29, 9, 7, FIRE_ORANGE)
		_ellipse(image, x0 + 16 + sway, 22, 5, 9, FIRE_ORANGE)
		_ellipse(image, x0 + 16, 31, 5, 5, FIRE_YELLOW)
		_ellipse(image, x0 + 16 - sway, 25, 2.5, 5, FIRE_YELLOW)
		_outline(image, x0, CELL)
	image.save_png("res://assets/tiles/fire.png")

	var splash := _new_image(8, 8)
	_ellipse(splash, 3.5, 3.5, 2.5, 2.5, W_LIGHT)
	_dot(splash, 2, 2, W_FOAM)
	_dot(splash, 3, 2, W_FOAM)
	_outline(splash, 0, 8)
	splash.save_png("res://assets/tiles/splash.png")


## Bits say which sides get a rough edge: 1 north, 2 east, 4 south, 8 west.
func _save_scorch() -> void:
	var image := _new_image(CELL * 16, CELL)
	for mask in range(16):
		var x0 := mask * CELL
		# Same seed for every mask, so neighboring tiles match where they meet.
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for y in range(CELL):
			for x in range(CELL):
				var roll := rng.randf()
				var jagged := rng.randf()
				var sides := [y, CELL - 1 - x, CELL - 1 - y, x]
				var keep := true
				for side in range(4):
					if mask & (1 << side) and (sides[side] == 0 or (sides[side] == 1 and jagged < 0.5)):
						keep = false
					elif mask & (1 << side) and sides[side] == 2 and jagged < 0.2:
						keep = false
				if keep:
					image.set_pixel(x0 + x, y, CHAR_DARK if roll < 0.55 else CHAR_MID)
		for i in range(9):
			_ash_if_burned(image, x0 + rng.randi_range(4, CELL - 6), rng.randi_range(4, CELL - 5), ASH)
			_ash_if_burned(image, x0 + rng.randi_range(4, CELL - 6), rng.randi_range(4, CELL - 5), EMBER if i < 4 else ASH)
	image.save_png("res://assets/tiles/scorch.png")


func _ash_if_burned(image: Image, x: int, y: int, color: Color) -> void:
	if image.get_pixel(x, y).a > 0.0:
		image.set_pixel(x, y, color)


# --- Roads ---

## Whether a pixel is on a road tile. Bits say which sides join another road:
## 1 north, 2 east, 4 south, 8 west.
func _on_road(x: int, y: int, joined: int) -> bool:
	const LOW := 5
	const HIGH := CELL - 6
	if x < 0 or y < 0 or x >= CELL or y >= CELL:
		return true
	var in_x := x >= LOW and x <= HIGH
	var in_y := y >= LOW and y <= HIGH
	if in_x and in_y:
		var left := x < LOW + 2
		var right := x > HIGH - 2
		var top := y < LOW + 2
		var bottom := y > HIGH - 2
		if (left and top and not joined & 9) or (right and top and not joined & 3):
			return false
		if (left and bottom and not joined & 12) or (right and bottom and not joined & 6):
			return false
		return true
	if in_x:
		return (y < LOW and joined & 1) or (y > HIGH and joined & 4)
	if in_y:
		return (x > HIGH and joined & 2) or (x < LOW and joined & 8)
	return false


func _save_roads() -> void:
	var image := _new_image(CELL * 16, CELL)
	for joined in range(16):
		var x0 := joined * CELL
		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		for y in range(CELL):
			for x in range(CELL):
				var roll := rng.randf()
				if not _on_road(x, y, joined):
					continue
				var at_edge := false
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if not _on_road(x + offset.x, y + offset.y, joined):
						at_edge = true
				var color := ROAD_LIGHT if roll > 0.12 else ROAD_MID
				image.set_pixel(x0 + x, y, ROAD_EDGE if at_edge else color)
	image.save_png("res://assets/tiles/roads.png")


# --- Bridges ---

## Planks lie across the direction of travel, so the arms decide which way they run.
func _plank_color(x: int, y: int, joined: int) -> Color:
	const LOW := 5
	const HIGH := CELL - 6
	var north_south_arm := y < LOW or y > HIGH
	var east_west_arm := x < LOW or x > HIGH
	var runs_east_west := east_west_arm or (not north_south_arm and joined & 10 and not joined & 5)
	var along := x if runs_east_west else y
	if along % 4 == 3:
		return WOOD_DARK
	return WOOD_MID if (along / 4) % 3 == 1 else WOOD_LIGHT


## The same shapes as roads, so the two line up where they meet.
func _save_bridges() -> void:
	var image := _new_image(CELL * 16, CELL)
	for joined in range(16):
		var x0 := joined * CELL
		for y in range(CELL):
			for x in range(CELL):
				if not _on_road(x, y, joined):
					if y > 0 and y < CELL - 1 and _on_road(x, y - 1, joined):
						image.set_pixel(x0 + x, y, W_DEEP)
					continue
				var at_edge := false
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if not _on_road(x + offset.x, y + offset.y, joined):
						at_edge = true
				if at_edge:
					image.set_pixel(x0 + x, y, WOOD_END if (x + y) % 8 == 0 else WOOD_DARK)
				else:
					image.set_pixel(x0 + x, y, _plank_color(x, y, joined))
	image.save_png("res://assets/tiles/bridges.png")


# --- Boats ---

const BOAT := 16
## Boat sheet columns: across, across with a stroke of the oars, up and down,
## up and down with a stroke. Rows: empty, someone rowing, someone fishing.
const BOAT_COLUMNS := 4
const BOAT_ROWS := 3


func _line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step in range(steps + 1):
		var point := Vector2(from).lerp(Vector2(to), float(step) / maxi(steps, 1)).round()
		_dot(image, int(point.x), int(point.y), color)


func _boat_frame(across: bool, stroke: int, rider: int) -> Image:
	var image := _new_image(BOAT, BOAT)
	var center := Vector2(7.5, 9.0) if across else Vector2(7.5, 8.0)
	var radius := Vector2(7.0, 3.5) if across else Vector2(3.5, 7.0)
	_ellipse(image, center.x, center.y, radius.x, radius.y, WOOD_DARK)
	_ellipse(image, center.x, center.y - 0.5, radius.x - 0.5, radius.y - 0.5, WOOD_MID)
	_ellipse(image, center.x, center.y - 0.5, radius.x - 2.0, radius.y - 2.0, WOOD_DARK)
	var bench := Vector2i(center.round())
	if across:
		_rect(image, bench.x - 1, bench.y - 2, 2, 4, WOOD_LIGHT)
	else:
		_rect(image, bench.x - 2, bench.y - 1, 4, 2, WOOD_LIGHT)
	if rider == 1:
		# Oars out to both sides, swept back and forth.
		var sweep := 2 if stroke else -2
		if across:
			_line(image, bench + Vector2i(0, -2), bench + Vector2i(sweep, -7), WOOD_END)
			_line(image, bench + Vector2i(0, 2), bench + Vector2i(sweep, 6), WOOD_END)
		else:
			_line(image, bench + Vector2i(-2, 0), bench + Vector2i(-7, sweep), WOOD_END)
			_line(image, bench + Vector2i(2, 0), bench + Vector2i(7, sweep), WOOD_END)
	if rider > 0:
		# Someone sitting on the bench, seen from above.
		_rect(image, bench.x - 2, bench.y - 2, 4, 3, TUNIC)
		_rect(image, bench.x - 2, bench.y - 5, 4, 4, SKIN)
		_rect(image, bench.x - 2, bench.y - 5, 4, 2, WOOD_DARK)
	if rider == 2:
		# A rod held out over the side, its line bobbing.
		var tip := Vector2i(15, 1) if across else Vector2i(14, 2)
		_line(image, bench + Vector2i(1, -3), tip, WOOD_DARK)
		_line(image, tip, tip + Vector2i(0, 4 + stroke), W_FOAM)
		_dot(image, tip.x, tip.y + 5 + stroke, ROOF_MID)
	_outline(image, 0, BOAT)
	# The boat's shadow on the water, only where nothing else is drawn.
	var shadow := _new_image(BOAT, BOAT)
	_ellipse(shadow, center.x, center.y + 2.0, radius.x, radius.y, W_DEEP)
	for y in range(BOAT):
		for x in range(BOAT):
			if image.get_pixel(x, y).a == 0.0 and shadow.get_pixel(x, y).a > 0.0:
				image.set_pixel(x, y, W_DEEP)
	return image


## Rowing boats for the docks, in a sheet of their own.
func _save_boats() -> void:
	var image := _new_image(BOAT * BOAT_COLUMNS, BOAT * BOAT_ROWS)
	for rider in range(BOAT_ROWS):
		for column in range(BOAT_COLUMNS):
			var frame := _boat_frame(column < 2, column % 2, rider)
			image.blit_rect(frame, Rect2i(0, 0, BOAT, BOAT), Vector2i(column * BOAT, rider * BOAT))
	image.save_png("res://assets/tiles/boats.png")


# --- Villagers ---

## Draws one 12x16 frame. Direction: 0 down, 1 up, 2 side. Step: 0 or 1.
func _villager_frame(direction: int, step: int, tunic: Color, tunic_dark: Color, hair: Color, helmet := false) -> Image:
	var image := _new_image(12, 16)
	# Legs, alternating on each step.
	if direction == 2:
		_rect(image, 3 + step * 2, 12, 2, 3, WOOD_DARK)
		_rect(image, 7 - step * 2, 12, 2, 3, WOOD_DARK)
	else:
		_rect(image, 3, 12, 2, 3 - step, WOOD_DARK)
		_rect(image, 7, 12, 2, 2 + step, WOOD_DARK)
	# Body.
	_rect(image, 2, 8, 8, 5, tunic)
	_rect(image, 2, 12, 8, 1, tunic_dark)
	_rect(image, 1, 8, 1, 3, SKIN if direction != 2 else tunic)
	_rect(image, 10, 8, 1, 3, SKIN if direction != 2 else tunic)
	# Head with hair.
	_rect(image, 2, 2, 8, 6, SKIN)
	_rect(image, 3, 1, 6, 1, hair)
	_rect(image, 2, 2, 8, 2, hair)
	if direction == 0:
		_dot(image, 4, 5, INK)
		_dot(image, 7, 5, INK)
	elif direction == 1:
		_rect(image, 2, 2, 8, 5, hair)
	else:
		_rect(image, 2, 2, 3, 5, hair)
		_dot(image, 8, 5, INK)
	if helmet:
		_rect(image, 2, 1, 8, 3, STONE_LIGHT)
		_rect(image, 2, 3, 8, 1, STONE_MID)
		_rect(image, 5, 0, 2, 1, ROOF_MID)
	_outline(image, 0, 12)
	return image


func _save_villagers() -> void:
	var looks: Array[Array] = [
		[LEAF, Color8(40, 112, 40), WOOD_MID],
		[TUNIC, W_DEEP, Color8(248, 216, 96)],
		[ROOF_MID, ROOF_DARK, INK],
		[Color8(136, 88, 168), Color8(96, 56, 128), WOOD_DARK],
		# Trained fighters.
		[TUNIC, W_DEEP, WOOD_MID, true],
	]
	var image := _new_image(12 * 6, 16 * looks.size())
	for row in range(looks.size()):
		var look: Array = looks[row]
		for direction in range(3):
			for step in range(2):
				var frame := _villager_frame(direction, step, look[0], look[1], look[2], look.size() > 3)
				var at := Vector2i((direction * 2 + step) * 12, row * 16)
				image.blit_rect(frame, Rect2i(0, 0, 12, 16), at)
	image.save_png("res://assets/tiles/villagers.png")


# --- Hero ---

const HERO_W := 16
const HERO_H := 20
## Where a villager-sized figure sits in a hero frame, leaving room for weapons.
const HERO_X := 2
const HERO_Y := 4
const HERO_SHOT := 12
## Skin, hair, cape, dark cape. In the order of Hero.LOOKS.
var _hero_looks: Array[Array] = [
	[SKIN, Color8(216, 72, 32), ROOF_MID, ROOF_DARK],
	[Color8(136, 88, 56), Color8(48, 40, 56), GOLD, WHEAT_DARK],
	[Color8(224, 168, 120), Color8(216, 224, 240), Color8(40, 152, 152), Color8(24, 104, 112)],
]


func _hero_torso(image: Image, direction: int, armor: int, skin: Color) -> void:
	var x := HERO_X + 2
	var y := HERO_Y + 8
	match armor:
		0: # Leather: a laced vest over bare arms.
			_rect(image, x, y, 8, 5, WOOD_MID)
			_rect(image, x, y + 3, 8, 1, WOOD_DARK)
			if direction == 0:
				_rect(image, x + 3, y, 2, 3, WOOD_END)
		1: # Chainmail: checkered rings and matching sleeves.
			_rect(image, x, y, 8, 5, STONE_MID)
			for ring_y in range(y, y + 5):
				for ring_x in range(x + (ring_y % 2), x + 8, 2):
					_dot(image, ring_x, ring_y, STONE_LIGHT)
			_rect(image, x, y + 4, 8, 1, WOOD_DARK)
		2: # Dragonscale: red scales, a golden chest and big shoulders.
			_rect(image, x, y, 8, 5, D_DARK)
			for scale_y in range(y, y + 5):
				for scale_x in range(x + (scale_y % 2), x + 8, 2):
					_dot(image, scale_x, scale_y, D_MID)
			if direction == 0:
				_rect(image, x + 2, y + 1, 4, 2, D_BELLY)
	var arm: Color = [skin, STONE_MID, D_DARK][armor]
	if direction != 2:
		_rect(image, x - 1, y, 1, 3, arm)
		_rect(image, x + 8, y, 1, 3, arm)
	if armor == 2:
		_rect(image, x - 1, y - 1, 3, 2, D_LIGHT)
		_rect(image, x + 6, y - 1, 3, 2, D_LIGHT)


func _hero_head(image: Image, direction: int, look: int) -> void:
	var details: Array = _hero_looks[look]
	var hair: Color = details[1]
	var x := HERO_X + 2
	var y := HERO_Y
	_rect(image, x, y + 2, 8, 6, details[0])
	_rect(image, x + 1, y + 1, 6, 1, hair)
	_rect(image, x, y + 2, 8, 2, hair)
	if direction == 0:
		_dot(image, x + 2, y + 5, INK)
		_dot(image, x + 5, y + 5, INK)
	elif direction == 1:
		_rect(image, x, y + 2, 8, 5, hair)
	else:
		_rect(image, x, y + 2, 3, 5, hair)
		_dot(image, x + 6, y + 5, INK)
	match look:
		0: # Ember: spiky.
			_dot(image, x + 1, y, hair)
			_dot(image, x + 4, y, hair)
			_dot(image, x + 6, y, hair)
		1: # Raven: topknot and a gold band.
			_rect(image, x + 3, y - 1, 2, 2, hair)
			_rect(image, x, y + 3, 8, 1, GOLD)
		2: # Frost: long hair.
			_rect(image, x, y + 3, 1, 7, hair)
			if direction != 2:
				_rect(image, x + 7, y + 3, 1, 7, hair)


func _hero_weapon(image: Image, direction: int, weapon: int) -> void:
	# Carried on the right, except from behind, where that hand is on the left.
	var x := 1 if direction == 1 else 13
	match weapon:
		0: # Longsword.
			_rect(image, x, 2, 2, 11, STONE_LIGHT)
			_rect(image, x + 1, 2, 1, 11, WHITE)
			_rect(image, x - 1, 13, 4, 1, GOLD)
			_rect(image, x, 14, 2, 2, WOOD_DARK)
		1: # Longbow.
			_rect(image, x, 3, 1, 14, W_FOAM)
			for bow_y in range(3, 17):
				var bend := roundi(sin((bow_y - 3) / 13.0 * PI) * 2.0)
				_dot(image, x + (bend if direction != 1 else -bend), bow_y, WOOD_LIGHT)
		2: # Battle axe.
			_rect(image, x, 2, 1, 15, WOOD_MID)
			_rect(image, x - 2, 3, 5, 4, STONE_MID)
			_rect(image, x - 2, 3, 1, 4, STONE_LIGHT)
			_rect(image, x + 2, 3, 1, 4, STONE_LIGHT)


## Draws one frame. Direction: 0 down, 1 up, 2 side. Step: 0 or 1.
func _hero_frame(direction: int, step: int, armor: int, weapon: int, look: int) -> Image:
	var image := _new_image(HERO_W, HERO_H)
	var details: Array = _hero_looks[look]
	# The cape hangs behind everything else.
	_rect(image, HERO_X + 1, HERO_Y + 8, 10, 7, details[3])
	var boots: Color = [WOOD_DARK, STONE_DARK, D_DARK][armor]
	var legs_y := HERO_Y + 12
	if direction == 2:
		_rect(image, HERO_X, HERO_Y + 8, 2, 7, details[3])
		_rect(image, HERO_X + 3 + step * 2, legs_y, 2, 3, boots)
		_rect(image, HERO_X + 7 - step * 2, legs_y, 2, 3, boots)
	else:
		_rect(image, HERO_X + 3, legs_y, 2, 3 - step, boots)
		_rect(image, HERO_X + 7, legs_y, 2, 2 + step, boots)
	_hero_torso(image, direction, armor, details[0])
	_hero_head(image, direction, look)
	if direction == 1:
		_rect(image, HERO_X + 2, HERO_Y + 8, 8, 6, details[2])
	_hero_weapon(image, direction, weapon)
	_outline(image, 0, HERO_W)
	return image


## One row per combination, in the order of Hero.sprite_row_for().
func _save_hero() -> void:
	var image := _new_image(HERO_W * 6, HERO_H * 27)
	for armor in range(3):
		for weapon in range(3):
			for look in range(3):
				var row := armor * 9 + weapon * 3 + look
				for direction in range(3):
					for step in range(2):
						var frame := _hero_frame(direction, step, armor, weapon, look)
						var at := Vector2i((direction * 2 + step) * HERO_W, row * HERO_H)
						image.blit_rect(frame, Rect2i(0, 0, HERO_W, HERO_H), at)
	image.save_png("res://assets/tiles/hero.png")


## Sword slash, arrow pointing right and axe impact, in the order of Hero.WEAPONS.
func _save_hero_shots() -> void:
	var image := _new_image(HERO_SHOT * 3, HERO_SHOT)
	_ellipse(image, 6, 6, 5, 5, W_FOAM)
	_ellipse(image, 3, 6, 5, 5, Color(0, 0, 0, 0))
	var arrow := HERO_SHOT
	_rect(image, arrow + 1, 5, 8, 1, WOOD_END)
	_rect(image, arrow + 9, 4, 1, 3, STONE_LIGHT)
	_dot(image, arrow + 10, 5, WHITE)
	_dot(image, arrow, 4, ROOF_MID)
	_dot(image, arrow, 6, ROOF_MID)
	var blow := HERO_SHOT * 2
	_rect(image, blow + 5, 1, 2, 10, FIRE_YELLOW)
	_rect(image, blow + 1, 5, 10, 2, FIRE_ORANGE)
	_rect(image, blow + 4, 4, 4, 4, WHITE)
	image.save_png("res://assets/tiles/hero_shots.png")


func _save_cursor() -> void:
	var image := _new_image(CELL, CELL)
	for flip_x: bool in [false, true]:
		for flip_y: bool in [false, true]:
			for layer: Array in [[0, 8, 3, INK], [1, 6, 1, WHITE]]:
				var start: int = layer[0]
				var length: int = layer[1]
				var thick: int = layer[2]
				var color: Color = layer[3]
				for i in range(length):
					for j in range(thick):
						var h := Vector2i(start + i, start + j)
						var v := Vector2i(start + j, start + i)
						for point: Vector2i in [h, v]:
							var px := CELL - 1 - point.x if flip_x else point.x
							var py := CELL - 1 - point.y if flip_y else point.y
							image.set_pixel(px, py, color)
	image.save_png("res://assets/ui/cursor.png")


# --- Interface ---

func _save_icons() -> void:
	var wood := _new_image(12, 12)
	_rect(wood, 1, 3, 9, 6, INK)
	_rect(wood, 2, 4, 7, 4, WOOD_MID)
	_rect(wood, 2, 4, 7, 1, WOOD_LIGHT)
	_rect(wood, 2, 7, 7, 1, WOOD_DARK)
	_ellipse(wood, 9, 6, 2.5, 3, INK)
	_ellipse(wood, 9, 6, 1.5, 2, WOOD_END)
	wood.save_png("res://assets/ui/icon_wood.png")

	var food := _new_image(12, 12)
	_rect(food, 5, 3, 2, 9, INK)
	_rect(food, 5, 4, 1, 8, LEAF)
	for y: int in [1, 4, 7]:
		_ellipse(food, 3.5, y + 1, 1.5, 1.5, INK)
		_ellipse(food, 8, y + 1, 1.5, 1.5, INK)
		_dot(food, 3, y + 1, WHEAT)
		_dot(food, 4, y + 1, WHEAT)
		_dot(food, 7, y + 1, WHEAT_DARK)
		_dot(food, 8, y + 1, WHEAT)
	_dot(food, 5, 1, WHEAT)
	food.save_png("res://assets/ui/icon_food.png")

	var people := _new_image(12, 12)
	_rect(people, 2, 7, 8, 5, INK)
	_rect(people, 3, 8, 6, 4, TUNIC)
	_ellipse(people, 5.5, 4, 3.5, 4, INK)
	_ellipse(people, 5.5, 4, 2.5, 3, SKIN)
	_rect(people, 3, 1, 6, 2, WOOD_MID)
	_dot(people, 4, 4, INK)
	_dot(people, 7, 4, INK)
	people.save_png("res://assets/ui/icon_people.png")

	var water_icon := _new_image(12, 12)
	_ellipse(water_icon, 5.5, 7.5, 3.5, 3.5, W_MID)
	_polygon(water_icon, 0, [Vector2(5.5, 0), Vector2(2, 7), Vector2(9, 7)], W_MID)
	_rect(water_icon, 4, 6, 1, 3, W_FOAM)
	_outline(water_icon, 0, 12)
	water_icon.save_png("res://assets/ui/icon_water.png")

	var fighter_icon := _new_image(12, 12)
	_ellipse(fighter_icon, 5.5, 5, 4.5, 4, STONE_LIGHT)
	_rect(fighter_icon, 1, 5, 10, 2, STONE_MID)
	_rect(fighter_icon, 5, 0, 2, 2, ROOF_MID)
	_rect(fighter_icon, 3, 7, 6, 3, SKIN)
	_dot(fighter_icon, 4, 8, INK)
	_dot(fighter_icon, 7, 8, INK)
	_outline(fighter_icon, 0, 12)
	fighter_icon.save_png("res://assets/ui/icon_fighter.png")


const FACE_SIZE := 12
## Miserable to delighted, matching Happiness.Level.
const FACE_COLORS: Array[Color] = [
	Color8(216, 96, 72), Color8(240, 152, 72), Color8(248, 208, 72), Color8(192, 216, 72), Color8(120, 200, 88),
]


## One 12x12 face per happiness level, side by side.
func _save_happiness_faces() -> void:
	var image := _new_image(FACE_SIZE * FACE_COLORS.size(), FACE_SIZE)
	for level in range(FACE_COLORS.size()):
		var x0 := level * FACE_SIZE
		_ellipse(image, x0 + 5.5, 5.5, 5, 5, FACE_COLORS[level])
		_dot(image, x0 + 3, 2, FACE_COLORS[level].lightened(0.5))
		_dot(image, x0 + 4, 2, FACE_COLORS[level].lightened(0.5))
		_outline(image, x0, FACE_SIZE)
		_rect(image, x0 + 3, 3, 1, 2, INK)
		_rect(image, x0 + 8, 3, 1, 2, INK)
		_face_mouth(image, x0, level)
	image.save_png("res://assets/ui/icon_happiness.png")


func _face_mouth(image: Image, x0: int, level: int) -> void:
	match level:
		0:
			_rect(image, x0 + 4, 7, 4, 1, INK)
			_dot(image, x0 + 3, 8, INK)
			_dot(image, x0 + 8, 8, INK)
			_rect(image, x0 + 3, 5, 1, 2, W_LIGHT)
		1:
			_rect(image, x0 + 4, 7, 4, 1, INK)
			_dot(image, x0 + 3, 8, INK)
			_dot(image, x0 + 8, 8, INK)
		2:
			_rect(image, x0 + 4, 8, 4, 1, INK)
		3:
			_dot(image, x0 + 3, 7, INK)
			_dot(image, x0 + 8, 7, INK)
			_rect(image, x0 + 4, 8, 4, 1, INK)
		4:
			_rect(image, x0 + 3, 6, 6, 1, INK)
			_rect(image, x0 + 3, 7, 6, 2, INK)
			_rect(image, x0 + 4, 7, 4, 1, WHITE)
			_rect(image, x0 + 5, 8, 2, 1, ROOF_MID)


## One 16x16 icon per attraction, in VillageSim.ATTRACTIONS order, then a
## boarded-up hatch for attractions whose entrance burned down.
func _save_attraction_icons() -> void:
	var image := _new_image(ATTRACTION_ICON * 7, ATTRACTION_ICON)
	_darts_icon(image, 0)
	_arcade_icon(image, ATTRACTION_ICON)
	_mini_golf_icon(image, ATTRACTION_ICON * 2)
	_bowling_icon(image, ATTRACTION_ICON * 3)
	_water_slide_icon(image, ATTRACTION_ICON * 4)
	_roller_coaster_icon(image, ATTRACTION_ICON * 5)
	_hatch_icon(image, ATTRACTION_ICON * 6)
	for index in range(7):
		_outline(image, index * ATTRACTION_ICON, ATTRACTION_ICON)
	image.save_png("res://assets/ui/attractions.png")


func _darts_icon(image: Image, x0: int) -> void:
	var rings := [ROOF_MID, WHITE, ROOF_MID, LEAF, GOLD]
	for index in range(rings.size()):
		var radius := 6.5 - index * 1.3
		_ellipse(image, x0 + 7.5, 8, radius, radius, rings[index])
	_rect(image, x0 + 10, 3, 5, 1, WOOD_LIGHT)
	_rect(image, x0 + 8, 4, 3, 1, STONE_LIGHT)
	_rect(image, x0 + 13, 2, 2, 1, TUNIC)
	_rect(image, x0 + 13, 4, 2, 1, TUNIC)


func _arcade_icon(image: Image, x0: int) -> void:
	_rect(image, x0 + 3, 1, 10, 15, NAVY_LIGHT)
	_rect(image, x0 + 3, 1, 10, 2, ROOF_MID)
	_rect(image, x0 + 5, 4, 6, 5, INK)
	_rect(image, x0 + 6, 5, 4, 3, LEAF)
	_dot(image, x0 + 7, 6, WHITE)
	_rect(image, x0 + 2, 10, 12, 2, STONE_MID)
	_dot(image, x0 + 5, 10, ROOF_MID)
	_dot(image, x0 + 9, 10, GOLD)
	_dot(image, x0 + 11, 10, W_LIGHT)
	_rect(image, x0 + 4, 13, 8, 1, NAVY)


func _mini_golf_icon(image: Image, x0: int) -> void:
	_ellipse(image, x0 + 7.5, 11.5, 7, 3.5, G_LIGHT)
	_ellipse(image, x0 + 9, 11.5, 2, 1, INK)
	_rect(image, x0 + 9, 1, 1, 11, WOOD_LIGHT)
	_polygon(image, x0, [Vector2(10, 1), Vector2(14, 3), Vector2(10, 5)], ROOF_MID)
	_ellipse(image, x0 + 3.5, 11, 1.5, 1.5, WHITE)


func _bowling_icon(image: Image, x0: int) -> void:
	_ellipse(image, x0 + 5, 4, 2, 2.5, WHITE)
	_ellipse(image, x0 + 5, 11, 3, 4, WHITE)
	_rect(image, x0 + 4, 6, 3, 2, WHITE)
	_rect(image, x0 + 3, 6, 5, 1, ROOF_MID)
	_ellipse(image, x0 + 11, 11, 4, 4, NAVY_LIGHT)
	_dot(image, x0 + 10, 9, INK)
	_dot(image, x0 + 12, 9, INK)
	_dot(image, x0 + 11, 11, INK)


func _water_slide_icon(image: Image, x0: int) -> void:
	# Ladder tower on the left.
	_rect(image, x0 + 1, 2, 1, 13, WOOD_DARK)
	_rect(image, x0 + 4, 2, 1, 13, WOOD_DARK)
	for y in range(4, 15, 3):
		_rect(image, x0 + 2, y, 2, 1, WOOD_LIGHT)
	_rect(image, x0 + 1, 2, 5, 1, WOOD_MID)
	# A winding chute down into the pool.
	for x in range(5, 15):
		var t := (x - 5) / 9.0
		var y := 3 + int(round(t * 8.0 + sin(t * TAU) * 2.0))
		_rect(image, x0 + x, y, 1, 3, W_MID)
		_dot(image, x0 + x, y, W_FOAM)
	_rect(image, x0 + 6, 14, 10, 2, W_LIGHT)
	_dot(image, x0 + 14, 12, W_FOAM)


func _roller_coaster_icon(image: Image, x0: int) -> void:
	# A tall hill, then a small one, on a wooden trestle.
	for x in range(16):
		var height := sin(x / 10.0 * PI) * 9.0 if x <= 10 else sin((x - 10) / 5.0 * PI) * 4.0
		var y := 13 - int(round(height))
		_dot(image, x0 + x, y, ROOF_DARK)
		_dot(image, x0 + x, y + 1, WOOD_LIGHT)
		if x % 3 == 1:
			_rect(image, x0 + x, y + 2, 1, 14 - y, WOOD_MID)
	_rect(image, x0 + 0, 15, 16, 1, WOOD_DARK)
	# The car, cresting the tall hill.
	_rect(image, x0 + 2, 1, 6, 3, TUNIC)
	_rect(image, x0 + 2, 1, 6, 1, W_LIGHT)
	_dot(image, x0 + 3, 4, INK)
	_dot(image, x0 + 6, 4, INK)
	_dot(image, x0 + 4, 0, SKIN)


func _hatch_icon(image: Image, x0: int) -> void:
	_rect(image, x0 + 1, 3, 14, 12, SOIL_DARK)
	for y in range(4, 14, 3):
		_rect(image, x0 + 2, y, 12, 2, WOOD_MID)
		_rect(image, x0 + 2, y, 12, 1, WOOD_LIGHT)
	_rect(image, x0 + 2, 6, 12, 1, WOOD_DARK)
	for index in range(12):
		_dot(image, x0 + 2 + index, 4 + index * 10 / 11, WOOD_DARK)
	_dot(image, x0 + 7, 9, GOLD)
	_dot(image, x0 + 8, 9, GOLD)


## A speech bubble with an exclamation mark.
func _save_idle_mark() -> void:
	var image := _new_image(14, 16)
	_rect(image, 2, 1, 10, 10, WHITE)
	_rect(image, 1, 2, 12, 8, WHITE)
	_rect(image, 5, 11, 4, 1, WHITE)
	_rect(image, 6, 12, 2, 1, WHITE)
	_rect(image, 6, 3, 2, 4, ROOF_MID)
	_rect(image, 6, 8, 2, 1, ROOF_MID)
	_outline(image, 0, 14)
	image.save_png("res://assets/ui/idle_mark.png")


## A beveled 16x16 box that the theme stretches as a nine-slice.
func _save_box(path: String, border: Color, fill: Color, shine: Color) -> void:
	var image := _new_image(16, 16)
	_rect(image, 1, 0, 14, 16, INK)
	_rect(image, 0, 1, 16, 14, INK)
	_rect(image, 2, 1, 12, 14, border)
	_rect(image, 1, 2, 14, 12, border)
	_rect(image, 3, 2, 10, 12, INK)
	_rect(image, 2, 3, 12, 10, INK)
	_rect(image, 3, 3, 10, 10, fill)
	_rect(image, 3, 3, 10, 1, shine)
	image.save_png(path)


func _save_panels() -> void:
	_save_box("res://assets/ui/panel.png", WHITE, NAVY, NAVY)
	_save_box("res://assets/ui/button.png", GRAY, NAVY_LIGHT, GRAY)
	_save_box("res://assets/ui/button_hover.png", WHITE, NAVY_LIGHT, WHITE)
	_save_box("res://assets/ui/button_pressed.png", GOLD, NAVY, NAVY_LIGHT)
	_save_box("res://assets/ui/button_disabled.png", STONE_DARK, NAVY, NAVY)
	var close := _new_image(9, 9)
	for i in range(7):
		for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			_dot(close, 1 + i + offset.x, 1 + i + offset.y, INK)
			_dot(close, 7 - i + offset.x, 1 + i + offset.y, INK)
	for i in range(7):
		close.set_pixel(1 + i, 1 + i, WHITE)
		close.set_pixel(7 - i, 1 + i, WHITE)
	close.save_png("res://assets/ui/close.png")


## Saves white outlined glyphs as a BMFont. Lowercase letters reuse the capitals.
func _save_font() -> void:
	var names: Array = GLYPHS.keys()
	var rows := ceili((names.size() + 1) / float(FONT_COLUMNS))
	var image := _new_image(FONT_COLUMNS * GLYPH_W, rows * GLYPH_H)
	var lines := PackedStringArray()
	for index in range(names.size()):
		var name: String = names[index]
		var x0: int = index % FONT_COLUMNS * GLYPH_W
		var y0: int = index / FONT_COLUMNS * GLYPH_H
		var bits: Array = GLYPHS[name]
		for pass_index in range(2):
			for row in range(7):
				for col in range(5):
					if not bits[row] & (1 << (4 - col)):
						continue
					if pass_index == 1:
						image.set_pixel(x0 + 1 + col, y0 + 1 + row, WHITE)
						continue
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							image.set_pixel(x0 + 1 + col + dx, y0 + 1 + row + dy, INK)
		lines.append(_font_char(name.unicode_at(0), x0, y0))
		if name != name.to_lower():
			lines.append(_font_char(name.to_lower().unicode_at(0), x0, y0))
	lines.append("char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15")
	image.save_png("res://assets/ui/pixel_font.png")

	var file := FileAccess.open("res://assets/ui/pixel_font.fnt", FileAccess.WRITE)
	file.store_line('info face="Village Pixel" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0')
	file.store_line("common lineHeight=10 base=8 scaleW=%d scaleH=%d pages=1 packed=0" % [image.get_width(), image.get_height()])
	file.store_line('page id=0 file="pixel_font.png"')
	file.store_line("chars count=%d" % lines.size())
	file.store_string("\n".join(lines) + "\n")


func _font_char(id: int, x: int, y: int) -> String:
	return "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15" % [id, x, y, GLYPH_W, GLYPH_H]
