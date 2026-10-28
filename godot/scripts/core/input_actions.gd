extends RefCounted
## Registers every input action in code, so project.godot needs no hand-serialised InputEvents.
## Call register() once; it is safe to call repeatedly.

const KEYS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"interact": [KEY_E],
	"ability": [KEY_Q],
	"wipe_glasses": [KEY_R],
	"open_wheel": [KEY_TAB],
	"switch_1": [KEY_1],
	"switch_2": [KEY_2],
	"switch_3": [KEY_3],
	"pause": [KEY_ESCAPE],
}

const MOUSE := {
	"grapple": [MOUSE_BUTTON_LEFT],
	"vision": [MOUSE_BUTTON_RIGHT],
}


static func register() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)

	for action in MOUSE:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for button in MOUSE[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
