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
	_save_villagers()
	_save_cursor()
	_save_icons()
	_save_idle_mark()
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


func _save_buildings() -> void:
	var image := _new_image(CELL * 5, BUILDING_H)
	_house(image, 0)
	_farm(image, CELL)
	_lumber_camp(image, CELL * 2)
	_well(image, CELL * 3)
	_tower(image, CELL * 4)
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
	var image := _new_image(160, 56)
	_dragon_frame(image, 0, true)
	_dragon_frame(image, 80, false)
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


# --- Villagers ---

## Draws one 12x16 frame. Direction: 0 down, 1 up, 2 side. Step: 0 or 1.
func _villager_frame(direction: int, step: int, tunic: Color, tunic_dark: Color, hair: Color) -> Image:
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
	_outline(image, 0, 12)
	return image


func _save_villagers() -> void:
	var looks: Array[Array] = [
		[LEAF, Color8(40, 112, 40), WOOD_MID],
		[TUNIC, W_DEEP, Color8(248, 216, 96)],
		[ROOF_MID, ROOF_DARK, INK],
		[Color8(136, 88, 168), Color8(96, 56, 128), WOOD_DARK],
	]
	var image := _new_image(12 * 6, 16 * looks.size())
	for row in range(looks.size()):
		var look: Array = looks[row]
		for direction in range(3):
			for step in range(2):
				var frame := _villager_frame(direction, step, look[0], look[1], look[2])
				var at := Vector2i((direction * 2 + step) * 12, row * 16)
				image.blit_rect(frame, Rect2i(0, 0, 12, 16), at)
	image.save_png("res://assets/tiles/villagers.png")


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
