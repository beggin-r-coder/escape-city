class_name ChaseCamera
extends Camera3D
## High third-person chase camera with a stable horizon (no roll). Widens near
## intersections and at speed so the next decision is visible. Smoothed heading keeps
## drifts readable. Supports reduced motion (no shake) and a slow menu orbit.

var target: PlayerCar
var graph: LaneGraph
var distance: float = 12.0
var height: float = 25.0
var look_ahead: float = 7.0
var base_fov: float = 55.0
var wide_fov: float = 64.0
var reduced_motion: bool = false
var orbit: bool = false

var _cam_heading: float = 0.0
var _shake: float = 0.0
var _orbit_angle: float = 0.0


func setup(player_car: PlayerCar, lane_graph: LaneGraph) -> void:
	target = player_car
	graph = lane_graph
	fov = base_fov
	near = 0.5
	far = 240.0
	add_to_group(&"origin_shift")


func snap() -> void:
	if target == null:
		return
	_cam_heading = target.heading
	_update(1.0, true)


func add_shake(amount: float) -> void:
	if not reduced_motion:
		_shake = clampf(_shake + amount, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_update(delta, false)


func _update(delta: float, instant: bool) -> void:
	if target == null:
		return
	var tpos := target.global_position
	if orbit:
		_orbit_angle += delta * 0.15
		var offset := Vector3(sin(_orbit_angle), 0, cos(_orbit_angle)) * 42.0 + Vector3(0, 46.0, 0)
		global_position = tpos + offset
		look_at(tpos, Vector3.UP)
		fov = base_fov
		return
	var k := 1.0 if instant else clampf(delta * 3.0, 0.0, 1.0)
	_cam_heading = lerp_angle(_cam_heading, target.heading, k)
	var fwd := LaneGraph.forward_of(_cam_heading)
	var speed_t := clampf(target.speed / 22.0, 0.0, 1.0)
	var near_junction := graph.nearest_intersection_distance(tpos) < graph.half_road() + 10.0
	var dist := distance + speed_t * 2.0
	var h := height + speed_t * 2.0 + (2.5 if near_junction else 0.0)
	var desired := tpos - fwd * dist + Vector3.UP * h
	var pk := 1.0 if instant else clampf(delta * 6.0, 0.0, 1.0)
	global_position = global_position.lerp(desired, pk)
	var target_fov := lerpf(base_fov, wide_fov, maxf(speed_t * 0.6, 1.0 if near_junction else 0.0))
	fov = lerpf(fov, target_fov, 1.0 if instant else clampf(delta * 2.0, 0.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.5)
		var s := _shake * _shake * 0.8
		global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	look_at(tpos + fwd * look_ahead, Vector3.UP)


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
