class_name PlayerController
extends CharacterBody3D

enum MoveGait {
	WALK = 0,
	RUN = 1,
	SPRINT = 2,
}

enum ViewMode {
	THIRD_PERSON = 0,
	FIRST_PERSON = 1,
}

signal view_mode_changed(new_mode: int)

@export_group("View Mode")
@export var default_view_mode: ViewMode = ViewMode.THIRD_PERSON

@export_group("Movement Speeds (m/s)")
@export var walk_speed: float = 1.65
@export var run_speed: float = 4.35
@export var sprint_speed: float = 6.40
@export var crouch_speed: float = 1.35
@export var aim_walk_speed: float = 1.50
@export var aim_crouch_speed: float = 1.15
@export var ready_run_speed: float = 3.25

@export_group("Acceleration, Turning & Jump")
@export var walk_acceleration: float = 11.5
@export var run_acceleration: float = 8.4
@export var sprint_acceleration: float = 6.8
@export var ground_acceleration: float = 10.5
@export var ground_deceleration: float = 13.5
@export var sprint_deceleration: float = 7.6
@export var air_acceleration: float = 3.4
@export var turn_speed: float = 11.5
@export var run_turn_speed: float = 8.6
@export var sprint_turn_speed: float = 6.6
@export var aim_turn_speed: float = 18.0
@export var gravity_strength: float = 14.2
@export var jump_velocity: float = 5.5
@export var coyote_time_seconds: float = 0.12
@export var jump_buffer_seconds: float = 0.12
@export var landing_recovery_seconds: float = 0.26

@export_group("Crouch & Collider")
@export var standing_capsule_height: float = 1.84
@export var crouch_capsule_height: float = 1.26
@export var standing_pivot_height: float = 1.45
@export var crouch_pivot_height: float = 1.08
@export var crouch_transition_speed: float = 10.5

@export_group("Health & Stamina")
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var sprint_stamina_drain: float = 15.5
@export var jump_stamina_cost: float = 10.0

@export_group("References")
@export var visual_root_path: NodePath = NodePath("VisualRoot")
@export var camera_rig_path: NodePath = NodePath("CameraRig")
@export var collision_shape_path: NodePath = NodePath("CollisionShape3D")

var _visual_root: Node3D
var _camera_rig: PlayerCamera
var _collision_shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _sound: SoundManager
var _weapon: WeaponController

var _touch_move_input: Vector2 = Vector2.ZERO
var _active_gait: MoveGait = MoveGait.WALK
var _is_crouching: bool = false
var _was_on_floor: bool = true
var _air_time: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jump_start_timer: float = 0.0
var _landing_timer: float = 0.0

var health: float = 100.0
var stamina: float = 100.0
var _stamina_regen_delay: float = 0.0
var _sprint_exhausted: bool = false
var _step_accum: float = 0.0

var weapon_equipped: bool = false
var is_aiming: bool = false
var weapon_action: String = ""
var _hipfire_face_timer: float = 0.0
var current_view_mode: ViewMode = ViewMode.THIRD_PERSON

var current_horizontal_speed: float = 0.0
var current_target_speed: float = 0.0
var current_locomotion_state: String = "Idle"
var current_slope_deg: float = 0.0
var current_signed_slope_deg: float = 0.0
var current_turn_rate_rad: float = 0.0
var current_vertical_velocity: float = 0.0
var is_grounded: bool = true

func _ready() -> void:
	_visual_root = get_node_or_null(visual_root_path)
	_camera_rig = get_node_or_null(camera_rig_path)
	_collision_shape = get_node_or_null(collision_shape_path)
	if _collision_shape and _collision_shape.shape is CapsuleShape3D:
		_capsule = _collision_shape.shape as CapsuleShape3D
	_weapon = find_child("WeaponController", true, false) as WeaponController
	current_view_mode = default_view_mode
	health = max_health
	stamina = max_stamina

	floor_max_angle = deg_to_rad(45.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_snap_length = 0.44

	await get_tree().process_frame
	_sound = get_tree().root.find_child("SoundManager", true, false) as SoundManager

func set_sound_manager(sm: SoundManager) -> void:
	_sound = sm

func set_touch_move_vector(vec: Vector2) -> void:
	if vec.length() > 1.0:
		_touch_move_input = vec.normalized()
	else:
		_touch_move_input = vec

func toggle_run() -> void:
	if _is_crouching:
		if not _can_stand_up():
			return
		_is_crouching = false
	if is_aiming and _weapon:
		_weapon.set_aiming(false)
	_active_gait = MoveGait.WALK if _active_gait == MoveGait.RUN else MoveGait.RUN

func toggle_view_mode() -> void:
	var next_mode := ViewMode.FIRST_PERSON if current_view_mode == ViewMode.THIRD_PERSON else ViewMode.THIRD_PERSON
	set_view_mode(next_mode)

func set_view_mode(mode: ViewMode) -> void:
	if current_view_mode == mode:
		return
	current_view_mode = mode
	if _visual_root and _camera_rig and current_view_mode == ViewMode.THIRD_PERSON:
		# Keep facing synced seamlessly with camera yaw when switching back so character never spins suddenly
		if is_aiming or weapon_equipped:
			_visual_root.rotation.y = _camera_rig.get_yaw()
	view_mode_changed.emit(int(current_view_mode))

func is_first_person() -> bool:
	return current_view_mode == ViewMode.FIRST_PERSON

func get_view_mode_label() -> String:
	return "FIRST PERSON" if current_view_mode == ViewMode.FIRST_PERSON else "THIRD PERSON"

func set_sprint_active(active: bool) -> void:
	if active:
		if not _sprint_exhausted and not _is_crouching:
			_active_gait = MoveGait.SPRINT
	elif _active_gait == MoveGait.SPRINT:
		_active_gait = MoveGait.WALK

func toggle_sprint() -> void:
	if _sprint_exhausted:
		return
	if _is_crouching:
		if not _can_stand_up():
			return
		_is_crouching = false
	if is_aiming and _weapon:
		_weapon.set_aiming(false)
	if _weapon and _weapon.is_equipped() and current_view_mode == ViewMode.THIRD_PERSON:
		_weapon.toggle_equip()
	_active_gait = MoveGait.WALK if _active_gait == MoveGait.SPRINT else MoveGait.SPRINT

func toggle_crouch() -> void:
	if _is_crouching:
		if _can_stand_up():
			_is_crouching = false
	else:
		_is_crouching = true
		_active_gait = MoveGait.WALK

func request_jump() -> void:
	if _is_crouching and not _can_stand_up():
		return
	_jump_buffer_timer = jump_buffer_seconds

func notify_weapon_fired(aimed: bool) -> void:
	if not aimed:
		_hipfire_face_timer = 0.65

func get_aim_pitch_rad() -> float:
	return _camera_rig.get_pitch() if _camera_rig else 0.0

func is_run_active() -> bool:
	return _active_gait == MoveGait.RUN and not _is_crouching

func is_sprint_active() -> bool:
	return _active_gait == MoveGait.SPRINT and not _is_crouching

func is_crouch_active() -> bool:
	return _is_crouching

func get_gait_label() -> String:
	if is_aiming:
		return "Aim Crouch" if _is_crouching else "Aim"
	if _is_crouching:
		return "Crouch"
	match _active_gait:
		MoveGait.RUN:
			return "Run"
		MoveGait.SPRINT:
			return "Sprint"
		_:
			return "Walk"

func _can_stand_up() -> bool:
	var space := get_world_3d().direct_space_state
	if not space:
		return true
	var r := 0.24
	var offsets: Array[Vector3] = [Vector3.ZERO, Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	for off: Vector3 in offsets:
		var from: Vector3 = global_position + off + Vector3(0.0, 0.85, 0.0)
		var to: Vector3 = global_position + off + Vector3(0.0, standing_capsule_height + 0.04, 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
		q.exclude = [get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event
		if ke.keycode == KEY_SPACE:
			request_jump()
		elif ke.keycode == KEY_C:
			toggle_crouch()
		elif ke.keycode == KEY_R:
			var ars := get_node_or_null("WeaponArsenal")
			if ars and int(ars.get("active")) != 0 and _weapon and _weapon.is_equipped():
				ars.call("reload")
				get_viewport().set_input_as_handled()
			elif _weapon and _weapon.is_equipped():
				_weapon.try_reload()
			else:
				toggle_run()
		elif ke.keycode == KEY_SHIFT:
			toggle_sprint()
		elif ke.keycode == KEY_1 or ke.keycode == KEY_Q:
			if _weapon:
				_weapon.toggle_equip()
		elif ke.keycode == KEY_E or ke.keycode == KEY_TAB:
			toggle_view_mode()
		elif ke.keycode == KEY_V:
			if _weapon:
				_weapon.toggle_aim()
		elif ke.keycode == KEY_F:
			var ars := get_node_or_null("WeaponArsenal")
			if ars and int(ars.get("active")) != 0:
				ars.call("try_fire", true)
			elif _weapon:
				_weapon.try_fire()
	elif event.is_action_pressed("walk_toggle"):
		toggle_run()

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	if grounded:
		_coyote_timer = coyote_time_seconds
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)
	if _hipfire_face_timer > 0.0:
		_hipfire_face_timer = maxf(0.0, _hipfire_face_timer - delta)

	# Execute buffered/coyote jump cleanly
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		if _is_crouching:
			if _can_stand_up():
				_is_crouching = false
		if not _is_crouching:
			velocity.y = jump_velocity
			grounded = false
			_coyote_timer = 0.0
			_jump_buffer_timer = 0.0
			_jump_start_timer = 0.14
			_landing_timer = 0.0
			stamina = maxf(0.0, stamina - jump_stamina_cost)
			_stamina_regen_delay = 0.6

	if _jump_start_timer > 0.0:
		_jump_start_timer = maxf(0.0, _jump_start_timer - delta)

	floor_snap_length = 0.0 if velocity.y > 0.25 else 0.25

	if not grounded:
		velocity.y -= gravity_strength * delta
		_air_time += delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	if _landing_timer > 0.0:
		_landing_timer = maxf(0.0, _landing_timer - delta)

	var input_data := _gather_move_input()
	var raw_dir: Vector2 = input_data["dir"]
	var desired_speed: float = input_data["target_speed"]

	var move_dir := Vector3.ZERO
	if raw_dir.length_squared() > 0.001:
		var cam_yaw: float = _camera_rig.get_yaw() if _camera_rig else 0.0
		var cam_basis := Basis(Vector3.UP, cam_yaw)
		var forward := -cam_basis.z
		var right := cam_basis.x
		move_dir = (right * raw_dir.x + forward * raw_dir.y)
		move_dir.y = 0.0
		if move_dir.length_squared() > 0.0001:
			move_dir = move_dir.normalized()

	var adj_target_speed := desired_speed
	if grounded and move_dir.length_squared() > 0.01:
		var fn := get_floor_normal()
		var slope_rad := acos(clampf(fn.dot(Vector3.UP), -1.0, 1.0))
		var slope_horiz := Vector3(fn.x, 0.0, fn.z)
		var climb_factor := 0.0
		if slope_horiz.length_squared() > 0.0001:
			climb_factor = -move_dir.dot(slope_horiz.normalized()) * sin(slope_rad)
		current_signed_slope_deg = rad_to_deg(asin(clampf(climb_factor, -1.0, 1.0)))
		if climb_factor > 0.18:
			var penalty := clampf((climb_factor - 0.18) * 0.55, 0.0, 0.24)
			adj_target_speed *= (1.0 - penalty)
	else:
		current_signed_slope_deg = 0.0

	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	if grounded and move_dir.length_squared() > 0.01 and horiz_vel.length() > 2.4 and not is_aiming:
		var vel_dir := horiz_vel.normalized()
		var turn_align := vel_dir.dot(move_dir)
		if turn_align < 0.35:
			var turn_slow := lerpf(0.68, 1.0, clampf((turn_align + 1.0) / 1.35, 0.0, 1.0))
			adj_target_speed *= turn_slow

	current_target_speed = adj_target_speed
	var target_vel_xz := move_dir * adj_target_speed

	var rate: float
	if grounded:
		if adj_target_speed > 0.05:
			if _is_crouching or is_aiming:
				rate = walk_acceleration
			elif _active_gait == MoveGait.SPRINT:
				rate = sprint_acceleration
			elif _active_gait == MoveGait.RUN:
				rate = run_acceleration
			else:
				rate = walk_acceleration
		else:
			rate = sprint_deceleration if horiz_vel.length() > 3.8 else ground_deceleration
	else:
		rate = air_acceleration

	var blend := 1.0 - exp(-rate * delta)
	horiz_vel = horiz_vel.lerp(target_vel_xz, blend)
	if adj_target_speed < 0.01 and horiz_vel.length() < 0.05:
		horiz_vel = Vector3.ZERO

	velocity.x = horiz_vel.x
	velocity.z = horiz_vel.z

	move_and_slide()

	var post_grounded := is_on_floor()
	var pre_land_speed := Vector2(velocity.x, velocity.z).length()
	if not _was_on_floor and post_grounded and _air_time >= 0.12:
		_landing_timer = landing_recovery_seconds if pre_land_speed < 2.2 else 0.17
		_air_time = 0.0
		if _sound:
			_sound.play_footstep(_detect_surface(), 1.35)
	elif post_grounded:
		_air_time = 0.0
	_was_on_floor = post_grounded
	is_grounded = post_grounded
	current_vertical_velocity = velocity.y

	var planar_vel := Vector3(velocity.x, 0.0, velocity.z)
	current_horizontal_speed = planar_vel.length()

	# Character facing: in First-Person always align smoothly with look yaw; in TPS lock during aim/hip-fire
	var prev_yaw := _visual_root.rotation.y if _visual_root else 0.0
	if _visual_root:
		var face_camera := is_first_person() or is_aiming or _hipfire_face_timer > 0.0 or weapon_action == "Fire"
		if face_camera and _camera_rig:
			var target_yaw := _camera_rig.get_yaw()
			var rate_yaw := aim_turn_speed if (is_aiming or is_first_person()) else aim_turn_speed * 0.8
			var rot_blend := 1.0 - exp(-rate_yaw * delta)
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_yaw, rot_blend)
			current_turn_rate_rad = lerpf(current_turn_rate_rad, 0.0, 1.0 - exp(-12.0 * delta))
		elif move_dir.length_squared() > 0.01:
			var target_yaw := atan2(-move_dir.x, -move_dir.z)
			var active_turn_rate := turn_speed
			if not _is_crouching:
				if _active_gait == MoveGait.SPRINT and current_horizontal_speed > 3.6:
					active_turn_rate = sprint_turn_speed
				elif _active_gait == MoveGait.RUN and current_horizontal_speed > 2.2:
					active_turn_rate = run_turn_speed
			var rot_blend := 1.0 - exp(-active_turn_rate * delta)
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_yaw, rot_blend)
			var d_yaw := wrapf(_visual_root.rotation.y - prev_yaw, -PI, PI)
			current_turn_rate_rad = lerpf(current_turn_rate_rad, d_yaw / maxf(delta, 0.001), 1.0 - exp(-12.0 * delta))
		else:
			current_turn_rate_rad = lerpf(current_turn_rate_rad, 0.0, 1.0 - exp(-12.0 * delta))

	if post_grounded:
		var fn := get_floor_normal()
		current_slope_deg = rad_to_deg(acos(clampf(fn.dot(Vector3.UP), -1.0, 1.0)))
	else:
		current_slope_deg = 0.0

	_update_stamina(delta, post_grounded)
	_update_crouch_collider_and_camera(delta)
	_update_locomotion_state(post_grounded)
	_update_footsteps_and_ambience(delta, post_grounded)

func _update_stamina(delta: float, post_grounded: bool) -> void:
	if _active_gait == MoveGait.SPRINT and post_grounded and current_horizontal_speed > 4.2 and not _is_crouching:
		stamina = maxf(0.0, stamina - sprint_stamina_drain * delta)
		_stamina_regen_delay = 0.75
		if stamina <= 0.5:
			_sprint_exhausted = true
			_active_gait = MoveGait.RUN
	else:
		if _stamina_regen_delay > 0.0:
			_stamina_regen_delay = maxf(0.0, _stamina_regen_delay - delta)
		else:
			var regen := 22.0 if current_horizontal_speed < 2.2 else 12.0
			stamina = minf(max_stamina, stamina + regen * delta)
			if _sprint_exhausted and stamina >= 22.0:
				_sprint_exhausted = false

func _update_footsteps_and_ambience(delta: float, post_grounded: bool) -> void:
	if _sound:
		var dist_river := maxf(0.0, (global_position.y - 1.1) * 8.0)
		_sound.update_ambience(dist_river, 1.0 + clampf(global_position.y / 25.0, 0.0, 0.6))

	if not post_grounded or current_horizontal_speed < 0.25 or not _sound:
		_step_accum = 0.0
		return

	var step_len := 0.90
	if _is_crouching:
		step_len = 0.66
	elif current_horizontal_speed > 5.0:
		step_len = 1.62
	elif current_horizontal_speed > 2.8:
		step_len = 1.25

	var prev_idx := int(floor(_step_accum))
	_step_accum += delta * current_horizontal_speed / step_len
	var new_idx := int(floor(_step_accum))
	if new_idx > prev_idx:
		_sound.play_footstep(_detect_surface(), clampf(current_horizontal_speed / walk_speed, 0.7, 1.5))

func _detect_surface() -> String:
	var p := global_position
	if p.y < 1.22:
		return "water"
	if absf(p.x - 23.53) < 6.0 and absf(p.z + 16.0) < 2.3:
		return "wood"
	if p.x < -12.0 and p.z > -18.0 and p.z < 20.0:
		return "dirt"
	if current_slope_deg > 22.0:
		return "stone"
	return "grass"

func _update_crouch_collider_and_camera(delta: float) -> void:
	var target_h := crouch_capsule_height if _is_crouching else standing_capsule_height
	var target_pivot := crouch_pivot_height if _is_crouching else standing_pivot_height
	var blend := 1.0 - exp(-crouch_transition_speed * delta)

	if _capsule and _collision_shape:
		if not is_equal_approx(_capsule.height, target_h):
			_capsule.height = target_h
			_collision_shape.position.y = target_h * 0.5
	if _camera_rig:
		_camera_rig.pivot_height = lerpf(_camera_rig.pivot_height, target_pivot, blend)

func _update_locomotion_state(post_grounded: bool) -> void:
	if not post_grounded:
		if _jump_start_timer > 0.0 and velocity.y > 1.2:
			current_locomotion_state = "JumpStart"
		elif _air_time > 0.05 or absf(velocity.y) > 0.65:
			current_locomotion_state = "Jumping"
		return

	if _landing_timer > 0.0:
		current_locomotion_state = "Landing"
		return

	if _is_crouching:
		current_locomotion_state = "CrouchIdle" if current_horizontal_speed < 0.14 else "CrouchWalk"
		return

	if current_horizontal_speed < 0.14:
		current_locomotion_state = "Idle"
	elif current_horizontal_speed < lerpf(walk_speed, run_speed, 0.45):
		current_locomotion_state = "Walking"
	elif current_horizontal_speed < lerpf(run_speed, sprint_speed, 0.46):
		current_locomotion_state = "Running"
	else:
		current_locomotion_state = "Sprinting"

func _gather_move_input() -> Dictionary:
	var max_gait_speed := walk_speed
	if is_aiming:
		max_gait_speed = aim_crouch_speed if _is_crouching else aim_walk_speed
	elif _is_crouching:
		max_gait_speed = crouch_speed
	elif _active_gait == MoveGait.SPRINT:
		max_gait_speed = sprint_speed * (0.90 if weapon_equipped else 1.0)
	elif weapon_equipped:
		max_gait_speed = ready_run_speed if _active_gait == MoveGait.RUN else walk_speed
	elif _active_gait == MoveGait.RUN:
		max_gait_speed = run_speed

	var touch_mag := _touch_move_input.length()
	if touch_mag > 0.08:
		var dir := _touch_move_input.normalized()
		var frac := clampf((touch_mag - 0.08) / 0.72, 0.42, 1.0)
		return {"dir": dir, "target_speed": max_gait_speed * frac}

	var kx := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var ky := Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var kvec := Vector2(kx, ky)
	if kvec.length() > 0.05:
		return {"dir": kvec.normalized(), "target_speed": max_gait_speed}

	return {"dir": Vector2.ZERO, "target_speed": 0.0}

# ============================================================================
# STAGE 4 — damage intake
# ----------------------------------------------------------------------------
# Additive only: the Stage 3.2 controller had no damage entry point because
# nothing could hurt Vlado yet. Enemy fire now calls this. Existing health
# regeneration / HUD handling is untouched — this only mutates `health`.
# ============================================================================
signal damaged(amount: float, health_left: float)

var _damage_flash_timer: float = 0.0
var _last_hurt_ms: int = 0


func heal(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = minf(max_health, health + amount)


func take_damage(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_last_hurt_ms = Time.get_ticks_msec()
	damaged.emit(amount, health)
	if _camera_rig and _camera_rig.has_method("add_recoil_kick"):
		_camera_rig.add_recoil_kick(0.5, randf_range(-0.4, 0.4))
	if health <= 0.0:
		_on_player_down()


func is_alive() -> bool:
	return health > 0.0


func _on_player_down() -> void:
	print("[Player] Vlado je pao.")
	await get_tree().create_timer(2.5).timeout
	health = max_health
	var spawn_y := 2.4
	var sc := get_tree().current_scene
	var td = sc.get("terrain_data") if sc else null
	if td and td.has_method("get_height"):
		spawn_y = td.get_height(-5.0, 9.5) + 0.15
	global_position = Vector3(-5.0, spawn_y, 9.5)
	velocity = Vector3.ZERO
