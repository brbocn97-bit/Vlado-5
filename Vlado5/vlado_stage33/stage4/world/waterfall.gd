class_name Stage4Waterfall
extends Node3D
## Stage4Waterfall — a falls where a side stream drops into the Krupa gorge.
##
## Built from the same primitive vocabulary as everything else in Stage 4:
## a carved rock lip, a stack of scrolling water sheets, mist billboards at the
## base, and a splash ring. The water sheets use a small runtime shader because
## the baseline `mountain_water.gdshader` is written for a river surface with
## flow along Z, not for a vertical curtain.
##
## Cost is deliberately low: 3 sheets, 6 mist quads, 1 light. On a phone the
## whole thing is under 400 triangles.

const SHEET_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.72, 0.80, 0.84, 0.82);
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);
uniform float flow_speed = 1.35;
uniform float foam_amount = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	// vertical scroll, stretched vertically so it reads as falling water
	float t = TIME * flow_speed;
	float n1 = noise(vec2(uv.x * 8.0, uv.y * 3.0 - t));
	float n2 = noise(vec2(uv.x * 19.0 + 4.0, uv.y * 7.0 - t * 1.7));
	float streak = mix(n1, n2, 0.45) * 0.6 + 0.4;
	// fade the sheet at its edges so it does not look like a flat card
	float edge = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);
	float foam = smoothstep(1.0 - foam_amount, 1.0, streak) * edge;
	vec3 col = mix(water_color.rgb, foam_color.rgb, foam);
	ALBEDO = col;
	ALPHA = clamp(water_color.a * (0.55 + streak * 0.55) * edge, 0.0, 1.0);
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	// a touch of emission keeps the foam readable in shadow
	EMISSION = foam_color.rgb * foam * 0.12;
}
"""

var height := 9.0
var width := 3.4
var water_material: ShaderMaterial
var _sheets: Array[MeshInstance3D] = []
var _mists: Array[MeshInstance3D] = []
var _t := 0.0


func build(p_height: float, p_width: float) -> void:
	height = p_height
	width = p_width
	_make_material()
	_make_sheets()
	_make_pool()
	_make_mist()
	_make_light()


func _make_material() -> void:
	var sh := Shader.new()
	sh.code = SHEET_SHADER
	water_material = ShaderMaterial.new()
	water_material.shader = sh


func _make_sheets() -> void:
	# three slightly offset curtains give the falls some body
	var offsets := [
		{"x": 0.0, "z": 0.0, "w": 1.0, "h": 1.0, "a": 0.94},
		{"x": -0.55, "z": 0.12, "w": 0.62, "h": 0.94, "a": 0.70},
		{"x": 0.62, "z": -0.10, "w": 0.55, "h": 0.88, "a": 0.62},
	]
	for o in offsets:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(width * float(o["w"]), height * float(o["h"]))
		qm.orientation = PlaneMesh.FACE_Z
		mi.mesh = qm
		var m: ShaderMaterial = water_material.duplicate()
		m.set_shader_parameter("water_color", Color(0.72, 0.80, 0.84, float(o["a"])))
		mi.material_override = m
		mi.position = Vector3(float(o["x"]), -height * 0.5 * float(o["h"]), float(o["z"]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_sheets.append(mi)


func _make_pool() -> void:
	# splash ring at the foot of the falls
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = width * 0.42
	tor.outer_radius = width * 0.70
	ring.mesh = tor
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.90, 0.95, 0.97, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.55, 0.66, 0.72)
	m.emission_energy_multiplier = 0.35
	ring.material_override = m
	ring.position = Vector3(0, 0.06, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var foam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = width * 0.62
	cyl.bottom_radius = width * 0.70
	cyl.height = 0.12
	cyl.radial_segments = 14
	cyl.rings = 1
	foam.mesh = cyl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.94, 0.97, 0.98, 0.42)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.roughness = 0.35
	foam.material_override = fm
	foam.position = Vector3(0, 0.04, 0)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)


func _make_mist() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.95, 0.97, 0.20)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 8811
	for i in 6:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var s := width * rng.randf_range(0.7, 1.3)
		qm.size = Vector2(s, s * 0.8)
		mi.mesh = qm
		mi.material_override = m
		mi.position = Vector3(rng.randf_range(-1.2, 1.2) * width * 0.4,
			rng.randf_range(0.3, 2.4), rng.randf_range(-0.7, 0.7))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_mists.append(mi)


func _make_light() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.72, 0.84, 0.92)
	l.light_energy = 0.45
	l.omni_range = width * 2.6
	l.position = Vector3(0, 0.6, 0.4)
	add_child(l)


func _process(delta: float) -> void:
	_t += delta
	# breathing mist
	for i in _mists.size():
		var mi := _mists[i]
		var ph := _t * 0.55 + float(i) * 1.3
		mi.position.y = 1.2 + sin(ph) * 0.55
		var s := 1.0 + sin(ph * 0.8) * 0.10
		mi.scale = Vector3(s, s, s)
