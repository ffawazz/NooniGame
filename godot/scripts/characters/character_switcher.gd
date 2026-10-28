extends Node
## The Cat-ical Wheel. Owns "who is possessed right now".
##
## Hold Tab: time slows, gameplay input is suspended, the wheel opens and the mouse picks a slice.
## Release Tab: commit the hovered slice (centre dead zone = cancel). A quick tap cycles to the next cat.
## 1 / 2 / 3: instant switch with no slow-motion.
##
## FREE -> WHEEL -> BLENDING -> FREE. While BLENDING the new character cannot act, so nobody receives
## input while the camera is still travelling to them. A slot holding null is a locked character.

signal character_changed(previous, next)
signal switch_denied(character)

const Game := preload("res://scripts/core/game.gd")
const WheelMath := preload("res://scripts/ui/wheel_math.gd")

enum Mode { FREE, WHEEL, BLENDING }

const SLOT_NAMES := ["Nooni", "Bruce", "Semba"]
const SLOT_COLORS := [Color(0.27, 0.45, 0.9, 0.9), Color(0.3, 0.26, 0.4, 0.92), Color(0.75, 0.6, 0.35, 0.9)]

@export_range(0.01, 1.0) var slow_time_scale := 0.1
@export var blend_seconds := 0.6
@export var tap_seconds := 0.18

## Index = character id; null = locked slot.
var roster: Array = []
var current: Node
var mode := Mode.FREE
var hovered := -1
## Set when the round is over so nobody can switch or move.
var locked := false
## Headless tests: no mouse capture, and hover is driven by hover_offset() instead of the real pointer.
var test_mode := false
var wheel_ui: Node

var _opened_msec := 0
var _blend_cam: Camera3D
var _blend_t := 0.0
var _blend_from := Transform3D.IDENTITY
var _blend_fov_from := 75.0
var _blend_h_from := 0.0


func setup(characters: Array, ui: Node, start_index := 0) -> void:
	roster = characters
	wheel_ui = ui
	current = roster[start_index]
	current.possess(true)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _input(event: InputEvent) -> void:
	if locked:
		return
	if event.is_action_pressed("open_wheel"):
		open_wheel()
	elif event.is_action_released("open_wheel"):
		close_wheel(true)
	else:
		for i in 3:
			if event.is_action_pressed("switch_%d" % (i + 1)):
				request_switch(i)


func _process(delta: float) -> void:
	match mode:
		Mode.WHEEL:
			if not test_mode:
				var viewport := get_viewport()
				hover_offset(viewport.get_mouse_position() - viewport.get_visible_rect().size * 0.5)
		Mode.BLENDING:
			_update_blend(delta)


func is_blending() -> bool:
	return mode == Mode.BLENDING


func is_wheel_open() -> bool:
	return mode == Mode.WHEEL


# ---- Wheel ---------------------------------------------------------------------------

## Opens the wheel. Returns false if it can't (mid-switch, round over, or the current character is busy).
func open_wheel() -> bool:
	if mode != Mode.FREE or locked:
		return false
	if not current.can_release():
		switch_denied.emit(current)
		return false

	mode = Mode.WHEEL
	hovered = -1
	Game.sfx("wheel_open")
	_opened_msec = Time.get_ticks_msec()
	Engine.time_scale = slow_time_scale
	current.input_enabled = false
	if not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var viewport := get_viewport()
		viewport.warp_mouse(viewport.get_visible_rect().size * 0.5)
	wheel_ui.show_wheel(_slots(), roster.find(current))
	return true


## Pointer offset from the wheel centre, in pixels. Called every frame while open.
func hover_offset(offset: Vector2) -> int:
	hovered = wheel_ui.update_hover(offset)
	return hovered


func close_wheel(commit := true) -> void:
	if mode != Mode.WHEEL:
		return
	Engine.time_scale = 1.0
	wheel_ui.hide_wheel()

	var pick := hovered
	var tapped := Time.get_ticks_msec() - _opened_msec < int(tap_seconds * 1000.0)
	if commit and pick < 0 and tapped:
		pick = _next_unlocked_index()

	if commit and _can_pick(pick):
		_begin_switch(pick)
	else:
		_back_to_free()


## Direct switch by roster index (keys 1/2/3, or scripted). Respects locks and can_release().
func request_switch(index: int) -> bool:
	if mode != Mode.FREE or locked or not _can_pick(index):
		return false
	if not current.can_release():
		switch_denied.emit(current)
		return false
	_begin_switch(index)
	return true


func _can_pick(index: int) -> bool:
	return index >= 0 and index < roster.size() and roster[index] != null and roster[index] != current


func _next_unlocked_index() -> int:
	var start := roster.find(current)
	for step in range(1, roster.size() + 1):
		var index := (start + step) % roster.size()
		if _can_pick(index):
			return index
	return -1


func _slots() -> Array:
	var out := []
	for i in 3:
		var character: Node = roster[i] if i < roster.size() else null
		out.append({
			"name": character.display_name if character else SLOT_NAMES[i],
			"color": SLOT_COLORS[i],
			"locked": character == null,
		})
	return out


# ---- Switching and the camera blend ---------------------------------------------------

func _begin_switch(index: int) -> void:
	var previous := current
	var next: Node = roster[index]

	var from_cam: Camera3D = previous.get_camera()
	_blend_from = from_cam.global_transform
	_blend_fov_from = from_cam.fov
	_blend_h_from = from_cam.h_offset

	if _blend_cam == null:
		_blend_cam = Camera3D.new()
		add_child(_blend_cam)
	_blend_cam.global_transform = _blend_from
	_blend_cam.fov = _blend_fov_from
	_blend_cam.h_offset = _blend_h_from
	_blend_cam.current = true

	previous.release()
	next.possess(false)
	next.input_enabled = false  # until the camera arrives
	current = next

	mode = Mode.BLENDING
	_blend_t = 0.0
	if not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.sfx("switch")
	character_changed.emit(previous, next)


func _update_blend(delta: float) -> void:
	_blend_t = minf(1.0, _blend_t + delta / blend_seconds)
	var k := _blend_t * _blend_t * (3.0 - 2.0 * _blend_t)
	var target: Camera3D = current.get_camera()
	_blend_cam.global_transform = _blend_from.interpolate_with(target.global_transform, k)
	_blend_cam.fov = lerpf(_blend_fov_from, target.fov, k)
	_blend_cam.h_offset = lerpf(_blend_h_from, target.h_offset, k)
	if _blend_t >= 1.0:
		target.current = true
		_back_to_free()


func _back_to_free() -> void:
	mode = Mode.FREE
	current.input_enabled = not locked
	if not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
