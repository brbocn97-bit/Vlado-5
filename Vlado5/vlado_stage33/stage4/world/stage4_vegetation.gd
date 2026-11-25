extends Node3D
## Stage4Vegetation — forest belt for the outer world.
##
## Stage 3.2's MontenegroVegetation only scatters inside [-255, 255] because
## the original playable bowl is ~510 m wide, while the world is 1400 m. Every
## Stage 4 region sits outside that box, so without this the outer regions read
## as bare moonscape. This scatters the same trees from the baseline's own
## MultiMesh meshes, using the same terrain data and forest-zone test, and stays
## clear of region benches so villages are not buried in trees.

const OUTER_MIN := 248.0      # start where the baseline stops
const OUTER_MAX := 690.0
const CLEAR_RADIUS := 74.0    # manji krug oko sela (bilo 118 = preveliko)

var data: MontenegroTerrainData
var pine_mesh: Mesh
var beech_mesh: Mesh
var pine_far: Mesh
var beech_far: Mesh
var _built := false


func build(p_data: MontenegroTerrainData) -> void:
	if _built:
		return
	_built = true
	data = p_data
	_make_meshes()
	_scatter()


# ------------------------------------------------------------------- meshes
func _trunk_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/pine_bark_albedo.png") if ResourceLoader.exists("res://assets/textures/pine_bark_albedo.png") else null
	m.normal_texture = load("res://assets/textures/pine_bark_normal.png") if ResourceLoader.exists("res://assets/textures/pine_bark_normal.png") else null
	m.normal_enabled = m.normal_texture != null
	m.roughness = 0.94
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


func _pine_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/pine_bough_albedo.png") if ResourceLoader.exists("res://assets/textures/pine_bough_albedo.png") else null
	m.roughness = 0.95
	m.albedo_color = Color(0.52, 0.62, 0.42)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _beech_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/beech_leaf_albedo.png") if ResourceLoader.exists("res://assets/textures/beech_leaf_albedo.png") else null
	m.roughness = 0.95
	m.albedo_color = Color(0.60, 0.68, 0.40)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Low-poly conifer: 2 surfaces (trunk + green pine needles).
func _make_conifer(near: bool) -> Mesh:
	var seg := 5 if not near else 7
	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.09
	trunk.bottom_radius = 0.17
	trunk.height = 1.9
	trunk.radial_segments = seg
	trunk.rings = 1
	st_trunk.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 0.95, 0)))
	var mesh := st_trunk.commit()
	mesh.surface_set_material(0, _trunk_mat())

	var st_leaf := SurfaceTool.new()
	st_leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.30 - i * 0.33
		cone.height = 2.2 - i * 0.35
		cone.radial_segments = seg
		cone.rings = 1
		var y := 1.9 + i * 1.15
		st_leaf.append_from(cone, 0, Transform3D(Basis(), Vector3(0, y, 0)))
	st_leaf.commit(mesh)
	mesh.surface_set_material(1, _pine_mat())
	return mesh


func _make_meshes() -> void:
	pine_mesh = _make_conifer(true)
	beech_mesh = pine_mesh


# ------------------------------------------------------------------ scatter
func _chunk_index(x: float, z: float) -> int:
	var cx := int(floor((x + 700.0) / 175.0))
	var cz := int(floor((z + 700.0) / 175.0))
	cx = clampi(cx, 0, 7)
	cz = clampi(cz, 0, 7)
	return cz * 8 + cx


func _scatter() -> void:
	var buckets := {}
	for i in 64:
		buckets[i] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 1944
	var placed := 0
	for _attempt in 55000:
		if placed >= 9500:
			break
		var x := rng.randf_range(-OUTER_MAX, OUTER_MAX)
		var z := rng.randf_range(-OUTER_MAX, OUTER_MAX)
		var rad := Vector2(x, z).length()
		if rad < OUTER_MIN or rad > OUTER_MAX:
			continue
		# keep the region benches readable as clearings
		var too_close := false
		for site in data.S4_SITES:
			var c: Vector2 = site["c"]
			if Vector2(x - c.x, z - c.y).length() < float(site["r"]) * 0.72:
				too_close = true
				break
		if too_close:
			continue
		if not data.is_forest_zone(x, z):
			continue
		if data.get_slope_deg(x, z) > 26.0:
			continue
		var y := data.get_height(x, z)
		var sc := rng.randf_range(0.85, 1.55)
		var b := Basis.from_euler(Vector3(
			rng.randf_range(-0.035, 0.035),
			rng.randf_range(0.0, TAU),
			rng.randf_range(-0.035, 0.035))).scaled(Vector3(sc, sc, sc))
		buckets[_chunk_index(x, z)].append(Transform3D(b, Vector3(x, y - 0.15, z)))
		placed += 1

	for k in buckets:
		var xf: Array = buckets[k]
		if xf.is_empty():
			continue
		for mesh in [pine_mesh, beech_mesh]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xf.size()
			for i in xf.size():
				mm.set_instance_transform(i, xf[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.name = "OuterForest_%d" % k
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 460.0
			mmi.visibility_range_end_margin = 40.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mmi)
			break   # one mesh per bucket keeps draw calls low
	print("[Stage4] outer forest: %d trees in %d buckets" % [placed, buckets.size()])
