extends CanvasLayer
## End-of-level panel: win (story outro, time, tries, next level) or lose (try again). Pauses the world behind it.

const Game := preload("res://scripts/core/game.gd")
const MenuKit := preload("res://scripts/ui/menu_kit.gd")


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_result(won: bool, title: String, lines: Array, seconds: float, attempts: int, has_next: bool) -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := MenuKit.panel()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(MenuKit.label(title, 44, MenuKit.GOLD if won else Color(1.0, 0.45, 0.45)))

	for line in lines:
		var text := MenuKit.label(line, 22, Color(1.0, 0.95, 0.85))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(620, 0)
		box.add_child(text)

	if won:
		box.add_child(MenuKit.label("Time %s   |   Tries %d" % [MenuKit.format_time(seconds), attempts + 1], 20, Color(0.8, 0.85, 1.0)))
		box.add_child(MenuKit.button("Next level" if has_next else "Finish the game", func(): Game.state().go_next()))
		box.add_child(MenuKit.button("Replay level", func(): Game.state().restart_level()))
	else:
		box.add_child(MenuKit.button("Try again", func(): Game.state().restart_level()))
	box.add_child(MenuKit.button("Main menu", func(): Game.state().go_menu()))
