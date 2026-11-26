class_name PlayerAnimator
extends Node

@export var controller_path: NodePath = NodePath("..")
@export var model_root_path: NodePath = NodePath("../VisualRoot/VladoModel")
@export var visual_root_path: NodePath = NodePath("../VisualRoot")
@export var locomotion_library_path: String = ""
@export var crossfade_seconds: float = 0.16

# Referentne brzine = brzina kojom animacija PRIRODNO krece stopalo.
# Izmjereno iz GLB klipova:
#   Walking   1.20 s ciklus, ~1.50 m -> 1.25 m/s
#   Running   0.80 s ciklus, ~3.00 m -> 3.75 m/s
#   Sprinting 0.67 s ciklus, ~4.30 m -> 6.40 m/s
#   Crouching 1.00 s ciklus, ~1.10 m -> 1.10 m/s
# Ako su pogresne, stopala klize po zemlji.
const WALK_REF_SPEED := 1.25
const RUN_REF_SPEED := 3.75
const SPRINT_REF_SPEED := 6.40
const CROUCH_REF_SPEED := 1.10
const AIM_WALK_REF_SPEED := 1.25
const AIM_CROUCH_REF_SPEED := 1.10

var _controller: PlayerController
var _visual_root: Node3D
var _anim_player: AnimationPlayer
var _skel: Skeleton3D
var _anim_tree: AnimationTree
var _state_machine: AnimationNodeStateMachinePlayback
var _active_state: String = "Idle"

var _spine_idx: int = -1
var _chest_idx: int = -1
var _upper_chest_idx: int = -1
var _wm_idx: int = -1
var _rh_idx: int = -1
var _wm_rel_chest: Transform3D = Transform3D.IDENTITY
var _rifle_mi: MeshInstance3D = null
var _rifle_home: Transform3D = Transform3D.IDENTITY
var _rifle_attached := false
var _has_wm_offset: bool = false

var _active_hold_style: String = "pistol"
var _weapon_mount_node: Node3D = null

var _smoothed_bank_rad: float = 0.0
var _smoothed_slope_lean_rad: float = 0.0
var _smoothed_ground_drop: float = 0.0
var _smoothed_aim_pitch_rad: float = 0.0
var _ik_mod: Node = null

func _ready() -> void:
	_controller = get_node_or_null(controller_path)
	_visual_root = get_node_or_null(visual_root_path)
	var model_root := get_node_or_null(model_root_path)
	if model_root:
		_anim_player = model_root.find_child("AnimationPlayer", true, false)
		_skel = model_root.find_child("Skeleton3D", true, false)
		_configure_character_materials(model_root)

	if _anim_player and _skel:
		_cache_skeleton_indices()
	if _anim_player:
		_setup_animation_tree()



func _configure_character_materials(model_root: Node) -> void:
	# Ne oslanjaj se na GLB ORM interpretaciju na Android mobile rendereru.
	# Eksplicitni surface override sprečava potpuno crnu siluetu na telefonu.
	_apply_vlado_material(model_root, "Vlado_Body", "Character", false)
	_apply_vlado_material(model_root, "Vlado_Hair", "Hair", true)
	_apply_vlado_material(model_root, "Rifle_BoltAction", "Rifle", false)


func _apply_vlado_material(model_root: Node, mesh_name: String, texture_name: String, is_hair: bool) -> void:
	var mesh_instance := model_root.find_child(mesh_name, true, false) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return
	var base := "res://assets/characters/vlado/Vlado_Sipcic_ReRigged_%s_" % texture_name
	var albedo := load(base + "Albedo.jpg") as Texture2D
	var normal := load(base + "Normal.jpg") as Texture2D
	if albedo == null:
		push_warning("Vlado material missing: " + base + "Albedo.jpg")
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = albedo
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.metallic = 0.0
	mat.roughness = 0.84 if not is_hair else 0.78
	mat.normal_enabled = normal != null
	mat.normal_texture = normal
	mat.normal_scale = 0.62
	# Vrlo blaga teksturisana emisija čuva detalje u sjenci bez unshaded izgleda.
	mat.emission_enabled = true
	mat.emission_texture = albedo
	mat.emission = Color(0.10, 0.10, 0.10)
	mat.emission_energy_multiplier = 1.0
	if is_hair:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.42
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		mat.cull_mode = BaseMaterial3D.CULL_BACK
	mesh_instance.set_surface_override_material(0, mat)

func _load_locomotion_library() -> void:
	if not ResourceLoader.exists(locomotion_library_path):
		push_warning("Missing locomotion library: " + locomotion_library_path)
		return
	var loco_lib := load(locomotion_library_path) as AnimationLibrary
	if not loco_lib:
		return
	if _anim_player.has_animation_library("vlado_loco"):
		_anim_player.remove_animation_library("vlado_loco")
	_anim_player.add_animation_library("vlado_loco", loco_lib)

func _cache_skeleton_indices() -> void:
	_spine_idx = _skel.find_bone("Spine")
	_chest_idx = _skel.find_bone("Chest")
	_upper_chest_idx = _skel.find_bone("UpperChest")
	_wm_idx = _skel.find_bone("WeaponMount")
	_rh_idx = _skel.find_bone("RightHand")
	if _upper_chest_idx != -1 and _wm_idx != -1:
		var prev_cb := _anim_player.callback_mode_process
		_anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var idle_clip := "vlado_loco/Idle" if _anim_player.has_animation("vlado_loco/Idle") else "Idle"
		_anim_player.play(idle_clip)
		_anim_player.seek(0.0, true)
		_anim_player.advance(0.0)
		_wm_rel_chest = _skel.get_bone_global_pose(_upper_chest_idx).affine_inverse() * _skel.get_bone_global_pose(_wm_idx)
		_has_wm_offset = true
		_anim_player.stop()
		_anim_player.callback_mode_process = prev_cb
	_find_rifle()

func _setup_animation_tree() -> void:
	_anim_tree = AnimationTree.new()
	_anim_tree.name = "LocomotionTree"
	add_child(_anim_tree)

	var sm := AnimationNodeStateMachine.new()
	var state_to_clip := {"Idle":"Idle","Walking":"Walking","Running":"Running","Sprinting":"Sprinting","CrouchIdle":"CrouchIdle","CrouchWalk":"Crouching","JumpStart":"JumpStart","Jumping":"Jumping","Landing":"Landing"}
	for combat_st in ["PistolIdle","PistolAim","PistolFire","PistolReload","PistolWalk","PistolRun","PistolEquip","PistolHolster","RifleIdle","RifleAim","RifleWalk","RifleRun","HeavyIdle","HeavyWalk","RifleEquip","RifleHolster","RifleFire","HeavyFire","RifleReload","GrenadeIdle","GrenadeThrow","MeleeIdle","MeleeAttack"]:
		if _anim_player.has_animation(combat_st): state_to_clip[combat_st] = combat_st

	for state_name in state_to_clip.keys():
		var node := AnimationNodeAnimation.new()
		node.animation = state_to_clip[state_name]
		sm.add_node(state_name, node)

	var tr_start := AnimationNodeStateMachineTransition.new()
	tr_start.xfade_time = 0.0
	tr_start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "Idle", tr_start)

	var grounded_states := ["Idle", "Walking", "Running", "Sprinting", "CrouchIdle", "CrouchWalk"]
	var combat_states := ["PistolIdle","PistolAim","PistolFire","PistolReload","PistolWalk","PistolRun","PistolEquip","PistolHolster","RifleIdle","RifleAim","RifleWalk","RifleRun","HeavyIdle","HeavyWalk","RifleEquip","RifleHolster","RifleFire","HeavyFire","RifleReload","GrenadeIdle","GrenadeThrow","MeleeIdle","MeleeAttack"]
	var all_grounded := grounded_states.duplicate()
	for cs in combat_states:
		if state_to_clip.has(cs):
			all_grounded.append(cs)

	for a in all_grounded:
		for b in all_grounded:
			if a == b:
				continue
			var tr := AnimationNodeStateMachineTransition.new()
			if b == "FireRecoil" or a == "FireRecoil":
				tr.xfade_time = 0.04
			elif b in ["EquipRifle", "HolsterRifle", "ReloadBolt"] or a in ["EquipRifle", "HolsterRifle"]:
				tr.xfade_time = 0.09
			elif b in ["AimIdle", "AimWalk", "AimCrouchIdle", "AimCrouchWalk"] or a in ["AimIdle", "AimWalk", "AimCrouchIdle", "AimCrouchWalk"]:
				tr.xfade_time = 0.12
			elif a == "Idle" or b == "Idle":
				tr.xfade_time = 0.14
			elif (a == "Running" and b == "Sprinting") or (a == "Sprinting" and b == "Running"):
				tr.xfade_time = 0.18
			else:
				tr.xfade_time = crossfade_seconds
			sm.add_transition(a, b, tr)

	for g in all_grounded:
		var tr_js := AnimationNodeStateMachineTransition.new()
		tr_js.xfade_time = 0.06
		sm.add_transition(g, "JumpStart", tr_js)

		var tr_ja := AnimationNodeStateMachineTransition.new()
		tr_ja.xfade_time = 0.08
		sm.add_transition(g, "Jumping", tr_ja)

		var tr_lg := AnimationNodeStateMachineTransition.new()
		tr_lg.xfade_time = 0.15
		sm.add_transition("Landing", g, tr_lg)

		var tr_jg := AnimationNodeStateMachineTransition.new()
		tr_jg.xfade_time = 0.14
		sm.add_transition("Jumping", g, tr_jg)

	var tr_js_ja := AnimationNodeStateMachineTransition.new()
	tr_js_ja.xfade_time = 0.07
	sm.add_transition("JumpStart", "Jumping", tr_js_ja)

	var tr_js_lg := AnimationNodeStateMachineTransition.new()
	tr_js_lg.xfade_time = 0.10
	sm.add_transition("JumpStart", "Landing", tr_js_lg)

	var tr_ja_l := AnimationNodeStateMachineTransition.new()
	tr_ja_l.xfade_time = 0.09
	sm.add_transition("Jumping", "Landing", tr_ja_l)

	var tr_l_js := AnimationNodeStateMachineTransition.new()
	tr_l_js.xfade_time = 0.08
	sm.add_transition("Landing", "JumpStart", tr_l_js)

	var tr_l_ja := AnimationNodeStateMachineTransition.new()
	tr_l_ja.xfade_time = 0.10
	sm.add_transition("Landing", "Jumping", tr_l_ja)

	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Locomotion", sm, Vector2(-280, 80))
	var ts := AnimationNodeTimeScale.new()
	blend_tree.add_node("TimeScale", ts, Vector2(0, 80))
	blend_tree.connect_node("TimeScale", 0, "Locomotion")
	blend_tree.connect_node("output", 0, "TimeScale")

	_anim_tree.tree_root = blend_tree
	_anim_tree.anim_player = _anim_tree.get_path_to(_anim_player)
	_anim_tree.active = true
	_state_machine = _anim_tree.get("parameters/Locomotion/playback")
	if _state_machine:
		_state_machine.start("Idle")

func _resolve_target_state() -> String:
	var loco: String = _controller.current_locomotion_state
	if loco in ["JumpStart", "Jumping", "Landing"]:
		return loco

	var act: String = _controller.weapon_action
	var speed := _controller.current_horizontal_speed
	if _controller.weapon_equipped:
		if _active_hold_style == "pistol":
			if act == "Equip": return "PistolEquip"
			if act == "Holster": return "PistolHolster"
			if act == "Reload": return "PistolReload"
			if act == "Fire": return "PistolFire"
			if _controller.is_aiming: return "PistolAim"
			if speed < 0.14: return "PistolIdle"
			return "PistolWalk" if speed < 2.2 else "PistolRun"
		if _active_hold_style == "grenade":
			if act == "Equip": return "PistolEquip"
			if act == "Holster": return "PistolHolster"
			if act == "Fire": return "GrenadeThrow"
			return "GrenadeIdle"
		if _active_hold_style == "melee":
			if act == "Equip": return "PistolEquip"
			if act == "Holster": return "PistolHolster"
			if act == "Fire": return "MeleeAttack"
			return "MeleeIdle"
		if _active_hold_style in ["rifle", "heavy", "m48"]:
			if act == "Equip": return "RifleEquip"
			if act == "Holster": return "RifleHolster"
			if act == "Reload": return "RifleReload"
			if act == "Fire": return "HeavyFire" if _active_hold_style == "heavy" else "RifleFire"
			if _controller.is_aiming: return "RifleAim"
			if _active_hold_style == "heavy": return "HeavyIdle" if speed < 0.14 else "HeavyWalk"
			if speed < 0.14: return "RifleIdle"
			return "RifleWalk" if speed < 2.6 else "RifleRun"

	return loco

func _process(delta: float) -> void:
	# POPRAVKA v17: puska na ledja / u ruke — MORA ici poslije animacije.
	_update_weapon_mount()

	if not _controller or not _anim_tree or not _state_machine:
		return

	var target_state := _resolve_target_state()
	if target_state != _active_state:
		_state_machine.travel(target_state)
		_active_state = target_state

	var speed: float = _controller.current_horizontal_speed
	var scale := 1.0
	match _active_state:
		"Walking":
			scale = clampf(speed / WALK_REF_SPEED, 0.55, 1.60)
		"PistolWalk", "RifleWalk", "HeavyWalk":
			scale = clampf(speed / WALK_REF_SPEED, 0.58, 1.55)
		"PistolRun", "RifleRun":
			scale = clampf(speed / RUN_REF_SPEED, 0.62, 1.45)
		"Running":
			scale = clampf(speed / RUN_REF_SPEED, 0.62, 1.45)
		"Sprinting":
			scale = clampf(speed / SPRINT_REF_SPEED, 0.70, 1.35)
		"CrouchWalk":
			scale = clampf(speed / CROUCH_REF_SPEED, 0.65, 1.25)
		"AimWalk":
			scale = clampf(speed / AIM_WALK_REF_SPEED, 0.55, 1.25)
		"AimCrouchWalk":
			scale = clampf(speed / AIM_CROUCH_REF_SPEED, 0.55, 1.25)
		"Landing":
			scale = 1.20 if speed > 2.2 else 1.0
		_:
			scale = 1.0
	_anim_tree.set("parameters/TimeScale/scale", scale)

	var speed_frac := clampf(speed / SPRINT_REF_SPEED, 0.0, 1.0)
	var target_bank := clampf(-_controller.current_turn_rate_rad * 0.010 * speed_frac, -deg_to_rad(3.0), deg_to_rad(3.0))
	if not _controller.is_grounded or _controller.is_aiming:
		target_bank *= 0.25
	_smoothed_bank_rad = lerpf(_smoothed_bank_rad, target_bank, 1.0 - exp(-10.0 * delta))

	var target_slope_lean := 0.0
	var target_ground_drop := 0.0
	if _controller.is_grounded:
		var signed_deg: float = _controller.current_signed_slope_deg
		target_slope_lean = clampf(deg_to_rad(signed_deg * 0.22), -deg_to_rad(6.0), deg_to_rad(7.0))
		if _controller.current_slope_deg > 8.0:
			target_ground_drop = clampf(-0.045 * sin(deg_to_rad(_controller.current_slope_deg)), -0.04, 0.0)
	_smoothed_slope_lean_rad = lerpf(_smoothed_slope_lean_rad, target_slope_lean, 1.0 - exp(-8.0 * delta))
	_smoothed_ground_drop = lerpf(_smoothed_ground_drop, target_ground_drop, 1.0 - exp(-12.0 * delta))

	var target_aim_pitch := 0.0
	if _controller.is_aiming or _controller.weapon_action == "Fire":
		target_aim_pitch = clampf(_controller.get_aim_pitch_rad(), -deg_to_rad(32.0), deg_to_rad(38.0))
	_smoothed_aim_pitch_rad = lerpf(_smoothed_aim_pitch_rad, target_aim_pitch, 1.0 - exp(-14.0 * delta))

	if _visual_root:
		_visual_root.position.y = _smoothed_ground_drop


# === POPRAVKA v17: PUSKA JE VISILA IZNAD GLAVE ===
# Mjereno u igri: Rifle_BoltAction je 100% vezana za kost "WeaponMount"
# (868 od 868 tezina), ali ta kost stoji na visini ramena i puska se od nje
# pruza +0.68 m NAVISE -> AABB y 2.90..3.90 dok je Vlado visok 1.82 m.
# Zato je puska bila iznad glave, a mlaznica (bijela lopta) jos vislje.
# MeshInstance3D.transform se za skinned mesh IGNORISE, pa se sve radi
# isključivo preko kosti, sa matricama izmjerenim u igri.
#
# Izmjereno u pokrenutoj sceni (prostor Skeletona, tijelo je y 0..1.83):
#   na ledjima:  X -0.28..0.28  Y 0.52..1.52  Z 0.08..0.32
#   u rukama:    X -0.12..0.44  Y 1.13..1.23  Z -0.92..0.08   (cijev naprijed)
# Bind matrica kosti WeaponMount (P_BIND) i relativne poze u odnosu na
# UpperChest (ledja) i RightHand (ruke) su izmjerene, ne procjenjene.
const P_BIND := Transform3D(
	Vector3(-0.5841516, -0.3708374, -0.7219741),
	Vector3(-0.5035451, 0.86322004, -0.035967458),
	Vector3(0.6365606, 0.34253597, -0.69098467),
	Vector3(0.5806106, -1.0773715, -0.35085502))
const REL_BACK := Transform3D(
	Vector3(0.99999315, 0.0010855106, 0.0035625903),
	Vector3(-0.00047987225, 0.9861618, -0.16578418),
	Vector3(0.0036932542, -0.1657814, -0.98615587),
	Vector3(0.043431964, -1.487392, 0.15855645))
const REL_HANDS := Transform3D(
	Vector3(-0.17546846, 0.9703112, 0.16645402),
	Vector3(0.059939403, 0.17929307, -0.9819681),
	Vector3(0.9826586, 0.1623273, 0.08962013),
	Vector3(-1.0221993, -0.23094833, -0.036963418))
const MUZZLE_ON_WM := Vector3(-0.007, 0.680, 0.022)
const MUZZLE_MESH := Vector3(-0.043, 1.8628, 0.159)

# Gotove poze kosti WeaponMount — izracunate iz konvergiranih mjerenja u
# pokrenutoj sceni, ne procijenjene. Lijepi se kao G = D * P_BIND^-1.
#   ledja: X -0.28..0.28  Y 0.50..1.50  Z 0.10..0.34   (tijelo: 0..1.83 / -0.23..0.15)
#   ruke:  X -0.14..0.42  Y 1.10..1.20  Z -0.90..0.10  (cijev naprijed)
const D_BACK := Transform3D(Vector3(1, 0, 0), Vector3(0, 0.9805807, -0.19611615), Vector3(0, 0.19611615, 0.9805807), Vector3(0.043144137, -0.30540693, 0.30701665))
const D_HANDS := Transform3D(Vector3(1, 0, 0), Vector3(0, 0.049937606, 0.99875236), Vector3(0, -0.99875236, 0.049937606), Vector3(0.18314414, 0.92337465, 1.46338215))

## POPRAVKA v17 — GRUPA A
## Da li je M48 izabran kao aktivno oruzje u arsenalu (Stage 3.3).
## Kad NIJE izabran, M48 ostaje VIDLJIVA na ledjima — nikad se ne skriva.
var _rifle_selected := true
var _rifle_owned := true
var _rifle_last_hands := false


func _find_rifle() -> void:
	_rifle_mi = null
	if _skel == null:
		return
	for c in _skel.get_children():
		if c is MeshInstance3D and String(c.name) == "Rifle_BoltAction":
			_rifle_mi = c as MeshInstance3D
			break
	if _rifle_mi == null:
		return
	# === POPRAVKA v17 ===
	# Puska je skinned mesh sa 868/868 tezine na kosti WeaponMount, a ta kost
	# stoji na visini ramena i puska se od nje pruza +0.68 m NAVISE -> visila
	# je iznad glave, a mlaznica (bijela lopta) jos vislje. Animacija svaki
	# frame pise pozu te kosti i pregazi svaku nasu korekciju.
	# Rjesenje: puska se odvaja od skina (skin = null) i kaci na
	# BoneAttachment3D, pa je AnimationMixer uopste ne dira.
	_rifle_home = _rifle_mi.transform
	# Puska se odvaja od skina i ostaje dijete Skeleton3D. Posto je mesh vec
	# ispravno oblikovan u prostoru skeletona (X -0.32..0.23, Y 0.86..1.86,
	# Z 0.08..0.23), dovoljno je postaviti _rifle_mi.transform u tom istom
	# prostoru — bez BineAttachment3D, bez kosti, bez animacijskih trackova.
	_rifle_mi.skin = null
	_rifle_mi.skeleton = NodePath("")
	if _skel.get_node_or_null("RifleSocket") != null:
		_skel.remove_child(_skel.get_node("RifleSocket"))
	_rifle_mi.transform = D_BACK


## POPRAVKA v17 — GRUPA A: drzi pusku na ledjima ili u rukama.
##
## v16 greska: WeaponArsenal je zvao `rifle.visible = false` kad je MG42
## izabran. Posto M48 postoji kao JEDAN primjerak u sceni, puska je nestajala
## u potpunosti — nije bila ni u rukama ni na ledjima.
##
## Sada:
##   · M48 je VIDLJIVA uvijek dok je u vlasnistvu (_rifle_owned)
##   · u RUKE ide samo ako je izabrana u arsenalu I equipped u Stage 3.2
##   · inace je NA LEDJIMA
func _update_weapon_mount() -> void:
	if _rifle_mi == null:
		return
	var equipped: bool = _controller != null and (
		_controller.weapon_equipped or _controller.weapon_action in ["Equip", "Holster"])
	var in_hands: bool = equipped and _rifle_selected
	_rifle_last_hands = in_hands
	_rifle_mi.visible = _rifle_owned
	_rifle_mi.transform = D_HANDS if in_hands else D_BACK


## POPRAVKA v17 — GRUPA A: WeaponArsenal kaze da li je M48 izabran.
## Ovo NIKAD ne skriva pusku — samo je prebacuje ruke <-> ledja.
func set_rifle_selected(selected: bool) -> void:
	_rifle_selected = selected
	_update_weapon_mount()


## POPRAVKA v17 — GRUPA A: je li M48 u vlasnistvu (za buduce koristenje).
func set_rifle_owned(owned: bool) -> void:
	_rifle_owned = owned
	_update_weapon_mount()


## Pozicija vrha cijevi u svijetu — za tracer, flash i raycast.
func get_world_muzzle() -> Vector3:
	if _rifle_mi != null:
		var mz := _rifle_mi.global_transform * MUZZLE_MESH
		if mz != Vector3.ZERO:
			return mz
	if _skel != null:
		return _skel.global_position + Vector3(0.0, 1.5, -0.6)
	return Vector3.ZERO


func _on_skeleton_updated() -> void:
	if not _skel or _ik_mod != null:
		return
	var has_bank := absf(_smoothed_bank_rad) > 0.001
	var has_slope := absf(_smoothed_slope_lean_rad) > 0.001

	if has_bank or has_slope:
		for pair in [[_spine_idx, 0.35], [_chest_idx, 0.35], [_upper_chest_idx, 0.30]]:
			var bi: int = pair[0]
			var w: float = pair[1]
			if bi == -1:
				continue
			var gp := _skel.get_bone_global_pose(bi)
			var delta_b := Basis(Vector3.FORWARD, _smoothed_bank_rad * w) * Basis(Vector3.RIGHT, -_smoothed_slope_lean_rad * w)
			gp.basis = (delta_b * gp.basis).orthonormalized()
			_skel.set_bone_global_pose(bi, gp)

	# === POPRAVKA v17 ===
	# Paznja: kost se NE postavlja ovdje. skeleton_updated se emituje PRIJE
	# nego sto AnimationMixer upise poze za ovaj frame, pa bi animacija
	# pregazila nasu pozu. Postavljanje je u _process (vidi dolje).
	# === kraj popravke ===

func set_weapon_hold_profile(hold_style: String, _grip_l_local: Vector3 = Vector3(0.0, 0.02, -0.26)) -> void:
	_active_hold_style = hold_style
func set_weapon_mount_node(node: Node3D) -> void:
	_weapon_mount_node = node
func get_weapon_ik_modifier() -> Node:
	return null


func get_active_animation() -> String:
	return _active_state
