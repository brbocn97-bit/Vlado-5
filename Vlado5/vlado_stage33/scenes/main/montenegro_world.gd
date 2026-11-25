extends Node3D

var terrain_data: MontenegroTerrainData

@onready var sun: DirectionalLight3D = $SunLight
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var terrain: MontenegroTerrain = $MontenegroTerrain
@onready var water: WaterSystem = $WaterSystem
@onready var rocks: RockFormations = $RockFormations
@onready var settlement: MontenegroSettlement = $MontenegroSettlement
@onready var vegetation: MontenegroVegetation = $MontenegroVegetation
@onready var time_ctrl: TimeOfDayController = $TimeOfDayController
@onready var player: PlayerController = $VladoPlayer
@onready var camera_rig: PlayerCamera = $VladoPlayer/CameraRig
@onready var visual_root: Node3D = $VladoPlayer/VisualRoot

func _ready() -> void:
	terrain_data = MontenegroTerrainData.new()

	terrain.build_terrain(terrain_data)
	rocks.build_rocks(terrain_data)
	water.build_water(terrain_data)
	settlement.build_settlement(terrain_data)
	vegetation.build_vegetation(terrain_data)

	time_ctrl.setup(sun, world_env, settlement.night_lights, settlement.emissive_window_mats)

	var sound_mgr := SoundManager.new()
	sound_mgr.name = "SoundManager"
	add_child(sound_mgr)

	var weapon_ctrl := player.find_child("WeaponController", true, false) as WeaponController
	if player:
		player.set_sound_manager(sound_mgr)
	if weapon_ctrl:
		weapon_ctrl.set_sound_manager(sound_mgr)

	ShootingTarget.spawn_range_in_world(self, terrain_data, weapon_ctrl)

	var spawn_x := -5.0
	var spawn_z := 9.5
	var spawn_y := terrain_data.get_height(spawn_x, spawn_z) + 0.08
	player.global_position = Vector3(spawn_x, spawn_y, spawn_z)
	if visual_root:
		visual_root.rotation.y = deg_to_rad(32.0)
	if camera_rig:
		camera_rig.set_angles_deg(28.0, -8.0)
		camera_rig.snap_to_target()

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.apply_graphics_to_scene(sun)
