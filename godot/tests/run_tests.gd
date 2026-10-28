extends SceneTree
## Headless checks:  godot --headless --path godot -s res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.

const VisionMath := preload("res://scripts/ai/vision_math.gd")
const RoomScene := preload("res://scenes/main.tscn")

var failures := 0


func _initialize() -> void:
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

	room.yasser.hold_position = true
	room.yasser.global_position = yasser_pos
	room.yasser.rotation.y = yasser_yaw
	room.nooni.global_position = nooni_pos
	room.nooni.set_crouching_instant(crouch)

	await create_timer(2.5).timeout
	_check(room.yasser.is_caught() == expect_caught, label)

	room.queue_free()
	await process_frame
