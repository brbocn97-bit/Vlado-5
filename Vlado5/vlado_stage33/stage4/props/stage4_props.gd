class_name Stage4Props
extends RefCounted
## Stage4Props — geometry + materials for every Stage 4 building and prop.
##
## Deliberately reuses the Stage 3.2 texture set (stone_wall, roof_slate,
## wood_timber, iron) so new buildings look like they were built by the same
## hands as the baseline village. Nothing here loads a texture the baseline
## does not already ship.

static var data: MontenegroTerrainData = null
static var _mats: Dictionary = {}

const WALL_T := 0.34

# ------------------------------------------------------------------ materials
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"stone":
			m.albedo_texture = _tex("stone_wall_albedo.png")
			m.normal_enabled = true
			m.normal_texture = _tex("stone_wall_normal.png")
			m.normal_scale = 1.15
			m.roughness = 0.92
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.35, 0.35, 0.35)
		"stone_dark":
			m.albedo_texture = _tex("stone_wall_albedo.png")
			m.albedo_color = Color(0.62, 0.60, 0.57)
			m.normal_enabled = true
			m.normal_texture = _tex("stone_wall_normal.png")
			m.roughness = 0.94
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.30, 0.30, 0.30)
		"stone_light":
			m.albedo_texture = _tex("stone_wall_albedo.png")
			m.albedo_color = Color(1.18, 1.16, 1.10)
			m.roughness = 0.88
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.28, 0.28, 0.28)
		"slate":
			m.albedo_texture = _tex("roof_slate_albedo.png")
			m.normal_enabled = true
			m.normal_texture = _tex("roof_slate_normal.png")
			m.roughness = 0.87
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.42, 0.42, 0.42)
		"wood":
			m.albedo_texture = _tex("wood_timber_albedo.png")
			m.normal_enabled = true
			m.normal_texture = _tex("wood_timber_normal.png")
			m.roughness = 0.86
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.55, 0.55, 0.55)
		"wood_dark":
			m.albedo_texture = _tex("wood_timber_albedo.png")
			m.albedo_color = Color(0.58, 0.50, 0.42)
			m.roughness = 0.89
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.50, 0.50, 0.50)
		"plaster":
			m.albedo_color = Color(0.87, 0.84, 0.76)
			m.roughness = 0.93
		"plaster_warm":
			m.albedo_color = Color(0.82, 0.74, 0.61)
			m.roughness = 0.93
		"concrete":
			m.albedo_color = Color(0.56, 0.56, 0.53)
			m.roughness = 0.95
		"iron":
			m.albedo_color = Color(0.16, 0.16, 0.17)
			m.metallic = 0.62
			m.roughness = 0.62
		"iron_rust":
			m.albedo_color = Color(0.42, 0.28, 0.21)
			m.metallic = 0.28
			m.roughness = 0.82
		"canvas":
			m.albedo_color = Color(0.60, 0.55, 0.42)
			m.roughness = 0.96
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"canvas_axis":
			m.albedo_color = Color(0.44, 0.43, 0.38)
			m.roughness = 0.96
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"canvas_green":
			m.albedo_color = Color(0.34, 0.38, 0.29)
			m.roughness = 0.96
		"hay":
			m.albedo_color = Color(0.70, 0.61, 0.35)
			m.roughness = 0.98
		"cloth_white":
			m.albedo_color = Color(0.89, 0.87, 0.82)
			m.roughness = 0.94
		"cloth_red":
			m.albedo_color = Color(0.54, 0.16, 0.13)
			m.roughness = 0.92
		"cloth_blue":
			m.albedo_color = Color(0.19, 0.25, 0.40)
			m.roughness = 0.92
		"dark_hole":
			m.albedo_color = Color(0.04, 0.04, 0.045)
			m.roughness = 1.0
		"glass":
			m.albedo_color = Color(0.26, 0.33, 0.35, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.12
			m.metallic = 0.2
		"emissive_amber":
			m.albedo_color = Color(1.0, 0.72, 0.34)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.60, 0.22)
			m.emission_energy_multiplier = 2.4
		"gravel":
			m.albedo_color = Color(0.55, 0.52, 0.45)
			m.roughness = 0.97
		"cobble":
			m.albedo_color = Color(0.50, 0.48, 0.45)
			m.roughness = 0.96
		_:
			m.albedo_color = Color(0.6, 0.6, 0.6)
	_mats[key] = m
	return m


static func _tex(file: String) -> Texture2D:
	var path := "res://assets/textures/" + file
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func reset_materials() -> void:
	_mats.clear()


# ------------------------------------------------------------- primitives
static func box(size: Vector3, material_key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat(material_key)
	mi.mesh = bm
	return mi


static func cyl(radius: float, height: float, key: String, top: float = -1.0,
		segs: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top < 0.0 else top
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	cm.material = mat(key)
	mi.mesh = cm
	return mi


static func sphere(radius: float, key: String, hemi: bool = false, segs: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * (1.0 if hemi else 2.0)
	sm.is_hemisphere = hemi
	sm.radial_segments = segs
	sm.rings = maxi(3, segs / 2)
	sm.material = mat(key)
	mi.mesh = sm
	return mi


static func plate(size: Vector2, key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	var m := mat(key).duplicate() as StandardMaterial3D
	if m:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		pm.material = m
	mi.mesh = pm
	return mi


## Triangular prism (tents, roof wedges, sandbag rows).
static func prism(size: Vector3, key: String) -> MeshInstance3D:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var hy := size.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := mat(key)
	st.set_material(m)
	var a := Vector3(-hx, 0, -hz)
	var b := Vector3(hx, 0, -hz)
	var c := Vector3(hx, 0, hz)
	var d := Vector3(-hx, 0, hz)
	var e := Vector3(-hx, hy, 0)
	var f := Vector3(hx, hy, 0)
	_tri(st, a, b, c, Vector3.DOWN)
	_tri(st, a, c, d, Vector3.DOWN)
	_tri(st, a, e, f, Vector3(0, 0.5, -1).normalized())
	_tri(st, a, f, b, Vector3(0, 0.5, -1).normalized())
	_tri(st, d, c, f, Vector3(0, 0.5, 1).normalized())
	_tri(st, d, f, e, Vector3(0, 0.5, 1).normalized())
	_tri(st, a, d, e, Vector3(-1, 0, 0))
	_tri(st, b, f, c, Vector3(1, 0, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_surface_count() > 0:
		(mi.mesh as ArrayMesh).surface_set_material(0, m)
	mi.material_override = m
	return mi


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x, v.z) * 0.4)
		st.add_vertex(v)


## Gable roof wedge (ridge along Z).
static func gable(width: float, depth: float, rise: float, overhang: float, key: String) -> MeshInstance3D:
	var hw := width * 0.5 + overhang
	var hd := depth * 0.5 + overhang
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat(key))
	var a := Vector3(-hw, 0, -hd)
	var b := Vector3(0, rise, -hd)
	var c := Vector3(hw, 0, -hd)
	var d := Vector3(-hw, 0, hd)
	var e := Vector3(0, rise, hd)
	var f := Vector3(hw, 0, hd)
	var n_west := Vector3(-rise, hw, 0).normalized()
	var n_east := Vector3(rise, hw, 0).normalized()
	_tri(st, a, d, e, n_west)
	_tri(st, a, e, b, n_west)
	_tri(st, c, b, e, n_east)
	_tri(st, c, e, f, n_east)
	_tri(st, a, b, c, Vector3(0, 0, -1))
	_tri(st, d, f, e, Vector3(0, 0, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m2 := mat(key)
	if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_surface_count() > 0:
		(mi.mesh as ArrayMesh).surface_set_material(0, m2)
	mi.material_override = m2
	return mi


static func static_body(shapes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for e in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = e["shape"]
		cs.transform = e.get("xform", Transform3D.IDENTITY)
		body.add_child(cs)
	return body


static func box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


static func cyl_shape(radius: float, height: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return s


# ------------------------------------------------------------------- ground
static func ground(x: float, z: float) -> float:
	if data == null:
		return 0.0
	return data.get_height(x, z)


static func place(node: Node3D, x: float, z: float, sink: float = 0.2) -> Node3D:
	node.position = Vector3(x, ground(x, z) - sink, z)
	return node


static func slope(x: float, z: float) -> float:
	if data == null:
		return 0.0
	return data.get_slope_deg(x, z)
