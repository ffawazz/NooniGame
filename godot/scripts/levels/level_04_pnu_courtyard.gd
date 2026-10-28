extends RefCounted
## Level 4: PNU Courtyard. Open-air campus plaza with two security guards and Ahmed, who followed the car's
## GPS. The library lobby (exit) is behind a smart-locked door in the north wall.
## Routes: hack the lock and dash, park Bruce on the plate, or grapple onto the lobby balcony from outside.
## Everything here is 22 wide (x) by 20 deep (z): courtyard z -10..8, library lobby z 8..10.

const Kit := preload("res://scripts/levels/level_kit.gd")
const STONE := Color(0.82, 0.74, 0.6)
const BRICK := Color(0.75, 0.5, 0.4)


static func data() -> Dictionary:
	var paving := {"checker_size": 2.0, "pattern_color": Color(0.7, 0.62, 0.5)}
	var brick_band := {"wainscot_height": 1.0, "pattern_color": Color(0.6, 0.4, 0.34)}

	var solids: Array = Kit.shell(22, 20, 3.4, Color(0.8, 0.72, 0.58), BRICK, paving, brick_band)
	solids.append_array([
		# Library facade at z = 8 with a 1.6 m entrance (x 6.2 .. 7.8) closed by a smart-locked door.
		Kit.wall_x("Facade_W", 8.0, -11.0, 6.2, 3.4, STONE, brick_band),
		Kit.wall_x("Facade_E", 8.0, 7.8, 11.0, 3.4, STONE, brick_band),
		Kit.solid("Facade_Lintel", Vector3(7.0, 3.25, 8.0), Vector3(1.6, 0.3, 0.2), STONE, brick_band),
		# Courtyard furniture: fountain, planters, benches, notice board.
		Kit.furniture("Fountain", 0.0, 0.0, 3.4, 3.4, 1.0, Color(0.55, 0.7, 0.8)),
		Kit.furniture("Planter_A", -6.5, -3.5, 2.6, 1.0, 0.9, Color(0.4, 0.6, 0.35)),
		Kit.furniture("Planter_B", -6.5, 3.5, 2.6, 1.0, 0.9, Color(0.4, 0.6, 0.35)),
		Kit.furniture("Planter_C", 6.0, -4.5, 2.6, 1.0, 0.9, Color(0.4, 0.6, 0.35)),
		Kit.furniture("Planter_D", 3.5, 4.5, 2.6, 1.0, 0.9, Color(0.4, 0.6, 0.35)),
		Kit.furniture("Bench_A", -2.5, -7.0, 2.4, 0.7, 0.7, Color(0.55, 0.4, 0.3)),
		Kit.furniture("Bench_B", 3.0, -7.0, 2.4, 0.7, 0.7, Color(0.55, 0.4, 0.3)),
		Kit.furniture("NoticeBoard", -9.4, 0.0, 0.5, 2.6, 2.4, Color(0.5, 0.35, 0.25)),
		# Library lobby: a balcony inside the entrance (reachable by grapple from the courtyard).
		Kit.solid("Balcony", Vector3(3.0, 2.6, 9.0), Vector3(4.0, 0.2, 1.6), STONE),
		Kit.furniture("LobbyDesk", -6.0, 9.2, 3.0, 1.0, 1.0, Color(0.6, 0.45, 0.35)),
	])

	var decor: Array = [
		Kit.box_decor(Vector3(0.0, 1.05, 0.0), Vector3(1.0, 0.7, 1.0), Color(0.7, 0.85, 0.95)),  # fountain spout
		Kit.box_decor(Vector3(-9.15, 1.4, 0.0), Vector3(0.05, 1.6, 2.2), Color(0.95, 0.9, 0.7), 0.01),  # notices
		Kit.box_decor(Vector3(7.0, 0.012, 8.9), Vector3(3.0, 0.02, 1.8), Color(0.7, 0.3, 0.3), 0.0),  # lobby rug
		Kit.box_decor(Vector3(0.0, 3.0, 7.85), Vector3(6.0, 0.5, 0.05), Color(0.2, 0.3, 0.55), 0.0),  # library sign board
		{"t": "sphere", "pos": Vector3(-6.5, 1.25, -3.5), "r": 0.5, "color": Color(0.3, 0.65, 0.3)},  # shrubs
		{"t": "sphere", "pos": Vector3(-6.5, 1.25, 3.5), "r": 0.5, "color": Color(0.3, 0.65, 0.3)},
		{"t": "sphere", "pos": Vector3(6.0, 1.25, -4.5), "r": 0.5, "color": Color(0.3, 0.65, 0.3)},
		{"t": "sphere", "pos": Vector3(3.5, 1.25, 4.5), "r": 0.5, "color": Color(0.3, 0.65, 0.3)},
	]

	return {
		"id": "pnu_courtyard",
		"title": "Level 4: PNU Courtyard",
		"objective": "Reach the library lobby. The door is smart-locked; hack it, weigh down the plate, or grapple over.",
		"story_intro": [
			"Princess Nourah University. Sunlight, sandstone, and the faint scent of cardamom coffee.",
			"Somewhere behind her, two brothers are tracking a blue Mazda through an app called 'Find My Car'.",
			"Security patrols the courtyard. They have never once been surprised. They have never once been awake before noon.",
			"The library lobby is forty paces north. The exam hall lies beyond it.",
		],
		"story_outro": [
			"The lobby's cool air greets her like an old friend.",
			"Behind her, the guards resume their patrol, unaware that history just walked past.",
			"One more hallway. One more room. One final exam.",
		],
		"hints": {
			"first_smudge": "The guards' stares fog her glasses. Tap R.",
			"door_open": "The library door is open. Keep Bruce on the plate!",
			"roar": "The yowl draws the guards and Ahmed to the notice board.",
			"vision": "The campus is full of smart devices. Detective Vision shows which ones to hack.",
			"grapple": "A hook above the library door! The balcony inside is a way over the lock.",
		},
		"environment": {"sky_top": Color(0.3, 0.55, 0.95), "sky_horizon": Color(1.0, 0.92, 0.75), "sun_energy": 0.7},
		"solids": solids,
		"decor": decor,
		"covers": [
			Kit.cover_around("Cover_Fountain", 0.0, 0.0, 3.4, 3.4, 0.6),
			Kit.cover_around("Cover_PlanterA", -6.5, -3.5, 2.6, 1.0),
			Kit.cover_around("Cover_PlanterB", -6.5, 3.5, 2.6, 1.0),
			Kit.cover_around("Cover_PlanterC", 6.0, -4.5, 2.6, 1.0),
			Kit.cover_around("Cover_PlanterD", 3.5, 4.5, 2.6, 1.0),
			Kit.cover_around("Cover_BenchA", -2.5, -7.0, 2.4, 0.7),
			Kit.cover_around("Cover_BenchB", 3.0, -7.0, 2.4, 0.7),
		],
		"climbables": [
			{"name": "Climb_NoticeBoard", "pos": Vector3(-8.7, 1.3, 0.0), "size": Vector3(0.9, 2.6, 2.0), "wall": Vector3(-1, 0, 0), "top_y": 2.4, "landing": Vector3(-9.4, 2.45, 0.0)},
		],
		"hackables": [
			{"name": "LibraryLock", "kind": "lock", "label": "Library lock", "pos": Vector3(5.7, 0, 7.8), "yaw": 0.0, "door": "LibraryDoor", "seconds": 14.0, "cooldown": 18.0},
			{"name": "CampusSpeaker", "kind": "speaker", "label": "Campus speaker", "pos": Vector3(9.5, 0, -7.5), "seconds": 9.0, "cooldown": 14.0},
			{"name": "SecurityLight", "kind": "lights", "label": "Security light", "pos": Vector3(-3.5, 0, 6.0), "seconds": 10.0},
		],
		"anchors": [
			{"name": "Hook_Balcony", "pos": Vector3(3.0, 3.3, 7.9), "landing": Vector3(3.0, 2.7, 8.8)},
		],
		"doors": [
			{"name": "LibraryDoor", "label": "Library door", "pos": Vector3(7.0, 1.7, 8.0), "size": Vector3(1.6, 3.4, 0.2), "open_offset": Vector3(0, 3.5, 0)},
		],
		"plates": [
			{"name": "GatePlate", "pos": Vector3(-8.0, 0, 6.0), "required": 2.0, "door": "LibraryDoor"},
		],
		"spawns": {
			"nooni": {"pos": Vector3(0.0, 0, -9.0), "yaw": PI},
			"bruce": {"pos": Vector3(-1.4, 0, -9.0), "yaw": PI},
			"semba": {"pos": Vector3(1.4, 0, -9.0), "yaw": PI},
		},
		"brothers": [
			{
				"name": "Guard Saad", "kind": "guard", "pos": Vector3(-4.5, 0, 3.0), "yaw": 0.0,
				"route": [Vector3(-4.5, 0, 3.0), Vector3(-4.5, 0, -3.5), Vector3(-1.0, 0, -5.0), Vector3(-4.5, 0, -3.5)],
			},
			{
				"name": "Guard Faisal", "kind": "guard", "pos": Vector3(4.5, 0, 1.5), "yaw": 0.0,
				"route": [Vector3(4.5, 0, 1.5), Vector3(8.5, 0, 1.5), Vector3(8.5, 0, 6.0), Vector3(4.5, 0, 6.0)],
			},
			{
				"name": "Ahmed", "kind": "ahmed", "pos": Vector3(9.0, 0, -2.0), "yaw": 0.0,
				"route": [Vector3(9.0, 0, -2.0), Vector3(2.5, 0, -2.0), Vector3(2.5, 0, -5.0), Vector3(9.0, 0, -5.0)],
			},
		],
		"exit": {"pos": Vector3(7.0, 0.0, 9.0), "radius": 1.1, "label": "LIBRARY"},
	}
