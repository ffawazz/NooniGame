extends "res://scripts/characters/playable_character.gd"
## Bruce: a fat black cat who thinks he is Batman. Slow, heavy tank.
##  - Weighs 3, so he alone can hold down heavy pressure plates.
##  - Bat-Nap (ability key): he flops on the floor. If a brother walks within nap_radius, that brother is
##    forced into a pet_seconds petting animation and freezes in place. The nap stays armed while you
##    play someone else, so Bruce makes a trap that Nooni can sneak past.
## Brothers never "see" cats, so Bruce is not detectable.

const Toon := preload("res://scripts/core/toon.gd")

enum State { NORMAL, NAPPING, PURRING, COOLDOWN }

@export_group("Movement")
@export var walk_speed := 1.9
@export var turn_speed := 8.0
@export var jump_height := 0.3
@export var gravity := 20.0

@export_group("Bat-Nap")
@export var nap_radius := 1.6
@export var pet_seconds := 10.0
@export var cooldown_seconds := 3.0

var state := State.NORMAL

var _timer := 0.0
var _flop := 0.0  # 0 = standing, 1 = flopped on his side
var _bob_time := 0.0
var _visual: Node3D
var _zzz: Label3D


func _init() -> void:
	display_name = "Bruce"
	character_id = 1
	weight = 3.0
	camera_distance = 2.6
	pivot_height = 0.9
	shoulder_offset = 0.35


func _ready() -> void:
	super()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 0.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.4
	add_child(collision)

	_visual = Node3D.new()  # origin at his belly, so flopping rotates him about his middle
	_visual.position.y = 0.45
	add_child(_visual)
	_build_look()

	_zzz = Label3D.new()
	_zzz.text = "z Z z"
	_zzz.font_size = 72
	_zzz.pixel_size = 0.008
	_zzz.outline_size = 14
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.no_depth_test = true
	_zzz.position = Vector3(0, 1.2, 0)
	_zzz.visible = false
	add_child(_zzz)


## Forward is -Z: face, chest emblem and ears on -Z; tail and cape on +Z.
func _build_look() -> void:
	var fur := Color(0.2, 0.2, 0.3)
	var gold := Color(1.0, 0.85, 0.2)

	var body := Toon.sphere(_visual, 0.42, Vector3.ZERO, fur)
	body.scale = Vector3(1.05, 0.85, 1.3)
	Toon.sphere(_visual, 0.27, Vector3(0, 0.26, -0.55), fur)  # head

	# Pointed cowl ears.
	for side in [-1.0, 1.0]:
		var ear := Toon.cylinder(_visual, 0.1, 0.3, Vector3(0.15 * side, 0.58, -0.52), fur, 0.02, 0.0)
		ear.rotation_degrees = Vector3(0, 0, -12.0 * side)
		Toon.sphere(_visual, 0.045, Vector3(0.1 * side, 0.33, -0.78), gold, 0.0)  # eyes
	Toon.sphere(_visual, 0.035, Vector3(0, 0.24, -0.8), Color(0.95, 0.55, 0.65), 0.0)  # nose

	# Bat emblem on the chest and a little cape.
	var emblem := Toon.sphere(_visual, 0.09, Vector3(0, 0.03, -0.53), gold, 0.0)
	emblem.scale = Vector3(1.6, 0.9, 0.35)
	var cape := Toon.box(_visual, Vector3(0.55, 0.32, 0.03), Vector3(0, 0.15, 0.52), Color(0.3, 0.18, 0.42), 0.02)
	cape.rotation_degrees = Vector3(-22, 0, 0)

	var tail := Toon.capsule(_visual, 0.06, 0.6, Vector3(0, 0.3, 0.75), fur, 0.02)
	tail.rotation_degrees = Vector3(40, 0, 0)

	for x in [-0.22, 0.22]:
		for z in [-0.32, 0.34]:
			Toon.sphere(_visual, 0.11, Vector3(x, -0.38, z), Color(0.13, 0.13, 0.2), 0.02)


func _physics_process(delta: float) -> void:
	var move_input := Vector2.ZERO
	var jump := false

	if input_enabled and Input.is_action_just_pressed("ability"):
		_on_ability()

	var can_move := state == State.NORMAL or state == State.COOLDOWN
	if input_enabled and can_move:
		move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		jump = Input.is_action_just_pressed("jump")

	var dir := Basis(Vector3.UP, _yaw) * Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	if is_on_floor():
		velocity.y = 0.0
		if jump:
			velocity.y = sqrt(2.0 * gravity * jump_height)
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	if dir.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, turn_speed * delta))

	_tick_state(delta)
	_animate(delta)


# ---- Bat-Nap -------------------------------------------------------------------------

func _on_ability() -> void:
	if state == State.NORMAL:
		start_nap()
	elif state == State.NAPPING:
		state = State.NORMAL  # changed his mind


## Flop onto the floor and wait for a brother to wander past. Returns false if he can't right now.
func start_nap() -> bool:
	if state != State.NORMAL:
		return false
	state = State.NAPPING
	return true


func _tick_state(delta: float) -> void:
	match state:
		State.NAPPING:
			for brother in get_tree().get_nodes_in_group("brother"):
				var flat: Vector3 = brother.global_position - global_position
				flat.y = 0.0
				if flat.length() <= nap_radius and brother.can_be_petted():
					brother.pet(pet_seconds)
					state = State.PURRING
					_timer = pet_seconds
					break
		State.PURRING:
			_timer -= delta
			if _timer <= 0.0:
				state = State.COOLDOWN
				_timer = cooldown_seconds
		State.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.NORMAL


func _animate(delta: float) -> void:
	_bob_time += delta
	var flopped := state == State.NAPPING or state == State.PURRING
	_flop = move_toward(_flop, 1.0 if flopped else 0.0, 3.0 * delta)
	_visual.rotation.z = _flop * 1.5
	var speed := Vector2(velocity.x, velocity.z).length()
	var bob := sin(_bob_time * 8.0) * 0.025 * clampf(speed / walk_speed, 0.0, 1.0)
	_visual.position.y = lerpf(0.45, 0.32, _flop) + bob
	_zzz.visible = flopped and _flop > 0.8
	_zzz.position.y = 1.2 + sin(_bob_time * 2.0) * 0.05


func state_name() -> String:
	match state:
		State.NAPPING:
			return "Bat-Nap armed"
		State.PURRING:
			return "Purring"
		State.COOLDOWN:
			return "Recovering"
		_:
			return "Ready"


func status_text() -> String:
	return "Bruce: %s (Q: Bat-Nap)" % state_name()
