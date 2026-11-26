extends SceneTree

const REQUIRED_BONES := ["Root","Hips","Spine","Chest","UpperChest","Neck","Head","LeftShoulder","LeftUpperArm","LeftLowerArm","LeftHand","RightShoulder","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","LeftToes","RightUpperLeg","RightLowerLeg","RightFoot","RightToes","WeaponMount"]
const REQUIRED_ANIMS := ["Idle","Walking","Running","Sprinting","Crouching","Jumping","RifleIdle","RifleAim","RifleFire","RifleReload","PistolIdle","PistolAim","PistolFire","GrenadeThrow","MeleeAttack"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://assets/characters/vlado/vlado_sipcic.glb")
	var model: Node = scene.instantiate()
	root.add_child(model)
	await process_frame
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var bad := 0
	if skel == null or ap == null:
		print("PHASE9_RIG_FATAL skeleton=%s animation_player=%s" % [skel != null, ap != null])
		quit(1); return
	for bone_name in REQUIRED_BONES:
		if skel.find_bone(bone_name) < 0:
			bad += 1
			print("PHASE9_RIG_MISSING_BONE " + bone_name)
	for anim_name in REQUIRED_ANIMS:
		if not ap.has_animation(anim_name):
			bad += 1
			print("PHASE9_RIG_MISSING_ANIM " + anim_name)
	var symmetry_pairs := [["LeftUpperArm","RightUpperArm"],["LeftLowerArm","RightLowerArm"],["LeftUpperLeg","RightUpperLeg"],["LeftLowerLeg","RightLowerLeg"],["LeftFoot","RightFoot"]]
	for pair in symmetry_pairs:
		var li := skel.find_bone(pair[0])
		var ri := skel.find_bone(pair[1])
		var ll := skel.get_bone_rest(li).origin.length()
		var rl := skel.get_bone_rest(ri).origin.length()
		var ok := absf(ll-rl) < 0.002
		print("PHASE9_RIG_SYMMETRY pair=%s/%s left=%.4f right=%.4f ok=%s" % [pair[0],pair[1],ll,rl,ok])
		if not ok: bad += 1
	print("PHASE9_RIG_DONE bones=%d animations=%d bad=%d" % [skel.get_bone_count(),ap.get_animation_list().size(),bad])
	quit(0 if bad == 0 else 1)
