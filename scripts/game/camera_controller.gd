class_name CameraController
extends Camera2D
## Moving the map: WASD/arrows, scrolling or a two-finger swipe, or dragging with
## the right or middle button (or the left button when no tool is picked).
## Zooming: a trackpad pinch, Ctrl/Cmd + scroll, or the +/- keys, toward the cursor.

const PAN_SPEED := 300.0
const GESTURE_PAN_SPEED := 6.0
## World pixels moved per unit of wheel factor. Browsers report about 0.03
## per pixel scrolled, and a mouse wheel notch is about 1.
const WHEEL_PAN_SPEED := 20.0
const PINCH_THRESHOLD := 1.25
## How much pinch the browser has to report before the zoom steps.
const WEB_PINCH_STEP := 40.0
## Zoom levels, smallest first. Below 1 shows more of the map.
const ZOOM_LEVELS: Array[float] = [0.5, 1.0, 2.0]
const DEFAULT_ZOOM := 1.0
## Pixels the mouse has to move before a press becomes a drag.
const DRAG_THRESHOLD := 4.0
const FOCUS_SECONDS := 0.6

## In browsers, a trackpad pinch reaches the game as an ordinary scroll, so this
## catches pinches (and Ctrl/Cmd + scroll) first and adds them up for the game.
const WEB_PINCH_LISTENER := """
if (!window.villagePinch) {
	window.villagePinch = 0;
	window.addEventListener('wheel', function (event) {
		if (event.ctrlKey || event.metaKey) {
			event.preventDefault();
			event.stopImmediatePropagation();
			window.villagePinch += event.deltaMode === 1 ? event.deltaY * 33 : event.deltaY;
		}
	}, { capture: true, passive: false });
}
"""

## Centers of the map's edge tiles. The view is kept on the map.
var bounds := Rect2()
## Set while no tool is picked, so a left drag moves the map instead of building.
var left_drag_pans := true

var _pinch := 1.0
var _web_pinch := 0.0
var _drag_button := MOUSE_BUTTON_NONE
var _drag_start := Vector2.ZERO
var _dragging := false


func _ready() -> void:
	zoom = Vector2.ONE * DEFAULT_ZOOM
	get_viewport().size_changed.connect(func() -> void: position = _keep_on_map(position))
	if OS.has_feature("web"):
		JavaScriptBridge.eval(WEB_PINCH_LISTENER, true)


func _process(delta: float) -> void:
	var direction := Vector2(
		_axis(KEY_A, KEY_LEFT, KEY_D, KEY_RIGHT),
		_axis(KEY_W, KEY_UP, KEY_S, KEY_DOWN),
	)
	if direction != Vector2.ZERO:
		_pan_by(direction.normalized() * PAN_SPEED * delta / zoom.x)
	if OS.has_feature("web"):
		_read_web_pinch()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventPanGesture:
		_pan_by(event.delta * GESTURE_PAN_SPEED / zoom.x)
	elif event is InputEventMagnifyGesture:
		_pinch *= event.factor
		if _pinch > PINCH_THRESHOLD or _pinch < 1.0 / PINCH_THRESHOLD:
			_zoom_toward_mouse(1 if _pinch > 1.0 else -1)
			_pinch = 1.0
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom_toward_mouse(1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_toward_mouse(-1)


func focus_on(target: Vector2) -> void:
	var destination := _keep_on_map(target)
	create_tween().tween_property(self, "position", destination, FOCUS_SECONDS)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	var wheel := _wheel_direction(event.button_index)
	if wheel != Vector2.ZERO:
		if not event.pressed:
			return
		if event.ctrl_pressed or event.meta_pressed:
			_zoom_toward_mouse(-int(wheel.y))
		else:
			var amount := event.factor if event.factor > 0.0 else 1.0
			_pan_by(wheel * amount * WHEEL_PAN_SPEED / zoom.x)
		get_viewport().set_input_as_handled()
		return
	if not _can_drag_with(event.button_index):
		return
	if event.pressed and _drag_button == MOUSE_BUTTON_NONE:
		_drag_button = event.button_index
		_drag_start = event.position
		_dragging = false
	elif not event.pressed and event.button_index == _drag_button:
		_drag_button = MOUSE_BUTTON_NONE
		if _dragging:
			# The drag was for moving the map, so it isn't also a click.
			_dragging = false
			get_viewport().set_input_as_handled()


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _drag_button == MOUSE_BUTTON_NONE:
		return
	if not _dragging and event.position.distance_to(_drag_start) >= DRAG_THRESHOLD:
		_dragging = true
		_pan_by((_drag_start - event.position) / zoom.x)
	elif _dragging:
		_pan_by(-event.relative / zoom.x)
	if _dragging:
		get_viewport().set_input_as_handled()


func _can_drag_with(button: MouseButton) -> bool:
	match button:
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			return true
		MOUSE_BUTTON_LEFT:
			return left_drag_pans or _drag_button == MOUSE_BUTTON_LEFT
	return false


## Which way a wheel event scrolls. Browsers send a rightward swipe as WHEEL_LEFT.
func _wheel_direction(button: MouseButton) -> Vector2:
	match button:
		MOUSE_BUTTON_WHEEL_UP:
			return Vector2.UP
		MOUSE_BUTTON_WHEEL_DOWN:
			return Vector2.DOWN
		MOUSE_BUTTON_WHEEL_LEFT:
			return Vector2.RIGHT if OS.has_feature("web") else Vector2.LEFT
		MOUSE_BUTTON_WHEEL_RIGHT:
			return Vector2.LEFT if OS.has_feature("web") else Vector2.RIGHT
	return Vector2.ZERO


func _read_web_pinch() -> void:
	var reported: Variant = JavaScriptBridge.eval("(function () { var p = window.villagePinch || 0; window.villagePinch = 0; return p; })()", true)
	if reported is float or reported is int:
		_web_pinch += reported
	if absf(_web_pinch) >= WEB_PINCH_STEP:
		# Pinching out (fingers apart) reports negative values.
		_zoom_toward_mouse(1 if _web_pinch < 0.0 else -1)
		_web_pinch = 0.0


func _axis(neg_physical: Key, neg_key: Key, pos_physical: Key, pos_key: Key) -> float:
	var negative := Input.is_physical_key_pressed(neg_physical) or Input.is_key_pressed(neg_key)
	var positive := Input.is_physical_key_pressed(pos_physical) or Input.is_key_pressed(pos_key)
	return float(positive) - float(negative)


func _pan_by(offset_amount: Vector2) -> void:
	position = _keep_on_map(position + offset_amount)


## Keeps the view inside the map, or centers the map when it's smaller than the view.
func _keep_on_map(center: Vector2) -> Vector2:
	var map := bounds.grow_individual(
		MapView.TILE_SIZE.x / 2.0, MapView.TILE_SIZE.y / 2.0,
		MapView.TILE_SIZE.x / 2.0, MapView.TILE_SIZE.y / 2.0)
	var half_view := get_viewport_rect().size / zoom / 2.0
	var result := center
	for axis in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		if map.size[axis] <= half_view[axis] * 2.0:
			result[axis] = map.get_center()[axis]
		else:
			result[axis] = clampf(center[axis], map.position[axis] + half_view[axis], map.end[axis] - half_view[axis])
	return result


func _zoom_toward_mouse(step: int) -> void:
	var level := ZOOM_LEVELS.find(zoom.x)
	if level < 0:
		level = ZOOM_LEVELS.find(DEFAULT_ZOOM)
	var new_zoom: float = ZOOM_LEVELS[clampi(level + step, 0, ZOOM_LEVELS.size() - 1)]
	if is_equal_approx(new_zoom, zoom.x):
		return
	var viewport := get_viewport()
	var from_center := viewport.get_mouse_position() - viewport.get_visible_rect().size / 2.0
	var anchored := position + from_center / zoom.x - from_center / new_zoom
	zoom = Vector2.ONE * new_zoom
	position = _keep_on_map(anchored)
