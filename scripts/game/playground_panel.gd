class_name PlaygroundPanel
extends Control
## The full-screen list of attractions the player can build under a playground entrance.

signal attraction_chosen(cell: Vector2i, type: StringName)

const ICONS := preload("res://assets/ui/attractions.png")
const ICON_SIZE := 16
const ICON_SCALE := 2
const TEXT_WIDTH := 220
const BUTTON_WIDTH := 60
const TITLE_COLOR := Color(0.97, 0.82, 0.28)
const BUILT_COLOR := Color(0.55, 0.85, 0.45)
const DIM_COLOR := Color(0.03, 0.03, 0.12, 0.6)

var _sim: VillageSim
var _cell := Vector2i.ZERO
var _summary: Label
var _rows: GridContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Underground Playground"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(title)
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_summary)
	_rows = GridContainer.new()
	_rows.columns = 3
	_rows.add_theme_constant_override("h_separation", 6)
	_rows.add_theme_constant_override("v_separation", 2)
	column.add_child(_rows)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(hide)
	column.add_child(close)


## Shows what's built under this entrance and what could be added.
func open(sim: VillageSim, cell: Vector2i) -> void:
	_sim = sim
	_cell = cell
	refresh()
	show()


func refresh() -> void:
	if _sim == null or not _sim.is_playground(_cell):
		hide()
		return
	var built := _sim.attractions_at(_cell)
	var staff := _sim.attraction_staff(_cell)
	var hired := 0
	var needed := 0
	for type in built:
		hired += staff[type].x
		needed += VillageSim.ATTRACTIONS[type].staff
	_summary.text = "Attractions %d/%d   Staff %d/%d   Village fun %d/100" % [
		built.size(), VillageSim.ATTRACTIONS.size(), hired, needed, roundi(_sim.entertainment() * 100),
	]
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var index := 0
	for type: StringName in VillageSim.ATTRACTIONS:
		_add_row(type, index, type in built, staff.get(type, Vector2i.ZERO))
		index += 1


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _add_row(type: StringName, index: int, is_built: bool, staff: Vector2i) -> void:
	var attraction: Dictionary = VillageSim.ATTRACTIONS[type]
	var icon := TextureRect.new()
	var region := AtlasTexture.new()
	region.atlas = ICONS
	region.region = Rect2(index * ICON_SIZE, 0, ICON_SIZE, ICON_SIZE)
	icon.texture = region
	icon.custom_minimum_size = Vector2.ONE * ICON_SIZE * ICON_SCALE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rows.add_child(icon)

	var text := Label.new()
	text.custom_minimum_size.x = TEXT_WIDTH
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_built:
		text.text = "%s\n%s" % [attraction.name, describe_staff(attraction.staff, staff)]
		text.add_theme_color_override("font_color", BUILT_COLOR)
	else:
		text.text = "%s\n%s   Staff %d   Fun for %d" % [
			attraction.name, describe_cost(attraction.cost), attraction.staff, attraction.guests,
		]
	_rows.add_child(text)

	var button := Button.new()
	button.custom_minimum_size.x = BUTTON_WIDTH
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.text = "Built" if is_built else "Build"
	button.disabled = not _sim.can_build_attraction(_cell, type)
	button.pressed.connect(func() -> void: attraction_chosen.emit(_cell, type))
	_rows.add_child(button)


static func describe_cost(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for resource: String in cost:
		parts.append("%d %s" % [cost[resource], resource])
	return " + ".join(parts)


## Staff hired (x) and working inside (y), for an attraction needing this many.
static func describe_staff(needed: int, staff: Vector2i) -> String:
	var status := "Open"
	if staff.x == 0:
		status = "Needs staff"
	elif staff.y == 0:
		status = "Staff on break"
	return "%s - staff %d/%d" % [status, staff.x, needed]
