shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap, repeat_enable;

uniform float tex_scale : hint_range(0.02, 0.5) = 0.14;
uniform float rock_tex_scale : hint_range(0.02, 0.5) = 0.085;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float macro_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv_ground = v_world_pos.xz * tex_scale;
	vec2 uv_forest = uv_ground * 1.1;
	vec2 uv_road = uv_ground * 1.35;
	vec2 uv_rock = v_world_pos.xz * rock_tex_scale + vec2(v_world_pos.y * 0.04, 0.0);

	vec2 dg_x = dFdx(uv_ground);
	vec2 dg_y = dFdy(uv_ground);
	vec2 dr_x = dFdx(uv_rock);
	vec2 dr_y = dFdy(uv_rock);

	float w_road = clamp(COLOR.r, 0.0, 1.0);
	float w_forest = clamp(COLOR.g, 0.0, 1.0);
	float w_cliff_hint = clamp(COLOR.b, 0.0, 1.0);

	float steep = 1.0 - clamp(v_world_nrm.y, 0.0, 1.0);
	float slope_rock = smoothstep(0.11, 0.28, steep + w_cliff_hint * 0.18);

	float w_rock = clamp(max(slope_rock, w_cliff_hint * 0.85), 0.0, 1.0);
	float rem = max(0.0, 1.0 - w_rock);
	float road_w = w_road * rem;
	float bio_rem = max(0.0, rem - road_w);
	float forest_w = w_forest * bio_rem;
	float grass_w = max(0.0, bio_rem - forest_w);

	vec3 albedo = vec3(0.0);
	vec3 n_blend = vec3(0.0);

	if (grass_w > 0.01) {
		albedo += textureGrad(grass_albedo, uv_ground, dg_x, dg_y).rgb * grass_w;
		n_blend += textureGrad(grass_normal, uv_ground, dg_x, dg_y).rgb * grass_w;
	}
	if (forest_w > 0.01) {
		albedo += textureGrad(forest_albedo, uv_forest, dg_x * 1.1, dg_y * 1.1).rgb * forest_w;
		n_blend += textureGrad(forest_normal, uv_forest, dg_x * 1.1, dg_y * 1.1).rgb * forest_w;
	}
	if (w_rock > 0.01) {
		albedo += textureGrad(rock_albedo, uv_rock, dr_x, dr_y).rgb * w_rock;
		n_blend += textureGrad(rock_normal, uv_rock, dr_x, dr_y).rgb * w_rock;
	}
	if (road_w > 0.01) {
		albedo += textureGrad(road_albedo, uv_road, dg_x * 1.35, dg_y * 1.35).rgb * road_w;
		n_blend += textureGrad(road_normal, uv_road, dg_x * 1.35, dg_y * 1.35).rgb * road_w;
	}

	float macro = macro_noise(v_world_pos.xz * 0.032);
	albedo *= mix(0.84, 1.12, macro);

	ALBEDO = albedo;
	NORMAL_MAP = n_blend;
	NORMAL_MAP_DEPTH = mix(0.75, 1.35, w_rock);
	ROUGHNESS = mix(0.92, 0.82, w_rock * 0.5 + road_w * 0.25);
	SPECULAR = mix(0.18, 0.30, w_rock);
}
