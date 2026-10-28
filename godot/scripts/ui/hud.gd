extends Node
## In-level HUD: who you are playing, the objective, each brother's state and suspicion, door status, Nooni's
## stress bar, the wipe-your-glasses hint, the cat wheel and the glasses smudge overlay.

const MenuKit := preload("res://scripts/ui/menu_kit.gd")
const GlassesOverlayScript := preload("res://scripts/ui/glasses_overlay.gd")
const VisionOverlayScript := preload("res://scripts/ui/vision_overlay.gd")
const ReticleScript := preload("res://scripts/ui/reticle.gd")
const WheelUIScript := preload("res://scripts/ui/cat_wheel_ui.gd")

var level: Node
var wheel_ui: Control
var reticle: Control
var glasses: Control
var vision_overlay: Control
var message_label: Label

var _status: Label
var _objective: Label
var _door_labels: Dictionary = {}
var _brother_rows: Array = []
var _stress_bar: ProgressBar
var _stress_fill: StyleBoxFlat
var _wipe_hint: Label
var _timer_label: Label


func setup(level_node: Node) -> void:
	level = level_node

	# Smudges sit on a layer below the HUD so the text stays readable through them.
	var glasses_layer := CanvasLayer.new()
	glasses_layer.layer = 0
	add_child(glasses_layer)
	vision_overlay = VisionOverlayScript.new()
	vision_overlay.vision = level.nooni.vision
	glasses_layer.add_child(vision_overlay)
	glasses = GlassesOverlayScript.new()
	glasses.stress = level.nooni.stress
	glasses_layer.add_child(glasses)

	var layer := CanvasLayer.new()
	add_child(layer)

	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	layer.add_child(box)

	_status = MenuKit.label("", 20)
	box.add_child(_status)
	_objective = MenuKit.label(level.data.get("objective", ""), 17, MenuKit.GOLD)
	box.add_child(_objective)

	for spec in level.data.get("doors", []):
		var door_label := MenuKit.label("", 18)
		box.add_child(door_label)
		_door_labels[spec.name] = door_label

	for brother in level.brothers:
		var row := MenuKit.label("", 18)
		box.add_child(row)
		var bar := MenuKit.bar(Color(0.95, 0.8, 0.25))
		box.add_child(bar)
		_brother_rows.append({"brother": brother, "label": row, "bar": bar})

	box.add_child(MenuKit.label("Nooni's stress", 18))
	_stress_bar = MenuKit.bar(Color(0.4, 0.85, 0.5))
	_stress_fill = _stress_bar.get_theme_stylebox("fill")
	box.add_child(_stress_bar)

	reticle = ReticleScript.new()
	reticle.level = level
	layer.add_child(reticle)

	wheel_ui = WheelUIScript.new()
	layer.add_child(wheel_ui)

	_wipe_hint = MenuKit.label("SMUDGED!  Press R to wipe your glasses", 28)
	_wipe_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_wipe_hint.position.y -= 70.0
	_wipe_hint.position.x -= 230.0
	_wipe_hint.visible = false
	layer.add_child(_wipe_hint)

	_timer_label = MenuKit.label("", 40, MenuKit.GOLD)
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_label.position.y = 10.0
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer_label.visible = level.time_limit() > 0.0
	layer.add_child(_timer_label)

	message_label = MenuKit.label("", 40)
	message_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(message_label)


func _process(_delta: float) -> void:
	if level == null or level.switcher == null:
		return
	var current = level.switcher.current
	_status.text = "%s: %s" % [current.display_name, current.status_text()]

	for name in _door_labels:
		var door = level.doors[name]
		_door_labels[name].text = "%s: %s" % [door.display_name, "OPEN" if door.is_open else "LOCKED"]

	for row in _brother_rows:
		row.label.text = "%s: %s" % [row.brother.name, row.brother.state_name()]
		row.bar.value = row.brother.awareness

	if _timer_label.visible:
		var left: float = maxf(0.0, level.time_limit() - level.elapsed_seconds())
		_timer_label.text = MenuKit.format_time(left)
		_timer_label.modulate = Color(1.0, 0.4, 0.4) if left < 30.0 else Color.WHITE

	var stress = level.nooni.stress
	_stress_bar.value = stress.value
	_stress_fill.bg_color = Color(0.4, 0.85, 0.5).lerp(Color(0.95, 0.25, 0.3), clampf(stress.value * 1.4 - 0.2, 0.0, 1.0))
	glasses.active = current == level.nooni
	_wipe_hint.visible = glasses.active and stress.smudge >= 0.25 and not stress.wiping and int(Time.get_ticks_msec() / 350.0) % 2 == 0
