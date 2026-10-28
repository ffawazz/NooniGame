extends RefCounted
## Builds a cel-shaded car from boxes. Forward is -Z. Used for the player's Mazda CX-5 and for traffic.

const Toon := preload("res://scripts/core/toon.gd")


static func build(parent: Node3D, body_color: Color, hero := false) -> void:
	Toon.box(parent, Vector3(1.9, 0.7, 4.3), Vector3(0, 0.55, 0), body_color)
	Toon.box(parent, Vector3(1.7, 0.6, 2.3), Vector3(0, 1.12, 0.25), body_color.darkened(0.2))
	Toon.box(parent, Vector3(1.72, 0.4, 2.1), Vector3(0, 1.15, 0.25), Color(0.55, 0.8, 0.95), 0.0)  # glass
	for x in [-0.95, 0.95]:
		for z in [-1.4, 1.4]:
			var wheel := Toon.cylinder(parent, 0.34, 0.25, Vector3(x, 0.34, z), Color(0.1, 0.1, 0.12), 0.02)
			wheel.rotation_degrees = Vector3(0, 0, 90)
	# Head and tail lights.
	for x in [-0.6, 0.6]:
		Toon.box(parent, Vector3(0.3, 0.15, 0.06), Vector3(x, 0.65, -2.17), Color(1.0, 0.95, 0.7), 0.0)
		Toon.box(parent, Vector3(0.3, 0.15, 0.06), Vector3(x, 0.65, 2.17), Color(0.9, 0.15, 0.15), 0.0)
	if hero:
		# A tiny cape on the Mazda's roof rack, because of course.
		var cape := Toon.box(parent, Vector3(0.6, 0.04, 0.9), Vector3(0, 1.5, 0.9), Color(0.16, 0.17, 0.32), 0.015)
		cape.rotation_degrees = Vector3(12, 0, 0)
