extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var player: Node = load("res://characters/vlado/vlado_character.tscn").instantiate()
	root3d.add_child(player)
	await process_frame
	await process_frame
	var model: Node = player.get_node_or_null("VisualRoot/VladoModel")
	var bad := 0
	for mesh_name in ["Vlado_Body", "Vlado_Hair", "Rifle_BoltAction"]:
		var mi := model.find_child(mesh_name, true, false) as MeshInstance3D if model else null
		var mat := mi.get_surface_override_material(0) as StandardMaterial3D if mi else null
		var ok := mat != null and mat.albedo_texture != null and mat.metallic == 0.0 and mat.emission_enabled
		print("PHASE9_MATERIAL mesh=%s override=%s albedo=%s emission=%s ok=%s" % [mesh_name, mat != null, mat.albedo_texture != null if mat else false, mat.emission_enabled if mat else false, ok])
		if not ok: bad += 1
	print("PHASE9_VLADO_VISUAL_DONE bad=%d" % bad)
	quit(0 if bad == 0 else 1)
