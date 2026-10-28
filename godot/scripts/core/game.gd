extends RefCounted
## Finds the GameState autoload by path. Scripts use Game.state() instead of the bare `GameState` name so they
## also compile when run with `godot -s` (headless tests), where autoload names are not defined.


static func state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/GameState")
