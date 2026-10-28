extends RefCounted
## Pure vision-cone maths, kept separate so it can be unit tested.


## True when `point` is within `view_range` of `eye` and inside a cone of total width `full_angle_deg`.
static func in_cone(eye: Vector3, forward: Vector3, point: Vector3, view_range: float, full_angle_deg: float) -> bool:
	var to := point - eye
	var sq := to.length_squared()
	if sq > view_range * view_range:
		return false
	if sq < 0.000001:
		return true
	return rad_to_deg(forward.angle_to(to)) <= full_angle_deg * 0.5
