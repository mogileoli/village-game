extends Camera2D
## WASD/arrows or middle-drag to pan, wheel or pinch to zoom toward the cursor.
## Zoom stays at whole numbers so pixel art never gets distorted.

const PAN_SPEED := 300.0
const GESTURE_PAN_SPEED := 6.0
const PINCH_THRESHOLD := 1.25
const MIN_ZOOM := 1
const MAX_ZOOM := 3
const FOCUS_SECONDS := 0.6

var bounds := Rect2()

var _pinch := 1.0


func _process(delta: float) -> void:
	var direction := Vector2(
		_axis(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT),
		_axis(KEY_W, KEY_UP, KEY_S, KEY_DOWN),
	)
	if direction != Vector2.ZERO:
		_pan_by(direction.normalized() * PAN_SPEED * delta / zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_toward_mouse(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_toward_mouse(-1)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		_pan_by(-event.relative / zoom.x)
	elif event is InputEventPanGesture:
		_pan_by(event.delta * GESTURE_PAN_SPEED / zoom.x)
	elif event is InputEventMagnifyGesture:
		_pinch *= event.factor
		if _pinch > PINCH_THRESHOLD or _pinch < 1.0 / PINCH_THRESHOLD:
			_zoom_toward_mouse(1 if _pinch > 1.0 else -1)
			_pinch = 1.0


func focus_on(target: Vector2) -> void:
	var destination := target.clamp(bounds.position, bounds.end)
	create_tween().tween_property(self, "position", destination, FOCUS_SECONDS)


func _axis(neg_physical: Key, neg_key: Key, pos_physical: Key, pos_key: Key) -> float:
	var negative := Input.is_physical_key_pressed(neg_physical) or Input.is_key_pressed(neg_key)
	var positive := Input.is_physical_key_pressed(pos_physical) or Input.is_key_pressed(pos_key)
	return float(positive) - float(negative)


func _pan_by(offset_amount: Vector2) -> void:
	position = (position + offset_amount).clamp(bounds.position, bounds.end)


func _zoom_toward_mouse(step: int) -> void:
	var new_zoom := clampi(roundi(zoom.x) + step, MIN_ZOOM, MAX_ZOOM)
	var viewport := get_viewport()
	var from_center := viewport.get_mouse_position() - viewport.get_visible_rect().size / 2.0
	_pan_by(from_center / zoom.x - from_center / new_zoom)
	zoom = Vector2.ONE * new_zoom
