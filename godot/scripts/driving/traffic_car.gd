extends Node3D
## A car on King Fahd Road. Moves with a fixed world velocity; the drive script checks it against the player.

const CarModel := preload("res://scripts/driving/car_model.gd")

## World velocity in m/s. Forward traffic uses -Z; cross traffic uses +/-X.
var velocity := Vector3.ZERO
## Half extents on X and Z (a cross-traffic car is turned 90 degrees, so these are swapped for it).
var half_size := Vector2(0.95, 2.15)
var cross := false
var color := Color.WHITE
var hit := false


func _ready() -> void:
	var visual := Node3D.new()
	add_child(visual)
	CarModel.build(visual, color)
	if cross:
		visual.rotation.y = PI * 0.5
		half_size = Vector2(2.15, 0.95)


func _process(delta: float) -> void:
	global_position += velocity * delta
