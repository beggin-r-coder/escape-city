class_name InputRouter
extends Node
## Maps touch drag / on-screen buttons / keyboard to normalized actions.
## - Left-thumb drag steers (floating origin), or fixed left/right buttons.
## - Brake is a held zone supplied by the HUD.
## - Touches over registered UI controls are ignored (UI consumes touches first).
## - All held input is cleared on focus loss and when re-enabled.
## The pause action is registered here but handled by the game's AppRoot (it must work
## while the tree is paused).

enum Layout { DRAG, BUTTONS }

var layout: int = Layout.DRAG
var dead_zone: float = 0.08
var drag_radius_px: float = 110.0
var enabled: bool = true:
	set(value):
		if value != enabled:
			clear_all()
		enabled = value

## Test harness / autopilot injection. When active it replaces player input.
var override_active: bool = false
var override_steer: float = 0.0
var override_brake: bool = false

var _zones: Dictionary = {}  # StringName -> Control
var _exclusions: Array[Control] = []
var _steer_index: int = -1
var _steer_origin: Vector2 = Vector2.ZERO
var _steer_touch: float = 0.0
var _brake_touches: Dictionary = {}
var _button_touches: Dictionary = {}  # index -> -1.0 / 1.0


func _ready() -> void:
	ensure_actions()


static func ensure_actions() -> void:
	_add_action(&"steer_left", [KEY_A, KEY_LEFT])
	_add_action(&"steer_right", [KEY_D, KEY_RIGHT])
	_add_action(&"brake", [KEY_SPACE, KEY_S, KEY_DOWN])
	_add_action(&"pause", [KEY_ESCAPE, KEY_P])


static func _add_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func set_zone(zone: StringName, control: Control) -> void:
	_zones[zone] = control


func add_exclusion(control: Control) -> void:
	if not _exclusions.has(control):
		_exclusions.append(control)


func clear_all() -> void:
	_steer_index = -1
	_steer_touch = 0.0
	_brake_touches.clear()
	_button_touches.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_all()


func get_steer() -> float:
	if not enabled:
		return 0.0
	if override_active:
		return clampf(override_steer, -1.0, 1.0)
	var key_axis := Input.get_axis(&"steer_left", &"steer_right")
	var touch := _steer_touch
	if layout == Layout.BUTTONS:
		touch = 0.0
		for v in _button_touches.values():
			touch += float(v)
		touch = clampf(touch, -1.0, 1.0)
	var raw := key_axis if absf(key_axis) > absf(touch) else touch
	return apply_dead_zone(raw, dead_zone)


func is_brake_held() -> bool:
	if not enabled:
		return false
	if override_active:
		return override_brake
	return not _brake_touches.is_empty() or Input.is_action_pressed(&"brake")


func is_steering_by_touch() -> bool:
	return _steer_index != -1 or not _button_touches.is_empty()


static func apply_dead_zone(value: float, zone: float) -> float:
	var mag := absf(value)
	if mag <= zone:
		return 0.0
	return signf(value) * clampf((mag - zone) / (1.0 - zone), 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		if _is_excluded(ev.position):
			return
		if _in_zone(&"brake", ev.position):
			_brake_touches[ev.index] = true
		elif layout == Layout.BUTTONS and _in_zone(&"left", ev.position):
			_button_touches[ev.index] = -1.0
		elif layout == Layout.BUTTONS and _in_zone(&"right", ev.position):
			_button_touches[ev.index] = 1.0
		elif layout == Layout.DRAG and _steer_index == -1 and ev.position.x < _viewport_width() * 0.5:
			_steer_index = ev.index
			_steer_origin = ev.position
			_steer_touch = 0.0
	else:
		_brake_touches.erase(ev.index)
		_button_touches.erase(ev.index)
		if ev.index == _steer_index:
			_steer_index = -1
			_steer_touch = 0.0


func _on_drag(ev: InputEventScreenDrag) -> void:
	if ev.index == _steer_index:
		var dx := ev.position.x - _steer_origin.x
		# Floating origin: if the thumb travels past the radius, drag the origin along.
		if absf(dx) > drag_radius_px:
			_steer_origin.x = ev.position.x - signf(dx) * drag_radius_px
			dx = signf(dx) * drag_radius_px
		_steer_touch = clampf(dx / drag_radius_px, -1.0, 1.0)
	elif layout == Layout.BUTTONS and _button_touches.has(ev.index):
		if _in_zone(&"left", ev.position):
			_button_touches[ev.index] = -1.0
		elif _in_zone(&"right", ev.position):
			_button_touches[ev.index] = 1.0


func _viewport_width() -> float:
	return get_viewport().get_visible_rect().size.x


func _in_zone(zone: StringName, pos: Vector2) -> bool:
	var control: Control = _zones.get(zone, null)
	return control != null and is_instance_valid(control) and control.is_visible_in_tree() \
		and control.get_global_rect().has_point(pos)


func _is_excluded(pos: Vector2) -> bool:
	for control in _exclusions:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(pos):
			return true
	return false
