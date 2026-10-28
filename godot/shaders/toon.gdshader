shader_type spatial;
render_mode specular_disabled;

// Cel shading: one hard light/shadow edge, a tinted shadow colour and a soft rim light.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.42, 0.38, 0.65, 1.0);
uniform float shade_threshold : hint_range(-1.0, 1.0) = 0.08;
uniform float shade_softness : hint_range(0.001, 0.5) = 0.025;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.18;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

// Optional world-space patterns (floor tiles, wall panelling).
uniform vec4 pattern_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float checker_size = 0.0;      // > 0 turns on a floor checker in XZ
uniform float wainscot_height = 0.0;   // > 0 recolours everything below this world height

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (checker_size > 0.0) {
		vec2 c = floor(wpos.xz / checker_size);
		if (mod(c.x + c.y, 2.0) > 0.5) {
			col = pattern_color.rgb;
		}
	}
	if (wainscot_height > 0.0 && wpos.y < wainscot_height) {
		col = pattern_color.rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;

	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = col * rim * rim_amount;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(shade_threshold - shade_softness, shade_threshold + shade_softness, ndl);
	DIFFUSE_LIGHT += mix(shade_color.rgb, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
