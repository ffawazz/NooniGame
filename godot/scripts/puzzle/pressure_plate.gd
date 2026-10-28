extends Area3D
## Floor plate that adds up the `weight` of every playable character standing on it. At or above
## `required_weight` it is active and tells its `target` (anything with set_open(bool)) to open.
## Nooni weighs 1 and Bruce weighs 3, so a required weight of 2 can only be held down by Bruce.

const Toon := preload("res://scripts/core/toon.gd")

signal changed(active: bool)

@export var required_weight := 2.0

## Anything with set_open(bool), set by whoever builds the room.
var target: Node
var total_weight := 0.0
var active := false

var _mesh: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # characters

	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 0.4
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.2
	add_child(collision)

	_mesh = Toon.cylinder(self, 0.6, 0.08, Vector3(0, 0.04, 0), Color(0.95, 0.6, 0.2), 0.02)

	_label = Label3D.new()
	_label.font_size = 56
	_label.pixel_size = 0.008
	_label.outline_size = 12
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 0.75, 0)
	add_child(_label)
	_refresh()


func _physics_process(_delta: float) -> void:
	var weight := 0.0
	for body in get_overlapping_bodies():
		if "weight" in body:
			weight += body.weight

	var now_active := weight >= required_weight
	if weight != total_weight or now_active != active:
		total_weight = weight
		var was_active := active
		active = now_active
		_refresh()
		if active != was_active:
			if target:
				target.set_open(active)
			changed.emit(active)


func _refresh() -> void:
	_mesh.position.y = 0.015 if active else 0.04
	_mesh.material_override.set_shader_parameter("albedo", Color(0.35, 0.8, 0.45) if active else Color(0.95, 0.6, 0.2))
	_label.text = "%d / %d" % [roundi(total_weight), roundi(required_weight)]
