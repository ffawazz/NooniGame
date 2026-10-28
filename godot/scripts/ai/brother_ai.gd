extends CharacterBody3D
## Yasser / Ahmed. Patrols waypoints on a navmesh with a vision cone.
##
## Detection: a target is perceived when it is inside the cone, within (view_distance * its visibility)
## and a ray from the eyes reaches it without touching the world layer. While perceived, awareness
## fills (faster when close); otherwise it drains. Awareness reaching 1 = caught.
##
## States: PATROL -> SUSPICIOUS (sees her, stops and stares) -> INVESTIGATE (lost her, walks to the last
## seen spot and looks around) -> back to PATROL. CAUGHT is terminal.

const VisionMath := preload("res://scripts/ai/vision_math.gd")

signal caught(brother)

enum State { PATROL, SUSPICIOUS, INVESTIGATE, CAUGHT }

@export_group("Patrol")
@export var patrol_speed := 1.8
@export var wait_at_point := 1.5

@export_group("Vision")
@export var view_distance := 9.0
@export var view_angle := 90.0  ## Total cone width, degrees.
@export var eye_height := 1.6

@export_group("Detection")
@export var detection_seconds := 1.2
@export var awareness_decay_seconds := 3.0

@export_group("Investigate")
@export var investigate_speed := 3.0
@export var look_around_seconds := 2.5
@export var look_around_deg_per_sec := 90.0
@export var stare_turn_speed := 6.0

var patrol_points: Array[Vector3] = []
## Stand still (tests, or a brother who is just watching TV).
var hold_position := false
var show_cone := true

var state := State.PATROL
var awareness := 0.0
var can_see_target := false

var _agent: NavigationAgent3D
var _lamp: StandardMaterial3D
var _cone: MeshInstance3D
var _cone_mesh: ImmediateMesh
var _running := false
var _patrol_index := 0
var _waiting := false
var _wait_timer := 0.0
var _look_timer := 0.0
var _arrived := false
var _last_known := Vector3.ZERO


func _ready() -> void:
	collision_layer = 4  # brother
	collision_mask = 1  # world
	_build_body()

	# Wait for the navigation map to sync with the baked region before asking for paths.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_running = true
	_enter(State.PATROL)


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.9
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.95
	add_child(collision)

	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.9
	body.mesh = mesh
	body.position.y = 0.95
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.35, 0.3)
	body.material_override = body_mat
	add_child(body)

	# Lamp on the forward (-Z) side: also the alert indicator.
	var lamp_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.2, 0.3)
	lamp_mesh.mesh = box
	lamp_mesh.position = Vector3(0.0, eye_height - 0.2, -0.5)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color.GREEN
	lamp_mesh.material_override = _lamp
	add_child(lamp_mesh)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.7  # navmesh floats ~0.4 m above the floor, so be generous
	_agent.target_desired_distance = 0.7
	_agent.radius = 0.5
	_agent.height = 1.9
	add_child(_agent)

	_cone_mesh = ImmediateMesh.new()
	_cone = MeshInstance3D.new()
	_cone.mesh = _cone_mesh
	_cone.top_level = true
	var cone_mat := StandardMaterial3D.new()
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.vertex_color_use_as_albedo = true
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone.material_override = cone_mat
	add_child(_cone)


func _physics_process(delta: float) -> void:
	if not _running:
		return

	if state != State.CAUGHT:
		_update_perception(delta)
		if awareness >= 1.0:
			_enter(State.CAUGHT)

	match state:
		State.PATROL:
			_tick_patrol(delta)
		State.SUSPICIOUS:
			_tick_suspicious(delta)
		State.INVESTIGATE:
			_tick_investigate(delta)
		State.CAUGHT:
			_stop(delta)

	_update_cone()


func is_caught() -> bool:
	return state == State.CAUGHT


func state_name() -> String:
	match state:
		State.PATROL:
			return "Patrol"
		State.SUSPICIOUS:
			return "Suspicious"
		State.INVESTIGATE:
			return "Investigating"
		_:
			return "CAUGHT"


# ---- Perception ----------------------------------------------------------------------

func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * eye_height


func _forward() -> Vector3:
	return -global_transform.basis.z


func _update_perception(delta: float) -> void:
	var best := 0.0
	var seen_at := Vector3.ZERO
	for target in get_tree().get_nodes_in_group("detectable"):
		var strength := _perceive(target)
		if strength > best:
			best = strength
			seen_at = target.global_position

	can_see_target = best > 0.0
	if can_see_target:
		awareness = minf(1.0, awareness + best * delta / detection_seconds)
		_last_known = seen_at
	else:
		awareness = maxf(0.0, awareness - delta / awareness_decay_seconds)


## 0 = not perceived, otherwise a fill-rate multiplier in [1, 2] (closer = faster).
func _perceive(target: Node3D) -> float:
	var visibility: float = target.get_visibility()
	if visibility <= 0.0:
		return 0.0

	var view_range := view_distance * visibility
	var eye := get_eye_position()
	var point: Vector3 = target.get_detection_point()

	if not VisionMath.in_cone(eye, _forward(), point, view_range, view_angle):
		return 0.0

	# Only the world layer blocks sight; characters live on other layers.
	var query := PhysicsRayQueryParameters3D.create(eye, point, 1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return 0.0

	return 1.0 + (1.0 - eye.distance_to(point) / view_range)


# ---- State machine -------------------------------------------------------------------

func _enter(next: State) -> void:
	state = next
	match next:
		State.PATROL:
			_lamp.albedo_color = Color.GREEN
			_waiting = false
			_goto_current_patrol_point()
		State.SUSPICIOUS:
			_lamp.albedo_color = Color.YELLOW
		State.INVESTIGATE:
			_lamp.albedo_color = Color(1.0, 0.55, 0.0)
			_agent.target_position = _last_known
			_arrived = false
			_look_timer = look_around_seconds
		State.CAUGHT:
			_lamp.albedo_color = Color.RED
			caught.emit(self)


func _tick_patrol(delta: float) -> void:
	if can_see_target:
		_enter(State.SUSPICIOUS)
		return
	if hold_position or patrol_points.is_empty():
		_stop(delta)
		return

	if _waiting:
		_stop(delta)
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_waiting = false
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
			_goto_current_patrol_point()
	elif _agent.is_navigation_finished():
		_waiting = true
		_wait_timer = wait_at_point
	else:
		_move_along_path(patrol_speed, delta)


func _tick_suspicious(delta: float) -> void:
	_stop(delta)
	_face_point(_last_known, stare_turn_speed * delta)
	if not can_see_target:
		_enter(State.INVESTIGATE)


func _tick_investigate(delta: float) -> void:
	if can_see_target:
		_enter(State.SUSPICIOUS)
		return

	if not _arrived:
		if _agent.is_navigation_finished():
			_arrived = true
		else:
			_move_along_path(investigate_speed, delta)
		return

	_stop(delta)
	rotate_y(deg_to_rad(look_around_deg_per_sec) * delta)
	_look_timer -= delta
	if _look_timer <= 0.0:
		_enter(State.PATROL)


# ---- Movement helpers ----------------------------------------------------------------

func _goto_current_patrol_point() -> void:
	if not patrol_points.is_empty():
		_agent.target_position = patrol_points[_patrol_index]


func _move_along_path(speed: float, delta: float) -> void:
	var to := _agent.get_next_path_position() - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.01 else Vector3.ZERO
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_apply_gravity(delta)
	move_and_slide()
	if dir != Vector3.ZERO:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 8.0 * delta))


func _stop(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 20.0 * delta


func _face_point(point: Vector3, weight: float) -> void:
	var flat := point - global_position
	flat.y = 0.0
	if flat.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), minf(1.0, weight))


# ---- Debug cone ----------------------------------------------------------------------

## Translucent floor fan showing where he is looking (green -> red as awareness fills).
## Each ray stops at walls and tall furniture, like his actual line of sight.
func _update_cone() -> void:
	_cone.visible = show_cone
	if not show_cone:
		return

	var origin := global_position
	_cone.global_transform = Transform3D(Basis(Vector3.UP, rotation.y), origin + Vector3.UP * 0.03)
	var color := Color.GREEN.lerp(Color.RED, awareness)
	color.a = 0.18

	var space := get_world_3d().direct_space_state
	var ray_height := Vector3.UP * (eye_height * 0.75)
	var half := deg_to_rad(view_angle) * 0.5
	var segments := 16

	_cone_mesh.clear_surfaces()
	_cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := _cone_edge(space, origin + ray_height, -half)
	for i in range(1, segments + 1):
		var next := _cone_edge(space, origin + ray_height, lerpf(-half, half, float(i) / segments))
		_cone_mesh.surface_set_color(color)
		_cone_mesh.surface_add_vertex(Vector3.ZERO)
		_cone_mesh.surface_set_color(color)
		_cone_mesh.surface_add_vertex(previous)
		_cone_mesh.surface_set_color(color)
		_cone_mesh.surface_add_vertex(next)
		previous = next
	_cone_mesh.surface_end()


## Local-space (cone node) end point of one fan ray, shortened where it hits the world.
func _cone_edge(space: PhysicsDirectSpaceState3D, from: Vector3, angle: float) -> Vector3:
	var local := Vector3(sin(angle), 0.0, -cos(angle))
	var world_dir := Basis(Vector3.UP, rotation.y) * local
	var query := PhysicsRayQueryParameters3D.create(from, from + world_dir * view_distance, 1)
	var hit := space.intersect_ray(query)
	var length := view_distance
	if not hit.is_empty():
		length = from.distance_to(hit.position)
	return local * length
