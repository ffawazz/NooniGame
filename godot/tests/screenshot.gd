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

	# Close-ups of both characters, from the front.
	var close := Camera3D.new()
	room.add_child(close)
	close.current = true
	room.yasser.hold_position = true
	_closeup(close, room.nooni, 3.2, 1.0)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/shot_nooni.png")
	room.nooni.set_crouching_instant(true)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/shot_nooni_crouched.png")
	room.nooni.set_crouching_instant(false)
	_closeup(close, room.yasser, 3.6, 1.0)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/shot_yasser.png")
	close.queue_free()

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


## Put `cam` in front of `who` (they face -Z locally), looking at them.
func _closeup(cam: Camera3D, who: Node3D, distance: float, height: float) -> void:
	var forward := -who.global_transform.basis.z
	cam.global_position = who.global_position + forward * distance + Vector3.UP * (height + 0.4)
	cam.look_at(who.global_position + Vector3.UP * height, Vector3.UP)
