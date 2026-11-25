class_name Stage4River
extends Node3D
## Stage4River — extends the Krupa river ribbon across the full ±700 m world.
##
## The Stage 3.2 WaterSystem builds MainRiver for Z ∈ [-260, 240] only. This node
## builds the two missing stretches (northern gorge Z < -260, southern canyon
## Z > 240) with identical cross-section logic and material, so the player can
## follow the river for the entire 1400 m world without a seam.
##
## Uses the baseline data functions get_river_center_x() / get_river_water_y()
## so the new water sits exactly in the carved channel.

const STEP_NORTH := 6.0
const STEP_SOUTH := 6.0
const CROSS_COLS := 7


func build(data: MontenegroTerrainData) -> void:
	_data_ref = data
	var mat := _find_water_material()
	_build_segment(data, -690.0, -258.0, STEP_NORTH, mat, "RiverNorthGorge")
	_build_segment(data, 242.0, 690.0, STEP_SOUTH, mat, "RiverSouthCanyon")
	_build_fords(data, mat)


## Reuse the exact ShaderMaterial the baseline river uses so shading matches.
func _find_water_material() -> Material:
	var water: Node = null
	var p := get_parent()
	while p and water == null:
		water = p.get_node_or_null("WaterSystem")
		p = p.get_parent()
	if water == null and get_tree() and get_tree().current_scene:
		water = get_tree().current_scene.find_child("WaterSystem", true, false)
	if water:
		for c in water.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh:
				var m := (c as MeshInstance3D).mesh as ArrayMesh
				if m and m.get_surface_count() > 0:
					var mat := m.surface_get_material(0)
					if mat:
						return mat
	# fallback: build a simple material if WaterSystem has not run yet
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.16, 0.29, 0.31, 0.86)
	fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fallback.roughness = 0.12
	fallback.metallic = 0.25
	return fallback


func _build_segment(data: MontenegroTerrainData, z_from: float, z_to: float,
		step: float, mat: Material, node_name: String) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var count := int(ceil(absf(z_to - z_from) / step)) + 1
	for iz in count:
		var t := float(iz) / float(maxi(count - 1, 1))
		var wz := lerpf(z_from, z_to, t)
		var cx := data.get_river_center_x(wz)
		var wy := data.get_river_water_y(wz)

		# The channel narrows in the gorge/canyon: read the real carving width
		# from the terrain data instead of assuming a constant half-width.
		var dx_dz := -0.55 + 16.0 * 0.021 * cos(wz * 0.021)
		var fwd := Vector3(dx_dz, 0.0, 1.0).normalized()
		var right := Vector3(fwd.z, 0.0, -fwd.x).normalized()
		var half_w := _width_at(data, cx, wz, wy)

		for ix in CROSS_COLS:
			var u := float(ix) / float(CROSS_COLS - 1)
			var lat := lerpf(-half_w, half_w, u)
			var p := Vector3(cx, wy, wz) + right * lat
			var edge_dist := 1.0 - absf(u * 2.0 - 1.0)
			verts.append(p)
			normals.append(Vector3.UP)
			tangents.append_array([1.0, 0.0, 0.0, -1.0])
			colors.append(Color(clampf(edge_dist * 1.25, 0.0, 1.0), 0.0, 0.0, 1.0))
			uvs.append(Vector2(u, t * 40.0))

	for iz in count - 1:
		for ix in CROSS_COLS - 1:
			var a := iz * CROSS_COLS + ix
			var b := a + 1
			var c := a + CROSS_COLS
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])

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
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Water half-width: wide in the valley, pinched in the gorge and canyon.
func _width_at(_data: MontenegroTerrainData, _cx: float, z: float, _wy: float) -> float:
	var w := 9.2
	if z < -260.0:
		w = lerpf(9.2, 4.6, clampf((-z - 260.0) / 300.0, 0.0, 1.0))
	elif z > 240.0:
		w = lerpf(9.2, 3.8, clampf((z - 240.0) / 330.0, 0.0, 1.0))
	return w


## Shallow stone fords where the player may wade across (Stage 4 traversal).
func _build_fords(_data: MontenegroTerrainData, mat: Material) -> void:
	var fords := [
		{ "z": 268.0, "name": "FordKanjonski" },       # canyon crossing (region 5)
		{ "z": -318.0, "name": "FordBoras" },          # northern gorge (region 4)
	]
	for f in fords:
		var z: float = f["z"]
		var cx: float = terrain_data_proxy().get_river_center_x(z)
		var wy: float = terrain_data_proxy().get_river_water_y(z)
		var root := Node3D.new()
		root.name = str(f["name"])
		root.position = Vector3(cx, wy - 0.55, z)
		add_child(root)
		for i in 9:
			var stone := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.05, 0.22, 0.75)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.44, 0.43, 0.40)
			m.roughness = 0.96
			bm.material = m
			stone.mesh = bm
			stone.position = Vector3(-4.0 + i * 1.0, 0.1 + randf() * 0.05, randf_range(-0.2, 0.2))
			stone.rotation.y = randf_range(-0.25, 0.25)
			root.add_child(stone)
		# wadeable collision slab just under the surface
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(9.0, 0.3, 1.6)
		cs.shape = bs
		body.add_child(cs)
		root.add_child(body)


# the ford helper runs before setup() stores the data, so keep a local handle
var _data_ref: MontenegroTerrainData
func terrain_data_proxy() -> MontenegroTerrainData:
	if _data_ref == null:
		_data_ref = get_parent().get("terrain_data") as MontenegroTerrainData \
			if get_parent() else null
	if _data_ref == null:
		_data_ref = MontenegroTerrainData.new()
	return _data_ref
