class_name DebrisPiece
extends Node3D
## A Kenney car-kit debris part thrown off on crashes. Ballistic with bounce and spin,
## then removes itself. A handful per crash, so it is not pooled.

const PARTS := ["debris-bumper", "debris-door", "debris-tire", "debris-plate-a", "debris-spoiler-a"]

var velocity: Vector3 = Vector3.ZERO
var spin: Vector3 = Vector3.ZERO
var life: float = 3.5
var _visual: Node3D


static func burst(parent: Node, origin: Vector3, base_velocity: Vector3, count: int) -> void:
	for i in count:
		var p := DebrisPiece.new()
		p._visual = ArtKit.kenney("cars/" + str(PARTS[i % PARTS.size()]))
		p._visual.scale = Vector3.ONE * 1.5
		p.add_child(p._visual)
		parent.add_child(p)
		p.add_to_group(&"origin_shift")
		p.global_position = origin + Vector3(randf_range(-1, 1), 0.8, randf_range(-1, 1))
		var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		p.velocity = base_velocity * 0.6 + away * randf_range(4, 9) + Vector3.UP * randf_range(5, 10)
		p.spin = Vector3(randf_range(-12, 12), randf_range(-8, 8), randf_range(-12, 12))


func _physics_process(delta: float) -> void:
	life -= delta
	velocity.y -= 22.0 * delta
	global_position += velocity * delta
	if global_position.y < 0.1:
		global_position.y = 0.1
		velocity.y = absf(velocity.y) * 0.35
		velocity.x *= 0.7
		velocity.z *= 0.7
		spin *= 0.6
	rotation += spin * delta
	if life < 0.6:
		scale = Vector3.ONE * maxf(life / 0.6, 0.01)
	if life <= 0.0:
		queue_free()


func apply_origin_shift(offset: Vector3) -> void:
	global_position += offset
