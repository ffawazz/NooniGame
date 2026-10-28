extends SceneTree
## Plays the real flow end to end with the real autoloads and scene changes (needs a display, e.g. xvfb):
##   xvfb-run -a godot --path godot --rendering-driver opengl3 -s res://tests/smoke_flow.gd
## Title -> New game -> story card -> level -> win -> result panel -> next level ... -> credits.

const Levels := preload("res://scripts/levels/levels.gd")

var failures := 0


func _check(condition: bool, label: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1


func _press_accept() -> void:
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	Input.parse_input_event(press)


## Press Space until the story card is gone (it pauses the world while it is up).
func _dismiss_cards() -> void:
	for i in 40:
		if not paused:
			return
		_press_accept()
		await create_timer(0.15).timeout


func _scene_name() -> String:
	return current_scene.name if current_scene else "(none)"


func _initialize() -> void:
	_run()


func _run() -> void:
	var state := root.get_node("GameState")
	state.save_path = "user://smoke_save.cfg"  # never touch the real save
	state.unlocked = 1
	state.results = {}
	state.intro_seen_for = -1

	# The title screen.
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.0).timeout
	_check(_scene_name() == "MainMenu", "the game opens on the title screen")
	_check(root.get_node("Audio").current_music() == "music_menu", "with the menu music playing")

	# New game: first level, story card up and the world paused behind it.
	state.new_game()
	await create_timer(1.2).timeout
	_check(_scene_name() == "Level", "New game loads the first level")
	_check(paused, "the story card pauses the world")
	await _dismiss_cards()
	_check(not paused, "pressing Space through the story card starts the level")
	_check(root.get_node("Audio").current_music() == "music_stealth", "the stealth music plays")

	# Play every level: win it, see the result panel, go on.
	for index in Levels.count():
		_check(state.current_level == index, "now on level %d (%s)" % [index + 1, Levels.info(index).id])
		var level = current_scene
		if Levels.info(index).kind == "stealth":
			await _dismiss_cards()
			_check(not paused, "level %d is running" % (index + 1))
			level.nooni.global_position = level.exit_position
		else:
			await _dismiss_cards()
			_check(not paused, "the drive is running")
			level.distance = level.length
		await create_timer(2.2).timeout
		_check(paused and level.find_children("*", "Button", true, false).size() >= 2, "level %d shows its result panel" % (index + 1))
		_check(state.unlocked >= mini(index + 2, Levels.count()), "winning unlocks the next level")
		state.go_next()
		await create_timer(1.2).timeout

	_check(_scene_name() == "Credits", "the credits roll after the last level")
	state.go_menu()
	await create_timer(1.0).timeout
	_check(_scene_name() == "MainMenu", "and any key returns to the title")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://smoke_save.cfg"))
	print("")
	print("SMOKE FLOW PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures)
	quit(1 if failures > 0 else 0)
