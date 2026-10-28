extends Node3D
## A surface Semba can scale (curtain, bookshelf). The node marks the zone in front of the surface where he
## can grab on. He must push toward the surface (`wall_direction` points INTO it) to start climbing, rises
## with the forward key, and on reaching `top_y` is placed at `landing` (a point standing on top).

@export var size := Vector3(1.0, 2.0, 1.0)
## Horizontal unit vector pointing from the zone into the surface.
@export var wall_direction := Vector3(-1, 0, 0)
## World height of the top edge.
@export var top_y := 2.0
## Where Semba ends up after mantling the top.
@export var landing := Vector3.ZERO
@export var hint_text := "climb (Semba)"


func _ready() -> void:
	add_to_group("climbable")
	var label := Label3D.new()
	label.text = hint_text
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.7, 0.85)
	label.position = Vector3(0, -size.y * 0.5 + 0.55, 0)
	add_child(label)


func contains(point: Vector3) -> bool:
	var p := global_transform.affine_inverse() * point
	var h := size * 0.5
	return absf(p.x) <= h.x and absf(p.y) <= h.y and absf(p.z) <= h.z


## The climbable whose grab zone contains `point`, or null.
static func find(tree: SceneTree, point: Vector3) -> Node:
	for node in tree.get_nodes_in_group("climbable"):
		if node.contains(point):
			return node
	return null
