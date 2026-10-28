extends "res://scripts/characters/playable_character.gd"
## Nooni on foot: camera-relative movement, toggled crouch-stealth, mouse-look third-person camera.
## The scene origin is at her feet. Built entirely in code, so the room scene stays tiny.
##
## Stealth (read by BrotherAI through get_visibility()):
##   standing               -> 1.0
##   crouched in the open   -> crouched_visibility, plus up to stress_visibility_penalty when stressed
##   crouched inside cover  -> 0.0 (hidden)

const Game := preload("res://scripts/core/game.gd")
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

@export_group("Grapple")
@export var grapple_aim_degrees := 9.0
@export var grapple_speed := 20.0
@export var grapple_cooldown_seconds := 1.2

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
## The grapple hook under the crosshair, if any (aim the camera at it, then click).
var grapple_target: Node
var grapple_cooldown_left := 0.0

var _zipping := false
var _zip_t := 0.0
var _zip_duration := 0.5
var _zip_from := Vector3.ZERO
var _zip_to := Vector3.ZERO
var _zip_anchor: Node
var _rope: MeshInstance3D
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

	_rope = MeshInstance3D.new()
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 0.02
	rope_mesh.bottom_radius = 0.02
	rope_mesh.height = 1.0
	_rope.mesh = rope_mesh
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.85, 0.85, 0.9)
	rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rope.material_override = rope_mat
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)

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
	grapple_cooldown_left = maxf(0.0, grapple_cooldown_left - delta)
	if _zipping:
		_tick_zip(delta)
		_animate(delta)
		return
	_update_grapple_target()

	var move_input := Vector2.ZERO
	var sprint := false
	var jump := false

	if input_enabled:
		if Input.is_action_just_pressed("crouch"):
			_toggle_crouch()
		if Input.is_action_just_pressed("wipe_glasses"):
			stress.wipe()
		if Input.is_action_just_pressed("grapple"):
			try_grapple()
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


# ---- Grapple -------------------------------------------------------------------------

## The best hook near the crosshair that is in range and not behind a wall, or null.
func _update_grapple_target() -> void:
	var best: Node = null
	if input_enabled and grapple_cooldown_left <= 0.0:
		var cam := get_camera()
		var from := cam.global_position
		var forward := -cam.global_transform.basis.z
		var chest := global_position + Vector3.UP * 1.2
		var best_angle := deg_to_rad(grapple_aim_degrees)
		for anchor in get_tree().get_nodes_in_group("grapple_anchor"):
			var to: Vector3 = anchor.global_position - from
			if to.length() < 1.5 or chest.distance_to(anchor.global_position) > anchor.max_range:
				continue
			var angle := forward.angle_to(to)
			if angle > best_angle:
				continue
			# Line of sight to just short of the hook (it sits on a surface).
			var stop: Vector3 = anchor.global_position - (anchor.global_position - chest).normalized() * 0.2
			var query := PhysicsRayQueryParameters3D.create(chest, stop, 1)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			best = anchor
			best_angle = angle
	if best != grapple_target:
		if grapple_target:
			grapple_target.set_targeted(false)
		grapple_target = best
		if grapple_target:
			grapple_target.set_targeted(true)


func try_grapple() -> bool:
	if grapple_target == null or _zipping or grapple_cooldown_left > 0.0:
		return false
	_zip_anchor = grapple_target
	_zip_from = global_position
	_zip_to = _zip_anchor.landing
	_zip_duration = clampf(_zip_from.distance_to(_zip_to) / grapple_speed, 0.25, 1.2)
	_zip_t = 0.0
	_zipping = true
	velocity = Vector3.ZERO
	set_crouching_instant(false)
	_rope.visible = true
	Game.sfx("grapple_fire")
	return true


func _tick_zip(delta: float) -> void:
	_zip_t = minf(1.0, _zip_t + delta / _zip_duration)
	var k := _zip_t * _zip_t * (3.0 - 2.0 * _zip_t)
	global_position = _zip_from.lerp(_zip_to, k) + Vector3.UP * sin(k * PI) * 0.6

	var heading := _zip_to - _zip_from
	heading.y = 0.0
	if heading.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-heading.x, -heading.z), minf(1.0, 14.0 * delta))
	_update_rope()

	if _zip_t >= 1.0:
		_zipping = false
		_rope.visible = false
		global_position = _zip_to
		velocity = Vector3.ZERO
		grapple_cooldown_left = grapple_cooldown_seconds
		Game.sfx("grapple_land")


## Stretch the rope cylinder from her chest to the hook.
func _update_rope() -> void:
	var a := global_position + Vector3.UP * 1.2
	var b: Vector3 = _zip_anchor.global_position
	var along := b - a
	var length := along.length()
	if length < 0.01:
		return
	var y := along / length
	var x := y.cross(Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var z := x.cross(y)
	_rope.global_transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)


func can_release() -> bool:
	return not _zipping


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

