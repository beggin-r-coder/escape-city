class_name ChunkBuilder
extends RefCounted
## Turns a ChunkPlanner plan into scene nodes under a pooled chunk root.
## Static geometry only; breakables and coins are pooled separately by StreamingWorld.

const PARKED_COLORS := [Color("8aa1b8"), Color("6c7a5a"), Color("b8b3ab"), Color("7d5a5a")]


static func build(root: Node3D, plan: Dictionary, graph: LaneGraph) -> void:
	var s := graph.cell_size
	var hw := graph.half_road()
	var block := s - 2.0 * hw
	var mid := s * 0.5
	ArtKit.box(root, Vector3(block, 0.12, block), Vector3(mid, 0.06, mid), ArtKit.mat(ArtKit.SIDEWALK))
	var kind := int(plan["kind"])
	if kind == ChunkDefinition.Kind.PARK:
		ArtKit.box(root, Vector3(block - 6.0, 0.14, block - 6.0), Vector3(mid, 0.07, mid), ArtKit.mat(ArtKit.GRASS))
	elif kind == ChunkDefinition.Kind.PLAZA:
		ArtKit.box(root, Vector3(block - 6.0, 0.14, block - 6.0), Vector3(mid, 0.07, mid), ArtKit.mat(ArtKit.PAVING))
	# Intersection tint keeps junctions readable from the high camera.
	ArtKit.box(root, Vector3(2.0 * hw, 0.02, 2.0 * hw), Vector3(0, 0.01, 0), ArtKit.mat(ArtKit.ASPHALT.lightened(0.08)))
	_dashes(root, Vector3(0, 0.02, hw), Vector3(0, 0, 1), block)
	if plan["south_open"]:
		_dashes(root, Vector3(hw, 0.02, 0), Vector3(1, 0, 0), block)
	for b in plan["buildings"]:
		var r: Rect2 = b["rect"]
		var h := float(b["height"])
		var c := r.get_center()
		var color: Color = ArtKit.BUILDINGS[int(b["color"]) % ArtKit.BUILDINGS.size()]
		ArtKit.static_box(root, Vector3(r.size.x, h, r.size.y), Vector3(c.x, h * 0.5, c.y), ArtKit.mat(color))
		# Roof trim gives silhouettes some definition at no gameplay cost.
		ArtKit.box(root, Vector3(r.size.x + 0.4, 0.5, r.size.y + 0.4), Vector3(c.x, h + 0.25, c.y), ArtKit.mat(color.darkened(0.25)))
	for t in plan["trees"]:
		var p: Vector2 = t
		ArtKit.tree(root, Vector3(p.x, 0, p.y), 0.85 + fposmod(p.x * 0.37 + p.y * 0.11, 0.35))
	for r2 in plan["planters"]:
		var pr: Rect2 = r2
		var pc := pr.get_center()
		ArtKit.static_box(root, Vector3(pr.size.x, 1.0, pr.size.y), Vector3(pc.x, 0.5, pc.y), ArtKit.mat(ArtKit.HEDGE))
	for entry in plan["parked"]:
		_parked_car(root, entry)


static func _dashes(root: Node3D, start: Vector3, dir: Vector3, length: float) -> void:
	var mark := ArtKit.mat(ArtKit.LANE_MARK)
	var dash := 3.0
	var gap := 3.0
	var u := gap
	while u + dash <= length - gap:
		var center := start + dir * (u + dash * 0.5)
		var size := Vector3(0.3, 0.02, dash) if dir.z != 0.0 else Vector3(dash, 0.02, 0.3)
		ArtKit.box(root, size, center, mark)
		u += dash + gap


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
	bs.size = Vector3(2.0, 1.6, 4.4)
	shape.shape = bs
	shape.position = Vector3(0, 0.8, 0)
	body.add_child(shape)
	var color: Color = PARKED_COLORS[int(entry["color"]) % PARKED_COLORS.size()]
	body.add_child(ArtKit.car(0, color, color.lightened(0.3)))
	root.add_child(body)
