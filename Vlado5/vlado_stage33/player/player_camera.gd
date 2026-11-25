class_name PlayerCamera
extends Node3D

@export_group("Camera Framing (Third-Person)")
@export_range(1.8, 6.0, 0.05) var camera_distance: float = 3.15
@export_range(35.0, 75.0, 1.0) var camera_fov: float = 52.0
@export var shoulder_offset_x: float = 0.32
@export var pivot_height: float = 1.45

@export_group("Over-The-Shoulder Aim (Mode A)")
@export var aim_distance: float = 2.12
@export var aim_fov: float = 40.0
@export var aim_shoulder_offset_x: float = 0.62
@export var aim_height_boost: float = 0.14
@export var aim_smoothing: float = 13.5

@export_group("First-Person View (Mode B)")
@export var fps_eye_height: float = 1.69
@export var fps_crouch_eye_height: float = 1.18
@export var fps_world_fov: float = 62.0
@export var fps_aim_world_fov: float = 46.0
@export var fp_transition_speed: float = 9.5
@export_range(-85.0, -25.0, 1.0) var fps_min_pitch_deg: float = -72.0
@export_range(25.0, 85.0, 1.0) var fps_max_pitch_deg: float = 76.0

@export_group("Orbit & Sensitivity")
@export_range(-70.0, -10.0, 1.0) var min_pitch_deg: float = -42.0
@export_range(10.0, 75.0, 1.0) var max_pitch_deg: float = 58.0
@export var initial_yaw_deg: float = 0.0
@export var initial_pitch_deg: float = -10.0
@export var follow_smoothing: float = 14.5
@export var follow_smoothing_y: float = 10.5
@export var gait_framing_smoothing: float = 5.5
@export var touch_sensitivity: float = 0.26
@export var aim_touch_sensitivity: float = 0.16
@export var tps_touch_sensitivity_hv: Vector2 = Vector2(0.26, 0.23)
@export var tps_aim_touch_sensitivity_hv: Vector2 = Vector2(0.16, 0.14)
@export var fps_touch_sensitivity_hv: Vector2 = Vector2(0.22, 0.20)
@export var fps_aim_touch_sensitivity_hv: Vector2 = Vector2(0.13, 0.115)
@export var mouse_sensitivity: float = 0.22
@export var fps_mouse_sensitivity_hv: Vector2 = Vector2(0.18, 0.16)
@export var zoom_step: float = 0.25
@export var min_zoom_distance: float = 2.0
@export var max_zoom_distance: float = 5.5

@export_group("Node Paths")
@export var target_body_path: NodePath = NodePath("..")
@export var fp_rig_path: NodePath = NodePath("../FirstPersonRig")

var _target_body: Node3D
var _fp_rig: FirstPersonRig
var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D

var _yaw_rad: float = 0.0
var _pitch_rad: float = deg_to_rad(-10.0)
var _mouse_dragging: bool = false
var _dynamic_dist_offset: float = 0.0
var _dynamic_fov_offset: float = 0.0
var _aim_blend: float = 0.0
var _fp_blend: float = 0.0
var _recoil_pitch_rad: float = 0.0
var _recoil_yaw_rad: float = 0.0

func _ready() -> void:
	_target_body = get_node_or_null(target_body_path)
	_fp_rig = get_node_or_null(fp_rig_path) as FirstPersonRig
	_yaw_pivot = $YawPivot
	_pitch_pivot = $YawPivot/PitchPivot
	_spring_arm = $YawPivot/PitchPivot/SpringArm3D
	_camera = $YawPivot/PitchPivot/SpringArm3D/Camera3D

	top_level = true
	_yaw_rad = deg_to_rad(initial_yaw_deg)
	_pitch_rad = _clamp_pitch(deg_to_rad(initial_pitch_deg))

	if _target_body:
		global_position = _target_body.global_position + Vector3(0.0, pivot_height, 0.0)
	_apply_framing()
	_apply_angles()

func get_yaw() -> float:
	return _yaw_rad

func get_pitch() -> float:
	return _pitch_rad

func get_fp_blend() -> float:
	return _fp_blend

func get_aim_blend() -> float:
	return _aim_blend

func is_fp_active() -> bool:
	return _fp_blend >= 0.62

func get_camera() -> Camera3D:
	return _camera

func get_effective_distance() -> float:
	return _spring_arm.spring_length if _spring_arm else 0.0

func get_effective_fov() -> float:
	return _camera.fov if _camera else camera_fov

func get_aim_ray() -> Dictionary:
	if not _camera:
		var fwd := -Basis(Vector3.UP, _yaw_rad).z
		return {"origin": global_position, "dir": fwd}
	var vp_size := get_viewport().get_visible_rect().size
	var center := vp_size * 0.5
	var cam_orig := _camera.project_ray_origin(center)
	var cam_dir := _camera.project_ray_normal(center)
	if not is_fp_active() and _target_body:
		var to_player := (_target_body.global_position + Vector3(0.0, 1.35, 0.0)) - cam_orig
		cam_orig += cam_dir * maxf(0.0, to_player.dot(cam_dir))
	return {
		"origin": cam_orig,
		"dir": cam_dir,
	}

func add_recoil_kick(pitch_deg: float, yaw_deg: float) -> void:
	_recoil_pitch_rad = clampf(_recoil_pitch_rad + deg_to_rad(pitch_deg), -0.20, 0.25)
	_recoil_yaw_rad = clampf(_recoil_yaw_rad + deg_to_rad(yaw_deg), -0.15, 0.15)

func snap_to_target() -> void:
	var target_fp := 1.0 if (_target_body is PlayerController and (_target_body as PlayerController).is_first_person()) else 0.0
	_fp_blend = target_fp
	if _target_body:
		var h := _get_target_pivot_height()
		global_position = _target_body.global_position + Vector3(0.0, h, 0.0)
	_dynamic_dist_offset = 0.0
	_dynamic_fov_offset = 0.0
	_aim_blend = 0.0
	_recoil_pitch_rad = 0.0
	_recoil_yaw_rad = 0.0
	_apply_framing()
	_apply_angles()

func set_angles_deg(yaw_deg: float, pitch_deg: float) -> void:
	_yaw_rad = deg_to_rad(yaw_deg)
	_pitch_rad = _clamp_pitch(deg_to_rad(pitch_deg))
	_apply_angles()

func adjust_distance(delta_m: float) -> void:
	camera_distance = clampf(camera_distance + delta_m, min_zoom_distance, max_zoom_distance)
	_apply_framing()

func cycle_shoulder_offset() -> void:
	if shoulder_offset_x > 0.1:
		shoulder_offset_x = 0.0
	elif shoulder_offset_x < -0.1:
		shoulder_offset_x = 0.32
	else:
		shoulder_offset_x = -0.32
	_apply_framing()

func _get_active_touch_sensitivity() -> Vector2:
	var is_aim := (_target_body is PlayerController) and (_target_body as PlayerController).is_aiming
	var is_fp := (_target_body is PlayerController) and (_target_body as PlayerController).is_first_person()
	if is_fp:
		return fps_aim_touch_sensitivity_hv if is_aim else fps_touch_sensitivity_hv
	return tps_aim_touch_sensitivity_hv if is_aim else tps_touch_sensitivity_hv

func _get_active_mouse_sensitivity() -> Vector2:
	var is_aim := (_target_body is PlayerController) and (_target_body as PlayerController).is_aiming
	var is_fp := (_target_body is PlayerController) and (_target_body as PlayerController).is_first_person()
	var base := fps_mouse_sensitivity_hv if is_fp else Vector2(mouse_sensitivity, mouse_sensitivity * 0.92)
	return base * (0.62 if is_aim else 1.0)

func _clamp_pitch(p_rad: float) -> float:
	var fp_desired := (_target_body is PlayerController) and (_target_body as PlayerController).is_first_person()
	var w := 1.0 if (fp_desired or _fp_blend > 0.5) else _fp_blend
	var lo := deg_to_rad(lerpf(min_pitch_deg, fps_min_pitch_deg, w))
	var hi := deg_to_rad(lerpf(max_pitch_deg, fps_max_pitch_deg, w))
	return clampf(p_rad, lo, hi)

func _get_target_pivot_height() -> float:
	var tps_h := pivot_height + aim_height_boost * _aim_blend
	var is_crouch := (_target_body is PlayerController) and (_target_body as PlayerController).is_crouch_active()
	var fps_h := fps_crouch_eye_height if is_crouch else fps_eye_height
	return lerpf(tps_h, fps_h, _fp_blend)

func add_touch_look_delta(delta_px: Vector2) -> void:
	var sens := _get_active_touch_sensitivity()
	_yaw_rad -= deg_to_rad(delta_px.x * sens.x)
	_pitch_rad = _clamp_pitch(_pitch_rad - deg_to_rad(delta_px.y * sens.y))
	if _fp_rig:
		_fp_rig.add_look_sway(delta_px)
	_apply_angles()

func _unhandled_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _fp_blend < 0.5:
				camera_distance = clampf(camera_distance - zoom_step, min_zoom_distance, max_zoom_distance)
				_apply_framing()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _fp_blend < 0.5:
				camera_distance = clampf(camera_distance + zoom_step, min_zoom_distance, max_zoom_distance)
				_apply_framing()
	elif event is InputEventMouseMotion and _mouse_dragging:
		var mm: InputEventMouseMotion = event
		var sens := _get_active_mouse_sensitivity()
		_yaw_rad -= deg_to_rad(mm.relative.x * sens.x)
		_pitch_rad = _clamp_pitch(_pitch_rad - deg_to_rad(mm.relative.y * sens.y))
		if _fp_rig:
			_fp_rig.add_look_sway(mm.relative)
		_apply_angles()

func _physics_process(delta: float) -> void:
	if not _target_body:
		return

	var target_dist_off := 0.0
	var target_fov_off := 0.0
	var target_aim := 0.0
	var target_fp := 0.0

	if _target_body is PlayerController:
		var pc := _target_body as PlayerController
		target_fp = 1.0 if pc.is_first_person() else 0.0
		var spd := pc.current_horizontal_speed
		if pc.is_aiming:
			target_aim = 1.0
		elif pc.is_crouch_active():
			target_dist_off = -0.18
			target_fov_off = -2.0
		elif pc.current_locomotion_state == "Sprinting" and spd > 4.5:
			target_dist_off = 0.34
			target_fov_off = 5.0
		elif pc.current_locomotion_state == "Running" and spd > 2.4:
			target_dist_off = 0.16
			target_fov_off = 2.2

	var fp_rate := 1.0 - exp(-fp_transition_speed * delta)
	_fp_blend = lerpf(_fp_blend, target_fp, fp_rate)
	if absf(_fp_blend - target_fp) < 0.002:
		_fp_blend = target_fp

	# Smoothly bring steep FPS pitch back inside TPS bounds if switching back to TPS
	if target_fp < 0.5:
		var tps_clamped := clampf(_pitch_rad, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		_pitch_rad = lerpf(_pitch_rad, tps_clamped, fp_rate)

	var gblend := 1.0 - exp(-gait_framing_smoothing * delta)
	_dynamic_dist_offset = lerpf(_dynamic_dist_offset, target_dist_off, gblend)
	_dynamic_fov_offset = lerpf(_dynamic_fov_offset, target_fov_off, gblend)

	var ablend := 1.0 - exp(-aim_smoothing * delta)
	_aim_blend = lerpf(_aim_blend, target_aim, ablend)

	var desired_h := _get_target_pivot_height()
	var desired_pos := _target_body.global_position + Vector3(0.0, desired_h, 0.0)
	if _fp_blend >= 0.99:
		# Rock-solid zero-jitter eye attachment in full First-Person
		global_position = Vector3(desired_pos.x, lerpf(global_position.y, desired_pos.y, 1.0 - exp(-18.0 * delta)), desired_pos.z)
	else:
		var blend_xz := 1.0 - exp(-follow_smoothing * delta)
		var blend_y := 1.0 - exp(-follow_smoothing_y * delta)
		global_position = Vector3(
			lerpf(global_position.x, desired_pos.x, blend_xz),
			lerpf(global_position.y, desired_pos.y, blend_y),
			lerpf(global_position.z, desired_pos.z, blend_xz)
		)

	var rblend := 1.0 - exp(-9.5 * delta)
	_recoil_pitch_rad = lerpf(_recoil_pitch_rad, 0.0, rblend)
	_recoil_yaw_rad = lerpf(_recoil_yaw_rad, 0.0, rblend)

	_apply_framing()
	_apply_angles()

func _apply_angles() -> void:
	if _yaw_pivot:
		_yaw_pivot.rotation.y = _yaw_rad + _recoil_yaw_rad
	if _pitch_pivot:
		var clamped := _clamp_pitch(_pitch_rad + _recoil_pitch_rad)
		_pitch_pivot.rotation.x = clamped

func _apply_framing() -> void:
	var base_sh := shoulder_offset_x
	var aim_sh := -aim_shoulder_offset_x if shoulder_offset_x < -0.1 else aim_shoulder_offset_x
	var tps_sh := lerpf(base_sh, aim_sh, _aim_blend)
	var base_dist := clampf(camera_distance + _dynamic_dist_offset, min_zoom_distance - 0.2, max_zoom_distance + 0.5)
	var tps_dist := lerpf(base_dist, aim_distance, _aim_blend)

	if _spring_arm:
		_spring_arm.position.x = lerpf(tps_sh, 0.0, _fp_blend)
		_spring_arm.spring_length = lerpf(tps_dist, 0.0, _fp_blend)
		_spring_arm.collision_mask = 0 if _fp_blend > 0.65 else 1

	if _camera:
		var tps_base_fov := clampf(camera_fov + _dynamic_fov_offset, 35.0, 75.0)
		var tps_fov := lerpf(tps_base_fov, aim_fov, _aim_blend)
		var fps_fov := lerpf(fps_world_fov, fps_aim_world_fov, _aim_blend)
		var target_fov := lerpf(tps_fov, fps_fov, _fp_blend)
		if not is_equal_approx(_camera.fov, target_fov):
			_camera.fov = target_fov
