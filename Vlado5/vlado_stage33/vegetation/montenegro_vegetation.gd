class_name MontenegroVegetation
extends Node3D

# preload umjesto class_name — ne zavisi od .godot kesa
const Stage4TerenProps := preload("res://stage4/props/stage4_teren_props.gd")

var grass_chunks: Array[MultiMeshInstance3D] = []
var shrub_chunks: Array[MultiMeshInstance3D] = []
var tree_far_chunks: Array[MultiMeshInstance3D] = []

func build_vegetation(data: MontenegroTerrainData) -> void:
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_texture = load("res://assets/textures/pine_bark_albedo.png")
	bark_mat.normal_enabled = true
	bark_mat.normal_texture = load("res://assets/textures/pine_bark_normal.png")
	bark_mat.roughness = 0.92
	bark_mat.uv1_scale = Vector3(1.0, 2.5, 1.0)

	var pine_leaf_mat := ShaderMaterial.new()
	pine_leaf_mat.shader = load("res://shaders/vegetation_foliage.gdshader")
	pine_leaf_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/pine_bough_albedo.png"))
	pine_leaf_mat.set_shader_parameter("wind_strength", 0.08)
	pine_leaf_mat.set_shader_parameter("wind_speed", 1.5)
	pine_leaf_mat.set_shader_parameter("tint_color", Color(0.88, 0.92, 0.88))

	var beech_leaf_mat := ShaderMaterial.new()
	beech_leaf_mat.shader = load("res://shaders/vegetation_foliage.gdshader")
	beech_leaf_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/beech_leaf_albedo.png"))
	beech_leaf_mat.set_shader_parameter("wind_strength", 0.10)
	beech_leaf_mat.set_shader_parameter("wind_speed", 1.75)
	beech_leaf_mat.set_shader_parameter("tint_color", Color(0.92, 0.93, 0.88))

	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/vegetation_foliage.gdshader")
	grass_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/grass_tuft_albedo.png"))
	# POPRAVKA: trava je izgledala crno. texture grass_tuft_albedo ima prosjek
	# RGB 33/40/23 (tamno), a tint 1.22 nije dovoljan. Sada 2.05 + topliji ton.
	grass_mat.set_shader_parameter("alpha_cutoff", 0.18)
	grass_mat.set_shader_parameter("wind_strength", 0.09)
	grass_mat.set_shader_parameter("wind_speed", 2.15)
	grass_mat.set_shader_parameter("tint_color", Color(2.05, 2.00, 1.55))

	var pine_mesh := _build_pine_tree_mesh(bark_mat, pine_leaf_mat)
	var beech_mesh := _build_beech_tree_mesh(bark_mat, beech_leaf_mat)
	var shrub_mesh := _build_shrub_mesh(beech_leaf_mat)
	# === TRAVA: BILLBOARD, NE GLB ===
	# GLB trava (trava_zelena/visoka/suha) su fotogrametrijski skenovi sa
	# 26.125 / 9.867 / 16.726 trouglova PO JEDNOJ VLATI. Na 35.588 vlati to je
	# 641 MILIONA trouglova -> telefon se gusi. Zato trava ide iz proceduralnog
	# cross-quad mesha (16 trouglova) sa grass_tuft_albedo.png teksturom.
	# GLB trava ostaje na disku, koristi se samo za blizinu ako se ikad ukljuci.
	var grass_mesh: Mesh = _build_grass_tuft_mesh(grass_mat)
	const GRASS_DETAIL_TRIS := 8
	print("[Vegetation] trava = proceduralni cross-quad (8 tris), GLB trava iskljucena radi FPS")

	# 4x4 chunk buckets across [-300, 300]
	var pine_near_buckets := _init_buckets(16)
	var pine_far_buckets := _init_buckets(16)
	var beech_near_buckets := _init_buckets(16)
	var beech_far_buckets := _init_buckets(16)
	var shrub_buckets := _init_buckets(64)
	var grass_buckets := _init_buckets(64)

	var trunk_colliders := StaticBody3D.new()
	trunk_colliders.name = "TreeTrunkColliders"
	trunk_colliders.collision_layer = 1
	add_child(trunk_colliders)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1944

	# 1. Place dense conifers + mixed beech forests across foothills & valley groves
	var placed_trees := 0
	var trunk_shapes_added := 0
	for _attempt in 3400:
		if placed_trees >= 1050:
			break
		var tx := rng.randf_range(-255.0, 255.0)
		var tz := rng.randf_range(-255.0, 255.0)
		if not data.is_forest_zone(tx, tz):
			continue
		# Avoid spawning right in front of village view corridor near spawn
		if Vector2(tx - (-5.0), tz - 9.0).length() < 26.0:
			continue

		var wy := data.get_height(tx, tz)
		var dist_origin := Vector2(tx, tz).length()
		var scale_h := rng.randf_range(0.82, 1.48)
		var rot_y := rng.randf_range(0.0, TAU)
		var tilt := Vector3(rng.randf_range(-0.04, 0.04), rot_y, rng.randf_range(-0.04, 0.04))
		var b := Basis.from_euler(tilt).scaled(Vector3(scale_h * rng.randf_range(0.9, 1.12), scale_h, scale_h * rng.randf_range(0.9, 1.12)))
		var xf := Transform3D(b, Vector3(tx, wy - 0.18, tz))

		var b_idx := _chunk_index(tx, tz)
		var st_dist: float = float(data.get_stream_info(tx, tz)["dist"])
		var is_beech: bool = (wy < 22.0 and rng.randf() < 0.34) or (st_dist < 14.0 and rng.randf() < 0.65)
		var is_near := dist_origin < 145.0

		if is_beech:
			if is_near:
				beech_near_buckets[b_idx].append(xf)
			else:
				beech_far_buckets[b_idx].append(xf)
		else:
			if is_near:
				pine_near_buckets[b_idx].append(xf)
			else:
				pine_far_buckets[b_idx].append(xf)

		if is_near and trunk_shapes_added < 220:
			var col := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.24 * scale_h
			cyl.height = 3.2
			col.shape = cyl
			col.position = Vector3(tx, wy + 1.4, tz)
			trunk_colliders.add_child(col)
			trunk_shapes_added += 1

		placed_trees += 1

	# 2. Place shrubs & forest undergrowth (around clearings, riverbanks, stone fences)
	for _s in 3200:
		var sx := rng.randf_range(-165.0, 165.0)
		var sz := rng.randf_range(-165.0, 165.0)
		if data.get_road_info(sx, sz)["dist"] < 3.4 or data.get_trail_info(sx, sz)["dist"] < 2.1:
			continue
		if data.get_river_distance(sx, sz) < 9.5 or data.get_stream_info(sx, sz)["dist"] < 2.2:
			continue
		if Vector2(sx - MontenegroTerrainData.VILLAGE_CENTER.x, sz - MontenegroTerrainData.VILLAGE_CENTER.y).length() < 16.0:
			if rng.randf() < 0.78:
				continue
		if Vector2(sx - (-5.0), sz - 9.0).length() < 5.5:
			continue
		var sy := data.get_height(sx, sz)
		if sy > 44.0 or data.get_slope_deg(sx, sz) > 34.0:
			continue
		var sc := rng.randf_range(0.68, 1.38)
		var xf := Transform3D(Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.15), sc)), Vector3(sx, sy - 0.06, sz))
		shrub_buckets[_chunk_index_grid(sx, sz, 8)].append(xf)

	# 3. Place wild grass tufts: dense playable-valley meadow pass + wider hillside pass
	# POPRAVKA: trava je bila rijetka (52000 pokusaja, tanke vlati od 0.22 m).
	# Sada 92000 pokusaja sa naglaskom na prvih 120 m, gdje se stvarno gleda.
	for _g in 92000:
		var rad := 40.0 if _g < 12000 else (75.0 if _g < 30000 else (120.0 if _g < 52000 else (180.0 if _g < 70000 else (320.0 if _g < 84000 else 620.0))))
		var gx := rng.randf_range(-rad, rad)
		var gz := rng.randf_range(-rad, rad)
		if data.get_road_info(gx, gz)["dist"] < 2.25 or data.get_trail_info(gx, gz)["dist"] < 1.2:
			continue
		if data.get_river_distance(gx, gz) < 8.4 or data.get_stream_info(gx, gz)["dist"] < 2.1:
			continue
		# Keep village courtyard neatly trimmed and house footprints clean
		if _inside_village_building(gx, gz):
			continue
		if Vector2(gx - MontenegroTerrainData.VILLAGE_CENTER.x, gz - MontenegroTerrainData.VILLAGE_CENTER.y).length() < 15.0 and rng.randf() < 0.72:
			continue
		var gy := data.get_height(gx, gz)
		if gy > 62.0 or data.get_slope_deg(gx, gz) > 34.0:
			continue
		var sc := rng.randf_range(0.85, 1.52)
		var xf := Transform3D(Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(sc, sc * rng.randf_range(0.85, 1.2), sc)), Vector3(gx, gy - 0.04, gz))
		grass_buckets[_chunk_index_grid(gx, gz, 8)].append(xf)

	# 4. Fallen forest logs along playable valley woodland borders
	_place_fallen_logs(data, bark_mat)

	# Emit MultiMeshInstance3D chunks
	for i in 16:
		_spawn_multimesh_chunk("PineNear_%d" % i, pine_mesh, pine_near_buckets[i], true, 220.0)
		var pf := _spawn_multimesh_chunk("PineFar_%d" % i, pine_mesh, pine_far_buckets[i], false, 380.0)
		if pf:
			tree_far_chunks.append(pf)
		_spawn_multimesh_chunk("BeechNear_%d" % i, beech_mesh, beech_near_buckets[i], true, 210.0)
		var bf := _spawn_multimesh_chunk("BeechFar_%d" % i, beech_mesh, beech_far_buckets[i], false, 360.0)
		if bf:
			tree_far_chunks.append(bf)
	for j in 64:
		var sh := _spawn_multimesh_chunk("Shrubs_%d" % j, shrub_mesh, shrub_buckets[j], false, 135.0)
		if sh:
			shrub_chunks.append(sh)
		var gr := _spawn_multimesh_chunk("Grass_%d" % j, grass_mesh, grass_buckets[j], false, 105.0)
		if gr:
			grass_chunks.append(gr)

func apply_quality_scale(tier: int) -> void:
	# 0=Low, 1=Medium, 2=High
	var grass_dist := 68.0 if tier == 0 else (85.0 if tier == 1 else 105.0)
	var shrub_dist := 92.0 if tier == 0 else (112.0 if tier == 1 else 135.0)
	var far_tree_dist := 260.0 if tier == 0 else (320.0 if tier == 1 else 380.0)
	for g in grass_chunks:
		g.visibility_range_end = grass_dist
	for s in shrub_chunks:
		s.visibility_range_end = shrub_dist
	for t in tree_far_chunks:
		t.visibility_range_end = far_tree_dist

func _inside_village_building(x: float, z: float) -> bool:
	# Exclude footprints of main stone house, cottage, barn & well
	var footprints := [
		Rect2(-28.5, -2.0, 9.0, 8.0),
		Rect2(-40.0, -13.0, 8.0, 8.0),
		Rect2(-23.5, 13.0, 9.0, 8.0),
		Rect2(-18.0, 3.5, 4.0, 4.0),
	]
	var p := Vector2(x, z)
	for r in footprints:
		if r.has_point(p):
			return true
	return false

func _init_buckets(count: int) -> Array:
	var arr := []
	for _i in count:
		var typed: Array[Transform3D] = []
		arr.append(typed)
	return arr

func _chunk_index(x: float, z: float) -> int:
	return _chunk_index_grid(x, z, 4)

func _chunk_index_grid(x: float, z: float, grid_n: int) -> int:
	var cell := 600.0 / float(grid_n)
	var cx := clampi(int((x + 300.0) / cell), 0, grid_n - 1)
	var cz := clampi(int((z + 300.0) / cell), 0, grid_n - 1)
	return cz * grid_n + cx

func _spawn_multimesh_chunk(node_name: String, mesh: Mesh, xforms: Array[Transform3D], shadows: bool, max_dist: float) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = max_dist
	mmi.visibility_range_end_margin = 14.0
	add_child(mmi)
	return mmi

func _place_fallen_logs(data: MontenegroTerrainData, bark_mat: Material) -> void:
	var cyl_mesh := CylinderMesh.new()
	cyl_mesh.top_radius = 0.20
	cyl_mesh.bottom_radius = 0.26
	cyl_mesh.height = 4.2
	cyl_mesh.radial_segments = 7
	cyl_mesh.material = bark_mat

	var log_spots := [
		Vector2(-32.0, -34.0),
		Vector2(-52.0, -54.0),
		Vector2(44.0, -6.0),
		Vector2(54.0, -48.0),
		Vector2(-48.0, 26.0),
		Vector2(12.0, -68.0),
	]
	for i in log_spots.size():
		var p2: Vector2 = log_spots[i]
		var wy := data.get_height(p2.x, p2.y)
		var body := StaticBody3D.new()
		body.name = "FallenLog_%d" % i
		body.position = Vector3(p2.x, wy + 0.18, p2.y)
		body.rotation = Vector3(0.0, float(i) * 1.15, PI * 0.5)
		body.collision_layer = 1
		add_child(body)

		var mi := MeshInstance3D.new()
		mi.mesh = cyl_mesh
		mi.visibility_range_end = 130.0
		body.add_child(mi)

		var col := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.25
		cs.height = 4.2
		col.shape = cs
		body.add_child(col)

func _build_pine_tree_mesh(bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.bottom_radius = 0.23
	trunk.top_radius = 0.05
	trunk.height = 8.4
	trunk.radial_segments = 6
	trunk.rings = 2
	st_trunk.append_from(trunk, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.2, 0.0)))
	var mesh := st_trunk.commit()
	mesh.surface_set_material(0, bark_mat)

	var st_fol := SurfaceTool.new()
	st_fol.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 5 tiered radial pine bough clusters from y=2.3m to y=8.2m
	var tiers := [
		{"y": 2.6, "w": 2.45, "h": 1.65, "tilt": 0.42, "cards": 4},
		{"y": 3.9, "w": 2.15, "h": 1.55, "tilt": 0.45, "cards": 4},
		{"y": 5.2, "w": 1.80, "h": 1.40, "tilt": 0.48, "cards": 4},
		{"y": 6.4, "w": 1.38, "h": 1.25, "tilt": 0.50, "cards": 3},
		{"y": 7.5, "w": 0.96, "h": 1.15, "tilt": 0.45, "cards": 3},
	]
	for t_idx in tiers.size():
		var t: Dictionary = tiers[t_idx]
		var cards: int = int(t["cards"])
		for c in cards:
			var ang := (float(c) / float(cards)) * PI + float(t_idx) * 0.55
			_add_crossed_foliage_card(st_fol, Vector3(0.0, float(t["y"]), 0.0), float(t["w"]), float(t["h"]), ang, float(t["tilt"]), 0.35 + float(t_idx) * 0.14)
	# Crown vertical cross-cards at tip
	_add_crossed_foliage_card(st_fol, Vector3(0.0, 8.2, 0.0), 0.72, 1.10, 0.25, 0.15, 0.95)
	_add_crossed_foliage_card(st_fol, Vector3(0.0, 8.2, 0.0), 0.72, 1.10, 1.82, 0.15, 0.95)

	st_fol.generate_normals()
	mesh = st_fol.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh

func _build_beech_tree_mesh(bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main_t := CylinderMesh.new()
	main_t.bottom_radius = 0.26
	main_t.top_radius = 0.11
	main_t.height = 4.2
	main_t.radial_segments = 6
	st_trunk.append_from(main_t, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.1, 0.0)))

	var limb := CylinderMesh.new()
	limb.bottom_radius = 0.11
	limb.top_radius = 0.04
	limb.height = 2.6
	limb.radial_segments = 5
	st_trunk.append_from(limb, 0, Transform3D(Basis.from_euler(Vector3(0.45, 0.4, 0.35)), Vector3(0.48, 4.3, 0.32)))
	st_trunk.append_from(limb, 0, Transform3D(Basis.from_euler(Vector3(-0.40, 1.9, -0.38)), Vector3(-0.46, 4.2, -0.28)))

	var mesh := st_trunk.commit()
	mesh.surface_set_material(0, bark_mat)

	var st_fol := SurfaceTool.new()
	st_fol.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crown_pts := [
		Vector3(0.0, 5.2, 0.0),
		Vector3(0.95, 4.6, 0.55),
		Vector3(-0.90, 4.5, -0.48),
		Vector3(0.35, 4.7, -0.92),
		Vector3(-0.35, 4.8, 0.88),
		Vector3(0.0, 6.2, 0.0),
	]
	for i in crown_pts.size():
		var cp: Vector3 = crown_pts[i]
		for k in 3:
			var ang := float(k) * (PI / 3.0) + float(i) * 0.45
			_add_crossed_foliage_card(st_fol, cp, 2.25, 1.85, ang, 0.32 * (k - 1), 0.72)

	st_fol.generate_normals()
	mesh = st_fol.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh

func _build_shrub_mesh(leaf_mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var ang := float(i) * (PI * 0.25)
		_add_crossed_foliage_card(st, Vector3(0.0, 0.55, 0.0), 1.35, 1.05, ang, 0.25, 0.55)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, leaf_mat)
	return m

func _build_grass_tuft_mesh(grass_mat: Material) -> ArrayMesh:
	# Keep individual tufts below knee height and narrow enough to avoid a
	# billboard-card look in the foreground.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var ang := float(i) * (PI / 4.0)
		var b := Basis.from_euler(Vector3(0.0, ang, 0.0))
		var hw := 0.09
		var h := 0.48
		var p0 := b * Vector3(-hw, 0.0, 0.0)
		var p1 := b * Vector3(hw, 0.0, 0.0)
		var p2 := b * Vector3(hw, h, 0.0)
		var p3 := b * Vector3(-hw, h, 0.0)
		var n := (b * Vector3.BACK).normalized()
		_emit_quad(st, p0, p1, p2, p3, n, 0.0, 1.0)
	var m := st.commit()
	m.surface_set_material(0, grass_mat)
	return m

func _add_crossed_foliage_card(st: SurfaceTool, center: Vector3, width: float, height: float, yaw: float, pitch: float, sway_weight: float) -> void:
	var rot := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var hw := width * 0.5
	var hh := height * 0.5
	var p0 := center + rot * Vector3(-hw, -hh, 0.0)
	var p1 := center + rot * Vector3(hw, -hh, 0.0)
	var p2 := center + rot * Vector3(hw, hh, 0.0)
	var p3 := center + rot * Vector3(-hw, hh, 0.0)
	var n := (rot * Vector3.BACK).normalized()
	_emit_quad(st, p0, p1, p2, p3, n, sway_weight * 0.35, sway_weight)

func _emit_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, sway_bot: float, sway_top: float) -> void:
	# Triangle 1: p0 -> p1 -> p2
	st.set_normal(n)
	st.set_color(Color(sway_bot, 0.0, 0.0, 1.0))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(p0)

	st.set_normal(n)
	st.set_color(Color(sway_bot, 0.0, 0.0, 1.0))
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p1)

	st.set_normal(n)
	st.set_color(Color(sway_top, 0.0, 0.0, 1.0))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p2)

	# Triangle 2: p0 -> p2 -> p3
	st.set_normal(n)
	st.set_color(Color(sway_bot, 0.0, 0.0, 1.0))
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(p0)

	st.set_normal(n)
	st.set_color(Color(sway_top, 0.0, 0.0, 1.0))
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p2)

	st.set_normal(n)
	st.set_color(Color(sway_top, 0.0, 0.0, 1.0))
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p3)
