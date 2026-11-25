class_name WeaponArsenal
extends Node
## WeaponArsenal — Stage 3.3 / 3.4 WW1-WW2 Yugoslav & Balkan Historical Arsenal.
##
## Vlado's primary starting weapon is Crnogorski Gaser M1870/74 (SLOT_GASSER = 3),
## while his Zastava M48 rifle (SLOT_M48 = 0) stays slung on his back and remains
## 100% compatible with Stage 3.2 WeaponController and Stage 4 mission slots
## (SLOT_MP40 = 1, SLOT_MG42 = 2).

signal weapon_changed(def: WeaponDef)
signal arsenal_ready()
signal shot_fired()
signal target_hit(is_target: bool, distance_m: float, total_hits: int)

const SLOT_M48 := 0
const SLOT_MP40 := 1
const SLOT_MG42 := 2
const SLOT_GASSER := 3

const MODEL_DIR := "res://assets/weapons/Models/"
const RECOVERED_DIR := "res://assets/weapons/Recovered/"

var player: PlayerController
var camera_rig: PlayerCamera
var animator: PlayerAnimator
var fps_rig: FirstPersonRig
var weapons: Array[WeaponDef] = []
var held: Dictionary = {}          # slot -> Node3D wrapper
var active: int = SLOT_GASSER
var owned: Array[int] = [SLOT_GASSER, SLOT_M48]

var _sound: SoundManager
var _fire_timer := 0.0
var _swap_timer := 0.0
var _swapping := false
var _reload_timer := 0.0
var _reloading := false
var _recoil_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _ammo: Dictionary = {}          # slot -> [mag, reserve]
var _mount_root: Node3D
var _skel: Skeleton3D
var _fps_mounted: Dictionary = {}   # weapon id -> bool
var _hit_targets: Dictionary = {}
var _grenades: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("arsenal")
	add_to_group("stage33_arsenal")
	_rng.seed = 5150
	_setup_defs()
	player = get_parent() as PlayerController
	if player:
		camera_rig = player.get_node_or_null("CameraRig") as PlayerCamera
		animator = player.get_node_or_null("PlayerAnimator") as PlayerAnimator
		fps_rig = player.find_child("FirstPersonRig", true, false) as FirstPersonRig
	await get_tree().process_frame
	if player:
		_skel = player.find_child("Skeleton3D", true, false) as Skeleton3D
		if animator == null:
			animator = player.get_node_or_null("PlayerAnimator") as PlayerAnimator
	_sound = get_tree().root.find_child("SoundManager", true, false) as SoundManager
	_mount_root_for_weapon()
	arsenal_ready.emit()


# --------------------------------------------------------------------- defs
func _setup_defs() -> void:
	weapons = [
		# 0: Zastava M48 (skinned in Vlado_Sipcic_Final.glb, kept on back when Gasser/others active)
		WeaponDef.new({
			"id": "m48", "display_name": "Zastava M48", "category": "Puške repetirke", "caliber": "7.92x57mm",
			"slot": SLOT_M48, "model_path": "", "hold_style": "m48",
			"mag_capacity": 5, "starting_reserve": 30, "reserve_max": 60,
			"fire_cooldown": 0.74, "reload_duration": 1.45,
			"automatic": false, "pellets": 1,
			"aim_spread_deg": 0.25, "hip_spread_deg": 2.1,
			"recoil_pitch": 1.7, "recoil_yaw": 0.45,
			"max_range_m": 220.0, "damage": 120.0, "sound_key": "rifle",
			"target_length_m": 1.10,
		}),
		# 1: MP40 (Stage 4 Mission Target 1 — cleaned Sketchfab model)
		WeaponDef.new({
			"id": "mp40", "display_name": "MP 40", "category": "Automati", "caliber": "9x19mm",
			"slot": SLOT_MP40, "model_path": MODEL_DIR + "mp40.glb", "hold_style": "rifle",
			"is_sketchfab": true, "target_length_m": 0.83,
			"sketchfab_grip_raw": Vector3(0.0, -0.02, 0.40),
			"sketchfab_muzzle_local": Vector3(0.0, 0.068, -0.57),
			"sketchfab_grip_l_local": Vector3(0.0, 0.022, -0.24),
			"sketchfab_eject_local": Vector3(0.025, 0.068, -0.10),
			"sketchfab_sight_local": Vector3(0.0, 0.095, -0.02),
			"mag_capacity": 32, "starting_reserve": 96, "reserve_max": 320,
			"fire_cooldown": 0.11, "reload_duration": 2.05,
			"automatic": true, "pellets": 1,
			"aim_spread_deg": 1.25, "hip_spread_deg": 2.9,
			"recoil_pitch": 0.58, "recoil_yaw": 0.28,
			"max_range_m": 95.0, "damage": 34.0, "sound_key": "smg",
			"fps_rot_deg": Vector3(90, 0, 0), "fps_offset": Vector3(0.0, -0.12, -0.045),
		}),
		# 2: MG42 (Stage 4 Mission Target 2 — cleaned Sketchfab model)
		WeaponDef.new({
			"id": "mg42", "display_name": "MG 42", "category": "Mitraljezi", "caliber": "7.92x57mm",
			"slot": SLOT_MG42, "model_path": MODEL_DIR + "maschinengewehr_mg_42.glb", "hold_style": "heavy",
			"is_sketchfab": true, "target_length_m": 1.22,
			"sketchfab_grip_raw": Vector3(-0.107, 0.09, -0.18),
			"sketchfab_muzzle_local": Vector3(0.0, 0.075, -0.88),
			"sketchfab_grip_l_local": Vector3(-0.02, 0.03, -0.36),
			"sketchfab_eject_local": Vector3(0.035, 0.08, -0.22),
			"sketchfab_sight_local": Vector3(0.0, 0.14, -0.10),
			"mag_capacity": 50, "starting_reserve": 150, "reserve_max": 350,
			"fire_cooldown": 0.055, "reload_duration": 3.1,
			"automatic": true, "pellets": 1,
			"aim_spread_deg": 1.75, "hip_spread_deg": 4.8,
			"recoil_pitch": 0.95, "recoil_yaw": 0.48,
			"max_range_m": 260.0, "damage": 44.0, "sound_key": "mg",
			"fps_rot_deg": Vector3(90, 0, 0), "fps_offset": Vector3(0.0, -0.14, -0.07),
		}),
		# 3: GLAVNO ORUŽJE — Crnogorski Gaser M1870/74 Revolver
		WeaponDef.new({
			"id": "gasser_m1870", "display_name": "Gaser M1870/74", "category": "Pištolji i revolveri", "caliber": "11.2x36mm R",
			"slot": SLOT_GASSER, "model_path": MODEL_DIR + "gasser_m1870.glb", "hold_style": "pistol",
			"mag_capacity": 6, "starting_reserve": 36, "reserve_max": 96,
			"fire_cooldown": 0.34, "reload_duration": 1.85,
			"automatic": false, "pellets": 1,
			"aim_spread_deg": 0.65, "hip_spread_deg": 2.3,
			"recoil_pitch": 1.85, "recoil_yaw": 0.36,
			"max_range_m": 85.0, "damage": 78.0, "sound_key": "revolver",
			"target_length_m": 0.36,
			"fps_rot_deg": Vector3(90, 0, 0), "fps_offset": Vector3(0.0, -0.14, -0.052),
		}),
		# 4: Mauser 98 Sporting (cleaned Sketchfab model)
		WeaponDef.new({
			"id": "mauser_98", "display_name": "Mauser 98 (Optika)", "category": "Puške repetirke", "caliber": "7.92x57mm",
			"slot": 4, "model_path": MODEL_DIR + "mauser_98_sporting.glb", "hold_style": "rifle",
			"is_sketchfab": true, "target_length_m": 1.10,
			"sketchfab_grip_raw": Vector3(0.010, 0.035, 0.04),
			"sketchfab_muzzle_local": Vector3(0.0, 0.025, -0.78),
			"sketchfab_grip_l_local": Vector3(0.0, 0.015, -0.34),
			"sketchfab_eject_local": Vector3(0.020, 0.05, -0.10),
			"sketchfab_sight_local": Vector3(0.0, 0.135, -0.12),
			"mag_capacity": 5, "starting_reserve": 35, "reserve_max": 80,
			"fire_cooldown": 0.78, "reload_duration": 1.75,
			"automatic": false, "pellets": 1,
			"aim_spread_deg": 0.12, "hip_spread_deg": 2.4,
			"recoil_pitch": 1.75, "recoil_yaw": 0.40,
			"max_range_m": 320.0, "damage": 135.0, "sound_key": "rifle",
			"fps_rot_deg": Vector3(90, 0, 0), "fps_offset": Vector3(0.0, -0.13, -0.085),
		}),
		# 5..9: Puške repetirke
		_std_def(5, "m24_mauser", "Mauzer M24", "Puške repetirke", "7.92x57mm", "rifle", 5, 35, 0.72, 1.55, false, 1, 0.25, 2.0, 1.65, 230.0, 115.0, "rifle", 1.10),
		_std_def(6, "mosin_91_30", "Mosin-Nagant 91/30", "Puške repetirke", "7.62x54mmR", "rifle", 5, 35, 0.76, 1.65, false, 1, 0.24, 2.2, 1.75, 250.0, 120.0, "rifle", 1.23),
		_std_def(7, "carcano_m91", "Carcano M91", "Puške repetirke", "6.5x52mm", "rifle", 6, 36, 0.68, 1.50, false, 1, 0.35, 2.1, 1.35, 200.0, 95.0, "rifle", 1.12),
		_std_def(8, "mannlicher_m95", "Mannlicher M95", "Puške repetirke", "8x50mmR", "rifle", 5, 35, 0.58, 1.45, false, 1, 0.32, 2.1, 1.60, 210.0, 108.0, "rifle", 1.10),
		_std_def(9, "lee_enfield_no4", "Lee-Enfield No.4", "Puške repetirke", ".303 British", "rifle", 10, 40, 0.54, 1.85, false, 1, 0.28, 2.0, 1.50, 240.0, 110.0, "rifle", 1.13),
		# 10..13: Poluautomatske puške
		_std_def(10, "svt40", "Tokarev SVT-40", "Poluautomatske puške", "7.62x54mmR", "rifle", 10, 40, 0.26, 2.10, false, 1, 0.45, 2.5, 1.25, 220.0, 92.0, "rifle", 1.22),
		_std_def(11, "g43", "Gewehr 43", "Poluautomatske puške", "7.92x57mm", "rifle", 10, 40, 0.25, 2.05, false, 1, 0.42, 2.4, 1.22, 220.0, 92.0, "rifle", 1.12),
		_std_def(12, "m1_carbine", "M1 Carbine", "Poluautomatske puške", ".30 Carbine", "rifle", 15, 60, 0.19, 1.75, false, 1, 0.68, 2.2, 0.72, 140.0, 56.0, "pistol", 0.90),
		_std_def(13, "m1_garand", "M1 Garand", "Poluautomatske puške", ".30-06", "rifle", 8, 48, 0.24, 1.65, false, 1, 0.38, 2.3, 1.30, 230.0, 96.0, "rifle", 1.11),
		# 14..18: Automati
		_std_def(14, "thompson_m1a1", "Thompson M1A1", "Automati", ".45 ACP", "rifle", 30, 90, 0.088, 2.15, true, 1, 1.40, 3.2, 0.68, 85.0, 38.0, "smg", 0.81),
		_std_def(15, "sten_mk2", "Sten Mk II", "Automati", "9x19mm", "rifle", 32, 96, 0.112, 1.95, true, 1, 1.55, 3.4, 0.56, 80.0, 32.0, "smg", 0.76),
		_std_def(16, "ppsh41", "PPŠ-41 Špagin", "Automati", "7.62x25mm", "rifle", 71, 142, 0.068, 2.65, true, 1, 1.65, 3.6, 0.52, 90.0, 29.0, "smg", 0.84),
		_std_def(17, "beretta_mab38", "Beretta MAB 38", "Automati", "9x19mm", "rifle", 40, 120, 0.100, 2.00, true, 1, 1.05, 2.7, 0.50, 105.0, 35.0, "smg", 0.87),
		_std_def(18, "zk383", "ZK-383", "Automati", "9x19mm", "rifle", 30, 90, 0.105, 1.95, true, 1, 1.05, 2.6, 0.52, 105.0, 35.0, "smg", 0.88),
		# 19..22: Mitraljezi
		_std_def(19, "mg34", "MG 34", "Mitraljezi", "7.92x57mm", "heavy", 50, 150, 0.072, 3.00, true, 1, 1.65, 4.5, 0.88, 250.0, 44.0, "mg", 1.22),
		_std_def(20, "breda_m30", "Breda M30", "Mitraljezi", "6.5x52mm", "heavy", 20, 100, 0.125, 2.60, true, 1, 1.55, 4.0, 0.76, 210.0, 42.0, "mg", 1.15),
		_std_def(21, "bren_mk1", "Bren Mk I", "Mitraljezi", ".303 British", "heavy", 30, 120, 0.115, 2.35, true, 1, 1.25, 3.7, 0.78, 240.0, 48.0, "mg", 1.15),
		_std_def(22, "zb26", "Zbrojovka ZB-26", "Mitraljezi", "7.92x57mm", "heavy", 20, 100, 0.112, 2.30, true, 1, 1.20, 3.6, 0.80, 240.0, 48.0, "mg", 1.16),
		# 23..26: Pištolji i revolveri
		_std_def(23, "luger_p08", "Luger P08", "Pištolji i revolveri", "9x19mm", "pistol", 8, 40, 0.22, 1.45, false, 1, 0.75, 2.1, 1.05, 70.0, 46.0, "pistol", 0.24),
		_std_def(24, "walther_p38", "Walther P38", "Pištolji i revolveri", "9x19mm", "pistol", 8, 40, 0.21, 1.45, false, 1, 0.80, 2.2, 1.08, 70.0, 46.0, "pistol", 0.23),
		_std_def(25, "tt33", "Tokarev TT-33", "Pištolji i revolveri", "7.62x25mm", "pistol", 8, 40, 0.20, 1.45, false, 1, 0.78, 2.2, 1.15, 75.0, 48.0, "pistol", 0.21),
		_std_def(26, "browning_m1922", "Browning M1922", "Pištolji i revolveri", "7.65mm", "pistol", 9, 45, 0.20, 1.40, false, 1, 0.85, 2.1, 0.90, 60.0, 38.0, "pistol", 0.20),
		# 27..28: Sačmarice
		_std_def(27, "lovacka_dvocijevka", "Lovačka Dvocijevka", "Sačmarice", "12 GA", "rifle", 2, 24, 0.34, 1.95, false, 8, 3.6, 4.8, 2.6, 45.0, 24.0, "shotgun", 1.12),
		_std_def(28, "winchester_m1897", "Winchester M1897", "Sačmarice", "12 GA", "rifle", 5, 30, 0.62, 2.25, false, 8, 3.3, 4.5, 2.4, 48.0, 22.0, "shotgun", 1.02),
		# 29..30: Ostalo pješadijsko oružje
		WeaponDef.new({
			"id": "m24_stielhandgranate", "display_name": "Ručna bomba M24", "category": "Ostalo oružje", "caliber": "TNT",
			"slot": 29, "model_path": MODEL_DIR + "m24_stielhandgranate.glb", "hold_style": "grenade",
			"is_explosive": true, "mag_capacity": 1, "starting_reserve": 4, "reserve_max": 8,
			"fire_cooldown": 1.15, "reload_duration": 0.90,
			"automatic": false, "pellets": 1, "aim_spread_deg": 0.5, "hip_spread_deg": 1.2,
			"recoil_pitch": 0.6, "recoil_yaw": 0.2, "max_range_m": 45.0, "damage": 180.0, "sound_key": "grenade",
			"target_length_m": 0.36, "fps_rot_deg": Vector3(90, 0, 0), "fps_offset": Vector3(0.06, -0.14, -0.05),
		}),
		WeaponDef.new({
			"id": "bajonet_m1924", "display_name": "Bajonet M1924 / Kama", "category": "Ostalo oružje", "caliber": "Čelik",
			"slot": 30, "model_path": MODEL_DIR + "bajonet_m1924.glb", "hold_style": "melee",
			"is_melee": true, "mag_capacity": 1, "starting_reserve": 1, "reserve_max": 1,
			"fire_cooldown": 0.42, "reload_duration": 0.2,
			"automatic": false, "pellets": 1, "aim_spread_deg": 0.0, "hip_spread_deg": 0.0,
			"recoil_pitch": 0.4, "recoil_yaw": 0.2, "max_range_m": 2.4, "damage": 110.0, "sound_key": "melee",
			"target_length_m": 0.43, "fps_rot_deg": Vector3(90, 0, 0), "fps_offset": Vector3(0.05, -0.14, -0.04),
		}),
	]
	for d in weapons:
		_ammo[d.slot] = [d.mag_capacity, d.starting_reserve]


func _std_def(slot_i: int, wid: String, dname: String, cat: String, cal: String, hold: String,
		mag: int, res: int, cd: float, rel: float, auto: bool, pel: int,
		aspr: float, hspr: float, rec: float, rng_m: float, dmg: float, skey: String, tlen: float) -> WeaponDef:
	var is_pis := (hold == "pistol")
	var off := Vector3(0.0, -0.14, -0.050) if is_pis else Vector3(0.0, -0.13, -0.048)
	return WeaponDef.new({
		"id": wid, "display_name": dname, "category": cat, "caliber": cal,
		"slot": slot_i, "model_path": MODEL_DIR + wid + ".glb", "hold_style": hold,
		"mag_capacity": mag, "starting_reserve": res, "reserve_max": maxi(res * 3, 60),
		"fire_cooldown": cd, "reload_duration": rel,
		"automatic": auto, "pellets": pel,
		"aim_spread_deg": aspr, "hip_spread_deg": hspr,
		"recoil_pitch": rec, "recoil_yaw": rec * 0.28,
		"max_range_m": rng_m, "damage": dmg, "sound_key": skey,
		"target_length_m": tlen,
		"fps_rot_deg": Vector3(90, 0, 0), "fps_offset": off,
	})


# ------------------------------------------------------------------ holding
func _mount_root_for_weapon() -> Node3D:
	if _mount_root and is_instance_valid(_mount_root):
		return _mount_root
	_mount_root = Node3D.new()
	_mount_root.name = "Stage33WeaponMount"
	if _skel:
		_skel.add_child(_mount_root)
		var anim := _animator_ref()
		if anim:
			anim.set_weapon_mount_node(_mount_root)
	elif player:
		player.add_child(_mount_root)
	return _mount_root


func _load_model_for(def: WeaponDef) -> Node3D:
	var path := _resolve_model_path(def)
	if path == "":
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Stage33: cannot load weapon model " + def.model_path)
		return null
	var raw_inst := scene.instantiate() as Node3D
	if def.is_sketchfab:
		return _standardize_sketchfab(raw_inst, def)
	if def.slot != SLOT_M48:
		return _standardize_fallback(raw_inst, def)
	raw_inst.name = "Model_" + def.id
	return raw_inst


## Normalise raw GLB weapons that do not provide Sketchfab-style Grip/Muzzle
## markers. This keeps every arsenal model at a real-world target length and
## gives the raycast/recoil systems stable marker positions.
func _standardize_fallback(raw: Node3D, def: WeaponDef) -> Node3D:
	var aabb := _combined_aabb(raw)
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var s: float = def.target_length_m / longest if longest > 0.0001 else 1.0
	def.applied_scale = s
	def.raw_size = aabb.size

	var wrapper := Node3D.new()
	wrapper.name = "Model_" + def.id
	raw.scale = Vector3(s, s, s)
	raw.position = -(aabb.position + aabb.size * 0.5) * s
	wrapper.add_child(raw)

	var grip_x := 0.0
	var grip_y := -0.02
	var grip_z := 0.18 if def.hold_style != "pistol" else 0.08
	_add_marker(wrapper, "Grip_R", Vector3(grip_x, grip_y, grip_z))
	_add_marker(wrapper, "Grip_L", Vector3(0.0, grip_y, -0.22))
	_add_marker(wrapper, "Muzzle", Vector3(0.0, 0.02, -def.target_length_m * 0.52))
	_add_marker(wrapper, "Eject", Vector3(0.025, 0.055, -0.06))
	_add_marker(wrapper, "IronSight", Vector3(0.0, 0.075, -0.08))
	return wrapper


func _standardize_sketchfab(raw: Node3D, def: WeaponDef) -> Node3D:
	var bad_prefixes: Array[String] = []
	if def.id == "mp40":
		bad_prefixes = ["Cube_001", "Cube_002", "Cube_003", "Cube_004", "Cylinder_001", "Cube_005", "Circle_001", "Camera"]
	elif def.id == "mg42":
		bad_prefixes = ["Plane_006", "BezierCurve_003"]
	elif def.id == "mauser_98":
		bad_prefixes = ["weapon#ammo_mesh_001_001", "weapon#ammo_mesh_001_002", "weapon#ammo_mesh_001_005", "weapon#ammo_mesh_001_006"]
	if not bad_prefixes.is_empty():
		_strip_nodes(raw, bad_prefixes)

	var aabb := _combined_aabb(raw)
	var longest: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var s: float = def.target_length_m / longest if longest > 0.0001 else 1.0
	def.applied_scale = s
	def.raw_size = aabb.size

	var wrapper := Node3D.new()
	wrapper.name = "Model_" + def.id
	raw.scale = Vector3(s, s, s)
	raw.position = -def.sketchfab_grip_raw * s
	wrapper.add_child(raw)

	_add_marker(wrapper, "Grip_R", Vector3.ZERO)
	_add_marker(wrapper, "Grip_L", def.sketchfab_grip_l_local)
	_add_marker(wrapper, "Muzzle", def.sketchfab_muzzle_local)
	_add_marker(wrapper, "Eject", def.sketchfab_eject_local)
	_add_marker(wrapper, "IronSight", def.sketchfab_sight_local)
	return wrapper


func _add_marker(parent: Node3D, mname: String, pos: Vector3) -> void:
	var mk := Marker3D.new()
	mk.name = mname
	mk.position = pos
	parent.add_child(mk)


func _strip_nodes(root_n: Node, bad_prefixes: Array[String]) -> void:
	var to_free: Array[Node] = []
	var stack: Array[Node] = [root_n]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var nm := String(n.name)
		var bad := false
		for p in bad_prefixes:
			if nm.begins_with(p):
				bad = true
				break
		if bad:
			to_free.append(n)
		else:
			for c in n.get_children():
				stack.append(c)
	for bn in to_free:
		if bn.get_parent():
			bn.get_parent().remove_child(bn)
		bn.free()


func _resolve_model_path(def: WeaponDef) -> String:
	if def.model_path != "" and ResourceLoader.exists(def.model_path):
		return def.model_path
	var alt := RECOVERED_DIR + def.id + ".glb"
	if ResourceLoader.exists(alt):
		return alt
	return ""


func _combined_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mi := node as MeshInstance3D
			var box: AABB = xf * mi.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in node.get_children():
			var cxf: Transform3D = xf
			if c is Node3D:
				cxf = xf * (c as Node3D).transform
			stack.append([c, cxf])
	return out


func show_weapon(slot: int, _instant := false) -> void:
	for s in held.keys():
		if held[s] and is_instance_valid(held[s]):
			held[s].visible = (s == slot)
	var def := def_for(slot)
	if def == null:
		return
	active = slot
	_fire_timer = 0.0
	_reloading = false
	_reload_timer = 0.0
	if player and player.weapon_action == "Reload":
		player.weapon_action = ""
	var anim := _animator_ref()
	if anim != null:
		anim.set_rifle_selected(slot == SLOT_M48)
		anim.set_weapon_mount_node(_mount_root_for_weapon())
		var gl_local := def.sketchfab_grip_l_local
		anim.set_weapon_hold_profile(def.hold_style, gl_local)

	if slot == SLOT_M48:
		_sync_fps_visibility(slot)
		return

	if player:
		var wc := player.get_node_or_null("WeaponController") as WeaponController
		if wc:
			if _instant and wc.current_state == WeaponController.State.HOLSTERED:
				wc.current_state = WeaponController.State.READY
				wc._state_timer = 0.0
				wc.call("_sync_player_flags")
				wc.state_changed.emit(wc.get_state_label())
			elif not wc.is_equipped():
				wc.toggle_equip()
		player.weapon_equipped = true

	if not held.has(slot) or held[slot] == null or not is_instance_valid(held[slot]):
		var model := _load_model_for(def)
		if model == null:
			return
		_mount_root_for_weapon().add_child(model)
		held[slot] = model
		# Read real Grip_L marker from loaded model if available
		var gl_mk := model.find_child("Grip_L", true, false) as Node3D
		if gl_mk and anim:
			anim.set_weapon_hold_profile(def.hold_style, gl_mk.position)
	else:
		var m_exist: Node3D = held[slot]
		var gl_mk2 := m_exist.find_child("Grip_L", true, false) as Node3D
		if gl_mk2 and anim:
			anim.set_weapon_hold_profile(def.hold_style, gl_mk2.position)

	held[slot].visible = true
	_ensure_fps_weapon(def)
	_sync_fps_visibility(slot)


func _ensure_fps_weapon(def: WeaponDef) -> void:
	if def.slot == SLOT_M48 or _fps_mounted.has(def.id):
		return
	if fps_rig == null and player:
		fps_rig = player.find_child("FirstPersonRig", true, false) as FirstPersonRig
	if fps_rig == null or not fps_rig.fp_has_rig():
		return
	var model := _load_model_for(def)
	if model == null:
		return
	var sight_mk := model.find_child("IronSight", true, false) as Node3D
	var off := def.fps_offset
	if sight_mk != null:
		# Align weapon's iron sights cleanly at camera eye level in WeaponMount frame
		off = Vector3(0.0, -0.14 if def.hold_style == "pistol" else -0.13, 0.041 - sight_mk.position.y)
	if fps_rig.fp_mount_weapon(def.id, model, def.fps_rot_deg, off):
		_fps_mounted[def.id] = true


func _sync_fps_visibility(slot: int) -> void:
	if fps_rig == null:
		return
	var d := def_for(slot)
	if d == null:
		return
	fps_rig.fp_show_weapon("" if slot == SLOT_M48 else d.id)


func _animator_ref() -> PlayerAnimator:
	if animator != null and is_instance_valid(animator):
		return animator
	if player != null:
		animator = player.get_node_or_null("PlayerAnimator") as PlayerAnimator
	return animator


# ------------------------------------------------------------------- public
func def_for(slot: int) -> WeaponDef:
	for d in weapons:
		if d.slot == slot:
			return d
	return null


func def_for_id(weapon_id: String) -> WeaponDef:
	var low := weapon_id.to_lower()
	if low.begins_with("maschinen"):
		low = "mg42"
	for d in weapons:
		if d.id == low:
			return d
	return null


func active_def() -> WeaponDef:
	return def_for(active)


func ammo_for(slot: int) -> Array:
	return _ammo.get(slot, [0, 0])


func owns(slot: int) -> bool:
	return owned.has(slot)


func give_weapon(slot: int, ammo_reserve := -1) -> bool:
	var d := def_for(slot)
	if owned.has(slot):
		if d:
			var res0: int = ammo_reserve if ammo_reserve >= 0 else d.starting_reserve
			var cur: Array = _ammo.get(slot, [0, 0])
			var mag: int = mini(d.mag_capacity, int(cur[0]) + d.mag_capacity)
			var reserve: int = mini(d.reserve_max, int(cur[1]) + res0)
			_ammo[slot] = [mag, reserve]
		return false
	owned.append(slot)
	if d:
		var res: int = ammo_reserve if ammo_reserve >= 0 else d.starting_reserve
		_ammo[slot] = [d.mag_capacity, res]
	var ms := get_tree().root.get_node_or_null("MissionSystem")
	if ms and ms.has_method("notify_weapon"):
		ms.notify_weapon(slot)
	return true


func unlock_full_arsenal() -> void:
	for d in weapons:
		if not owned.has(d.slot):
			owned.append(d.slot)
			_ammo[d.slot] = [d.mag_capacity, d.starting_reserve]
	owned.sort()
	var ms := get_tree().root.get_node_or_null("MissionSystem")
	if ms and ms.has_method("notify_weapon"):
		ms.notify_weapon(SLOT_MP40)
		ms.notify_weapon(SLOT_MG42)
	weapon_changed.emit(active_def())


func next_weapon() -> void:
	if owned.size() <= 1:
		return
	var idx := owned.find(active)
	var nxt: int = owned[(idx + 1) % owned.size()]
	switch_to(nxt)


func switch_to(slot: int) -> bool:
	if not owned.has(slot) or slot == active or _swapping:
		return false
	_swapping = true
	_swap_timer = 0.25
	await get_tree().create_timer(0.12).timeout
	active = slot
	_swapping = false
	_reloading = false
	_reload_timer = 0.0
	show_weapon(slot)
	var d := active_def()
	if d and _sound:
		_sound.play_equip(true)
	weapon_changed.emit(d)
	return true


func is_automatic() -> bool:
	var d := active_def()
	return d != null and d.automatic


# -------------------------------------------------------------------- fire
func try_fire(held_btn := true) -> bool:
	if _swapping or player == null or not player.is_alive():
		return false
	if player.is_sprint_active():
		player.set_sprint_active(false)
	var d := active_def()
	if d == null or _fire_timer > 0.0 or _reloading:
		return false
	if not player.weapon_equipped and d.slot != SLOT_M48:
		show_weapon(d.slot, true)

	if d.slot == SLOT_M48:
		var wc := player.get_node_or_null("WeaponController") as WeaponController
		if wc:
			return wc.try_fire()
		return false

	var a := ammo_for(d.slot)
	if not d.is_melee and int(a[0]) <= 0:
		if _sound:
			_sound.play_dry_fire()
		if int(a[1]) > 0:
			reload()
		return false
	if not d.automatic and not held_btn:
		return false

	_fire()
	_fire_timer = d.fire_cooldown
	return true


func _fire() -> void:
	var d := active_def()
	if d == null:
		return
	var a := ammo_for(d.slot)
	if not d.is_melee:
		a[0] = maxi(0, int(a[0]) - 1)

	var is_fp := camera_rig != null and camera_rig.is_fp_active() and fps_rig != null and fps_rig.is_fp_visible()
	var muzzle := fps_rig.get_muzzle_world_position() if is_fp else _muzzle_world()
	var ray := camera_rig.get_aim_ray() if camera_rig else {"origin": muzzle, "dir": -player.global_transform.basis.z}
	var origin: Vector3 = ray["origin"]
	var dir: Vector3 = ray["dir"]
	var fx := get_tree().current_scene if get_tree().current_scene else player.get_parent()

	# Special case 1: Melee Bayonet / Kama
	if d.is_melee:
		if _sound:
			_sound.play_melee_swing()
		var hit_m := _raycast(origin, dir, d.max_range_m)
		if hit_m["hit"]:
			var col_m: Object = hit_m["collider"]
			var surf_m := _apply_hit_damage(col_m, hit_m["pos"], hit_m["normal"], d.damage, origin, fx)
			if _sound:
				_sound.play_hit(surf_m)
		_recoil_timer = 0.18
		if player:
			player.weapon_action = "Fire"
		shot_fired.emit()
		if player.has_method("notify_weapon_fired"):
			player.notify_weapon_fired(true)
		return

	# Special case 2: Throwable M24 Grenade
	if d.is_explosive:
		if _sound:
			_sound.play_equip(false)
		_spawn_grenade_projectile(muzzle, (dir + Vector3(0, 0.24, 0)).normalized() * 18.0, d.damage)
		shot_fired.emit()
		if int(a[0]) == 0 and int(a[1]) > 0:
			reload()
		if player.has_method("notify_weapon_fired"):
			player.notify_weapon_fired(true)
		return

	# Standard ballistic / multi-pellet firearms
	if is_fp:
		fps_rig.trigger_muzzle_flash()
	else:
		WeaponEffects.spawn_muzzle_flash(fx, muzzle, dir)

	var spread := deg_to_rad(d.aim_spread_deg if player.is_aiming else d.hip_spread_deg)
	if player.current_horizontal_speed > 0.4:
		spread *= 1.35

	var pellets: int = maxi(1, d.pellets)
	for _pi in pellets:
		var pdir := (dir + Vector3(
			_rng.randf_range(-spread, spread),
			_rng.randf_range(-spread, spread),
			_rng.randf_range(-spread, spread)
		)).normalized()
		var hit := _raycast(origin, pdir, d.max_range_m)
		WeaponEffects.spawn_tracer(fx, muzzle, hit["pos"])
		if hit["hit"]:
			var col: Object = hit["collider"]
			var surf := _apply_hit_damage(col, hit["pos"], hit["normal"], d.damage, origin, fx)
			if _pi == 0 and _sound:
				_sound.play_hit(surf)

	# Brass shell ejection (revolvers eject on reload, semi/auto on every shot)
	if d.sound_key != "revolver":
		var ej := _eject_world()
		var right_dir := player.global_transform.basis.x
		var up_dir := Vector3.UP
		if held.has(active) and held[active] and is_instance_valid(held[active]):
			var hm := held[active] as Node3D
			right_dir = hm.global_transform.basis.x
			up_dir = hm.global_transform.basis.y
		WeaponEffects.spawn_shell_casing(fx, ej, right_dir, up_dir)

	_play_fire_sound(d.sound_key)
	if camera_rig:
		camera_rig.add_recoil_kick(
			d.recoil_pitch * _rng.randf_range(0.85, 1.2),
			_rng.randf_range(-d.recoil_yaw, d.recoil_yaw)
		)
	_recoil_timer = 0.16
	if player:
		player.weapon_action = "Fire"
	shot_fired.emit()
	if player.has_method("notify_weapon_fired"):
		player.notify_weapon_fired(player.is_aiming)


func _play_fire_sound(sound_key: String) -> void:
	if _sound == null:
		return
	match sound_key:
		"revolver":
			_sound.play_revolver_shot()
		"pistol":
			_sound.play_pistol_shot()
		"smg":
			_sound.play_smg_shot()
		"mg":
			_sound.play_mg_shot()
		"shotgun":
			_sound.play_shotgun_shot()
		_:
			_sound.play_rifle_shot()


func _apply_hit_damage(col: Object, pos: Vector3, normal: Vector3, dmg: float, origin: Vector3, fx: Node) -> String:
	var surf := "dirt"
	var is_tgt := false
	var dist := player.global_position.distance_to(pos) if player else 0.0
	if col is PostWarEnemy:
		(col as PostWarEnemy).take_damage(dmg)
		surf = "wood"
	elif col is ShootingTarget:
		var st := col as ShootingTarget
		surf = st.surface_kind
		is_tgt = true
		dist = st.register_hit(pos, player.global_position if player else origin)
		_hit_targets[st.name] = true
	elif col is Node:
		var nm := (col as Node).name.to_lower()
		if "rock" in nm or "stone" in nm or "wall" in nm or "house" in nm:
			surf = "stone"
		elif "barn" in nm or "tree" in nm:
			surf = "wood"
	WeaponEffects.spawn_impact(fx, pos, normal, surf)
	target_hit.emit(is_tgt, dist, _hit_targets.size())
	return surf


func _spawn_grenade_projectile(start_pos: Vector3, vel: Vector3, dmg: float) -> void:
	var fx := get_tree().current_scene if get_tree().current_scene else player.get_parent()
	var g := Node3D.new()
	g.name = "ThrownM24Grenade"
	g.position = start_pos
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.036
	cyl.bottom_radius = 0.036
	cyl.height = 0.24
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.34, 0.22)
	mesh_inst.material_override = mat
	g.add_child(mesh_inst)
	fx.add_child(g)
	_grenades.append({"node": g, "vel": vel, "timer": 1.6, "dmg": dmg})


func _detonate_grenade(pos: Vector3, dmg: float) -> void:
	if _sound:
		_sound.play_explosion()
	var fx := get_tree().current_scene if get_tree().current_scene else player.get_parent()
	# Visual flash sphere
	var blast := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 2.4
	sph.height = 4.8
	blast.mesh = sph
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.45, 0.08)
	bmat.emission_energy_multiplier = 4.0
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blast.material_override = bmat
	blast.position = pos + Vector3(0, 0.4, 0)
	fx.add_child(blast)
	var tw := blast.create_tween()
	tw.tween_property(blast, "scale", Vector3(2.2, 2.2, 2.2), 0.22)
	tw.parallel().tween_property(bmat, "albedo_color:a", 0.0, 0.30)
	tw.tween_callback(blast.queue_free)

	# AoE damage to enemies & shooting targets within 6 m
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is PostWarEnemy and (n as Node3D).global_position.distance_to(pos) <= 6.5:
			(n as PostWarEnemy).take_damage(dmg)
	var root_n := get_tree().current_scene
	if root_n:
		for st in root_n.find_children("*", "ShootingTarget", true, false):
			if st is ShootingTarget and (st as Node3D).global_position.distance_to(pos) <= 6.5:
				(st as ShootingTarget).register_hit(pos, player.global_position if player else pos)


func _muzzle_world() -> Vector3:
	if held.has(active) and held[active] and is_instance_valid(held[active]):
		var m := held[active] as Node3D
		var mk := m.find_child("Muzzle", true, false) as Node3D
		if mk:
			return mk.global_position
		var d := active_def()
		return m.global_transform * Vector3(0.0, 0.06, -(d.target_length_m if d else 0.5))
	if player:
		return player.global_position + Vector3(0.0, 1.45, 0.0) + player.global_transform.basis.z * -0.6
	return Vector3.ZERO


func _eject_world() -> Vector3:
	if held.has(active) and held[active] and is_instance_valid(held[active]):
		var m := held[active] as Node3D
		var mk := m.find_child("Eject", true, false) as Node3D
		if mk:
			return mk.global_position
		return m.global_transform * Vector3(0.02, 0.06, -0.05)
	return _muzzle_world()


func _raycast(origin: Vector3, dir: Vector3, dist: float) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * dist, 1 | 4)
	q.exclude = [player.get_rid()]
	var res := space.intersect_ray(q)
	if res.is_empty():
		return {"hit": false, "pos": origin + dir * dist, "normal": Vector3.UP, "collider": null}
	return {"hit": true, "pos": res["position"], "normal": res["normal"], "collider": res.get("collider")}


func reload() -> bool:
	var d := active_def()
	if d == null or _reloading or d.is_melee:
		return false
	if d.slot == SLOT_M48:
		var wc := player.get_node_or_null("WeaponController") as WeaponController if player else null
		if wc:
			return wc.try_reload()
		return false
	var a := ammo_for(d.slot)
	if int(a[0]) >= d.mag_capacity or int(a[1]) <= 0:
		return false
	_reloading = true
	_reload_timer = d.reload_duration
	if player:
		player.weapon_action = "Reload"
	if _sound:
		if d.sound_key == "revolver":
			_sound.play_revolver_reload()
		else:
			_sound.play_reload()
	return true


func is_reloading() -> bool:
	if active == SLOT_M48 and player:
		var wc := player.get_node_or_null("WeaponController") as WeaponController
		if wc:
			return wc.current_state == WeaponController.State.RELOADING
	return _reloading


func _process(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = maxf(0.0, _fire_timer - delta)
	if _recoil_timer > 0.0:
		_recoil_timer = maxf(0.0, _recoil_timer - delta)
		if _recoil_timer <= 0.0 and player and active != SLOT_M48 and player.weapon_action == "Fire":
			player.weapon_action = ""
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_reloading = false
			if player and active != SLOT_M48 and player.weapon_action == "Reload":
				player.weapon_action = ""
			var d := active_def()
			if d:
				var a := ammo_for(d.slot)
				var need: int = d.mag_capacity - int(a[0])
				var take: int = mini(need, int(a[1]))
				a[0] = int(a[0]) + take
				a[1] = int(a[1]) - take

	# Sync active held model visibility with player holster state
	if player and active != SLOT_M48 and held.has(active) and is_instance_valid(held[active]):
		var show_in_hand: bool = player.weapon_equipped or (player.weapon_action in ["Equip", "Holster", "Fire", "Reload"])
		var is_fp := camera_rig != null and camera_rig.is_fp_active() and fps_rig != null and fps_rig.is_fp_visible()
		(held[active] as Node3D).visible = show_in_hand and not is_fp

	# Update thrown grenades
	for i in range(_grenades.size() - 1, -1, -1):
		var gr: Dictionary = _grenades[i]
		var gn: Node3D = gr["node"]
		if not is_instance_valid(gn):
			_grenades.remove_at(i)
			continue
		var v: Vector3 = gr["vel"]
		v.y -= 13.5 * delta
		var next_p := gn.position + v * delta
		var space := player.get_world_3d().direct_space_state if player else null
		var hit_ground := false
		if space:
			var q := PhysicsRayQueryParameters3D.create(gn.global_position, next_p, 1)
			q.exclude = [player.get_rid()]
			var res := space.intersect_ray(q)
			if not res.is_empty():
				next_p = res["position"]
				var nrm: Vector3 = res["normal"]
				v = (v.bounce(nrm.normalized()) if nrm.length_squared() > 0.001 else -v) * 0.35
				hit_ground = true
		gn.position = next_p
		gn.rotate_x(8.0 * delta)
		gr["vel"] = v
		gr["timer"] = float(gr["timer"]) - delta
		if float(gr["timer"]) <= 0.0 or (hit_ground and v.length() < 1.5 and float(gr["timer"]) < 1.1):
			var dpos := gn.global_position
			var dmg_val: float = float(gr["dmg"])
			gn.queue_free()
			_grenades.remove_at(i)
			_detonate_grenade(dpos, dmg_val)


func status_text() -> String:
	var d := active_def()
	if d == null:
		return ""
	var a := ammo_for(d.slot)
	return "%s %d/%d" % [d.display_name, a[0], a[1]]
