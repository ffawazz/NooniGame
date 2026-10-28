extends SceneTree
## Renders the menus and cards (needs a display, e.g. xvfb):  -s res://tests/screenshot_ui.gd -- <out_dir>

func _initialize() -> void:
	await process_frame
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var state := preload("res://scripts/core/game_state.gd").new()
	state.name = "GameState"
	state.test_mode = true
	root.add_child(state)

	var menu = load("res://scenes/main.tscn").instantiate()
	root.add_child(menu)
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out + "/ui_menu.png")
	menu._show("levels")
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/ui_levels.png")
	menu.queue_free()
	await process_frame

	var room = load("res://scenes/level.tscn").instantiate()
	room.test_mode = true
	root.add_child(room)
	await create_timer(0.5).timeout
	room.captions.say("Semba's yowl draws the whole room. Nooni, now!", 30.0)
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out + "/ui_caption.png")
	var pause = preload("res://scripts/ui/pause_menu.gd").new()
	room.add_child(pause)
	pause.setup(room)
	pause.toggle()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/ui_pause.png")
	pause.toggle()
	var result = preload("res://scripts/ui/result_panel.gd").new()
	room.add_child(result)
	result.show_result(true, "MISSION COMPLETE", room.data.story_outro, 83.0, 1, true)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/ui_result.png")
	result.queue_free()
	paused = false
	room.queue_free()

	var card = preload("res://scripts/ui/story_card.gd").new()
	root.add_child(card)
	var data := preload("res://scripts/levels/level_01_living_room.gd").data()
	card.play(data.title, data.story_intro)
	await create_timer(3.5).timeout
	root.get_texture().get_image().save_png(out + "/ui_story.png")
	quit()
