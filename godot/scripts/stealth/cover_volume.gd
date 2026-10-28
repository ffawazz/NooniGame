extends Node3D
## Box-shaped "hiding space" (behind the sofa, beside the counter). A crouched character inside one is
## invisible. Pure maths on the box, so no physics areas or collision layers are involved.

@export var size := Vector3(2.0, 2.0, 2.0)
@export var show_debug_box := true


func _ready() -> void:
	add_to_group("cover_volume")
	if show_debug_box:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.6, 1.0, 0.1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = mat
		add_child(mesh)


func contains(point: Vector3) -> bool:
	var p := global_transform.affine_inverse() * point
	var h := size * 0.5
	return absf(p.x) <= h.x and absf(p.y) <= h.y and absf(p.z) <= h.z


static func is_covered(tree: SceneTree, point: Vector3) -> bool:
	for node in tree.get_nodes_in_group("cover_volume"):
		if node.contains(point):
			return true
	return false
