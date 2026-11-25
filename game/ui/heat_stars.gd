class_name HeatStars
extends Control
## "Wanted level" stars, drawn (no font glyphs needed). Lit stars pop when heat rises.

var count: int = 6
var lit: int = 1
var _pop: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(count * 30, 30)


func set_level(value: int) -> void:
	if value > lit:
		_pop = 1.0
	lit = value
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var step := size.x / float(count)
	for i in count:
		var c := Vector2(step * (i + 0.5), size.y * 0.5)
		var on := i < lit
		var r := step * 0.42 * (1.0 + (_pop * 0.35 if on and i == lit - 1 else 0.0))
		var col := Color("ffcf3a") if on else Color(1, 1, 1, 0.18)
		if on and lit >= count:
			col = col.lerp(Color("ff5a3c"), 0.5 + 0.5 * sin(_t * 8.0))
		draw_colored_polygon(_star(c, r), col)
		if on:
			draw_polyline(_star(c, r, true), Color(0.45, 0.25, 0.0, 0.8), 1.5, true)


static func _star(c: Vector2, r: float, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	if closed:
		pts.append(pts[0])
	return pts
