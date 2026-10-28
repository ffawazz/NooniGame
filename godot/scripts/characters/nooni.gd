extends "res://scripts/characters/playable_character.gd"
## Nooni on foot: camera-relative movement, toggled crouch-stealth, mouse-look third-person camera.
## The scene origin is at her feet. Built entirely in code, so the room scene stays tiny.
##
## Stealth (read by BrotherAI through get_visibility()):
##   standing               -> 1.0
##   crouched in the open   -> crouched_visibility, plus up to stress_visibility_penalty when stressed
##   crouched inside cover  -> 0.0 (hidden)

const CoverVolume := preload("res://scripts/stealth/cover_volume.gd")
const Toon := preload("res://scripts/core/toon.gd")
const StressMeter := preload("res://scripts/stealth/stress_meter.gd")
const DetectiveVision := preload("res://scripts/stealth/detective_vision.gd")
const Hackable := preload("res://scripts/puzzle/hackable.gd")

@export_group("Movement")
@export var walk_speed := 3.5
@export var sprint_speed := 6.0
@export var crouch_speed := 1.6
@export var turn_speed := 14.0
@export var jump_height := 0.9
@export var gravity := 20.0

@export_group("Body")
@export var body_radius := 0.35
@export var stand_height := 1.8
@export var crouch_height := 1.0
@export var crouch_transition_speed := 6.0
@export_range(0.0, 1.0) var crouched_visibility := 0.5
## Extra visibility when crouched in the open and fully stressed: shaky hands make her sloppy at hiding.
@export_range(0.0, 1.0) var stress_visibility_penalty := 0.3

var crouching := false
## Her stress meter and glasses smudge (see stress_meter.gd). Wipe with the R key.
var stress: Node
## Detective Vision (hold right mouse); hack gadgets with E while it is on.
var vision: Node
var current_height := 1.8

var _shape: CapsuleShape3D
var _collision: CollisionShape3D
var _visual: Node3D  # everything drawn; squashed when crouching
var _cape_pivot: Node3D
var _hair_long: Node3D
var _bun: Node3D
var _cape_tilt := 0.0
var _time := 0.0
var _headroom_shape: CapsuleShape3D


func _init() -> void:
	display_name = "Nooni"
	character_id = 0
	weight = 1.0


func _ready() -> void:
	super()
	add_to_group("detectable")
	current_height = stand_height
	_build_body()

	stress = StressMeter.new()
	stress.name = "StressMeter"
	stress.character = self
	add_child(stress)

	vision = DetectiveVision.new()
	vision.name = "DetectiveVision"
	vision.character = self
	add_child(vision)


func _build_body() -> void:
	_shape = CapsuleShape3D.new()
	_shape.radius = body_radius
	_shape.height = stand_height
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	add_child(_collision)

	_headroom_shape = CapsuleShape3D.new()
	_headroom_shape.radius = body_radius * 0.9
	_headroom_shape.height = stand_height

	_visual = Node3D.new()
	add_child(_visual)
	_build_look()
	_apply_height()


## Cel-shaded Nooni from primitives. Forward is -Z, so the face and glasses sit on -Z and the hair and cape on +Z.
func _build_look() -> void:
	var abaya := Color(0.16, 0.17, 0.32)
	var skin := Color(0.93, 0.74, 0.6)
	var hair := Color(0.2, 0.1, 0.07)

	Toon.capsule(_visual, 0.3, 1.3, Vector3(0, 0.65, 0), abaya)
	# The abaya hangs open: a cream dress shows down the front.
	Toon.box(_visual, Vector3(0.22, 1.0, 0.03), Vector3(0, 0.62, -0.285), Color(0.96, 0.92, 0.82), 0.015)

	Toon.sphere(_visual, 0.24, Vector3(0, 1.55, 0), skin)
	Toon.sphere(_visual, 0.26, Vector3(0, 1.6, 0.07), hair)  # hair on top and behind the head

	# Glasses (two rings and a bridge) on the face.
	var frame := Color(0.1, 0.08, 0.12)
	for side in [-1.0, 1.0]:
		var ring := Toon.torus(_visual, 0.045, 0.07, Vector3(0.095 * side, 1.56, -0.225), frame, 0.0)
		ring.rotation_degrees = Vector3(90, 0, 0)
	Toon.box(_visual, Vector3(0.05, 0.02, 0.02), Vector3(0, 1.57, -0.235), frame, 0.0)

	# Long curly hair down her back, tied up into a bun when she crouches.
	_hair_long = Node3D.new()
	_visual.add_child(_hair_long)
	var strands := [
		[Vector3(0.0, 1.38, 0.24), 0.17], [Vector3(-0.14, 1.28, 0.22), 0.12], [Vector3(0.14, 1.28, 0.22), 0.12],
		[Vector3(-0.06, 1.12, 0.25), 0.13], [Vector3(0.08, 1.05, 0.25), 0.12],
	]
	for strand in strands:
		Toon.sphere(_hair_long, strand[1], strand[0], hair, 0.02)
	_bun = Node3D.new()
	_visual.add_child(_bun)
	Toon.sphere(_bun, 0.13, Vector3(0, 1.88, 0.08), hair, 0.02)
	_bun.visible = false

	# Cape-like open abaya trailing behind; its tilt follows her speed.
	_cape_pivot = Node3D.new()
	_cape_pivot.position = Vector3(0, 1.28, 0.3)
	_visual.add_child(_cape_pivot)
	Toon.box(_cape_pivot, Vector3(0.7, 1.15, 0.04), Vector3(0, -0.575, 0.03), abaya, 0.02)


func _physics_process(delta: float) -> void:
	var move_input := Vector2.ZERO
	var sprint := false
	var jump := false

	if input_enabled:
		if Input.is_action_just_pressed("crouch"):
			_toggle_crouch()
		if Input.is_action_just_pressed("wipe_glasses"):
			stress.wipe()
		if vision.active and Input.is_action_just_pressed("interact"):
			Hackable.try_hack(get_tree(), global_position)
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		sprint = Input.is_action_pressed("sprint")
		jump = Input.is_action_just_pressed("jump")

	var dir := Basis(Vector3.UP, _yaw) * Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	var speed := crouch_speed if crouching else (sprint_speed if sprint else walk_speed)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if is_on_floor():
		velocity.y = 0.0
		if jump and not crouching:
			velocity.y = sqrt(2.0 * gravity * jump_height)
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	if dir.length_squared() > 0.01:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, turn_speed * delta))

	var target_height := crouch_height if crouching else stand_height
	current_height = move_toward(current_height, target_height, crouch_transition_speed * delta)
	_apply_height()
	_animate(delta)


## Cape streams out behind her as she speeds up; long hair becomes a bun while crouched.
func _animate(delta: float) -> void:
	_time += delta
	var speed := Vector2(velocity.x, velocity.z).length()
	var flutter := sin(_time * 9.0) * 0.06 * clampf(speed / 3.0, 0.0, 1.0)
	var target := clampf(speed * 0.1, 0.0, 0.6) + flutter + 0.04
	_cape_tilt = lerpf(_cape_tilt, target, minf(1.0, 8.0 * delta))
	_cape_pivot.rotation.x = -_cape_tilt
	_hair_long.visible = not crouching
	_bun.visible = crouching


func _toggle_crouch() -> void:
	if not crouching:
		crouching = true
	elif _has_headroom():
		crouching = false


## Can she stand up here without her head going through the sofa?
func _has_headroom() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _headroom_shape
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (stand_height * 0.5 + 0.05))
	params.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Resize the capsule with the feet pinned at y = 0 and squash the drawn figure to match.
func _apply_height() -> void:
	_shape.height = current_height
	_collision.position.y = current_height * 0.5
	_visual.scale.y = current_height / stand_height


func set_crouching_instant(on: bool) -> void:
	crouching = on
	current_height = crouch_height if on else stand_height
	_apply_height()


# ---- Detectable interface (duck-typed; BrotherAI looks in the "detectable" group) ----

func get_detection_point() -> Vector3:
	return global_position + Vector3.UP * (current_height * 0.6)


func is_in_cover() -> bool:
	return CoverVolume.is_covered(get_tree(), global_position + Vector3.UP * 0.5)


func get_visibility() -> float:
	if not crouching:
		return 1.0
	if is_in_cover():
		return 0.0
	return minf(1.0, crouched_visibility + stress.value * stress_visibility_penalty)


func status_text() -> String:
	if not crouching:
		return "STANDING (visible)"
	return "HIDDEN (crouched in cover)" if is_in_cover() else "CROUCHED (exposed)"

