extends SceneTree

const OUTPUT := "res://build/captures/gameplay_live.png"

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene := load("res://scenes/main/montenegro_world.tscn") as PackedScene
	if scene == null:
		push_error("Capture: scene not found")
		quit(2)
		return

	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var stage4 := world.find_child("Stage4World", true, false)
	for i in 180:
		await process_frame
		if stage4 == null:
			stage4 = world.find_child("Stage4World", true, false)

	if stage4 and stage4.has_method("teleport_to_region"):
		stage4.teleport_to_region("Security_Checkpoint")
		await process_frame
		await process_frame

	for i in 120:
		await process_frame

	var viewport_image := root.get_texture().get_image()
	if viewport_image == null:
		push_error("Capture: viewport image unavailable")
		quit(3)
		return
	var absolute := ProjectSettings.globalize_path(OUTPUT)
	var err := viewport_image.save_png(absolute)
	if err != OK:
		push_error("Capture: cannot save screenshot")
		quit(4)
		return
	print("[Capture] live gameplay screenshot: " + absolute)
	quit(0)
