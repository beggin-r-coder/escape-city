class_name PoliceArrows
extends Control
## Off-screen pursuit warning: flashing chevrons at the screen edge pointing to police.

var directions: Array[Vector2] = []
var urgency: Array[float] = []
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_markers(dirs: Array[Vector2], urgencies: Array[float]) -> void:
	directions = dirs
	urgency = urgencies
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if not directions.is_empty():
		queue_redraw()


func _draw() -> void:
	var rect := get_rect()
	var center := rect.size * 0.5
	var margin := 70.0
	var half := center - Vector2(margin, margin)
	for i in directions.size():
		var d := directions[i]
		if d == Vector2.ZERO:
			continue
		# Intersect the ray from the centre with the inset screen rectangle.
		var tx := INF if absf(d.x) < 0.001 else half.x / absf(d.x)
		var ty := INF if absf(d.y) < 0.001 else half.y / absf(d.y)
		var p := center + d * minf(tx, ty)
		var u := urgency[i] if i < urgency.size() else 0.5
		var flash := 0.5 + 0.5 * sin(_t * (8.0 + u * 10.0))
		var col := Color(1.0, 0.18, 0.2, 0.55 + 0.45 * flash) if fmod(_t, 0.6) < 0.3 else Color(0.25, 0.45, 1.0, 0.55 + 0.45 * flash)
		var size := 26.0 + 16.0 * u
		var ang := d.angle()
		var tip := p + Vector2.from_angle(ang) * size
		var l := p + Vector2.from_angle(ang + 2.4) * size * 0.8
		var r := p + Vector2.from_angle(ang - 2.4) * size * 0.8
		draw_colored_polygon(PackedVector2Array([tip, l, p, r]), col)
