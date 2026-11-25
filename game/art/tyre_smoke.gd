class_name TyreSmoke
extends Node3D
## Tyre smoke from the rear wheels: billowing, lit, soft puffs that grow and fade.
## CPUParticles3D for Compatibility/mobile safety. Intensity 0..1 from the car's slide.

const PUFF_LIFETIME := 1.3

var _emitters: Array[CPUParticles3D] = []
var _intensity: float = 0.0
static var _material: StandardMaterial3D
static var _mesh: QuadMesh


func setup(rear_points: Array[Vector3]) -> void:
	for p in rear_points:
		var e := CPUParticles3D.new()
		e.amount = 40
		e.lifetime = PUFF_LIFETIME
		e.local_coords = false  # puffs stay where they were emitted
		e.emitting = false
		e.mesh = _puff_mesh()
		e.position = p
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		e.emission_sphere_radius = 0.25
		e.direction = Vector3(0, 1, 0.4)
		e.spread = 40.0
		e.initial_velocity_min = 0.8
		e.initial_velocity_max = 2.4
		e.gravity = Vector3(0, 0.9, 0)
		e.damping_min = 1.2
		e.damping_max = 2.0
		e.angle_min = 0.0
		e.angle_max = 360.0
		e.angular_velocity_min = -40.0
		e.angular_velocity_max = 40.0
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.35))
		grow.add_point(Vector2(0.4, 1.0))
		grow.add_point(Vector2(1.0, 1.7))
		e.scale_amount_curve = grow
		e.scale_amount_min = 1.4
		e.scale_amount_max = 2.2
		var fade := Gradient.new()
		fade.set_color(0, Color(0.92, 0.92, 0.95, 0.55))
		fade.set_color(1, Color(0.85, 0.85, 0.9, 0.0))
		fade.add_point(0.15, Color(0.95, 0.95, 0.97, 0.6))
		e.color_ramp = fade
		add_child(e)
		_emitters.append(e)


static func _puff_mesh() -> QuadMesh:
	if _mesh != null:
		return _mesh
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.6))
	tex.gradient = g
	_material = StandardMaterial3D.new()
	_material.albedo_texture = tex
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_material.vertex_color_use_as_albedo = true
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.roughness = 1.0
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = QuadMesh.new()
	_mesh.size = Vector2(1.0, 1.0)
	_mesh.material = _material
	return _mesh


## 0 = none, 1 = full drift smoke.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	var on := _intensity > 0.08
	for e in _emitters:
		if e.emitting != on:
			e.emitting = on
		# Thicker, bigger puffs the harder the slide (CPUParticles3D has no amount_ratio in 4.3).
		e.color = Color(1, 1, 1, 0.35 + 0.65 * _intensity)
		e.scale_amount_max = 1.5 + 1.2 * _intensity
		e.initial_velocity_max = 1.2 + 2.0 * _intensity


## World-space puffs cannot be shifted; clear them on an origin shift.
func reset_puffs() -> void:
	for e in _emitters:
		e.restart()
		e.emitting = _intensity > 0.08
