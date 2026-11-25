class_name CarVisual
extends Node3D
## Render-side car: a Kenney car model that follows its physics body with interpolation
## between physics ticks (smooth on 60/90/120 Hz screens), spins and steers the wheels,
## and adds a little body roll/pitch/bob so motion reads as weight rather than sliding.
## top_level: it does not inherit the body's transform; the body feeds it each tick.

const WHEEL_RADIUS := 0.3  # Kenney car kit units

var model_scale: float = 1.55
var speed: float = 0.0  # m/s, signed along forward
var steer: float = 0.0  # -1..1 (positive = right)
var lateral: float = 0.0  # m/s sideways slip (drift)
var accel: float = 0.0  # m/s^2 along forward
var max_steer_angle: float = 0.5

var _model: Node3D
var _body: Node3D
var _body_base: Transform3D
var _wheels_front: Array[Node3D] = []
var _wheels_back: Array[Node3D] = []
var _wheel_base: Dictionary = {}
var _spin: float = 0.0
var _steer_vis: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var model_name: String = ""
var _lights_root: Node3D
var _prev: Transform3D = Transform3D.IDENTITY
var _curr: Transform3D = Transform3D.IDENTITY


func build(new_model: String, scale_f: float = 1.55) -> void:
	top_level = true
	model_scale = scale_f
	model_name = new_model
	if _model != null:
		_model.queue_free()
	_wheels_front.clear()
	_wheels_back.clear()
	_wheel_base.clear()
	_model = ArtKit.kenney("cars/%s" % new_model)
	_model.rotation.y = PI  # Kenney cars face +Z; the game drives toward -Z
	_model.scale = Vector3.ONE * scale_f
	add_child(_model)
	for side in ["left", "right"]:
		var f := _model.find_child("wheel-front-" + side, true, false) as Node3D
		var b := _model.find_child("wheel-back-" + side, true, false) as Node3D
		if f != null:
			_wheels_front.append(f)
			_wheel_base[f] = f.basis
		if b != null:
			_wheels_back.append(b)
			_wheel_base[b] = b.basis
	_body = _model.find_child("body", true, false) as Node3D
	if _body != null:
		_body_base = _body.transform


const HEAD_COLOR := Color("fff1cf")
const TAIL_COLOR := Color("ff2a1f")


## Headlights + tail lights (glow at night) and a fake beam on the road. `real` adds two
## SpotLights (player only: real lights are expensive on mobile).
func add_lights(real: bool) -> void:
	if _lights_root != null:
		_lights_root.queue_free()
	_lights_root = Node3D.new()
	_lights_root.name = "Lights"
	add_child(_lights_root)
	var bb := ArtKit.kenney_aabb("cars/" + model_name)
	var sc := model_scale
	# Model faces +Z but is rotated 180 deg, so its front (+Z) is our -Z.
	var front_z := -bb.end.z * sc
	var rear_z := -bb.position.z * sc
	var half_w := bb.size.x * 0.5 * sc
	var y := bb.size.y * 0.34 * sc
	var head_mat := ArtKit.night_glow(HEAD_COLOR, 3.5)
	var tail_mat := ArtKit.night_glow(TAIL_COLOR, 2.6)
	for sx in [-1.0, 1.0]:
		var h := ArtKit.box(_lights_root, Vector3(0.4, 0.16, 0.08), Vector3(sx * half_w * 0.62, y, front_z - 0.02), head_mat)
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var t := ArtKit.box(_lights_root, Vector3(0.36, 0.14, 0.08), Vector3(sx * half_w * 0.66, y, rear_z + 0.02), tail_mat)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ArtKit.light_pool(_lights_root, Vector3(0, 0.13, front_z - 8.0), Vector2(7.0, 15.0), HEAD_COLOR, 0.2)
	ArtKit.light_pool(_lights_root, Vector3(0, 0.13, rear_z + 1.6), Vector2(3.5, 3.0), TAIL_COLOR, 0.22)
	if real:
		for sx in [-1.0, 1.0]:
			var spot := SpotLight3D.new()
			spot.light_color = HEAD_COLOR
			spot.light_energy = 4.0
			spot.spot_range = 36.0
			spot.spot_angle = 30.0
			spot.spot_attenuation = 0.8
			spot.shadow_enabled = false
			spot.position = Vector3(sx * half_w * 0.62, y + 0.1, front_z - 0.1)
			spot.rotation_degrees = Vector3(-9.0, 0.0, 0.0)
			spot.add_to_group(&"night_only")
			spot.visible = ArtKit.lights_on
			_lights_root.add_child(spot)


func model() -> Node3D:
	return _model


## Called by the physics body at the end of each physics step.
func capture(xf: Transform3D) -> void:
	_prev = _curr
	_curr = xf


## Snap without interpolation (spawn, revive, origin shift).
func teleport(xf: Transform3D) -> void:
	_prev = xf
	_curr = xf
	global_transform = xf


func shift(offset: Vector3) -> void:
	_prev.origin += offset
	_curr.origin += offset


func interpolated() -> Transform3D:
	var f := clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	return _prev.interpolate_with(_curr, f)


func _process(delta: float) -> void:
	global_transform = interpolated()
	_spin = fmod(_spin + speed / (WHEEL_RADIUS * model_scale) * delta, TAU)
	_steer_vis = lerpf(_steer_vis, -steer * max_steer_angle, clampf(delta * 12.0, 0.0, 1.0))
	for w in _wheels_front:
		w.basis = Basis(Vector3.UP, _steer_vis) * Basis(Vector3.RIGHT, _spin) * (_wheel_base[w] as Basis)
	for w in _wheels_back:
		w.basis = Basis(Vector3.RIGHT, _spin) * (_wheel_base[w] as Basis)
	if _body != null:
		# Roll into the slide, pitch with acceleration; springy and capped.
		var k := clampf(delta * 8.0, 0.0, 1.0)
		_roll = lerpf(_roll, clampf(lateral * 0.018 + steer * speed * 0.0025, -0.09, 0.09), k)
		_pitch = lerpf(_pitch, clampf(accel * 0.006, -0.06, 0.06), k)
		# Model is rotated 180 deg, so its local X/Z are flipped relative to the car.
		var tilt := Basis(Vector3.FORWARD, _roll) * Basis(Vector3.RIGHT, _pitch)
		_body.transform = Transform3D(tilt * _body_base.basis, _body_base.origin)
