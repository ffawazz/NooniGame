extends SceneTree
## Headless checks:  godot --headless --path godot -s res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.

const VisionMath := preload("res://scripts/ai/vision_math.gd")
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
