class_name WeaponController
extends Node

enum State {
	HOLSTERED = 0,
	EQUIPPING = 1,
	READY = 2,
	AIMING = 3,
	RELOADING = 4,
	HOLSTERING = 5,
}

signal state_changed(state_name: String)
signal ammo_changed(mag_ammo: int, reserve_ammo: int, mag_cap: int)
signal shot_fired()
signal target_hit(is_target: bool, distance_m: float, total_hits: int)

@export var mag_capacity: int = 5
@export var starting_reserve: int = 30
@export var fire_cooldown: float = 0.74
@export var equip_duration: float = 0.36
@export var reload_duration: float = 1.45
@export var max_range_m: float = 220.0
@export var aim_spread_deg: float = 0.25
@export var hip_spread_deg: float = 2.1

@export var controller_path: NodePath = NodePath("..")
@export var camera_rig_path: NodePath = NodePath("../CameraRig")
@export var animator_path: NodePath = NodePath("../PlayerAnimator")

var current_state: State = State.HOLSTERED
var mag_ammo: int = 5
var reserve_ammo: int = 30
var total_target_hits: int = 0
var targets_hit_set: Dictionary = {}

var _controller: PlayerController
var _camera_rig: PlayerCamera
var _animator: PlayerAnimator
var _fp_rig: FirstPersonRig
var _skel: Skeleton3D
var _wm_idx: int = -1
var _sound: SoundManager

var _state_timer: float = 0.0
var _fire_timer: float = 0.0
var _recoil_anim_timer: float = 0.0
var _bolt_sound_timer: float = -1.0
var _aim_requested: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 79257
	mag_ammo = mag_capacity
	reserve_ammo = starting_reserve
	_controller = get_node_or_null(controller_path) as PlayerController
	_camera_rig = get_node_or_null(camera_rig_path) as PlayerCamera
	_animator = get_node_or_null(animator_path) as PlayerAnimator
	await get_tree().process_frame
	if _controller:
		_skel = _controller.find_child("Skeleton3D", true, false) as Skeleton3D
		_fp_rig = _controller.find_child("FirstPersonRig", true, false) as FirstPersonRig
		if _skel:
			_wm_idx = _skel.find_bone("WeaponMount")
	_sound = get_tree().root.find_child("SoundManager", true, false) as SoundManager
	_sync_player_flags()
	ammo_changed.emit(mag_ammo, reserve_ammo, mag_capacity)
	state_changed.emit(get_state_label())

func set_sound_manager(sm: SoundManager) -> void:
	_sound = sm

func is_equipped() -> bool:
	return current_state == State.READY or current_state == State.AIMING or current_state == State.RELOADING

func is_aiming() -> bool:
	return current_state == State.AIMING

func is_busy() -> bool:
	return current_state == State.EQUIPPING or current_state == State.HOLSTERING or current_state == State.RELOADING

func get_state_label() -> String:
	match current_state:
		State.HOLSTERED:
			return "Holstered"
		State.EQUIPPING:
			return "Equipping"
		State.READY:
			return "Ready"
		State.AIMING:
			return "Aiming"
		State.RELOADING:
			return "Reloading"
		State.HOLSTERING:
			return "Holstering"
	return "Holstered"

func toggle_equip() -> void:
	if current_state == State.HOLSTERED:
		_begin_equip(false)
	elif is_equipped() and current_state != State.EQUIPPING:
		_aim_requested = false
		current_state = State.HOLSTERING
		_state_timer = equip_duration
		if _sound:
			_sound.play_equip(false)
		_sync_player_flags()
		state_changed.emit(get_state_label())

func toggle_aim() -> void:
	if _controller and _controller.is_sprint_active():
		_controller.set_sprint_active(false)
	if current_state == State.HOLSTERED:
		_begin_equip(true)
		return
	if current_state == State.EQUIPPING:
		_aim_requested = not _aim_requested
		return
	if current_state == State.READY:
		current_state = State.AIMING
		_aim_requested = true
	elif current_state == State.AIMING:
		current_state = State.READY
		_aim_requested = false
	_sync_player_flags()
	state_changed.emit(get_state_label())

func set_aiming(enabled: bool) -> void:
	if enabled and _controller and _controller.is_sprint_active():
		_controller.set_sprint_active(false)
	_aim_requested = enabled
	if enabled and current_state == State.HOLSTERED:
		_begin_equip(true)
	elif enabled and current_state == State.READY:
		current_state = State.AIMING
	elif not enabled and current_state == State.AIMING:
		current_state = State.READY
	_sync_player_flags()
	state_changed.emit(get_state_label())

func try_fire() -> bool:
	if _controller and _controller.current_locomotion_state == "Sprinting":
		return false
	if current_state == State.HOLSTERED:
		_begin_equip(false)
		return false
	if is_busy() or _fire_timer > 0.0:
		return false
	if mag_ammo <= 0:
		if _sound:
			_sound.play_dry_fire()
		if reserve_ammo > 0:
			try_reload()
		return false

	mag_ammo -= 1
	_fire_timer = fire_cooldown
	_recoil_anim_timer = 0.24
	_bolt_sound_timer = 0.22
	ammo_changed.emit(mag_ammo, reserve_ammo, mag_capacity)

	if _controller:
		_controller.notify_weapon_fired(is_aiming())

	var is_fp := _camera_rig != null and _camera_rig.is_fp_active() and _fp_rig != null and _fp_rig.is_fp_visible()
	var muzzle_xform := _get_muzzle_world_xform()
	var muzzle_orig: Vector3 = _fp_rig.get_muzzle_world_position() if is_fp else muzzle_xform.origin
	var ray := _camera_rig.get_aim_ray() if _camera_rig else {"origin": muzzle_orig, "dir": -muzzle_xform.basis.z}
	var ray_orig: Vector3 = ray["origin"]
	var ray_dir: Vector3 = ray["dir"]

	# Apply slight accuracy cone (tight when aiming, wider when hip-firing)
	var spread_rad := deg_to_rad(aim_spread_deg if is_aiming() else hip_spread_deg)
	if _controller and _controller.current_horizontal_speed > 0.4:
		spread_rad *= 1.45
	var spread_dir := (ray_dir + Vector3(
		_rng.randf_range(-spread_rad, spread_rad),
		_rng.randf_range(-spread_rad, spread_rad),
		_rng.randf_range(-spread_rad, spread_rad)
	)).normalized()

	var hit := _raycast_world(ray_orig, spread_dir, max_range_m)
	var impact_pos: Vector3 = hit["pos"]
	var impact_norm: Vector3 = hit["normal"]
	var has_hit: bool = hit["hit"]
	var collider: Object = hit["collider"]

	var fx_parent := get_tree().current_scene if get_tree().current_scene else _controller.get_parent()
	if is_fp:
		_fp_rig.trigger_muzzle_flash()
		WeaponEffects.spawn_tracer(fx_parent, muzzle_orig + spread_dir * 0.25, impact_pos)
	else:
		WeaponEffects.spawn_muzzle_flash(fx_parent, muzzle_orig, (impact_pos - muzzle_orig).normalized())
		WeaponEffects.spawn_tracer(fx_parent, muzzle_orig, impact_pos)

	if _sound:
		_sound.play_rifle_shot()
	if _camera_rig:
		var kick_p := (1.15 if is_aiming() else 1.55) if is_fp else (1.7 if is_aiming() else 2.2)
		var kick_y := _rng.randf_range(-0.28, 0.28) if is_fp else _rng.randf_range(-0.45, 0.45)
		_camera_rig.add_recoil_kick(kick_p, kick_y)

	if has_hit:
		var surf := "dirt"
		var is_tgt := false
		var hit_dist := _controller.global_position.distance_to(impact_pos) if _controller else 0.0
		# Stage 4: the M48 damages post-war adversaries. Hit registration
		# stays identical; only an extra branch is added before the target case.
		if collider is PostWarEnemy:
			(collider as PostWarEnemy).take_damage(120.0)
			surf = "wood"
			target_hit.emit(false, hit_dist, targets_hit_set.size())
		elif collider is ShootingTarget:
			var st := collider as ShootingTarget
			surf = st.surface_kind
			is_tgt = true
			hit_dist = st.register_hit(impact_pos, _controller.global_position if _controller else ray_orig)
			total_target_hits += 1
			targets_hit_set[st.name] = true
		elif collider is Node:
			var nm := (collider as Node).name.to_lower()
			if "rock" in nm or "house" in nm or "wall" in nm or "well" in nm or "bridge" in nm:
				surf = "stone"
			elif "barn" in nm or "tree" in nm:
				surf = "wood"
		WeaponEffects.spawn_impact(fx_parent, impact_pos, impact_norm, surf)
		if _sound:
			_sound.play_hit(surf)
		target_hit.emit(is_tgt, hit_dist, targets_hit_set.size())

	# Eject brass shell slightly after bolt opens
	var wm_w := _get_wm_world_xform()
	WeaponEffects.spawn_shell_casing(fx_parent, wm_w.origin + wm_w.basis.y * 0.02, wm_w.basis.x, wm_w.basis.z)

	shot_fired.emit()
	_sync_player_flags()
	return true

func try_reload() -> bool:
	if current_state == State.HOLSTERED or is_busy():
		return false
	if mag_ammo >= mag_capacity or reserve_ammo <= 0:
		return false
	current_state = State.RELOADING
	_state_timer = reload_duration
	if _sound:
		_sound.play_reload()
	_sync_player_flags()
	state_changed.emit(get_state_label())
	return true

func add_reserve_ammo(amount: int) -> bool:
	if reserve_ammo >= 60:
		return false
	reserve_ammo = mini(reserve_ammo + amount, 60)
	ammo_changed.emit(mag_ammo, reserve_ammo, mag_capacity)
	return true

func play_reload_chime() -> void:
	if _sound:
		_sound.play_equip(true)

func _begin_equip(also_aim: bool) -> void:
	_aim_requested = also_aim
	current_state = State.EQUIPPING
	_state_timer = equip_duration
	if _sound:
		_sound.play_equip(true)
	_sync_player_flags()
	state_changed.emit(get_state_label())

func _physics_process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = maxf(0.0, _fire_timer - delta)
	if _recoil_anim_timer > 0.0:
		_recoil_anim_timer = maxf(0.0, _recoil_anim_timer - delta)
		if _recoil_anim_timer <= 0.0:
			_sync_player_flags()

	if _bolt_sound_timer > 0.0:
		_bolt_sound_timer -= delta
		if _bolt_sound_timer <= 0.0:
			_bolt_sound_timer = -1.0
			if _sound:
				_sound.play_bolt_cycle()

	if _state_timer > 0.0:
		_state_timer -= delta
		if _state_timer <= 0.0:
			if current_state == State.EQUIPPING:
				current_state = State.AIMING if _aim_requested else State.READY
			elif current_state == State.HOLSTERING:
				current_state = State.HOLSTERED
				_aim_requested = false
			elif current_state == State.RELOADING:
				var needed := mag_capacity - mag_ammo
				var take := mini(needed, reserve_ammo)
				mag_ammo += take
				reserve_ammo -= take
				ammo_changed.emit(mag_ammo, reserve_ammo, mag_capacity)
				current_state = State.AIMING if _aim_requested else State.READY
			_sync_player_flags()
			state_changed.emit(get_state_label())

func _sync_player_flags() -> void:
	if not _controller:
		return
	_controller.weapon_equipped = is_equipped() or current_state == State.EQUIPPING or current_state == State.HOLSTERING
	_controller.is_aiming = current_state == State.AIMING
	if current_state == State.EQUIPPING:
		_controller.weapon_action = "Equip"
	elif current_state == State.HOLSTERING:
		_controller.weapon_action = "Holster"
	elif current_state == State.RELOADING:
		_controller.weapon_action = "Reload"
	elif _recoil_anim_timer > 0.0:
		_controller.weapon_action = "Fire"
	else:
		_controller.weapon_action = ""

func _get_wm_world_xform() -> Transform3D:
	if _skel and _wm_idx >= 0:
		return _skel.global_transform * _skel.get_bone_global_pose(_wm_idx)
	return _controller.global_transform if _controller else Transform3D.IDENTITY

func _get_muzzle_world_xform() -> Transform3D:
	# === POPRAVKA v17 ===
	# Prije: mlaznica se racunala iz kosti WeaponMount + 0.68 m navise, a ta
	# kost stoji na visini ramena -> mlaznica (bijela lopta) je bila IZNAD
	# GLAVE. Sada se koristi stvarni transform puske u svijetu.
	var anim := _controller.get_node_or_null("PlayerAnimator") if _controller else null
	if anim != null and anim.has_method("get_world_muzzle"):
		var mp: Vector3 = anim.call("get_world_muzzle")
		var fwd := -_controller.global_transform.basis.z
		return Transform3D(Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, -fwd), mp)
	var wm_w := _get_wm_world_xform()
	var muzzle_pos := wm_w * Vector3(0.0, 0.68, 0.022)
	return Transform3D(wm_w.basis, muzzle_pos)
	# === kraj popravke ===

func _raycast_world(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	var space := _controller.get_world_3d().direct_space_state if _controller else null
	if not space:
		return {"hit": false, "pos": origin + dir * max_dist, "normal": Vector3.UP, "collider": null}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_dist, 1 | 4)
	if _controller:
		query.exclude = [_controller.get_rid()]
	var res := space.intersect_ray(query)
	if res.is_empty():
		return {"hit": false, "pos": origin + dir * max_dist, "normal": Vector3.UP, "collider": null}
	return {"hit": true, "pos": res["position"], "normal": res["normal"], "collider": res.get("collider", null)}
