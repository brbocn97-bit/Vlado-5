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
	for mesh_name in ["Vlado_Body", "Vlado_Hair", "Rifle_Prop"]:
		var mi := model.find_child(mesh_name, true, false) as MeshInstance3D if model else null
		var mat := mi.get_active_material(0) as StandardMaterial3D if mi else null
		var ok := mi != null and mi.mesh != null and mat != null
		print("PHASE9_MATERIAL mesh=%s present=%s material=%s ok=%s" % [mesh_name, mi != null, mat != null, ok])
		if not ok: bad += 1
	print("PHASE9_VLADO_VISUAL_DONE bad=%d" % bad)
	quit(0 if bad == 0 else 1)
