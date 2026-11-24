class_name BreakableProp
extends Area3D
## Breakable cone/crate. Vehicles pass through; the prop becomes pooled flying debris.
## Buildings and parked cars are static; only these props break.

signal smashed(prop: BreakableProp, by: Node3D)

static var _cone_mesh: CylinderMesh

var type: StringName = &"cone"
var broken: bool = false
var _visual: MeshInstance3D
var _vel: Vector3 = Vector3.ZERO
var _spin: Vector3 = Vector3.ZERO
var _t: float = 0.0


func setup(prop_type: StringName) -> void:
	type = prop_type
	collision_layer = 16
	collision_mask = 2 | 4 | 8
	monitorable = false
	add_to_group(&"origin_shift")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	_visual = MeshInstance3D.new()
	if type == &"cone":
		if _cone_mesh == null:
			_cone_mesh = CylinderMesh.new()
			_cone_mesh.top_radius = 0.06
			_cone_mesh.bottom_radius = 0.38
			_cone_mesh.height = 0.95
			_cone_mesh.radial_segments = 8
			_cone_mesh.rings = 1
		_visual.mesh = _cone_mesh
		_visual.material_override = ArtKit.mat(ArtKit.CONE, 0.25)
		_visual.position = Vector3(0, 0.475, 0)
		bs.size = Vector3(0.9, 1.0, 0.9)
	else:
		_visual.mesh = ArtKit.box_mesh()
		_visual.material_override = ArtKit.mat(ArtKit.CRATE, 0.15)
		_visual.transform = Transform3D(Basis.from_scale(Vector3(1.1, 1.1, 1.1)), Vector3(0, 0.55, 0))
		bs.size = Vector3(1.2, 1.2, 1.2)
	shape.shape = bs
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)
	add_child(_visual)
	body_entered.connect(_on_body_entered)
	deactivate()


func place(world_pos: Vector3) -> void:
	broken = false
	_t = 0.0
	global_position = world_pos
	rotation = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	visible = true
	set_deferred("monitoring", true)
	set_physics_process(false)


func deactivate() -> void:
	visible = false
	set_deferred("monitoring", false)
	set_physics_process(false)


func _on_body_entered(body: Node3D) -> void:
	if broken:
		return
	if body is PlayerCar or body is PoliceAgent or body is TrafficAgent:
		smash(body)


func smash(by: Node3D) -> void:
	broken = true
	set_deferred("monitoring", false)
	var push := Vector3.ZERO
	if by is CharacterBody3D:
		push = (by as CharacterBody3D).velocity
	var away := global_position - by.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	_vel = push * 0.8 + away.normalized() * 4.0 + Vector3.UP * randf_range(5.0, 8.0)
	_spin = Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9))
	set_physics_process(true)
	smashed.emit(self, by)


func _physics_process(delta: float) -> void:
	_t += delta
	_vel.y -= 22.0 * delta
	global_position += _vel * delta
	if global_position.y < 0.0:
		global_position.y = 0.0
		_vel.y = absf(_vel.y) * 0.3
		_vel.x *= 0.6
		_vel.z *= 0.6
	_visual.rotation += _spin * delta
	if _t > 1.6:
		visible = false
		set_physics_process(false)


func apply_origin_shift(offset: Vector3) -> void:
	global_position += offset
