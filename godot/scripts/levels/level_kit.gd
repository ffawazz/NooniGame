extends RefCounted
## Shorthand for writing level data: boxes, room shells and common props. All positions are box centres.


static func solid(box_name: String, pos: Vector3, size: Vector3, color: Color, opts := {}) -> Dictionary:
	return {"name": box_name, "pos": pos, "size": size, "color": color, "opts": opts}


## Floor plus four walls around a rectangle centred on the origin (width along X, depth along Z).
static func shell(width: float, depth: float, height: float, floor_color: Color, wall_color: Color, floor_opts := {}, wall_opts := {}) -> Array:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	return [
		solid("Floor", Vector3(0, -0.05, 0), Vector3(width, 0.1, depth), floor_color, floor_opts),
		solid("Wall_N", Vector3(0, height * 0.5, half_d + 0.05), Vector3(width + 0.2, height, 0.1), wall_color, wall_opts),
		solid("Wall_S", Vector3(0, height * 0.5, -half_d - 0.05), Vector3(width + 0.2, height, 0.1), wall_color, wall_opts),
		solid("Wall_E", Vector3(half_w + 0.05, height * 0.5, 0), Vector3(0.1, height, depth), wall_color, wall_opts),
		solid("Wall_W", Vector3(-half_w - 0.05, height * 0.5, 0), Vector3(0.1, height, depth), wall_color, wall_opts),
	]


## A wall along Z at x = `x` from z0 to z1.
static func wall_z(wall_name: String, x: float, z0: float, z1: float, height: float, color: Color, opts := {}, thickness := 0.2) -> Dictionary:
	return solid(wall_name, Vector3(x, height * 0.5, (z0 + z1) * 0.5), Vector3(thickness, height, absf(z1 - z0)), color, opts)


## A wall along X at z = `z` from x0 to x1.
static func wall_x(wall_name: String, z: float, x0: float, x1: float, height: float, color: Color, opts := {}, thickness := 0.2) -> Dictionary:
	return solid(wall_name, Vector3((x0 + x1) * 0.5, height * 0.5, z), Vector3(absf(x1 - x0), height, thickness), color, opts)


## A piece of furniture standing on the floor: pos is its footprint centre; `height` is how tall it is.
static func furniture(item_name: String, x: float, z: float, width: float, depth: float, height: float, color: Color) -> Dictionary:
	return solid(item_name, Vector3(x, height * 0.5, z), Vector3(width, height, depth), color)


## A hiding zone that wraps a piece of furniture with `margin` to spare on every side.
static func cover_around(cover_name: String, x: float, z: float, width: float, depth: float, margin := 0.7, height := 1.8) -> Dictionary:
	return {"name": cover_name, "pos": Vector3(x, height * 0.5, z), "size": Vector3(width + margin * 2.0, height, depth + margin * 2.0)}


static func box_decor(pos: Vector3, size: Vector3, color: Color, outline := 0.02) -> Dictionary:
	return {"t": "box", "pos": pos, "size": size, "color": color, "outline": outline}
