class_name HeroCreator
extends Control
## The full-screen form where the player names and equips their hero.

signal hero_chosen(hero_name: String, armor: StringName, weapon: StringName, look: StringName)

const HERO_TEXTURE := preload("res://assets/tiles/hero.png")
const FRAME_SIZE := Vector2(16, 20)
const PREVIEW_SCALE := 5
const OPTION_WIDTH := 96
const TITLE_COLOR := Color(0.97, 0.82, 0.28)
const DIM_COLOR := Color(0.03, 0.03, 0.12, 0.6)

var _armor := &"chainmail"
var _weapon := &"longsword"
var _look := &"ember"
var _name_field: LineEdit
var _create_button: Button
var _preview := AtlasTexture.new()
var _stats: Label


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
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "Create your Hero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TITLE_COLOR)
	rows.add_child(title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	rows.add_child(columns)
	columns.add_child(_build_preview())
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 4)
	columns.add_child(choices)
	choices.add_child(_build_name_row())
	_add_choice(choices, "Armor", Hero.ARMORS, _armor, func(key: StringName) -> void: _armor = key)
	_add_choice(choices, "Weapon", Hero.WEAPONS, _weapon, func(key: StringName) -> void: _weapon = key)
	_add_choice(choices, "Look", Hero.LOOKS, _look, func(key: StringName) -> void: _look = key)
	rows.add_child(_build_buttons())
	_update_preview()


func open() -> void:
	_name_field.text = ""
	_update_create_button()
	show()
	_name_field.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _build_preview() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size.x = FRAME_SIZE.x * PREVIEW_SCALE + 24
	_preview.atlas = HERO_TEXTURE
	var picture := TextureRect.new()
	picture.texture = _preview
	picture.custom_minimum_size = FRAME_SIZE * PREVIEW_SCALE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(picture)
	_stats = Label.new()
	column.add_child(_stats)
	return column


func _build_name_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Name"
	row.add_child(label)
	_name_field = LineEdit.new()
	_name_field.max_length = Hero.MAX_NAME_LENGTH
	_name_field.placeholder_text = "Hero name"
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(func(_text: String) -> void: _create())
	row.add_child(_name_field)
	return row


func _add_choice(parent: Control, title: String, options: Dictionary, current: StringName, pick: Callable) -> void:
	var label := Label.new()
	label.text = title
	parent.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var group := ButtonGroup.new()
	for key: StringName in options:
		var button := Button.new()
		button.text = "%s\n%s" % [options[key].name, options[key].note]
		button.custom_minimum_size.x = OPTION_WIDTH
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = key == current
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			pick.call(key)
			_update_preview())
		row.add_child(button)


func _build_buttons() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(hide)
	row.add_child(cancel)
	_create_button = Button.new()
	_create_button.text = "Create Hero"
	_create_button.focus_mode = Control.FOCUS_NONE
	_create_button.disabled = true
	_create_button.pressed.connect(_create)
	row.add_child(_create_button)
	return row


func _update_preview() -> void:
	var row := Hero.sprite_row_for(_armor, _weapon, _look)
	_preview.region = Rect2(Vector2(0, row * FRAME_SIZE.y), FRAME_SIZE)
	var armor: Dictionary = Hero.ARMORS[_armor]
	var weapon: Dictionary = Hero.WEAPONS[_weapon]
	_stats.text = "Health %d\nSpeed %.1fx\nDamage %d\nReach %s" % [
		armor.health, armor.speed, weapon.damage, String.num(weapon.reach),
	]


func _update_create_button() -> void:
	_create_button.disabled = Hero.clean_name(_name_field.text).is_empty()


## Removes characters the pixel font can't draw, as they're typed or pasted.
func _on_name_changed(text: String) -> void:
	var allowed := SaveGame.strip_unsupported_characters(text)
	if allowed != text:
		var caret := _name_field.caret_column - (text.length() - allowed.length())
		_name_field.text = allowed
		_name_field.caret_column = maxi(caret, 0)
	_update_create_button()


func _create() -> void:
	if _create_button.disabled:
		return
	hide()
	hero_chosen.emit(_name_field.text, _armor, _weapon, _look)
