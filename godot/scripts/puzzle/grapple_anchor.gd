extends Node3D
## A grapple hook on a wall or beam. Nooni aims at it with the camera and clicks; she zips to `landing`.
## Shows a "GRAPPLE" tag while targeted, and is highlighted in Detective Vision.

const Toon := preload("res://scripts/core/toon.gd")

@export var max_range := 14.0
## Where Nooni ends up standing (a point on top of something).
@export var landing := Vector3.ZERO

var targeted := false
var vision_on := false

var _tag: Label3D
var _glow: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	add_to_group("grapple_anchor")
	add_to_group("vision_aware")

	var ring := Toon.torus(self, 0.07, 0.14, Vector3.ZERO, Color(0.55, 0.58, 0.65), 0.012)
	ring.rotation_degrees = Vector3(90, 0, 0)
	Toon.cylinder(self, 0.035, 0.2, Vector3(0, 0, 0.1), Color(0.35, 0.37, 0.42), 0.01).rotation_degrees = Vector3(90, 0, 0)

	_glow = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	_glow.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_glow.material_override = mat
	_glow.visible = false
	add_child(_glow)

	_tag = Label3D.new()
	_tag.text = "GRAPPLE"
	_tag.font_size = 44
	_tag.pixel_size = 0.007
	_tag.outline_size = 10
	_tag.modulate = Color(1.0, 0.9, 0.4)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.position = Vector3(0, 0.45, 0)
	_tag.visible = false
	add_child(_tag)


func set_vision(on: bool) -> void:
	vision_on = on
	_refresh()


func set_targeted(on: bool) -> void:
	if on != targeted:
		targeted = on
		_refresh()


func _refresh() -> void:
	_glow.visible = targeted or vision_on
	_tag.visible = targeted or vision_on


func _process(delta: float) -> void:
	_time += delta
	if _glow.visible:
		_glow.scale = Vector3.ONE * (1.0 + 0.15 * sin(_time * 6.0))
