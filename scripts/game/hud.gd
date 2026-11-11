class_name Hud
extends CanvasLayer
## Shows village stats and the build toolbar.

signal tool_selected(tool: StringName)
signal save_requested(slot: int, save_name: String)
signal load_requested(slot: int)
signal menu_toggled(is_open: bool)
signal hero_created(hero_name: String, armor: StringName, weapon: StringName, look: StringName)
signal hero_focus_requested(hero: Hero)
signal hero_details_closed
signal teleport_pressed(hero: Hero)
signal attraction_chosen(cell: Vector2i, type: StringName)

const DEMOLISH := &"demolish"
const ROAD := &"road"
const BRIDGE := &"bridge"
const CLEAR_FOREST := &"clear_forest"
## Tools that keep working as the mouse is dragged across the map.
const PAINT_TOOLS: Array[StringName] = [ROAD, BRIDGE, CLEAR_FOREST]
const HERO_TRACK_COLOR := Color(0.09, 0.06, 0.13, 1)
const HERO_TRACK_SIZE := Vector2(48, 6)
const HERO_ROW_HEIGHT := 20
const HERO_ROSTER_MAX_HEIGHT := 200
## Shorter while a hero's details are open, so both fit above the toolbar.
const HERO_ROSTER_SHORT_HEIGHT := 80
const TELEPORT_TEXT := "Teleport"
const TELEPORT_CANCEL_TEXT := "Cancel teleport"
const HERO_HEALTHY_COLOR := Color(0.35, 0.75, 0.3)
const HERO_WOUNDED_COLOR := Color(0.82, 0.19, 0.16)
const WOOD_ICON := preload("res://assets/ui/icon_wood.png")
## One face per Happiness.Level, side by side.
const HAPPINESS_FACES := preload("res://assets/ui/icon_happiness.png")
const FACE_SIZE := 12
const FACTOR_TRACK_SIZE := Vector2(40, 5)
const FACTOR_POOR_COLOR := Color(0.82, 0.19, 0.16)
const FACTOR_FAIR_COLOR := Color(0.97, 0.75, 0.25)
const FACTOR_GOOD_COLOR := Color(0.35, 0.75, 0.3)
## Factor scores below these show as poor, then fair.
const FACTOR_POOR_BELOW := 0.34
const FACTOR_FAIR_BELOW := 0.67
const HAPPINESS_PANEL_GAP := 4
## What each Happiness.Level does to the village.
const HAPPINESS_EFFECTS: Array[String] = [
	"No one settles. Some leave.",
	"Settlers come slower.",
	"Settlers come as usual.",
	"Settlers come faster.",
	"Settlers come much faster.",
]
## Running out of food or water drives people away however happy they are.
const SHORTAGE_EFFECT := "Shortages drive people out!"

## Offered as the name when saving.
var village_name := SaveGame.OLD_SAVE_DISPLAY_NAME

var _tool_buttons := ButtonGroup.new()
var _roster_heroes: Array[Hero] = []
var _details_hero: Hero = null
var _faces: Array[AtlasTexture] = []
var _happiness_sim: VillageSim = null
var _happiness_hovered := false
var _happiness_pinned := false

@onready var _wood: Label = %Wood
@onready var _food: Label = %Food
@onready var _water: Label = %Water
@onready var _people: Label = %People
@onready var _jobs: Label = %Jobs
@onready var _fighters: Label = %Fighters
@onready var _happiness_box: Control = %HappinessBox
@onready var _happiness_icon: TextureRect = %HappinessIcon
@onready var _happiness: Label = %Happiness
@onready var _happiness_panel: Control = %HappinessPanel
@onready var _happiness_title: Label = %HappinessTitle
@onready var _happiness_factors: GridContainer = %HappinessFactors
@onready var _happiness_effect: Label = %HappinessEffect
@onready var _dragon_panel: Control = %DragonPanel
@onready var _dragon_name: Label = %DragonName
@onready var _dragon_fill: ColorRect = %DragonFill
@onready var _dragon_track: Control = %DragonTrack
@onready var _clock: Label = %Clock
@onready var _hero_button: Button = %HeroButton
@onready var _hero_scroll: ScrollContainer = %HeroScroll
@onready var _hero_roster: VBoxContainer = %HeroRoster
@onready var _hero_details: Control = %HeroDetails
@onready var _hero_details_name: Label = %HeroDetailsName
@onready var _hero_details_stats: Label = %HeroDetailsStats
@onready var _teleport_button: Button = %TeleportButton
@onready var _hero_creator: HeroCreator = %HeroCreator
@onready var _playground_panel: PlaygroundPanel = %PlaygroundPanel
@onready var _building_tools: HFlowContainer = %BuildingTools
@onready var _land_tools: HFlowContainer = %LandTools
@onready var _status: Label = %Status
@onready var _status_timer: Timer = %StatusTimer
@onready var _load_button: Button = %LoadButton
@onready var _save_menu: SaveMenu = %SaveMenu
@onready var _banner: Control = %Banner
@onready var _banner_text: Label = %BannerText
@onready var _banner_timer: Timer = %BannerTimer


func _ready() -> void:
	_tool_buttons.allow_unpress = true
	for type: StringName in VillageSim.BUILDINGS:
		var building: Dictionary = VillageSim.BUILDINGS[type]
		_add_tool(_building_tools, "%s %d" % [building.get("label", building.name), building.cost], type, WOOD_ICON)
	_add_tool(_land_tools, "Road %d" % VillageSim.ROAD_COST, ROAD, WOOD_ICON)
	_add_tool(_land_tools, "Bridge %d" % VillageSim.BRIDGE_COST, BRIDGE, WOOD_ICON)
	_add_tool(_land_tools, "Clear Trees", CLEAR_FOREST, null)
	_add_tool(_land_tools, "Demolish", DEMOLISH, null)
	%SaveButton.pressed.connect(func() -> void: _save_menu.open_for_save(village_name))
	_load_button.pressed.connect(_save_menu.open_for_load)
	_save_menu.save_chosen.connect(save_requested.emit)
	_save_menu.load_chosen.connect(load_requested.emit)
	_save_menu.visibility_changed.connect(func() -> void: menu_toggled.emit(_save_menu.visible))
	_hero_button.pressed.connect(func() -> void: _hero_creator.open())
	_teleport_button.pressed.connect(func() -> void: teleport_pressed.emit(_details_hero))
	%HeroDetailsClose.pressed.connect(hero_details_closed.emit)
	_hero_creator.hero_chosen.connect(hero_created.emit)
	_hero_creator.visibility_changed.connect(func() -> void: menu_toggled.emit(_hero_creator.visible))
	_playground_panel.attraction_chosen.connect(attraction_chosen.emit)
	_playground_panel.visibility_changed.connect(func() -> void: menu_toggled.emit(_playground_panel.visible))
	_status_timer.timeout.connect(func() -> void: _status.text = "")
	_banner_timer.timeout.connect(_banner.hide)
	_setup_happiness()


func show_stats(sim: VillageSim, speed: int) -> void:
	_wood.text = str(sim.wood)
	_food.text = str(sim.food)
	_water.text = str(sim.water)
	_people.text = "%d/%d" % [sim.population, sim.housing()]
	_jobs.text = "Jobs %d/%d" % [sim.filled_jobs(), sim.total_jobs()]
	_fighters.text = str(sim.fighter_count())
	_show_happiness(sim)
	_show_dragon(sim)
	_show_heroes(sim)
	_clock.text = "Paused" if speed == 0 else "Speed %dx" % speed
	if _playground_panel.visible:
		_playground_panel.refresh()


## Opens the list of attractions under the playground entrance at this cell.
func open_playground(sim: VillageSim, cell: Vector2i) -> void:
	_playground_panel.open(sim, cell)


func close_playground() -> void:
	_playground_panel.hide()


func show_status(message: String) -> void:
	_status.text = message
	_status_timer.start()


func show_banner(message: String) -> void:
	_banner_text.text = message
	_banner.show()
	_banner_timer.start()


## The face and its breakdown panel, which shows while hovered or after a click.
func _setup_happiness() -> void:
	for level in range(Happiness.Level.size()):
		var face := AtlasTexture.new()
		face.atlas = HAPPINESS_FACES
		face.region = Rect2(level * FACE_SIZE, 0, FACE_SIZE, FACE_SIZE)
		_faces.append(face)
	for factor in Happiness.FACTORS:
		var name_label := Label.new()
		name_label.text = factor.label
		_happiness_factors.add_child(name_label)
		var track := ColorRect.new()
		track.color = HERO_TRACK_COLOR
		track.custom_minimum_size = FACTOR_TRACK_SIZE
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.size = FACTOR_TRACK_SIZE
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)
		_happiness_factors.add_child(track)
		var score := Label.new()
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_happiness_factors.add_child(score)
	_happiness_box.mouse_entered.connect(func() -> void:
		_happiness_hovered = true
		_update_happiness_panel())
	_happiness_box.mouse_exited.connect(func() -> void:
		_happiness_hovered = false
		_update_happiness_panel())
	_happiness_box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_happiness_pinned = not _happiness_pinned
			_update_happiness_panel())


func _show_happiness(sim: VillageSim) -> void:
	_happiness_sim = sim
	_happiness_icon.texture = _faces[sim.happiness.level()]
	_happiness.text = str(roundi(sim.happiness.value))
	if _happiness_panel.visible:
		_update_happiness_panel()


## Shows why the village feels the way it does: each factor's score, where
## happiness is heading, and what that does to the village.
func _update_happiness_panel() -> void:
	_happiness_panel.visible = (_happiness_hovered or _happiness_pinned) and _happiness_sim != null
	if not _happiness_panel.visible:
		return
	var sim := _happiness_sim
	var value := roundi(sim.happiness.value)
	var target := roundi(sim.happiness.target(sim))
	var heading := "Holding steady."
	if target > value:
		heading = "Rising to %d." % target
	elif target < value:
		heading = "Falling to %d." % target
	_happiness_title.text = "Happiness %d: %s" % [value, Happiness.LEVEL_NAMES[sim.happiness.level()]]
	var scores := sim.happiness_factors()
	for index in range(Happiness.FACTORS.size()):
		var score: float = scores[Happiness.FACTORS[index].id]
		var fill: ColorRect = _happiness_factors.get_child(index * 3 + 1).get_child(0)
		fill.size.x = roundf(FACTOR_TRACK_SIZE.x * score)
		fill.color = _factor_color(score)
		_happiness_factors.get_child(index * 3 + 2).text = str(roundi(score * 100))
	var effect := HAPPINESS_EFFECTS[sim.happiness.level()]
	if sim.food == 0 or sim.water == 0:
		effect = SHORTAGE_EFFECT
	_happiness_effect.text = "%s\n%s" % [heading, effect]
	_happiness_panel.reset_size()
	var viewport_width := get_viewport().get_visible_rect().size.x
	var x := minf(_happiness_box.global_position.x, viewport_width - _happiness_panel.size.x - HAPPINESS_PANEL_GAP)
	var y := _happiness_box.global_position.y + _happiness_box.size.y + HAPPINESS_PANEL_GAP
	_happiness_panel.position = Vector2(x, y)


func _factor_color(score: float) -> Color:
	if score < FACTOR_POOR_BELOW:
		return FACTOR_POOR_COLOR
	if score < FACTOR_FAIR_BELOW:
		return FACTOR_FAIR_COLOR
	return FACTOR_GOOD_COLOR


## The dragon's resolve, which water from towers and fighters wears down.
func _show_dragon(sim: VillageSim) -> void:
	var visible_now := sim.dragon_is_visiting()
	_dragon_panel.visible = visible_now
	if not visible_now:
		return
	_dragon_name.text = "Dragon" if sim.dragon_level == 1 else "Dragon Lv %d" % sim.dragon_level
	var share := float(sim.dragon_resolve) / sim.dragon_max_resolve()
	_dragon_fill.size.x = roundf(_dragon_track.size.x * share)


## Says what's still needed for the next hero, and how each hero is doing.
func _show_heroes(sim: VillageSim) -> void:
	_hero_button.disabled = not sim.can_create_hero()
	var count := sim.heroes.size()
	if sim.population < VillageSim.HERO_MIN_POPULATION:
		_hero_button.text = "Hero: %d/%d people" % [sim.population, VillageSim.HERO_MIN_POPULATION]
	elif not sim.dragon_has_attacked():
		_hero_button.text = "Hero: awaits a dragon"
	elif sim.can_create_hero():
		_hero_button.text = "Create Hero (%d/%d)" % [count, sim.hero_limit()]
	else:
		_hero_button.text = "Next hero at %d people" % ((count + 1) * VillageSim.VILLAGERS_PER_HERO)
	if _roster_heroes != sim.heroes:
		_rebuild_roster(sim.heroes)
	for index in range(count):
		_update_roster_row(_hero_roster.get_child(index), sim.heroes[index])
	_update_hero_details(sim)


func _rebuild_roster(heroes: Array[Hero]) -> void:
	_roster_heroes = heroes.duplicate()
	for child in _hero_roster.get_children():
		_hero_roster.remove_child(child)
		child.queue_free()
	for hero in heroes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_button := Button.new()
		name_button.text = hero.hero_name
		name_button.focus_mode = Control.FOCUS_NONE
		name_button.pressed.connect(hero_focus_requested.emit.bind(hero))
		row.add_child(name_button)
		var track := ColorRect.new()
		track.color = HERO_TRACK_COLOR
		track.custom_minimum_size = HERO_TRACK_SIZE
		track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(track)
		var fill := ColorRect.new()
		fill.size = HERO_TRACK_SIZE
		track.add_child(fill)
		row.add_child(Label.new())
		_hero_roster.add_child(row)
	_fit_roster()


func _fit_roster() -> void:
	var tallest := HERO_ROSTER_SHORT_HEIGHT if _details_hero != null else HERO_ROSTER_MAX_HEIGHT
	_hero_scroll.custom_minimum_size.y = mini(_roster_heroes.size() * HERO_ROW_HEIGHT, tallest)


## Opens the details panel for this hero, or closes it if null.
func show_hero_details(hero: Hero) -> void:
	_details_hero = hero
	_hero_details.visible = hero != null
	set_teleporting(false)
	_fit_roster()


func set_teleporting(teleporting: bool) -> void:
	_teleport_button.text = TELEPORT_CANCEL_TEXT if teleporting else TELEPORT_TEXT


func _update_hero_details(sim: VillageSim) -> void:
	var hero := _details_hero
	if hero == null:
		return
	var status := "On patrol"
	if hero.wounded:
		status = "Wounded"
	elif sim.dragon_is_visiting():
		status = "Hunting a dragon"
	_hero_details_name.text = hero.hero_name
	_hero_details_stats.text = "\n".join([
		"Status: %s" % status,
		"Health: %d/%d" % [hero.health, hero.max_health()],
		"Armor: %s" % Hero.ARMORS[hero.armor].name,
		"Weapon: %s" % Hero.WEAPONS[hero.weapon].name,
		"Look: %s" % Hero.LOOKS[hero.look].name,
		"Speed: %.1fx" % hero.speed_factor(),
		"Damage: %d" % hero.damage(),
		"Reach: %s" % String.num(hero.reach()),
		"Dragons slain: %d" % hero.dragons_slain,
	])


func _update_roster_row(row: Control, hero: Hero) -> void:
	var fill: ColorRect = row.get_child(1).get_child(0)
	fill.size.x = roundf(HERO_TRACK_SIZE.x * hero.health / hero.max_health())
	fill.color = HERO_WOUNDED_COLOR if hero.wounded else HERO_HEALTHY_COLOR
	row.get_child(2).text = "Slain %d" % hero.dragons_slain


func hide_banner() -> void:
	_banner_timer.stop()
	_banner.hide()


func set_can_load(can_load: bool) -> void:
	_load_button.disabled = not can_load


func clear_tool() -> void:
	var pressed := _tool_buttons.get_pressed_button()
	if pressed:
		pressed.button_pressed = false


func _add_tool(row: HFlowContainer, label: String, tool: StringName, icon: Texture2D) -> void:
	var button := Button.new()
	button.text = label
	button.icon = icon
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.toggle_mode = true
	button.button_group = _tool_buttons
	button.focus_mode = Control.FOCUS_NONE
	button.toggled.connect(func(on: bool) -> void:
		if on:
			tool_selected.emit(tool)
		elif _tool_buttons.get_pressed_button() == null:
			tool_selected.emit(&"")
	)
	row.add_child(button)
