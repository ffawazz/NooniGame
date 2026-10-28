extends RefCounted
## Level 2: Kitchen and Garage. Two brothers. Reach the Mazda in the garage.
## West half = kitchen (Yasser), centre = hall (Ahmed), east end = garage behind a smart-locked door.
## Three ways in: hack the smart lock (Detective Vision) and dash, park Bruce on the plate, or lure the
## brothers away with Semba's roar / the smart speaker and walk through.

const Kit := preload("res://scripts/levels/level_kit.gd")
const WALL := Color(0.82, 0.74, 0.64)
const H := 3.0


static func data() -> Dictionary:
	var floor_tiles := {"checker_size": 1.0, "pattern_color": Color(0.56, 0.6, 0.68)}
	var wall_panel := {"wainscot_height": 0.9, "pattern_color": Color(0.85, 0.6, 0.55)}

	var solids: Array = Kit.shell(18, 10, H, Color(0.7, 0.74, 0.82), WALL, floor_tiles, wall_panel)
	solids.append_array([
		# Kitchen divider with a wide doorway (z -1.5 .. 1.5) into the hall.
		Kit.wall_z("Divider_S", -0.1, -5.0, -1.5, H, WALL, wall_panel),
		Kit.wall_z("Divider_N", -0.1, 1.5, 5.0, H, WALL, wall_panel),
		# Garage wall at x = 5 with a door gap (z -1 .. 1) closed by the smart-locked door.
		Kit.wall_z("Garage_S", 5.0, -5.0, -1.0, H, WALL, wall_panel),
		Kit.wall_z("Garage_N", 5.0, 1.0, 5.0, H, WALL, wall_panel),
		Kit.solid("Garage_Lintel", Vector3(5.0, 2.8, 0.0), Vector3(0.2, 0.4, 2.0), WALL, wall_panel),
		# Kitchen.
		Kit.furniture("Island", -5.0, 0.0, 3.0, 1.2, 1.0, Color(0.85, 0.7, 0.5)),
		Kit.furniture("KitchenCounter", -6.0, 4.4, 6.0, 1.0, 1.0, Color(0.7, 0.55, 0.4)),
		Kit.furniture("Fridge", -8.4, -3.2, 1.0, 1.0, 2.2, Color(0.8, 0.85, 0.9)),
		Kit.furniture("DiningTable", -3.0, -3.2, 2.2, 1.2, 0.8, Color(0.55, 0.38, 0.28)),
		# Hall.
		Kit.furniture("ShoeBench", 2.5, -4.2, 2.5, 0.8, 0.8, Color(0.5, 0.4, 0.6)),
		Kit.furniture("ConsoleTable", 4.2, 4.1, 1.4, 0.8, 0.9, Color(0.6, 0.45, 0.3)),
		Kit.furniture("TallCabinet", 1.0, 4.4, 1.0, 1.0, 2.0, Color(0.55, 0.4, 0.3)),
		# Garage.
		Kit.furniture("Workbench", 8.4, 4.2, 1.2, 1.2, 1.0, Color(0.5, 0.5, 0.55)),
		Kit.furniture("Toolbox", 8.4, -3.6, 1.0, 1.0, 0.8, Color(0.8, 0.3, 0.3)),
		Kit.furniture("Mazda", 7.6, 0.0, 1.9, 3.6, 0.9, Color(0.2, 0.4, 0.85)),
	])

	var decor: Array = [
		Kit.box_decor(Vector3(-5.0, 0.011, 0.0), Vector3(3.6, 0.02, 2.0), Color(0.45, 0.65, 0.75), 0.0),  # rug under the island
		# The Mazda CX-5: a blue body, cabin and wheels. Visual only, so Nooni walks around it.
		Kit.box_decor(Vector3(7.6, 1.15, -0.2), Vector3(1.7, 0.5, 2.0), Color(0.15, 0.3, 0.7)),
		Kit.box_decor(Vector3(7.6, 1.17, -0.2), Vector3(1.72, 0.3, 1.8), Color(0.55, 0.8, 0.95), 0.0),
		{"t": "cyl", "pos": Vector3(6.6, 0.3, 1.1), "r": 0.3, "h": 0.25, "color": Color(0.1, 0.1, 0.12), "rot": Vector3(0, 0, 90)},
		{"t": "cyl", "pos": Vector3(6.6, 0.3, -1.1), "r": 0.3, "h": 0.25, "color": Color(0.1, 0.1, 0.12), "rot": Vector3(0, 0, 90)},
		{"t": "cyl", "pos": Vector3(8.6, 0.3, 1.1), "r": 0.3, "h": 0.25, "color": Color(0.1, 0.1, 0.12), "rot": Vector3(0, 0, 90)},
		{"t": "cyl", "pos": Vector3(8.6, 0.3, -1.1), "r": 0.3, "h": 0.25, "color": Color(0.1, 0.1, 0.12), "rot": Vector3(0, 0, 90)},
		Kit.box_decor(Vector3(-3.0, 0.82, -3.2), Vector3(0.5, 0.06, 0.5), Color(0.95, 0.85, 0.4), 0.0),  # fruit bowl
	]

	return {
		"id": "kitchen_garage",
		"title": "Level 2: Kitchen and Garage",
		"objective": "Reach the Mazda in the garage. The door is smart-locked: hack the lock, or park a heavy cat on the plate.",
		"time_limit": 0.0,
		"story_intro": [
			"The keys are in her hand. The Mazda sleeps in the garage, forty metres of tile away.",
			"Yasser guards the kitchen. Ahmed, sharper-eyed and far less forgiving, prowls the hall.",
			"The garage door is smart-locked. Naturally. Everything in this house is smart except the people.",
			"Nooni has seen this movie. She knows how it ends. She has also read the whole wiki.",
		],
		"story_outro": [
			"The Mazda's engine turns over like a dramatic gasp.",
			"Behind her, two brothers finally notice the open garage door.",
			"Ahead lies King Fahd Road, and traffic that has never forgiven anyone.",
		],
		"hints": {
			"first_smudge": "Her glasses fog under the pressure. Tap R to wipe them.",
			"door_open": "The garage door is open. Don't let Bruce leave the plate!",
			"roar": "Semba's yowl pulls both brothers to him. The way is clear!",
			"vision": "The smart lock glows in Detective Vision. Press E near it to hack it. The door stays open for a while.",
			"grapple": "Grapple hooks line the kitchen. High places give you a better view.",
		},
		"environment": {"sky_top": Color(0.4, 0.55, 0.85), "sky_horizon": Color(0.98, 0.9, 0.78)},
		"solids": solids,
		"decor": decor,
		"covers": [
			Kit.cover_around("Cover_Island", -5.0, 0.0, 3.0, 1.2),
			Kit.cover_around("Cover_Counter", -6.0, 4.4, 6.0, 1.0, 0.6),
			Kit.cover_around("Cover_Table", -3.0, -3.2, 2.2, 1.2),
			Kit.cover_around("Cover_ShoeBench", 2.5, -4.2, 2.5, 0.8),
			Kit.cover_around("Cover_Console", 4.2, 4.1, 1.4, 0.8, 0.6),
			Kit.cover_around("Cover_Workbench", 8.4, 4.2, 1.2, 1.2, 0.6),
		],
		"climbables": [
			{"name": "Climb_Cabinet", "pos": Vector3(1.0, 1.1, 3.55), "size": Vector3(1.2, 2.2, 0.9), "wall": Vector3(0, 0, 1), "top_y": 2.0, "landing": Vector3(1.0, 2.05, 4.4)},
			{"name": "Climb_Fridge", "pos": Vector3(-7.7, 1.2, -3.2), "size": Vector3(0.9, 2.4, 1.2), "wall": Vector3(-1, 0, 0), "top_y": 2.2, "landing": Vector3(-8.4, 2.25, -3.2)},
		],
		"hackables": [
			{"name": "SmartLock", "kind": "lock", "label": "Smart lock", "pos": Vector3(4.55, 0, 2.0), "yaw": PI * 0.5, "door": "GarageDoor", "seconds": 14.0, "cooldown": 18.0},
			{"name": "SmartSpeaker", "kind": "speaker", "label": "Smart speaker", "pos": Vector3(-8.2, 1.0, 4.4), "seconds": 8.0, "cooldown": 14.0},
			{"name": "KitchenLamp", "kind": "lights", "label": "Smart light", "pos": Vector3(-1.0, 0, 4.4), "seconds": 10.0},
		],
		"anchors": [
			{"name": "Hook_Fridge", "pos": Vector3(-8.5, 2.9, -2.4), "landing": Vector3(-8.4, 2.25, -3.2)},
			{"name": "Hook_Cabinet", "pos": Vector3(1.0, 2.7, 4.95), "landing": Vector3(1.0, 2.05, 4.4)},
		],
		"doors": [
			{"name": "GarageDoor", "label": "Garage door", "pos": Vector3(5.0, 1.1, 0.0), "size": Vector3(0.2, 2.2, 2.0), "open_offset": Vector3(0, 2.3, 0)},
		],
		"plates": [
			{"name": "HallPlate", "pos": Vector3(3.2, 0, -3.4), "required": 2.0, "door": "GarageDoor"},
		],
		"spawns": {
			"nooni": {"pos": Vector3(-6.0, 0, -4.2), "yaw": -PI * 0.5},
			"bruce": {"pos": Vector3(-6.9, 0, -3.0), "yaw": -PI * 0.5},
			"semba": {"pos": Vector3(-7.3, 0, -4.4), "yaw": -PI * 0.5},
		},
		"brothers": [
			{
				"name": "Yasser", "kind": "yasser", "pos": Vector3(-7.0, 0, 3.0), "yaw": -PI * 0.5,
				"route": [Vector3(-7, 0, 2.6), Vector3(-2, 0, 2.6), Vector3(-2, 0, -1.2), Vector3(-7, 0, -1.2)],
			},
			{
				"name": "Ahmed", "kind": "ahmed", "pos": Vector3(1.5, 0, 3.0), "yaw": -PI * 0.5,
				"route": [Vector3(1.5, 0, 3.0), Vector3(3.8, 0, 3.0), Vector3(3.8, 0, -3.0), Vector3(1.5, 0, -3.0)],
			},
		],
		"exit": {"pos": Vector3(7.0, 0.0, 3.2), "radius": 1.2, "label": "MAZDA"},
	}
