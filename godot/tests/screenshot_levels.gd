extends SceneTree
## Renders an overhead and a gameplay view of each stealth level (needs a display):
##   -s res://tests/screenshot_levels.gd -- <out_dir> [level indices...]

const Levels := preload("res://scripts/levels/levels.gd")


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var state := preload("res://scripts/core/game_state.gd").new()
	state.name = "GameState"
	state.test_mode = true
	root.add_child(state)

	var wanted: Array = []
	for i in range(1, args.size()):
		wanted.append(int(args[i]))
	if wanted.is_empty():
		for i in Levels.count():
			wanted.append(i)

	for index in wanted:
		if Levels.info(index).kind != "stealth":
			continue
		var room = load("res://scenes/level.tscn").instantiate()
		room.level_index = index
		room.test_mode = true
		root.add_child(room)
		await create_timer(0.8).timeout
		root.get_texture().get_image().save_png("%s/level_%d_play.png" % [out, index + 1])

		var bounds := Vector2.ZERO
		for solid in room.data.solids:
			bounds.x = maxf(bounds.x, absf(solid.pos.x) + solid.size.x * 0.5)
			bounds.y = maxf(bounds.y, absf(solid.pos.z) + solid.size.z * 0.5)
		var top := Camera3D.new()
		room.add_child(top)
		top.projection = Camera3D.PROJECTION_ORTHOGONAL
		top.size = maxf(bounds.x * 2.0 * 720.0 / 1280.0, bounds.y * 2.0) * 1.1
		top.global_position = Vector3(0, 40, 0.01)
		top.rotation_degrees = Vector3(-90, 0, 0)
		top.current = true
		await create_timer(0.4).timeout
		root.get_texture().get_image().save_png("%s/level_%d_top.png" % [out, index + 1])
		room.queue_free()
		await process_frame
	quit()
