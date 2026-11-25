class_name ChaseCamera
extends Camera3D
## High third-person chase camera with a stable horizon (no roll). Widens near
## intersections and at speed so the next decision is visible. Smoothed heading keeps
## drifts readable. Supports reduced motion (no shake) and a slow menu orbit.

var target: PlayerCar
var graph: LaneGraph
var distance: float = 9.0
var height: float = 19.0
var look_ahead: float = 13.0
var base_fov: float = 52.0  # horizontal (KEEP_WIDTH): constant road width in portrait
var wide_fov: float = 60.0
var reduced_motion: bool = false
var orbit: bool = false
## Dev review mode: locked behind the direction of travel (no lag, no lean), so any rotation
## seen on screen is the car's own slide / tail swing / roll.
var rigid: bool = false

var _cam_heading: float = 0.0
var _look: Vector3 = Vector3.ZERO
var _shake: float = 0.0
var _orbit_angle: float = 0.0


func setup(player_car: PlayerCar, lane_graph: LaneGraph) -> void:
	target = player_car
	graph = lane_graph
	keep_aspect = Camera3D.KEEP_WIDTH
	fov = base_fov
	near = 0.5
	far = 260.0
	add_to_group(&"origin_shift")


func snap() -> void:
	if target == null:
		return
	_cam_heading = target.heading
	_update(1.0, true)


func add_shake(amount: float) -> void:
	if not reduced_motion:
		_shake = clampf(_shake + amount, 0.0, 1.0)


## Per rendered frame, following the interpolated car: smooth at any refresh rate.
func _process(delta: float) -> void:
	_update(delta, false)


static func _damp(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


func _target_xf() -> Transform3D:
	if target.visual != null and target.visual.is_inside_tree():
		return target.visual.interpolated()
	return target.global_transform


func _update(delta: float, instant: bool) -> void:
	if target == null:
		return
	var txf := _target_xf()
	var tpos := txf.origin
	if orbit:
		_orbit_angle += delta * 0.15
		var offset := Vector3(sin(_orbit_angle), 0, cos(_orbit_angle)) * 40.0 + Vector3(0, 52.0, 0)
		global_position = tpos + offset
		look_at(tpos, Vector3.UP)
		fov = base_fov
		return
	var car_heading := LaneGraph.heading_of(-txf.basis.z)
	# In a slide, look where the car is going rather than where its nose points, so drifts
	# feel fluid instead of swinging the whole view.
	var planar_vel := Vector3(target.velocity.x, 0.0, target.velocity.z)
	if planar_vel.length() > 5.0:
		var travel := LaneGraph.heading_of(planar_vel.normalized())
		var slide := clampf(absf(target.lateral) / 6.0, 0.0, 1.0)
		car_heading = lerp_angle(car_heading, travel, 0.6 * slide)
	if rigid and planar_vel.length() > 1.0:
		car_heading = LaneGraph.heading_of(planar_vel.normalized())
		instant = true
	_cam_heading = lerp_angle(_cam_heading, car_heading, 1.0 if instant else _damp(5.0, delta))
	var fwd := LaneGraph.forward_of(_cam_heading)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var speed_t := clampf(target.speed / 22.0, 0.0, 1.0)
	var near_junction := graph.nearest_intersection_distance(tpos) < graph.half_road() + 10.0
	var dist := distance + speed_t * 3.0
	var h := height + speed_t * 3.0 + (2.0 if near_junction else 0.0)
	var desired := tpos - fwd * dist + Vector3.UP * h
	global_position = desired if instant else global_position.lerp(desired, _damp(7.0, delta))
	# Look ahead of the car, leaning slightly into a drift.
	var lean := 0.0 if rigid else target.lateral * 0.6
	var look_target := tpos + fwd * (look_ahead + speed_t * 4.0) - right * lean
	_look = look_target if instant else _look.lerp(look_target, _damp(9.0, delta))
	var target_fov := lerpf(base_fov, wide_fov, maxf(speed_t * 0.5, 0.6 if near_junction else 0.0))
	fov = target_fov if instant else lerpf(fov, target_fov, _damp(2.0, delta))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var sk := _shake * _shake * 0.8
		global_position += Vector3(randf_range(-sk, sk), randf_range(-sk, sk), randf_range(-sk, sk))
	look_at(_look, Vector3.UP)


## Screen direction (x right, y down) from the player toward an off-screen point, measured
## on the ground plane in the camera's yaw frame. ZERO if the point is visible.
func offscreen_direction(world_pos: Vector3) -> Vector2:
	if is_position_in_frustum(world_pos + Vector3(0, 1.0, 0)):
		return Vector2.ZERO
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = LaneGraph.forward_of(_cam_heading)
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var d := world_pos - target.global_position
	var v := Vector2(d.dot(right), -d.dot(fwd))
	if v.length_squared() < 0.0001:
		return Vector2(0, 1)
	return v.normalized()


func apply_origin_shift(offset: Vector3) -> void:
	global_position += offset
	_look += offset
