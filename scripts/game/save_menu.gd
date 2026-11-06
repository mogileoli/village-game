class_name SaveMenu
extends Control
## The full-screen list of save slots, used for both saving and loading.

signal save_chosen(slot: int, save_name: String)
signal load_chosen(slot: int)

const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var _saving := false
var _pending: SaveGame.SlotInfo

@onready var _title: Label = %MenuTitle
@onready var _name_row: Control = %NameRow
@onready var _name_field: LineEdit = %NameField
@onready var _slots: VBoxContainer = %Slots
@onready var _confirm: ConfirmationDialog = %ConfirmDialog


func _ready() -> void:
	_name_field.max_length = SaveGame.MAX_NAME_LENGTH
	_name_field.text_changed.connect(_on_name_changed)
	%MenuCancel.pressed.connect(hide)
	_confirm.confirmed.connect(_on_confirmed)


func open_for_save(current_name: String) -> void:
	_saving = true
	_title.text = "Save game"
	_name_field.text = current_name
	_name_row.show()
	_open()
	_name_field.grab_focus()
	_name_field.select_all()


func open_for_load() -> void:
	_saving = false
	_title.text = "Load game"
	_name_row.hide()
	_open()


func _open() -> void:
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	for slot in range(1, SaveGame.SLOT_COUNT + 1):
		_add_slot_button(SaveGame.slot_info(slot))
	show()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not _confirm.visible:
		hide()
		get_viewport().set_input_as_handled()


func _add_slot_button(info: SaveGame.SlotInfo) -> void:
	var button := Button.new()
	button.text = describe_slot(info)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not _saving and info.status != SaveGame.SlotInfo.Status.READY
	button.pressed.connect(_on_slot_pressed.bind(info))
	_slots.add_child(button)


func _on_slot_pressed(info: SaveGame.SlotInfo) -> void:
	_pending = info
	if not _saving:
		_ask("Load %s?\nProgress since your last save will be lost." % info.name, "Load")
	elif info.status == SaveGame.SlotInfo.Status.READY:
		_ask("Replace %s?\nThat save will be lost." % info.name, "Replace")
	elif info.status == SaveGame.SlotInfo.Status.DAMAGED:
		_ask("Replace the damaged save in slot %d?" % info.slot, "Replace")
	else:
		_on_confirmed()


func _ask(question: String, action: String) -> void:
	_confirm.dialog_text = question
	_confirm.ok_button_text = action
	_confirm.popup_centered()


func _on_confirmed() -> void:
	hide()
	if _saving:
		save_chosen.emit(_pending.slot, _name_field.text)
	else:
		load_chosen.emit(_pending.slot)


## Removes characters the pixel font can't draw, as they're typed or pasted.
func _on_name_changed(text: String) -> void:
	var allowed := SaveGame.strip_unsupported_characters(text)
	if allowed != text:
		var caret := _name_field.caret_column - (text.length() - allowed.length())
		_name_field.text = allowed
		_name_field.caret_column = maxi(caret, 0)


static func describe_slot(info: SaveGame.SlotInfo) -> String:
	match info.status:
		SaveGame.SlotInfo.Status.EMPTY:
			return "Slot %d - Empty" % info.slot
		SaveGame.SlotInfo.Status.DAMAGED:
			return "Slot %d - Damaged save" % info.slot
	return "\n".join([
		"Slot %d - %s" % [info.slot, info.name],
		"Saved %s" % format_saved_time(info.saved_at),
		"Wood %d   Food %d   Water %d" % [info.wood, info.food, info.water],
		"People %d/%d   Jobs %d/%d   Buildings %d" % [
			info.population, info.housing, info.filled_jobs, info.total_jobs, info.buildings,
		],
		"Game time %s" % format_game_time(info.game_seconds),
	])


## Shows a save time in the player's local time zone.
static func format_saved_time(unix_time: int) -> String:
	var bias_minutes: int = Time.get_time_zone_from_system().bias
	var date := Time.get_datetime_dict_from_unix_time(unix_time + bias_minutes * 60)
	var hour: int = date.hour % 12
	return "%s %d, %d  %d:%02d %s" % [
		MONTHS[date.month - 1], date.day, date.year,
		12 if hour == 0 else hour, date.minute, "AM" if date.hour < 12 else "PM",
	]


static func format_game_time(seconds: int) -> String:
	var hours := seconds / 3600
	var minutes := seconds / 60 % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds % 60]
	return "%d:%02d" % [minutes, seconds % 60]
