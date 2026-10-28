extends RefCounted
## Level 5: The Exam Hall (finale). 24 x 14 m hall of desks. The professor patrols the centre aisle, Yasser and
## Ahmed walk the aisles on either side, and the clock is running: reach seat 42 before the exam begins.
## Desks are cover. Cats, hacks and grapple hooks all help; the stage at the front is a quick way across.

const Kit := preload("res://scripts/levels/level_kit.gd")
const WALL := Color(0.78, 0.7, 0.62)
const WOOD := Color(0.62, 0.45, 0.32)


static func data() -> Dictionary:
	var floor_tiles := {"checker_size": 1.5, "pattern_color": Color(0.6, 0.62, 0.66)}
	var wall_panel := {"wainscot_height": 1.0, "pattern_color": Color(0.3, 0.38, 0.5)}

	var solids: Array = Kit.shell(24, 14, 3.6, Color(0.72, 0.74, 0.78), WALL, floor_tiles, wall_panel)
	var covers: Array = []
	var decor: Array = []

	# Four rows of six desks, leaving a wide centre aisle (z -1.4 .. 1.4) and two side aisles.
	for row_z in [-4.5, -1.8, 1.8, 4.5]:
		for column_x in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0]:
			var tag := "%d_%d" % [int(column_x), int(row_z * 10)]
			solids.append(Kit.furniture("Desk_" + tag, column_x, row_z, 1.6, 0.8, 0.9, WOOD))
			covers.append(Kit.cover_around("Cover_" + tag, column_x, row_z, 1.6, 0.8, 0.5))
			decor.append(Kit.box_decor(Vector3(column_x, 0.93, row_z), Vector3(0.5, 0.04, 0.35), Color(0.95, 0.95, 0.9), 0.0))  # exam paper

	solids.append_array([
		# The front: a stage with the professor's desk, and the finish seat in the corner.
		Kit.solid("Stage", Vector3(-1.0, 0.25, 6.0), Vector3(6.0, 0.5, 2.0), Color(0.55, 0.4, 0.35)),
		Kit.furniture("Seat42Desk", 10.0, 5.2, 1.6, 0.8, 0.9, Color(0.9, 0.7, 0.3)),
		Kit.furniture("Bookcase", -11.5, -5.8, 0.6, 2.4, 2.4, Color(0.5, 0.35, 0.25)),
	])
	decor.append_array([
		Kit.box_decor(Vector3(-1.0, 1.05, 6.4), Vector3(1.6, 0.8, 0.6), Color(0.45, 0.32, 0.25)),  # professor's desk
		Kit.box_decor(Vector3(-1.0, 2.2, 6.95), Vector3(5.0, 1.6, 0.05), Color(0.15, 0.3, 0.2), 0.0),  # blackboard
		{"t": "omni", "pos": Vector3(0.0, 3.0, 0.0), "color": Color(1.0, 0.97, 0.9), "energy": 0.12, "range": 7.0},
	])

	return {
		"id": "exam_hall",
		"title": "Level 5: The Exam Hall",
		"objective": "Reach Seat 42 before the exam begins. Everyone in this room wants to stop her. Including the clock.",
		"time_limit": 150.0,
		"time_up_text": "The bell rang. The papers dropped. Her seat stayed empty.",
		"story_intro": [
			"The Information Systems final. Two hours. Forty questions. One seat: number 42.",
			"The professor patrols the aisle, sharp as a blackboard pointer. Yasser and Ahmed have somehow gotten in through the side doors.",
			"They are not here to cause a scene. They are here to bring her a sandwich. This is somehow worse.",
			"The clock reads 2:30. Nooni adjusts her glasses. Somewhere, a violin begins to play.",
		],
		"story_outro": [
			"She slides into Seat 42 exactly as the bell rings.",
			"Yasser and Ahmed stand at the door, holding a sandwich and a thermos. They have never looked so proud.",
			"Question 1: 'Describe a complex system using the actors involved.' Nooni smiles. She has a lot to say.",
		],
		"hints": {
			"first_smudge": "The pressure is on. Tap R to clear the glasses.",
			"roar": "Semba's yowl pulls the professor and the brothers to the bookcase!",
			"vision": "Detective Vision shows every sightline. The aisles are your friends.",
			"grapple": "The blackboard hook lets you skip the rows. Aim up and click.",
		},
		"environment": {"sky_top": Color(0.35, 0.45, 0.7), "sky_horizon": Color(0.85, 0.8, 0.75), "sun_energy": 0.5},
		"solids": solids,
		"decor": decor,
		"covers": covers,
		"climbables": [
			{"name": "Climb_Bookcase", "pos": Vector3(-10.7, 1.3, -5.8), "size": Vector3(0.9, 2.6, 2.2), "wall": Vector3(-1, 0, 0), "top_y": 2.4, "landing": Vector3(-11.5, 2.45, -5.8)},
		],
		"hackables": [
			{"name": "FireAlarm", "kind": "speaker", "label": "Fire alarm", "pos": Vector3(11.4, 0, -6.5), "seconds": 9.0, "cooldown": 16.0},
			{"name": "HallLights", "kind": "lights", "label": "Hall lights", "pos": Vector3(-11.3, 0, 6.3), "seconds": 12.0, "cooldown": 18.0},
		],
		"anchors": [
			{"name": "Hook_Stage", "pos": Vector3(-1.0, 3.0, 6.9), "landing": Vector3(-1.0, 0.55, 5.4)},
		],
		"spawns": {
			"nooni": {"pos": Vector3(-11.0, 0, 0.0), "yaw": -PI * 0.5},
			"bruce": {"pos": Vector3(-11.0, 0, 1.4), "yaw": -PI * 0.5},
			"semba": {"pos": Vector3(-11.0, 0, -1.4), "yaw": -PI * 0.5},
		},
		"brothers": [
			{
				"name": "Professor", "kind": "professor", "pos": Vector3(-8.0, 0, 0.0), "yaw": -PI * 0.5,
				"route": [Vector3(-8.0, 0, 0.0), Vector3(8.0, 0, 0.0)],
			},
			{
				"name": "Yasser", "kind": "yasser", "pos": Vector3(-10.0, 0, 3.15), "yaw": -PI * 0.5,
				"route": [Vector3(-10.0, 0, 3.15), Vector3(9.0, 0, 3.15)],
			},
			{
				"name": "Ahmed", "kind": "ahmed", "pos": Vector3(9.0, 0, -3.15), "yaw": PI * 0.5,
				"route": [Vector3(9.0, 0, -3.15), Vector3(-10.0, 0, -3.15)],
			},
		],
		"exit": {"pos": Vector3(10.0, 0.0, 3.6), "radius": 1.1, "label": "SEAT 42"},
	}
