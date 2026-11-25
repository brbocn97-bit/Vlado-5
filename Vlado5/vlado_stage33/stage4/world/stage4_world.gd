class_name Stage4World
extends Node3D
## Stage4World — orchestrator for the Stage 4 layer, mounted on top of the
## Stage 3.2 baseline (MontenegroTerrainData / MontenegroTerrain / WaterSystem /
## MontenegroSettlement / MontenegroVegetation / PlayerController / WeaponController).
##
## NOTHING in the Stage 3.2 files is rewritten: this node instantiates the six
## streamed regions, the region streamer, the interaction layer and the combat
## actors, and hands them the baseline's terrain_data instance so every height,
## river and forest query matches the existing world exactly.
##
## Hierarchy (added under MontenegroWorld):
##   Stage4World
##     RegionStreamer          (autoload WorldStreamer drives it)
##     Regions                 (6 x WorldRegion)
##     LongRiver               (river ribbon extended to Z ±690)
##     Stage4Actors            (NPCs / enemies registered by regions)
##     InteractionBridge       (routes AimRay hits to Interactable prompts)

signal regions_ready()

const REGION_SCRIPTS := {
	"Krupa_Valley": "res://stage4/world/region_krupa_valley.gd",
	"Crnca_Village": "res://stage4/world/region_crnca_village.gd",
	"Security_Checkpoint": "res://stage4/world/region_security_checkpoint.gd",
	"Durmitor_Forest_Hideout": "res://stage4/world/region_durmitor_hideout.gd",
	"Krupa_Canyon_Crossings": "res://stage4/world/region_canyon_crossings.gd",
	"Lovcen_High_Peaks": "res://stage4/world/region_lovcen_peaks.gd",
}

var terrain_data: MontenegroTerrainData
var regions_root: Node3D
var regions: Array[WorldRegion] = []
var player: PlayerController
var hud: Node


func setup(p_terrain_data: MontenegroTerrainData, p_player: PlayerController, p_hud: Node) -> void:
	terrain_data = p_terrain_data
	player = p_player
	hud = p_hud

	Stage4Props.data = terrain_data

	_build_extended_river()
	_build_regions()
	_build_outer_vegetation()
	_build_bridge()
	_register_with_streamer()
	regions_ready.emit()


# ---------------------------------------------------------------- hydrology
## The baseline river mesh only covers Z -260..+240 while the world spans
## ±700 m. This adds the missing northern gorge and southern canyon stretches
## using the SAME MontenegroTerrainData river functions, so the surface is
## continuous with the original mesh (and with the carved terrain).
func _build_extended_river() -> void:
	var river := Stage4River.new()
	river.name = "LongRiver"
	add_child(river)
	river.build(terrain_data)


func _build_outer_vegetation() -> void:
	var veg := preload("res://stage4/world/stage4_vegetation.gd").new()
	veg.name = "Stage4Vegetation"
	add_child(veg)
	veg.build(terrain_data)


# ------------------------------------------------------------------ regions
func _build_regions() -> void:
	regions_root = Node3D.new()
	regions_root.name = "Regions"
	add_child(regions_root)
	for id in REGION_SCRIPTS.keys():
		var path: String = REGION_SCRIPTS[id]
		if not ResourceLoader.exists(path):
			push_warning("Stage4: region script missing -> " + path)
			continue
		var sc := load(path) as Script
		if sc == null:
			continue
		var region := WorldRegion.new()
		region.set_script(sc)
		region.region_id = id
		region.name = "Region_" + id
		region.terrain_data = terrain_data
		region.player = player
		regions_root.add_child(region)
		regions.append(region)


## Registers every region with the (previously orphaned) Stage 3 WorldStreamer.
func _register_with_streamer() -> void:
	var streamer := get_tree().root.get_node_or_null("WorldStreamer")
	if streamer == null:
		push_warning("Stage4: WorldStreamer autoload not found — regions stay ACTIVE.")
		for r in regions:
			r.set_stream_state(0)
		return
	streamer.set_player(player)
	for r in regions:
		streamer.register_region(r)


func _build_bridge() -> void:
	# Keep the Stage 3.2 bridge untouched; Stage 4 only adds the walkable
	# collision deck if the baseline one is missing a top surface.
	pass


# ---------------------------------------------------------------- utilities
func region_by_id(id: String) -> WorldRegion:
	for r in regions:
		if r.region_id == id:
			return r
	return null


## Teleports the player to a region. If the region exposes a `focus_point`
## (its main landmark) the player is placed ~18 m in front of it and the camera
## is turned to face it, so a debug jump immediately shows what the region has.
func teleport_to_region(id: String) -> void:
	var data := RegionData.get_region(id)
	if data.is_empty() or player == null:
		return
	var c: Vector2 = data["center"]
	var focus := Vector2.ZERO
	var has_focus := false
	for r in regions:
		if r.region_id == id:
			var fp: Variant = r.get("focus_point")
			if fp != null:
				focus = fp
				has_focus = focus.length() > 0.001
			break
	var stand := c
	if has_focus:
		var away := (c - focus)
		if away.length() < 1.0:
			away = Vector2(0.0, -1.0)
		stand = focus + away.normalized() * 17.0
	var y := terrain_data.get_height(stand.x, stand.y) + 1.0
	player.global_position = Vector3(stand.x, y, stand.y)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var cam: PlayerCamera = player.get_node_or_null("CameraRig") as PlayerCamera
	if cam and has_focus:
		var d := focus - stand
		# Stage 3.2 camera yaw 0 looks toward -Z, so yaw = atan2(-dx, -dz)
		var yaw := atan2(-d.x, -d.y)
		var pitch := -6.0
		if cam.has_method("set_angles_deg"):
			cam.set_angles_deg(rad_to_deg(yaw), pitch)
	if player is Node3D:
		(player as Node3D).rotation.y = 0.0
	var streamer := get_tree().root.get_node_or_null("WorldStreamer")
	if streamer and streamer.has_method("refresh_now"):
		streamer.refresh_now()
	if hud and hud.has_method("show_toast"):
		hud.show_toast(str(data["subtitle"]))
