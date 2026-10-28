extends CanvasLayer
## Bottom-of-screen narration. say() queues a caption; each stays for its own number of seconds.

const MenuKit := preload("res://scripts/ui/menu_kit.gd")

var _queue: Array = []
var _timer := 0.0
var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	layer = 8
	_panel = MenuKit.panel()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position.y -= 24.0
	_panel.visible = false
	add_child(_panel)

	_label = MenuKit.label("", 22, Color(1.0, 0.95, 0.8))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(640, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)


func say(text: String, seconds := 4.0) -> void:
	_queue.append({"text": text, "seconds": seconds})
	if not _panel.visible:
		_next()


func is_showing() -> bool:
	return _panel.visible


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_panel.visible = false
		return
	var item: Dictionary = _queue.pop_front()
	_label.text = item.text
	_timer = item.seconds
	_panel.visible = true
