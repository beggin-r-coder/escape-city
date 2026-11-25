class_name PlayerCar
extends CharacterBody3D
## Ground-following arcade car: heading + longitudinal speed + lateral slip.
## Auto-throttle holds cruise speed; brake slows; steering while braking adds a capped
## drift assist. Static walls block movement; vehicle contacts apply scripted slowdown
## and damage instead of unstable rigid-body pileups. Health 0 = wrecked.

signal wrecked
signal damaged(amount: float, health: float)
signal impact(strength: float)
signal drift_changed(active: bool)

var config: HandlingConfig
var router: InputRouter
var cruise_speed: float = 14.0
var heading: float = 0.0
var speed: float = 0.0
var lateral: float = 0.0
var steer: float = 0.0
var health: float = 100.0
var drifting: bool = false
var braking: bool = false
var controls_enabled: bool = true
var damage_enabled: bool = true
var invulnerable_timer: float = 0.0
var distance_travelled: float = 0.0
var steer_used: Vector2 = Vector2.ZERO  # tutorial tracking: x = left used, y = right used
var drift_time: float = 0.0
var visual: CarVisual
var yaw_rate: float = 0.0

var _is_wrecked: bool = false
var _contact_cooldowns: Dictionary = {}
var _prev_pos: Vector3 = Vector3.ZERO
var _last_speed: float = 0.0


func setup(handling: HandlingConfig, input_router: InputRouter) -> void:
	config = handling
	router = input_router
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	floor_snap_length = 0.3
	add_to_group(&"origin_shift")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.2, 4.0)
	shape.shape = bs
	shape.position = Vector3(0, 0.62, 0)
	add_child(shape)


func set_look(model_name: String) -> void:
	if visual == null:
		visual = CarVisual.new()
		visual.name = "Visual"
		add_child(visual)
	visual.build(model_name)
	visual.teleport(global_transform)


func reset_at(pos: Vector3, new_heading: float, initial_speed: float = 0.0) -> void:
	global_position = pos
	heading = new_heading
	rotation = Vector3(0, heading, 0)
	speed = initial_speed
	lateral = 0.0
	steer = 0.0
	velocity = Vector3.ZERO
	health = config.max_health
	drifting = false
	braking = false
	_is_wrecked = false
	invulnerable_timer = 0.0
	distance_travelled = 0.0
	steer_used = Vector2.ZERO
	drift_time = 0.0
	yaw_rate = 0.0
	_last_speed = initial_speed
	_contact_cooldowns.clear()
	_prev_pos = pos
	if visual != null:
		visual.teleport(global_transform)


func forward() -> Vector3:
	return LaneGraph.forward_of(heading)


func right() -> Vector3:
	return Vector3(cos(heading), 0.0, -sin(heading))


func is_wrecked() -> bool:
	return _is_wrecked


func _physics_process(delta: float) -> void:
	if config == null:
		return
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	for k in _contact_cooldowns.keys():
		_contact_cooldowns[k] = float(_contact_cooldowns[k]) - delta
		if float(_contact_cooldowns[k]) <= 0.0:
			_contact_cooldowns.erase(k)

	var steer_in := 0.0
	var brake_in := false
	if controls_enabled and not _is_wrecked and router != null:
		steer_in = router.get_steer()
		brake_in = router.is_brake_held()
	steer = move_toward(steer, steer_in, config.steer_response * delta)
	braking = brake_in
	if steer_in < -0.5:
		steer_used.x = 1.0
	elif steer_in > 0.5:
		steer_used.y = 1.0

	# Longitudinal: auto-throttle toward cruise, brake toward min speed.
	if _is_wrecked:
		speed = move_toward(speed, 0.0, 12.0 * delta)
	elif braking:
		var decel := config.drift_brake_deceleration if drifting else config.brake_deceleration
		speed = move_toward(speed, config.min_brake_speed, decel * delta)
	elif controls_enabled:
		var target := minf(cruise_speed, config.max_speed)
		var rate := config.acceleration if speed < target else config.acceleration * 0.5
		speed = move_toward(speed, target, rate * delta)
	else:
		speed = move_toward(speed, 0.0, config.brake_deceleration * delta)

	# Drift assist: braking + steering above a speed threshold, capped yaw and slip.
	var want_drift := braking and absf(steer) > config.drift_steer_threshold and speed > config.drift_min_speed
	if want_drift != drifting:
		drifting = want_drift
		drift_changed.emit(drifting)
	if drifting:
		drift_time += delta

	var authority := clampf(speed / config.steer_full_speed, 0.0, 1.0)
	var t := clampf(speed / config.max_speed, 0.0, 1.0)
	var rate_yaw := lerpf(config.steer_rate_low_speed, config.steer_rate_high_speed, t)
	var yaw := -steer * rate_yaw * authority
	if drifting:
		yaw *= config.drift_yaw_multiplier
	yaw_rate = move_toward(yaw_rate, yaw, config.yaw_response * delta)
	heading = wrapf(heading + yaw_rate * delta, -PI, PI)

	if drifting:
		lateral = clampf(lateral - steer * config.drift_slip_accel * delta, -config.max_lateral_slip, config.max_lateral_slip)
	lateral = move_toward(lateral, 0.0, (config.drift_grip if drifting else config.grip) * delta)

	rotation = Vector3(0, heading, 0)
	var planar := forward() * speed + right() * lateral
	velocity = Vector3(planar.x, -2.0, planar.z)
	var pre_velocity := velocity
	move_and_slide()
	_handle_collisions(pre_velocity)
	# Keep the speed state honest: if the car is pinned (boxed in by police, wedged on a
	# wall) its measured forward motion is what counts, so capture rules see the truth.
	var real := get_real_velocity()
	var actual_forward := Vector3(real.x, 0.0, real.z).dot(forward())
	if actual_forward < speed - 0.5:
		speed = maxf(actual_forward, 0.0)

	var moved := global_position - _prev_pos
	moved.y = 0.0
	distance_travelled += moved.length()
	_prev_pos = global_position

	if visual != null:
		visual.speed = speed
		visual.steer = steer
		visual.lateral = lateral
		visual.accel = (speed - _last_speed) / maxf(delta, 0.0001)
		visual.capture(global_transform)
	_last_speed = speed


func _handle_collisions(pre_velocity: Vector3) -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		var n := col.get_normal()
		n.y = 0.0
		if n.length_squared() < 0.01:
			continue
		n = n.normalized()
		if other is PoliceAgent or other is TrafficAgent:
			var other_vel := Vector3.ZERO
			if other is PoliceAgent:
				other_vel = (other as PoliceAgent).velocity
			else:
				other_vel = (other as TrafficAgent).current_velocity
			var rel := maxf(0.0, (pre_velocity - other_vel).dot(-n))
			apply_vehicle_hit(other as Node, rel)
		else:
			_wall_contact(other, n, pre_velocity)


func _wall_contact(other: Object, n: Vector3, pre_velocity: Vector3) -> void:
	var planar := Vector3(pre_velocity.x, 0, pre_velocity.z)
	var impact_speed := maxf(0.0, planar.dot(-n))
	if impact_speed < 1.0:
		return
	var head_on := speed > 0.5 and impact_speed > 0.7 * speed
	if head_on:
		speed = maxf(2.0, speed * config.head_on_speed_keep)
	else:
		speed = maxf(0.0, speed - impact_speed * 0.5)
	# Align heading along the wall tangent so the player is never pinned facing it.
	var tangent := planar - n * planar.dot(n)
	if tangent.length() > 0.5:
		heading = lerp_angle(heading, LaneGraph.heading_of(tangent.normalized()), 0.5)
	lateral *= 0.3
	yaw_rate *= 0.5
	var key := other.get_instance_id() if other != null else 0
	if impact_speed > config.wall_damage_min_speed and not _contact_cooldowns.has(key):
		_contact_cooldowns[key] = config.contact_cooldown
		take_damage((impact_speed - config.wall_damage_min_speed) * config.wall_damage_per_mps + 4.0)
		impact.emit(impact_speed)


## Scripted vehicle contact used by both the player's own collisions and police rams.
func apply_vehicle_hit(source: Node, relative_speed: float) -> void:
	if source == null:
		return
	var key := source.get_instance_id()
	if _contact_cooldowns.has(key):
		return
	_contact_cooldowns[key] = config.contact_cooldown
	speed *= config.vehicle_slowdown
	impact.emit(relative_speed)
	if source is TrafficAgent:
		(source as TrafficAgent).on_bumped()
	if relative_speed > 1.5:
		take_damage(relative_speed * config.vehicle_damage_per_mps)


func on_prop_smashed() -> void:
	speed *= config.prop_slowdown


func take_damage(amount: float) -> void:
	if not damage_enabled or invulnerable_timer > 0.0 or _is_wrecked or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount, health)
	if health <= 0.0:
		_is_wrecked = true
		wrecked.emit()


func restore_for_revive(pos: Vector3, new_heading: float, health_fraction: float, protect_seconds: float) -> void:
	global_position = pos
	heading = new_heading
	rotation = Vector3(0, heading, 0)
	speed = 0.0
	lateral = 0.0
	velocity = Vector3.ZERO
	health = config.max_health * health_fraction
	_is_wrecked = false
	invulnerable_timer = protect_seconds
	yaw_rate = 0.0
	_contact_cooldowns.clear()
	_prev_pos = pos
	if visual != null:
		visual.teleport(global_transform)


func apply_origin_shift(offset: Vector3) -> void:
	global_position += offset
	_prev_pos += offset
	if visual != null:
		visual.shift(offset)
