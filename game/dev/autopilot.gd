class_name Autopilot
extends RefCounted
## Drives the player along the lane graph for automated tests: follows its lane, picks the
## junction exit that leads away from police, dodges traffic by switching lanes and brakes
## (drifting) into sharp turns. Writes into InputRouter's override fields.

var run: RunRoot
var rng := RandomNumberGenerator.new()
var _prev: Vector2i
var _next: Vector2i
var _ready_path: bool = false
var _stuck_time: float = 0.0
var _unstick_time: float = 0.0
var _unstick_dir: float = 1.0


func _init(run_root: RunRoot, seed_value: int = 1) -> void:
	run = run_root
	rng.seed = seed_value


func reset() -> void:
	_ready_path = false


func _axis_step(fwd: Vector3) -> Vector2i:
	if absf(fwd.x) > absf(fwd.z):
		return Vector2i(int(signf(fwd.x)), 0)
	return Vector2i(0, int(signf(fwd.z)))


func _init_path() -> void:
	var g := run.graph
	var p := run.player
	var step := _axis_step(p.forward())
	var here := g.world_to_node(p.global_position)
	# The node behind us along the travel axis, and the one ahead.
	var to_here := g.node_world(here) - p.global_position
	if to_here.dot(p.forward()) > 0.0:
		_next = here
		_prev = here - step
	else:
		_prev = here
		_next = here + step
	_ready_path = true


func _choose_exit() -> Vector2i:
	var g := run.graph
	var options: Array[Vector2i] = []
	for nb in g.neighbors(_next):
		if nb != _prev:
			options.append(nb)
	if options.is_empty():
		return _prev
	var best: Vector2i = options[rng.randi_range(0, options.size() - 1)]
	var best_score := -INF
	for o in options:
		var pos := g.node_world(o)
		var score := rng.randf() * 30.0
		for cop in run.director.police():
			score += minf((cop as Node3D).global_position.distance_to(pos), 150.0)
		if score > best_score:
			best_score = score
			best = o
	return best


func update(router: InputRouter) -> void:
	var g := run.graph
	var p := run.player
	if not _ready_path:
		_init_path()
	var node_pos := g.node_world(_next)
	if node_pos.distance_to(p.global_position) < g.half_road() + 2.0:
		var after := _choose_exit()
		_prev = _next
		_next = after
		node_pos = g.node_world(_next)
	var dir := (node_pos - g.node_world(_prev)).normalized()
	var right := Vector3(-dir.z, 0.0, dir.x)
	var lane := g.lane_offset
	# Traffic or police ahead in our lane: use the other lane.
	for t in run.traffic.agents():
		var to := (t as Node3D).global_position - p.global_position
		var along := to.dot(dir)
		if along > 0.0 and along < 18.0 and absf(to.dot(right) - lane) < 2.5:
			lane = -lane
			break
	var along_now := (p.global_position - g.node_world(_prev)).dot(dir)
	var aim := g.node_world(_prev) + dir * minf(along_now + 11.0, g.cell_size) + right * lane
	var to_aim := aim - p.global_position
	to_aim.y = 0.0
	var desired := LaneGraph.heading_of(to_aim.normalized())
	var diff := wrapf(desired - p.heading, -PI, PI)
	router.override_active = true
	router.override_steer = clampf(-diff * 2.2, -1.0, 1.0)
	var dist_to_node := node_pos.distance_to(p.global_position)
	router.override_brake = (absf(diff) > 0.6 and p.speed > 9.0) or (dist_to_node < 14.0 and p.speed > 15.0)
	# Unstick: pinned for a second -> full lock away for a moment, no brake.
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	_stuck_time = _stuck_time + dt if p.speed < 2.0 else 0.0
	if _stuck_time > 1.0 and _unstick_time <= 0.0:
		_unstick_time = 1.2
		_unstick_dir = -1.0 if rng.randf() < 0.5 else 1.0
	if _unstick_time > 0.0:
		_unstick_time -= dt
		router.override_steer = _unstick_dir
		router.override_brake = false
		if _unstick_time <= 0.0:
			_ready_path = false


func release(router: InputRouter) -> void:
	router.override_active = false
	router.override_steer = 0.0
	router.override_brake = false
