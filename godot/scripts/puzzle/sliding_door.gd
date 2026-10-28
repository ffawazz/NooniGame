extends AnimatableBody3D
## A door that slides up out of the way. Opened and closed with set_open(), e.g. by a PressurePlate.

const Game := preload("res://scripts/core/game.gd")
const Toon := preload("res://scripts/core/toon.gd")

@export var size := Vector3(1.0, 2.2, 0.15)
@export var open_offset := Vector3(0.0, 2.1, 0.0)
@export var slide_seconds := 0.6
@export var display_name := "Door"

var is_open := false

var _closed_position := Vector3.ZERO
var _mesh: MeshInstance3D
var _tween: Tween


func _ready() -> void:
	collision_layer = 1  # world: blocks movement and sight while closed
	collision_mask = 0
	_closed_position = position

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	_mesh = Toon.box(self, size, Vector3.ZERO, Color(0.85, 0.3, 0.3), 0.03)


func set_open(value: bool) -> void:
	if value == is_open:
		return
	is_open = value
	Game.sfx("door", -4.0)
	_mesh.material_override.set_shader_parameter("albedo", Color(0.35, 0.8, 0.45) if is_open else Color(0.85, 0.3, 0.3))
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", _closed_position + (open_offset if is_open else Vector3.ZERO), slide_seconds)


func is_fully_open() -> bool:
	return is_open and position.distance_to(_closed_position + open_offset) < 0.01
