extends Node3D
## A stoplight over the road. While it is red, cross traffic flows through the junction. It cycles on its own,
## and Nooni can hack it to green for a while.

const Toon := preload("res://scripts/core/toon.gd")

@export var red_seconds := 11.0
@export var green_seconds := 9.0
@export var hacked_green_seconds := 10.0
@export var road_half := 5.4

var green := false
var hacked_left := 0.0
var cooldown_left := 0.0
## World Z of the junction.
var junction_z := 0.0

var _timer := 0.0
var _lamps: Array = []


func _ready() -> void:
	# A gantry across the road with a lamp over each lane, plus posts at the kerb.
	Toon.box(self, Vector3(road_half * 2.0 + 3.0, 0.4, 0.5), Vector3(0, 6.0, 0), Color(0.3, 0.3, 0.35))
	for side in [-1.0, 1.0]:
		Toon.box(self, Vector3(0.5, 6.0, 0.5), Vector3(side * (road_half + 1.2), 3.0, 0), Color(0.3, 0.3, 0.35))
	for x in [-3.6, 0.0, 3.6]:
		Toon.box(self, Vector3(0.9, 1.6, 0.5), Vector3(x, 5.0, 0.1), Color(0.12, 0.12, 0.15))
		var lamp := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.32
		mesh.height = 0.64
		lamp.mesh = mesh
		lamp.position = Vector3(x, 5.0, 0.4)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp.material_override = mat
		add_child(lamp)
		_lamps.append(mat)

	# A white stop line on the road.
	Toon.box(self, Vector3(road_half * 2.0, 0.03, 0.5), Vector3(0, 0.03, 12.0), Color(0.95, 0.95, 0.95), 0.0)
	_timer = randf_range(0.0, red_seconds)
	_refresh()


func tick(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if hacked_left > 0.0:
		hacked_left = maxf(0.0, hacked_left - delta)
		green = true
	else:
		_timer += delta
		var limit := green_seconds if green else red_seconds
		if _timer >= limit:
			_timer = 0.0
			green = not green
	_refresh()


## Force green for a while. Returns false while the hack is recharging.
func hack() -> bool:
	if cooldown_left > 0.0:
		return false
	hacked_left = hacked_green_seconds
	cooldown_left = hacked_green_seconds + 6.0
	green = true
	_refresh()
	return true


func _refresh() -> void:
	var color := Color(0.2, 1.0, 0.4) if green else Color(1.0, 0.2, 0.2)
	for mat in _lamps:
		mat.albedo_color = color
