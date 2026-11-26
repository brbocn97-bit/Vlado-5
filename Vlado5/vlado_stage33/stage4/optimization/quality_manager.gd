extends Node
## Runtime phone quality manager. LOW/MEDIUM/HIGH are user-selectable and
## persisted. ULTRA remains desktop-only and is never auto-selected on Android.

signal quality_changed(tier: int, tier_name: String)

enum Tier { LOW, MEDIUM, HIGH, ULTRA }
const SAVE_PATH := "user://graphics_quality.cfg"
const MOBILE_MAX_TIER := Tier.HIGH

var tier: Tier = Tier.MEDIUM
var tier_name := "MEDIUM"
var foliage_range := 160.0
var detail_range := 120.0
var landmark_range := 850.0
var shadow_distance := 30.0
var shadow_enabled := true
var msaa := Viewport.MSAA_DISABLED
var screen_scale := 0.80
var target_fps := 45
var _applied := false
var _user_selected := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _load_saved_tier():
		_choose_automatic_tier()
	_choose_tier_values()
	apply()
	print("[Quality] tier=%s scale=%.2f foliage=%.0fm shadows=%.0fm fps=%d saved=%s" % [tier_name, screen_scale, foliage_range, shadow_distance, target_fps, str(_user_selected)])

func _load_saved_tier() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	var value := int(cfg.get_value("graphics", "tier", -1))
	if value < int(Tier.LOW) or value > int(Tier.HIGH):
		return false
	tier = value as Tier
	_user_selected = true
	return true

func _save_tier() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "tier", int(tier))
	cfg.set_value("graphics", "name", tier_name)
	cfg.save(SAVE_PATH)

func _choose_automatic_tier() -> void:
	if OS.get_name() == "Android":
		var gpu := RenderingServer.get_video_adapter_name().to_upper()
		if "ADRENO 8" in gpu or "ADRENO 7" in gpu or "IMMORTALIS" in gpu or "XCLIPSE" in gpu:
			tier = Tier.HIGH
		elif "ADRENO 6" in gpu or "ADRENO 5" in gpu or "MALI-G7" in gpu or "MALI-G6" in gpu or "MALI-G5" in gpu:
			tier = Tier.MEDIUM
		else:
			tier = Tier.LOW
	elif OS.has_feature("mobile"):
		tier = Tier.MEDIUM
	else:
		tier = Tier.ULTRA

func _choose_tier_values() -> void:
	tier_name = ["LOW", "MEDIUM", "HIGH", "ULTRA"][int(tier)]
	match tier:
		Tier.LOW:
			foliage_range = 80.0
			detail_range = 70.0
			landmark_range = 650.0
			shadow_distance = 0.0
			shadow_enabled = false
			msaa = Viewport.MSAA_DISABLED
			screen_scale = 0.65
			target_fps = 30
		Tier.MEDIUM:
			foliage_range = 160.0
			detail_range = 120.0
			landmark_range = 850.0
			shadow_distance = 30.0
			shadow_enabled = true
			msaa = Viewport.MSAA_DISABLED
			screen_scale = 0.80
			target_fps = 45
		Tier.HIGH:
			foliage_range = 280.0
			detail_range = 180.0
			landmark_range = 1100.0
			shadow_distance = 60.0
			shadow_enabled = true
			msaa = Viewport.MSAA_DISABLED
			screen_scale = 1.0
			target_fps = 60
		Tier.ULTRA:
			foliage_range = 420.0
			detail_range = 220.0
			landmark_range = 1400.0
			shadow_distance = 95.0
			shadow_enabled = true
			msaa = Viewport.MSAA_2X
			screen_scale = 1.0
			target_fps = 60

func set_tier(new_tier: int, save_choice: bool = true) -> void:
	var max_tier := int(MOBILE_MAX_TIER) if OS.has_feature("mobile") or OS.get_name() == "Android" else int(Tier.ULTRA)
	tier = clampi(new_tier, int(Tier.LOW), max_tier) as Tier
	_user_selected = save_choice
	_choose_tier_values()
	if save_choice:
		_save_tier()
	apply()
	quality_changed.emit(int(tier), tier_name)
	print("[Quality] selected %s — %s" % [tier_name, get_profile_summary()])

func cycle_tier() -> void:
	# Phone UI intentionally cycles only LOW/MEDIUM/HIGH.
	set_tier((int(tier) + 1) % 3, true)

func reset_to_automatic() -> void:
	_user_selected = false
	_choose_automatic_tier()
	_choose_tier_values()
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "tier", -1)
	cfg.save(SAVE_PATH)
	apply()
	quality_changed.emit(int(tier), tier_name)

func get_profile_summary() -> String:
	return "%d FPS • %d%% rezolucije • trava %.0fm • sjenke %.0fm" % [target_fps, int(screen_scale * 100.0), foliage_range, shadow_distance]

func apply() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_applied = true
	Engine.max_fps = target_fps
	var vp := tree.root.get_viewport()
	if vp:
		vp.msaa_3d = msaa
		vp.scaling_3d_scale = screen_scale
	var sun := tree.root.find_child("SunLight", true, false) as DirectionalLight3D
	if sun:
		sun.shadow_enabled = shadow_enabled
		if shadow_enabled:
			sun.directional_shadow_max_distance = shadow_distance
	var vegetation := tree.root.find_child("MontenegroVegetation", true, false)
	if vegetation and vegetation.has_method("apply_quality_scale"):
		vegetation.call("apply_quality_scale", mini(int(tier), int(Tier.HIGH)))
	_apply_to_vegetation()

func _apply_to_vegetation() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var grass_end := 42.0
	var shrub_end := 58.0
	match tier:
		Tier.LOW:
			grass_end = 42.0; shrub_end = 58.0
		Tier.MEDIUM:
			grass_end = 72.0; shrub_end = 92.0
		Tier.HIGH:
			grass_end = 95.0; shrub_end = 125.0
		_:
			grass_end = 110.0; shrub_end = 145.0
	var n := 0
	for mi in tree.root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := mi as MultiMeshInstance3D
		if mmi == null:
			continue
		var nm := String(mmi.name)
		var end_d := foliage_range
		if nm.begins_with("Grass_"):
			end_d = grass_end
		elif nm.begins_with("Shrubs_"):
			end_d = shrub_end
		mmi.visibility_range_end = end_d
		mmi.visibility_range_end_margin = end_d * 0.12
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		n += 1
	if n > 0:
		print("[Quality] vegetation nodes=%d grass=%.0fm shrubs=%.0fm other=%.0fm" % [n, grass_end, shrub_end, foliage_range])
