extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main/montenegro_world.tscn"
const VladoRigCompat = preload("res://characters/vlado/vlado_rig_compat.gd")
const REQUIRED_NATIVE_CLIPS: Array[String] = [
	"idle",
	"idle_rifle",
	"run",
	"run_rifle",
	"jump",
	"jump_in_place",
	"jump_rifle",
	"jump_rifle_in_place",
]
const STRUCTURAL_STATE_CLIPS: Dictionary = {
	"Idle": "idle",
	"Walking": "run",
	"Running": "run",
	"Sprinting": "run",
	"CrouchIdle": "idle",
	"CrouchWalk": "run",
	"Jumping": "jump_in_place",
	"Landing": "jump_in_place",
	"RifleIdle": "idle_rifle",
	"RifleWalk": "run_rifle",
	"RifleRun": "run_rifle",
	"HeavyIdle": "idle_rifle",
	"HeavyWalk": "run_rifle",
	"ArmedJump": "jump_rifle_in_place",
}

var bad := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, condition: bool, details: String) -> void:
	print("NATIVE_ANIMATION_TEST %s ok=%s %s" % [label, condition, details])
	if not condition:
		bad += 1

func _frames(count: int) -> void:
	for _i in count:
		await process_frame

func _clip_for_state(state_machine: AnimationNodeStateMachine, state_name: String) -> String:
	if not state_machine.has_node(state_name):
		return ""
	var node := state_machine.get_node(state_name) as AnimationNodeAnimation
	if node == null:
		return ""
	return String(node.animation).get_file()

func _scenario(
	label: String,
	controller_state: String,
	hold_style: String,
	weapon_equipped: bool,
	speed: float,
	expected_state: String,
	expected_clip: String,
	expected_scale: float,
	controller: PlayerController,
	animator: PlayerAnimator,
	animation_tree: AnimationTree,
	state_machine: AnimationNodeStateMachine,
	playback: AnimationNodeStateMachinePlayback
) -> void:
	controller.current_locomotion_state = controller_state
	controller.weapon_equipped = weapon_equipped
	controller.weapon_action = ""
	controller.is_aiming = false
	controller.current_horizontal_speed = speed
	animator.set_weapon_hold_profile(hold_style)

	await _frames(8)
	var resolved_state := animator.get_active_animation()
	var actual_state := String(playback.get_current_node())
	var actual_clip := _clip_for_state(state_machine, actual_state)
	var time_before := playback.get_current_play_position()
	var actual_scale := float(animation_tree.get("parameters/TimeScale/scale"))
	await _frames(6)
	var time_after := playback.get_current_play_position()
	var time_advances := not is_equal_approx(time_before, time_after)
	var ok := (
		resolved_state == expected_state
		and actual_state == expected_state
		and actual_clip == expected_clip
		and is_equal_approx(actual_scale, expected_scale)
		and time_advances
	)
	print(
		"CONTROLLER_STATE=%s HOLD_STYLE=%s WEAPON_EQUIPPED=%s RESOLVED_STATE=%s ACTUAL_CLIP=%s TIME_BEFORE=%.4f TIME_AFTER=%.4f TIME_SCALE=%.3f OK=%s"
		% [
			controller_state,
			hold_style,
			weapon_equipped,
			resolved_state,
			actual_clip,
			time_before,
			time_after,
			actual_scale,
			ok,
		]
	)
	_check("%s_scenario" % label, ok, "expected=%s -> %s scale=%.3f" % [expected_state, expected_clip, expected_scale])

func _run() -> void:
	var main_packed := load(MAIN_SCENE_PATH) as PackedScene
	if main_packed == null:
		push_error("Could not load active main scene: " + MAIN_SCENE_PATH)
		quit(1)
		return
	var scene_change_error := change_scene_to_packed(main_packed)
	if scene_change_error != OK:
		push_error("Could not change to active main scene, error=%d" % scene_change_error)
		quit(1)
		return
	await _frames(30)

	var main_scene := current_scene
	if main_scene == null or main_scene.scene_file_path != MAIN_SCENE_PATH:
		push_error("SceneTree.current_scene was not set to the active main scene")
		quit(1)
		return
	var player := main_scene.get_node_or_null("VladoPlayer") as PlayerController
	if player == null:
		push_error("VladoPlayer is missing or is not a PlayerController")
		quit(1)
		return
	player.set_physics_process(false)
	var weapon_controller := player.get_node_or_null("WeaponController")
	if weapon_controller:
		weapon_controller.set_process(false)

	var model := player.find_child("VladoModel", true, false)
	var animation_player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer if model else null
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D if model else null
	var animator := player.get_node_or_null("PlayerAnimator") as PlayerAnimator
	var animation_tree := animator.get_node_or_null("LocomotionTree") as AnimationTree if animator else null
	var playback := animation_tree.get("parameters/Locomotion/playback") as AnimationNodeStateMachinePlayback if animation_tree else null
	var state_machine := animation_tree.tree_root.get_node("Locomotion") as AnimationNodeStateMachine if animation_tree else null
	var fps_rig := player.get_node_or_null("FirstPersonRig") as FirstPersonRig
	if (
		animation_player == null
		or skeleton == null
		or animator == null
		or animation_tree == null
		or playback == null
		or state_machine == null
		or fps_rig == null
	):
		push_error("Player is missing model, AnimationPlayer, Skeleton3D, AnimationTree, playback, or first-person rig")
		quit(1)
		return

	_check("current_scene", current_scene == main_scene, "path=%s" % current_scene.scene_file_path)
	_check("player_prefab", player.scene_file_path == "res://characters/vlado/vlado_character.tscn", "path=%s" % player.scene_file_path)
	_check("original_skeleton", skeleton.get_bone_count() == 44, "bones=%d" % skeleton.get_bone_count())
	_check("animation_tree_active", animation_tree.active, "active=%s" % animation_tree.active)

	var native_names: Array[String] = []
	for animation_name in animation_player.get_animation_list():
		native_names.append(String(animation_name).get_file())
	native_names.sort()
	var expected_names := REQUIRED_NATIVE_CLIPS.duplicate()
	expected_names.sort()
	_check(
		"exactly_eight_native_clips",
		native_names.size() == 8 and native_names == expected_names,
		"clips=%s" % ",".join(native_names)
	)

	for state_name in STRUCTURAL_STATE_CLIPS:
		var actual_clip := _clip_for_state(state_machine, state_name)
		var expected_clip: String = STRUCTURAL_STATE_CLIPS[state_name]
		var ok := actual_clip == expected_clip and animation_player.has_animation(actual_clip)
		print("STRUCTURE %s -> %s OK=%s" % [state_name, actual_clip, ok])
		_check("structure_%s" % state_name, ok, "expected=%s" % expected_clip)

	print("Crouch: MISSING_CUSTOM_ANIMATION")
	print("Pistol: MISSING_CUSTOM_ANIMATION")
	print("Grenade: MISSING_CUSTOM_ANIMATION")
	print("Melee: MISSING_CUSTOM_ANIMATION")
	print("Hit/Death/Roll: MISSING_CUSTOM_ANIMATION")

	var third_person_rifle := model.find_child("Rifle_Prop", true, false) as MeshInstance3D
	var third_person_skeleton := skeleton
	var original_rifle_mesh: Mesh = third_person_rifle.mesh if third_person_rifle else null
	var original_rifle_parent: Node = third_person_rifle.get_parent() if third_person_rifle else null
	var original_rifle_transform: Transform3D = third_person_rifle.transform if third_person_rifle else Transform3D.IDENTITY
	var original_rifle_skin: Skin = third_person_rifle.skin if third_person_rifle else null

	var fp_skeleton := fps_rig.get("_fps_skel") as Skeleton3D
	var weapon_socket_index := VladoRigCompat.weapon_socket_index(skeleton)
	_check(
		"original_weapon_socket",
		weapon_socket_index >= 0 and skeleton.get_bone_name(weapon_socket_index) == "WeaponSocket",
		"bone=%s" % (skeleton.get_bone_name(weapon_socket_index) if weapon_socket_index >= 0 else "<missing>")
	)

	var arsenal := player.get_node_or_null("WeaponArsenal") as WeaponArsenal
	_check("third_person_arsenal_present", arsenal != null, "arsenal=%s" % str(arsenal))
	if arsenal:
		arsenal.call("_mount_root_for_weapon")
	await process_frame
	var tp_mount := skeleton.get_node_or_null("RightHandWeaponSocket") as BoneAttachment3D
	var tp_mount_root := arsenal.get("_mount_root") as Node3D if arsenal else null
	_check(
		"third_person_hand_socket",
		tp_mount != null
		and tp_mount.bone_name == &"Hand.R"
		and tp_mount_root != null
		and tp_mount_root.get_parent() == tp_mount,
		"bone=%s mount_parent=%s"
		% [
			String(tp_mount.bone_name) if tp_mount else "<missing>",
			str(tp_mount_root.get_parent()) if tp_mount_root else "<missing>",
		]
	)

	var audit_weapon := Node3D.new()
	var fps_mount_ok := fps_rig.fp_mount_weapon(
		"native_mapping_test",
		audit_weapon,
		Vector3.ZERO,
		Vector3.ZERO
	)
	var fps_mount := fps_rig.get("_fps_weapon_attach") as BoneAttachment3D
	_check(
		"first_person_socket_no_warning",
		fps_mount_ok and fps_mount != null and fps_mount.bone_name == &"WeaponSocket",
		"mount_ok=%s bone=%s" % [fps_mount_ok, String(fps_mount.bone_name) if fps_mount else "<missing>"]
	)
	_check(
		"fps_and_third_person_mounts_separate",
		tp_mount != null
		and fps_mount != null
		and tp_mount != fps_mount
		and tp_mount.get_parent() == third_person_skeleton
		and fps_mount.get_parent() == fp_skeleton
		and third_person_skeleton != fp_skeleton,
		"tp_mount=%s fps_mount=%s separate_skeletons=%s"
		% [str(tp_mount), str(fps_mount), third_person_skeleton != fp_skeleton]
	)

	var walk_scale := clampf(player.walk_speed / 1.25, 0.55, 1.60)
	var run_scale := clampf(player.run_speed / 3.75, 0.62, 1.45)
	var sprint_scale := clampf(player.sprint_speed / 6.40, 0.70, 1.35)
	await _scenario("idle", "Idle", "pistol", false, 0.0, "Idle", "idle", 1.0, player, animator, animation_tree, state_machine, playback)
	await _scenario("walk", "Walking", "pistol", false, player.walk_speed, "Walking", "run", walk_scale, player, animator, animation_tree, state_machine, playback)
	await _scenario("run", "Running", "pistol", false, player.run_speed, "Running", "run", run_scale, player, animator, animation_tree, state_machine, playback)
	await _scenario("sprint", "Sprinting", "pistol", false, player.sprint_speed, "Sprinting", "run", sprint_scale, player, animator, animation_tree, state_machine, playback)
	await _scenario("unarmed_jump", "Jumping", "pistol", false, 0.0, "Jumping", "jump_in_place", 1.0, player, animator, animation_tree, state_machine, playback)
	await _scenario("rifle_idle", "Idle", "rifle", true, 0.0, "RifleIdle", "idle_rifle", 1.0, player, animator, animation_tree, state_machine, playback)
	await _scenario("rifle_walk", "Walking", "rifle", true, player.walk_speed, "RifleWalk", "run_rifle", walk_scale, player, animator, animation_tree, state_machine, playback)
	await _scenario("rifle_run", "Running", "rifle", true, player.run_speed, "RifleRun", "run_rifle", run_scale, player, animator, animation_tree, state_machine, playback)
	await _scenario("armed_jump_start", "JumpStart", "rifle", true, 0.0, "ArmedJump", "jump_rifle_in_place", 1.0, player, animator, animation_tree, state_machine, playback)
	await _scenario("armed_jump_air", "Jumping", "rifle", true, 0.0, "ArmedJump", "jump_rifle_in_place", 1.0, player, animator, animation_tree, state_machine, playback)

	var rifle_unchanged := (
		third_person_rifle != null
		and third_person_rifle.mesh == original_rifle_mesh
		and third_person_rifle.get_parent() == original_rifle_parent
		and third_person_rifle.transform == original_rifle_transform
		and third_person_rifle.skin == original_rifle_skin
	)
	_check("third_person_rifle_prop_unchanged", rifle_unchanged, "mesh_parent_transform_skin_preserved=%s" % rifle_unchanged)

	var test_holder := (fps_rig.get("_fps_weapon_models") as Dictionary).get("native_mapping_test") as Node3D
	if is_instance_valid(test_holder):
		(fps_rig.get("_fps_weapon_models") as Dictionary).erase("native_mapping_test")
		test_holder.free()
	fps_rig.set("_fps_weapon_active", "")
	if animation_tree:
		animation_tree.active = false
	var fps_tree := fps_rig.get("_fps_tree") as AnimationTree
	if fps_tree:
		fps_tree.active = false
	if animation_player:
		animation_player.stop()
	main_scene.process_mode = Node.PROCESS_MODE_DISABLED
	main_scene.queue_free()
	await process_frame
	await process_frame

	print("NATIVE_ANIMATION_MAPPING_DONE bad=%d" % bad)
	quit(0 if bad == 0 else 1)
