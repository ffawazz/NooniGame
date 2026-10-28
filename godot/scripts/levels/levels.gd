extends RefCounted
## The game's level list, in play order. Each entry points at a data script with `static func data()`.
## "stealth" levels use scenes/level.tscn; "drive" levels use scenes/drive.tscn.

const ORDER := [
	{"id": "living_room", "kind": "stealth", "script": "res://scripts/levels/level_01_living_room.gd"},
]


static func count() -> int:
	return ORDER.size()


static func info(index: int) -> Dictionary:
	return ORDER[clampi(index, 0, ORDER.size() - 1)]


static func data(index: int) -> Dictionary:
	var script: GDScript = load(info(index).script)
	return script.data()


static func scene_for(index: int) -> String:
	return "res://scenes/drive.tscn" if info(index).kind == "drive" else "res://scenes/level.tscn"
