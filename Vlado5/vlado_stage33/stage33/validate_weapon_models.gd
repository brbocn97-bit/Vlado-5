extends SceneTree
## Validation tool — verifies the three Stage 3.3 weapon GLBs and reports real
## numbers (triangles, materials, dimensions) plus the scale/orientation each
## one needs so it sits correctly in Vlado's hands.
##
## Run:  godot --headless --path . --script stage33/validate_weapon_models.gd


func _init() -> void:
	print("=== Stage 3.3 weapon model validation ===")
	var specs := {
		"mp40": 0.63,
		"maschinengewehr_mg_42": 1.22,
		"mauser_98_sporting": 1.10,
	}
	for id in specs:
		_validate(id, specs[id])
	quit()


func _validate(id: String, target_len: float) -> void:
	var path := "res://assets/weapons/Models/%s.glb" % id
	print("\n--- %s" % id)
	if not ResourceLoader.exists(path):
		print("    STATUS: MISSING  (%s)" % path)
		return
	var scene := load(path) as PackedScene
	if scene == null:
		print("    STATUS: FAILED TO LOAD")
		return
	var inst := scene.instantiate()
	var tris := 0
	var verts := 0
	var surfaces := 0
	var mats := {}
	var aabb := AABB()
	var first := true
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mi := n as MeshInstance3D
			var m := mi.mesh
			for si in m.get_surface_count():
				surfaces += 1
				var arr := m.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				var pos = arr[Mesh.ARRAY_VERTEX]
				if pos != null:
					verts += (pos as PackedVector3Array).size()
				if idx != null:
					tris += (idx as PackedInt32Array).size() / 3
				elif pos != null:
					tris += (pos as PackedVector3Array).size() / 3
				var mat := m.surface_get_material(si)
				if mat:
					var key: String = mat.resource_name
					if key == "":
						key = (mat as BaseMaterial3D).albedo_texture.resource_path.get_file() if (mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture) else mat.get_class()
					mats[key] = true
				var box: AABB = mi.transform * mi.get_aabb()
				aabb = box if first else aabb.merge(box)
				first = false
		for c in n.get_children():
			stack.append(c)

	print("    triangles : %d" % tris)
	print("    vertices  : %d" % verts)
	print("    surfaces  : %d   materials: %d" % [surfaces, mats.size()])
	print("    raw size  : x=%.3f y=%.3f z=%.3f" % [aabb.size.x, aabb.size.y, aabb.size.z])
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if longest > 0.0001:
		print("    scale to %.2f m -> %.5f" % [target_len, target_len / longest])
	# which local axis is the barrel?
	if aabb.size.x >= aabb.size.z:
		print("    barrel axis: X  -> needs a 90 deg Y rotation on mount")
	else:
		print("    barrel axis: Z  -> no mount rotation needed")
	print("    budget     : %s" % ("OK for mobile" if tris < 70000 else "HEAVY — needs decimation"))
	inst.free()
