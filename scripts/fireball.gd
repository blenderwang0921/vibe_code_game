extends Node3D

var world
var direction: Vector3 = Vector3.FORWARD
var damage: float = 24.0
var speed: float = 17.0
var max_distance: float = 17.0
var traveled: float = 0.0
var consumed: bool = false
var trail: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("projectiles")
	LowPoly.orb(self, Vector3.ZERO, 0.23, Color("ffcd8e"), true)
	for i in 5:
		var mote := LowPoly.orb(self, -direction * (i + 1) * 0.17, 0.14 - i * 0.021, Color("ee815d"), true)
		trail.append(mote)

func _physics_process(delta: float) -> void:
	if consumed:
		return
	var step := minf(speed * delta, max_distance - traveled)
	var next := global_position + direction * step
	# Sweeping the entire segment prevents tunnelling at low FPS. Ray queries
	# return the nearest hit, so an obstacle shields enemies behind it.
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 2 | 8)
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		consumed = true
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(damage)
		world.effect(hit.position, Color("ffbd81"), 0.65)
		queue_free()
		return
	global_position = next
	traveled += step
	if traveled >= max_distance:
		queue_free()

