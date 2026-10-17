class_name ActorVisual
extends Node3D

@export_enum("wizard", "enemy", "elder") var kind: String = "wizard"
@export var model_scene: PackedScene
var moving: bool = false
var cast_left: float = 0.0
var flash_left: float = 0.0
var phase: float = 0.0
var rig: Node3D
var staff: Node3D
var feet: Array[Node3D] = []
var parts: Array[MeshInstance3D] = []
var flash_material: StandardMaterial3D

func _ready() -> void:
	rig = model_scene.instantiate() as Node3D if model_scene else Node3D.new()
	add_child(rig)
	if not model_scene:
		if kind == "enemy":
			_build_enemy()
		else:
			_build_person()
	_collect_parts(rig)
	flash_material = LowPoly.material(Color(1.0, 0.86, 0.68, 0.7), true)

func _collect_parts(node: Node) -> void:
	if node is MeshInstance3D:
		parts.append(node)
	for child in node.get_children():
		_collect_parts(child)

func _build_person() -> void:
	var wizard := kind == "wizard"
	var robe := Color("645eac") if wizard else Color("427f76")
	LowPoly.cone(rig, Vector3(0, 0.7, 0), 0.5, 0.25, 1.15, robe)
	LowPoly.cone(rig, Vector3(0, 1.22, 0), 0.39, 0.23, 0.3, robe.lightened(0.22))
	LowPoly.cone(rig, Vector3(0, 0.95, 0), 0.38, 0.36, 0.1, Color("dcb77d"))
	LowPoly.orb(rig, Vector3(0, 1.56, -0.015), 0.27, Color("edc49c"))
	LowPoly.box(rig, Vector3(-0.1, 1.59, -0.26), Vector3(0.06, 0.065, 0.035), Color("223243"))
	LowPoly.box(rig, Vector3(0.1, 1.59, -0.26), Vector3(0.06, 0.065, 0.035), Color("223243"))
	if wizard:
		LowPoly.cone(rig, Vector3(0, 1.8, 0), 0.62, 0.6, 0.075, robe.lightened(0.15))
		var hat := LowPoly.cone(rig, Vector3(0.03, 2.15, 0.03), 0.43, 0.035, 0.78, robe)
		hat.rotation.z = -0.13
		LowPoly.cone(rig, Vector3(0, 1.87, 0), 0.41, 0.37, 0.12, Color("dcb77d"))
	else:
		LowPoly.orb(rig, Vector3(0, 1.75, 0.05), 0.25, Color("dce2d7"))
		LowPoly.cone(rig, Vector3(0, 1.31, -0.22), 0.03, 0.19, 0.42, Color("dce2d7"))
	for x in [-0.21, 0.21]:
		var foot := LowPoly.box(rig, Vector3(x, 0.13, -0.04), Vector3(0.22, 0.25, 0.38), Color("2c3445"))
		feet.append(foot)
	staff = Node3D.new()
	staff.position = Vector3(0.54, 1.05, -0.13)
	rig.add_child(staff)
	LowPoly.cone(staff, Vector3(0, -0.14, 0), 0.045, 0.035, 1.65, Color("a27a56"))
	LowPoly.cone(staff, Vector3(0, 0.69, 0), 0.13, 0.1, 0.17, Color("e0c17e"))
	LowPoly.orb(staff, Vector3(0, 0.88, 0), 0.18, Color("a6f6e7"), true)
	LowPoly.orb(rig, Vector3(0.47, 1.07, -0.08), 0.13, Color("edc49c"))

func _build_enemy() -> void:
	var body := LowPoly.orb(rig, Vector3(0, 0.67, 0.06), 0.65, Color("66806b"))
	body.scale = Vector3(1, 0.82, 1.2)
	LowPoly.orb(rig, Vector3(0, 0.7, -0.51), 0.43, Color("859675"))
	LowPoly.box(rig, Vector3(-0.2, 0.8, -0.87), Vector3(0.13, 0.075, 0.08), Color("ffd181"))
	LowPoly.box(rig, Vector3(0.2, 0.8, -0.87), Vector3(0.13, 0.075, 0.08), Color("ffd181"))
	for x in [-0.3, 0.3]:
		var horn := LowPoly.cone(rig, Vector3(x, 1.12, -0.36), 0.13, 0.015, 0.55, Color("dfc99b"), 5)
		horn.rotation.z = -x * 1.2
		for z in [-0.35, 0.4]:
			var foot := LowPoly.box(rig, Vector3(x, 0.18, z), Vector3(0.19, 0.37, 0.23), Color("3b514c"))
			feet.append(foot)
	for z in [0.1, 0.4, 0.7]:
		LowPoly.cone(rig, Vector3(0, 1.15, z), 0.25, 0.01, 0.42, Color("a7ae77"), 5)

func flash() -> void:
	flash_left = 0.15

func cast() -> void:
	cast_left = 0.3

func _process(delta: float) -> void:
	phase += delta * (10.0 if moving else 2.2)
	cast_left = maxf(0.0, cast_left - delta)
	flash_left = maxf(0.0, flash_left - delta)
	# Imported characters keep their authored rest pose until animations are added.
	if not model_scene:
		_animate_procedural()
	for part in parts:
		part.material_overlay = flash_material if flash_left > 0.0 else null

func _animate_procedural() -> void:
	rig.position.y = sin(phase) * (0.065 if moving else 0.018)
	rig.rotation.z = sin(phase * 0.5) * (0.055 if moving else 0.012)
	for i in feet.size():
		feet[i].rotation.x = sin(phase + i * PI) * (0.4 if moving else 0.0)
	if staff:
		staff.rotation.x = -sin(cast_left / 0.3 * PI) * 0.85
	elif cast_left > 0.0:
		rig.rotation.x = sin(cast_left / 0.3 * PI) * 0.2
	else:
		rig.rotation.x = 0.0

