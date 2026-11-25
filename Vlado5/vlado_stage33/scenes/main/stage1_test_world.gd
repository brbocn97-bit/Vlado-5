extends Node3D

@onready var sun: DirectionalLight3D = $SunLight
@onready var player: PlayerController = $VladoPlayer
@onready var camera_rig: PlayerCamera = $VladoPlayer/CameraRig
@onready var animator: PlayerAnimator = $VladoPlayer/PlayerAnimator
@onready var spring_arm: SpringArm3D = $VladoPlayer/CameraRig/YawPivot/PitchPivot/SpringArm3D

func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.apply_graphics_to_scene(sun)
	if OS.has_environment("VLADO_STAGE1_SHOT_DIR"):
		_run_visual_verification(OS.get_environment("VLADO_STAGE1_SHOT_DIR"))

func _run_visual_verification(out_dir: String) -> void:
	# 1. Idle hero view + HUD + mobile buttons
	camera_rig.set_angles_deg(15.0, -8.0)
	await _wait_frames(12)
	_save_shot(out_dir.path_join("stage1_01_idle_rear_3q.png"))

	# 2. Default virtual joystick -> Natural Walking (1.8 m/s, reduced stride length)
	camera_rig.set_angles_deg(-68.0, -8.0)
	camera_rig.snap_to_target()
	player.set_touch_move_vector(Vector2(0.0, 1.0))
	await _wait_until_stride(1.2, 0.30, 1.60)
	_save_shot(out_dir.path_join("stage1_02_walking_natural.png"))
	print("TEST_WALK speed=", snapped(player.current_horizontal_speed, 0.01),
		" state=", player.current_locomotion_state,
		" anim=", animator.get_active_animation())

	# 3. Toggle RUN ON -> Running up the 22-deg test ramp (4.6 m/s)
	player.toggle_run()
	player.global_position = Vector3(0.0, 0.05, -4.5)
	camera_rig.set_angles_deg(0.0, -10.0)
	camera_rig.snap_to_target()
	player.set_touch_move_vector(Vector2(0.0, 1.0))
	await _wait_until_running_on_slope(2.8)
	camera_rig.set_angles_deg(-24.0, -10.0)
	camera_rig.snap_to_target()
	await _wait_frames(1)
	_save_shot(out_dir.path_join("stage1_03_running_slope.png"))
	print("TEST_RUN_SLOPE speed=", snapped(player.current_horizontal_speed, 0.01),
		" slope=", snapped(player.current_slope_deg, 0.1),
		" state=", player.current_locomotion_state,
		" anim=", animator.get_active_animation())

	# 4. Toggle SPRINT ON -> Sprinting on flat ground (6.2 m/s)
	player.toggle_sprint()
	player.global_position = Vector3(4.0, 0.05, 12.0)
	camera_rig.set_angles_deg(-62.0, -8.0)
	camera_rig.snap_to_target()
	player.set_touch_move_vector(Vector2(0.0, 1.0))
	await _wait_until_stride(1.1, 0.45, 5.60)
	_save_shot(out_dir.path_join("stage1_04_sprinting.png"))
	print("TEST_SPRINT speed=", snapped(player.current_horizontal_speed, 0.01),
		" state=", player.current_locomotion_state,
		" anim=", animator.get_active_animation())

	# 5. Toggle CROUCH ON -> Crouched walking (1.15 m/s)
	player.toggle_crouch()
	player.global_position = Vector3(0.0, 0.05, 3.0)
	camera_rig.set_angles_deg(-55.0, -8.0)
	camera_rig.snap_to_target()
	player.set_touch_move_vector(Vector2(0.0, 1.0))
	await _wait_until_stride(1.2, 0.20, 0.90)
	_save_shot(out_dir.path_join("stage1_05_crouch_walk.png"))
	print("TEST_CROUCH_WALK speed=", snapped(player.current_horizontal_speed, 0.01),
		" state=", player.current_locomotion_state,
		" anim=", animator.get_active_animation())

	# 6. Press JUMP -> Uncrouches cleanly and launches into mid-air Jump pose
	player.set_touch_move_vector(Vector2(0.0, 0.8))
	player.request_jump()
	await _wait_frames(2)
	_save_shot(out_dir.path_join("stage1_06_jump_air.png"))
	print("TEST_JUMP y=", snapped(player.global_position.y, 0.01),
		" state=", player.current_locomotion_state,
		" anim=", animator.get_active_animation())

	# 7. Wait for landing, then verify SpringArm3D wall anti-clipping near StoneWall
	player.set_touch_move_vector(Vector2.ZERO)
	await _wait_seconds(1.2)
	player.global_position = Vector3(-4.2, 0.05, -2.0)
	camera_rig.set_angles_deg(-90.0, -6.0)
	camera_rig.snap_to_target()
	await _wait_frames(8)
	var hit_dist := spring_arm.get_hit_length()
	_save_shot(out_dir.path_join("stage1_07_camera_collision.png"))
	print("TEST_CAM_COLLISION configured=", spring_arm.spring_length, " hit_length=", snapped(hit_dist, 0.01))

	get_tree().quit()

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait_until_stride(min_sec: float, min_stride_sep: float, min_speed: float) -> void:
	var skel: Skeleton3D = player.find_child("Skeleton3D", true, false)
	var lf_idx := skel.find_bone("LeftFoot") if skel else -1
	var rf_idx := skel.find_bone("RightFoot") if skel else -1
	var t := 0.0
	while t < min_sec + 1.8:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= min_sec and player.current_horizontal_speed >= min_speed and lf_idx != -1 and rf_idx != -1:
			var lf := skel.get_bone_global_pose(lf_idx).origin
			var rf := skel.get_bone_global_pose(rf_idx).origin
			if absf(lf.z - rf.z) >= min_stride_sep:
				break

func _wait_until_running_on_slope(max_sec: float) -> void:
	var skel: Skeleton3D = player.find_child("Skeleton3D", true, false)
	var lf_idx := skel.find_bone("LeftFoot") if skel else -1
	var rf_idx := skel.find_bone("RightFoot") if skel else -1
	var t := 0.0
	while t < max_sec:
		await get_tree().process_frame
		t += get_process_delta_time()
		if player.current_horizontal_speed >= 4.25 and player.current_slope_deg >= 15.0:
			if lf_idx != -1 and rf_idx != -1:
				var lf := skel.get_bone_global_pose(lf_idx).origin
				var rf := skel.get_bone_global_pose(rf_idx).origin
				if absf(lf.z - rf.z) >= 0.40:
					break
			else:
				break

func _wait_seconds(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().process_frame
		t += get_process_delta_time()

func _save_shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
