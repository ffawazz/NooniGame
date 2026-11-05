extends SceneTree
## Renders the touch layout at a phone-shaped window (needs a display):  -s res://tests/screenshot_touch.gd -- <out_dir>

func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	DisplayServer.window_set_size(Vector2i(2160, 960))
	await create_timer(0.5).timeout
	var Levels := preload("res://scripts/levels/levels.gd")

	var room = load("res://scenes/level.tscn").instantiate()
	room.test_mode = true
	room.force_touch = true
	root.add_child(room)
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/touch_level.png")
	room.queue_free()
	await process_frame

	var drive = load("res://scenes/drive.tscn").instantiate()
	drive.level_index = Levels.index_of("king_fahd_road")
	drive.test_mode = true
	drive.force_touch = true
	root.add_child(drive)
	await create_timer(0.8).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/touch_drive.png")
	quit()
