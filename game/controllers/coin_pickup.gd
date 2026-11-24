class_name CoinPickup
extends Area3D
## Authored pickup-line coin. Collected only by the player.

signal collected(coin: CoinPickup)

static var _mesh: CylinderMesh

var taken: bool = false
var _visual: MeshInstance3D


func setup() -> void:
	collision_layer = 16
	collision_mask = 2
	monitorable = false
	add_to_group(&"origin_shift")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	shape.shape = sphere
	shape.position = Vector3(0, 1.0, 0)
	add_child(shape)
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 0.55
		_mesh.bottom_radius = 0.55
		_mesh.height = 0.14
		_mesh.radial_segments = 14
		_mesh.rings = 1
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	_visual.material_override = ArtKit.mat(ArtKit.COIN, 1.2)
	_visual.position = Vector3(0, 1.1, 0)
	_visual.rotation = Vector3(PI * 0.5, 0, 0)
	add_child(_visual)
	body_entered.connect(_on_body_entered)
	deactivate()


func place(world_pos: Vector3) -> void:
	taken = false
	global_position = world_pos
	visible = true
	set_deferred("monitoring", true)
	set_process(true)


func deactivate() -> void:
	visible = false
	set_deferred("monitoring", false)
	set_process(false)


func _process(delta: float) -> void:
	rotate_y(delta * 3.0)


func _on_body_entered(body: Node3D) -> void:
	if taken or not (body is PlayerCar):
		return
	taken = true
	deactivate()
	collected.emit(self)


func apply_origin_shift(offset: Vector3) -> void:
	global_position += offset
