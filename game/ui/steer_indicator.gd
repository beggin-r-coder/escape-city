class_name SteerIndicator
extends Control
## Shows where the thumb went down and how far it is steering (drag layout only).

var router: InputRouter
var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var active := router != null and router.is_drag_steering()
	_alpha = move_toward(_alpha, 1.0 if active else 0.0, delta * 6.0)
	if _alpha > 0.0 or active:
		queue_redraw()


func _draw() -> void:
	if router == null or _alpha <= 0.0:
		return
	var o := router.steer_touch_origin()
	var radius := router.drag_radius_px
	draw_arc(o, radius, 0, TAU, 48, Color(1, 1, 1, 0.28 * _alpha), 4.0, true)
	draw_line(o - Vector2(radius, 0), o + Vector2(radius, 0), Color(1, 1, 1, 0.15 * _alpha), 3.0)
	var knob := o + Vector2(router.steer_touch_value() * radius, 0)
	draw_circle(knob, 34.0, Color(1, 1, 1, 0.22 * _alpha))
	draw_arc(knob, 34.0, 0, TAU, 32, Color(1, 1, 1, 0.6 * _alpha), 3.0, true)
