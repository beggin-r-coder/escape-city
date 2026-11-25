class_name ArtKit
extends RefCounted
## Placeholder art vocabulary built from primitives with shared meshes and cached
## materials. Restrained warm/cool palette; hazards use high-contrast orange/yellow,
## decoration never uses hazard colors.

const ASPHALT := Color("26282e")
const LANE_MARK := Color("d9d4c5")
const SIDEWALK := Color("7d7a76")
const GRASS := Color("4f7a46")
const PAVING := Color("a39a8c")
const HEDGE := Color("3e6b3a")
const TRUNK := Color("5a4030")
const CROWN := Color("4c8a45")
const CONE := Color("ff6a13")
const CRATE := Color("f2c230")
const COIN := Color("ffd23f")
const BUILDINGS := [
	Color("d9b38c"), Color("c46f4f"), Color("8fa3b8"), Color("e6d3b3"),
	Color("6f8299"), Color("c9925a"), Color("a35a44"), Color("b8c2c9"),
]

const KENNEY_DIR := "res://game/art/kenney/"

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}
static var _aabbs: Dictionary = {}
static var _box: BoxMesh
static var _cylinder: CylinderMesh
static var _sphere: SphereMesh


static func mat(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [color.to_html(), emission, unshaded]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = m
	return m


## Instantiate a Kenney model, e.g. kenney("cars/police") or kenney("roads/road-straight").
static func kenney(path: String) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load(KENNEY_DIR + path + ".glb")
	var scene := _scenes[path] as PackedScene
	if scene == null:
		push_error("Missing Kenney model %s" % path)
		return Node3D.new()
	return scene.instantiate() as Node3D


## Combined mesh AABB of a Kenney model in its own (unscaled) space. Cached.
static func kenney_aabb(path: String) -> AABB:
	if _aabbs.has(path):
		return _aabbs[path]
	var inst := kenney(path)
	var box := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := _relative_xf(m, inst)
		var b := xf * m.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	inst.free()
	_aabbs[path] = box
	return box


static func _relative_xf(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Fresh (non-cached) material, for things that animate (brake lights, light bars).
static func unique_mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = emission
	return m


static func box_mesh() -> BoxMesh:
	if _box == null:
		_box = BoxMesh.new()
	return _box


static func cylinder_mesh() -> CylinderMesh:
	if _cylinder == null:
		_cylinder = CylinderMesh.new()
		_cylinder.top_radius = 0.5
		_cylinder.bottom_radius = 0.5
		_cylinder.height = 1.0
		_cylinder.radial_segments = 10
		_cylinder.rings = 1
	return _cylinder


static func sphere_mesh() -> SphereMesh:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 0.5
		_sphere.height = 1.0
		_sphere.radial_segments = 10
		_sphere.rings = 6
	return _sphere


## Unit-box visual scaled to `size`, centred at `center`.
static func box(parent: Node, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh()
	mi.material_override = material
	mi.transform = Transform3D(Basis.from_scale(size), center)
	parent.add_child(mi)
	return mi


static func static_box(parent: Node, size: Vector3, center: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	body.add_to_group(&"static_world")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	if material != null:
		box(body, size, Vector3.ZERO, material)
	parent.add_child(body)
	return body


static func tree(parent: Node, pos: Vector3, scale_f: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.add_to_group(&"static_world")
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.5
	cs.height = 3.0
	shape.shape = cs
	shape.position = Vector3(0, 1.5, 0)
	body.add_child(shape)
	var trunk := MeshInstance3D.new()
	trunk.mesh = cylinder_mesh()
	trunk.material_override = mat(TRUNK)
	trunk.transform = Transform3D(Basis.from_scale(Vector3(0.6, 3.0, 0.6)), Vector3(0, 1.5, 0))
	body.add_child(trunk)
	var crown := MeshInstance3D.new()
	crown.mesh = sphere_mesh()
	crown.material_override = mat(CROWN)
	var s := 4.2 * scale_f
	crown.transform = Transform3D(Basis.from_scale(Vector3(s, s * 0.9, s)), Vector3(0, 3.0 + s * 0.35, 0))
	body.add_child(crown)
	parent.add_child(body)


## Car model facing -Z. shape: 0 coupe, 1 hatch, 2 muscle, 3 van.
## Returns the model root; meta "brake_mat" / "bar_red" / "bar_blue" hold animated materials.
static func car(shape: int, body_color: Color, accent: Color, police: bool = false) -> Node3D:
	var root := Node3D.new()
	var length := 4.2
	var width := 2.0
	var body_h := 0.7
	var cabin := Vector3(1.7, 0.6, 2.0)
	var cabin_z := 0.3
	match shape:
		1:
			length = 3.7
			cabin = Vector3(1.75, 0.7, 2.1)
			cabin_z = 0.5
		2:
			width = 2.1
			body_h = 0.6
			cabin = Vector3(1.6, 0.5, 1.7)
			cabin_z = 0.5
		3:
			length = 4.6
			body_h = 1.0
			cabin = Vector3(1.9, 1.0, 3.2)
			cabin_z = 0.5
	var body_mat := mat(body_color)
	box(root, Vector3(width, body_h, length), Vector3(0, 0.35 + body_h * 0.5, 0), body_mat)
	box(root, cabin, Vector3(0, 0.35 + body_h + cabin.y * 0.5, cabin_z), mat(accent))
	if shape == 2:
		box(root, Vector3(0.5, 0.08, length * 0.9), Vector3(0, 0.36 + body_h, 0), mat(accent))
	var wheel_mat := mat(Color("15161a"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.mesh = cylinder_mesh()
			w.material_override = wheel_mat
			var b := Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(0.76, 0.3, 0.76))
			w.transform = Transform3D(b, Vector3(sx * (width * 0.5 - 0.05), 0.38, sz * (length * 0.5 - 0.75)))
			root.add_child(w)
	var head := mat(Color("fff6d8"), 2.0)
	for sx in [-0.6, 0.6]:
		box(root, Vector3(0.4, 0.18, 0.06), Vector3(sx, 0.75, -length * 0.5), head)
	var brake := unique_mat(Color("ff2a2a"), 0.6)
	for sx in [-0.65, 0.65]:
		box(root, Vector3(0.4, 0.18, 0.06), Vector3(sx, 0.75, length * 0.5), brake)
	root.set_meta(&"brake_mat", brake)
	if police:
		# Big unshaded light bar + white roof so police read instantly from the high camera.
		var red := StandardMaterial3D.new()
		red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		red.albedo_color = Color("ff2233")
		var blue := StandardMaterial3D.new()
		blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		blue.albedo_color = Color("2a6bff")
		var roof_y := 0.35 + body_h + cabin.y
		box(root, Vector3(cabin.x - 0.1, 0.06, cabin.z - 0.2), Vector3(0, roof_y + 0.03, cabin_z), mat(Color("f4f6fa")))
		box(root, Vector3(0.75, 0.28, 0.55), Vector3(-0.42, roof_y + 0.2, cabin_z), red)
		box(root, Vector3(0.75, 0.28, 0.55), Vector3(0.42, roof_y + 0.2, cabin_z), blue)
		box(root, Vector3(width + 0.02, 0.2, 1.2), Vector3(0, 0.55 + body_h * 0.5, 0.0), mat(accent))
		root.set_meta(&"bar_red", red)
		root.set_meta(&"bar_blue", blue)
	return root


static func car_extent(shape: int) -> Vector3:
	match shape:
		1:
			return Vector3(2.0, 1.6, 3.7)
		2:
			return Vector3(2.1, 1.4, 4.2)
		3:
			return Vector3(2.0, 2.4, 4.6)
	return Vector3(2.0, 1.6, 4.2)
