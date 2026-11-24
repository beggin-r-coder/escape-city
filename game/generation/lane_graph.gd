class_name LaneGraph
extends RefCounted
## Implicit infinite road grid. Intersections ("nodes") sit at grid points; roads run
## between adjacent nodes. Cell (i, j) spans from node (i, j) to node (i+1, j+1) and owns
## the intersection at its corner, its south road (x-direction edge) and west road
## (z-direction edge).
##
## Connectivity guarantee (no validation pass needed at runtime):
##  - every z-direction edge is open, so every column is a connected line;
##  - x-direction edges on rows where j % 3 == 0 are always open;
##  - other x-direction edges may close, but at most one per node side (parity rule).
## Therefore the whole grid is connected, every node has degree >= 3 and loops exist.
## The sole escape route is never removed.

const GENERATOR_VERSION := 1

var cell_size: float = 64.0
var road_width: float = 16.0
var lane_offset: float = 3.0
var closure_rate: float = 0.22
var origin_cell: Vector2i = Vector2i.ZERO
var seeds: SeedService


func _init(seed_service: SeedService, cell: float = 64.0, road: float = 16.0) -> void:
	seeds = seed_service
	cell_size = cell
	road_width = road


func half_road() -> float:
	return road_width * 0.5


func node_world(n: Vector2i) -> Vector3:
	return Vector3(float(n.x - origin_cell.x) * cell_size, 0.0, float(n.y - origin_cell.y) * cell_size)


func world_to_node(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / cell_size) + origin_cell.x, roundi(p.z / cell_size) + origin_cell.y)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell_size) + origin_cell.x, floori(p.z / cell_size) + origin_cell.y)


func is_edge_open(a: Vector2i, b: Vector2i) -> bool:
	var d := b - a
	if absi(d.x) + absi(d.y) != 1:
		return false
	if d.y != 0:
		return true
	var i := mini(a.x, b.x)
	var j := a.y
	if posmod(j, 3) == 0:
		return true
	if posmod(i + j, 2) != 0:
		return true
	return seeds.cell_value(SeedService.STREAM_ROUTE, i, j, 17) >= closure_rate


const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func neighbors(n: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var nb: Vector2i = n + d
		if is_edge_open(n, nb):
			out.append(nb)
	return out


## Bounded A* over intersections. Returns [start, ..., goal] or [] if not found.
func find_path(start: Vector2i, goal: Vector2i, max_expansions: int = 600) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if start == goal:
		result.append(start)
		return result
	var open: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g: Dictionary = {start: 0}
	var f: Dictionary = {start: _manhattan(start, goal)}
	var closed: Dictionary = {}
	var expansions := 0
	while not open.is_empty() and expansions < max_expansions:
		var best_idx := 0
		for k in range(1, open.size()):
			if int(f[open[k]]) < int(f[open[best_idx]]):
				best_idx = k
		var current: Vector2i = open[best_idx]
		open.remove_at(best_idx)
		if current == goal:
			result.append(current)
			while came_from.has(current):
				current = came_from[current]
				result.push_front(current)
			return result
		closed[current] = true
		expansions += 1
		for nb in neighbors(current):
			if closed.has(nb):
				continue
			var tentative := int(g[current]) + 1
			if not g.has(nb) or tentative < int(g[nb]):
				came_from[nb] = current
				g[nb] = tentative
				f[nb] = tentative + _manhattan(nb, goal)
				if not open.has(nb):
					open.append(nb)
	return result


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Graph travel distance in meters (via roads), or INF when unreachable within bounds.
func travel_distance(a: Vector2i, b: Vector2i) -> float:
	var path := find_path(a, b, 400)
	if path.is_empty():
		return INF
	return float(path.size() - 1) * cell_size


func nearest_intersection_distance(p: Vector3) -> float:
	var c := node_world(world_to_node(p))
	return Vector2(p.x - c.x, p.z - c.z).length()


## True when p lies on drivable road surface (open road strip or intersection).
func is_on_road(p: Vector3) -> bool:
	var cell := world_to_cell(p)
	var corner := node_world(cell)
	var lx := p.x - corner.x
	var lz := p.z - corner.z
	var hw := half_road()
	var near_x_line := lx < hw or lx > cell_size - hw  # near a z-direction road
	var near_z_line := lz < hw or lz > cell_size - hw  # near an x-direction road
	if near_x_line:
		return true
	if near_z_line:
		var row := cell.y if lz < hw else cell.y + 1
		return is_edge_open(Vector2i(cell.x, row), Vector2i(cell.x + 1, row))
	return false


## Right-hand lane point travelling from node a toward node b at distance s from a's centre.
func lane_point(a: Vector2i, b: Vector2i, s: float) -> Vector3:
	var pa := node_world(a)
	var d := (node_world(b) - pa).normalized()
	var right := Vector3(-d.z, 0.0, d.x)
	return pa + d * s + right * lane_offset


static func heading_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func forward_of(heading: float) -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))
