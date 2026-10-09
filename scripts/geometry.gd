class_name LowPoly
extends RefCounted

static var _materials: Dictionary = {}
static var _font: SystemFont

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if _materials.has(key):
		return _materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.95
	if glow:
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = result
	return result

static func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = at
	item.material_override = material(color, glow)
	parent.add_child(item)
	return item

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, color)

static func cone(parent: Node3D, at: Vector3, bottom: float, top: float, height: float, color: Color, sides: int = 8) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = bottom
	shape.top_radius = top
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	return mesh(parent, shape, at, color)

static func orb(parent: Node3D, at: Vector3, radius: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 8
	shape.rings = 3
	return mesh(parent, shape, at, color, glow)

static func ring(parent: Node3D, at: Vector3, radius: float, color: Color, width: float = 0.035) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = maxf(0.01, radius - width)
	shape.outer_radius = radius + width
	shape.rings = 40
	shape.ring_segments = 4
	var item := mesh(parent, shape, at, color, true)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item

static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["PingFang TC", "Microsoft JhengHei", "Noto Sans CJK TC", "sans-serif"])
	return _font

static func label(parent: Node3D, at: Vector3, text: String, color: Color, size: int = 28) -> Label3D:
	var item := Label3D.new()
	item.font = font()
	item.text = text
	item.font_size = size * 2
	item.pixel_size = 0.015
	item.position = at
	item.modulate = color
	item.outline_size = 6
	item.outline_modulate = Color("14282d")
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(item)
	return item

