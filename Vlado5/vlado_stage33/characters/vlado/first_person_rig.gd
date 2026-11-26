class_name FirstPersonRig
extends Node3D

@export var controller_path: NodePath = NodePath("..")
@export var camera_rig_path: NodePath = NodePath("../CameraRig")
@export var visual_root_path: NodePath = NodePath("../VisualRoot")
@export var model_scene_path: String = "res://assets/characters/vlado/vlado_sipcic.glb"
@export var fps_library_path: String = "res://animations/vlado_fps.tres"
@export var ready_fov: float = 52.0
@export var ads_fov: float = 44.0

const FPS_WALK_REF := 1.65
const FPS_RUN_REF := 4.35
const FPS_SPRINT_REF := 6.40
const EYE_OFFSET_IN_SKEL := Vector3(0.0, -1.690, 0.060)
const MUZZLE_LOCAL_ON_WM := Vector3(-0.007, 0.680, 0.022)

var _controller: PlayerController
var _camera_rig: PlayerCamera
var _visual_root: Node3D

var _canvas_layer: CanvasLayer
var _svp_container: SubViewportContainer
var _sub_viewport: SubViewport
var _fps_cam: Camera3D
var _fps_env: Environment
var _fps_sun: DirectionalLight3D
var _fps_fill: DirectionalLight3D
var _rig_root: Node3D
var _fps_model: Node3D
var _fps_skel: Skeleton3D
var _fps_ap: AnimationPlayer
var _fps_tree: AnimationTree
var _fps_sm: AnimationNodeStateMachinePlayback

var _wm_idx: int = -1
var _muzzle_light: OmniLight3D
var _muzzle_flash_mesh: MeshInstance3D
var _flash_timer: float = 0.0
var _active_state: String = "FPS_WeaponIdle"
var _tp_meshes: Array[MeshInstance3D] = []
var _tp_hidden: bool = false
var _fp_active: bool = false

var _sway_offset: Vector2 = Vector2.ZERO
var _recoil_kick_z: float = 0.0
var _ads_blend: float = 0.0
var _last_action: String = ""

func _ready() -> void:
	_controller = get_node_or_null(controller_path)
	_camera_rig = get_node_or_null(camera_rig_path)
	_visual_root = get_node_or_null(visual_root_path)

	_cache_tp_meshes()
	_build_viewport_hierarchy()
	_load_fps_rig_and_animations()
	set_fp_active(false, false)

func _cache_tp_meshes() -> void:
	_tp_meshes.clear()
	if not _visual_root:
		return
	for n in _visual_root.find_children("*", "MeshInstance3D", true, false):
		if n is MeshInstance3D:
			_tp_meshes.append(n as MeshInstance3D)

func _build_viewport_hierarchy() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "FPSViewLayer"
	_canvas_layer.layer = 0
	add_child(_canvas_layer)

	_svp_container = SubViewportContainer.new()
	_svp_container.name = "FPSViewportContainer"
	_svp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_svp_container.stretch = true
	_svp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_svp_container.visible = false
	_canvas_layer.add_child(_svp_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "FPSSubViewport"
	_sub_viewport.own_world_3d = true
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sub_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_svp_container.add_child(_sub_viewport)

	_fps_cam = Camera3D.new()
	_fps_cam.name = "FPS_Camera3D"
	_fps_cam.cull_mask = 1
	_fps_cam.fov = ready_fov
	_fps_cam.near = 0.015
	_fps_cam.far = 12.0
	_fps_cam.current = true
	_fps_env = Environment.new()
	_fps_env.background_mode = Environment.BG_CLEAR_COLOR
	_fps_env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	_fps_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_fps_env.ambient_light_color = Color(0.56, 0.62, 0.68)
	_fps_env.ambient_light_energy = 0.72
	_fps_cam.environment = _fps_env
	_sub_viewport.add_child(_fps_cam)

	# Isolated FPS sun + sky-bounce lights synced to Montenegro SunLight/TimeOfDayController
	# (avoids self-shadowing from 3rd-person SHADOWS_ONLY torso/skull!)
	_fps_sun = DirectionalLight3D.new()
	_fps_sun.name = "FPSSunLight"
	_fps_sun.shadow_enabled = false
	_fps_sun.light_energy = 1.45
	_fps_sun.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
	_sub_viewport.add_child(_fps_sun)

	_fps_fill = DirectionalLight3D.new()
	_fps_fill.name = "FPSBounceLight"
	_fps_fill.shadow_enabled = false
	_fps_fill.light_color = Color(0.76, 0.84, 0.96)
	_fps_fill.light_energy = 0.42
	_fps_fill.rotation_degrees = Vector3(32.0, -145.0, 0.0)
	_sub_viewport.add_child(_fps_fill)

	_rig_root = Node3D.new()
	_rig_root.name = "FPS_RigRoot"
	_fps_cam.add_child(_rig_root)

func _load_fps_rig_and_animations() -> void:
	if not ResourceLoader.exists(model_scene_path):
		push_warning("Missing Vlado GLB for FPS rig: " + model_scene_path)
		return
	var packed := load(model_scene_path) as PackedScene
	if not packed:
		return

	_fps_model = packed.instantiate()
	_fps_model.name = "VladoFPSModel"
	_fps_model.position = EYE_OFFSET_IN_SKEL
	_rig_root.add_child(_fps_model)

	_fps_skel = _fps_model.find_child("Skeleton3D", true, false) as Skeleton3D
	_fps_ap = _fps_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var body_mi := _fps_model.find_child("Vlado_Body", true, false) as MeshInstance3D
	var hair_mi := _fps_model.find_child("Vlado_Hair", true, false) as MeshInstance3D
	var rifle_mi := _fps_model.find_child("Rifle_BoltAction", true, false) as MeshInstance3D

	if _fps_skel and body_mi and body_mi.mesh:
		body_mi.mesh = _build_fps_arms_mesh(_fps_skel, body_mi)
		body_mi.layers = 1
		body_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body_mi.extra_cull_margin = 2.0

	if hair_mi:
		hair_mi.visible = false
		hair_mi.layers = 0

	if rifle_mi:
		rifle_mi.layers = 1
		rifle_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rifle_mi.extra_cull_margin = 2.0

	if _fps_skel:
		_wm_idx = _fps_skel.find_bone("WeaponMount")

	_build_fps_muzzle_fx()
	_setup_fps_animation_tree()

func _build_fps_arms_mesh(skel: Skeleton3D, body_mi: MeshInstance3D) -> ArrayMesh:
	var arm_bones: Dictionary = {}
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i)
		if "UpperArm" in bn or "LowerArm" in bn or "Hand" in bn or "Index" in bn or "Middle" in bn or "Ring" in bn or "Little" in bn or "Thumb" in bn:
			arm_bones[i] = true

	var arrs := body_mi.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrs[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrs[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX]
	var new_idx := PackedInt32Array()

	for ti in range(0, idx.size(), 3):
		var keep := true
		var any_arm := false
		for k in 3:
			var vi := idx[ti + k]
			var arm_w := 0.0
			for wi in 4:
				if arm_bones.has(bones[vi * 4 + wi]):
					arm_w += weights[vi * 4 + wi]
			if arm_w >= 0.40:
				any_arm = true
			if arm_w < 0.05:
				keep = false
		if keep and any_arm:
			new_idx.append(idx[ti])
			new_idx.append(idx[ti + 1])
			new_idx.append(idx[ti + 2])

	var new_arrs := arrs.duplicate()
	new_arrs[Mesh.ARRAY_INDEX] = new_idx
	var arm_mesh := ArrayMesh.new()
	arm_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrs)
	var mat: Material = body_mi.mesh.surface_get_material(0)
	if mat:
		arm_mesh.surface_set_material(0, mat)
	return arm_mesh

func _build_fps_muzzle_fx() -> void:
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.name = "FPSMuzzleLight"
	_muzzle_light.layers = 1
	_muzzle_light.light_cull_mask = 1
	_muzzle_light.light_color = Color(1.0, 0.72, 0.34)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 1.8
	_muzzle_light.visible = false
	_rig_root.add_child(_muzzle_light)

	_muzzle_flash_mesh = MeshInstance3D.new()
	_muzzle_flash_mesh.name = "FPSMuzzleFlash"
	_muzzle_flash_mesh.layers = 1
	_muzzle_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.032
	sphere.height = 0.085
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.85, 0.42, 0.92)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.no_depth_test = false
	sphere.material = fmat
	_muzzle_flash_mesh.mesh = sphere
	_muzzle_flash_mesh.visible = false
	_rig_root.add_child(_muzzle_flash_mesh)

func _setup_fps_animation_tree() -> void:
	if not _fps_ap or not ResourceLoader.exists(fps_library_path):
		return
	var fps_lib := load(fps_library_path) as AnimationLibrary
	if not fps_lib:
		return
	if _fps_ap.has_animation_library("vlado_fps"):
		_fps_ap.remove_animation_library("vlado_fps")
	_fps_ap.add_animation_library("vlado_fps", fps_lib)

	_fps_tree = AnimationTree.new()
	_fps_tree.name = "FPSAnimationTree"
	_fps_model.add_child(_fps_tree)

	var sm := AnimationNodeStateMachine.new()
	var clip_names := [
		"FPS_WeaponIdle", "FPS_AimIdle", "FPS_Walk", "FPS_Run", "FPS_Sprint",
		"FPS_Fire", "FPS_Recoil", "FPS_ReloadBolt", "FPS_Equip", "FPS_Holster"
	]
	for cname in clip_names:
		if _fps_ap.has_animation("vlado_fps/" + cname):
			var node := AnimationNodeAnimation.new()
			node.animation = "vlado_fps/" + cname
			sm.add_node(cname, node)

	var tr_start := AnimationNodeStateMachineTransition.new()
	tr_start.xfade_time = 0.0
	tr_start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "FPS_WeaponIdle", tr_start)

	for a in clip_names:
		for b in clip_names:
			if a == b:
				continue
			if not (sm.has_node(a) and sm.has_node(b)):
				continue
			var tr := AnimationNodeStateMachineTransition.new()
			if b == "FPS_Fire":
				tr.xfade_time = 0.02
			elif a == "FPS_Fire" and b == "FPS_Recoil":
				tr.xfade_time = 0.05
			elif b == "FPS_AimIdle" or a == "FPS_AimIdle":
				tr.xfade_time = 0.11
			elif b in ["FPS_Equip", "FPS_Holster", "FPS_ReloadBolt"] or a in ["FPS_Equip", "FPS_Holster", "FPS_ReloadBolt"]:
				tr.xfade_time = 0.09
			elif b == "FPS_Sprint" or a == "FPS_Sprint":
				tr.xfade_time = 0.14
			else:
				tr.xfade_time = 0.14
			sm.add_transition(a, b, tr)

	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Locomotion", sm, Vector2(-240, 80))
	var ts := AnimationNodeTimeScale.new()
	blend_tree.add_node("TimeScale", ts, Vector2(0, 80))
	blend_tree.connect_node("TimeScale", 0, "Locomotion")
	blend_tree.connect_node("output", 0, "TimeScale")

	_fps_tree.tree_root = blend_tree
	_fps_tree.anim_player = _fps_tree.get_path_to(_fps_ap)
	_fps_tree.active = true
	_fps_sm = _fps_tree.get("parameters/Locomotion/playback")
	if _fps_sm:
		_fps_sm.start("FPS_WeaponIdle")

func set_fp_active(fp_visible: bool, hide_tp_body: bool) -> void:
	_fp_active = fp_visible
	if _svp_container:
		_svp_container.visible = fp_visible
	if _sub_viewport:
		_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if fp_visible else SubViewport.UPDATE_DISABLED

	if hide_tp_body != _tp_hidden:
		_tp_hidden = hide_tp_body
		for mi in _tp_meshes:
			if is_instance_valid(mi):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if _tp_hidden else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func is_fp_visible() -> bool:
	return _fp_active

func add_look_sway(delta_px: Vector2) -> void:
	if not _fp_active:
		return
	var sway_scale := 0.00008 if _ads_blend > 0.5 else 0.00018
	_sway_offset.x = clampf(_sway_offset.x - delta_px.x * sway_scale, -0.009, 0.009)
	_sway_offset.y = clampf(_sway_offset.y + delta_px.y * sway_scale, -0.007, 0.007)

func trigger_muzzle_flash() -> void:
	_flash_timer = 0.055
	_recoil_kick_z = 0.016
	if _muzzle_light:
		_muzzle_light.light_energy = 4.2
		_muzzle_light.visible = true
	if _muzzle_flash_mesh:
		_muzzle_flash_mesh.visible = true
		_muzzle_flash_mesh.scale = Vector3(1.0, 1.0, 1.35)
	_update_muzzle_fx_pose()

func get_muzzle_world_position() -> Vector3:
	var local_m := _get_muzzle_rig_local_pos()
	if _camera_rig and _camera_rig.get_camera():
		return _camera_rig.get_camera().global_transform * local_m
	return global_position + Vector3(0.0, 1.65, -0.9)

func _relative_pos_to_holder(holder: Node3D, node: Node3D) -> Vector3:
	var p := Vector3.ZERO
	var cur: Node = node
	while cur != null and cur != holder:
		if cur is Node3D:
			p = (cur as Node3D).transform * p
		cur = cur.get_parent()
	return holder.transform * p


func _get_muzzle_rig_local_pos() -> Vector3:
	if _fps_skel and _wm_idx != -1:
		var wm_pose := _fps_skel.get_bone_global_pose(_wm_idx)
		if _fps_weapon_active != "" and _fps_weapon_models.has(_fps_weapon_active):
			var holder: Node3D = _fps_weapon_models[_fps_weapon_active]
			if is_instance_valid(holder):
				var mz := holder.find_child("Muzzle", true, false) as Node3D
				if mz != null:
					return EYE_OFFSET_IN_SKEL + wm_pose * _relative_pos_to_holder(holder, mz)
		return EYE_OFFSET_IN_SKEL + wm_pose * MUZZLE_LOCAL_ON_WM
	return Vector3(0.08, -0.10, -0.90)

func _update_muzzle_fx_pose() -> void:
	var mp := _get_muzzle_rig_local_pos()
	if _muzzle_light:
		_muzzle_light.position = mp + Vector3(0.0, 0.02, 0.05)
	if _muzzle_flash_mesh:
		_muzzle_flash_mesh.position = mp
		_muzzle_flash_mesh.rotation.z += 0.7

func _resolve_fps_state() -> String:
	if not _controller:
		return "FPS_WeaponIdle"
	var act: String = _controller.weapon_action
	if act == "Equip":
		return "FPS_Equip"
	if act == "Holster":
		return "FPS_Holster"
	if act == "Reload":
		return "FPS_ReloadBolt"
	if act == "Fire":
		return "FPS_Fire"

	# Brief recoil settle right after Fire ends
	if _last_action == "Fire" and act == "":
		return "FPS_Recoil"

	if _controller.is_aiming:
		return "FPS_AimIdle"

	var loco: String = _controller.current_locomotion_state
	var spd: float = _controller.current_horizontal_speed
	if loco == "Sprinting" and spd > 3.6:
		return "FPS_Sprint"
	if loco == "Running" and spd > 2.2:
		return "FPS_Run"
	if (loco in ["Walking", "CrouchWalk"]) and spd > 0.16:
		return "FPS_Walk"
	return "FPS_WeaponIdle"

func _process(delta: float) -> void:
	if not _camera_rig:
		return

	var fp_blend := _camera_rig.get_fp_blend()
	var show_fp := fp_blend >= 0.62
	var hide_tp := fp_blend >= 0.62
	set_fp_active(show_fp, hide_tp)

	if not _fp_active:
		return

	# Sync world camera orientation & world SunLight / TimeOfDayController mood into isolated FPS World3D
	var world_cam := _camera_rig.get_camera()
	if world_cam and _fps_cam:
		_fps_cam.global_transform = world_cam.global_transform
		var aim_b := _camera_rig.get_aim_blend()
		_ads_blend = aim_b
		_fps_cam.fov = lerpf(ready_fov, ads_fov, aim_b)

		var scene_root := get_tree().current_scene
		var world_sun := scene_root.find_child("SunLight", true, false) as DirectionalLight3D if scene_root else null
		if world_sun and _fps_sun:
			_fps_sun.global_transform = world_sun.global_transform
			_fps_sun.light_color = world_sun.light_color
			_fps_sun.light_energy = maxf(0.28, world_sun.light_energy)
			if _fps_fill:
				_fps_fill.light_energy = clampf(0.20 + world_sun.light_energy * 0.24, 0.20, 0.55)
			if _fps_env:
				_fps_env.ambient_light_color = world_sun.light_color.lerp(Color(0.58, 0.66, 0.76), 0.68)
				_fps_env.ambient_light_energy = clampf(0.32 + world_sun.light_energy * 0.38, 0.32, 0.88)

	# Show FPS arms & M48 when equipped OR playing Equip/Holster transition; hide cleanly when holstered!
	var show_weapon := _controller and (_controller.weapon_equipped or _controller.weapon_action in ["Equip", "Holster"])
	if _fps_model:
		_fps_model.visible = show_weapon

	# Decay weapon sway & recoil impulse cleanly (zero idle jitter!)
	_sway_offset = _sway_offset.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
	_recoil_kick_z = lerpf(_recoil_kick_z, 0.0, 1.0 - exp(-16.0 * delta))
	if _rig_root:
		var sway_damp := lerpf(1.0, 0.25, _ads_blend)
		_rig_root.position = Vector3(_sway_offset.x * sway_damp, _sway_offset.y * sway_damp, _recoil_kick_z)

	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		_update_muzzle_fx_pose()
		if _flash_timer <= 0.0:
			if _muzzle_light:
				_muzzle_light.visible = false
				_muzzle_light.light_energy = 0.0
			if _muzzle_flash_mesh:
				_muzzle_flash_mesh.visible = false

	if _fps_sm and show_weapon:
		var target_st := _resolve_fps_state()
		# Allow natural FPS_Recoil tail to settle before snapping back to AimIdle/WeaponIdle
		if target_st == "FPS_Recoil":
			_fps_sm.travel("FPS_Recoil")
			_active_state = "FPS_Recoil"
		elif _active_state == "FPS_Recoil" and _controller.weapon_action == "" and target_st in ["FPS_AimIdle", "FPS_WeaponIdle"]:
			var cur_node := _fps_sm.get_current_node()
			if cur_node == "FPS_Recoil" and _fps_sm.get_current_play_position() < 0.28:
				pass
			else:
				_fps_sm.travel(target_st)
				_active_state = target_st
		elif target_st != _active_state:
			_fps_sm.travel(target_st)
			_active_state = target_st

		var spd := _controller.current_horizontal_speed if _controller else 0.0
		var ts_val := 1.0
		match _active_state:
			"FPS_Walk":
				ts_val = clampf(spd / FPS_WALK_REF, 0.65, 1.35)
			"FPS_Run":
				ts_val = clampf(spd / FPS_RUN_REF, 0.72, 1.25)
			"FPS_Sprint":
				ts_val = clampf(spd / FPS_SPRINT_REF, 0.80, 1.20)
			_:
				ts_val = 1.0
		_fps_tree.set("parameters/TimeScale/scale", ts_val)

	if _controller:
		_last_action = _controller.weapon_action

func get_active_animation() -> String:
	return _active_state

# ============================================================================
# STAGE 3.3 — FPS weapon mounting
# ----------------------------------------------------------------------------
# The first-person rig renders through its own SubViewport with its own copy of
# Vlado, which already carries the skinned M48 mesh ("Rifle_BoltAction"). The
# captured weapons are separate GLBs, so they need their own attachment on this
# rig's WeaponMount bone. Nothing above this block is modified: the addon only
# adds a second attachment and a visibility switch.
# ============================================================================
var _fps_weapon_attach: BoneAttachment3D
var _fps_weapon_models: Dictionary = {}   # weapon id -> Node3D
var _fps_weapon_active: String = ""


## Attaches a weapon model to the FPS skeleton so it renders inside the
## first-person SubViewport. `scaled` is the already-normalised model whose
## origin sits on its centre.
func fp_mount_weapon(weapon_id: String, model: Node3D, rot_deg: Vector3, offset: Vector3) -> bool:
	if _fps_skel == null:
		return false
	if _fps_weapon_attach == null:
		if _wm_idx < 0:
			_wm_idx = _fps_skel.find_bone("WeaponMount")
		if _wm_idx < 0:
			push_warning("Stage33: FPS skeleton has no WeaponMount bone")
			return false
		_fps_weapon_attach = BoneAttachment3D.new()
		_fps_weapon_attach.name = "FPSWeaponAttach"
		_fps_weapon_attach.bone_name = _fps_skel.get_bone_name(_wm_idx)
		_fps_skel.add_child(_fps_weapon_attach)

	if _fps_weapon_models.has(weapon_id):
		var old: Node3D = _fps_weapon_models[weapon_id]
		if is_instance_valid(old):
			old.queue_free()
	var holder := Node3D.new()
	holder.name = "FPSGun_" + weapon_id
	holder.rotation_degrees = rot_deg
	holder.position = offset
	# FPS copies are pulled slightly closer to the lens than the TPS scale
	holder.scale = Vector3(0.86, 0.86, 0.86)
	_fps_weapon_attach.add_child(holder)
	holder.add_child(model)
	_fps_weapon_models[weapon_id] = holder
	holder.visible = (weapon_id == _fps_weapon_active)
	return true


## Shows exactly one FPS weapon. Pass "" to leave only the skinned M48.
func fp_show_weapon(weapon_id: String) -> void:
	_fps_weapon_active = weapon_id
	for k in _fps_weapon_models.keys():
		var n: Node3D = _fps_weapon_models[k]
		if is_instance_valid(n):
			n.visible = (k == weapon_id)
	# the M48 is part of Vlado's GLB; hide it while a captured gun is out
	_set_fp_rifle_visible(weapon_id == "")


func _set_fp_rifle_visible(v: bool) -> void:
	if _fps_model == null:
		return
	var rifle := _fps_model.find_child("Rifle_BoltAction", true, false) as MeshInstance3D
	if rifle:
		rifle.visible = v


## Debug-only: nudges the FPS holder for the active weapon so one export can
## test several orientations. Used by tools/fps_orient.js.
func fp_debug_rot(extra: Vector3) -> void:
	var id := _fps_weapon_active
	if id == "" or not _fps_weapon_models.has(id):
		return
	var h: Node3D = _fps_weapon_models[id]
	if is_instance_valid(h):
		h.rotation_degrees += extra
		print("[Stage33] fps holder rot = %s" % str(h.rotation_degrees))


## Debug-only: sets the FPS holder to an absolute rotation (used by the
## on-screen ROT button so orientation can be calibrated on a phone).
func fp_set_rot(rot_deg: Vector3) -> void:
	var id := _fps_weapon_active
	if id == "" or not _fps_weapon_models.has(id):
		return
	var h: Node3D = _fps_weapon_models[id]
	if is_instance_valid(h):
		h.rotation_degrees = rot_deg
		print("[Stage33] fps rot -> %s" % str(rot_deg))


func fp_debug_state() -> String:
	var id := _fps_weapon_active
	if id == "" or not _fps_weapon_models.has(id):
		return "none"
	var h: Node3D = _fps_weapon_models[id]
	if not is_instance_valid(h):
		return "gone"
	return "%s rot=%s pos=%s scale=%s vis=%s" % [id, str(h.rotation_degrees), str(h.position), str(h.scale), str(h.visible)]


func fp_active_weapon() -> String:
	return _fps_weapon_active


func fp_has_rig() -> bool:
	return _fps_skel != null
