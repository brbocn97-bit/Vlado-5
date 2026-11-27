extends SceneTree

const MODEL_SCENE_PATH := "res://assets/characters/vlado/vlado_sipcic.glb"
const OUTPUT_DIR := "/workspaces/input/phase3_audit/visual_validation"
const CLIP_NAMES: Array[String] = [
	"idle",
	"idle_rifle",
	"run",
	"run_rifle",
	"jump",
	"jump_in_place",
	"jump_rifle",
	"jump_rifle_in_place",
]
const SAMPLE_STEPS := 16

var world: Node3D
var model: Node3D
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var camera: Camera3D
var combined_bounds := AABB()
var report_lines: Array[String] = []
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_setup_world()
	var packed := load(MODEL_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load original model scene: " + MODEL_SCENE_PATH)
		_finish()
		return
	model = packed.instantiate() as Node3D
	if model == null:
		_fail("Original GLB did not instantiate as Node3D")
		_finish()
		return
	world.add_child(model)
	await process_frame
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if animation_player == null or skeleton == null:
		_fail("Original model is missing AnimationPlayer or Skeleton3D")
		_finish()
		return

	_measure_model_bounds()
	_frame_camera()
	_report_header()
	for clip_name in CLIP_NAMES:
		if not animation_player.has_animation(clip_name):
			_fail("Missing native animation: " + clip_name)
			continue
		await _validate_clip(clip_name)

	_append_review_checklist()
	report_lines.append("")
	report_lines.append("## Summary")
	report_lines.append("- Status: **PENDING HUMAN REVIEW**")
	report_lines.append("- Native clip count found: %d / %d" % [animation_player.get_animation_list().size(), CLIP_NAMES.size()])
	report_lines.append("- Validator errors: %s" % ("yes" if failed else "none"))
	report_lines.append("- Static screenshots do not prove absence of limb deformation, foot sliding, or contact errors; inspect the frame sequences interactively.")
	report_lines.append("- No automatic visual pass is claimed.")
	_finish()


func _setup_world() -> void:
	get_root().size = Vector2i(1440, 900)
	world = Node3D.new()
	world.name = "NativeVisualAuditWorld"
	get_root().add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.82)
	env.ambient_light_energy = 0.65
	environment.environment = env
	world.add_child(environment)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-8.0, 145.0, 0.0)
	fill.light_energy = 0.65
	fill.shadow_enabled = false
	world.add_child(fill)

	var floor := MeshInstance3D.new()
	floor.name = "AuditFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8.0, 8.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.28, 0.30, 0.33)
	floor_material.roughness = 0.9
	floor.material_override = floor_material
	world.add_child(floor)

	camera = Camera3D.new()
	camera.name = "AuditCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.current = true
	world.add_child(camera)


func _measure_model_bounds() -> void:
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		if not found:
			combined_bounds = mesh_bounds
			found = true
		else:
			combined_bounds = combined_bounds.merge(mesh_bounds)
	if not found:
		_fail("No meshes found in original model")
		return
	print("VISUAL_AUDIT_BOUNDS=%s" % str(combined_bounds))
	_set_floor_height(combined_bounds.position.y)


func _set_floor_height(y: float) -> void:
	var floor := world.get_node("AuditFloor") as MeshInstance3D
	floor.position.y = y


func _frame_camera() -> void:
	var center := combined_bounds.get_center()
	camera.size = maxf(combined_bounds.size.y * 1.28, 2.0)
	_set_camera_view("front", center)


func _set_camera_view(view_name: String, target: Vector3) -> void:
	var distance := maxf(combined_bounds.size.y * 2.7, 4.0)
	if view_name == "front":
		camera.position = target + Vector3(0.0, 0.0, distance)
	else:
		camera.position = target + Vector3(distance, 0.0, 0.0)
	camera.look_at(target, Vector3.UP)
	camera.fov = 38.0
	camera.size = maxf(combined_bounds.size.y * 1.24, 2.0)


func _report_header() -> void:
	report_lines.append("# Vlado Native Animation Visual Validation")
	report_lines.append("")
	report_lines.append("**Status: PENDING HUMAN REVIEW**")
	report_lines.append("")
	report_lines.append("Source: `%s` (directly instantiated original GLB; no retargeting)." % MODEL_SCENE_PATH)
	report_lines.append("")
	report_lines.append("Each native clip has a rendered still from the front and side at a representative sample time. These stills are review evidence, not proof of animation quality. Use the interactive-review command below to inspect motion over time.")
	report_lines.append("")
	report_lines.append("Interactive review command (open the original GLB scene in Godot Editor, then scrub each AnimationPlayer clip):")
	report_lines.append("")
	report_lines.append("```sh")
	report_lines.append("godot --editor --path Vlado5/vlado_stage33 res://assets/characters/vlado/vlado_sipcic.glb")
	report_lines.append("```")
	report_lines.append("")
	report_lines.append("| Native clip | Length (s) | Sample time (s) | Front | Side | Max per-foot vertical range (m) | Max per-foot horizontal excursion (m) |")
	report_lines.append("|---|---:|---:|---|---|---:|---:|")


func _append_review_checklist() -> void:
	report_lines.append("")
	report_lines.append("## Human review checklist (all items pending)")
	report_lines.append("")
	report_lines.append("Mark each item only after reviewing the rendered sequence and scrubbing the full clip. Foot-bone motion metrics below are diagnostics, not a foot-sliding verdict.")
	report_lines.append("")
	report_lines.append("| Clip | Arms / hands | Rifle / grip | Shoulders | Hips | Knees | Feet / ground contact | Deformation | Foot sliding |")
	report_lines.append("|---|---|---|---|---|---|---|---|---|")
	for clip_name in CLIP_NAMES:
		report_lines.append("| `%s` | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING | PENDING |" % clip_name)


func _validate_clip(clip_name: String) -> void:
	var animation := animation_player.get_animation(clip_name)
	var duration := animation.length
	var sample_time := minf(duration * 0.35, maxf(0.0, duration - 0.001))
	animation_player.play(clip_name)
	animation_player.seek(sample_time, true)
	animation_player.advance(0.001)
	await process_frame
	await process_frame

	var clip_safe := clip_name.validate_filename()
	var front_path := OUTPUT_DIR.path_join("%s_front.png" % clip_safe)
	var side_path := OUTPUT_DIR.path_join("%s_side.png" % clip_safe)
	_set_camera_view("front", combined_bounds.get_center())
	await process_frame
	var front_error := get_root().get_texture().get_image().save_png(front_path)
	_set_camera_view("side", combined_bounds.get_center())
	await process_frame
	var side_error := get_root().get_texture().get_image().save_png(side_path)
	if front_error != OK or side_error != OK:
		_fail("Failed to save screenshot(s) for " + clip_name)

	var foot_ranges := await _sample_foot_bones(clip_name, duration)
	var vertical_range: float = foot_ranges.vertical
	var horizontal_range: float = foot_ranges.horizontal
	report_lines.append(
		"| `%s` | %.3f | %.3f | [`front`](%s) | [`side`](%s) | %.4f | %.4f |"
		% [
			clip_name,
			duration,
			sample_time,
			front_path.get_file(),
			side_path.get_file(),
			vertical_range,
			horizontal_range,
		]
	)
	print(
		"VISUAL_AUDIT_CLIP=%s length=%.3f sample=%.3f front=%s side=%s foot_y_range=%.4f foot_horizontal_range=%.4f"
		% [clip_name, duration, sample_time, front_path, side_path, vertical_range, horizontal_range]
	)


func _sample_foot_bones(clip_name: String, duration: float) -> Dictionary:
	var left_index := skeleton.find_bone("Foot.L")
	var right_index := skeleton.find_bone("Foot.R")
	if left_index < 0 or right_index < 0 or duration <= 0.0:
		_fail("Foot.L/Foot.R or valid clip duration missing for " + clip_name)
		return {"vertical": 0.0, "horizontal": 0.0}
	var minimums := [Vector3(INF, INF, INF), Vector3(INF, INF, INF)]
	var maximums := [Vector3(-INF, -INF, -INF), Vector3(-INF, -INF, -INF)]
	for sample_index in SAMPLE_STEPS + 1:
		var sample_time := duration * float(sample_index) / float(SAMPLE_STEPS)
		animation_player.play(clip_name)
		animation_player.seek(sample_time, true)
		animation_player.advance(0.001)
		await process_frame
		var foot_indices: Array[int] = [left_index, right_index]
		for foot_number in foot_indices.size():
			var bone_index: int = foot_indices[foot_number]
			var world_pose := skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
			minimums[foot_number] = minimums[foot_number].min(world_pose.origin)
			maximums[foot_number] = maximums[foot_number].max(world_pose.origin)
	var vertical_range := 0.0
	var horizontal_range := 0.0
	for foot_number in minimums.size():
		var foot_extent: Vector3 = maximums[foot_number] - minimums[foot_number]
		vertical_range = maxf(vertical_range, foot_extent.y)
		horizontal_range = maxf(
			horizontal_range,
			Vector2(foot_extent.x, foot_extent.z).length()
		)
	return {
		"vertical": vertical_range,
		"horizontal": horizontal_range,
	}


func _fail(message: String) -> void:
	failed = true
	push_error("VISUAL_AUDIT_ERROR " + message)
	report_lines.append("- Validator error: " + message)


func _finish() -> void:
	var report_path := OUTPUT_DIR.path_join("VISUAL_VALIDATION_REPORT.md")
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("Unable to create report: " + report_path)
		quit(1)
		return
	report_file.store_string("\n".join(report_lines) + "\n")
	report_file.close()
	print("VISUAL_AUDIT_REPORT=%s" % report_path)
	if model and is_instance_valid(model):
		model.queue_free()
	await process_frame
	quit(1 if failed else 0)
