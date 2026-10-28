extends RefCounted
## Pure maths for the Cat-ical Wheel, kept separate so it can be unit tested.


## Maps a pointer offset from the wheel centre (screen pixels, +Y down) to a slice index, or -1 inside the
## dead zone. Slice 0 is centred at 12 o'clock and slices run clockwise.
static func select_slice(offset: Vector2, slice_count: int, dead_zone: float) -> int:
	if slice_count <= 0 or offset.length_squared() < dead_zone * dead_zone:
		return -1
	var angle := rad_to_deg(atan2(offset.x, -offset.y))  # clockwise from up
	if angle < 0.0:
		angle += 360.0
	var size := 360.0 / slice_count
	return int(floor(fposmod(angle + size * 0.5, 360.0) / size))
