class_name SaveGame
extends RefCounted
## Reads and writes saved games, including the numbered slots shown to the player.
## In web builds user:// is browser storage.

const SLOT_COUNT := 3
const MAX_NAME_LENGTH := 24
## The single save file used before slots existed.
const OLD_SAVE_NAME := "village_save.json"
const OLD_SAVE_DISPLAY_NAME := "My Village"
## Everything the game's pixel font can draw.
const UNSUPPORTED_CHARACTERS := "[^A-Za-z0-9 .,:'!?()\\-/+]"

## Where saves live. Tests point this somewhere else.
static var directory := "user://"


class SlotInfo:
	enum Status { EMPTY, DAMAGED, READY }

	var slot := 0
	var status := Status.EMPTY
	var name := ""
	var saved_at := 0
	var wood := 0
	var food := 0
	var water := 0
	var population := 0
	var housing := 0
	var filled_jobs := 0
	var total_jobs := 0
	var buildings := 0
	var game_seconds := 0
	var fighters := 0


static func slot_path(slot: int) -> String:
	return directory.path_join("save_slot_%d.json" % slot)


static func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


static func any_slot_used() -> bool:
	for slot in range(1, SLOT_COUNT + 1):
		if FileAccess.file_exists(slot_path(slot)):
			return true
	return false


static func strip_unsupported_characters(text: String) -> String:
	return RegEx.create_from_string(UNSUPPORTED_CHARACTERS).sub(text, "", true)


## Returns a name that's safe to display, or a default if nothing usable is left.
static func clean_name(text: String, slot: int) -> String:
	var cleaned := strip_unsupported_characters(text).strip_edges().left(MAX_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else "Village %d" % slot


static func write_slot(slot: int, sim: VillageSim, save_name: String, saved_at := -1) -> Error:
	if not is_valid_slot(slot):
		return ERR_PARAMETER_RANGE_ERROR
	return write(sim, slot_path(slot), clean_name(save_name, slot), saved_at)


static func read_slot(slot: int) -> VillageSim:
	return read(slot_path(slot)) if is_valid_slot(slot) else null


## Stats come from loading the game itself, so they can't disagree with it.
static func slot_info(slot: int) -> SlotInfo:
	var info := SlotInfo.new()
	info.slot = slot
	var path := slot_path(slot)
	if not is_valid_slot(slot) or not FileAccess.file_exists(path):
		return info
	var data: Variant = _read_json(path)
	var sim: VillageSim = _game_from(data)
	if sim == null:
		info.status = SlotInfo.Status.DAMAGED
		return info
	info.status = SlotInfo.Status.READY
	info.name = clean_name(str(data.get("name", "")), slot)
	var saved_at: Variant = data.get("saved_at")
	info.saved_at = int(saved_at) if saved_at is float or saved_at is int else FileAccess.get_modified_time(path)
	info.wood = sim.wood
	info.food = sim.food
	info.water = sim.water
	info.population = sim.population
	info.housing = sim.housing()
	info.filled_jobs = sim.filled_jobs()
	info.total_jobs = sim.total_jobs()
	info.buildings = sim.building_count()
	info.game_seconds = sim.tick_count
	info.fighters = sim.fighter_count()
	return info


## Moves a save from before slots existed into slot 1, keeping its save time.
## The old file stays where it is as a backup.
static func move_old_save_to_slot() -> void:
	var old_path := directory.path_join(OLD_SAVE_NAME)
	if any_slot_used() or not FileAccess.file_exists(old_path):
		return
	var sim := read(old_path)
	if sim != null:
		write_slot(1, sim, OLD_SAVE_DISPLAY_NAME, FileAccess.get_modified_time(old_path))


## Writes to a temporary file first so a failed save can't damage the previous one.
static func write(sim: VillageSim, path: String, save_name := "", saved_at := -1) -> Error:
	var when: int = saved_at if saved_at >= 0 else int(Time.get_unix_time_from_system())
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"name": save_name, "saved_at": when, "game": sim.to_save_data()}))
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(temp_path, path)


## Returns null if the file is missing or isn't a valid save.
static func read(path: String) -> VillageSim:
	return _game_from(_read_json(path))


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


## Saves from before slots hold the game's data directly, with no name or time.
static func _game_from(data: Variant) -> VillageSim:
	if not data is Dictionary:
		return null
	var game: Variant = data.get("game", data)
	return VillageSim.from_save_data(game) if game is Dictionary else null
