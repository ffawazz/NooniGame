extends RefCounted
## Builds cel-shaded, outlined meshes in code. Everything in the greybox goes through here so the whole
## game shares one look. Pass box_hull = true for BoxMesh parts (see outline.gdshader).

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const OUTLINE_COLOR := Color(0.07, 0.05, 0.11)


static func material(color: Color, outline_width := 0.03, box_hull := false, options := {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", color)
	for key in options:
		mat.set_shader_parameter(key, options[key])
	if outline_width > 0.0:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter("width", outline_width)
		outline.set_shader_parameter("box_hull", box_hull)
		outline.set_shader_parameter("outline_color", OUTLINE_COLOR)
		mat.next_pass = outline
	return mat


static func box(parent: Node, size: Vector3, pos: Vector3, color: Color, outline_width := 0.03, options := {}) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, material(color, outline_width, true, options))


static func sphere(parent: Node, radius: float, pos: Vector3, color: Color, outline_width := 0.03) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add(parent, mesh, pos, material(color, outline_width))


static func capsule(parent: Node, radius: float, height: float, pos: Vector3, color: Color, outline_width := 0.03) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _add(parent, mesh, pos, material(color, outline_width))


static func cylinder(parent: Node, radius: float, height: float, pos: Vector3, color: Color, outline_width := 0.03, top_radius := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	return _add(parent, mesh, pos, material(color, outline_width))


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, color: Color, outline_width := 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return _add(parent, mesh, pos, material(color, outline_width))


static func _add(parent: Node, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance
