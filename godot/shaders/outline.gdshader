shader_type spatial;
render_mode cull_front, unshaded;

// Inverted-hull outline: draw the mesh again, pushed outward, showing only its back faces.
uniform vec4 outline_color : source_color = vec4(0.07, 0.05, 0.11, 1.0);
uniform float width = 0.03;
// Boxes have hard normals (the hull would split at the corners), so grow them by sign(vertex) instead.
uniform bool box_hull = false;

void vertex() {
	if (box_hull) {
		VERTEX += sign(VERTEX) * width;
	} else {
		VERTEX += NORMAL * width;
	}
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
