class_name Villager
extends RefCounted
## One person's place in their daily routine. VillageSim moves them each tick.

enum State { AT_HOME, WALKING, WORKING, OUTSIDE }

const NO_CELL := Vector2i(-1, -1)

var home := NO_CELL
var job := NO_CELL
var cell := NO_CELL
var state := State.AT_HOME
var timer := 0
var path: Array[Vector2i] = []
## Cells walked along path. It runs half a cell past each end when the trip
## starts or ends at a building, so people walk in and out of doors.
var progress := 0.0
var from_building := NO_CELL
var to_building := NO_CELL
var layout_version := 0
## Ticks spent inside a training center. VillageSim.TRAINING_TICKS makes a fighter.
var training := 0
## Fish in the boat on a docks shift, landed as food when the shift ends.
var fish := 0
## Ticks worked so far this shift. Docks use it to time the boat's trip.
var shift_ticks := 0


## Multiplies walking pace.
func speed_factor() -> float:
	return 1.0


func trip_end() -> float:
	return path.size() - 1 + (0.5 if to_building != NO_CELL else 0.0)


func to_data() -> Dictionary:
	var saved_path: Array[Array] = []
	for step in path:
		saved_path.append([step.x, step.y])
	return {
		"home": [home.x, home.y],
		"job": [job.x, job.y],
		"cell": [cell.x, cell.y],
		"state": state,
		"timer": timer,
		"path": saved_path,
		"progress": progress,
		"from_building": [from_building.x, from_building.y],
		"to_building": [to_building.x, to_building.y],
		"training": training,
		"fish": fish,
		"shift_ticks": shift_ticks,
	}
