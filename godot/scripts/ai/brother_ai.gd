extends CharacterBody3D
## Yasser / Ahmed. Patrols waypoints on a navmesh with a vision cone.
##
## Detection: a target is perceived when it is inside the cone, within (view_distance * its visibility)
## and a ray from the eyes reaches it without touching the world layer. While perceived, awareness
## fills (faster when close); otherwise it drains. Awareness reaching 1 = caught.
##
## States: PATROL -> SUSPICIOUS (sees her, stops and stares) -> INVESTIGATE (lost her, walks to the last
## seen spot and looks around) -> back to PATROL. CAUGHT is terminal. PETTED: Bruce's Bat-Nap froze him
## for a while; he ignores everything, then forgets what he was doing and resumes his patrol.
## LURED is INVESTIGATE with a flag: Semba's Mighty Roar sends him to the spot below the yowl to stare up.

const VisionMath := preload("res://scripts/ai/vision_math.gd")
const Toon := preload("res://scripts/core/toon.gd")

signal caught(brother)

enum State { PATROL, SUSPICIOUS, INVESTIGATE, CAUGHT, PETTED }

## Who this is. Sets his look and how sharp he is (see _apply_kind): yasser, ahmed, guard, professor.
@export var kind := "yasser"
var body_color := Color(0.82, 0.28, 0.27)
var hair_color := Color(0.12, 0.08, 0.07)

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
var _petted_timer := 0.0
var _lured := false
var _lure_reason := "a yowl"
var vision_scale := 1.0  ## Hacked lights out: his sight range is multiplied by this.
var _dark_timer := 0.0
var vision_on := false  ## Detective Vision is showing him.
var _assist_cones := true
var _xray: MeshInstance3D
var _xray_material: StandardMaterial3D
var _alert_label: Label3D
var _lure_seconds := 0.0
var _lure_source := Vector3.ZERO
var _hearts: Node3D


func _ready() -> void:
	_apply_kind()
	add_to_group("brother")
	add_to_group("vision_aware")
	var settings: Dictionary = (Engine.get_main_loop() as SceneTree).root.get_node("/root/GameState").settings
	_assist_cones = settings.get("assist_cones", 1.0) > 0.5
	collision_layer = 4  # brother
	collision_mask = 1  # world
	_build_body()

	# Wait for the navigation map to sync with the baked region before asking for paths.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_running = true
	if state != State.PETTED:
		_enter(State.PATROL)


## Per-character look and senses. Yasser keeps the defaults.
func _apply_kind() -> void:
	match kind:
		"ahmed":  # sharp-eyed, narrower view, quicker to notice
			body_color = Color(0.25, 0.45, 0.85)
			hair_color = Color(0.35, 0.2, 0.1)
			view_distance = 11.0
			view_angle = 70.0
			patrol_speed = 1.5
			detection_seconds = 1.0
			wait_at_point = 0.8
		"guard":  # campus security: wide view, brisk
			body_color = Color(0.32, 0.38, 0.32)
			hair_color = Color(0.1, 0.1, 0.1)
			view_distance = 8.0
			view_angle = 110.0
			patrol_speed = 2.2
			detection_seconds = 0.9
		"professor":  # absent-minded: slow, but sees a huge arc
			body_color = Color(0.55, 0.38, 0.65)
			hair_color = Color(0.75, 0.75, 0.78)
			view_distance = 7.0
			view_angle = 130.0
			patrol_speed = 1.1
			detection_seconds = 1.6
			wait_at_point = 2.5


func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.9
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.95
	add_child(collision)

	# Cel-shaded Yasser: red hoodie, dark hair, and a visor that doubles as the alert lamp.
	Toon.capsule(self, 0.48, 1.45, Vector3(0, 0.725, 0), body_color)
	Toon.sphere(self, 0.29, Vector3(0, 1.6, 0), Color(0.87, 0.66, 0.52))
	var hair := Toon.sphere(self, 0.31, Vector3(0, 1.68, 0.05), hair_color)
	hair.scale = Vector3(1.0, 0.8, 1.0)

	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.1, 0.1)
	visor.mesh = box
	visor.position = Vector3(0.0, eye_height - 0.02, -0.27)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color.GREEN
	_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visor.material_override = _lamp
	add_child(visor)

	var tag := Label3D.new()
	tag.text = name
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0, 2.15, 0)
	add_child(tag)

	# Detective Vision extras: a glowing silhouette that shows through walls, and a suspicion read-out.
	_xray = MeshInstance3D.new()
	var xray_mesh := CapsuleMesh.new()
	xray_mesh.radius = 0.52
	xray_mesh.height = 2.0
	_xray.mesh = xray_mesh
	_xray.position.y = 1.0
	_xray_material = StandardMaterial3D.new()
	_xray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_xray_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_xray_material.no_depth_test = true
	_xray_material.albedo_color = Color(0.3, 1.0, 0.6, 0.3)
	_xray.material_override = _xray_material
	_xray.visible = false
	add_child(_xray)

	_alert_label = Label3D.new()
	_alert_label.font_size = 56
	_alert_label.pixel_size = 0.007
	_alert_label.outline_size = 12
	_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_label.no_depth_test = true
	_alert_label.position = Vector3(0, 2.55, 0)
	_alert_label.visible = false
	add_child(_alert_label)

	# Hearts that orbit his head while he is being petted.
	_hearts = Node3D.new()
	_hearts.position = Vector3(0, 2.35, 0)
	_hearts.visible = false
	add_child(_hearts)
	for i in 3:
		var a := TAU * i / 3.0
		Toon.sphere(_hearts, 0.09, Vector3(sin(a), 0.0, cos(a)) * 0.35, Color(1.0, 0.45, 0.7), 0.015)

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

	if _dark_timer > 0.0:
		_dark_timer -= delta
		if _dark_timer <= 0.0:
			vision_scale = 1.0

	if state != State.CAUGHT and state != State.PETTED:
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
		State.PETTED:
			_tick_petted(delta)
		State.CAUGHT:
			_stop(delta)

	_update_cone()
	_update_vision_extras()


func is_caught() -> bool:
	return state == State.CAUGHT


func state_name() -> String:
	match state:
		State.PATROL:
			return "Patrol"
		State.SUSPICIOUS:
			return "Suspicious"
		State.INVESTIGATE:
			return ("Drawn by " + _lure_reason) if _lured else "Investigating"
		State.PETTED:
			return "Being petted"
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

	var view_range := view_distance * visibility * vision_scale
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
	if next != State.INVESTIGATE:
		_lured = false
	_hearts.visible = next == State.PETTED
	match next:
		State.PATROL:
			_lamp.albedo_color = Color.GREEN
			_waiting = false
			_goto_current_patrol_point()
		State.SUSPICIOUS:
			_lamp.albedo_color = Color.YELLOW
		State.INVESTIGATE:
			_lamp.albedo_color = Color(0.35, 0.65, 1.0) if _lured else Color(1.0, 0.55, 0.0)
			_agent.target_position = _last_known
			_arrived = false
			_look_timer = _lure_seconds if _lured else look_around_seconds
		State.PETTED:
			_lamp.albedo_color = Color(1.0, 0.5, 0.75)
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
	if _lured:
		_face_point(_lure_source, stare_turn_speed * delta)  # stare up at the yowling cat
	else:
		rotate_y(deg_to_rad(look_around_deg_per_sec) * delta)
	_look_timer -= delta
	if _look_timer <= 0.0:
		_enter(State.PATROL)


func is_petted() -> bool:
	return state == State.PETTED


func can_be_lured() -> bool:
	return _running and state != State.CAUGHT and state != State.PETTED


## Semba's Mighty Roar: drop what he is doing, walk to the spot below `source` and stare up for `seconds`.
## If he catches sight of Nooni on the way he still turns suspicious, as usual.
func lure(source: Vector3, seconds: float, reason := "a yowl") -> bool:
	if not can_be_lured():
		return false
	_lure_source = source
	_last_known = Vector3(source.x, 0.0, source.z)
	_lure_seconds = seconds
	_lure_reason = reason
	_lured = true
	_enter(State.INVESTIGATE)
	return true


func can_be_petted() -> bool:
	return _running and state != State.CAUGHT and state != State.PETTED


## Bruce's Bat-Nap: freeze in a petting animation for `seconds`. Returns false if he can't be petted now.
func pet(seconds: float) -> bool:
	if not can_be_petted():
		return false
	_petted_timer = seconds
	_enter(State.PETTED)
	return true


func _tick_petted(delta: float) -> void:
	_stop(delta)
	_hearts.rotate_y(3.0 * delta)
	_petted_timer -= delta
	if _petted_timer <= 0.0:
		awareness = 0.0
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


func set_vision(on: bool) -> void:
	vision_on = on
	_xray.visible = on
	_alert_label.visible = on


## Hacked lights out: for `seconds` his sight range is halved.
func set_darkness(seconds: float) -> void:
	vision_scale = 0.5
	_dark_timer = seconds


func _update_vision_extras() -> void:
	if not vision_on:
		return
	_xray_material.albedo_color = Color(_lamp.albedo_color.r, _lamp.albedo_color.g, _lamp.albedo_color.b, 0.3)
	_alert_label.text = "%s  %d%%" % [state_name(), roundi(awareness * 100.0)]
	_alert_label.modulate = Color.WHITE.lerp(Color(1.0, 0.4, 0.4), awareness)


# ---- Debug cone ----------------------------------------------------------------------

## Translucent floor fan showing where he is looking (green -> red as awareness fills).
## Each ray stops at walls and tall furniture, like his actual line of sight.
func _update_cone() -> void:
	# Faint with the assist setting on, bright in Detective Vision, hidden otherwise.
	_cone.visible = show_cone and (vision_on or _assist_cones)
	if not _cone.visible:
		return

	var origin := global_position
	_cone.global_transform = Transform3D(Basis(Vector3.UP, rotation.y), origin + Vector3.UP * 0.03)
	var color := Color.GREEN.lerp(Color.RED, awareness)
	color.a = 0.3 if vision_on else 0.12

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
