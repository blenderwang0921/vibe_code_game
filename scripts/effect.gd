extends Node3D

var tint: Color = Color("ffd194")
var radius: float = 1.0
var lifetime: float = 0.55
var age: float = 0.0
var ring_mesh: MeshInstance3D
var shards: Array[MeshInstance3D] = []
var fade_material: StandardMaterial3D

func _ready() -> void:
	ring_mesh = LowPoly.ring(self, Vector3(0, 0.055, 0), 1.0, tint)
	fade_material = ring_mesh.material_override.duplicate()
	fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mesh.material_override = fade_material
	for i in 8:
		var a := i * TAU / 8.0
		var shard := LowPoly.cone(self, Vector3(cos(a), 0.2, sin(a)), 0.1, 0.0, 0.5, tint, 4)
		shard.material_override = fade_material
		shards.append(shard)

func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / lifetime, 0, 1)
	ring_mesh.scale = Vector3.ONE * radius * lerpf(0.35, 1.0, ease(progress, 0.4))
	for i in shards.size():
		var a := i * TAU / shards.size()
		shards[i].position = Vector3(cos(a) * radius * progress, sin(progress * PI) * 0.6, sin(a) * radius * progress)
		shards[i].scale = Vector3.ONE * (1.0 - progress)
	fade_material.albedo_color = Color(tint, (1.0 - progress) * 0.8)
	if age >= lifetime:
		queue_free()

