class_name VladoWeaponIKModifier
extends SkeletonModifier3D
## VladoWeaponIKModifier — post-AnimationTree analytical 2-bone arm IK & weapon socket aligner.
##
## Runs inside SkeletonModifier3D._process_modification() AFTER AnimationTree writes bone poses
## (so Godot 4.7 never overwrites our overrides!).

const PALM_LOCAL_R := Vector3(0.012, 0.068, 0.018)
const PALM_LOCAL_L := Vector3(-0.012, 0.068, 0.018)

var controller: PlayerController
var animator: Node
var weapon_mount_node: Node3D
var active_hold_style: String = "pistol"   # "m48" | "pistol" | "rifle" | "heavy" | "grenade" | "melee"
var active_grip_l_local: Vector3 = Vector3(0.0, 0.02, -0.26)

var _skel: Skeleton3D
var _rua: int = -1
var _rla: int = -1
var _rh: int = -1
var _lua: int = -1
var _lla: int = -1
var _lh: int = -1
var _spine: int = -1
var _chest: int = -1
var _uchest: int = -1

var _weapon_skel_xform: Transform3D = Transform3D.IDENTITY
var _has_weapon_xform: bool = false


func _ready() -> void:
	_skel = get_skeleton()
	_cache_bones()


func _cache_bones() -> void:
	if _skel == null:
		_skel = get_skeleton()
	if _skel == null:
		return
	_rua = _skel.find_bone("RightUpperArm")
	_rla = _skel.find_bone("RightLowerArm")
	_rh = _skel.find_bone("RightHand")
	_lua = _skel.find_bone("LeftUpperArm")
	_lla = _skel.find_bone("LeftLowerArm")
	_lh = _skel.find_bone("LeftHand")
	_spine = _skel.find_bone("Spine")
	_chest = _skel.find_bone("Chest")
	_uchest = _skel.find_bone("UpperChest")


func get_weapon_skel_transform() -> Transform3D:
	return _weapon_skel_xform


func has_weapon_transform() -> bool:
	return _has_weapon_xform


func _process_modification() -> void:
	if _skel == null:
		_cache_bones()
	if _skel == null or _rh < 0 or _lh < 0:
		return

	# 1) Apply subtle torso bank & slope lean from PlayerAnimator (runs post-AnimationTree!)
	if animator:
		var bank_rad: float = float(animator.get("_smoothed_bank_rad"))
		var slope_rad: float = float(animator.get("_smoothed_slope_lean_rad"))
		if absf(bank_rad) > 0.001 or absf(slope_rad) > 0.001:
			for pair in [[_spine, 0.35], [_chest, 0.35], [_uchest, 0.30]]:
				var bi: int = int(pair[0])
				var w: float = float(pair[1])
				if bi >= 0:
					var gp := _skel.get_bone_global_pose(bi)
					var delta_b := Basis(Vector3.FORWARD, bank_rad * w) * Basis(Vector3.RIGHT, -slope_rad * w)
					gp.basis = (delta_b * gp.basis).orthonormalized()
					_skel.set_bone_global_pose(bi, gp)

	if controller == null:
		return

	var equipped: bool = controller.weapon_equipped or (controller.weapon_action in ["Equip", "Holster", "Fire", "Reload"])
	if not equipped or active_hold_style == "m48":
		_has_weapon_xform = false
		return

	var aim_pitch: float = float(animator.get("_smoothed_aim_pitch_rad")) if animator else 0.0
	var is_aim: bool = controller.is_aiming or controller.weapon_action == "Fire"

	# 2) For one-handed / revolver / pistol / grenade / melee, pose Right Arm relative to shoulder
	if active_hold_style in ["pistol", "grenade", "melee"]:
		var r_shoulder: Vector3 = _skel.get_bone_global_pose(_rua).origin if _rua >= 0 else Vector3(0.20, 1.46, -0.03)
		var l_shoulder: Vector3 = _skel.get_bone_global_pose(_lua).origin if _lua >= 0 else Vector3(-0.20, 1.46, -0.03)
		var target_wrist: Vector3
		var barrel_dir: Vector3

		if active_hold_style == "grenade":
			if is_aim:
				target_wrist = r_shoulder + Vector3(0.06, 0.10 + sin(aim_pitch) * 0.14, -0.18)
				barrel_dir = Vector3(0.0, 0.35 + sin(aim_pitch), -cos(aim_pitch)).normalized()
			else:
				target_wrist = r_shoulder + Vector3(0.05, -0.26, -0.20)
				barrel_dir = Vector3(-0.04, 0.25, -0.96).normalized()
		elif active_hold_style == "melee":
			if controller.weapon_action == "Fire":
				target_wrist = r_shoulder + Vector3(-0.10, -0.08, -0.45)
				barrel_dir = Vector3(-0.20, 0.05, -0.98).normalized()
			else:
				target_wrist = r_shoulder + Vector3(0.06, -0.26, -0.26)
				barrel_dir = Vector3(-0.08, -0.18, -0.98).normalized()
		else:
			# Revolver / Pistol (Crnogorski Gaser M1870/74, Luger, P38, TT33, M1922)
			if is_aim:
				target_wrist = r_shoulder + Vector3(-0.05, -0.04 + sin(aim_pitch) * 0.18, -0.43)
				barrel_dir = Vector3(-0.03, sin(aim_pitch), -cos(aim_pitch)).normalized()
			else:
				target_wrist = r_shoulder + Vector3(0.03, -0.22, -0.32)
				barrel_dir = Vector3(-0.06, -0.15, -0.985).normalized()

		_solve_arm_ik(_rua, _rla, _rh, target_wrist, Vector3(0.55, -0.45, 0.65))
		_orient_right_hand_to_barrel(barrel_dir)

		var gp_rh := _skel.get_bone_global_pose(_rh)
		var grip_r_pos: Vector3 = gp_rh * PALM_LOCAL_R
		_weapon_skel_xform = _build_weapon_xform(grip_r_pos, barrel_dir)
		_has_weapon_xform = true

		# Left arm: two-hand Weaver support when aiming pistol, relaxed counterbalance when hip-ready
		if active_hold_style == "pistol" and is_aim:
			var support_palm: Vector3 = _weapon_skel_xform * Vector3(-0.015, -0.055, 0.018)
			_solve_left_palm_ik(support_palm, Vector3(-0.55, -0.45, 0.65))
		else:
			var relax_wrist := l_shoulder + Vector3(-0.04, -0.40, -0.10)
			_solve_arm_ik(_lua, _lla, _lh, relax_wrist, Vector3(-0.60, -0.25, 0.65))

	else:
		# 3) Two-handed firearms (Rifle, SMG, Shotgun, LMG)
		var gp_rh := _skel.get_bone_global_pose(_rh)
		var gp_lh := _skel.get_bone_global_pose(_lh)
		var grip_r_pos: Vector3 = gp_rh * PALM_LOCAL_R
		var lh_palm_pos: Vector3 = gp_lh * PALM_LOCAL_L

		var barrel_dir: Vector3
		if is_aim:
			barrel_dir = Vector3(-0.07, sin(aim_pitch), -cos(aim_pitch)).normalized()
		else:
			var raw_dir := lh_palm_pos - grip_r_pos
			if raw_dir.length_squared() < 0.01:
				raw_dir = Vector3(-0.55, -0.12, -0.82)
			raw_dir.z = minf(raw_dir.z, -0.22)
			raw_dir.y = clampf(raw_dir.y, -0.24, 0.14)
			barrel_dir = raw_dir.normalized()

		_weapon_skel_xform = _build_weapon_xform(grip_r_pos, barrel_dir)
		_has_weapon_xform = true

		# Solve Left Arm 2-bone IK (2 passes so palm offset tracks rotated hand basis)
		var grip_l_target: Vector3 = _weapon_skel_xform * active_grip_l_local
		_solve_left_palm_ik(grip_l_target, Vector3(-0.55, -0.50, 0.55))

	if weapon_mount_node and is_instance_valid(weapon_mount_node) and _has_weapon_xform:
		weapon_mount_node.transform = _weapon_skel_xform


func _solve_left_palm_ik(target_palm: Vector3, pole_hint: Vector3) -> void:
	for _pass in range(2):
		var gp_lh := _skel.get_bone_global_pose(_lh)
		var l_wrist_target: Vector3 = target_palm - gp_lh.basis * PALM_LOCAL_L
		_solve_arm_ik(_lua, _lla, _lh, l_wrist_target, pole_hint)


func _build_weapon_xform(grip_r_pos: Vector3, barrel_dir: Vector3) -> Transform3D:
	var fwd := barrel_dir.normalized()
	var up := (Vector3.UP - fwd * Vector3.UP.dot(fwd))
	if up.length_squared() < 0.001:
		up = Vector3.UP
	up = up.normalized()
	var right := fwd.cross(up).normalized()
	up = right.cross(fwd).normalized()
	# Weapon standard: -Z = fwd, +Y = up, +X = right -> Basis(right, up, -fwd)
	return Transform3D(Basis(right, up, -fwd).orthonormalized(), grip_r_pos)


func _orient_right_hand_to_barrel(barrel_dir: Vector3) -> void:
	if _rh < 0:
		return
	var gp_rh := _skel.get_bone_global_pose(_rh)
	var fwd := barrel_dir.normalized()
	# In Vlado's RightHand bone frame: +Y = fingers (forward), +X = thumb/top (up), +Z = inward (-X)
	var hand_x := Vector3(-0.18, 0.98, 0.0).normalized()
	var hand_y := fwd
	var hand_z := hand_x.cross(hand_y)
	if hand_z.length_squared() < 0.001:
		return
	hand_z = hand_z.normalized()
	hand_x = hand_y.cross(hand_z).normalized()
	gp_rh.basis = Basis(hand_x, hand_y, hand_z).orthonormalized()
	_skel.set_bone_global_pose(_rh, gp_rh)


func _solve_arm_ik(upper_i: int, lower_i: int, hand_i: int, wrist_target: Vector3, pole_hint: Vector3) -> void:
	if upper_i < 0 or lower_i < 0 or hand_i < 0:
		return
	var gp_u := _skel.get_bone_global_pose(upper_i)
	var gp_l := _skel.get_bone_global_pose(lower_i)
	var gp_h := _skel.get_bone_global_pose(hand_i)

	var s: Vector3 = gp_u.origin
	var e0: Vector3 = gp_l.origin
	var h0: Vector3 = gp_h.origin
	var l1: float = maxf(0.05, s.distance_to(e0))
	var l2: float = maxf(0.05, e0.distance_to(h0))

	var to_t := wrist_target - s
	var dist := clampf(to_t.length(), 0.08, (l1 + l2) * 0.985)
	var dir := to_t.normalized() if to_t.length_squared() > 1e-6 else Vector3.FORWARD

	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -0.999, 0.999)
	var sin_a := sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var bend := pole_hint - dir * dir.dot(pole_hint)
	if bend.length_squared() < 1e-5:
		bend = Vector3.DOWN
	bend = bend.normalized()

	var e_new := s + dir * (l1 * cos_a) + bend * (l1 * sin_a)
	var h_new := s + dir * dist

	var u_dir0 := (e0 - s).normalized()
	var u_dir1 := (e_new - s).normalized()
	if u_dir0.length_squared() > 0.5 and u_dir1.length_squared() > 0.5:
		var q_u := Quaternion(u_dir0, u_dir1)
		gp_u.basis = (Basis(q_u) * gp_u.basis).orthonormalized()
		_skel.set_bone_global_pose(upper_i, gp_u)

	var l_dir0 := (h0 - e0).normalized()
	var l_dir1 := (h_new - e_new).normalized()
	if l_dir0.length_squared() > 0.5 and l_dir1.length_squared() > 0.5:
		var q_l := Quaternion(l_dir0, l_dir1)
		gp_l.origin = e_new
		gp_l.basis = (Basis(q_l) * gp_l.basis).orthonormalized()
		_skel.set_bone_global_pose(lower_i, gp_l)
