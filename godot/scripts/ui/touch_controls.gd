extends CanvasLayer
## On-screen controls for phones and tablets. Stealth levels get a floating move stick on the left, drag-to-look on
## the right, and buttons that depend on who is being played. The driving stage gets steering, gas and brake.
## Everything feeds the normal input actions, so the game itself needs no special touch code. Multi-touch works:
## every finger is tracked separately.

const MenuKit := preload("res://scripts/ui/menu_kit.gd")

## True while touch controls are on screen. Characters ignore emulated mouse motion then, so the finger that
## moves the stick does not also swing the camera.
static var active := false

const STICK_RADIUS := 110.0
const DEAD_ZONE := 0.18
const LOOK_SENSITIVITY := 0.0042
const TAP_SECONDS := 0.09

## "level" (on foot) or "drive".
var mode := "level"
var level: Node  ## The level or drive scene.

var _buttons: Array = []
var _touches: Dictionary = {}  # finger index -> {"kind": "stick" | "look" | "button", "id": String}
var _stick_center := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _stick_finger := -1
var _releases: Array = []  # [action, time] pending releases for taps
var _canvas: Control


## Whether the current device should show touch controls (phones and tablets).
static func wanted() -> bool:
	return OS.has_feature("mobile")


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	active = true
	_build_buttons()


func _exit_tree() -> void:
	_release_all()
	active = false


# ---- Buttons -------------------------------------------------------------------------

## id, input action, label, whether it is held (vs tapped), radius, and where it is (offset from a screen corner).
func _build_buttons() -> void:
	if mode == "drive":
		_add("left", "move_left", "<", true, 64.0, "bl", Vector2(120, -120))
		_add("right", "move_right", ">", true, 64.0, "bl", Vector2(310, -120))
		_add("gas", "move_forward", "GAS", true, 66.0, "br", Vector2(-125, -125))
		_add("brake", "move_back", "BRAKE", true, 52.0, "br", Vector2(-295, -95))
		_add("drift", "jump", "DRIFT", true, 40.0, "br", Vector2(-135, -275))
		_add("hack", "interact", "HACK", false, 44.0, "br", Vector2(-305, -245))
		_add("horn", "horn", "HORN", false, 34.0, "br", Vector2(-440, -90))
	else:
		_add("jump", "jump", "JUMP", true, 58.0, "br", Vector2(-120, -120))
		_add("ability", "ability", "Q", false, 46.0, "br", Vector2(-262, -85), [1, 2])
		_add("crouch", "crouch", "DUCK", false, 46.0, "br", Vector2(-100, -268), [0])
		_add("sprint", "sprint", "RUN", true, 42.0, "br", Vector2(-255, -215), [0])
		_add("grapple", "grapple", "HOOK", false, 44.0, "br", Vector2(-390, -135), [0])
		_add("hack", "interact", "HACK", false, 40.0, "br", Vector2(-400, -255), [0])
		_add("vision", "vision", "EYE", true, 44.0, "br", Vector2(-522, -100), [0])
		_add("wipe", "wipe_glasses", "WIPE", false, 40.0, "br", Vector2(-525, -225), [0])
		_add("cat0", "switch_1", "N", false, 34.0, "tr", Vector2(-250, 56))
		_add("cat1", "switch_2", "B", false, 34.0, "tr", Vector2(-170, 56))
		_add("cat2", "switch_3", "S", false, 34.0, "tr", Vector2(-90, 56))
	_add("pause", "", "II", false, 30.0, "tr", Vector2(-50, 140))


func _add(id: String, action: String, label: String, hold: bool, radius: float, corner: String, offset: Vector2, characters := []) -> void:
	_buttons.append({
		"id": id, "action": action, "label": label, "hold": hold, "radius": radius,
		"corner": corner, "offset": offset, "characters": characters, "pressed": false, "center": Vector2.ZERO,
	})


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


## Scale so the controls stay comfortable on any screen.
func _unit() -> float:
	return clampf(_screen().y / 720.0, 0.8, 1.7)


func _layout() -> void:
	var s := _screen()
	var u := _unit()
	for button in _buttons:
		var o: Vector2 = button.offset * u
		match button.corner:
			"br":
				button.center = Vector2(s.x, s.y) + o
			"bl":
				button.center = Vector2(0, s.y) + o
			"tr":
				button.center = Vector2(s.x, 0) + o
			_:
				button.center = o


func button_center(id: String) -> Vector2:
	_layout()
	for button in _buttons:
		if button.id == id:
			return button.center
	return Vector2.ZERO


func is_button_visible(button: Dictionary) -> bool:
	if mode != "level" or button.characters.is_empty():
		return true
	var current = level.switcher.current if level and level.switcher else null
	return current != null and button.characters.has(current.character_id)


func _button_at(pos: Vector2) -> Dictionary:
	_layout()
	var u := _unit()
	for button in _buttons:
		if is_button_visible(button) and pos.distance_to(button.center) <= button.radius * u * 1.15:
			return button
	return {}


# ---- Input ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position, event.relative)


func _touch_down(finger: int, pos: Vector2) -> void:
	var button := _button_at(pos)
	if not button.is_empty():
		_touches[finger] = {"kind": "button", "id": button.id}
		_press(button)
		return
	var s := _screen()
	if _stick_finger == -1 and pos.x < s.x * 0.42 and pos.y > s.y * 0.2:
		_stick_finger = finger
		_stick_center = pos
		_stick_pos = pos
		_touches[finger] = {"kind": "stick", "id": ""}
	elif mode == "level" and pos.x >= s.x * 0.3:
		_touches[finger] = {"kind": "look", "id": ""}


func _touch_up(finger: int) -> void:
	if not _touches.has(finger):
		return
	var info: Dictionary = _touches[finger]
	match info.kind:
		"button":
			for button in _buttons:
				if button.id == info.id:
					_release(button)
		"stick":
			_stick_finger = -1
			_set_move(Vector2.ZERO)
	_touches.erase(finger)


func _touch_move(finger: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(finger):
		return
	match _touches[finger].kind:
		"stick":
			_stick_pos = pos
			var offset := pos - _stick_center
			var limit := STICK_RADIUS * _unit()
			if offset.length() > limit:  # drag the base along so the thumb never runs out of room
				_stick_center = pos - offset.normalized() * limit
				offset = pos - _stick_center
			_set_move(offset / limit)
		"look":
			var current = level.switcher.current if (level and level.switcher) else null
			if current and current.input_enabled:
				current.apply_look(relative * LOOK_SENSITIVITY)


func _set_move(vector: Vector2) -> void:
	_axis("move_left", "move_right", vector.x)
	_axis("move_forward", "move_back", vector.y)  # up on screen = forward


func _axis(negative: String, positive: String, value: float) -> void:
	var amount := absf(value)
	if amount < DEAD_ZONE:
		_send(negative, false)
		_send(positive, false)
	elif value > 0.0:
		_send(negative, false)
		_send(positive, true, minf(1.0, amount))
	else:
		_send(positive, false)
		_send(negative, true, minf(1.0, amount))


## Sends a real input event for an action, so both polling (Input.is_action_pressed) and event listeners
## (such as the cat switcher's _input) see it. Input.action_press alone would only reach the polling kind.
func _send(action: String, pressed: bool, strength := 1.0) -> void:
	if action == "":
		return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = strength if pressed else 0.0
	Input.parse_input_event(event)


func _press(button: Dictionary) -> void:
	button.pressed = true
	if button.id == "pause":
		if level and level.pause_menu:
			level.pause_menu.toggle()
		return
	_send(button.action, true)
	if not button.hold:
		_releases.append([button.action, Time.get_ticks_msec() + int(TAP_SECONDS * 1000.0)])


func _release(button: Dictionary) -> void:
	button.pressed = false
	if button.hold and button.action != "":
		_send(button.action, false)


func _release_all() -> void:
	for button in _buttons:
		_release(button)
	for entry in _releases:
		_send(entry[0], false)
	_releases.clear()
	_set_move(Vector2.ZERO)
	_touches.clear()
	_stick_finger = -1


func _process(_delta: float) -> void:
	# Taps stay "pressed" for a moment so the physics step sees them.
	var now := Time.get_ticks_msec()
	for i in range(_releases.size() - 1, -1, -1):
		if now >= _releases[i][1]:
			_send(_releases[i][0], false)
			_releases.remove_at(i)
	if get_tree().paused:
		if not _touches.is_empty():
			_release_all()
		_canvas.visible = false
		return
	_canvas.visible = true
	_canvas.queue_redraw()


# ---- Drawing -------------------------------------------------------------------------

func _draw_controls() -> void:
	_layout()
	var u := _unit()
	var font := ThemeDB.fallback_font

	if _stick_finger != -1:
		_canvas.draw_circle(_stick_center, STICK_RADIUS * u, Color(1, 1, 1, 0.12))
		_canvas.draw_arc(_stick_center, STICK_RADIUS * u, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 3.0, true)
		_canvas.draw_circle(_stick_pos, 38.0 * u, Color(1.0, 0.9, 0.5, 0.55))
	else:
		# A faint hint of where the stick appears.
		var s := _screen()
		_canvas.draw_arc(Vector2(s.x * 0.17, s.y * 0.72), 60.0 * u, 0.0, TAU, 32, Color(1, 1, 1, 0.18), 3.0, true)

	for button in _buttons:
		if not is_button_visible(button):
			continue
		var radius: float = button.radius * u
		var fill := Color(1.0, 0.85, 0.3, 0.7) if button.pressed else Color(0.1, 0.08, 0.22, 0.5)
		_canvas.draw_circle(button.center, radius, fill)
		_canvas.draw_arc(button.center, radius, 0.0, TAU, 36, Color(1, 1, 1, 0.65), 3.0, true)
		var label: String = _label_for(button)
		var size := int(clampf(radius * 0.5, 14.0, 30.0))
		var pos: Vector2 = button.center + Vector2(-radius, size * 0.35)
		_canvas.draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, 6, Color(0.05, 0.03, 0.1))
		_canvas.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, size, Color.WHITE)


func _label_for(button: Dictionary) -> String:
	if button.id == "ability" and level and level.switcher:
		match level.switcher.current.character_id:
			1:
				return "NAP"
			2:
				return "ROAR"
			_:
				return "-"
	return button.label
