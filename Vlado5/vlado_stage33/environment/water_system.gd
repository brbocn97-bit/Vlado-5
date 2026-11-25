class_name WaterSystem
extends Node3D

var _water_mat: ShaderMaterial

func build_water(data: MontenegroTerrainData) -> void:
	_water_mat = _create_water_material()
	_build_main_river(data)
	_build_mountain_stream(data)

func _create_water_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/mountain_water.gdshader")
	sm.set_shader_parameter("water_normal", load("res://assets/textures/water_normal.png"))
	return sm

func _build_main_river(data: MontenegroTerrainData) -> void:
	var z_start := -260.0
	var z_end := 240.0
	var z_steps := 140
	var half_w := 9.2
	var cross_cols := 9

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for iz in z_steps + 1:
		var t := float(iz) / float(z_steps)
		var wz := lerpf(z_start, z_end, t)
		var cx := data.get_river_center_x(wz)
		var wy := data.get_river_water_y(wz)

		var dx_dz := -0.55 + 16.0 * 0.021 * cos(wz * 0.021)
		var fwd := Vector3(dx_dz, 0.0, 1.0).normalized()
		var right := Vector3(fwd.z, 0.0, -fwd.x).normalized()

		for ix in cross_cols:
			var u := float(ix) / float(cross_cols - 1)
			var lat := lerpf(-half_w, half_w, u)
			var p := Vector3(cx, wy, wz) + right * lat
			var edge_dist := 1.0 - absf(u * 2.0 - 1.0)
			verts.append(p)
			normals.append(Vector3.UP)
			tangents.append_array([1.0, 0.0, 0.0, -1.0])
			colors.append(Color(clampf(edge_dist * 1.25, 0.0, 1.0), 0.0, 0.0, 1.0))
			uvs.append(Vector2(u, t * 40.0))

	for iz in z_steps:
		for ix in cross_cols - 1:
			var a := iz * cross_cols + ix
			var b := a + 1
			var c := a + cross_cols
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])

	_add_water_mesh("MainRiver", verts, normals, tangents, colors, uvs, indices)

func _build_mountain_stream(data: MontenegroTerrainData) -> void:
	# Smooth Catmull-Rom curve shared identically with terrain channel carving
	var dense := data.get_stream_points()

	var cols := 5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i in dense.size():
		var p2 := dense[i]
		var prev2 := dense[maxi(0, i - 1)]
		var next2 := dense[mini(dense.size() - 1, i + 1)]
		var dir2 := (next2 - prev2).normalized()
		var perp2 := Vector2(-dir2.y, dir2.x)

		var h_center := data.get_height(p2.x, p2.y)
		var h_prev := data.get_height(prev2.x, prev2.y)
		var h_next := data.get_height(next2.x, next2.y)
		var slope := clampf((h_prev - h_next) / maxf((next2 - prev2).length(), 0.1), 0.0, 1.0)
		var cascade_foam := clampf((slope - 0.14) * 2.8, 0.0, 0.85)
		var water_y := h_center + 0.18
		if p2.distance_to(Vector2(31.78, -45.0)) < 6.0:
			water_y = maxf(water_y, data.get_river_water_y(p2.y) + 0.02)

		var t_stream := float(i) / float(maxi(1, dense.size() - 1))
		var half_w := lerpf(1.15, 1.65, t_stream)
		var creek_y := h_center + 0.52
		if p2.distance_to(Vector2(31.78, -45.0)) < 6.5:
			creek_y = maxf(creek_y, data.get_river_water_y(p2.y) + 0.02)
		for ix in cols:
			var u := float(ix) / float(cols - 1)
			var lat := lerpf(-half_w, half_w, u)
			var wx := p2.x + perp2.x * lat
			var wz := p2.y + perp2.y * lat
			var edge_d := 1.0 - absf(u * 2.0 - 1.0)
			verts.append(Vector3(wx, creek_y, wz))
			normals.append(Vector3.UP)
			tangents.append_array([1.0, 0.0, 0.0, -1.0])
			colors.append(Color(clampf(edge_d, 0.0, 1.0), cascade_foam, 0.0, 1.0))
			uvs.append(Vector2(u, float(i) * 0.45))

	for i in dense.size() - 1:
		for ix in cols - 1:
			var a := i * cols + ix
			var b := a + 1
			var c := a + cols
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])

	_add_water_mesh("MountainStream", verts, normals, tangents, colors, uvs, indices)

func _add_water_mesh(
	node_name: String,
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	tangents: PackedFloat32Array,
	colors: PackedColorArray,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _water_mat)

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
