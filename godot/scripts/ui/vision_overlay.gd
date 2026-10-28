extends Control
## Detective Vision on the screen: a cyan scanline tint with a vignette, and the anime-style glint across the
## glasses when it switches on.

var vision: Node

var _tint: ColorRect
var _material: ShaderMaterial
var _intensity := 0.0
var _glint := 1.0  # 0..1 progress of the glint, >= 1 means idle

const SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float vignette = smoothstep(0.3, 0.95, distance(UV, vec2(0.5)));
	float scan = 0.5 + 0.5 * sin(UV.y * 900.0);
	float a = intensity * (0.13 + vignette * 0.55 + scan * 0.07);
	COLOR = vec4(0.1, 0.85, 0.95, a);
}
"""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_tint = ColorRect.new()
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.material = _material
	add_child(_tint)
	if vision:
		vision.activated.connect(func(): _glint = 0.0)


func _process(delta: float) -> void:
	# A Control under a CanvasLayer has no parent to size it, so size the tint from the viewport.
	_tint.position = Vector2.ZERO
	_tint.size = get_viewport_rect().size
	var target := 1.0 if (vision != null and vision.active) else 0.0
	_intensity = move_toward(_intensity, target, delta * 6.0)
	_material.set_shader_parameter("intensity", _intensity)
	if _glint < 1.0:
		_glint = minf(1.0, _glint + delta / 0.45)
	visible = _intensity > 0.01 or _glint < 1.0
	queue_redraw()


func _draw() -> void:
	if _glint >= 1.0:
		return
	var area := get_viewport_rect().size
	# A bright diagonal band sweeps across the lens...
	var x := lerpf(-0.2, 1.2, _glint) * area.x
	var w := area.x * 0.09
	var slant := area.y * 0.4
	draw_colored_polygon(
		PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - slant, area.y), Vector2(x - slant, area.y)]),
		Color(1, 1, 1, 0.55 * sin(_glint * PI))
	)
	# ...and a four-point sparkle pops at the corner of the glasses.
	var center := Vector2(area.x * 0.78, area.y * 0.28)
	var size := area.y * 0.16 * sin(_glint * PI)
	var color := Color(1, 1, 1, 0.9)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -size), center + Vector2(size * 0.12, 0), center + Vector2(0, size), center + Vector2(-size * 0.12, 0)]), color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-size, 0), center + Vector2(0, size * 0.12), center + Vector2(size, 0), center + Vector2(0, -size * 0.12)]), color)
