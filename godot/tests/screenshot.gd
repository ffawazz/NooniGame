extends SceneTree
## Renders the room (needs a display, e.g. xvfb) and saves PNGs:  -s res://tests/screenshot.gd -- <out_dir>
func _initialize() -> void:
	await process_frame
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var room = load("res://scenes/main.tscn").instantiate()
	room.test_mode = true
	root.add_child(room)
	await create_timer(1.0).timeout

	var cam := root.get_camera_3d()
	print("gameplay camera at ", cam.global_position, "  nooni at ", room.nooni.global_position)
	root.get_texture().get_image().save_png(out + "/shot_start.png")

	# Overhead view of the whole room.
	var top := Camera3D.new()
	room.add_child(top)
	top.global_position = Vector3(0, 17, 0.1)
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.current = true
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/shot_overhead.png")

	# Stand in Yasser's view for a moment so the cone shows rising awareness.
	room.nooni.global_position = Vector3(0, 0, 1.5)
	await create_timer(0.4).timeout
	root.get_texture().get_image().save_png(out + "/shot_overhead_spotted.png")
	quit()
