class_name MontenegroTerrain
extends Node3D

@export var chunks_per_side: int = 8
@export var quads_per_chunk: int = 34

var data: MontenegroTerrainData

func build_terrain(terrain_data: MontenegroTerrainData) -> void:
	data = terrain_data
	var mat := _create_terrain_material()
	var chunk_world_size := MontenegroTerrainData.WORLD_SIZE / float(chunks_per_side)
	var step := chunk_world_size / float(quads_per_chunk)
	var verts_side := quads_per_chunk + 1

	for cz in chunks_per_side:
		for cx in chunks_per_side:
			var x0 := -MontenegroTerrainData.HALF_WORLD + float(cx) * chunk_world_size
			var z0 := -MontenegroTerrainData.HALF_WORLD + float(cz) * chunk_world_size

			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var tangents := PackedFloat32Array()
			var colors := PackedColorArray()
			var uvs := PackedVector2Array()
			var indices := PackedInt32Array()

			verts.resize(verts_side * verts_side)
			normals.resize(verts_side * verts_side)
			tangents.resize(verts_side * verts_side * 4)
			colors.resize(verts_side * verts_side)
			uvs.resize(verts_side * verts_side)
			indices.resize(quads_per_chunk * quads_per_chunk * 6)

			var idx := 0
			for iz in verts_side:
				var wz := z0 + float(iz) * step
				for ix in verts_side:
					var wx := x0 + float(ix) * step
					var wy := data.get_height(wx, wz)
					var n := _sample_normal(wx, wz)
					var t_vec := (Vector3.RIGHT - n * n.dot(Vector3.RIGHT)).normalized()
					verts[idx] = Vector3(wx, wy, wz)
					normals[idx] = n
					tangents[idx * 4] = t_vec.x
					tangents[idx * 4 + 1] = t_vec.y
					tangents[idx * 4 + 2] = t_vec.z
					tangents[idx * 4 + 3] = -1.0
					colors[idx] = data.get_splat_weights(wx, wz)
					uvs[idx] = Vector2(wx, wz) * 0.1
					idx += 1

			var ii := 0
			for iz in quads_per_chunk:
				for ix in quads_per_chunk:
					var a := iz * verts_side + ix
					var b := a + 1
					var c := a + verts_side
					var d := c + 1
					# Godot CW front-facing from +Y above
					indices[ii] = a
					indices[ii + 1] = b
					indices[ii + 2] = c
					indices[ii + 3] = b
					indices[ii + 4] = d
					indices[ii + 5] = c
					ii += 6

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

			var body := StaticBody3D.new()
			body.name = "TerrainChunk_%d_%d" % [cx, cz]
			body.collision_layer = 1
			body.collision_mask = 0
			add_child(body)

			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			body.add_child(mi)

			var col := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(mesh.get_faces())
			col.shape = shape
			body.add_child(col)

			var streamer := get_tree().root.get_node_or_null("WorldStreamer")
			if streamer and streamer.has_method("register_chunk"):
				var c_pos := Vector3(x0 + chunk_world_size * 0.5, 0.0, z0 + chunk_world_size * 0.5)
				var half_e := Vector2(chunk_world_size * 0.5, chunk_world_size * 0.5)
				streamer.register_chunk(body, c_pos, half_e)

func _sample_normal(x: float, z: float) -> Vector3:
	var eps := 1.4
	var dx := (data.get_height(x + eps, z) - data.get_height(x - eps, z)) / (2.0 * eps)
	var dz := (data.get_height(x, z + eps) - data.get_height(x, z - eps)) / (2.0 * eps)
	return Vector3(-dx, 1.0, -dz).normalized()

func _create_terrain_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/montenegro_terrain.gdshader")
	sm.set_shader_parameter("grass_albedo", load("res://assets/textures/terrain_grass_albedo.png"))
	sm.set_shader_parameter("grass_normal", load("res://assets/textures/terrain_grass_normal.png"))
	sm.set_shader_parameter("forest_albedo", load("res://assets/textures/terrain_forest_floor_albedo.png"))
	sm.set_shader_parameter("forest_normal", load("res://assets/textures/terrain_forest_floor_normal.png"))
	sm.set_shader_parameter("rock_albedo", load("res://assets/textures/terrain_limestone_albedo.png"))
	sm.set_shader_parameter("rock_normal", load("res://assets/textures/terrain_limestone_normal.png"))
	sm.set_shader_parameter("road_albedo", load("res://assets/textures/terrain_dirt_road_albedo.png"))
	sm.set_shader_parameter("road_normal", load("res://assets/textures/terrain_dirt_road_normal.png"))
	return sm
