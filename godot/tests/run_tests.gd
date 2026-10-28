extends SceneTree
## Headless checks:  godot --headless --path godot -s res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.

const VisionMath := preload("res://scripts/ai/vision_math.gd")
const WheelMath := preload("res://scripts/ui/wheel_math.gd")
const Levels := preload("res://scripts/levels/levels.gd")
const RoomScene := preload("res://scenes/level.tscn")

var failures := 0
## Pass a section name after `--` to run only that section, e.g.  -s res://tests/run_tests.gd -- driving
var _only := ''


func _initialize() -> void:
	# Autoloads aren't started by `godot -s`, so install our own GameState node where the game expects it.
	var state = root.get_node_or_null("GameState")
	if state == null:
		state = preload("res://scripts/core/game_state.gd").new()
		state.name = "GameState"
		root.add_child(state)
	state.test_mode = true  # no scene changes, never touch the real save
	# Nodes added to the root during _initialize don't get _ready until the first frame.
	await process_frame
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_only = args[0] if args.size() > 0 else ""
	if _want("vision_math"):
		_test_vision_math()

	if _want("detection"):
		# Same spot in clear view of Yasser; only Nooni's stance differs.
		# Yasser at (-2,0,1) faces -Z; Nooni at (-2,0,-2.2) is inside the sofa cover zone.
		await _scenario("standing in clear view is caught", Vector3(-2, 0, 1), 0.0, Vector3(-2, 0, -2.2), false, true)
		await _scenario("crouched inside cover is never seen", Vector3(-2, 0, 1), 0.0, Vector3(-2, 0, -2.2), true, false)

		# Yasser at (-5,0,1.5) faces +X; Nooni 6 m ahead in the open (no cover): standing range 9, crouched range 4.5.
		await _scenario("standing at 6 m is caught", Vector3(-5, 0, 1.5), -PI * 0.5, Vector3(1, 0, 1.5), false, true)
		await _scenario("crouched in the open at 6 m is not seen", Vector3(-5, 0, 1.5), -PI * 0.5, Vector3(1, 0, 1.5), true, false)

		# Behind Yasser: outside the cone.
		await _scenario("standing behind him is not seen", Vector3(-5, 0, 1.5), -PI * 0.5, Vector3(-5.8, 0, 1.5), false, false)

	if _want("patrol"):
		await _test_patrol()
	if _want("nooni_movement"):
		await _test_nooni_movement()
	if _want("glimpse_then_investigate"):
		await _test_glimpse_then_investigate()
	if _want("arrow_keys"):
		await _test_arrow_keys()
	if _want("wheel_math"):
		_test_wheel_math()
	if _want("pressure_plate"):
		await _test_pressure_plate()
	if _want("switching"):
		await _test_switching()
	if _want("wheel_flow"):
		await _test_wheel_flow()
	if _want("bat_nap"):
		await _test_bat_nap()
	if _want("semba_climbing"):
		await _test_semba_climbing()
	if _want("mighty_roar"):
		await _test_mighty_roar()
	if _want("win_through_door"):
		await _test_win_through_door()
	if _want("stress_and_smudge"):
		await _test_stress_and_smudge()
	if _want("framework"):
		await _test_framework()
	if _want("vision_and_hacking"):
		await _test_vision_and_hacking()
	if _want("grapple"):
		await _test_grapple()
	if _want("levels_solvable"):
		await _test_levels_solvable()
	if _want("level_two"):
		await _test_level_two()
	if _want("courtyard_and_exam_hall"):
		await _test_courtyard_and_exam_hall()
	if _want("driving"):
		await _test_driving()
	if _want("audio"):
		await _test_audio()
	if _want("playthrough"):
		await _test_playthrough()

	print("")
	if failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % failures)
	quit(1 if failures > 0 else 0)


func _want(section: String) -> bool:
	return _only == "" or _only == section


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


func _test_stress_and_smudge() -> void:
	var room := await _new_room()
	var nooni = room.nooni
	var stress = nooni.stress
	_check(stress.value == 0.0 and stress.smudge == 0.0, "stress starts at zero with clean glasses")

	# Yasser in plain view but slow to react: awareness climbs, so does stress.
	room.yasser.global_position = Vector3(-5, 0, 1.5)
	room.yasser.rotation.y = -PI * 0.5
	room.yasser.detection_seconds = 5.0
	nooni.global_position = Vector3(1, 0, 1.5)  # 6 m ahead of him
	await create_timer(2.6).timeout
	_check(stress.value > 0.5, "stress rises while a brother is closing in (%.2f)" % stress.value)
	_check(stress.smudge > 0.25, "her glasses smudge once stress passes the threshold (%.2f)" % stress.smudge)
	_check(not room._finished, "and she hasn't been caught yet")

	# Hide: stress falls but the smudge stays until she wipes.
	nooni.global_position = Vector3(-2, 0, -3.9)  # she ducks into the sofa's cover
	nooni.set_crouching_instant(true)
	var smudge_before: float = stress.smudge
	await create_timer(1.5).timeout
	_check(stress.smudge >= smudge_before - 0.001, "the smudge does not clean itself")

	# Wipe with the real key.
	var stress_before: float = stress.value
	Input.action_press("wipe_glasses")
	await create_timer(0.1).timeout
	Input.action_release("wipe_glasses")
	_check(stress.wiping, "pressing R starts a wipe")
	await create_timer(0.6).timeout
	_check(stress.smudge == 0.0 and not stress.wiping, "the glasses are clean again")
	_check(stress.value < stress_before, "and wiping takes the edge off her stress")
	_check(not stress.wipe(), "wiping clean glasses does nothing")
	room.queue_free()
	await process_frame

	# Calming: faster when crouched in cover than standing in the open.
	room = await _new_room()
	var calm_open = room.nooni
	calm_open.stress.value = 0.8
	calm_open.global_position = Vector3(-4.5, 0, -1)  # open floor, no brother near
	await create_timer(2.0).timeout
	var open_drop: float = 0.8 - calm_open.stress.value
	calm_open.stress.value = 0.8
	calm_open.global_position = Vector3(-2, 0, -3.9)
	calm_open.set_crouching_instant(true)
	await create_timer(2.0).timeout
	var cover_drop: float = 0.8 - calm_open.stress.value
	_check(cover_drop > open_drop + 0.1, "stress falls faster crouched in cover (%.2f vs %.2f)" % [cover_drop, open_drop])
	room.queue_free()
	await process_frame

	# Stress makes her sloppy at hiding in the open, but cover is still perfectly safe.
	room = await _new_room()
	var n2 = room.nooni
	n2.global_position = Vector3(-4.5, 0, -1)
	n2.set_crouching_instant(true)
	n2.stress.value = 0.0
	var calm_visibility: float = n2.get_visibility()
	n2.stress.value = 1.0
	_check(n2.get_visibility() > calm_visibility + 0.2, "a stressed Nooni is easier to spot when crouched in the open (%.2f -> %.2f)" % [calm_visibility, n2.get_visibility()])
	n2.global_position = Vector3(-2, 0, -3.9)
	_check(n2.get_visibility() == 0.0, "but still invisible in cover")
	room.queue_free()
	await process_frame

	# A brother who is merely close (and looking away) still makes her a bit nervous.
	room = await _new_room()
	room.yasser.global_position = Vector3(-2, 0, 1)
	room.yasser.rotation.y = PI  # facing away
	room.nooni.global_position = Vector3(-2, 0, -1.5)  # 2.5 m behind him
	await create_timer(3.0).timeout
	_check(room.nooni.stress.value > 0.05 and room.yasser.awareness == 0.0, "a close brother raises stress even without spotting her (%.2f)" % room.nooni.stress.value)
	room.queue_free()
	await process_frame

	# The overlay shows only while Nooni is the one being played.
	room = await _new_room()
	room.nooni.stress.smudge = 0.6
	await create_timer(0.2).timeout
	_check(room._glasses.visible, "the smudge is drawn while Nooni is played")
	room.switcher.request_switch(1)
	await create_timer(0.9).timeout
	_check(not room._glasses.visible, "and hidden while Bruce is played (cats don't wear glasses)")
	room.switcher.request_switch(0)
	await create_timer(0.9).timeout
	_check(room._glasses.visible, "but still there when we switch back")
	room.queue_free()
	await process_frame


func _test_framework() -> void:
	var state = root.get_node("GameState")
	state.save_path = "user://test_save.cfg"
	state.unlocked = 1
	state.results = {}
	state.current_level = 0

	# Progress and best times.
	var has_next: bool = state.complete_level(42.0, 2)
	_check(has_next == (Levels.count() > 1), "completing a level reports whether another follows")
	_check(state.results[0].seconds == 42.0 and state.results[0].spotted == 2, "the result is recorded")
	state.complete_level(60.0, 5)
	_check(state.results[0].seconds == 42.0, "a slower run does not replace the best time")
	state.complete_level(30.0, 1)
	_check(state.results[0].seconds == 30.0, "a faster run does")
	_check(state.unlocked == mini(2, Levels.count()), "the next level unlocks")

	# Save / load round trip.
	state.settings.master = 0.25
	state.save()
	state.results = {}
	state.unlocked = 1
	state.settings.master = 0.8
	state.load_save()
	_check(state.results.has(0) and state.results[0].seconds == 30.0 and is_equal_approx(state.settings.master, 0.25), "progress and settings survive a save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	state.results = {}
	state.unlocked = 1
	state.settings.master = 0.8
	_check(not state.has_save(), "a fresh game has nothing to continue")

	# Every level in the registry has the data the builder needs.
	for i in Levels.count():
		var data := Levels.data(i)
		var keys := ["title", "objective", "story_intro", "story_outro"]
		keys.append_array(["length", "time_limit", "lights"] if Levels.info(i).kind == "drive" else ["solids", "spawns", "exit"])
		for key in keys:
			_check(data.has(key), "level %d has '%s'" % [i + 1, key])

	# The HUD has a row per brother.
	var room := await _new_room()
	_check(room.hud._brother_rows.size() == room.brothers.size(), "the HUD lists every brother")
	room.queue_free()
	await process_frame

	await _test_menus_and_cards()


func _test_menus_and_cards() -> void:
	# Title screen builds with its pages and level list.
	var menu = load("res://scenes/main.tscn").instantiate()
	root.add_child(menu)
	await create_timer(0.3).timeout
	_check(menu._pages.size() == 4, "the title screen has main, level select, controls and settings pages")
	menu._show("levels")
	await process_frame
	await process_frame
	_check(menu._level_box.get_child_count() == Levels.count(), "level select lists every level")
	menu.queue_free()
	await process_frame

	# Narration captions queue and expire.
	var captions = preload("res://scripts/ui/captions.gd").new()
	root.add_child(captions)
	await process_frame
	captions.say("first", 0.2)
	captions.say("second", 0.2)
	_check(captions.is_showing() and captions._label.text == "first", "a caption shows")
	await create_timer(0.3).timeout
	_check(captions._label.text == "second", "the next caption follows")
	await create_timer(0.3).timeout
	_check(not captions.is_showing(), "and it disappears when the queue is empty")
	captions.queue_free()

	# Story card: space skips typing, then advances; finishes after the last line.
	var card = preload("res://scripts/ui/story_card.gd").new()
	root.add_child(card)
	var done := [false]
	card.finished.connect(func(): done[0] = true)
	card.play("Test", ["line one", "line two"])
	for i in 4:
		var press := InputEventAction.new()
		press.action = "ui_accept"
		press.pressed = true
		Input.parse_input_event(press)
		await create_timer(0.1).timeout
	_check(done[0], "the story card finishes after its last line")
	card.queue_free()

	# Pause menu toggles pause.
	var pause = preload("res://scripts/ui/pause_menu.gd").new()
	root.add_child(pause)
	pause.setup(null)
	pause.toggle()
	_check(paused and pause.visible, "Esc pauses the game and shows the menu")
	pause.toggle()
	_check(not paused and not pause.visible, "and resumes it")
	pause.queue_free()

	# Result panel: win and lose variants.
	var result = preload("res://scripts/ui/result_panel.gd").new()
	root.add_child(result)
	result.show_result(true, "MISSION COMPLETE", ["An outro line."], 75.0, 2, true)
	var buttons := 0
	for node in result.find_children("*", "Button", true, false):
		buttons += 1
	_check(paused and buttons == 3, "the win panel offers next level, replay and main menu")
	result.queue_free()
	paused = false
	var lose = preload("res://scripts/ui/result_panel.gd").new()
	root.add_child(lose)
	lose.show_result(false, "SPOTTED BY YASSER", ["Oh no."], 10.0, 0, false)
	buttons = 0
	for node in lose.find_children("*", "Button", true, false):
		buttons += 1
	_check(buttons == 2, "the lose panel offers try again and main menu")
	lose.queue_free()
	paused = false
	await process_frame


func _test_vision_and_hacking() -> void:
	var room := await _new_room()
	var nooni = room.nooni
	var yasser = room.yasser
	var tv = room.get_node("SmartTV")
	var lamp = room.get_node("SmartLamp")

	# Detective Vision on/off with the real mouse action.
	_check(not nooni.vision.active and not yasser._xray.visible, "vision starts off")
	Input.action_press("vision")
	await create_timer(0.2).timeout
	_check(nooni.vision.active and yasser._xray.visible and tv._marker.visible, "holding right mouse turns Detective Vision on for brothers and gadgets")
	_check(yasser._cone.visible, "his sightline is shown")
	Input.action_release("vision")
	await create_timer(0.2).timeout
	_check(not nooni.vision.active and not yasser._xray.visible and not tv._marker.visible, "releasing turns it off again")

	# Hacking needs vision, range and a ready device.
	nooni.global_position = Vector3(-0.5, 0, 3.4)  # next to the TV
	room.yasser.global_position = Vector3(-4, 0, -2)
	room.yasser.rotation.y = 0.0  # facing the south wall, away from Nooni
	room.yasser.view_distance = 0.1  # this test is about the lure, not his eyes
	Input.action_press("interact")
	await create_timer(0.1).timeout
	Input.action_release("interact")
	_check(tv.cooldown_left <= 0.0 and yasser.state_name() != "Drawn by a noise", "E does nothing without Detective Vision")

	Input.action_press("vision")
	await create_timer(0.2).timeout
	nooni.global_position = Vector3(-5, 0, -4)  # far from every gadget
	Input.action_press("interact")
	await create_timer(0.1).timeout
	Input.action_release("interact")
	_check(tv.cooldown_left <= 0.0, "and nothing happens out of range")

	nooni.global_position = Vector3(2.5, 0, 2.0)  # 3.8 m from the TV, off to the side of Yasser's path
	await create_timer(0.1).timeout
	Input.action_press("interact")
	await create_timer(0.1).timeout
	Input.action_release("interact")
	_check(tv.cooldown_left > 0.0, "with vision on and the TV in range, E hacks it")
	await create_timer(0.3).timeout
	_check(yasser.state_name() == "Drawn by a noise", "the blaring TV draws Yasser over")
	await create_timer(3.5).timeout
	var tv_gap: float = Vector2(yasser.global_position.x - tv.global_position.x, yasser.global_position.z - tv.global_position.z).length()
	_check(tv_gap < 2.5, "he walks across the room to the TV (%.1f m away)" % tv_gap)
	Input.action_release("vision")

	# The TV is recharging, so a second hack is refused.
	_check(not tv.hack(), "a recharging device can't be hacked again")
	tv.cooldown_left = 0.0

	# Lights out: Yasser's sight range halves, so Nooni 6 m away in plain view is no longer caught.
	room.queue_free()
	await process_frame
	room = await _new_room()
	room.yasser.global_position = Vector3(-5, 0, 1.5)
	room.yasser.rotation.y = -PI * 0.5
	room.nooni.global_position = Vector3(1, 0, 1.5)  # 6 m ahead of him
	var dark_lamp = room.get_node("SmartLamp")
	var energy_before: float = dark_lamp._light.light_energy
	dark_lamp.hack()
	_check(dark_lamp._light.light_energy == 0.0 and room.yasser.vision_scale == 0.5, "hacking the smart lamp kills the light and halves every brother's sight")
	await create_timer(2.5).timeout
	_check(not room.yasser.is_caught(), "so a standing Nooni 6 m away goes unnoticed in the dark")
	dark_lamp.effect_left = 0.1
	room.yasser._dark_timer = 0.1
	await create_timer(0.5).timeout
	_check(is_equal_approx(dark_lamp._light.light_energy, energy_before) and room.yasser.vision_scale == 1.0, "and the lights come back after a while")
	room.queue_free()
	await process_frame

	# A smart lock opens its door (used by later levels): build a tiny rig by hand.
	room = await _new_room()
	var lock := preload("res://scripts/puzzle/hackable.gd").new()
	lock.kind = "lock"
	lock.display_name = "Smart lock"
	lock.target = room.door
	lock.effect_seconds = 0.0
	room.add_child(lock)
	await process_frame
	_check(not room.door.is_open, "the pantry door starts shut")
	lock.hack()
	_check(room.door.is_open, "hacking a smart lock opens its door")
	room.queue_free()
	await process_frame


func _test_grapple() -> void:
	var room := await _new_room()
	var nooni = room.nooni
	var hook = room.get_node("Hook_WallShelf")
	var shelf_top := Vector3(-3.5, 1.95, 4.65)

	# Face the hook and tilt the camera to put it under the crosshair.
	nooni.global_position = Vector3(-3.5, 0, 1.0)
	nooni._yaw = PI  # camera looks toward +Z, at the north wall
	await create_timer(0.2).timeout
	# The crosshair ray runs through the camera pivot, so aim the pivot at the hook.
	var toward: Vector3 = (hook.global_position - nooni._pivot.global_position).normalized()
	nooni._pitch = asin(toward.y)
	await create_timer(0.2).timeout
	_check(nooni.grapple_target == hook and hook.targeted, "aiming at the wall hook targets it")

	# Looking away loses the target.
	nooni._pitch = -0.45
	await create_timer(0.2).timeout
	_check(nooni.grapple_target == null and not hook.targeted, "looking away drops the target")

	# Too far away: out of range.
	nooni.global_position = Vector3(5.5, 0, -4.5)
	nooni._yaw = PI * 0.75
	await create_timer(0.2).timeout
	_check(nooni.grapple_target == null, "a hook beyond max range can't be targeted")

	# Fire it.
	nooni.global_position = Vector3(-3.5, 0, 1.0)
	nooni._yaw = PI
	await create_timer(0.2).timeout
	toward = (hook.global_position - nooni._pivot.global_position).normalized()
	nooni._pitch = asin(toward.y)
	await create_timer(0.2).timeout
	Input.action_press("grapple")
	await create_timer(0.1).timeout
	Input.action_release("grapple")
	_check(nooni._zipping and nooni._rope.visible, "clicking launches the grapple and shows the rope")
	_check(not nooni.can_release(), "she can't be switched away mid-zip")
	await create_timer(1.4).timeout
	_check(not nooni._zipping and nooni.global_position.distance_to(shelf_top) < 0.8, "she lands on the wall shelf (%.2f m off)" % nooni.global_position.distance_to(shelf_top))
	_check(not nooni._rope.visible and nooni.can_release(), "the rope retracts and she is free again")
	_check(nooni.grapple_cooldown_left > 0.0 or nooni.grapple_cooldown_left == 0.0, "cooldown runs")

	# She can walk about up there, and drop back down.
	var perch: Vector3 = nooni.global_position
	nooni._yaw = PI * 0.5
	Input.action_press("move_forward")
	await create_timer(0.3).timeout
	Input.action_release("move_forward")
	_check(nooni.global_position.y > 1.5, "she stands on the shelf rather than falling through it (y = %.2f)" % nooni.global_position.y)

	# Blocked line of sight: the sofa-height cover isn't enough, so put a tall wall in the way.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.3)
	shape.shape = box
	blocker.add_child(shape)
	room.add_child(blocker)
	blocker.global_position = Vector3(-3.5, 2, 2.5)
	nooni.global_position = Vector3(-3.5, 0, 1.0)
	nooni._yaw = PI
	nooni._pitch = asin(toward.y)
	nooni.grapple_cooldown_left = 0.0
	await create_timer(0.3).timeout
	_check(nooni.grapple_target == null, "a wall between her and the hook blocks the shot")
	room.queue_free()
	await process_frame


## Every level: the exit is reachable on foot once the doors are open, and every brother can walk his route.
func _test_levels_solvable() -> void:
	for i in Levels.count():
		if Levels.info(i).kind != "stealth":
			continue
		var room := RoomScene.instantiate()
		room.level_index = i
		room.test_mode = true
		root.add_child(room)
		await create_timer(0.4).timeout
		var label: String = room.data.title

		for door in room.doors.values():
			door.set_open(true)
		await create_timer(1.0).timeout
		# The navmesh sits ~0.4 m above the floor, so an open door's lower edge still blocks a brother-sized
		# agent; lift opened doors clear to check the layout itself.
		for door in room.doors.values():
			door.position.y += 3.0
		await physics_frame
		var region: NavigationRegion3D = room.get_node("World")
		region.bake_navigation_mesh(false)
		await physics_frame
		await physics_frame
		await physics_frame
		var map: RID = room.get_world_3d().navigation_map

		var path := NavigationServer3D.map_get_path(map, room.nooni.global_position, room.exit_position, true)
		var reach: float = path[path.size() - 1].distance_to(room.exit_position) if path.size() > 0 else 99.0
		_check(path.size() > 0 and reach < room.goal_radius + 0.8, "%s: the exit is reachable on foot (path ends %.1f m from it)" % [label, reach])

		for brother in room.brothers:
			var ok := true
			for point in brother.patrol_points:
				var route := NavigationServer3D.map_get_path(map, brother.global_position, point, true)
				if route.size() == 0 or route[route.size() - 1].distance_to(point) > 1.0:
					ok = false
			_check(ok, "%s: %s can walk every point of his patrol" % [label, brother.name])

		for cat in [room.bruce, room.semba]:
			if cat:
				var cat_path := NavigationServer3D.map_get_path(map, cat.global_position, room.nooni.global_position, true)
				_check(cat_path.size() > 0, "%s: %s can reach Nooni" % [label, cat.name])
		room.queue_free()
		await process_frame


## A level other than the first, with every brother parked harmlessly facing a wall.
func _new_level(index: int) -> Node:
	var room := RoomScene.instantiate()
	room.level_index = index
	room.test_mode = true
	root.add_child(room)
	await create_timer(0.3).timeout
	for brother in room.brothers:
		brother.hold_position = true
		brother.view_distance = 0.1  # parked and blind: these tests are about the puzzles
	return room


func _test_level_two() -> void:
	var room := await _new_level(1)
	var door = room.doors["GarageDoor"]
	_check(room.brothers.size() == 2 and room.brothers[1].kind == "ahmed", "level 2 has Yasser and Ahmed")
	_check(room.brothers[1].view_angle < room.brothers[0].view_angle and room.brothers[1].view_distance == 0.1, "Ahmed has his own senses (narrow cone)")

	# 1) Smart lock: hack it with Detective Vision from the console table; the door opens, then closes again.
	room.nooni.global_position = Vector3(4.2, 0, 3.6)
	Input.action_press("vision")
	await create_timer(0.2).timeout
	Input.action_press("interact")
	await create_timer(0.1).timeout
	Input.action_release("interact")
	await create_timer(0.8).timeout
	_check(door.is_open and door.is_fully_open(), "hacking the smart lock opens the garage door")
	Input.action_release("vision")
	room.get_node("SmartLock").effect_left = 0.3
	await create_timer(0.8).timeout
	_check(not door.is_open, "and it closes again after a while")

	# 2) Bruce on the plate keeps it open.
	room.bruce.global_position = room.plates[0].global_position
	await create_timer(1.3).timeout
	_check(door.is_fully_open(), "Bruce on the hall plate holds the garage door open")

	# The doorway is wide enough to walk through.
	room.nooni.global_position = Vector3(4.0, 0, 0.0)
	room.nooni._yaw = -PI * 0.5  # camera looks east
	Input.action_press("move_forward")
	await create_timer(0.9).timeout
	Input.action_release("move_forward")
	_check(room.nooni.global_position.x > 5.4, "Nooni walks through the open garage door (x = %.1f)" % room.nooni.global_position.x)
	room.queue_free()
	await process_frame

	# 3) Semba on the fridge roars: both brothers come.
	room = await _new_level(1)
	room.semba.global_position = Vector3(-8.4, 2.3, -3.2)
	await create_timer(0.3).timeout
	_check(room.semba.try_roar(), "Semba can roar from the top of the fridge")
	await create_timer(0.3).timeout
	var drawn := 0
	for brother in room.brothers:
		if brother.state_name() == "Drawn by a yowl":
			drawn += 1
	_check(drawn == 2, "both brothers are drawn by the yowl")
	room.queue_free()
	await process_frame

	# 4) The smart speaker lures them too, and the lights hack halves their sight.
	room = await _new_level(1)
	room.get_node("SmartSpeaker").hack()
	await create_timer(0.2).timeout
	drawn = 0
	for brother in room.brothers:
		if brother.state_name() == "Drawn by a noise":
			drawn += 1
	_check(drawn == 2, "the smart speaker draws both brothers")
	room.get_node("KitchenLamp").hack()
	_check(room.brothers[0].vision_scale == 0.5 and room.brothers[1].vision_scale == 0.5, "the smart light halves both brothers' sight")
	room.queue_free()
	await process_frame


func _test_courtyard_and_exam_hall() -> void:
	# --- PNU Courtyard ---
	var room := await _new_level(Levels.index_of("pnu_courtyard"))
	var door = room.doors["LibraryDoor"]
	_check(room.brothers.size() == 3 and room.brothers[0].kind == "guard", "the courtyard has two guards and Ahmed")
	_check(room.brothers[0].view_angle > room.brothers[2].view_angle, "guards see a wider arc than Ahmed")

	# Hack the library lock from beside the planter.
	room.nooni.global_position = Vector3(3.5, 0, 6.0)
	Input.action_press("vision")
	await create_timer(0.2).timeout
	Input.action_press("interact")
	await create_timer(0.1).timeout
	Input.action_release("interact")
	Input.action_release("vision")
	await create_timer(1.0).timeout
	_check(door.is_open, "hacking the library lock opens the door")
	room.queue_free()
	await process_frame

	# Bruce on the gate plate holds it open.
	room = await _new_level(Levels.index_of("pnu_courtyard"))
	room.bruce.global_position = room.plates[0].global_position
	await create_timer(1.3).timeout
	_check(room.doors["LibraryDoor"].is_fully_open(), "Bruce on the gate plate opens the library door")
	room.queue_free()
	await process_frame

	# The grapple route: hook above the entrance, landing on the lobby balcony.
	room = await _new_level(Levels.index_of("pnu_courtyard"))
	var hook = room.get_node("Hook_Balcony")
	room.nooni.global_position = Vector3(3.0, 0, 3.0)
	room.nooni._yaw = PI
	await create_timer(0.2).timeout
	var toward: Vector3 = (hook.global_position - room.nooni._pivot.global_position).normalized()
	room.nooni._pitch = asin(toward.y)
	await create_timer(0.3).timeout
	_check(room.nooni.grapple_target == hook, "the balcony hook can be targeted from the courtyard")
	Input.action_press("grapple")
	await create_timer(0.1).timeout
	Input.action_release("grapple")
	await create_timer(1.5).timeout
	_check(room.nooni.global_position.distance_to(Vector3(3.0, 2.7, 8.8)) < 0.8 and room.nooni.global_position.z > 8.0, "she lands on the balcony inside the library (z = %.1f)" % room.nooni.global_position.z)
	room.queue_free()
	await process_frame

	# --- Exam Hall ---
	room = await _new_level(Levels.index_of("exam_hall"))
	_check(room.time_limit() == 150.0 and room.hud._timer_label.visible, "the exam hall has a countdown")
	_check(room.brothers.size() == 3 and room.brothers[0].kind == "professor", "the professor, Yasser and Ahmed patrol the hall")
	_check(room.brothers[0].view_angle > 120.0 and room.brothers[0].patrol_speed < 1.5, "the professor is slow with a huge arc")
	_check(not room._finished, "the exam hasn't started")
	room._started_msec -= 151000  # the clock runs out
	await create_timer(0.2).timeout
	_check(room._finished and not room._won and room._message_label.text == "OUT OF TIME", "running out of time fails the level")
	room.queue_free()
	await process_frame

	# And winning in time works: put Nooni on the seat.
	room = await _new_level(Levels.index_of("exam_hall"))
	room.nooni.global_position = room.exit_position
	await create_timer(0.3).timeout
	_check(room._finished and room._won, "reaching Seat 42 in time wins the finale")
	room.queue_free()
	await process_frame


func _new_drive() -> Node:
	var drive = load("res://scenes/drive.tscn").instantiate()
	drive.level_index = Levels.index_of("king_fahd_road")
	drive.test_mode = true
	root.add_child(drive)
	await create_timer(0.3).timeout
	return drive


func _test_driving() -> void:
	var drive := await _new_drive()
	_check(drive.length == 1300.0 and drive.lights.size() == 3, "King Fahd Road is 1.3 km long with three stoplights")
	_check(Levels.info(Levels.index_of("king_fahd_road")).kind == "drive", "it is registered as a driving level")

	# Throttle, steering, braking.
	Input.action_press("move_forward")
	await create_timer(2.0).timeout
	var top: float = drive.speed
	_check(top > 15.0 and drive.distance > 15.0, "W accelerates the Mazda (%.0f km/h after 2 s)" % (top * 3.6))
	Input.action_press("move_right")
	await create_timer(0.6).timeout
	Input.action_release("move_right")
	_check(drive.lateral > 1.5, "D steers right (x = %.1f)" % drive.lateral)
	Input.action_press("move_left")
	await create_timer(4.0).timeout
	Input.action_release("move_left")
	_check(drive.lateral < 0.0 and drive.lateral >= -4.7, "A steers left and the road edge stops her (x = %.1f)" % drive.lateral)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await create_timer(1.2).timeout
	Input.action_release("move_back")
	_check(drive.speed < top - 10.0 and drive.speed >= 0.0, "S brakes (%.0f km/h)" % (drive.speed * 3.6))
	Input.action_press("move_forward")
	await create_timer(8.0).timeout
	Input.action_release("move_forward")
	_check(drive.speed <= drive.max_speed + 0.01, "speed is capped (%.0f km/h)" % (drive.speed * 3.6))
	drive.queue_free()
	await process_frame

	# Crashing into slower traffic costs speed and time.
	drive = await _new_drive()
	for other in drive.traffic:
		other.queue_free()
	drive.traffic.clear()
	drive.speed = 20.0
	drive._spawn_traffic(Vector3(drive.lateral, 0, -drive.distance - 6.0), Vector3(0, 0, -5.0), false)
	await create_timer(0.7).timeout
	_check(drive.crashes == 1 and is_equal_approx(drive.penalty, 4.0), "hitting a car counts one crash and adds a time penalty")
	_check(drive.speed < 10.0, "and kills most of her speed (%.0f km/h)" % (drive.speed * 3.6))
	await create_timer(0.5).timeout
	_check(drive.crashes == 1, "the same car can't be hit twice")
	drive.queue_free()
	await process_frame

	# Stoplights: red lights spawn cross traffic; hacking turns one green; the cycle turns them over by itself.
	drive = await _new_drive()
	var light = drive.lights[0]
	light.green = false
	light.hacked_left = 0.0
	light._timer = 0.0
	drive.distance = 250.0
	drive._spawned_until = 1e9  # no ordinary traffic in this check
	await create_timer(2.0).timeout
	var crossing := 0
	for other in drive.traffic:
		if other.cross:
			crossing += 1
	_check(crossing > 0, "a red light 80 m ahead sends cross traffic through the junction (%d cars)" % crossing)
	_check(drive.try_hack_light() == light and light.green, "E hacks the next red light to green")
	_check(drive.try_hack_light() == null, "and the hack then recharges")
	var before_cross := 0
	for other in drive.traffic:
		if other.cross:
			before_cross += 1
	await create_timer(3.0).timeout
	var after_cross := 0
	for other in drive.traffic:
		if other.cross:
			after_cross += 1
	_check(after_cross <= before_cross, "no new cross traffic while it is green")
	var cycler := preload("res://scripts/driving/stop_light.gd").new()
	cycler.red_seconds = 0.2
	cycler.green_seconds = 0.2
	cycler.green = false
	drive.add_child(cycler)
	await process_frame
	cycler._timer = 0.0
	cycler.tick(0.3)
	_check(cycler.green, "an unhacked light turns green on its own after its red phase")
	drive.queue_free()
	await process_frame

	# Winning and losing.
	drive = await _new_drive()
	drive.distance = drive.length
	await create_timer(0.2).timeout
	_check(drive._finished and drive._won, "reaching PNU wins")
	drive.queue_free()
	await process_frame
	drive = await _new_drive()
	drive.penalty = 200.0
	await create_timer(0.2).timeout
	_check(drive._finished and not drive._won and drive._hud.message.text == "TOO LATE", "running out of time fails the drive")
	drive.queue_free()
	await process_frame


func _test_audio() -> void:
	# `godot -s` starts the autoloads, so use the real Audio node when there is one.
	var audio = root.get_node_or_null("Audio")
	var installed := audio == null
	if installed:
		audio = preload("res://scripts/core/audio.gd").new()
		audio.name = "Audio"
		root.add_child(audio)
	await process_frame

	# Every sound the game can ask for exists and loads.
	var missing := []
	for sound in audio.SFX_NAMES + audio.MUSIC_NAMES + ["engine"]:
		if not ResourceLoader.exists("res://audio/%s.wav" % sound) or audio.stream(sound) == null:
			missing.append(sound)
	_check(missing.is_empty(), "all %d sound files load%s" % [audio.SFX_NAMES.size() + audio.MUSIC_NAMES.size() + 1, "" if missing.is_empty() else " (missing: %s)" % ", ".join(missing)])

	# Effects play through the pool, music loops, the engine follows the speed.
	audio.sfx("ui_click")
	var playing := 0
	for player in audio._pool:
		if player.playing:
			playing += 1
	_check(playing >= 1, "a sound effect starts playing")
	audio.play_music("music_stealth")
	_check(audio.current_music() == "music_stealth" and audio._music.playing, "music starts")
	_check(audio._music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and audio._music.stream.loop_end > 100000, "and loops")
	audio.engine(true, 0.0)
	var idle_pitch: float = audio._engine.pitch_scale
	audio.engine(true, 1.0)
	_check(audio._engine.playing and audio._engine.pitch_scale > idle_pitch + 1.0, "the engine pitch rises with speed")
	audio.engine(false)
	_check(not audio._engine.playing, "and stops")

	# Volumes follow the saved settings.
	var state = root.get_node("GameState")
	state.settings.music = 0.25
	state.settings.master = 0.5
	state.settings_changed.emit()
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var master_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	_check(absf(music_db - linear_to_db(0.25)) < 0.1 and absf(master_db - linear_to_db(0.5)) < 0.1, "the music and master sliders set the bus volumes")
	state.settings.music = 0.6
	state.settings.master = 0.8
	state.settings_changed.emit()

	# Game events trigger their sounds.
	var room := await _new_room()
	_check(audio.current_music() == "music_stealth", "a stealth level starts the stealth music")
	var heard := func(sound: String) -> bool:
		return audio.played.has(sound)
	room.get_node("SmartTV").hack()
	_check(heard.call("hack"), "hacking a gadget plays the hack sound")
	room.nooni.global_position = Vector3(-3.5, 0, 1.0)
	room.semba.global_position = Vector3(-5.72, 2.05, 3.2)
	await create_timer(0.3).timeout
	room.semba.try_roar()
	_check(heard.call("roar"), "Semba's roar plays")
	room.bruce.start_nap()
	_check(heard.call("meow"), "Bruce's Bat-Nap plays a meow")
	room.switcher.open_wheel()
	_check(heard.call("wheel_open"), "opening the wheel plays its swoosh")
	room.switcher.close_wheel(false)
	room.bruce.global_position = room.plate.global_position
	await create_timer(0.6).timeout
	_check(heard.call("plate") or heard.call("door"), "the plate and the door make noise")
	room.yasser.global_position = Vector3(-5, 0, 1.5)
	room.yasser.rotation.y = -PI * 0.5
	room.yasser.detection_seconds = 6.0
	room.nooni.global_position = Vector3(1, 0, 1.5)
	await create_timer(0.8).timeout
	_check(heard.call("alert"), "a brother noticing Nooni plays the alert sting")
	room.queue_free()
	await process_frame

	var drive := await _new_drive()
	_check(audio.current_music() == "music_drive" and audio._engine.playing, "the driving level plays the drive music and engine")
	drive.speed = 20.0
	drive._spawn_traffic(Vector3(drive.lateral, 0, -drive.distance - 6.0), Vector3(0, 0, -5.0), false)
	await create_timer(0.7).timeout
	_check(heard.call("crash"), "a crash makes noise")
	drive.queue_free()
	await process_frame
	_check(not audio._engine.playing, "leaving the drive stops the engine")

	audio.stop_music()
	if installed:
		audio.queue_free()
	await process_frame


## A bot plays the real game: it follows a navigation path to the exit by steering Nooni's camera and holding W.
## The brothers are parked and blind (we are testing the layout and Nooni's movement, not stealth).
func _test_playthrough() -> void:
	# Campaign flow: finishing each level unlocks the next, then the credits.
	var state = root.get_node("GameState")
	state.save_path = "user://test_campaign.cfg"
	state.new_game()
	_check(state.current_level == 0 and state.unlocked == 1, "a new game starts on level 1")
	for i in Levels.count():
		var more: bool = state.complete_level(30.0 + i, i)
		_check(more == (i + 1 < Levels.count()), "level %d reports %s" % [i + 1, "more to come" if i + 1 < Levels.count() else "the end of the game"])
		if more:
			state.go_next()
			_check(state.current_level == i + 1, "go_next moves to level %d" % (i + 2))
	_check(state.unlocked == Levels.count(), "every level is unlocked at the end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_campaign.cfg"))
	state.unlocked = 1
	state.results = {}
	state.current_level = 0

	for i in Levels.count():
		match Levels.info(i).kind:
			"stealth":
				var room := await _new_level(i)
				var label: String = room.data.title
				var won := await _bot_walk_to_exit(room, 60.0)
				_check(won, "%s: a bot walks Nooni from the start to the exit and wins (%.0f s)" % [label, room.elapsed_seconds()])
				room.queue_free()
				await process_frame
			"drive":
				var drive := await _new_drive()
				drive.penalty = 0.0
				drive._spawned_until = 1e9  # an empty road: this checks the course and the clock
				for light in drive.lights:
					light.green = true
					light.hacked_left = 999.0
				Input.action_press("move_forward")
				var waited := 0.0
				while not drive._finished and waited < 90.0:
					await create_timer(0.5).timeout
					waited += 0.5
				Input.action_release("move_forward")
				_check(drive._won, "King Fahd Road can be driven end to end in time (%.0f s of %.0f)" % [drive.total_seconds(), drive.time_limit()])
				drive.queue_free()
				await process_frame


func _bot_walk_to_exit(room: Node, max_seconds: float) -> bool:
	for door in room.doors.values():
		door.set_open(true)
	await create_timer(1.0).timeout
	# Brother-sized navigation needs the open doors lifted clear; Nooni herself fits under them as they are.
	for door in room.doors.values():
		door.position.y += 3.0
	await physics_frame
	room.get_node("World").bake_navigation_mesh(false)
	for i in 3:
		await physics_frame
	for door in room.doors.values():
		door.position.y -= 3.0
	var map: RID = room.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, room.nooni.global_position, room.exit_position, true)
	if path.size() < 2:
		return false

	var index := 1
	var elapsed := 0.0
	Input.action_press("move_forward")
	while elapsed < max_seconds and not room._finished and index < path.size():
		await physics_frame
		elapsed += 1.0 / 60.0
		var to: Vector3 = path[index] - room.nooni.global_position
		to.y = 0.0
		if to.length() < 0.5:
			index += 1
			continue
		room.nooni._yaw = atan2(-to.x, -to.z)
	# Walk the last stretch straight at the pad.
	while elapsed < max_seconds and not room._finished:
		await physics_frame
		elapsed += 1.0 / 60.0
		var to: Vector3 = room.exit_position - room.nooni.global_position
		to.y = 0.0
		room.nooni._yaw = atan2(-to.x, -to.z)
	Input.action_release("move_forward")
	return room._won
