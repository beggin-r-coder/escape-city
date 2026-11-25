class_name TrafficAgent
extends AnimatableBody3D
## Lane-following traffic. Drives right-hand lanes between graph nodes, stops at the
## stop line until the TrafficManager grants the intersection slot, turns along a
## quadratic curve, then releases the slot. Keeps a gap to vehicles ahead.
## Holds only logical graph nodes, never chunk references.

enum Mode { LANE, WAIT, TURN }

var manager: TrafficManager
var graph: LaneGraph
var current_velocity: Vector3 = Vector3.ZERO
var cruise: float = 9.0
var speed: float = 0.0
var active: bool = false
var shape_kind: int = 0

var _a: Vector2i
var _b: Vector2i
var _c: Vector2i
var _mode: int = Mode.LANE
var _s: float = 0.0  # distance travelled along current segment
var _stun: float = 0.0
var _wait: float = 0.0
var _sense_timer: float = 0.0
var _blocked: bool = false
var visual: CarVisual
var _last_speed: float = 0.0
var _skip_velocity: bool = false


func setup(traffic_manager: TrafficManager, lane_graph: LaneGraph) -> void:
	manager = traffic_manager
	graph = lane_graph
	collision_layer = 8
	collision_mask = 0
	sync_to_physics = false
	add_to_group(&"origin_shift")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.4, 4.2)
	shape.shape = bs
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	deactivate()


func set_look(model_name: String) -> void:
	if visual == null:
		visual = CarVisual.new()
		visual.name = "Visual"
		add_child(visual)
	if visual.get_meta(&"model", "") != model_name:
		visual.build(model_name)
		visual.add_lights(false)
		visual.set_meta(&"model", model_name)


func activate(a: Vector2i, b: Vector2i, start_s: float, cruise_speed: float) -> void:
	_a = a
	_b = b
	_mode = Mode.LANE
	_s = start_s
	cruise = cruise_speed
	speed = cruise_speed
	_stun = 0.0
	_wait = 0.0
	active = true
	visible = true
	collision_layer = 8
	process_mode = Node.PROCESS_MODE_INHERIT
	_apply_pose(_lane_pos(_s), _lane_dir())
	if visual != null:
		visual.visible = true
		visual.teleport(global_transform)


func deactivate() -> void:
	if manager != null:
		manager.release_slot(_b, self)
	active = false
	visible = false
	collision_layer = 0
	current_velocity = Vector3.ZERO
	global_position = Vector3(0, -50, 0)
	if visual != null:
		visual.visible = false


func on_bumped() -> void:
	_stun = 1.2
	speed = 0.0


func _segment_len() -> float:
	return graph.cell_size - 2.0 * (graph.half_road() + 1.0)


func _lane_dir() -> Vector3:
	return (graph.node_world(_b) - graph.node_world(_a)).normalized()


func _lane_pos(s: float) -> Vector3:
	return graph.lane_point(_a, _b, graph.half_road() + 1.0 + s)


func _turn_points() -> Array[Vector3]:
	var p0 := graph.lane_point(_a, _b, graph.cell_size - graph.half_road() - 1.0)
	var p2 := graph.lane_point(_b, _c, graph.half_road() + 1.0)
	var d := _lane_dir()
	var p1: Vector3
	if _c == _a:
		p1 = graph.node_world(_b)
	else:
		p1 = p0 + d * (p2 - p0).dot(d)
	var pts: Array[Vector3] = [p0, p1, p2]
	return pts


static func _bezier(p: Array[Vector3], t: float) -> Vector3:
	var u := 1.0 - t
	return p[0] * u * u + p[1] * 2.0 * u * t + p[2] * t * t


func _turn_len(p: Array[Vector3]) -> float:
	return maxf(1.0, p[0].distance_to(p[1]) + p[1].distance_to(p[2]))


func _physics_process(delta: float) -> void:
	if not active:
		return
	_stun = maxf(0.0, _stun - delta)
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = 0.1
		_blocked = manager.is_blocked_ahead(self, global_position, -global_transform.basis.z)
	var target := 0.0 if (_stun > 0.0 or _blocked) else cruise
	speed = move_toward(speed, target, (14.0 if target < speed else 4.0) * delta)
	var prev := global_position
	match _mode:
		Mode.LANE:
			_s += speed * delta
			if _s >= _segment_len():
				_s = _segment_len()
				_mode = Mode.WAIT
				_wait = 0.0
			_apply_pose(_lane_pos(_s), _lane_dir())
		Mode.WAIT:
			speed = 0.0
			_wait += delta
			if manager.request_slot(_b, self, _wait):
				_c = manager.choose_next(_a, _b)
				_mode = Mode.TURN
				_s = 0.0
				speed = cruise * 0.6
		Mode.TURN:
			var pts := _turn_points()
			var total := _turn_len(pts)
			_s += maxf(speed, 3.0) * delta
			var t := clampf(_s / total, 0.0, 1.0)
			var pos := _bezier(pts, t)
			var ahead := _bezier(pts, minf(1.0, t + 0.05))
			var dir := ahead - pos
			if dir.length_squared() < 0.0001:
				dir = (pts[2] - pts[1]).normalized()
			_apply_pose(pos, dir.normalized())
			if t >= 1.0:
				manager.release_slot(_b, self)
				_a = _b
				_b = _c
				_mode = Mode.LANE
				_s = 0.0
	if _skip_velocity:
		_skip_velocity = false
	else:
		current_velocity = (global_position - prev) / maxf(delta, 0.0001)
	if visual != null:
		visual.speed = speed
		visual.steer = 0.0 if _mode != Mode.TURN else (0.6 if _turn_sign() > 0.0 else -0.6)
		visual.accel = (speed - _last_speed) / maxf(delta, 0.0001)
		visual.capture(global_transform)
	_last_speed = speed


func _apply_pose(pos: Vector3, dir: Vector3) -> void:
	var h := LaneGraph.heading_of(dir)
	global_transform = Transform3D(Basis(Vector3.UP, h), Vector3(pos.x, 0.0, pos.z))


func waiting_node() -> Vector2i:
	return _b


## +1 for a right turn, -1 for a left turn, 0 straight (for steering the front wheels).
func _turn_sign() -> float:
	var d1 := _lane_dir()
	var d2 := (graph.node_world(_c) - graph.node_world(_b)).normalized()
	var cross := d1.x * d2.z - d1.z * d2.x
	return signf(cross)


func apply_origin_shift(_offset: Vector3) -> void:
	# Pose is recomputed from logical graph nodes every step; skip one velocity sample.
	_skip_velocity = true
	if visual != null:
		visual.shift(_offset)
