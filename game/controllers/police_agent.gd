class_name PoliceAgent
extends CharacterBody3D
## Police pursuer with a small state machine: PURSUE, INTERCEPT, RECOVER, DISENGAGE.
## Decisions run at a staggered 5-10 Hz; movement runs at physics rate. Uses local graph
## routes (no navmesh), limited prediction and capped rubber-banding.

enum Mode { PURSUE, INTERCEPT, RECOVER, DISENGAGE }

signal rammed_player(strength: float)

var graph: LaneGraph
var player: PlayerCar
var mode: int = Mode.PURSUE
var role_intercept: bool = false
var active: bool = false
var has_los: bool = false
var frozen: bool = false

var heading: float = 0.0
var speed: float = 0.0
var base_speed: float = 15.0
var rubber_cap: float = 4.0
var rubber_gain: float = 0.12
var aggression: float = 0.5
var accel: float = 13.0
var turn_rate: float = 2.5
var ai_interval: float = 0.125

var target_point: Vector3 = Vector3.ZERO
var _path: Array[Vector2i] = []
var _goal: Vector2i = Vector2i(999999, 999999)
var _repath_timer: float = 0.0
var _ai_timer: float = 0.0
var _stuck_timer: float = 0.0
var _recover_timer: float = 0.0
var _recover_steer: float = 1.0
var _flash_t: float = 0.0
var _recoil: float = 0.0  # after a ram, drop back so the player gets a window to turn away
const RAM_RECOIL_SECONDS := 2.5
const RAM_RECOIL_SPEED := 0.85
var visual: CarVisual
var _yaw_rate: float = 0.0
var _last_speed: float = 0.0
var _beacon: OmniLight3D
var _red: StandardMaterial3D
var _blue: StandardMaterial3D


func setup(lane_graph: LaneGraph, player_car: PlayerCar) -> void:
	graph = lane_graph
	player = player_car
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	floor_snap_length = 0.3
	add_to_group(&"origin_shift")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.2, 4.0)
	shape.shape = bs
	shape.position = Vector3(0, 0.62, 0)
	add_child(shape)
	deactivate()


func set_skin(model_name: String) -> void:
	if visual == null:
		visual = CarVisual.new()
		visual.name = "Visual"
		add_child(visual)
	if visual.model() == null or visual.get_meta(&"model", "") != model_name:
		visual.build(model_name)
		visual.add_lights(false)
		visual.set_meta(&"model", model_name)
		_add_light_flash()


## Flashing overlay on the model's built-in light bar so it reads from the high camera.
func _add_light_flash() -> void:
	_red = StandardMaterial3D.new()
	_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blue = StandardMaterial3D.new()
	_blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var holder := Node3D.new()
	visual.add_child(holder)
	var y := 1.12 * visual.model_scale
	ArtKit.box(holder, Vector3(0.42, 0.14, 0.3), Vector3(-0.3, y, 0.05), _red)
	ArtKit.box(holder, Vector3(0.42, 0.14, 0.3), Vector3(0.3, y, 0.05), _blue)
	# At night a real beacon washes the street red/blue (max 4 police: affordable).
	_beacon = OmniLight3D.new()
	_beacon.omni_range = 11.0
	_beacon.light_energy = 2.6
	_beacon.shadow_enabled = false
	_beacon.position = Vector3(0, y + 0.6, 0)
	_beacon.add_to_group(&"night_only")
	_beacon.visible = ArtKit.lights_on
	holder.add_child(_beacon)


func activate(pos: Vector3, new_heading: float, tuning: Dictionary) -> void:
	global_position = pos
	heading = new_heading
	rotation = Vector3(0, heading, 0)
	velocity = Vector3.ZERO
	apply_tuning(tuning)
	speed = base_speed * 0.6
	mode = Mode.PURSUE
	_path.clear()
	_goal = Vector2i(999999, 999999)
	_recoil = 0.0
	_stuck_timer = 0.0
	_recover_timer = 0.0
	_ai_timer = randf() * ai_interval  # stagger decisions across agents
	target_point = player.global_position if player != null else pos
	active = true
	frozen = false
	visible = true
	_yaw_rate = 0.0
	if visual != null:
		visual.visible = true
		visual.teleport(global_transform)
	collision_layer = 4
	set_physics_process(true)


func apply_tuning(tuning: Dictionary) -> void:
	base_speed = float(tuning.get("base_speed", base_speed))
	rubber_cap = float(tuning.get("rubber_cap", rubber_cap))
	rubber_gain = float(tuning.get("rubber_gain", rubber_gain))
	aggression = float(tuning.get("aggression", aggression))


func deactivate() -> void:
	active = false
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	global_position = Vector3(0, -60, 0)
	set_physics_process(false)
	if visual != null:
		visual.visible = false


func disengage() -> void:
	if mode != Mode.DISENGAGE:
		mode = Mode.DISENGAGE
		_path.clear()
		_goal = Vector2i(999999, 999999)


func distance_to_player() -> float:
	return global_position.distance_to(player.global_position)


func forward() -> Vector3:
	return LaneGraph.forward_of(heading)


func _physics_process(delta: float) -> void:
	if not active:
		return
	_flash(delta)
	if frozen:
		speed = move_toward(speed, 0.0, 14.0 * delta)
		_move(delta, 0.0)
		return
	_recoil = maxf(0.0, _recoil - delta)
	_ai_timer -= delta
	if _ai_timer <= 0.0:
		_ai_timer += ai_interval
		_think()
	_drive(delta)


func _think() -> void:
	var dist := distance_to_player()
	has_los = _check_los()
	_repath_timer -= ai_interval
	if mode == Mode.RECOVER:
		return
	if mode != Mode.DISENGAGE:
		if speed < 1.5 and dist > 10.0:
			_stuck_timer += ai_interval
			if _stuck_timer > 1.2:
				_stuck_timer = 0.0
				mode = Mode.RECOVER
				_recover_timer = 1.0
				_recover_steer = -1.0 if randf() < 0.5 else 1.0
				return
		else:
			_stuck_timer = 0.0
	match mode:
		Mode.DISENGAGE:
			var away := global_position - player.global_position
			away.y = 0.0
			_route_to(graph.world_to_node(global_position + away.normalized() * graph.cell_size * 3.0))
		_:
			if has_los and dist < 70.0 and (not role_intercept or dist < 30.0):
				mode = Mode.PURSUE
				# Limited prediction: lead the player by at most ~0.8 s, scaled by aggression.
				var lead := clampf(dist / 25.0, 0.0, 1.0) * lerpf(0.2, 0.8, aggression)
				if dist < 12.0 and aggression > 0.6:
					lead = 0.0  # close and aggressive: ram
				target_point = player.global_position + player.velocity * lead
				_path.clear()
			elif role_intercept and dist > 25.0:
				mode = Mode.INTERCEPT
				_route_to(_intercept_node())
			else:
				mode = Mode.PURSUE
				_route_to(graph.world_to_node(player.global_position))


func _intercept_node() -> Vector2i:
	var f := player.forward()
	var step := Vector2i(int(signf(f.x)), 0) if absf(f.x) > absf(f.z) else Vector2i(0, int(signf(f.z)))
	return graph.world_to_node(player.global_position) + step * 2


func _route_to(goal: Vector2i) -> void:
	var here := graph.world_to_node(global_position)
	if goal != _goal or _path.is_empty() or _repath_timer <= 0.0:
		_goal = goal
		_path = graph.find_path(here, goal, 300)
		_repath_timer = 1.0
	# Drop nodes we have reached.
	while _path.size() > 1 and graph.node_world(_path[0]).distance_to(global_position) < 9.0:
		_path.remove_at(0)
	if _path.size() > 1 and _path[0] == here:
		_path.remove_at(0)
	if _path.is_empty():
		target_point = player.global_position
	else:
		target_point = graph.node_world(_path[0])
		if _path[0] == goal and goal == graph.world_to_node(player.global_position):
			target_point = player.global_position


func _check_los() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.2, 0)
	var to := player.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return space.intersect_ray(q).is_empty()


func max_speed_now() -> float:
	if _recoil > 0.0:
		return player.speed * RAM_RECOIL_SPEED
	var dist := distance_to_player()
	return base_speed + clampf((dist - 30.0) * rubber_gain, 0.0, rubber_cap)


func _drive(delta: float) -> void:
	if mode == Mode.RECOVER:
		_recover_timer -= delta
		speed = move_toward(speed, -6.0, 16.0 * delta)
		heading = wrapf(heading + _recover_steer * 1.2 * delta, -PI, PI)
		_move(delta, speed)
		if _recover_timer <= 0.0:
			mode = Mode.PURSUE
			_path.clear()
		return
	var to_t := target_point - global_position
	to_t.y = 0.0
	var desired_speed := max_speed_now()
	if mode == Mode.DISENGAGE:
		desired_speed = base_speed * 0.8
	if to_t.length() > 0.5:
		var desired_heading := LaneGraph.heading_of(to_t.normalized())
		var diff := wrapf(desired_heading - heading, -PI, PI)
		var max_rate := turn_rate * clampf(absf(speed) / 5.0, 0.3, 1.0)
		var want := clampf(diff * 4.0, -max_rate, max_rate)
		_yaw_rate = move_toward(_yaw_rate, want, 9.0 * delta)
		heading = wrapf(heading + _yaw_rate * delta, -PI, PI)
		if absf(diff) > 0.9:
			desired_speed *= 0.72
	var rate := accel if speed < desired_speed else 14.0
	speed = move_toward(speed, desired_speed, rate * delta)
	_move(delta, speed)


func _move(delta: float, spd: float) -> void:
	rotation = Vector3(0, heading, 0)
	var planar := forward() * spd
	velocity = Vector3(planar.x, -2.0, planar.z)
	var pre := velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is PlayerCar:
			var n := col.get_normal()
			var rel := maxf(0.0, (pre - player.velocity).dot(-n))
			var strength := rel * (0.6 + aggression) + aggression * 6.0
			player.apply_vehicle_hit(self, strength)
			rammed_player.emit(strength)
			speed *= 0.5
			_recoil = RAM_RECOIL_SECONDS
		elif other is StaticBody3D:
			var n2 := col.get_normal()
			if absf(forward().dot(n2)) > 0.7:
				speed *= 0.5
	if visual != null:
		visual.speed = spd
		visual.steer = clampf(-_yaw_rate / maxf(turn_rate, 0.1), -1.0, 1.0)
		visual.accel = (spd - _last_speed) / maxf(delta, 0.0001)
		visual.capture(global_transform)
	_last_speed = spd


func _flash(delta: float) -> void:
	if _red == null:
		return
	_flash_t += delta * 6.0
	var on := fmod(_flash_t, 2.0) < 1.0
	_red.albedo_color = Color("ff2233") if on else Color("4a1015")
	_blue.albedo_color = Color("1b2a50") if on else Color("3a7bff")
	if _beacon != null:
		_beacon.light_color = Color("ff2a3a") if on else Color("3a6bff")


func apply_origin_shift(offset: Vector3) -> void:
	global_position += offset
	target_point += offset
	if visual != null:
		visual.shift(offset)
