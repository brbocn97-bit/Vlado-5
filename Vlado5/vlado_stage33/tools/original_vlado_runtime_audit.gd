extends SceneTree

func _initialize() -> void:
	await process_frame
	var main: String = String(ProjectSettings.get_setting("application/run/main_scene"))
	print("ORIGINAL_VLADO_AUDIT main_scene=", main)

	var player_scene: PackedScene = load("res://characters/vlado/vlado_character.tscn")
	if player_scene == null:
		push_error("Player prefab could not be loaded")
		quit(1)
		return
	var player: Node = player_scene.instantiate()
	root.add_child(player)
	await process_frame

	var model_root: Node = player.find_child("VladoModel", true, false)
	var model_path := "res://assets/characters/vlado/vlado_sipcic.glb"
	print("ORIGINAL_VLADO_AUDIT model_path=", model_path)

	if model_root == null:
		push_error("VladoModel is missing")
		quit(1)
		return

	var meshes: Array[String] = []
	for c: Node in model_root.find_children("*", "MeshInstance3D", true, false):
		if c is MeshInstance3D:
			meshes.append(String(c.name))
	print("ORIGINAL_VLADO_AUDIT meshes=", ",".join(meshes))

	var skel := model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		print("ORIGINAL_VLADO_AUDIT bone_count=", skel.get_bone_count())
	else:
		push_error("Skeleton3D is missing")
		quit(1)
		return

	var ap := model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		var names: Array[String] = []
		for library_name in ap.get_animation_library_list():
			var library := ap.get_animation_library(library_name)
			for animation_name in library.get_animation_list():
				names.append(library_name + "/" + animation_name)
		print("ORIGINAL_VLADO_AUDIT animations=", ",".join(names))
	else:
		push_error("AnimationPlayer is missing")
		quit(1)
		return

	player.queue_free()
	quit(0)
