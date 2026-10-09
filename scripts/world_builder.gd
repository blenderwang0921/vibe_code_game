class_name WorldBuilder
extends RefCounted

var region: NavigationRegion3D
var scenery: Node3D
var obstacle_points: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

func build(navigation: NavigationRegion3D, decoration: Node3D) -> void:
	region = navigation
	scenery = decoration
	rng.seed = 73129
	_solid(Vector3(0, -0.5, -8), Vector3(52, 1, 64), 1)
	LowPoly.box(scenery, Vector3(0, -0.15, -18), Vector3(52, 0.28, 44), Color("3c6658"))
	LowPoly.box(scenery, Vector3(0, -0.15, 14), Vector3(52, 0.28, 20), Color("768473"))
	LowPoly.box(scenery, Vector3(0, -1.3, -8), Vector3(52.3, 2.3, 64.3), Color("344e4b"))
	_path()
	for pos in [Vector3(-11, 0, 15), Vector3(11, 0, 15), Vector3(-13, 0, 7), Vector3(14, 0, 8)]:
		_house(pos)
	var trees: Array[Vector3] = [
		Vector3(-3, 0, -7), Vector3(7, 0, -5), Vector3(-9, 0, -10), Vector3(10, 0, -15),
		Vector3(-4, 0, -19), Vector3(5, 0, -24), Vector3(-12, 0, -25), Vector3(14, 0, -31),
		Vector3(-5, 0, -34), Vector3(4, 0, -35), Vector3(17, 0, -8), Vector3(-17, 0, -4),
		Vector3(-18, 0, -16), Vector3(18, 0, -20), Vector3(-17, 0, -34)]
	for z in range(-38, 23, 7):
		trees.append(Vector3(-23 + rng.randf_range(-0.5, 0.5), 0, z))
		trees.append(Vector3(23 + rng.randf_range(-0.5, 0.5), 0, z + 1))
	for x in range(-19, 23, 7):
		trees.append(Vector3(x, 0, -38))
	for point in trees:
		_tree(point, rng.randf_range(0.85, 1.25))
	for point in [Vector3(3, 0, -11), Vector3(-9, 0, -3), Vector3(-12, 0, -18), Vector3(13, 0, -21), Vector3(0, 0, -28)]:
		_rock(point)
	for x in [-6.0, 6.0]:
		_solid(Vector3(x, 1.3, 4), Vector3(0.6, 2.6, 0.6), 2)
		LowPoly.box(scenery, Vector3(x, 1.3, 4), Vector3(0.6, 2.6, 0.6), Color("b1afa0"))
		LowPoly.orb(scenery, Vector3(x, 2.8, 4), 0.25, Color("a8e5cf"), true)
		LowPoly.cone(scenery, Vector3(x, 2.55, 4), 0.5, 0.35, 0.15, Color("d9c998"))
	for x in range(-24, 26, 2):
		LowPoly.box(scenery, Vector3(x, 0.012, 4), Vector3(1.1, 0.025, 0.14), Color("abd4bc"))
	LowPoly.label(scenery, Vector3(0, 1.1, 4), "↑  暮光森林\n村莊結界", Color("d4e9cc"), 24)
	# A small gathering circle gives the NPC a readable landmark.
	LowPoly.cone(scenery, Vector3(-2.5, 0.02, 12), 2.3, 2.3, 0.05, Color("959787"), 12)
	LowPoly.ring(scenery, Vector3(-2.5, 0.06, 12), 2.1, Color("bdb08b"), 0.03)
	for i in 95:
		var p := Vector3(rng.randf_range(-21, 21), 0.04, rng.randf_range(-36, 22))
		if absf(p.x) < 3.0 or p.distance_to(Vector3(-2.5, 0, 12)) < 3.5:
			continue
		var color := Color("9caf77") if p.z > 4 else Color("739b79")
		LowPoly.cone(scenery, p, 0.14, 0, rng.randf_range(0.2, 0.45), color, 4)
		if i % 4 == 0:
			LowPoly.orb(scenery, p + Vector3(0, 0.22, 0), 0.09, Color("ded6a3"))
	# Invisible edge colliders are outside the playable ground.
	for x in [-26.5, 26.5]:
		_solid(Vector3(x, 1, -8), Vector3(1, 3, 66), 2)
	_solid(Vector3(0, 1, -40.5), Vector3(54, 3, 1), 2)
	_solid(Vector3(0, 1, 24.5), Vector3(54, 3, 1), 2)

func _solid(at: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	region.add_child(body)
	return body

func _tree(at: Vector3, size: float) -> void:
	obstacle_points.append(at)
	var body := _solid(at + Vector3(0, 1.4, 0), Vector3(0.8, 2.8, 0.8) * Vector3(size, 1, size), 2)
	body.name = "Tree"
	LowPoly.cone(scenery, at + Vector3(0, 1.4, 0), 0.38 * size, 0.2 * size, 2.8, Color("65594b"))
	var green := Color("2d6559").lightened(rng.randf_range(0.0, 0.13))
	for i in 3:
		var foliage := LowPoly.cone(scenery, at + Vector3(0, (2.5 + i * 0.9) * size, 0), (1.8 - i * 0.38) * size, 0, 2.25 * size, green.lightened(i * 0.05), 7)
		foliage.rotation.y = i * 0.4

func _rock(at: Vector3) -> void:
	obstacle_points.append(at)
	_solid(at + Vector3(0, 0.65, 0), Vector3(2, 1.3, 1.8), 2)
	var rock := LowPoly.orb(scenery, at + Vector3(0, 0.65, 0), 1.1, Color("84968b"))
	rock.scale = Vector3(1.12, 0.83, 1.0)
	rock.rotation = Vector3(0.15, 0.5, 0.1)
	LowPoly.orb(scenery, at + Vector3(0.55, 0.25, 0.8), 0.35, Color("a4ad99"))

func _house(at: Vector3) -> void:
	obstacle_points.append(at)
	_solid(at + Vector3(0, 1.65, 0), Vector3(4.8, 3.3, 4.2), 2)
	LowPoly.box(scenery, at + Vector3(0, 1.4, 0), Vector3(4.6, 2.8, 4), Color("d3c3a0"))
	LowPoly.box(scenery, at + Vector3(0, 0.22, 0), Vector3(4.9, 0.44, 4.3), Color("7e8274"))
	var roof := PrismMesh.new()
	roof.size = Vector3(5.5, 2.0, 4.9)
	LowPoly.mesh(scenery, roof, at + Vector3(0, 3.4, 0), Color("697d88") if at.x > 0 else Color("a77860"))
	LowPoly.box(scenery, at + Vector3(0, 0.94, 2.03), Vector3(0.95, 1.85, 0.08), Color("655b4f"))
	for x in [-1.4, 1.4]:
		LowPoly.box(scenery, at + Vector3(x, 1.65, 2.05), Vector3(0.72, 0.86, 0.08), Color("795e49"))
		var window := LowPoly.box(scenery, at + Vector3(x, 1.65, 2.1), Vector3(0.5, 0.64, 0.05), Color("f4cd8f"))
		window.material_override = LowPoly.material(Color("f4cd8f"), true)
		LowPoly.box(scenery, at + Vector3(x, 1.65, 2.15), Vector3(0.045, 0.66, 0.06), Color("795e49"))
	LowPoly.box(scenery, at + Vector3(1.5, 3.9, -0.7), Vector3(0.7, 1.7, 0.7), Color("a0a08e"))

func _path() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-38, 24, 2):
		var x1 := sin(z * 0.13) * 1.3
		var x2 := sin((z + 2) * 0.13) * 1.3
		var width := 2.0 if z < 4 else 3.0
		var a := Vector3(x1 - width, 0.006, z)
		var b := Vector3(x1 + width, 0.006, z)
		var c := Vector3(x2 + width, 0.006, z + 2)
		var d := Vector3(x2 - width, 0.006, z + 2)
		for point in [a, b, c, a, c, d]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	LowPoly.mesh(scenery, surface.commit(), Vector3.ZERO, Color("8e9378"))

