class_name RockFormations
extends Node3D

var _rock_mat: StandardMaterial3D

func build_rocks(data: MontenegroTerrainData) -> void:
	_rock_mat = _create_rock_material()

	var cliff_mesh := _make_karst_rock_mesh(1101, Vector3(4.8, 3.6, 4.2), 0.32)
	var boulder_mesh := _make_karst_rock_mesh(2203, Vector3(1.5, 1.05, 1.35), 0.28)
	var flat_slab_mesh := _make_karst_rock_mesh(3307, Vector3(2.2, 0.72, 1.9), 0.22)

	# 1. Hero cliff outcrops & waterfall gorge rocks (with StaticBody3D collision)
	var hero_cliffs := [
		# NW Waterfall Gorge cliffs flanking the cascade
		{"pos": Vector2(-88.0, -120.0), "scale": Vector3(2.2, 2.5, 2.0), "rot": 0.4},
		{"pos": Vector2(-60.0, -104.0), "scale": Vector3(1.9, 2.2, 1.7), "rot": 1.7},
		{"pos": Vector2(-80.0, -80.0), "scale": Vector3(1.6, 1.9, 1.5), "rot": 2.3},
		{"pos": Vector2(-46.0, -88.0), "scale": Vector3(1.7, 2.0, 1.5), "rot": -0.8},
		# River Gorge cliffs framing the valley bend (clear of main river water!)
		{"pos": Vector2(88.0, -108.0), "scale": Vector3(2.4, 2.8, 2.0), "rot": 1.1},
		{"pos": Vector2(106.0, -92.0), "scale": Vector3(2.2, 2.6, 2.1), "rot": 2.8},
		{"pos": Vector2(-46.0, 96.0), "scale": Vector3(2.0, 2.1, 1.7), "rot": 0.6},
		# Outlaw ridge karst outcrops above the village
		{"pos": Vector2(-68.0, 26.0), "scale": Vector3(1.4, 1.5, 1.3), "rot": 1.9},
		{"pos": Vector2(-95.0, -32.0), "scale": Vector3(1.8, 2.1, 1.6), "rot": 0.2},
		{"pos": Vector2(56.0, 22.0), "scale": Vector3(1.5, 1.7, 1.4), "rot": -1.2},
	]
	for idx in hero_cliffs.size():
		var cfg: Dictionary = hero_cliffs[idx]
		var p2: Vector2 = cfg["pos"]
		var sc: Vector3 = cfg["scale"]
		var wy := data.get_height(p2.x, p2.y) - 1.9 * sc.y
		var body := StaticBody3D.new()
		body.name = "KarstCliff_%d" % idx
		body.position = Vector3(p2.x, wy, p2.y)
		body.rotation.y = float(cfg["rot"])
		body.collision_layer = 1
		add_child(body)

		var mi := MeshInstance3D.new()
		mi.mesh = cliff_mesh
		mi.scale = sc
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.visibility_range_end = 360.0
		body.add_child(mi)

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6.8 * sc.x, 4.8 * sc.y, 6.0 * sc.z)
		col.shape = box
		col.position.y = 1.4 * sc.y
		body.add_child(col)

	# 2. Instanced limestone boulders along slopes, trails & riverbanks (MultiMeshInstance3D)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4077

	var boulder_transforms: Array[Transform3D] = []
	var slab_transforms: Array[Transform3D] = []

	for _i in 460:
		var rx := rng.randf_range(-210.0, 210.0)
		var rz := rng.randf_range(-210.0, 210.0)
		if Vector2(rx - MontenegroTerrainData.VILLAGE_CENTER.x, rz - MontenegroTerrainData.VILLAGE_CENTER.y).length() < 32.0:
			continue
		if Vector2(rx - (-5.0), rz - 9.0).length() < 12.0:
			continue
		if data.get_road_info(rx, rz)["dist"] < 5.0:
			continue
		if data.get_trail_info(rx, rz)["dist"] < 3.0:
			continue

		var r_dist := data.get_river_distance(rx, rz)
		var st_dist: float = data.get_stream_info(rx, rz)["dist"]
		var near_water := (r_dist >= 6.8 and r_dist <= 13.5) or (st_dist >= 2.0 and st_dist <= 5.5)
		var slope := data.get_slope_deg(rx, rz)
		if not near_water and slope < 10.0 and rng.randf() > 0.22:
			continue

		var wy := data.get_height(rx, rz)
		var b := Basis.from_euler(Vector3(
			rng.randf_range(-0.22, 0.22),
			rng.randf_range(0.0, TAU),
			rng.randf_range(-0.22, 0.22)
		))
		var s := rng.randf_range(0.45, 1.45)
		if near_water:
			s *= 0.82
		b = b.scaled(Vector3(s, s * rng.randf_range(0.7, 1.15), s))
		var t := Transform3D(b, Vector3(rx, wy - 0.18 * s, rz))
		if rng.randf() < 0.35:
			slab_transforms.append(t)
		else:
			boulder_transforms.append(t)

	_add_rock_multimesh("KarstBoulders", boulder_mesh, boulder_transforms, 210.0)
	_add_rock_multimesh("LimestoneSlabs", flat_slab_mesh, slab_transforms, 180.0)

func _add_rock_multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D], max_dist: float) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = max_dist
	mmi.visibility_range_end_margin = 20.0
	add_child(mmi)

func _create_rock_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/terrain_limestone_albedo.png")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/terrain_limestone_normal.png")
	mat.normal_scale = 1.15
	mat.roughness = 0.88
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(2.4, 2.4, 2.4)
	return mat

func _make_karst_rock_mesh(seed_val: int, radii: Vector3, crag: float) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 1.6, 1.6)
	box.subdivide_width = 3
	box.subdivide_height = 3
	box.subdivide_depth = 3

	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]

	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.4
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 2

	for i in verts.size():
		var v := verts[i]
		var n := noise.get_noise_3d(v.x * 1.4, v.y * 1.4, v.z * 1.4)
		var n2 := noise.get_noise_3d(v.z * 2.1 + 11.0, v.y * 1.8, v.x * 2.1)
		# Taper upper crag slightly + fractured karst shelves
		var top_taper := lerpf(1.08, 0.62, clampf((v.y + 0.8) / 1.6, 0.0, 1.0))
		var disp := 0.84 + absf(n) * crag * 1.45 + n2 * 0.14
		v = Vector3(v.x * radii.x * disp * top_taper, v.y * radii.y * (0.9 + n * 0.24), v.z * radii.z * disp * top_taper)
		verts[i] = v

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	var temp := ArrayMesh.new()
	temp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(temp, 0)
	st.generate_normals()
	st.generate_tangents()
	var final_mesh := st.commit()
	final_mesh.surface_set_material(0, _rock_mat)
	return final_mesh
