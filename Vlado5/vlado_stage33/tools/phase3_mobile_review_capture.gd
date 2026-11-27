extends SceneTree

const FPS := 30
const FRAME_SIZE := Vector2i(960, 540)
const CAPTURE_MANIFEST := "/tmp/vlado_82f8284_capture_manifest.txt"
const PLAYER_SCENE := "res://characters/vlado/vlado_character.tscn"
const CLIPS: Array[String] = [
	"idle",
	"idle_rifle",
	"run",
	"run_rifle",
	"jump",
	"jump_in_place",
	"jump_rifle",
	"jump_rifle_in_place",
]

var world: Node3D
var player: PlayerController
var animator: PlayerAnimator
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var state_camera: Camera3D
var gameplay_camera: Camera3D
var status_label: Label
var frame_index := 0
var failure_count := 0
var review_angle := "front"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = FRAME_SIZE
	DisplayServer.window_set_size(FRAME_SIZE)
	Engine.max_fps = FPS
	Engine.time_scale = 1.0
	_setup_studio()

	var player_packed := load(PLAYER_SCENE) as PackedScene
	if player_packed == null:
		_fail("Unable to load player prefab from commit source")
		quit(1)
		return
	player = player_packed.instantiate() as PlayerController
	if player == null:
		_fail("Player prefab is not a PlayerController")
		quit(1)
		return
	player.name = "VladoPlayer"
	world.add_child(player)
	current_scene = world
	await _wait_frames(60)

	animator = player.get_node_or_null("PlayerAnimator") as PlayerAnimator
	animation_tree = animator.get_node_or_null("LocomotionTree") as AnimationTree if animator else null
	var model := player.get_node_or_null("VisualRoot/VladoModel")
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer if model else null
	gameplay_camera = player.get_node_or_null("CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D") as Camera3D
	var fps_rig := player.get_node_or_null("FirstPersonRig") as FirstPersonRig
	if animator == null or animation_tree == null or animation_player == null or gameplay_camera == null or fps_rig == null:
		_fail("Live player prefab missing Animator, AnimationTree, AnimationPlayer, Camera, or FirstPersonRig")
		quit(1)
		return
	if animation_player.get_animation_list().size() < CLIPS.size():
		_fail("Original AnimationPlayer does not expose all eight clips")
		quit(1)
		return

	player.set_physics_process(false)
	var weapon_controller := player.get_node_or_null("WeaponController")
	if weapon_controller:
		weapon_controller.set_process(false)
		weapon_controller.set_physics_process(false)
	gameplay_camera.current = false
	state_camera.current = true
	_set_review_camera("front")
	_set_unarmed()
	animation_tree.active = false
	animation_player.stop()
	await _capture_for_seconds(1.0, "COMMIT 82f8284 | VLADO NATIVE ANIMATION REVIEW | ENGINE RENDER")

	for clip_name in CLIPS:
		var armed := clip_name in ["idle_rifle", "run_rifle", "jump_rifle", "jump_rifle_in_place"]
		_set_armed(armed)
		for angle in ["front", "side"]:
			_set_review_camera(angle)
			for repeat_index in 2:
				animation_player.play(clip_name, 0.0, 1.0, false)
				var duration := animation_player.get_animation(clip_name).length
				var count := maxi(1, roundi(duration * FPS))
				await _capture_frame_sequence(
					count,
					"NATIVE CLIP: %s | THIRD-PERSON | %s | CYCLE %d/2"
					% [clip_name, angle.to_upper(), repeat_index + 1]
				)

	animation_tree.active = true
	animation_player.stop()
	player.set_view_mode(PlayerController.ViewMode.THIRD_PERSON)
	player.velocity = Vector3.ZERO
	player.global_position = Vector3.ZERO
	player.current_horizontal_speed = 0.0
	player.current_locomotion_state = "Idle"
	player.weapon_equipped = false
	player.is_aiming = false
	animator.set_weapon_hold_profile("pistol")
	animator.set_rifle_selected(true)
	player.set_touch_move_vector(Vector2.ZERO)
	player.set_physics_process(true)
	state_camera.current = true
	_set_review_camera("front")
	await _capture_for_seconds(1.2, "GAMEPLAY TRANSITION: IDLE | THIRD-PERSON | CONTROLLER")

	player.toggle_run()
	player.set_touch_move_vector(Vector2(0.0, 1.0))
	await _capture_for_seconds(2.0, "GAMEPLAY TRANSITION: IDLE -> RUN | PHYSICS CONTROLLER")
	player.request_jump()
	await _capture_for_seconds(0.34, "GAMEPLAY TRANSITION: RUN -> JUMP TAKEOFF | PHYSICS CONTROLLER")
	player.set_touch_move_vector(Vector2.ZERO)
	await _capture_for_seconds(1.25, "GAMEPLAY TRANSITION: JUMP / LANDING | PHYSICS CONTROLLER")
	await _capture_until_idle(1.5)
	await _capture_for_seconds(0.8, "GAMEPLAY TRANSITION: RETURNED TO IDLE")

	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.current_horizontal_speed = 0.0
	player.current_locomotion_state = "Idle"
	player.weapon_equipped = true
	player.is_aiming = false
	animator.set_weapon_hold_profile("rifle")
	animator.set_rifle_selected(true)
	await _wait_frames(30)
	player.set_view_mode(PlayerController.ViewMode.FIRST_PERSON)
	state_camera.current = false
	gameplay_camera.current = true
	await _wait_frames(45)
	await _capture_for_seconds(2.0, "FIRST-PERSON RIFLE: READY / WEAPON AND HANDS")
	player.is_aiming = true
	await _capture_for_seconds(2.0, "FIRST-PERSON RIFLE: AIM VIEW")
	player.is_aiming = false
	player.set_view_mode(PlayerController.ViewMode.THIRD_PERSON)
	await _wait_frames(45)
	gameplay_camera.current = false
	state_camera.current = true
	_set_review_camera("front")
	await _capture_for_seconds(1.0, "THIRD-PERSON RIFLE: IDLE / BOTH HANDS AND PROP")

	animation_tree.active = false
	animation_player.stop()
	player.set_physics_process(false)
	_write_capture_manifest()
	print(
		"MOBILE_REVIEW_CAPTURE_DONE frames=%d failures=%d manifest=%s"
		% [frame_index, failure_count, CAPTURE_MANIFEST]
	)
	quit(1 if failure_count > 0 else 0)


func _setup_studio() -> void:
	world = Node3D.new()
	world.name = "Commit82f8284MobileReview"
	get_root().add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.105, 0.12, 0.145)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.76, 0.80, 0.86)
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	world.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	key.light_energy = 1.45
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	fill.light_energy = 0.60
	world.add_child(fill)

	var floor_mesh_instance := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80.0, 80.0)
	floor_mesh_instance.mesh = floor_mesh
	floor_mesh_instance.position.y = -0.10
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.24, 0.27, 0.30)
	floor_material.roughness = 0.92
	floor_mesh_instance.material_override = floor_material
	world.add_child(floor_mesh_instance)

	var floor_body := StaticBody3D.new()
	floor_body.name = "ReviewGround"
	floor_body.position.y = -0.10
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 0.20, 80.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	state_camera = Camera3D.new()
	state_camera.name = "ReviewCamera"
	state_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	state_camera.size = 2.35
	state_camera.current = true
	world.add_child(state_camera)

	var hud := CanvasLayer.new()
	hud.layer = 20
	world.add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.02, 0.027, 0.84)
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(1150.0, 58.0)
	hud.add_child(panel)
	status_label = Label.new()
	status_label.position = Vector2(34.0, 27.0)
	status_label.size = Vector2(1115.0, 42.0)
	status_label.add_theme_font_size_override("font_size", 25)
	status_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	hud.add_child(status_label)


func _set_review_camera(angle: String) -> void:
	if player == null or state_camera == null:
		return
	review_angle = angle
	var target := player.global_position + Vector3(0.0, 0.92, 0.0)
	var camera_distance := 5.5
	state_camera.size = 2.35
	if angle == "front":
		state_camera.global_position = target + Vector3(0.0, 0.0, camera_distance)
	else:
		state_camera.global_position = target + Vector3(camera_distance, 0.0, 0.0)
	state_camera.look_at(target, Vector3.UP)


func _set_unarmed() -> void:
	player.weapon_equipped = false
	player.is_aiming = false
	animator.set_weapon_hold_profile("pistol")
	animator.set_rifle_selected(true)


func _set_armed(armed: bool) -> void:
	player.weapon_equipped = armed
	player.is_aiming = false
	animator.set_weapon_hold_profile("rifle" if armed else "pistol")
	animator.set_rifle_selected(true)
	player.current_locomotion_state = "Idle"
	player.current_horizontal_speed = 0.0


func _capture_for_seconds(seconds: float, title: String) -> void:
	await _capture_frame_sequence(maxi(1, roundi(seconds * FPS)), title)


func _capture_frame_sequence(count: int, title: String) -> void:
	for frame_in_sequence in count:
		status_label.text = "%s  |  %.2f sec" % [title, float(frame_in_sequence) / FPS]
		_set_review_camera(review_angle)
		await process_frame
		frame_index += 1


func _capture_until_idle(max_seconds: float) -> void:
	var maximum_frames := roundi(max_seconds * FPS)
	for frame_in_sequence in maximum_frames:
		status_label.text = "GAMEPLAY TRANSITION: LANDING -> IDLE | PHYSICS CONTROLLER"
		_set_review_camera(review_angle)
		await process_frame
		frame_index += 1
		if player.current_locomotion_state == "Idle":
			return


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _write_capture_manifest() -> void:
	var file := FileAccess.open(CAPTURE_MANIFEST, FileAccess.WRITE)
	if file == null:
		_fail("Unable to write capture manifest")
		return
	file.store_line("source_commit=82f8284e417814d080b1d5bc02681420b1655e91")
	file.store_line("frame_rate=%d" % FPS)
	file.store_line("frame_size=%dx%d" % [FRAME_SIZE.x, FRAME_SIZE.y])
	file.store_line("frame_count=%d" % frame_index)
	file.store_line("clip_repeat_count=2")
	file.store_line("animation_time_scale=1.0")
	file.store_line("validator_errors=%d" % failure_count)
	file.close()


func _fail(message: String) -> void:
	failure_count += 1
	push_error("MOBILE_REVIEW_ERROR " + message)
