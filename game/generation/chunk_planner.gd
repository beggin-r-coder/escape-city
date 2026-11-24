class_name ChunkPlanner
extends RefCounted
## Pure-data generation for one cell. Pipeline per cell:
##  1. choose a definition compatible with the difficulty band (route stream);
##  2. lay out static obstacles (route stream) - never inside open lanes;
##  3. validate safe reachability (lanes and intersection stay clear);
##  4. reserve hazard slots (hazard stream) and pickup lines (pickup stream);
##  5. decoration values such as heights/colours (cosmetic stream).
## A failed validation returns a known-safe recovery plan instead.
## All coordinates are local XZ (Vector2) relative to the cell corner node.

const LANE_HALF_SPAN := 5.2  # lanes occupy |offset| <= this from the road centre line
const PARK_OFFSET := 6.5  # parked cars sit in the curb strip
const SIDEWALK := 3.0

var graph: LaneGraph
var seeds: SeedService
var definitions: Array[ChunkDefinition] = []
var recovery: ChunkDefinition
var failures: Array[String] = []


func _init(lane_graph: LaneGraph, seed_service: SeedService, defs: Array[ChunkDefinition], recovery_def: ChunkDefinition) -> void:
	graph = lane_graph
	seeds = seed_service
	definitions = defs
	recovery = recovery_def


func choose_definition(cell: Vector2i, band: int) -> ChunkDefinition:
	var compatible: Array[ChunkDefinition] = []
	var total := 0.0
	for d in definitions:
		if d.allows_band(band) and not d.is_recovery and d.weight > 0.0:
			compatible.append(d)
			total += d.weight
	if compatible.is_empty():
		return recovery
	var roll := seeds.cell_value(SeedService.STREAM_ROUTE, cell.x, cell.y, 3) * total
	for d in compatible:
		roll -= d.weight
		if roll <= 0.0:
			return d
	return compatible[compatible.size() - 1]


func south_open(cell: Vector2i) -> bool:
	return graph.is_edge_open(cell, cell + Vector2i(1, 0))


func plan_cell(cell: Vector2i, band: int, hazard_density: float, allow_hazards: bool, allow_pickups: bool = true) -> Dictionary:
	var def := choose_definition(cell, band)
	var plan := _layout(cell, def)
	var errors := validate_plan(plan)
	if not errors.is_empty():
		failures.append("seed=%d gen=%d cell=%s def=%s: %s" % [seeds.run_seed, LaneGraph.GENERATOR_VERSION, cell, def.id, ", ".join(errors)])
		plan = _layout(cell, recovery)
		plan["recovery"] = true
	else:
		plan["recovery"] = def.is_recovery
	if allow_hazards and not bool(plan["recovery"]):
		_reserve_hazards(plan, cell, def, hazard_density)
	if allow_pickups:
		_reserve_coins(plan, cell, def)
	return plan


func _empty_plan(cell: Vector2i, def: ChunkDefinition) -> Dictionary:
	return {
		"cell": cell,
		"def_id": def.id,
		"kind": def.kind,
		"south_open": south_open(cell),
		"buildings": [],
		"trees": [],
		"planters": [],
		"parked": [],
		"hazards": [],
		"coins": [],
		"recovery": false,
	}


func _layout(cell: Vector2i, def: ChunkDefinition) -> Dictionary:
	var plan := _empty_plan(cell, def)
	var route := seeds.cell_rng(SeedService.STREAM_ROUTE, cell.x, cell.y)
	var cosmetic := seeds.cell_rng(SeedService.STREAM_COSMETICS, cell.x, cell.y)
	var s := graph.cell_size
	var hw := graph.half_road()
	var lot_min := hw + SIDEWALK
	var lot_max := s - hw - SIDEWALK
	var lot := Rect2(lot_min, lot_min, lot_max - lot_min, lot_max - lot_min)

	if def.is_recovery:
		var inset := lot.grow(-6.0)
		plan["buildings"].append({"rect": inset, "height": 6.0, "color": 0})
	elif def.max_lots > 0:
		for r in _split_lots(lot, def.max_lots, route):
			var h := cosmetic.randf_range(def.building_min_height, def.building_max_height)
			plan["buildings"].append({"rect": r, "height": h, "color": cosmetic.randi_range(0, ArtKit.BUILDINGS.size() - 1)})

	match def.kind:
		ChunkDefinition.Kind.PARK:
			_scatter_trees(plan, lot.grow(-2.0), def.tree_count, 7.0, route)
		ChunkDefinition.Kind.PLAZA:
			var c := lot.get_center()
			plan["planters"].append(Rect2(c - Vector2(3.5, 3.5), Vector2(7, 7)))
			_scatter_trees(plan, lot.grow(-3.0), def.tree_count, 9.0, route, Rect2(c - Vector2(6, 6), Vector2(12, 12)))
		_:
			if def.tree_count > 0:
				_street_trees(plan, def.tree_count, route)

	if not plan["south_open"]:
		# Closed x-direction road becomes a pocket park with planters (one solid barrier).
		plan["planters"].append(Rect2(hw, -hw, s - 2.0 * hw, 2.0 * hw))

	for k in def.parked_car_slots:
		_place_parked_car(plan, route, cosmetic)
	return plan


func _split_lots(lot: Rect2, max_lots: int, rng: RandomNumberGenerator) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var n := rng.randi_range(1, max_lots)
	var gap := 0.8
	if n == 1:
		out.append(lot)
	elif n == 2:
		var t := rng.randf_range(0.4, 0.6)
		if rng.randf() < 0.5:
			var w := lot.size.x * t
			out.append(Rect2(lot.position, Vector2(w - gap * 0.5, lot.size.y)))
			out.append(Rect2(lot.position + Vector2(w + gap * 0.5, 0), Vector2(lot.size.x - w - gap * 0.5, lot.size.y)))
		else:
			var hgt := lot.size.y * t
			out.append(Rect2(lot.position, Vector2(lot.size.x, hgt - gap * 0.5)))
			out.append(Rect2(lot.position + Vector2(0, hgt + gap * 0.5), Vector2(lot.size.x, lot.size.y - hgt - gap * 0.5)))
	else:
		var tx := lot.size.x * rng.randf_range(0.4, 0.6)
		var tz := lot.size.y * rng.randf_range(0.4, 0.6)
		var xs := [lot.position.x, lot.position.x + tx, lot.end.x]
		var zs := [lot.position.y, lot.position.y + tz, lot.end.y]
		for ix in 2:
			for iz in 2:
				if n == 3 and ix == 1 and iz == 1:
					continue  # leave a courtyard
				var x0: float = xs[ix] + (gap * 0.5 if ix == 1 else 0.0)
				var x1: float = xs[ix + 1] - (gap * 0.5 if ix == 0 else 0.0)
				var z0: float = zs[iz] + (gap * 0.5 if iz == 1 else 0.0)
				var z1: float = zs[iz + 1] - (gap * 0.5 if iz == 0 else 0.0)
				out.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	return out


func _scatter_trees(plan: Dictionary, area: Rect2, count: int, spacing: float, rng: RandomNumberGenerator, avoid: Rect2 = Rect2()) -> void:
	var placed: Array = plan["trees"]
	var attempts := 0
	while placed.size() < count and attempts < count * 8:
		attempts += 1
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if avoid.size != Vector2.ZERO and avoid.has_point(p):
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < spacing:
				ok = false
				break
		if ok:
			placed.append(p)


func _street_trees(plan: Dictionary, count: int, rng: RandomNumberGenerator) -> void:
	# Trees on the block-side sidewalk of the cell's own roads (outside lanes).
	var s := graph.cell_size
	var hw := graph.half_road()
	var curb := hw + 1.4
	for k in count:
		var u := rng.randf_range(hw + 6.0, s - hw - 6.0)
		if rng.randf() < 0.5:
			plan["trees"].append(Vector2(u, curb))
		else:
			plan["trees"].append(Vector2(curb, u))


func _place_parked_car(plan: Dictionary, route: RandomNumberGenerator, cosmetic: RandomNumberGenerator) -> void:
	var s := graph.cell_size
	var hw := graph.half_road()
	var u := route.randf_range(hw + 4.0, s - hw - 8.0)
	var side := -1.0 if route.randf() < 0.5 else 1.0
	var on_south := route.randf() < 0.5 and bool(plan["south_open"])
	var pos: Vector2
	var yaw: float
	if on_south:
		pos = Vector2(u, side * PARK_OFFSET)
		yaw = PI * 0.5
	else:
		pos = Vector2(side * PARK_OFFSET, u)
		yaw = 0.0
	plan["parked"].append({"pos": pos, "yaw": yaw, "color": cosmetic.randi_range(0, 3)})


static func parked_rect(entry: Dictionary) -> Rect2:
	var pos: Vector2 = entry["pos"]
	var along_x := absf(float(entry["yaw"])) > 0.1
	var size := Vector2(4.4, 2.0) if along_x else Vector2(2.0, 4.4)
	return Rect2(pos - size * 0.5, size)


## Lane rectangles of the open roads this cell owns, plus its intersection.
func lane_rects(plan: Dictionary) -> Array[Rect2]:
	var s := graph.cell_size
	var hw := graph.half_road()
	var out: Array[Rect2] = [Rect2(-hw, -hw, 2.0 * hw, 2.0 * hw)]
	out.append(Rect2(-LANE_HALF_SPAN, hw, 2.0 * LANE_HALF_SPAN, s - 2.0 * hw))  # west road: always open
	if plan["south_open"]:
		out.append(Rect2(hw, -LANE_HALF_SPAN, s - 2.0 * hw, 2.0 * LANE_HALF_SPAN))
	return out


func static_rects(plan: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for b in plan["buildings"]:
		out.append(b["rect"])
	for r in plan["planters"]:
		out.append(r)
	for t in plan["trees"]:
		out.append(Rect2(Vector2(t) - Vector2(0.6, 0.6), Vector2(1.2, 1.2)))
	for p in plan["parked"]:
		out.append(parked_rect(p))
	return out


## Returns problems that would block a lane or intersection; empty means certified.
func validate_plan(plan: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var lanes := lane_rects(plan)
	for r in static_rects(plan):
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			errors.append("degenerate rect %s" % r)
			continue
		for lane in lanes:
			if r.intersects(lane):
				errors.append("static %s blocks lane %s" % [r, lane])
	return errors


func _reserve_hazards(plan: Dictionary, cell: Vector2i, def: ChunkDefinition, density: float) -> void:
	var rng := seeds.cell_rng(SeedService.STREAM_HAZARDS, cell.x, cell.y)
	var s := graph.cell_size
	var hw := graph.half_road()
	for k in def.hazard_slots:
		if rng.randf() >= density:
			continue
		var on_south := bool(plan["south_open"]) and rng.randf() < 0.5
		var u := rng.randf_range(hw + 6.0, s - hw - 6.0)
		var lane := graph.lane_offset * (-1.0 if rng.randf() < 0.5 else 1.0)
		var type: StringName = &"cone" if rng.randf() < 0.6 else &"crate"
		var offsets := [-1.3, 0.0, 1.3] if type == &"cone" else [-0.8, 0.8]
		for o in offsets:
			var lateral: float = lane + float(o)
			var pos := Vector2(u, lateral) if on_south else Vector2(lateral, u)
			plan["hazards"].append({"pos": pos, "type": type})


func _reserve_coins(plan: Dictionary, cell: Vector2i, def: ChunkDefinition) -> void:
	var rng := seeds.cell_rng(SeedService.STREAM_PICKUPS, cell.x, cell.y)
	if rng.randf() >= def.coin_line_chance:
		return
	var s := graph.cell_size
	var hw := graph.half_road()
	var on_south := bool(plan["south_open"]) and rng.randf() < 0.5
	var lane := graph.lane_offset * (-1.0 if rng.randf() < 0.5 else 1.0)
	var count := 6
	var spacing := 4.5
	var u0 := rng.randf_range(hw + 2.0, s - hw - 2.0 - spacing * (count - 1))
	var weave := rng.randf() < 0.4  # a risky trail that drifts across lanes
	for k in count:
		var lateral := lane
		if weave:
			lateral = lane * cos(float(k) / float(count - 1) * PI)
		var u := u0 + spacing * k
		plan["coins"].append(Vector2(u, lateral) if on_south else Vector2(lateral, u))
