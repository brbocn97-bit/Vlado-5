from pathlib import Path
R=Path('/tmp/vlado_rebuild/Vlado5/vlado_stage33')
def rep(p,a,b):
 s=p.read_text();assert a in s,(p,a[:80]);p.write_text(s.replace(a,b,1))
# scene uses new GLB
p=R/'characters/vlado/vlado_character.tscn';rep(p,'[ext_resource type="PackedScene" uid="uid://c3u2q1o1wqfpa" path="res://assets/characters/vlado/Vlado_Sipcic_Final.glb" id="2_vlado"]','[ext_resource type="PackedScene" path="res://assets/characters/vlado/Vlado_Sipcic_ReRigged.glb" id="2_vlado"]')
p=R/'player/player_animator.gd'
rep(p,'@export var locomotion_library_path: String = "res://animations/vlado_locomotion.tres"','@export var locomotion_library_path: String = ""')
rep(p,'const VladoWeaponIK := preload("res://player/vlado_weapon_ik.gd")\n\nvar _smoothed_bank_rad: float = 0.0','var _active_hold_style: String = "pistol"\nvar _weapon_mount_node: Node3D = null\n\nvar _smoothed_bank_rad: float = 0.0')
rep(p,'var _ik_mod: VladoWeaponIKModifier = null','var _ik_mod: Node = null')
rep(p,'\tif _anim_player and _skel:\n\t\t_load_locomotion_library()\n\t\t_cache_skeleton_indices()\n\t\t_skel.skeleton_updated.connect(_on_skeleton_updated)\n\t\t_ik_mod = VladoWeaponIK.new()\n\t\t_ik_mod.name = "VladoWeaponIKModifier"\n\t\t_ik_mod.controller = _controller\n\t\t_ik_mod.animator = self\n\t\t_skel.add_child(_ik_mod)\n\tif _anim_player:','\tif _anim_player and _skel:\n\t\t_cache_skeleton_indices()\n\tif _anim_player:')
a='''\tvar use_loco := _anim_player.has_animation_library("vlado_loco")
\tvar pfx := "vlado_loco/" if use_loco else ""

\tvar sm := AnimationNodeStateMachine.new()
\tvar state_to_clip := {
\t\t"Idle": pfx + "Idle",
\t\t"Walking": pfx + "Walking",
\t\t"Running": pfx + "Running",
\t\t"Sprinting": pfx + "Sprinting",
\t\t"CrouchIdle": pfx + "CrouchIdle" if use_loco else "Crouching",
\t\t"CrouchWalk": pfx + "CrouchWalk" if use_loco else "Walking",
\t\t"JumpStart": pfx + "JumpStart" if use_loco else "Jumping",
\t\t"Jumping": pfx + "JumpAir" if use_loco else "Jumping",
\t\t"Landing": pfx + "Landing",
\t}
\tif use_loco:
\t\tfor combat_st in [
\t\t\t"RifleReadyIdle", "RifleReadyWalk",
\t\t\t"AimIdle", "AimWalk", "AimCrouchIdle", "AimCrouchWalk",
\t\t\t"EquipRifle", "HolsterRifle", "FireRecoil", "ReloadBolt"
\t\t]:
\t\t\tif _anim_player.has_animation(pfx + combat_st):
\t\t\t\tstate_to_clip[combat_st] = pfx + combat_st'''
b='''\tvar sm := AnimationNodeStateMachine.new()
\tvar state_to_clip := {"Idle":"Idle","Walking":"Walking","Running":"Running","Sprinting":"Sprinting","CrouchIdle":"CrouchIdle","CrouchWalk":"Crouching","JumpStart":"JumpStart","Jumping":"Jumping","Landing":"Landing"}
\tfor combat_st in ["PistolIdle","PistolAim","PistolFire","PistolReload","PistolWalk","PistolRun","PistolEquip","PistolHolster","RifleIdle","RifleAim","RifleWalk","RifleRun","HeavyIdle","HeavyWalk","RifleEquip","RifleHolster","RifleFire","HeavyFire","RifleReload"]:
\t\tif _anim_player.has_animation(combat_st): state_to_clip[combat_st] = combat_st''';rep(p,a,b)
rep(p,'\tvar combat_states := ["RifleReadyIdle", "RifleReadyWalk", "AimIdle", "AimWalk", "AimCrouchIdle", "AimCrouchWalk", "EquipRifle", "HolsterRifle", "FireRecoil", "ReloadBolt"]','\tvar combat_states := ["PistolIdle","PistolAim","PistolFire","PistolReload","PistolWalk","PistolRun","PistolEquip","PistolHolster","RifleIdle","RifleAim","RifleWalk","RifleRun","HeavyIdle","HeavyWalk","RifleEquip","RifleHolster","RifleFire","HeavyFire","RifleReload"]')
a='''\tvar act: String = _controller.weapon_action
\tif act == "Equip" and _anim_player.has_animation("vlado_loco/EquipRifle"):
\t\treturn "EquipRifle"
\tif act == "Holster" and _anim_player.has_animation("vlado_loco/HolsterRifle"):
\t\treturn "HolsterRifle"
\tif act == "Reload" and _anim_player.has_animation("vlado_loco/ReloadBolt"):
\t\treturn "ReloadBolt"
\tif act == "Fire" and _anim_player.has_animation("vlado_loco/FireRecoil"):
\t\treturn "FireRecoil"

\tif _controller.is_aiming and _anim_player.has_animation("vlado_loco/AimIdle"):
\t\tif _controller.is_crouch_active():
\t\t\treturn "AimCrouchIdle" if _controller.current_horizontal_speed < 0.14 else "AimCrouchWalk"
\t\treturn "AimIdle" if _controller.current_horizontal_speed < 0.14 else "AimWalk"

\tif _controller.weapon_equipped and _anim_player.has_animation("vlado_loco/RifleReadyIdle"):
\t\tif _controller.is_crouch_active():
\t\t\treturn "AimCrouchIdle" if _controller.current_horizontal_speed < 0.14 else "AimCrouchWalk"
\t\treturn "RifleReadyIdle" if _controller.current_horizontal_speed < 0.14 else "RifleReadyWalk"'''
b='''\tvar act: String = _controller.weapon_action
\tvar speed := _controller.current_horizontal_speed
\tif _controller.weapon_equipped:
\t\tif _active_hold_style == "pistol":
\t\t\tif act == "Equip": return "PistolEquip"
\t\t\tif act == "Holster": return "PistolHolster"
\t\t\tif act == "Reload": return "PistolReload"
\t\t\tif act == "Fire": return "PistolFire"
\t\t\tif _controller.is_aiming: return "PistolAim"
\t\t\tif speed < 0.14: return "PistolIdle"
\t\t\treturn "PistolWalk" if speed < 2.2 else "PistolRun"
\t\tif _active_hold_style in ["rifle", "heavy", "m48"]:
\t\t\tif act == "Equip": return "RifleEquip"
\t\t\tif act == "Holster": return "RifleHolster"
\t\t\tif act == "Reload": return "RifleReload"
\t\t\tif act == "Fire": return "HeavyFire" if _active_hold_style == "heavy" else "RifleFire"
\t\t\tif _controller.is_aiming: return "RifleAim"
\t\t\tif _active_hold_style == "heavy": return "HeavyIdle" if speed < 0.14 else "HeavyWalk"
\t\t\tif speed < 0.14: return "RifleIdle"
\t\t\treturn "RifleWalk" if speed < 2.6 else "RifleRun"''';rep(p,a,b)
rep(p,'\t\t"RifleReadyWalk":\n\t\t\tscale = clampf(speed / WALK_REF_SPEED, 0.58, 1.55)\n\t\t"Running":','\t\t"PistolWalk", "RifleWalk", "HeavyWalk":\n\t\t\tscale = clampf(speed / WALK_REF_SPEED, 0.58, 1.55)\n\t\t"PistolRun", "RifleRun":\n\t\t\tscale = clampf(speed / RUN_REF_SPEED, 0.62, 1.45)\n\t\t"Running":')
a='''func set_weapon_hold_profile(hold_style: String, grip_l_local: Vector3 = Vector3(0.0, 0.02, -0.26)) -> void:
\tif _ik_mod != null:
\t\t_ik_mod.active_hold_style = hold_style
\t\t_ik_mod.active_grip_l_local = grip_l_local


func set_weapon_mount_node(node: Node3D) -> void:
\tif _ik_mod != null:
\t\t_ik_mod.weapon_mount_node = node


func get_weapon_ik_modifier() -> VladoWeaponIKModifier:
\treturn _ik_mod'''
b='''func set_weapon_hold_profile(hold_style: String, _grip_l_local: Vector3 = Vector3(0.0, 0.02, -0.26)) -> void:
\t_active_hold_style = hold_style
func set_weapon_mount_node(node: Node3D) -> void:
\t_weapon_mount_node = node
func get_weapon_ik_modifier() -> Node:
\treturn null''';rep(p,a,b)
# Arsenal real hand socket
p=R/'stage33/weapon_arsenal.gd'
a='''\t_mount_root = Node3D.new()
\t_mount_root.name = "Stage33WeaponMount"
\tif _skel:
\t\t_skel.add_child(_mount_root)
\t\tvar anim := _animator_ref()
\t\tif anim:
\t\t\tanim.set_weapon_mount_node(_mount_root)
\telif player:
\t\tplayer.add_child(_mount_root)'''
b='''\t_mount_root = Node3D.new()
\t_mount_root.name = "Stage33WeaponMount"
\tif _skel:
\t\tvar socket := _skel.get_node_or_null("RightHandWeaponSocket") as BoneAttachment3D
\t\tif socket == null:
\t\t\tsocket = BoneAttachment3D.new(); socket.name = "RightHandWeaponSocket"; socket.bone_name = &"RightHand"; _skel.add_child(socket)
\t\tsocket.add_child(_mount_root)
\t\tvar anim := _animator_ref()
\t\tif anim: anim.set_weapon_mount_node(_mount_root)
\telif player: player.add_child(_mount_root)''';rep(p,a,b)
rep(p,'func _load_model_for(def: WeaponDef) -> Node3D:','''func _configure_mount_for_style(style: String) -> void:
\tvar mount := _mount_root_for_weapon(); mount.position = Vector3.ZERO
\tmatch style:
\t\t"pistol": mount.rotation_degrees = Vector3(21.559, -118.542, -88.847)
\t\t"rifle", "heavy":
\t\t\tmount.position = Vector3(-0.015974, 0.041719, -0.050044)
\t\t\tmount.rotation_degrees = Vector3(77.787, -176.465, 167.626)
\t\t"grenade", "melee": mount.rotation_degrees = Vector3(21.559, -118.542, -88.847)
\t\t_: mount.rotation_degrees = Vector3.ZERO

func _load_model_for(def: WeaponDef) -> Node3D:''')
rep(p,'\t\tanim.set_weapon_hold_profile(def.hold_style, gl_local)\n\n\tif slot == SLOT_M48:','\t\tanim.set_weapon_hold_profile(def.hold_style, gl_local)\n\t_configure_mount_for_style(def.hold_style)\n\n\tif slot == SLOT_M48:')
# remove legacy active assets after backup exists in source Drive ZIP
for x in ['player/vlado_weapon_ik.gd','player/vlado_weapon_ik.gd.uid','animations/vlado_locomotion.tres','animations/vlado_locomotion_PROCEDURAL.tres.bak']:
 q=R/x
 if q.exists():q.unlink()
print('PHASE3_PATCH_APPLIED')
