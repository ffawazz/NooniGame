extends RefCounted
## Finds the GameState autoload by path. Scripts use Game.state() instead of the bare `GameState` name so they
## also compile when run with `godot -s` (headless tests), where autoload names are not defined.


static func state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/GameState")


## The Audio autoload, or null when it isn't installed (headless tools).
static func audio() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Audio")


static func sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var node := audio()
	if node:
		node.sfx(sound, volume_db, pitch)


static func music(track: String) -> void:
	var node := audio()
	if node:
		node.play_music(track)
