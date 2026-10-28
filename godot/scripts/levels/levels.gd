extends RefCounted
## The game's level list, in play order. Each entry points at a data script with `static func data()`.
## "stealth" levels use scenes/level.tscn; "drive" levels use scenes/drive.tscn.

const ORDER := [
	{"id": "living_room", "kind": "stealth", "script": "res://scripts/levels/level_01_living_room.gd"},
	{"id": "kitchen_garage", "kind": "stealth", "script": "res://scripts/levels/level_02_kitchen_garage.gd"},
	{"id": "king_fahd_road", "kind": "drive", "script": "res://scripts/levels/level_03_king_fahd_road.gd"},
	{"id": "pnu_courtyard", "kind": "stealth", "script": "res://scripts/levels/level_04_pnu_courtyard.gd"},
	{"id": "exam_hall", "kind": "stealth", "script": "res://scripts/levels/level_05_exam_hall.gd"},
]


static func count() -> int:
	return ORDER.size()


## Position of a level in play order, by id (-1 if there is none).
static func index_of(level_id: String) -> int:
	for i in ORDER.size():
		if ORDER[i].id == level_id:
			return i
	return -1


static func info(index: int) -> Dictionary:
	return ORDER[clampi(index, 0, ORDER.size() - 1)]


static func data(index: int) -> Dictionary:
	var script: GDScript = load(info(index).script)
	return script.data()


static func scene_for(index: int) -> String:
	return "res://scenes/drive.tscn" if info(index).kind == "drive" else "res://scenes/level.tscn"
