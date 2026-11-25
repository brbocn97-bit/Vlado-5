shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cutoff : hint_range(0.1, 0.9) = 0.28;
uniform float wind_strength : hint_range(0.0, 0.5) = 0.09;
uniform float wind_speed : hint_range(0.2, 4.0) = 1.65;
uniform vec3 tint_color : source_color = vec3(1.0, 1.0, 1.0);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway_weight = clamp(COLOR.r, 0.0, 1.0);
	float phase = wp.x * 0.45 + wp.z * 0.37 + TIME * wind_speed;
	VERTEX.x += sin(phase) * wind_strength * sway_weight;
	VERTEX.z += cos(phase * 0.83) * wind_strength * 0.7 * sway_weight;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < alpha_cutoff) {
		discard;
	}
	ALBEDO = tex.rgb * tint_color;
	ROUGHNESS = 0.86;
	SPECULAR = 0.14;
}
