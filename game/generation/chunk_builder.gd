class_name ChunkBuilder
extends RefCounted
## Turns a ChunkPlanner plan into scene nodes under a pooled chunk root, using the Kenney
## City Kit (Roads + Commercial, CC0). Static geometry only; breakables and coins are
## pooled separately by StreamingWorld.
##
## Tile facts (checked with tests/asset_gallery.gd): road tiles are 1x1 units; straight and
## crossing tiles run along X; the T-junction tile is closed on its -Z side; street-light
## arms point -Z; buildings and cars face +Z.

const ROAD_TILE_HEIGHT := 4.0  # flatten tiles: 0.02 units -> 0.08 m so wheels sit on them
const LOW_RISE := [
	"building-a", "building-b", "building-c", "building-d", "building-e", "building-f", "building-g",
	"building-h", "building-i", "building-j", "building-k", "building-l", "building-m", "building-n",
]
const TOWERS := ["building-skyscraper-a", "building-skyscraper-b", "building-skyscraper-c", "building-skyscraper-d", "building-skyscraper-e"]
const HOUSES := [
	"building-type-a", "building-type-b", "building-type-c", "building-type-d", "building-type-e",
	"building-type-f", "building-type-g", "building-type-h", "building-type-i", "building-type-j",
	"building-type-k", "building-type-l", "building-type-m", "building-type-n", "building-type-o",
	"building-type-p", "building-type-q", "building-type-r", "building-type-s", "building-type-t", "building-type-u",
]
const PARKED := ["sedan", "suv", "van", "taxi"]
const LAMP_LIGHT := Color("ffc98a")
## Lamp head offset in the lamp's own frame (arm points -Z), at LAMP_SCALE.
const LAMP_SCALE := 10.0
const LAMP_HEAD := Vector3(0, 5.7, -1.9)
const SIDEWALK := Color("9ea3b0")
const GRASS := Color("7fae5c")
const PAVING := Color("cbc4b5")
const DIRT := Color("a08766")


static func build(root: Node3D, plan: Dictionary, graph: LaneGraph) -> void:
	var s := graph.cell_size
	var hw := graph.half_road()
	var block := s - 2.0 * hw
	var mid := s * 0.5
	var kind := int(plan["kind"])
	ArtKit.box(root, Vector3(block, 0.1, block), Vector3(mid, 0.05, mid), ArtKit.mat(SIDEWALK))
	if kind == ChunkDefinition.Kind.PARK or kind == ChunkDefinition.Kind.RESIDENTIAL:
		ArtKit.box(root, Vector3(block - 6.0, 0.14, block - 6.0), Vector3(mid, 0.07, mid), ArtKit.mat(GRASS))
	elif kind == ChunkDefinition.Kind.PLAZA:
		ArtKit.box(root, Vector3(block - 6.0, 0.12, block - 6.0), Vector3(mid, 0.06, mid), ArtKit.mat(PAVING))
	_roads(root, plan, graph)
	var cell: Vector2i = plan["cell"]
	for b in plan["buildings"]:
		if kind == ChunkDefinition.Kind.RESIDENTIAL:
			_house(root, b["rect"], int(b["color"]), s)
		else:
			_building(root, b["rect"], kind, int(b["color"]), s, kind == ChunkDefinition.Kind.DOWNTOWN)
	if kind == ChunkDefinition.Kind.DOWNTOWN or kind == ChunkDefinition.Kind.PARKING:
		_sidewalk_planters(root, plan, graph)
	for t in plan["trees"]:
		var p: Vector2 = t
		ArtKit.tree(root, Vector3(p.x, 0, p.y), 0.85 + fposmod(p.x * 0.37 + p.y * 0.11, 0.35))
	for r2 in plan["planters"]:
		var pr: Rect2 = r2
		if pr.size.x > 2.0 * hw and pr.position.y < 0.0:
			_construction_zone(root, pr, hw)
		else:
			var pc := pr.get_center()
			ArtKit.static_box(root, Vector3(pr.size.x, 1.0, pr.size.y), Vector3(pc.x, 0.5, pc.y), ArtKit.mat(ArtKit.HEDGE))
	for entry in plan["parked"]:
		_parked_car(root, entry)
	if kind == ChunkDefinition.Kind.PLAZA:
		for k in 3:
			var umbrella := ArtKit.kenney("city/detail-parasol-a" if k % 2 == 0 else "city/detail-parasol-b")
			umbrella.scale = Vector3.ONE * 6.0
			umbrella.position = Vector3(hw + 8.0 + float(k) * 13.0, 0.1, s - hw - 8.0)
			root.add_child(umbrella)
	_street_furniture(root, plan, graph, cell)


# ---------------------------------------------------------------- roads

static func _tile(root: Node3D, model: String, pos: Vector3, yaw: float, tile: float) -> void:
	var t := ArtKit.kenney("roads/" + model)
	t.scale = Vector3(tile, ROAD_TILE_HEIGHT, tile)
	t.rotation.y = yaw
	t.position = pos
	root.add_child(t)


static func _roads(root: Node3D, plan: Dictionary, graph: LaneGraph) -> void:
	var cell: Vector2i = plan["cell"]
	var tile := graph.road_width
	var hw := graph.half_road()
	var east := graph.is_edge_open(cell, cell + Vector2i(1, 0))
	var west := graph.is_edge_open(cell - Vector2i(1, 0), cell)
	if east and west:
		_tile(root, "road-crossroad", Vector3.ZERO, 0.0, tile)
	else:
		var closed := Vector3(1, 0, 0) if not east else Vector3(-1, 0, 0)
		_tile(root, "road-intersection", Vector3.ZERO, LaneGraph.heading_of(closed), tile)
	var segments := int(round((graph.cell_size - 2.0 * hw) / tile))
	for k in segments:
		var u := hw + tile * (float(k) + 0.5)
		var model := "road-crossing" if (k == 0 or k == segments - 1) else "road-straight"
		_tile(root, model, Vector3(0, 0, u), PI * 0.5, tile)  # west road (z-direction), always open
		if plan["south_open"]:
			_tile(root, model, Vector3(u, 0, 0), 0.0, tile)


static func _street_furniture(root: Node3D, plan: Dictionary, graph: LaneGraph, cell: Vector2i) -> void:
	var s := graph.cell_size
	var curb := graph.half_road() - 0.8
	var lamps: Array[Vector3] = []
	# Street lights on both sides of every owned road, staggered, arms over the road.
	lamps.append(_lamp(root, Vector3(curb, 0, s * 0.32), PI * 0.5))
	lamps.append(_lamp(root, Vector3(-curb, 0, s * 0.68), -PI * 0.5))
	if plan["south_open"]:
		lamps.append(_lamp(root, Vector3(s * 0.32, 0, curb), 0.0))
		lamps.append(_lamp(root, Vector3(s * 0.68, 0, -curb), PI))
	root.set_meta(&"lamps", lamps)
	# A traffic light on the junction corner of every other cell.
	if posmod(cell.x + cell.y, 2) == 0:
		_pole(root, "roads/traffic-light", Vector3(curb, 0, curb), PI * 0.75, 9.0)


## Street light with a glowing head and a fake light pool. Returns the head position (local).
static func _lamp(root: Node3D, pos: Vector3, yaw: float) -> Vector3:
	_pole(root, "roads/light-square", pos, yaw, LAMP_SCALE)
	var rot := Basis(Vector3.UP, yaw)
	var head := pos + rot * LAMP_HEAD
	var glow := ArtKit.box(root, Vector3(0.9, 0.25, 1.2), head, ArtKit.night_glow(LAMP_LIGHT, 4.0))
	glow.basis = rot * Basis.from_scale(Vector3(0.9, 0.25, 1.2))
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ArtKit.light_pool(root, Vector3(head.x, 0.14, head.z), Vector2(13, 13), LAMP_LIGHT, 0.55)
	return head


static func _pole(root: Node3D, model: String, pos: Vector3, yaw: float, scale_f: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"static_world")
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 5.0, 0.5)
	shape.shape = bs
	shape.position = Vector3(0, 2.5, 0)
	body.add_child(shape)
	var m := ArtKit.kenney(model)
	m.scale = Vector3.ONE * scale_f
	m.rotation.y = yaw
	body.add_child(m)
	root.add_child(body)


## Closed x-direction road: a fenced construction site (one solid collision box).
static func _construction_zone(root: Node3D, rect: Rect2, hw: float) -> void:
	var c := rect.get_center()
	ArtKit.static_box(root, Vector3(rect.size.x, 0.4, rect.size.y), Vector3(c.x, 0.2, c.y), ArtKit.mat(DIRT))
	var bb := ArtKit.kenney_aabb("roads/construction-barrier")
	var sc := 1.2 / maxf(bb.size.y, 0.01)
	var step := maxf(bb.size.x * sc, 1.0)
	for end_x in [rect.position.x + 0.9, rect.end.x - 0.9]:
		var z := -hw + step * 0.5
		while z < hw:
			var bar := ArtKit.kenney("roads/construction-barrier")
			bar.scale = Vector3.ONE * sc
			bar.rotation.y = PI * 0.5
			bar.position = Vector3(end_x, 0.35, z)
			root.add_child(bar)
			z += step
	for k in 3:
		var cone := ArtKit.kenney("roads/construction-cone")
		cone.scale = Vector3.ONE * 11.0
		cone.position = Vector3(c.x - 10.0 + 10.0 * k, 0.4, c.y + (2.5 if k % 2 == 0 else -2.5))
		root.add_child(cone)
	var lamp := ArtKit.kenney("roads/construction-light")
	lamp.scale = Vector3.ONE * 10.0
	lamp.position = Vector3(c.x, 0.4, c.y)
	root.add_child(lamp)


# ---------------------------------------------------------------- buildings & cars

static func _building(root: Node3D, rect: Rect2, _kind: int, color_pick: int, s: float, downtown: bool) -> void:
	var hash_pick := absi(int(rect.position.x * 7.3) * 31 + int(rect.position.y * 3.1) * 17 + color_pick * 5)
	var tall := downtown and hash_pick % 2 == 0
	var list: Array = TOWERS if tall else LOW_RISE
	var path := "city/" + str(list[hash_pick % list.size()])
	var bb := ArtKit.kenney_aabb(path)
	# Face the nearest street.
	var c := rect.get_center()
	var options := [[c.y, Vector3(0, 0, -1)], [c.x, Vector3(-1, 0, 0)], [s - c.y, Vector3(0, 0, 1)], [s - c.x, Vector3(1, 0, 0)]]
	var best: Array = options[0]
	for o in options:
		if float(o[0]) < float(best[0]):
			best = o
	var face: Vector3 = best[1]
	var yaw := atan2(face.x, face.z)  # model front is +Z
	var sideways := absf(face.x) > 0.5
	var foot_x := bb.size.z if sideways else bb.size.x
	var foot_z := bb.size.x if sideways else bb.size.z
	var cap := 9.0 if tall else 19.0
	var sc := minf(minf(rect.size.x / foot_x, rect.size.y / foot_z) * 0.94, cap)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"static_world")
	body.position = Vector3(c.x, 0, c.y)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(foot_x * sc, bb.size.y * sc, foot_z * sc)
	shape.shape = bs
	shape.position = Vector3(0, bs.size.y * 0.5, 0)
	body.add_child(shape)
	var m := ArtKit.kenney(path)
	m.scale = Vector3.ONE * sc
	m.rotation.y = yaw
	var center := Basis(Vector3.UP, yaw) * (bb.get_center() * sc)
	m.position = Vector3(-center.x, 0, -center.z)
	body.add_child(m)
	root.add_child(body)


## Suburban house set back on its lot, facing the street, with a tree in the front yard.
static func _house(root: Node3D, rect: Rect2, pick: int, s: float) -> void:
	var c := rect.get_center()
	var options := [[c.y, Vector3(0, 0, -1)], [c.x, Vector3(-1, 0, 0)], [s - c.y, Vector3(0, 0, 1)], [s - c.x, Vector3(1, 0, 0)]]
	var best: Array = options[0]
	for o in options:
		if float(o[0]) < float(best[0]):
			best = o
	var face: Vector3 = best[1]
	var idx := absi(int(rect.position.x * 5.1) * 13 + int(rect.position.y * 2.7) * 7 + pick * 3) % HOUSES.size()
	var path := "suburban/" + str(HOUSES[idx])
	var bb := ArtKit.kenney_aabb(path)
	var yaw := atan2(face.x, face.z)
	var sideways := absf(face.x) > 0.5
	var foot_x := bb.size.z if sideways else bb.size.x
	var foot_z := bb.size.x if sideways else bb.size.z
	var sc := minf(minf(rect.size.x / foot_x, rect.size.y / foot_z) * 0.72, 12.5)
	# Push the house back from the street to leave a front yard.
	var yard := (minf(rect.size.x, rect.size.y) - maxf(foot_x, foot_z) * sc) * 0.35
	var center := Vector3(c.x, 0, c.y) - face * yard
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"static_world")
	body.position = center
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(foot_x * sc, bb.size.y * sc, foot_z * sc)
	shape.shape = bs
	shape.position = Vector3(0, bs.size.y * 0.5, 0)
	body.add_child(shape)
	var m := ArtKit.kenney(path)
	m.scale = Vector3.ONE * sc
	m.rotation.y = yaw
	var off := Basis(Vector3.UP, yaw) * (bb.get_center() * sc)
	m.position = Vector3(-off.x, 0, -off.z)
	body.add_child(m)
	root.add_child(body)
	# Front-yard tree beside the path to the door.
	var side := Vector3(-face.z, 0, face.x)
	var front := Vector3(c.x, 0, c.y) + face * (minf(rect.size.x, rect.size.y) * 0.38) + side * (minf(rect.size.x, rect.size.y) * 0.3)
	ArtKit.tree(root, front, 0.9)


## Planters with shrubs along commercial sidewalks (solid, outside the lanes).
static func _sidewalk_planters(root: Node3D, plan: Dictionary, graph: LaneGraph) -> void:
	var s := graph.cell_size
	var band := graph.half_road() + 1.6
	var spots: Array = [[Vector3(band, 0, s * 0.5), PI * 0.5]]
	if plan["south_open"]:
		spots.append([Vector3(s * 0.5, 0, band), 0.0])
	for spot in spots:
		var p: Vector3 = spot[0]
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group(&"static_world")
		body.position = p
		body.rotation.y = float(spot[1])
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3.4, 1.2, 2.4)
		shape.shape = bs
		shape.position = Vector3(0, 0.6, 0)
		body.add_child(shape)
		var m := ArtKit.kenney("suburban/planter")
		m.scale = Vector3.ONE * 8.5
		body.add_child(m)
		root.add_child(body)


static func _parked_car(root: Node3D, entry: Dictionary) -> void:
	var pos: Vector2 = entry["pos"]
	var yaw := float(entry["yaw"])
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group(&"static_world")
	body.position = Vector3(pos.x, 0, pos.y)
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.1, 1.6, 4.0)
	shape.shape = bs
	shape.position = Vector3(0, 0.8, 0)
	body.add_child(shape)
	var m := ArtKit.kenney("cars/" + str(PARKED[int(entry["color"]) % PARKED.size()]))
	m.scale = Vector3.ONE * 1.5
	body.add_child(m)
	root.add_child(body)
