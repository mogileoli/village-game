class_name Hud
extends CanvasLayer
## Shows village stats and the build toolbar.

signal tool_selected(tool: StringName)
signal save_requested(slot: int, save_name: String)
signal load_requested(slot: int)
signal menu_toggled(is_open: bool)
signal hero_created(hero_name: String, armor: StringName, weapon: StringName, look: StringName)
signal hero_focus_requested(hero: Hero)

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
const HERO_HEALTHY_COLOR := Color(0.35, 0.75, 0.3)
const HERO_WOUNDED_COLOR := Color(0.82, 0.19, 0.16)
const WOOD_ICON := preload("res://assets/ui/icon_wood.png")

## Offered as the name when saving.
var village_name := SaveGame.OLD_SAVE_DISPLAY_NAME

var _tool_buttons := ButtonGroup.new()
var _roster_heroes: Array[Hero] = []

@onready var _wood: Label = %Wood
@onready var _food: Label = %Food
@onready var _water: Label = %Water
@onready var _people: Label = %People
@onready var _jobs: Label = %Jobs
@onready var _fighters: Label = %Fighters
@onready var _dragon_panel: Control = %DragonPanel
@onready var _dragon_name: Label = %DragonName
@onready var _dragon_fill: ColorRect = %DragonFill
@onready var _dragon_track: Control = %DragonTrack
@onready var _clock: Label = %Clock
@onready var _hero_button: Button = %HeroButton
@onready var _hero_scroll: ScrollContainer = %HeroScroll
@onready var _hero_roster: VBoxContainer = %HeroRoster
@onready var _hero_creator: HeroCreator = %HeroCreator
@onready var _building_tools: HBoxContainer = %BuildingTools
@onready var _land_tools: HBoxContainer = %LandTools
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
	_hero_creator.hero_chosen.connect(hero_created.emit)
	_hero_creator.visibility_changed.connect(func() -> void: menu_toggled.emit(_hero_creator.visible))
	_status_timer.timeout.connect(func() -> void: _status.text = "")
	_banner_timer.timeout.connect(_banner.hide)


func show_stats(sim: VillageSim, speed: int) -> void:
	_wood.text = str(sim.wood)
	_food.text = str(sim.food)
	_water.text = str(sim.water)
	_people.text = "%d/%d" % [sim.population, sim.housing()]
	_jobs.text = "Jobs %d/%d" % [sim.filled_jobs(), sim.total_jobs()]
	_fighters.text = str(sim.fighter_count())
	_show_dragon(sim)
	_show_heroes(sim)
	_clock.text = "Paused" if speed == 0 else "Speed %dx" % speed


func show_status(message: String) -> void:
	_status.text = message
	_status_timer.start()


func show_banner(message: String) -> void:
	_banner_text.text = message
	_banner.show()
	_banner_timer.start()


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
	_hero_scroll.custom_minimum_size.y = mini(heroes.size() * HERO_ROW_HEIGHT, HERO_ROSTER_MAX_HEIGHT)


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


func _add_tool(row: HBoxContainer, label: String, tool: StringName, icon: Texture2D) -> void:
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
