extends SceneTree
## Headless checks:  godot --headless --path godot -s res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.

const VisionMath := preload("res://scripts/ai/vision_math.gd")
const WheelMath := preload("res://scripts/ui/wheel_math.gd")
const RoomScene := preload("res://scenes/main.tscn")

var failures := 0


func _initialize() -> void:
	# Nodes added to the root during _initialize don't get _ready until the first frame.
	await process_frame
	_run()


func _run() -> void:
	_test_vision_math()

	# Same spot in clear view of Yasser; only Nooni's stance differs.
	# Yasser at (-2,0,1) faces -Z; Nooni at (-2,0,-2.2) is inside the sofa cover zone.
	await _scenario("standing in clear view is caught", Vector3(-2, 0, 1), 0.0, Vector3(-2, 0, -2.2), false, true)
	await _scenario("crouched inside cover is never seen", Vector3(-2, 0, 1), 0.0, Vector3(-2, 0, -2.2), true, false)

	# Yasser at (-5,0,1.5) faces +X; Nooni 6 m ahead in the open (no cover): standing range 9, crouched range 4.5.
	await _scenario("standing at 6 m is caught", Vector3(-5, 0, 1.5), -PI * 0.5, Vector3(1, 0, 1.5), false, true)
	await _scenario("crouched in the open at 6 m is not seen", Vector3(-5, 0, 1.5), -PI * 0.5, Vector3(1, 0, 1.5), true, false)

	# Behind Yasser: outside the cone.
	await _scenario("standing behind him is not seen", Vector3(-5, 0, 1.5), -PI * 0.5, Vector3(-5.8, 0, 1.5), false, false)

	await _test_patrol()
	await _test_nooni_movement()
	await _test_glimpse_then_investigate()
	await _test_arrow_keys()
	_test_wheel_math()
	await _test_pressure_plate()
	await _test_switching()
	await _test_wheel_flow()
	await _test_bat_nap()
	await _test_semba_climbing()
	await _test_mighty_roar()
	await _test_win_through_door()

	print("")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		failures += 1


func _test_vision_math() -> void:
	var eye := Vector3.ZERO
	var fwd := Vector3(0, 0, -1)
	_check(VisionMath.in_cone(eye, fwd, Vector3(0, 0, -5), 9.0, 90.0), "point ahead is in the cone")
	_check(VisionMath.in_cone(eye, fwd, Vector3(4, 0, -5), 9.0, 90.0), "point inside the half angle is in the cone")
	_check(not VisionMath.in_cone(eye, fwd, Vector3(5, 0, -4), 9.0, 90.0), "point outside the half angle is not")
	_check(not VisionMath.in_cone(eye, fwd, Vector3(0, 0, 2), 9.0, 90.0), "point behind is not")
	_check(not VisionMath.in_cone(eye, fwd, Vector3(0, 0, -10), 9.0, 90.0), "point beyond range is not")
	_check(not VisionMath.in_cone(eye, fwd, Vector3(0, 0, -6), 4.5, 90.0), "reduced range hides a crouched target")


func _scenario(label: String, yasser_pos: Vector3, yasser_yaw: float, nooni_pos: Vector3, crouch: bool, expect_caught: bool) -> void:
	var room := RoomScene.instantiate()
	room.test_mode = true
	root.add_child(room)
	await process_frame

	if room.yasser == null or room.nooni == null:
		_check(false, label + " (room did not build)")
		room.queue_free()
		return

	room.yasser.hold_position = true
	room.yasser.global_position = yasser_pos
	room.yasser.rotation.y = yasser_yaw
	room.nooni.global_position = nooni_pos
	room.nooni.set_crouching_instant(crouch)

	await create_timer(2.5).timeout
	_check(room.yasser.is_caught() == expect_caught, label)

	room.queue_free()
	await process_frame


func _test_patrol() -> void:
	var room := RoomScene.instantiate()
	room.test_mode = true
	root.add_child(room)
	await process_frame
	# Park Nooni where Yasser can't see her (crouched in the sofa's cover) so he just patrols.
	room.nooni.global_position = Vector3(-2, 0, -3.9)
	room.nooni.set_crouching_instant(true)

	var start: Vector3 = room.yasser.global_position
	var farthest := 0.0
	var visited_east := false
	for i in range(14):
		await create_timer(0.5).timeout
		var p: Vector3 = room.yasser.global_position
		farthest = maxf(farthest, p.distance_to(start))
		if p.x > 1.0:
			visited_east = true
	_check(farthest > 3.0, "Yasser walks away from his start along the navmesh (moved %.1f m)" % farthest)
	_check(visited_east, "Yasser reaches the east end of his patrol route")
	_check(not room.yasser.is_caught(), "patrolling Yasser does not catch a hidden Nooni")
	room.queue_free()
	await process_frame


func _test_nooni_movement() -> void:
	var room := RoomScene.instantiate()
	room.test_mode = true
	root.add_child(room)
	await process_frame
	room.yasser.hold_position = true
	room.yasser.global_position = Vector3(5, 0, 4.5)  # far away, out of the way

	var start: Vector3 = room.nooni.global_position
	Input.action_press("move_forward")
	await create_timer(1.0).timeout
	Input.action_release("move_forward")
	var walked: float = room.nooni.global_position.distance_to(start)
	_check(walked > 2.0 and walked < 5.0, "Nooni walks forward ~3.5 m/s (moved %.1f m in 1 s)" % walked)

	Input.action_press("crouch")
	await create_timer(0.2).timeout
	Input.action_release("crouch")
	await create_timer(0.5).timeout
	_check(room.nooni.crouching, "crouch key toggles crouch on")
	_check(absf(room.nooni.current_height - room.nooni.crouch_height) < 0.01, "capsule shrinks to crouch height")

	Input.action_press("crouch")
	await create_timer(0.2).timeout
	Input.action_release("crouch")
	await create_timer(0.6).timeout
	_check(not room.nooni.crouching, "crouch key toggles crouch off in the open")

	room.queue_free()
	await process_frame


## A brief glimpse should send him suspicious, then to the last-seen spot, then back to his route.
func _test_glimpse_then_investigate() -> void:
	var room := RoomScene.instantiate()
	room.test_mode = true
	root.add_child(room)
	await process_frame

	# Yasser starts at (-3,0,1.5) facing +X and waits there 1.5 s, so Nooni is in clear view 3 m ahead.
	var seen := {}
	room.nooni.global_position = Vector3(0, 0, 1.5)
	for i in range(9):
		await create_timer(0.05).timeout
		seen[room.yasser.state_name()] = true
	# She ducks into the sofa's cover, so his look-around sweep can't find her.
	room.nooni.global_position = Vector3(-2, 0, -3.9)
	room.nooni.set_crouching_instant(true)

	for i in range(140):
		await create_timer(0.1).timeout
		seen[room.yasser.state_name()] = true
	_check(seen.has("Suspicious"), "a glimpse makes Yasser suspicious")
	_check(seen.has("Investigating"), "then he investigates the last-seen spot")
	_check(room.yasser.state_name() == "Patrol", "then he returns to patrol")
	_check(not room.yasser.is_caught(), "a short glimpse alone does not get Nooni caught")
	room.queue_free()
	await process_frame


## Each arrow key must move Nooni, using real key events (not just action presses).
func _test_arrow_keys() -> void:
	for key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var room := RoomScene.instantiate()
		room.test_mode = true
		root.add_child(room)
		await process_frame
		room.yasser.hold_position = true
		room.yasser.global_position = Vector3(5, 0, 4.5)
		room.nooni.global_position = Vector3(0, 0, -2)  # open floor, away from furniture

		var start: Vector3 = room.nooni.global_position
		var press := InputEventKey.new()
		press.physical_keycode = key
		press.pressed = true
		Input.parse_input_event(press)
		await create_timer(0.6).timeout
		var release := InputEventKey.new()
		release.physical_keycode = key
		release.pressed = false
		Input.parse_input_event(release)

		var moved: float = room.nooni.global_position.distance_to(start)
		_check(moved > 1.0, "%s key moves Nooni (%.1f m in 0.6 s)" % [OS.get_keycode_string(key), moved])
		room.queue_free()
		await process_frame


## A room with Yasser parked harmlessly in the south-east corner, facing a wall.
func _new_room() -> Node:
	var room := RoomScene.instantiate()
	room.test_mode = true
	root.add_child(room)
	await process_frame
	room.yasser.hold_position = true
	room.yasser.global_position = Vector3(5, 0, -4.2)
	room.yasser.rotation.y = 0.0
	return room


func _test_wheel_math() -> void:
	# Three slices: Nooni at 12 o'clock, Bruce lower right, Semba lower left. +Y is down on screen.
	_check(WheelMath.select_slice(Vector2(0, -100), 3, 50.0) == 0, "wheel: up selects slice 0")
	_check(WheelMath.select_slice(Vector2(87, 50), 3, 50.0) == 1, "wheel: lower right selects slice 1")
	_check(WheelMath.select_slice(Vector2(-87, 50), 3, 50.0) == 2, "wheel: lower left selects slice 2")
	_check(WheelMath.select_slice(Vector2(30, -100), 3, 50.0) == 0, "wheel: still inside slice 0's 120 degrees")
	_check(WheelMath.select_slice(Vector2(10, 10), 3, 50.0) == -1, "wheel: dead zone selects nothing")


func _test_pressure_plate() -> void:
	var room := await _new_room()
	var plate = room.plate
	var door = room.door

	room.nooni.global_position = plate.global_position
	await create_timer(0.5).timeout
	_check(not door.is_open, "Nooni alone (weight 1) can't open the heavy door (plate %.0f/%.0f)" % [plate.total_weight, plate.required_weight])

	room.nooni.global_position = Vector3(-3.2, 0, -4.3)
	room.bruce.global_position = plate.global_position
	await create_timer(0.5).timeout
	_check(door.is_open, "Bruce (weight 3) on the plate opens the door")
	await create_timer(0.8).timeout
	_check(door.is_fully_open(), "the door finishes sliding up")

	room.bruce.global_position = Vector3(-4.4, 0, -4.2)
	await create_timer(0.5).timeout
	_check(not door.is_open, "stepping off the plate closes the door again")
	room.queue_free()
	await process_frame


func _test_switching() -> void:
	var room := await _new_room()
	var sw = room.switcher
	_check(sw.current == room.nooni and room.nooni.input_enabled, "game starts with Nooni in control")

	_check(sw.request_switch(1), "switching to Bruce is accepted")
	await create_timer(0.2).timeout
	_check(sw.is_blending(), "the camera is blending")
	_check(not room.bruce.input_enabled, "Bruce can't act until the blend ends")
	await create_timer(0.8).timeout
	_check(not sw.is_blending(), "the blend finishes")
	_check(room.bruce.input_enabled and not room.nooni.input_enabled, "control passed from Nooni to Bruce")
	_check(root.get_camera_3d() == room.bruce.get_camera(), "Bruce's camera is the live camera")

	var nooni_start: Vector3 = room.nooni.global_position
	var bruce_start: Vector3 = room.bruce.global_position
	Input.action_press("move_forward")
	await create_timer(0.6).timeout
	Input.action_release("move_forward")
	var bruce_moved: float = room.bruce.global_position.distance_to(bruce_start)
	var nooni_moved: float = room.nooni.global_position.distance_to(nooni_start)
	_check(bruce_moved > 0.5 and bruce_moved < 1.6, "Bruce is slow: %.1f m in 0.6 s (Nooni would do ~2 m)" % bruce_moved)
	_check(nooni_moved < 0.05, "Nooni stays put while Bruce is played")

	_check(sw.request_switch(2), "switching on to Semba is accepted")
	await create_timer(0.8).timeout
	_check(sw.current == room.semba and room.semba.input_enabled and not room.bruce.input_enabled, "control passed from Bruce to Semba")
	_check(root.get_camera_3d() == room.semba.get_camera(), "Semba's camera is the live camera")
	_check(sw.request_switch(0), "and we can switch back to Nooni")
	await create_timer(0.8).timeout
	_check(sw.current == room.nooni and room.nooni.input_enabled, "back in control of Nooni")
	room.queue_free()
	await process_frame


func _test_wheel_flow() -> void:
	var room := await _new_room()
	var sw = room.switcher

	# A null roster slot is a locked character: lock Semba for a moment to check the wheel respects it.
	sw.roster[2] = null
	sw.open_wheel()
	sw.hover_offset(Vector2(-87, 50))
	await create_timer(0.3, true, false, true).timeout
	sw.close_wheel(true)
	_check(sw.current == room.nooni and room.nooni.input_enabled, "releasing over a locked slot does nothing")
	sw.roster[2] = room.semba

	_check(sw.open_wheel(), "holding Tab opens the wheel")
	_check(is_equal_approx(Engine.time_scale, sw.slow_time_scale), "time slows down while the wheel is open")
	_check(not room.nooni.input_enabled, "gameplay input is suspended while the wheel is open")
	sw.hover_offset(Vector2(87, 50))
	_check(sw.hovered == 1, "hovering lower right highlights Bruce")
	await create_timer(0.3, true, false, true).timeout
	sw.close_wheel(true)
	_check(is_equal_approx(Engine.time_scale, 1.0), "time returns to normal on release")
	_check(sw.current == room.bruce, "releasing over Bruce switches to him")
	await create_timer(0.8).timeout

	sw.open_wheel()
	sw.hover_offset(Vector2(5, 5))
	await create_timer(0.3, true, false, true).timeout
	sw.close_wheel(true)
	_check(sw.current == room.bruce and room.bruce.input_enabled, "releasing in the dead zone cancels (stays Bruce, input back)")

	sw.open_wheel()
	sw.hover_offset(Vector2(-87, 50))
	_check(sw.hovered == 2, "hovering lower left highlights Semba")
	await create_timer(0.3, true, false, true).timeout
	sw.close_wheel(true)
	_check(sw.current == room.semba, "releasing over Semba switches to him")
	await create_timer(0.8).timeout

	sw.open_wheel()
	sw.close_wheel(true)  # an immediate tap
	_check(sw.current == room.nooni, "a quick tap cycles on to the next cat (Semba -> Nooni)")
	await create_timer(0.8).timeout
	room.queue_free()
	await process_frame


func _test_bat_nap() -> void:
	# Same set-up as the 'standing in clear view is caught' test, but with Bruce napping between them.
	var room := await _new_room()
	room.yasser.global_position = Vector3(-2, 0, 1)
	room.yasser.rotation.y = 0.0
	room.nooni.global_position = Vector3(-2, 0, -2.2)
	room.bruce.global_position = Vector3(-2, 0, 0.2)

	_check(room.bruce.start_nap(), "Bruce flops down for a Bat-Nap")
	await create_timer(0.6).timeout
	_check(room.yasser.state_name() == "Being petted", "a brother walking by is forced into petting")
	_check(room.bruce.state_name() == "Purring", "Bruce purrs while he is petted")
	await create_timer(2.5).timeout
	_check(not room.yasser.is_caught(), "a petted Yasser doesn't catch Nooni standing in clear view")
	room.queue_free()
	await process_frame

	# And it wears off: shorten the petting, hide Nooni, and watch both return to normal.
	room = await _new_room()
	room.yasser.global_position = Vector3(-2, 0, 1)
	room.yasser.rotation.y = 0.0
	room.nooni.global_position = Vector3(-2, 0, -3.9)
	room.nooni.set_crouching_instant(true)
	room.bruce.global_position = Vector3(-2, 0, 0.2)
	room.bruce.pet_seconds = 1.0
	room.bruce.cooldown_seconds = 0.5
	room.bruce.start_nap()
	await create_timer(0.5).timeout
	_check(room.yasser.state_name() == "Being petted", "petting starts")
	await create_timer(2.5).timeout
	_check(room.yasser.state_name() != "Being petted", "Yasser snaps out of it after the petting ends")
	_check(room.bruce.state_name() == "Ready", "Bruce recovers and can nap again")
	room.queue_free()
	await process_frame


## Semba grabs the bookshelf by pushing toward it and climbs it with the forward key.
func _test_semba_climbing() -> void:
	var room := await _new_room()
	var sw = room.switcher
	var semba = room.semba

	_check(sw.request_switch(2), "switch to Semba")
	await create_timer(0.8).timeout

	# Stand in front of the bookshelf, facing it (camera yaw west), then push forward.
	semba.global_position = Vector3(-4.7, 0, 3.2)
	semba._yaw = PI * 0.5
	var start_speed_check: Vector3 = semba.global_position
	Input.action_press("move_forward")
	var climbed := false
	for i in range(30):
		await create_timer(0.1).timeout
		if semba.state == semba.State.CLIMBING:
			climbed = true
	Input.action_release("move_forward")
	_check(climbed, "pushing toward the bookshelf makes Semba start climbing")
	_check(semba.global_position.y > 1.9, "he reaches the top of the bookshelf (y = %.2f)" % semba.global_position.y)
	_check(semba.global_position.distance_to(Vector3(-5.72, 2.05, 3.2)) < 1.0, "and is standing on it, not floating beside it")

	# Fast: Semba outruns Nooni (5.5 vs 3.5 m/s).
	semba.global_position = Vector3(0, 0, -2)
	semba._yaw = -PI * 0.5
	await create_timer(0.3).timeout
	var from: Vector3 = semba.global_position
	Input.action_press("move_forward")
	await create_timer(0.6).timeout
	Input.action_release("move_forward")
	var ran: float = semba.global_position.distance_to(from)
	_check(ran > 2.5, "Semba is fast: %.1f m in 0.6 s (Nooni does ~2 m)" % ran)

	# Double jump: a second Space press in mid-air.
	await create_timer(0.3).timeout
	var ground_y: float = semba.global_position.y
	Input.action_press("jump")
	await create_timer(0.1).timeout
	Input.action_release("jump")
	await create_timer(0.15).timeout
	var first_peak: float = semba.global_position.y
	Input.action_press("jump")
	await create_timer(0.1).timeout
	Input.action_release("jump")
	await create_timer(0.3).timeout
	_check(semba.global_position.y > ground_y + 1.2, "a second jump in mid-air carries him higher (%.2f m above ground)" % (semba.global_position.y - ground_y))
	room.queue_free()
	await process_frame


func _test_mighty_roar() -> void:
	var room := await _new_room()
	var semba = room.semba

	# On the floor there is nothing to roar from.
	semba.global_position = Vector3(-4.0, 0, 0)
	_check(not semba.can_roar() and not semba.try_roar(), "Semba can't roar from the floor")

	# On top of the bookshelf he can. Yasser starts across the room, looking away.
	room.yasser.global_position = Vector3(-2, 0, -3.8)
	room.yasser.rotation.y = PI  # facing +Z, away from the south wall
	semba.global_position = Vector3(-5.72, 2.05, 3.2)
	await create_timer(0.3).timeout
	_check(semba.can_roar(), "from the high point he can roar")
	_check(semba.try_roar(), "Mighty Roar!")
	_check(not semba.can_release(), "he can't be switched away from mid-roar")
	_check(semba.state_name() == "ROARING", "state shows ROARING")
	await create_timer(0.2).timeout
	_check(room.yasser.state_name() == "Drawn by a yowl", "Yasser is drawn by the yowl")

	await create_timer(5.0).timeout
	var floor_spot := Vector3(-5.72, 0, 3.2)
	var gap: float = Vector2(room.yasser.global_position.x - floor_spot.x, room.yasser.global_position.z - floor_spot.z).length()
	_check(gap < 2.6, "he walked across the room to the bookshelf (%.1f m away)" % gap)
	_check(semba.can_release(), "Semba is free to be switched again after the roar")
	_check(not semba.can_roar(), "and is hoarse for a while (cooldown)")
	room.queue_free()
	await process_frame

	# The lure wears off and he goes back to patrolling.
	room = await _new_room()
	room.semba.lure_seconds = 1.0
	room.yasser.global_position = Vector3(-2, 0, 0)
	room.yasser.rotation.y = PI
	room.nooni.global_position = Vector3(-2, 0, -3.9)
	room.nooni.set_crouching_instant(true)  # hidden in the sofa's cover
	room.semba.global_position = Vector3(-5.72, 2.05, 3.2)
	await create_timer(0.3).timeout
	room.semba.try_roar()
	await create_timer(0.3).timeout
	_check(room.yasser.state_name() == "Drawn by a yowl", "lured")
	await create_timer(6.0).timeout
	_check(room.yasser.state_name() == "Patrol", "the lure wears off and he returns to patrol")
	room.queue_free()
	await process_frame


## The whole point: the exit is only reachable while Bruce holds the door open.
func _test_win_through_door() -> void:
	# Door shut: pushing at the doorway gets her nowhere.
	var room := await _new_room()
	room.nooni.global_position = Vector3(4.7, 0, 1.6)
	room.nooni._yaw = PI  # camera faces +Z, toward the door
	Input.action_press("move_forward")
	await create_timer(1.5).timeout
	Input.action_release("move_forward")
	_check(room.nooni.global_position.z < 2.4 and not room._finished, "with the door shut Nooni can't get into the pantry")
	room.queue_free()
	await process_frame

	# Bruce on the plate: she walks through and wins.
	room = await _new_room()
	room.bruce.global_position = room.plate.global_position
	await create_timer(1.5).timeout
	_check(room.door.is_fully_open(), "Bruce holds the door open")
	room.nooni.global_position = Vector3(4.7, 0, 1.6)
	room.nooni._yaw = PI
	Input.action_press("move_forward")
	await create_timer(2.5).timeout
	Input.action_release("move_forward")
	_check(room._finished, "Nooni walks through the open door onto the exit pad and the round is won")
	_check(room._message_label.text.begins_with("MISSION COMPLETE"), "with the win message on screen")
	room.queue_free()
	await process_frame
