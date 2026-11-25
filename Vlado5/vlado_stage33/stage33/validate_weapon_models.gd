extends SceneTree
## Validation tool — verifies the three Stage 3.3 weapon GLBs and reports real
## numbers (triangles, materials, dimensions) plus the scale/orientation each
## one needs so it sits correctly in Vlado's hands.
##
## Run:  godot --headless --path . --script stage33/validate_weapon_models.gd


func _init() -> void:
	print("=== Stage 3.3 weapon model validation ===")
	var specs := {
		"gasser_m1870": 0.36,
		"m48": 1.10,
		"mp40": 0.83,
		"maschinengewehr_mg_42": 1.22,
		"mauser_98_sporting": 1.10,
		"m24_mauser": 1.10,
		"mosin_91_30": 1.23,
		"carcano_m91": 1.12,
		"mannlicher_m95": 1.10,
		"lee_enfield_no4": 1.13,
		"svt40": 1.22,
		"g43": 1.12,
		"m1_carbine": 0.90,
		"m1_garand": 1.11,
		"thompson_m1a1": 0.81,
		"sten_mk2": 0.76,
		"ppsh41": 0.84,
		"beretta_mab38": 0.87,
		"zk383": 0.88,
		"mg34": 1.22,
		"breda_m30": 1.15,
		"bren_mk1": 1.15,
		"zb26": 1.16,
		"luger_p08": 0.24,
		"walther_p38": 0.23,
		"tt33": 0.21,
		"browning_m1922": 0.20,
		"lovacka_dvocijevka": 1.12,
		"winchester_m1897": 1.02,
		"m24_stielhandgranate": 0.36,
		"bajonet_m1924": 0.43,
	}
	for id in specs:
		_validate(id, specs[id])
	quit()


func _validate(id: String, target_len: float) -> void:
	var path := "res://assets/weapons/Models/%s.glb" % id
	print("\n--- %s" % id)
	if id == "m48":
		print("    STATUS: INTEGRATED SKINNED MODEL in Vlado_Sipcic_Final.glb")
		return
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
