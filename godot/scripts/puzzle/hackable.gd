extends Node3D
## A smart-home gadget Nooni can hack while Detective Vision is on (hold right mouse, then press E in range).
##   tv / speaker : blasts noise; every brother (or those within lure_radius) walks over to it for effect_seconds.
##   lights       : the lamp goes dark for effect_seconds, halving every brother's sight range.
##   lock         : opens `target` (a door); closes it again after effect_seconds if that is above zero.
## Each device builds its own look from primitives, plus an AR marker that only shows in Detective Vision.

signal hacked(device)

const Toon := preload("res://scripts/core/toon.gd")
const MenuKit := preload("res://scripts/ui/menu_kit.gd")

@export var kind := "tv"
@export var display_name := "Smart TV"
@export var hack_range := 4.5
@export var cooldown_seconds := 12.0
@export var effect_seconds := 7.0
## 0 = every brother in the level hears it.
@export var lure_radius := 0.0
@export var lamp_energy := 0.45

## For "lock": the door to open.
var target: Node
var vision_on := false
var cooldown_left := 0.0
var effect_left := 0.0

var _marker: Node3D
var _label: Label3D
var _led: MeshInstance3D
var _led_material: StandardMaterial3D
var _screen_material: StandardMaterial3D
var _light: OmniLight3D
var _shade: MeshInstance3D
var _time := 0.0
var _marker_height := 2.0


func _ready() -> void:
	add_to_group("hackable")
	add_to_group("vision_aware")
	match kind:
		"tv":
			_build_tv()
		"speaker":
			_build_speaker()
		"lights":
			_build_lamp()
		"lock":
			_build_lock()
	_build_marker()
	set_vision(false)


# ---- Looks ---------------------------------------------------------------------------

func _build_tv() -> void:
	_marker_height = 1.9
	Toon.box(self, Vector3(1.0, 0.5, 0.4), Vector3(0, 0.25, 0), Color(0.25, 0.2, 0.2))
	Toon.box(self, Vector3(1.5, 0.9, 0.1), Vector3(0, 0.95, 0), Color(0.08, 0.08, 0.1), 0.03)
	_screen_material = _unshaded(Color(0.12, 0.2, 0.32))
	var screen := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.36, 0.76, 0.02)
	screen.mesh = mesh
	screen.material_override = _screen_material
	screen.position = Vector3(0, 0.95, -0.06)
	add_child(screen)
	_add_led(Vector3(0.6, 0.55, -0.06))


func _build_speaker() -> void:
	_marker_height = 1.1
	Toon.cylinder(self, 0.16, 0.34, Vector3(0, 0.17, 0), Color(0.3, 0.3, 0.38), 0.02)
	_add_led(Vector3(0, 0.3, -0.14))


func _build_lamp() -> void:
	_marker_height = 2.5
	Toon.cylinder(self, 0.04, 1.6, Vector3(0, 0.8, 0), Color(0.2, 0.18, 0.25), 0.015)
	_shade = Toon.cylinder(self, 0.32, 0.4, Vector3(0, 1.8, 0), Color(1.0, 0.92, 0.6), 0.02, 0.18)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.7, 0)
	_light.light_color = Color(1.0, 0.85, 0.55)
	_light.light_energy = lamp_energy
	_light.omni_range = 6.0
	add_child(_light)
	_add_led(Vector3(0.05, 0.1, -0.05))


func _build_lock() -> void:
	_marker_height = 1.9
	Toon.box(self, Vector3(0.3, 0.42, 0.1), Vector3(0, 1.3, 0), Color(0.25, 0.28, 0.35), 0.02)
	_add_led(Vector3(0, 1.4, -0.06))


func _add_led(pos: Vector3) -> void:
	_led = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	_led.mesh = mesh
	_led_material = _unshaded(Color(0.3, 1.0, 0.5))
	_led.material_override = _led_material
	_led.position = pos
	add_child(_led)


func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.position = Vector3(0, _marker_height, 0)
	add_child(_marker)
	var diamond := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 0.25, 0.25)
	diamond.mesh = mesh
	diamond.rotation_degrees = Vector3(45, 0, 45)
	var mat := _unshaded(Color(0.3, 0.95, 1.0, 0.9))
	mat.no_depth_test = true
	diamond.material_override = mat
	_marker.add_child(diamond)

	_label = Label3D.new()
	_label.font_size = 40
	_label.pixel_size = 0.007
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 0.42, 0)
	_marker.add_child(_label)


func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


# ---- Hacking -------------------------------------------------------------------------

func set_vision(on: bool) -> void:
	vision_on = on
	_marker.visible = on


func distance_to(point: Vector3) -> float:
	var flat := global_position - point
	flat.y = 0.0
	return flat.length()


func in_range(point: Vector3) -> bool:
	return distance_to(point) <= hack_range


func can_hack(from: Vector3) -> bool:
	return cooldown_left <= 0.0 and in_range(from)


## Run the device's effect. Returns false while it is recharging.
func hack() -> bool:
	if cooldown_left > 0.0:
		return false
	cooldown_left = cooldown_seconds
	effect_left = effect_seconds
	match kind:
		"tv", "speaker":
			for brother in get_tree().get_nodes_in_group("brother"):
				if lure_radius <= 0.0 or brother.global_position.distance_to(global_position) <= lure_radius:
					brother.lure(global_position, effect_seconds, "a noise")
		"lights":
			if _light:
				_light.light_energy = 0.0
			for brother in get_tree().get_nodes_in_group("brother"):
				brother.set_darkness(effect_seconds)
		"lock":
			if target:
				target.set_open(true)
	hacked.emit(self)
	return true


## Hacks the nearest ready device in range of `from`. Returns it, or null.
static func try_hack(tree: SceneTree, from: Vector3) -> Node:
	var best: Node = null
	var best_distance := INF
	for device in tree.get_nodes_in_group("hackable"):
		if device.can_hack(from) and device.distance_to(from) < best_distance:
			best = device
			best_distance = device.distance_to(from)
	if best and best.hack():
		return best
	return null


func _process(delta: float) -> void:
	_time += delta
	cooldown_left = maxf(0.0, cooldown_left - delta)

	if effect_left > 0.0:
		effect_left = maxf(0.0, effect_left - delta)
		if effect_left <= 0.0:
			_effect_ended()
	_animate_effect()

	if _led_material:
		var ready := cooldown_left <= 0.0
		var blink := 0.5 + 0.5 * sin(_time * (3.0 if ready else 9.0))
		_led_material.albedo_color = Color(0.3, 1.0, 0.5, 0.4 + 0.6 * blink) if ready else Color(1.0, 0.4, 0.3, 0.4 + 0.6 * blink)

	if vision_on:
		_marker.position.y = _marker_height + sin(_time * 3.0) * 0.06
		_marker.rotation.y = _time * 1.5
		_label.rotation.y = -_marker.rotation.y  # keep the text facing the camera, not spinning
		if cooldown_left > 0.0:
			_label.text = "%s\nrecharging %ds" % [display_name, ceili(cooldown_left)]
			_label.modulate = Color(1.0, 0.6, 0.5)
		else:
			_label.text = "%s\n[E] Hack" % display_name
			_label.modulate = Color(0.5, 1.0, 0.9)


func _animate_effect() -> void:
	if kind == "tv" and _screen_material:
		if effect_left > 0.0:
			var hue := fmod(_time * 2.0, 1.0)
			_screen_material.albedo_color = Color.from_hsv(hue, 0.7, 1.0)
		else:
			_screen_material.albedo_color = Color(0.12, 0.2, 0.32)
	if kind == "lights" and _shade:
		pass


func _effect_ended() -> void:
	if kind == "lights" and _light:
		_light.light_energy = lamp_energy
	if kind == "lock" and target and effect_seconds > 0.0:
		target.set_open(false)
