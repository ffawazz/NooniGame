extends "res://scripts/characters/playable_character.gd"
## Semba (Ash): a hyperactive grey British street cat with a Lion King complex.
##  - Fast, with a double jump, so he can parkour over furniture.
##  - Climbs curtains and bookshelves (Climbable zones): push toward the surface, then climb with the
##    forward key; Space kicks off. Reaching the top lands him on top.
##  - Mighty Roar (ability key), only from a high point (feet above roar_min_height): every brother in the
##    room is drawn to the spot below him for lure_seconds. Brothers still have eyes, so Nooni should stay
##    out of sight while they cross the room.
## Brothers never "see" cats, so Semba is not detectable.

const Game := preload("res://scripts/core/game.gd")
const Toon := preload("res://scripts/core/toon.gd")
const Climbable := preload("res://scripts/puzzle/climbable.gd")

signal roared(position: Vector3)

enum State { NORMAL, CLIMBING, ROARING }

@export_group("Movement")
@export var run_speed := 5.5
@export var turn_speed := 16.0
@export var jump_height := 1.1
@export var air_jumps := 1
@export var gravity := 22.0
@export var climb_speed := 3.0

@export_group("Mighty Roar")
@export var roar_min_height := 1.4
@export var roar_seconds := 1.2
@export var roar_cooldown_seconds := 6.0
@export var lure_seconds := 7.0

var state := State.NORMAL

var _climbable: Node
var _near_climbable := false
var _air_jumps_left := 0
var _roar_timer := 0.0
var _roar_cooldown := 0.0
var _time := 0.0
var _pose := 0.0  # smoothed pitch of the body: climbing and roaring tilt his head up
var _visual: Node3D
var _roar_label: Label3D


func _init() -> void:
	display_name = "Semba"
	character_id = 2
	weight = 0.5
	camera_distance = 2.4
	pivot_height = 0.75
	shoulder_offset = 0.3


func _ready() -> void:
	super()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 0.6
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.3
	add_child(collision)

	_visual = Node3D.new()  # origin at his belly
	_visual.position.y = 0.32
	add_child(_visual)
	_build_look()

	_roar_label = Label3D.new()
	_roar_label.text = "ROOOAR!"
	_roar_label.font_size = 96
	_roar_label.pixel_size = 0.006
	_roar_label.outline_size = 18
	_roar_label.modulate = Color(1.0, 0.85, 0.3)
	_roar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_roar_label.no_depth_test = true
	_roar_label.position = Vector3(0, 1.3, 0)
	_roar_label.visible = false
	add_child(_roar_label)


## Forward is -Z: face and mane on -Z, tail on +Z.
func _build_look() -> void:
	var fur := Color(0.58, 0.61, 0.69)
	var stripe := Color(0.36, 0.38, 0.45)
	var mane := Color(0.82, 0.48, 0.2)

	var body := Toon.sphere(_visual, 0.26, Vector3.ZERO, fur)
	body.scale = Vector3(0.85, 0.8, 1.55)
	for z in [-0.14, 0.02, 0.18]:  # tabby stripes
		var band := Toon.box(_visual, Vector3(0.36, 0.03, 0.06), Vector3(0, 0.2, z), stripe, 0.0)
		band.rotation_degrees = Vector3(-8, 0, 0)
	var chest := Toon.sphere(_visual, 0.12, Vector3(0, -0.02, -0.36), Color(0.95, 0.95, 0.97), 0.0)
	chest.scale = Vector3(0.9, 1.0, 0.45)

	var head_pos := Vector3(0, 0.2, -0.44)
	Toon.sphere(_visual, 0.2, head_pos, fur)
	# The mane: a ring of fluff behind and around his head, because he is a lion.
	for k in 8:
		var a := TAU * k / 8.0
		Toon.sphere(_visual, 0.1, head_pos + Vector3(cos(a) * 0.21, sin(a) * 0.21, 0.08), mane, 0.015)
	for side in [-1.0, 1.0]:
		var ear := Toon.cylinder(_visual, 0.08, 0.2, head_pos + Vector3(0.13 * side, 0.22, 0.02), fur, 0.015, 0.0)
		ear.rotation_degrees = Vector3(0, 0, -10.0 * side)
		Toon.sphere(_visual, 0.04, head_pos + Vector3(0.085 * side, 0.04, -0.17), Color(0.95, 0.7, 0.1), 0.0)  # eyes
	Toon.sphere(_visual, 0.03, head_pos + Vector3(0, -0.03, -0.2), Color(0.95, 0.55, 0.65), 0.0)  # nose

	var tail := Toon.capsule(_visual, 0.045, 0.6, Vector3(0, 0.3, 0.5), fur, 0.015)
	tail.rotation_degrees = Vector3(50, 0, 0)
	Toon.sphere(_visual, 0.075, Vector3(0, 0.55, 0.72), mane, 0.015)  # lion tail tuft

	for x in [-0.13, 0.13]:
		for z in [-0.26, 0.28]:
			Toon.sphere(_visual, 0.075, Vector3(x, -0.26, z), stripe, 0.015)


func _physics_process(delta: float) -> void:
	_time += delta
	_roar_cooldown = maxf(0.0, _roar_cooldown - delta)
	match state:
		State.NORMAL:
			_tick_normal(delta)
		State.CLIMBING:
			_tick_climbing()
		State.ROARING:
			_tick_roaring(delta)
	_animate(delta)


func _read_move() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back") if input_enabled else Vector2.ZERO


func _tick_normal(delta: float) -> void:
	var move_input := _read_move()
	var dir := Basis(Vector3.UP, _yaw) * Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	velocity.x = dir.x * run_speed
	velocity.z = dir.z * run_speed

	if is_on_floor():
		velocity.y = 0.0
		_air_jumps_left = air_jumps
	else:
		velocity.y -= gravity * delta

	if input_enabled and Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = sqrt(2.0 * gravity * jump_height)
		elif _air_jumps_left > 0:
			_air_jumps_left -= 1
			velocity.y = sqrt(2.0 * gravity * jump_height)

	if input_enabled and Input.is_action_just_pressed("ability"):
		try_roar()

	move_and_slide()

	if dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, turn_speed * delta))

	# Grab a climbable by pushing toward it.
	var spot := Climbable.find(get_tree(), global_position + Vector3.UP * 0.3)
	_near_climbable = spot != null
	if spot and dir.length() > 0.1 and dir.normalized().dot(spot.wall_direction) > 0.5:
		start_climb(spot)


# ---- Climbing ------------------------------------------------------------------------

func start_climb(spot: Node) -> void:
	state = State.CLIMBING
	_climbable = spot
	velocity = Vector3.ZERO
	rotation.y = atan2(-spot.wall_direction.x, -spot.wall_direction.z)


func _tick_climbing() -> void:
	var up := -_read_move().y  # forward key = up
	velocity = Vector3(0.0, up * climb_speed, 0.0)
	move_and_slide()

	if input_enabled and Input.is_action_just_pressed("jump"):
		# Kick off the wall.
		velocity = -_climbable.wall_direction * 4.0 + Vector3.UP * 3.0
		state = State.NORMAL
	elif up > 0.1 and global_position.y + 0.3 >= _climbable.top_y:
		global_position = _climbable.landing
		velocity = Vector3.ZERO
		state = State.NORMAL
	elif up < -0.1 and is_on_floor():
		state = State.NORMAL
	elif not _climbable.contains(global_position + Vector3.UP * 0.3):
		state = State.NORMAL  # drifted off the surface


# ---- Mighty Roar ---------------------------------------------------------------------

func can_roar() -> bool:
	return state == State.NORMAL and _roar_cooldown <= 0.0 and global_position.y >= roar_min_height


## Yowl from a high point; every brother in the room is drawn to the spot below. Returns false if he can't.
func try_roar() -> bool:
	if not can_roar():
		return false
	state = State.ROARING
	_roar_timer = roar_seconds
	_roar_cooldown = roar_cooldown_seconds
	for brother in get_tree().get_nodes_in_group("brother"):
		brother.lure(global_position, lure_seconds)
	roared.emit(global_position)
	Game.sfx("roar")
	_spawn_shockwave()
	return true


func _tick_roaring(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	_roar_timer -= delta
	if _roar_timer <= 0.0:
		state = State.NORMAL


func can_release() -> bool:
	return state != State.ROARING


func _spawn_shockwave() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.top_level = true
	add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.1
	ring.scale = Vector3.ONE * 0.4

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 7.0, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.1)
	tween.chain().tween_callback(ring.queue_free)


# ---- Look and feel -------------------------------------------------------------------

func _animate(delta: float) -> void:
	var target_pose := 0.0
	if state == State.CLIMBING:
		target_pose = 1.3
	elif state == State.ROARING:
		target_pose = 0.6
	_pose = lerpf(_pose, target_pose, minf(1.0, 10.0 * delta))
	_visual.rotation.x = _pose

	var speed := Vector2(velocity.x, velocity.z).length()
	var bob := sin(_time * 14.0) * 0.03 * clampf(speed / run_speed, 0.0, 1.0)
	var shake := sin(_time * 40.0) * 0.015 if state == State.ROARING else 0.0
	_visual.position.y = 0.32 + bob
	_visual.position.x = shake

	_roar_label.visible = state == State.ROARING
	_roar_label.scale = Vector3.ONE * (1.0 + 0.12 * sin(_time * 18.0))


func state_name() -> String:
	match state:
		State.CLIMBING:
			return "Climbing"
		State.ROARING:
			return "ROARING"
		_:
			if _roar_cooldown > 0.0:
				return "Hoarse (%.0fs)" % _roar_cooldown
			return "Roar ready" if global_position.y >= roar_min_height else "Climb higher to roar"


func status_text() -> String:
	var hint := ""
	if state == State.NORMAL and _near_climbable:
		hint = "  [push toward it to climb]"
	return "Semba: %s (Q: Mighty Roar)%s" % [state_name(), hint]
