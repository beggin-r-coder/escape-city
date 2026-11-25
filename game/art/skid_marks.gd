class_name SkidMarks
extends MultiMeshInstance3D
## Tyre marks laid behind the rear wheels while drifting or braking hard. A ring buffer of
## flat quads in one MultiMesh: a single draw call, bounded memory, oldest marks recycle.

const CAPACITY := 320
const SPACING := 0.55

var _next: int = 0
var _last_left: Vector3 = Vector3.INF
var _last_right: Vector3 = Vector3.INF


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.42, 1.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.1, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = CAPACITY
	for i in CAPACITY:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -100, 0)))
	multimesh = mm


## Call each physics step with the car transform; `active` while sliding/braking hard.
func track(car: Transform3D, active: bool) -> void:
	if not active:
		_last_left = Vector3.INF
		_last_right = Vector3.INF
		return
	var right := car.basis.x.normalized()
	var back := car.basis.z.normalized()  # car forward is -Z, so +Z is towards the rear
	var rear := car.origin + back * 1.25 + Vector3.UP * 0.1
	_last_left = _lay(rear - right * 0.8, _last_left)
	_last_right = _lay(rear + right * 0.8, _last_right)


func _lay(p: Vector3, last: Vector3) -> Vector3:
	if last == Vector3.INF:
		return p
	var d := p - last
	d.y = 0.0
	var length := d.length()
	if length < SPACING:
		return last
	var dir := d / length
	var x := Vector3(-dir.z, 0, dir.x)
	var mark := Basis(x, Vector3.UP, dir * (length + 0.05))
	multimesh.set_instance_transform(_next, Transform3D(mark, (p + last) * 0.5))
	_next = (_next + 1) % CAPACITY
	return p


func clear_marks() -> void:
	for i in CAPACITY:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -100, 0)))
	_last_left = Vector3.INF
	_last_right = Vector3.INF


func apply_origin_shift(offset: Vector3) -> void:
	for i in CAPACITY:
		var t := multimesh.get_instance_transform(i)
		t.origin += offset
		multimesh.set_instance_transform(i, t)
	if _last_left != Vector3.INF:
		_last_left += offset
	if _last_right != Vector3.INF:
		_last_right += offset
