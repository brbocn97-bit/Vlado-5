shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D water_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.18, 0.30, 0.29);
uniform vec3 deep_color : source_color = vec3(0.07, 0.14, 0.17);
uniform vec3 foam_color : source_color = vec3(0.76, 0.80, 0.79);
uniform float flow_speed : hint_range(0.05, 2.0) = 0.42;
uniform float wave_scale : hint_range(0.05, 1.0) = 0.22;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ripple = sin(v_world_pos.x * 1.4 + TIME * 2.2) * cos(v_world_pos.z * 1.2 - TIME * 1.8) * 0.025;
	VERTEX.y += ripple * COLOR.r;
}

void fragment() {
	float depth_mask = clamp(COLOR.r, 0.0, 1.0);
	float cascade_mask = clamp(COLOR.g, 0.0, 1.0);

	vec2 flow_uv1 = v_world_pos.xz * wave_scale + vec2(-TIME * flow_speed * 0.24, TIME * flow_speed * 0.32);
	vec2 flow_uv2 = v_world_pos.xz * (wave_scale * 1.6) + vec2(TIME * flow_speed * 0.15, TIME * flow_speed * 0.48);
	vec3 n1 = texture(water_normal, flow_uv1).rgb;
	vec3 n2 = texture(water_normal, flow_uv2).rgb;
	vec3 n_mix = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0);

	// Shoreline & streaked waterfall foam
	float edge_foam = smoothstep(0.30, 0.03, depth_mask);
	float streak = smoothstep(0.42, 0.78, n_mix.x * 0.5 + 0.5);
	float cascade_streaks = cascade_mask * mix(0.28, 0.85, streak);
	float foam = clamp(streak * edge_foam * 0.65 + cascade_streaks * 0.62, 0.0, 0.78);

	float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	vec3 base_col = mix(shallow_color, deep_color, smoothstep(0.08, 0.85, depth_mask));
	base_col = mix(base_col, vec3(0.42, 0.50, 0.54), fresnel * 0.42);
	vec3 final_col = mix(base_col, foam_color, foam);

	ALBEDO = final_col;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = 0.65;
	ROUGHNESS = mix(0.09, 0.50, foam);
	METALLIC = 0.05;
	SPECULAR = 0.65;
	ALPHA = clamp(mix(0.44, 0.88, depth_mask) + foam * 0.25, 0.42, 0.94);
}
