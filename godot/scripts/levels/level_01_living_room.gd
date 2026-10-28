extends RefCounted
## Level 1: The Living Room. Teaches switching: Bruce opens the pantry door, Semba lures Yasser away.
## Metres, +X east, +Z south on screen. Positions are the centre of each box.

const WALL := Color(0.93, 0.8, 0.62)


static func data() -> Dictionary:
	var floor_tiles := {"checker_size": 1.0, "pattern_color": Color(0.7, 0.55, 0.42)}
	var wall_panel := {"wainscot_height": 0.9, "pattern_color": Color(0.5, 0.66, 0.66)}

	var decor: Array = [
		{"t": "box", "pos": Vector3(-0.5, 0.011, 0), "size": Vector3(3.2, 0.02, 2.2), "color": Color(0.78, 0.36, 0.34), "outline": 0.0},  # rug
		{"t": "box", "pos": Vector3(-2.9, 0.91, -3.0), "size": Vector3(0.55, 0.22, 0.5), "color": Color(0.98, 0.78, 0.3)},  # cushions
		{"t": "box", "pos": Vector3(-1.1, 0.91, -3.0), "size": Vector3(0.55, 0.22, 0.5), "color": Color(0.35, 0.75, 0.7)},
		{"t": "box", "pos": Vector3(-2.0, 1.55, 4.97), "size": Vector3(2.0, 1.0, 0.05), "color": Color(0.3, 0.2, 0.15), "outline": 0.0},  # picture
		{"t": "box", "pos": Vector3(-2.0, 1.55, 4.945), "size": Vector3(1.8, 0.8, 0.02), "color": Color(0.55, 0.78, 0.95), "outline": 0.0},
		{"t": "box", "pos": Vector3(-5.95, 1.2, 1.6), "size": Vector3(0.05, 2.1, 1.1), "color": Color(0.78, 0.3, 0.48)},  # curtain
		{"t": "cyl", "pos": Vector3(-5.9, 2.3, 1.6), "r": 0.03, "h": 1.4, "color": Color(0.3, 0.22, 0.18), "outline": 0.01, "rot": Vector3(90, 0, 0)},
		{"t": "cyl", "pos": Vector3(-5.4, 0.8, 4.4), "r": 0.04, "h": 1.6, "color": Color(0.2, 0.18, 0.25), "outline": 0.015},  # floor lamp
		{"t": "cyl", "pos": Vector3(-5.4, 1.8, 4.4), "r": 0.32, "h": 0.4, "color": Color(1.0, 0.92, 0.6), "top_r": 0.18},
		{"t": "omni", "pos": Vector3(-5.4, 1.7, 4.4), "color": Color(1.0, 0.85, 0.55), "energy": 0.45, "range": 6.0},
	]
	# Books on the bookshelf's front face.
	var spines := [Color(0.85, 0.3, 0.35), Color(0.3, 0.55, 0.85), Color(0.95, 0.75, 0.25), Color(0.4, 0.75, 0.5), Color(0.7, 0.4, 0.8)]
	for row in 3:
		var shelf_y := 0.3 + row * 0.55
		decor.append({"t": "box", "pos": Vector3(-5.46, shelf_y, 3.2), "size": Vector3(0.08, 0.04, 1.9), "color": Color(0.42, 0.27, 0.18), "outline": 0.0})
		for i in 7:
			decor.append({
				"t": "box", "pos": Vector3(-5.44, shelf_y + 0.2, 2.35 + i * 0.27), "size": Vector3(0.12, 0.34, 0.2),
				"color": spines[(i + row) % spines.size()], "outline": 0.01, "rot": Vector3(0, 0, 4.0 * ((i + row) % 3 - 1)),
			})

	return {
		"id": "living_room",
		"title": "Level 1: The Living Room",
		"objective": "Reach the snack pad in the pantry. Its door opens only while a heavy cat sits on the pressure plate.",
		"story_intro": [
			"Riyadh. 11:47 PM. The living room.",
			"Two brothers. One snack. A pantry sealed by a door that only the heavy can open.",
			"Nooni adjusts her glasses. Somewhere, a violin begins to play. (There is no violin.)",
			"Tab opens the Cat-ical Wheel. Bruce is heavy. Semba is loud. Nooni is... dramatic.",
		],
		"story_outro": [
			"The snack was acquired.",
			"Yasser, still staring at the bookshelf, will never know what happened.",
			"But the night is young, and the garage door is only a few steps away...",
		],
		"hints": {
			"first_smudge": "Her glasses fog under the pressure. A quick tap of R wipes them clean.",
			"door_open": "The door slides open. Don't let Bruce leave the plate!",
			"roar": "Semba's yowl draws the whole room. Nooni, now!",
		},
		"environment": {"sky_top": Color(0.36, 0.52, 0.86), "sky_horizon": Color(0.98, 0.86, 0.74)},
		"solids": [
			{"name": "Floor", "pos": Vector3(0, -0.05, 0), "size": Vector3(12, 0.1, 10), "color": Color(0.84, 0.72, 0.56), "opts": floor_tiles},
			{"name": "Wall_N", "pos": Vector3(0, 1.25, 5.05), "size": Vector3(12.2, 2.5, 0.1), "color": WALL, "opts": wall_panel},
			{"name": "Wall_S", "pos": Vector3(0, 1.25, -5.05), "size": Vector3(12.2, 2.5, 0.1), "color": WALL, "opts": wall_panel},
			{"name": "Wall_E", "pos": Vector3(6.05, 1.25, 0), "size": Vector3(0.1, 2.5, 10), "color": WALL, "opts": wall_panel},
			{"name": "Wall_W", "pos": Vector3(-6.05, 1.25, 0), "size": Vector3(0.1, 2.5, 10), "color": WALL, "opts": wall_panel},
			{"name": "Sofa", "pos": Vector3(-2, 0.4, -3), "size": Vector3(3, 0.8, 1), "color": Color(0.55, 0.38, 0.78)},
			{"name": "Counter", "pos": Vector3(4.5, 0.5, -1), "size": Vector3(1, 1, 3), "color": Color(0.85, 0.55, 0.35)},
			{"name": "CoffeeTable", "pos": Vector3(-0.5, 0.25, 0), "size": Vector3(1.6, 0.5, 0.8), "color": Color(0.5, 0.33, 0.24)},
			{"name": "Bookshelf", "pos": Vector3(-5.75, 1.0, 3.2), "size": Vector3(0.5, 2.0, 2.0), "color": Color(0.62, 0.42, 0.28)},
			{"name": "Pantry_West", "pos": Vector3(3.2, 1.25, 3.75), "size": Vector3(0.15, 2.5, 2.5), "color": WALL, "opts": wall_panel},
			{"name": "Pantry_South_A", "pos": Vector3(3.7, 1.25, 2.5), "size": Vector3(1.0, 2.5, 0.15), "color": WALL, "opts": wall_panel},
			{"name": "Pantry_South_B", "pos": Vector3(5.6, 1.25, 2.5), "size": Vector3(0.8, 2.5, 0.15), "color": WALL, "opts": wall_panel},
			{"name": "Pantry_Lintel", "pos": Vector3(4.7, 2.4, 2.5), "size": Vector3(1.0, 0.2, 0.15), "color": WALL, "opts": wall_panel},
		],
		"decor": decor,
		"covers": [
			{"name": "CoverZone_Sofa", "pos": Vector3(-2, 0.9, -3), "size": Vector3(3.6, 1.8, 2.4)},
			{"name": "CoverZone_Counter", "pos": Vector3(4.5, 0.9, -1), "size": Vector3(2.2, 1.8, 3.6)},
		],
		"climbables": [
			{"name": "Climb_Bookshelf", "pos": Vector3(-5.0, 1.1, 3.2), "size": Vector3(0.9, 2.2, 1.6), "wall": Vector3(-1, 0, 0), "top_y": 2.0, "landing": Vector3(-5.72, 2.05, 3.2)},
			{"name": "Climb_Curtain", "pos": Vector3(-5.4, 1.2, 1.6), "size": Vector3(1.0, 2.4, 1.1), "wall": Vector3(-1, 0, 0), "top_y": 2.3, "landing": Vector3(-5.72, 2.05, 2.6)},
		],
		"doors": [
			{"name": "PantryDoor", "label": "Pantry door", "pos": Vector3(4.7, 1.1, 2.5)},
		],
		"plates": [
			{"name": "PressurePlate", "pos": Vector3(0.5, 0, 3.8), "required": 2.0, "door": "PantryDoor"},
		],
		"spawns": {
			"nooni": {"pos": Vector3(-3.2, 0, -4.3), "yaw": -PI * 0.5},
			"bruce": {"pos": Vector3(-4.4, 0, -4.2), "yaw": -PI * 0.5},
			"semba": {"pos": Vector3(-5.2, 0, -3.5), "yaw": -PI * 0.5},
		},
		"brothers": [
			{
				"name": "Yasser", "kind": "yasser", "pos": Vector3(-3, 0, 1.5), "yaw": -PI * 0.5,
				"route": [Vector3(-3, 0, 1.5), Vector3(2, 0, 1.5), Vector3(2, 0, -1.5), Vector3(-3, 0, -1.5)],
			},
		],
		"exit": {"pos": Vector3(5.0, 0.0, 4.0), "radius": 1.2, "label": "SNACK"},
	}
