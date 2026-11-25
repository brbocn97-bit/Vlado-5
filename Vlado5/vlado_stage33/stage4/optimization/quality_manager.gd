extends Node
## QualityManager — autoload. One place that decides how heavy the game runs.
##
## Stage 4 targets the Galaxy S25 Ultra (Adreno 830, 12 GB) but the same build
## must stay playable on weaker hardware, so quality is set once at boot from a
## tier list and then every subsystem reads it instead of hard-coding its own
## constants.
##
## Tiers
##   ULTRA  desktop                  : full vegetation, 460 m foliage draw,
##                                    shadows 105 m, MSAA 2x
##   HIGH   high-end phone           : 320 m foliage, shadows 70 m, no MSAA
##   MEDIUM Web / mid-range          : 200 m foliage, shadows 45 m, no MSAA
##   LOW    fallback                 : 120 m foliage, no shadows, no grass
##
## Everything is applied through the properties the world scripts already
## expose, so no other file has to know about quality.

enum Tier { LOW, MEDIUM, HIGH, ULTRA }

var tier: Tier = Tier.HIGH
var tier_name := "HIGH"

# foliage / prop draw distance in metres
var foliage_range := 320.0
var detail_range := 190.0
var landmark_range := 1100.0

# shadows
var shadow_distance := 70.0
var shadow_enabled := true

# rendering
var msaa := Viewport.MSAA_DISABLED
var screen_scale := 1.0
var target_fps := 60

var _applied := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_choose_tier()
	apply()
	print("[Quality] tier=%s foliage=%.0fm shadows=%.0fm msaa=%d fps=%d" % [
		tier_name, foliage_range, shadow_distance, msaa, target_fps])


func _choose_tier() -> void:
	# Web exports can run on software renderers and must not inherit desktop ULTRA.
	if OS.get_name() == "Web":
		tier = Tier.MEDIUM
	# Android: infer from the GPU string, which is reliable for Adreno/Mali.
	elif OS.get_name() == "Android":
		var gpu: String = RenderingServer.get_video_adapter_name().to_upper()
		# ULTRA (460 m foliage, MSAA 2x) is desktop-only; flagship phones cap at HIGH.
		if "IMMORTALIS" in gpu or "ADRENO 8" in gpu or "ADRENO 7" in gpu \
				or "ADRENO 6" in gpu or "MALI-G7" in gpu or "MALI-G6" in gpu \
				or "XCLOUD" in gpu or "APPLE" in gpu:
			tier = Tier.HIGH
		elif "ADRENO" in gpu or "MALI" in gpu or "POWERVR" in gpu:
			tier = Tier.MEDIUM
		else:
			tier = Tier.MEDIUM
	elif OS.has_feature("mobile"):
		tier = Tier.HIGH
	else:
		tier = Tier.ULTRA
	_set_tier_values()


func _set_tier_values() -> void:
	tier_name = ["LOW", "MEDIUM", "HIGH", "ULTRA"][tier]
	match tier:
		Tier.LOW:
			foliage_range = 120.0
			detail_range = 90.0
			shadow_distance = 0.0
			shadow_enabled = false
			msaa = Viewport.MSAA_DISABLED
			screen_scale = 0.8
			target_fps = 60
		Tier.MEDIUM:
			foliage_range = 200.0
			detail_range = 140.0
			shadow_distance = 45.0
			shadow_enabled = true
			msaa = Viewport.MSAA_DISABLED
			screen_scale = 0.9
			target_fps = 60
		Tier.HIGH:
			foliage_range = 320.0
			detail_range = 190.0
			shadow_distance = 70.0
			shadow_enabled = true
			msaa = Viewport.MSAA_DISABLED
			screen_scale = 1.0
			target_fps = 60
		Tier.ULTRA:
			foliage_range = 460.0
			detail_range = 190.0
			shadow_distance = 105.0
			shadow_enabled = true
			msaa = Viewport.MSAA_2X
			screen_scale = 1.0
			target_fps = 60


## Applies the tier to whatever is currently in the tree. Safe to call again
## after a scene reload.
func apply() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_applied = true
	Engine.max_fps = target_fps
	# shadows
	var sun := tree.root.find_child("SunLight", true, false) as DirectionalLight3D
	if sun:
		sun.shadow_enabled = shadow_enabled
		if shadow_enabled:
			sun.directional_shadow_max_distance = shadow_distance
	# viewport knobs
	var vp := tree.root.get_viewport()
	if vp:
		vp.msaa_3d = msaa
		vp.scaling_3d_scale = screen_scale
	_apply_to_vegetation()


func _apply_to_vegetation() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var n := 0
	# Trava i zbunje imaju SVOJE distance (105 m / 135 m) — ne smiju se
	# razvlaciti na foliage_range, jer bi se crtalo 4x vise vlati nego treba.
	var grass_end := foliage_range
	var shrub_end := foliage_range
	match tier:
		Tier.LOW:
			grass_end = 55.0
			shrub_end = 75.0
		Tier.MEDIUM:
			grass_end = 78.0
			shrub_end = 100.0
		Tier.HIGH:
			grass_end = 95.0
			shrub_end = 125.0
		_:
			grass_end = 105.0
			shrub_end = 135.0
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
		elif nm.begins_with("PineNear_") or nm.begins_with("BeechNear_"):
			end_d = minf(foliage_range, 220.0)
		elif nm.begins_with("PineFar_") or nm.begins_with("BeechFar_"):
			end_d = minf(foliage_range, 380.0)
		mmi.visibility_range_end = end_d
		mmi.visibility_range_end_margin = end_d * 0.12
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		n += 1
	if n > 0:
		print("[Quality] vegetation ranges set on %d MultiMesh nodes (grass %.0fm, shrubs %.0fm, ostalo %.0fm)" % [n, grass_end, shrub_end, foliage_range])


## Called by the HUD/settings screen.
func cycle_tier() -> void:
	tier = ((tier + 1) % 4) as Tier
	_set_tier_values()
	apply()
