extends SceneTree
## Renders the driving level (needs a display):  -s res://tests/screenshot_drive.gd -- <out_dir>

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var state := preload("res://scripts/core/game_state.gd").new()
	state.name = "GameState"
	state.test_mode = true
	root.add_child(state)
	var Levels := preload("res://scripts/levels/levels.gd")
	var drive = load("res://scenes/drive.tscn").instantiate()
	drive.level_index = Levels.index_of("king_fahd_road")
	drive.test_mode = true
	root.add_child(drive)
	await create_timer(0.5).timeout
	Input.action_press("move_forward")
	await create_timer(3.0).timeout
	root.get_texture().get_image().save_png(out + "/drive_cruise.png")
	drive.distance = 250.0
	drive.lights[0].green = false
	drive.lights[0].hacked_left = 0.0
	await create_timer(2.5).timeout
	root.get_texture().get_image().save_png(out + "/drive_light.png")
	quit()
