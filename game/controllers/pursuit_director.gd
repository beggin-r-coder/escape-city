class_name PursuitDirector
extends Node
## Caps pursuit pressure and enforces spawn fairness.
##  - Police count / speed / aggression come from the DifficultyProfile band.
##  - 30-60 s pressure/recovery waves instead of limitless escalation.
##  - Spawns only on graph-connected roads outside the view frustum, at least
##    min_spawn_travel_seconds of travel away, never in front of the player, never
##    overlapping player/traffic exclusion zones.
##  - Escape bonus: no line of sight and distance above threshold for 5 s, 20 s cooldown,
##    paid at most once per disengagement.

signal escape_verified(total: int)
signal band_changed(band: int)
signal wave_changed(pressure: bool)
signal police_spawned(agent: PoliceAgent)

const MAX_POLICE := 4

var profile: DifficultyProfile
var graph: LaneGraph
var player: PlayerCar
var camera: Camera3D
var pool: ChunkPool
var traffic: TrafficManager
var catalog: CosmeticCatalog
var rng: RandomNumberGenerator

var running: bool = false
var band: int = 0
var heat_bonus: float = 0.0
var pressure: bool = true
var escapes: int = 0
var engaged: bool = false
var escape_timer: float = 0.0
var escape_cooldown: float = 0.0
var spawn_rejections: int = 0

var _wave_timer: float = 0.0
var _spawn_timer: float = 0.0
var _protect_timer: float = 0.0
var _min_d: float = INF
var _any_los: bool = false
var _police_parent: Node


func setup(difficulty: DifficultyProfile, lane_graph: LaneGraph, player_car: PlayerCar, cam: Camera3D, object_pool: ChunkPool, traffic_manager: TrafficManager, cosmetics: CosmeticCatalog, random: RandomNumberGenerator, police_parent: Node) -> void:
	profile = difficulty
	graph = lane_graph
	player = player_car
	camera = cam
	pool = object_pool
	traffic = traffic_manager
	catalog = cosmetics
	rng = random
	_police_parent = police_parent
	pool.register_type(&"police", _make_police, MAX_POLICE, _reset_police)


func _make_police() -> Object:
	var p := PoliceAgent.new()
	p.name = "Police"
	_police_parent.add_child(p)
	p.setup(graph, player)
	return p


func _reset_police(obj: Object) -> void:
	(obj as PoliceAgent).deactivate()


func police() -> Array:
	return pool.active(&"police")


func police_nodes() -> Array:
	return police()


func reset() -> void:
	pool.release_all(&"police")
	running = false
	band = 0
	heat_bonus = 0.0
	pressure = true
	escapes = 0
	engaged = false
	escape_timer = 0.0
	escape_cooldown = 0.0
	spawn_rejections = 0
	_wave_timer = profile.pressure_seconds
	_spawn_timer = 0.0
	_protect_timer = 0.0
	_min_d = INF
	_any_los = false


func start() -> void:
	running = true
	_spawn_timer = 0.5


func stop() -> void:
	running = false
	for p in police():
		(p as PoliceAgent).frozen = true


## Revive / protected countdown: clear police and delay respawns.
func protect(seconds: float) -> void:
	pool.release_all(&"police")
	_protect_timer = seconds
	_spawn_timer = seconds
	engaged = false
	escape_timer = 0.0


func add_heat(seconds: float) -> void:
	heat_bonus += seconds


func tuning_for_band(b: int) -> Dictionary:
	var factor := DifficultyProfile.pick_f(profile.police_speed_factor, b)
	if not pressure:
		factor *= 0.92
	return {
		"base_speed": player.cruise_speed * factor,
		"rubber_cap": profile.rubber_band_cap,
		"rubber_gain": profile.rubber_band_gain,
		"aggression": DifficultyProfile.pick_f(profile.police_aggression, b),
	}


func desired_police() -> int:
	var n := DifficultyProfile.pick_i(profile.police_count, band)
	if not pressure and n > 1:
		n -= 1
	return clampi(n, 0, MAX_POLICE)


func update(delta: float, survival_time: float) -> void:
	if not running:
		return
	var new_band := profile.band_for_time(survival_time + heat_bonus)
	if new_band != band:
		band = new_band
		band_changed.emit(band)
	_protect_timer = maxf(0.0, _protect_timer - delta)
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_set_pressure(not pressure)
	_measure()
	_update_escape(delta)
	_manage_roster()
	_spawn_timer -= delta
	var chasing := 0
	for p in police():
		if (p as PoliceAgent).mode != PoliceAgent.Mode.DISENGAGE:
			chasing += 1
	if _protect_timer <= 0.0 and _spawn_timer <= 0.0 and chasing < desired_police():
		_spawn_timer = maxf(1.5, profile.spawn_interval - float(band) * 0.4)
		if not try_spawn():
			_spawn_timer = 0.5
			spawn_rejections += 1


func _set_pressure(value: bool) -> void:
	pressure = value
	_wave_timer = profile.pressure_seconds if pressure else profile.recovery_seconds
	wave_changed.emit(pressure)


func _measure() -> void:
	_min_d = INF
	_any_los = false
	for p in police():
		var cop: PoliceAgent = p
		if cop.mode == PoliceAgent.Mode.DISENGAGE:
			continue
		var d := cop.distance_to_player()
		_min_d = minf(_min_d, d)
		if cop.has_los:
			_any_los = true


func nearest_police_distance() -> float:
	return _min_d


func any_line_of_sight() -> bool:
	return _any_los


func _update_escape(delta: float) -> void:
	escape_cooldown = maxf(0.0, escape_cooldown - delta)
	if not engaged and _min_d < profile.engage_distance and _any_los:
		engaged = true
	if engaged and not _any_los and _min_d > profile.escape_distance:
		escape_timer += delta
	else:
		escape_timer = 0.0
	if engaged and escape_timer >= profile.escape_hold_seconds and escape_cooldown <= 0.0:
		escapes += 1
		engaged = false
		escape_timer = 0.0
		escape_cooldown = profile.escape_cooldown_seconds
		escape_verified.emit(escapes)
		_set_pressure(false)  # reward the escape with a recovery wave


func escape_progress() -> float:
	if not engaged:
		return 0.0
	return clampf(escape_timer / profile.escape_hold_seconds, 0.0, 1.0)


func _manage_roster() -> void:
	var tuning := tuning_for_band(band)
	var list := police()
	var want := desired_police()
	var intercepts := int(floor(float(want) * DifficultyProfile.pick_f(profile.intercept_share, band)))
	var chasing: Array = []
	for p in list:
		var cop: PoliceAgent = p
		var d := cop.distance_to_player()
		var seen := _visible(cop.global_position)
		if cop.mode == PoliceAgent.Mode.DISENGAGE:
			if d > 120.0 and not seen:
				pool.release(cop)
			continue
		if d > 230.0 and not seen:
			pool.release(cop)  # replaced by a fair respawn closer in
			continue
		cop.apply_tuning(tuning)
		chasing.append(cop)
	# Too many chasers (recovery wave): the farthest disengages.
	var nearer := func(a: PoliceAgent, b: PoliceAgent) -> bool:
		return a.distance_to_player() < b.distance_to_player()
	chasing.sort_custom(nearer)
	while chasing.size() > want:
		var extra: PoliceAgent = chasing.pop_back()
		extra.disengage()
	for k in chasing.size():
		(chasing[k] as PoliceAgent).role_intercept = k >= chasing.size() - intercepts and k > 0


func _visible(p: Vector3) -> bool:
	if camera == null or not camera.is_inside_tree():
		return false
	for off in [Vector3(0, 1, 0), Vector3(4, 1, 0), Vector3(-4, 1, 0), Vector3(0, 1, 4), Vector3(0, 1, -4)]:
		if camera.is_position_in_frustum(p + off):
			return true
	return false


## Pure fairness rule, shared with automated checks.
static func is_spawn_fair(spawn_pos: Vector3, player_pos: Vector3, player_forward: Vector3, travel_distance: float, police_speed: float, min_travel_seconds: float, in_view: bool, exclusion_points: Array, exclusion_radius: float) -> bool:
	if in_view:
		return false
	if travel_distance < police_speed * min_travel_seconds:
		return false
	var to := spawn_pos - player_pos
	to.y = 0.0
	if to.length() < police_speed * min_travel_seconds:
		return false
	# Never directly ahead (blind unavoidable junction).
	if to.length() < 110.0 and to.normalized().dot(player_forward) > 0.5:
		return false
	for e in exclusion_points:
		if spawn_pos.distance_to(e) < exclusion_radius:
			return false
	return true


func try_spawn() -> bool:
	var tuning := tuning_for_band(band)
	var police_speed := float(tuning["base_speed"]) + profile.rubber_band_cap
	var pnode := graph.world_to_node(player.global_position)
	var candidates: Array[Vector2i] = []
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			var n := pnode + Vector2i(dx, dz)
			var ring := maxi(absi(dx), absi(dz))
			if ring >= 1:
				candidates.append(n)
	# Shuffle deterministically from the agents stream.
	for k in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp := candidates[k]
		candidates[k] = candidates[j]
		candidates[j] = tmp
	var exclusions: Array = [player.global_position]
	for t in traffic.agents():
		exclusions.append((t as Node3D).global_position)
	for p in police():
		exclusions.append((p as Node3D).global_position)
	for n in candidates:
		var pos := graph.node_world(n)
		var travel := graph.travel_distance(n, pnode)
		if not is_spawn_fair(pos, player.global_position, player.forward(), travel, police_speed, profile.min_spawn_travel_seconds, _visible(pos), exclusions, 12.0):
			continue
		var cop := pool.acquire(&"police") as PoliceAgent
		if cop == null:
			return false
		var skin := 0 if band < 3 else 1
		cop.set_skin(catalog.police_body[skin], catalog.police_accent[skin])
		var path := graph.find_path(n, pnode, 200)
		var dir := (player.global_position - pos).normalized()
		if path.size() > 1:
			dir = (graph.node_world(path[1]) - pos).normalized()
		cop.activate(pos, LaneGraph.heading_of(dir), tuning)
		police_spawned.emit(cop)
		return true
	return false
