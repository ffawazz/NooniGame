extends RefCounted
## Level 3: King Fahd Road. Arcade driving in the blue Mazda CX-5, from the house to PNU.


static func data() -> Dictionary:
	return {
		"id": "king_fahd_road",
		"kind": "drive",
		"title": "Level 3: King Fahd Road",
		"objective": "Drive to PNU before the clock runs out. Dodge traffic and hack red lights.",
		"length": 1300.0,
		"time_limit": 110.0,
		"max_speed": 42.0,
		"lights": [330, 660, 990],
		"gap_min": 26.0,
		"gap_max": 55.0,
		"cross_interval": 1.3,
		"crash_penalty": 4.0,
		"time_up_text": "The exam started without her. The Mazda sulked in a parking lot.",
		"story_intro": [
			"King Fahd Road. Eight lanes of destiny, and every driver convinced they have the right of way.",
			"The Mazda's engine hums a single, dramatic note. Nooni grips the wheel like it owes her money.",
			"Three red lights stand between her and PNU. Her phone has a signal. Her laptop has a script.",
			"W to accelerate. A and D to weave. E to hack a light. Space to drift like she means it.",
		],
		"story_outro": [
			"PNU rises ahead, glowing in the sunset like a promise.",
			"Behind her, two very confused brothers stare at an empty garage.",
			"She parks. She breathes. She adjusts her glasses. It begins.",
		],
		"hints": {
			"crash": "Minor contact. Her glasses survive. Her pride does not.",
			"hack": "Light hacked. The cross traffic holds its breath.",
		},
	}
