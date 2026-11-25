class_name WeaponDef
extends RefCounted
## WeaponDef — one entry of the Stage 3.3 / 3.4 WW1-WW2 Balkan historical arsenal.
##
## Plain data object so the HUD, the arsenal logic, IK rig and the world pickups
## can all talk about a weapon without loading its model.

var id := ""
var display_name := ""
var category := "Puške repetirke"
var caliber := "7.92x57mm"
var slot := 0
var model_path := ""

# --- hold & combat style ---
## "pistol" | "rifle" | "heavy" | "grenade" | "melee"
var hold_style := "rifle"
var is_sketchfab := false
var is_melee := false
var is_explosive := false

# --- ballistics & handling ---
var mag_capacity := 5
var starting_reserve := 30
var reserve_max := 60
var fire_cooldown := 0.74
var reload_duration := 1.45
var automatic := false
var pellets := 1
var aim_spread_deg := 0.25
var hip_spread_deg := 2.1
var recoil_pitch := 1.7
var recoil_yaw := 0.45
var max_range_m := 220.0
var damage := 100.0
var sound_key := "rifle"

# --- presentation & socket fallback (used for Sketchfab cleaned imports) ---
var mount_pos := Vector3.ZERO
var fps_offset := Vector3.ZERO
var mount_rot_deg := Vector3.ZERO
var fps_rot_deg := Vector3.ZERO
var mount_scale := 1.0
var target_length_m := 1.0
var sketchfab_grip_raw := Vector3.ZERO
var sketchfab_muzzle_local := Vector3(0.0, 0.06, -0.50)
var sketchfab_grip_l_local := Vector3(0.0, 0.02, -0.28)
var sketchfab_eject_local := Vector3(0.02, 0.06, -0.06)
var sketchfab_sight_local := Vector3(0.0, 0.09, -0.04)

# --- filled in at load time ---
var applied_scale := 1.0
var raw_size := Vector3.ZERO


func _init(d: Dictionary = {}) -> void:
	for k in d.keys():
		set(k, d[k])


func length_label() -> String:
	return "%.2f m" % target_length_m
