extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var debug_hud: Node = load("res://ui/debug_hud.tscn").instantiate()
	host.add_child(debug_hud)
	var stage4_script: Script = load("res://stage4/ui/stage4_hud.gd")
	var stage4_hud: Node = stage4_script.new()
	host.add_child(stage4_hud)
	await process_frame
	await process_frame
	var telemetry := debug_hud.get_node_or_null("Panel/Margin/VBox/TelemetryLabel") as Control
	var controls := debug_hud.get_node_or_null("Panel/Margin/VBox/ControlsRow") as Control
	var stream_panel = stage4_hud.get("lbl_stream")
	var rot_button = stage4_hud.get("_btn_rot")
	var bad := 0
	var debug_hidden := telemetry != null and controls != null and not telemetry.visible and not controls.visible
	if not debug_hidden: bad += 1
	if stream_panel != null: bad += 1
	if rot_button != null: bad += 1
	print("PHASE9_PRODUCTION_UI telemetry_hidden=%s controls_hidden=%s stream_absent=%s rot_absent=%s bad=%d" % [telemetry != null and not telemetry.visible, controls != null and not controls.visible, stream_panel == null, rot_button == null, bad])
	quit(0 if bad == 0 else 1)
