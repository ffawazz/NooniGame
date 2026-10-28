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
	# Bruce, standing and then flopped for a Bat-Nap.
	room.bruce.global_position = Vector3(-4.4, 0, -2.0)
	room.bruce.rotation.y = 0.0
	_closeup(close, room.bruce, 2.6, 0.5)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/shot_bruce.png")
	room.bruce.start_nap()
	await create_timer(0.8).timeout
	root.get_texture().get_image().save_png(out + "/shot_bruce_nap.png")
	room.bruce.state = room.bruce.State.NORMAL
	close.queue_free()
	room.nooni.get_camera().current = true

	# Semba close-up, then roaring from the bookshelf with Yasser drawn toward him.
	var cam2 := Camera3D.new()
	room.add_child(cam2)
	cam2.current = true
	room.semba.global_position = Vector3(1.5, 0, -3.5)
	room.semba.rotation.y = -PI * 0.5
	_closeup(cam2, room.semba, 2.4, 0.4)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/shot_semba.png")

	room.semba.global_position = Vector3(-5.72, 2.05, 3.2)
	room.semba.rotation.y = -PI * 0.5
	room.yasser.global_position = Vector3(-2.0, 0, 1.0)
	room.yasser.rotation.y = PI
	await create_timer(0.3).timeout
	room.semba.try_roar()
	cam2.global_position = Vector3(-2.2, 3.2, 4.2)
	cam2.look_at(Vector3(-5.2, 1.6, 2.8), Vector3.UP)
	await create_timer(0.5).timeout
	root.get_texture().get_image().save_png(out + "/shot_semba_roar.png")
	await create_timer(1.0).timeout
	cam2.global_position = Vector3(-1.5, 3.4, 5.2)
	cam2.look_at(Vector3(-4.2, 0.5, 2.6), Vector3.UP)
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out + "/shot_yasser_lured.png")
	cam2.queue_free()
	room.nooni.get_camera().current = true
	room.semba.global_position = Vector3(-5.2, 0, -3.5)
	await create_timer(0.3).timeout

	# The Cat-ical Wheel, hovering Bruce, from Nooni's camera.
	room.switcher.open_wheel()
	room.switcher.hover_offset(Vector2(87, 50))
	await create_timer(0.3, true, false, true).timeout
	root.get_texture().get_image().save_png(out + "/shot_wheel.png")
	room.switcher.close_wheel(false)
	await create_timer(0.3).timeout

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

	# Bruce on the plate: the pantry door slides open.
	room.nooni.global_position = Vector3(-3.2, 0, -4.3)
	room.bruce.global_position = room.plate.global_position
	await create_timer(1.2).timeout
	root.get_texture().get_image().save_png(out + "/shot_overhead_door_open.png")
	quit()


## Put `cam` in front of `who` (they face -Z locally), looking at them.
func _closeup(cam: Camera3D, who: Node3D, distance: float, height: float) -> void:
	var forward := -who.global_transform.basis.z
	cam.global_position = who.global_position + forward * distance + Vector3.UP * (height + 0.4)
	cam.look_at(who.global_position + Vector3.UP * height, Vector3.UP)
