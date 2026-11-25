class_name TrafficManager
extends Node3D
## Spawns/recycles pooled traffic outside the camera, owns intersection reservations
## (one vehicle per junction slot, with expiry to avoid deadlocks) and gap keeping.

const SLOT_EXPIRY := 4.0
const FORCE_GRANT_AFTER := 5.0

var graph: LaneGraph
var pool: ChunkPool
var camera: Camera3D
var player: PlayerCar
var police_provider: Callable = Callable()  # () -> Array of Node3D
var catalog: CosmeticCatalog
var rng: RandomNumberGenerator
var desired_count: int = 4
var spawn_min: float = 60.0
var spawn_max: float = 150.0
var despawn_distance: float = 190.0

var _slots: Dictionary = {}  # Vector2i -> {"agent": TrafficAgent, "time": float}
var _clock: float = 0.0
var _spawn_timer: float = 0.0


func setup(lane_graph: LaneGraph, object_pool: ChunkPool, cam: Camera3D, player_car: PlayerCar, cosmetics: CosmeticCatalog, random: RandomNumberGenerator) -> void:
	graph = lane_graph
	pool = object_pool
	camera = cam
	player = player_car
	catalog = cosmetics
	rng = random
	pool.register_type(&"traffic", _make_agent, 10, _reset_agent)


func _make_agent() -> Object:
	var a := TrafficAgent.new()
	a.name = "Traffic"
	add_child(a)
	a.setup(self, graph)
	return a


func _reset_agent(obj: Object) -> void:
	(obj as TrafficAgent).deactivate()


func agents() -> Array:
	return pool.active(&"traffic")


func reset_traffic() -> void:
	pool.release_all(&"traffic")
	_slots.clear()
	_spawn_timer = 0.0


func update(delta: float) -> void:
	_clock += delta
	_spawn_timer -= delta
	for a in agents():
		var agent: TrafficAgent = a
		var d := agent.global_position.distance_to(player.global_position)
		if d > despawn_distance and not _visible(agent.global_position):
			pool.release(agent)
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.5
		if pool.active_count(&"traffic") < desired_count:
			_try_spawn()


func _try_spawn() -> bool:
	var pnode := graph.world_to_node(player.global_position)
	var reach := int(ceil(spawn_max / graph.cell_size))
	for attempt in 8:
		var a := pnode + Vector2i(rng.randi_range(-reach, reach), rng.randi_range(-reach, reach))
		var nbs := graph.neighbors(a)
		if nbs.is_empty():
			continue
		var b: Vector2i = nbs[rng.randi_range(0, nbs.size() - 1)]
		var s := rng.randf_range(0.0, graph.cell_size - 2.0 * (graph.half_road() + 1.0) - 6.0)
		var pos := graph.lane_point(a, b, graph.half_road() + 1.0 + s)
		var d := pos.distance_to(player.global_position)
		if d < spawn_min or d > spawn_max or _visible(pos) or not _clear(pos, 10.0):
			continue
		var agent := pool.acquire(&"traffic") as TrafficAgent
		if agent == null:
			return false
		var look := rng.randi_range(0, catalog.traffic_models.size() - 1)
		agent.set_look(catalog.traffic_models[look])
		agent.activate(a, b, s, rng.randf_range(7.5, 10.5))
		return true
	return false


func _visible(p: Vector3) -> bool:
	if camera == null or not camera.is_inside_tree():
		return false
	return camera.is_position_in_frustum(p) or camera.is_position_in_frustum(p + Vector3(0, 2.0, 0))


func _clear(p: Vector3, radius: float) -> bool:
	if p.distance_to(player.global_position) < radius:
		return false
	for a in agents():
		if (a as Node3D).global_position.distance_to(p) < radius:
			return false
	if police_provider.is_valid():
		for cop in police_provider.call():
			if (cop as Node3D).global_position.distance_to(p) < radius:
				return false
	return true


func is_position_clear(p: Vector3, radius: float) -> bool:
	for a in agents():
		if (a as Node3D).global_position.distance_to(p) < radius:
			return false
	return true


## Intersection reservation. Expired holders lose the slot; long waits force a grant.
func request_slot(node: Vector2i, agent: TrafficAgent, waited: float) -> bool:
	if _slots.has(node):
		var slot: Dictionary = _slots[node]
		var holder: TrafficAgent = slot["agent"]
		var expired := _clock - float(slot["time"]) > SLOT_EXPIRY
		if holder != agent and is_instance_valid(holder) and holder.active and not expired and waited < FORCE_GRANT_AFTER:
			return false
	_slots[node] = {"agent": agent, "time": _clock}
	return true


func release_slot(node: Vector2i, agent: TrafficAgent) -> void:
	if _slots.has(node) and (_slots[node] as Dictionary)["agent"] == agent:
		_slots.erase(node)


func choose_next(from: Vector2i, at: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for nb in graph.neighbors(at):
		if nb != from:
			options.append(nb)
	if options.is_empty():
		return from
	return options[rng.randi_range(0, options.size() - 1)]


## Gap keeping: anything in a narrow cone ahead (traffic, police, player) blocks.
func is_blocked_ahead(agent: TrafficAgent, pos: Vector3, fwd: Vector3) -> bool:
	var others: Array = [player]
	for a in agents():
		if a != agent:
			others.append(a)
	if police_provider.is_valid():
		others.append_array(police_provider.call())
	for o in others:
		var to := (o as Node3D).global_position - pos
		to.y = 0.0
		var along := to.dot(fwd)
		if along <= 0.5 or along > 9.0:
			continue
		var lateral := (to - fwd * along).length()
		if lateral < 2.2:
			return true
	return false
