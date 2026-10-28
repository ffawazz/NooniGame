extends CharacterBody3D
## Shared by Nooni, Bruce and (later) Semba: third-person camera rig, mouse-look and possession.
## Exactly one playable character is "possessed" at a time (see CharacterSwitcher); the others stand
## where they were left, with input off, so Bruce can keep napping on a trap while Nooni sneaks.

const InputActions := preload("res://scripts/core/input_actions.gd")

## 0 = Nooni, 1 = Bruce, 2 = Semba. Matches the cat wheel's slice order.
@export var character_id := 0
@export var display_name := "Character"
## Pressure plates add up the weight of everything standing on them.
@export var weight := 1.0

@export_group("Camera")
@export var look_sensitivity := 0.003
@export var camera_distance := 3.2
@export var pivot_height := 1.5
@export var shoulder_offset := 0.5
@export var min_pitch_deg := -60.0
@export var max_pitch_deg := 25.0

## True only while this character is the one being played and the player has control.
var input_enabled := false
## Skips mouse capture (headless tests).
var test_mode := false

var _yaw := 0.0
var _pitch := -0.45
var _pivot: Node3D
var _camera: Camera3D


func _ready() -> void:
	InputActions.register()
	collision_layer = 2  # player side
	collision_mask = 1  # world
	add_to_group("playable")
	_yaw = rotation.y
	_build_camera()


func _build_camera() -> void:
	# top_level so the camera orbit doesn't rotate with the body.
	_pivot = Node3D.new()
	_pivot.top_level = true
	add_child(_pivot)

	var arm := SpringArm3D.new()
	arm.spring_length = camera_distance
	arm.margin = 0.2
	arm.collision_mask = 1
	_pivot.add_child(arm)

	_camera = Camera3D.new()
	_camera.h_offset = shoulder_offset
	arm.add_child(_camera)
	_update_pivot()


func get_camera() -> Camera3D:
	return _camera


## Take control. `make_camera_current` is false when a camera blend is about to hand the view over.
func possess(make_camera_current := true) -> void:
	input_enabled = true
	if make_camera_current:
		_camera.current = true
	if not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release() -> void:
	input_enabled = false


## Return false while the character is committed to something that must not be interrupted.
func can_release() -> bool:
	return true


func status_text() -> String:
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if test_mode or not input_enabled:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * look_sensitivity
		_pitch = clampf(
			_pitch - event.relative.y * look_sensitivity,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	_update_pivot()


func _update_pivot() -> void:
	if _pivot == null:
		return
	_pivot.global_position = global_position + Vector3.UP * pivot_height
	_pivot.global_rotation = Vector3(_pitch, _yaw, 0.0)
