class_name StreamingWorld
extends Node3D
## Keeps a window of generated cells around the player (and around active vehicles).
## Cells are recycled only when outside the camera; new cells activate a few per frame
## (per-frame budget) and are generated beyond sight distance. Hazards are never spawned
## into visible cells or the spawn safe zone.

signal prop_smashed(prop: BreakableProp, by: Node3D)
signal coin_collected(coin: CoinPickup)

var graph: LaneGraph
var planner: ChunkPlanner
var pool: ChunkPool
var camera: Camera3D
var radius: int = 2
var max_activations_per_frame: int = 1  # ~2.4 ms per block on desktop; phones are slower
var band: int = 0
var hazard_density: float = 0.3
var safe_center: Vector3 = Vector3.ZERO
var safe_radius: float = 0.0
var active: Dictionary = {}  # Vector2i -> {"node", "props", "coins", "plan"}
## Streaming cost (microseconds) for frame-hitch monitoring.
var last_activate_usec: int = 0
var max_activate_usec: int = 0
var activations: int = 0

var _ground: MeshInstance3D
var _floor: StaticBody3D


func setup(lane_graph: LaneGraph, chunk_planner: ChunkPlanner, object_pool: ChunkPool, cam: Camera3D) -> void:
	graph = lane_graph
	planner = chunk_planner
	pool = object_pool
	camera = cam
	add_to_group(&"origin_shift")
	# Window + vehicle neighbourhoods + cells lingering while still on camera.
	var window := (radius * 2 + 5) * (radius * 2 + 5)
	pool.register_type(&"chunk", _make_chunk, window + 16, _reset_chunk)
	pool.register_type(&"cone", _make_prop.bind(&"cone"), 180, _reset_prop)
	pool.register_type(&"crate", _make_prop.bind(&"crate"), 90, _reset_prop)
	pool.register_type(&"coin", _make_coin, 160, _reset_coin)
	_build_ground()


func _build_ground() -> void:
	_floor = StaticBody3D.new()
	_floor.name = "Floor"
	_floor.collision_layer = 1
	_floor.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	_floor.add_child(shape)
	add_child(_floor)
	_ground = MeshInstance3D.new()
	_ground.name = "Asphalt"
	var plane := PlaneMesh.new()
	var extent := graph.cell_size * float(radius * 2 + 4)
	plane.size = Vector2(extent, extent)
	_ground.mesh = plane
	_ground.material_override = ArtKit.mat(ArtKit.ASPHALT)
	add_child(_ground)


func _make_chunk() -> Object:
	var n := Node3D.new()
	n.name = "Chunk"
	n.visible = false
	add_child(n)
	return n


func _reset_chunk(obj: Object) -> void:
	var n := obj as Node3D
	for child in n.get_children():
		child.queue_free()
	n.visible = false


func _make_prop(type: StringName) -> Object:
	var p := BreakableProp.new()
	add_child(p)
	p.setup(type)
	p.smashed.connect(prop_smashed.emit)
	return p


func _reset_prop(obj: Object) -> void:
	(obj as BreakableProp).deactivate()


func _make_coin() -> Object:
	var c := CoinPickup.new()
	add_child(c)
	c.setup()
	c.collected.connect(coin_collected.emit)
	return c


func _reset_coin(obj: Object) -> void:
	(obj as CoinPickup).deactivate()


## Release everything and synchronously build the full window (used at run start/retry).
func reset_world(center: Vector3, safe_zone_radius: float = 90.0) -> void:
	for cell in active.keys():
		_release_cell(cell)
	active.clear()
	safe_center = center
	safe_radius = safe_zone_radius
	var c := graph.world_to_cell(center)
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			_activate(c + Vector2i(dx, dz), true)
	_follow_ground(center)


func update(center: Vector3, vehicle_positions: Array[Vector3]) -> void:
	var desired := {}
	var c := graph.world_to_cell(center)
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			desired[c + Vector2i(dx, dz)] = true
	# Keep the neighbourhood of active vehicles alive so agents never lose their blocks.
	for p in vehicle_positions:
		var vc := graph.world_to_cell(p)
		if absi(vc.x - c.x) <= radius + 2 and absi(vc.y - c.y) <= radius + 2:
			desired[vc] = true
	for cell in active.keys():
		if desired.has(cell):
			continue
		var cv: Vector2i = cell
		var far := absi(cv.x - c.x) > radius + 3 or absi(cv.y - c.y) > radius + 3
		if far or not _cell_visible(cv):
			_release_cell(cv)
	var missing: Array[Vector2i] = []
	for cell in desired.keys():
		if not active.has(cell):
			missing.append(cell)
	var by_distance := func(a: Vector2i, b: Vector2i) -> bool:
		return (a - c).length_squared() < (b - c).length_squared()
	missing.sort_custom(by_distance)
	var budget := max_activations_per_frame
	for cell in missing:
		if budget <= 0:
			break
		_activate(cell, false)
		budget -= 1
	_follow_ground(center)


func _follow_ground(center: Vector3) -> void:
	var s := graph.cell_size
	_ground.global_position = Vector3(snappedf(center.x, s), 0.0, snappedf(center.z, s))


func _activate(cell: Vector2i, initial: bool) -> void:
	var t0 := Time.get_ticks_usec()
	_activate_inner(cell, initial)
	last_activate_usec = Time.get_ticks_usec() - t0
	activations += 1
	if not initial:
		max_activate_usec = maxi(max_activate_usec, last_activate_usec)


func _activate_inner(cell: Vector2i, initial: bool) -> void:
	var corner := graph.node_world(cell)
	var cell_center := corner + Vector3(graph.cell_size * 0.5, 0, graph.cell_size * 0.5)
	var in_safe_zone := safe_radius > 0.0 and cell_center.distance_to(safe_center) < safe_radius
	var allow_hazards := not in_safe_zone and (initial or not _cell_visible(cell))
	var plan := planner.plan_cell(cell, band, hazard_density, allow_hazards, not in_safe_zone or not initial)
	var node := pool.acquire(&"chunk") as Node3D
	if node == null:
		return
	node.position = corner
	node.visible = true
	ChunkBuilder.build(node, plan, graph)
	var props: Array = []
	for h in plan["hazards"]:
		var prop := pool.acquire(h["type"]) as BreakableProp
		if prop == null:
			continue
		var hp: Vector2 = h["pos"]
		prop.place(corner + Vector3(hp.x, 0, hp.y))
		props.append(prop)
	var coins: Array = []
	for cp in plan["coins"]:
		var coin := pool.acquire(&"coin") as CoinPickup
		if coin == null:
			continue
		var p2: Vector2 = cp
		coin.place(corner + Vector3(p2.x, 0, p2.y))
		coins.append(coin)
	active[cell] = {"node": node, "props": props, "coins": coins, "plan": plan}


func _release_cell(cell: Vector2i) -> void:
	if not active.has(cell):
		return
	var rec: Dictionary = active[cell]
	for p in rec["props"]:
		pool.release(p)
	for c in rec["coins"]:
		pool.release(c)
	pool.release(rec["node"])
	active.erase(cell)


func _cell_visible(cell: Vector2i) -> bool:
	if camera == null or not camera.is_inside_tree():
		return false
	var corner := graph.node_world(cell)
	var s := graph.cell_size
	for offset in [Vector3(0, 0, 0), Vector3(s, 0, 0), Vector3(0, 0, s), Vector3(s, 0, s), Vector3(s * 0.5, 8.0, s * 0.5)]:
		if camera.is_position_in_frustum(corner + offset):
			return true
	return false


func apply_origin_shift(_offset: Vector3) -> void:
	# graph.origin_cell is already updated; recompute chunk roots from logical cells.
	for cell in active.keys():
		var rec: Dictionary = active[cell]
		(rec["node"] as Node3D).position = graph.node_world(cell)
	safe_radius = 0.0


func active_cell_count() -> int:
	return active.size()
