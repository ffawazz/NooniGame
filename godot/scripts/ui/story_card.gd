extends CanvasLayer
## Full-screen story card: a title and lines of overdramatic narration that type themselves out.
## Space / Enter / click skips the typing, then advances. Emits `finished` after the last line.
## Runs while the tree is paused.

signal finished

const MenuKit := preload("res://scripts/ui/menu_kit.gd")

var _lines: Array = []
var _index := -1
var _typing := false
var _text: Label
var _tween: Tween
var _hint: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(title: String, lines: Array) -> void:
	_lines = lines
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.02, 0.07)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 28)
	add_child(box)

	var heading := MenuKit.label(title, 30, MenuKit.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	_text = MenuKit.label("", 32)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(900, 160)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_text)

	_hint = MenuKit.label("Space / click to continue", 18, Color(0.7, 0.68, 0.8))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)

	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_advance()


func _input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_finish_typing()
	else:
		_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		if not Engine.is_editor_hint():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		finished.emit()
		return
	_text.text = _lines[_index]
	_text.visible_ratio = 0.0
	_typing = true
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(0.6, _lines[_index].length() * 0.03))
	_tween.tween_callback(func(): _typing = false)


func _finish_typing() -> void:
	if _tween:
		_tween.kill()
	_text.visible_ratio = 1.0
	_typing = false
